import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'gaia.dart';
import 'spp_windows.dart';

class PairedDevice {
  PairedDevice(this.name, this.mac);
  final String name;
  final String mac;
}

/// Estado e comandos do fone, falando GAIA v3 por RFCOMM.
class MoondropDevice extends ChangeNotifier {
  SppConnection? _conn;
  Timer? _poll;
  var _busy = false;

  bool connected = false;
  bool connecting = false;
  String? error;
  String mac = '';
  AncMode? anc;
  List<({int id, int percent})> battery = const [];
  String? apiVersion;

  // ---------------------------------------------------------------- config
  File get _cfg {
    final base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
    return File('$base\\moondrop_pc\\config.json');
  }

  Future<void> loadConfig() async {
    try {
      final j = jsonDecode(await _cfg.readAsString()) as Map<String, dynamic>;
      mac = (j['mac'] as String?) ?? '';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveConfig() async {
    try {
      await _cfg.parent.create(recursive: true);
      await _cfg.writeAsString(jsonEncode({'mac': mac}));
    } catch (_) {}
  }

  // ------------------------------------------------------------- descoberta
  /// Lista dispositivos Bluetooth ClÃ¡ssico pareados no Windows (nome + MAC).
  static Future<List<PairedDevice>> listPaired() async {
    const script = r'''
Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
  Where-Object { $_.InstanceId -match '^BTHENUM\\DEV_([0-9A-F]{12})' } |
  ForEach-Object { $null = $_.InstanceId -match 'DEV_([0-9A-F]{12})'; "$($_.FriendlyName)|$($Matches[1])" } |
  Sort-Object -Unique
''';
    final r = await Process.run(
        'powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
    final seen = <String>{};
    final out = <PairedDevice>[];
    for (final line in const LineSplitter().convert(r.stdout.toString())) {
      final p = line.trim().split('|');
      if (p.length != 2 || p[1].length != 12) continue;
      if (!seen.add(p[1])) continue;
      final m = p[1];
      out.add(PairedDevice(p[0],
          '${m.substring(0, 2)}:${m.substring(2, 4)}:${m.substring(4, 6)}:${m.substring(6, 8)}:${m.substring(8, 10)}:${m.substring(10, 12)}'));
    }
    return out;
  }

  // -------------------------------------------------------------- conexÃ£o
  Future<void> connect(String address) async {
    if (connecting) return;
    connecting = true;
    error = null;
    mac = address.trim().toUpperCase();
    notifyListeners();
    try {
      _conn = await SppConnection.connect(mac);
      connected = true;
      await _saveConfig();
      await refreshAll();
      _poll = Timer.periodic(const Duration(seconds: 4), (t) => _tick(t.tick));
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
      await disconnect();
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _poll?.cancel();
    _poll = null;
    _conn?.close();
    _conn = null;
    connected = false;
    anc = null;
    battery = const [];
    notifyListeners();
  }

  // ------------------------------------------------------------- comandos
  Future<List<GaiaFrame>> _ask(int feature, int cmd, [List<int> payload = const []]) async {
    final c = _conn;
    if (c == null) return const [];
    final raw = await c.request(buildCommand(feature, cmd, payload));
    if (raw.isEmpty && connected) {
      // fone parou de responder
    }
    return parseFrames(raw).frames;
  }

  GaiaFrame? _response(List<GaiaFrame> fs, int feature, int cmd) {
    for (final f in fs) {
      if (f.feature == feature && f.command == cmd && f.type == 2) return f;
    }
    return null;
  }

  Future<void> refreshAll() async {
    if (_busy) return;
    _busy = true;
    try {
      final v = _response(await _ask(GaiaFeature.basic, 0), GaiaFeature.basic, 0);
      if (v != null && v.payload.length >= 2) {
        apiVersion = '${v.payload[0]}.${v.payload[1]}';
      }
      await _readAnc();
      await _readBattery();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _tick(int n) async {
    if (_busy || !connected) return;
    _busy = true;
    try {
      await _readAnc();
      if (n % 8 == 0) await _readBattery();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _readAnc() async {
    final r = _response(await _ask(GaiaFeature.audioCuration, 3),
        GaiaFeature.audioCuration, 3);
    if (r != null && r.payload.isNotEmpty) {
      anc = AncMode.fromValue(r.payload[0]);
    } else if (_conn != null && connected) {
      _failCount++;
      if (_failCount >= 3) {
        error = 'O fone parou de responder.';
        await disconnect();
      }
      return;
    }
    _failCount = 0;
  }

  var _failCount = 0;

  Future<void> _readBattery() async {
    final r = _response(
        await _ask(GaiaFeature.battery, 1), GaiaFeature.battery, 1);
    if (r == null) return;
    final p = r.payload;
    final list = <({int id, int percent})>[];
    for (var i = 0; i + 1 < p.length; i += 2) {
      list.add((id: p[i], percent: p[i + 1]));
    }
    battery = list;
  }

  /// Define o modo de ANC. O fone nÃ£o manda ack, entÃ£o relÃª o modo depois.
  Future<void> setAnc(AncMode mode) async {
    if (!connected) return;
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _busy = true;
    final before = anc;
    anc = mode; // otimista
    notifyListeners();
    try {
      await _ask(GaiaFeature.audioCuration, 4, [mode.setMask]);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _readAnc();
      if (anc != mode) {
        error = 'O fone nÃ£o aplicou o modo ${mode.label}.';
      } else {
        error = null;
      }
    } catch (e) {
      anc = before;
      error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _conn?.close();
    super.dispose();
  }
}

