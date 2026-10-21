import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'gaia.dart';
import 'spp_windows.dart';
import 'window_bridge.dart';

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
  String? deviceName; // nome exibido (usado no modo demonstração)

  // EQ (feature 5)
  List<int> eqPresets = const [];
  int? eqActive;
  List<EqBand> eqBands = const [];
  double eqPreGain = 0;
  bool eqDirty = false; // há edições locais ainda não aplicadas ao fone
  bool eqEditing = false; // enquanto o usuário arrasta um slider, a leitura não sobrescreve

  // Preferências (salvas em %APPDATA%\moondrop_pc\config.json)
  bool autoConnect = true; // conecta ao abrir e reconecta se o fone cair
  bool closeToTray = false; // fechar a janela minimiza para a bandeja
  Timer? _retry;
  bool _manualOff = false; // o usuário pediu para desconectar: não reconectar sozinho

  // ---------------------------------------------------------------- config
  File get _cfg {
    final base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
    return File('$base\\moondrop_pc\\config.json');
  }

  Future<void> loadConfig() async {
    try {
      final j = jsonDecode(await _cfg.readAsString()) as Map<String, dynamic>;
      mac = (j['mac'] as String?) ?? '';
      autoConnect = (j['autoConnect'] as bool?) ?? true;
      closeToTray = (j['closeToTray'] as bool?) ?? false;
      WindowBridge.setCloseToTray(closeToTray);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveConfig() async {
    try {
      await _cfg.parent.create(recursive: true);
      await _cfg.writeAsString(jsonEncode(
          {'mac': mac, 'autoConnect': autoConnect, 'closeToTray': closeToTray}));
    } catch (_) {}
  }

  Future<void> setAutoConnect(bool v) async {
    autoConnect = v;
    if (!v) {
      _retry?.cancel();
      _retry = null;
    } else if (!connected && mac.isNotEmpty) {
      _manualOff = false;
      _scheduleRetry(const Duration(seconds: 1));
    }
    notifyListeners();
    await _saveConfig();
  }

  Future<void> setCloseToTray(bool v) async {
    closeToTray = v;
    WindowBridge.setCloseToTray(v);
    notifyListeners();
    await _saveConfig();
  }

  /// Chamado ao abrir o app: conecta sozinho ao último fone, se configurado.
  void startAuto() {
    if (autoConnect && mac.isNotEmpty && !connected && !connecting) {
      _scheduleRetry(const Duration(milliseconds: 300));
    }
  }

  void _scheduleRetry(Duration after) {
    _retry?.cancel();
    if (!autoConnect || _manualOff || mac.isEmpty) return;
    _retry = Timer(after, () {
      if (!connected && !connecting && autoConnect && !_manualOff) {
        connect(mac, silent: true);
      }
    });
  }

  /// Dados de exemplo para ver/testar a interface sem fone (MOONDROP_DEMO=1).
  void loadDemo() {
    connected = true;
    mac = '00:11:22:33:44:55';
    deviceName = 'Space Travel 2';
    apiVersion = '3.1';
    anc = AncMode.noise;
    battery = const [(id: 1, percent: 40), (id: 2, percent: 40)];
    eqPresets = const [0, 1, 2, 3, 4, kCustomPreset];
    eqActive = kCustomPreset;
    eqPreGain = -3.1;
    eqBands = [
      EqBand(0, 20, 0.7068, 0, -2.5),
      EqBand(1, 200, 0.7068, 0, 4.0),
      EqBand(2, 2000, 0.7068, 0, 0),
      EqBand(3, 12000, 0.7068, 0, -3.0),
      EqBand(4, 20000, 0.7068, 0, 3.0),
    ];
    notifyListeners();
  }

  // ------------------------------------------------------------- descoberta
  /// Lista dispositivos Bluetooth Clássico pareados no Windows (nome + MAC).
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

  // -------------------------------------------------------------- conexão
  /// [silent]: tentativa automática; falhas não mostram erro (o fone pode estar desligado).
  Future<void> connect(String address, {bool silent = false}) async {
    if (connecting) return;
    connecting = true;
    if (!silent) {
      error = null;
      _manualOff = false;
    }
    mac = address.trim().toUpperCase();
    notifyListeners();
    try {
      _conn = await SppConnection.connect(mac);
      connected = true;
      error = null;
      await _saveConfig();
      await refreshAll();
      _poll = Timer.periodic(const Duration(seconds: 4), (t) => _tick(t.tick));
    } catch (e) {
      if (!silent) error = e.toString().replaceFirst('Bad state: ', '');
      await disconnect();
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  /// [manual]: o usuário pediu para desconectar, então não reconecta sozinho.
  Future<void> disconnect({bool manual = false}) async {
    if (manual) {
      _manualOff = true;
      _retry?.cancel();
      _retry = null;
    }
    _poll?.cancel();
    _poll = null;
    _conn?.close();
    _conn = null;
    connected = false;
    anc = null;
    battery = const [];
    eqPresets = const [];
    eqActive = null;
    eqBands = const [];
    eqPreGain = 0;
    notifyListeners();
    if (!manual) _scheduleRetry(const Duration(seconds: 6));
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
      await _readEqPresets();
      await _readEqActive(force: true);
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
      await _readEqActive();
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

  Future<void> _readEqPresets() async {
    final r = _response(
        await _ask(GaiaFeature.musicProcessing, EqCmd.getPresets),
        GaiaFeature.musicProcessing,
        EqCmd.getPresets);
    if (r == null || r.payload.isEmpty) return;
    final n = r.payload[0];
    eqPresets = r.payload.sublist(1, (1 + n).clamp(1, r.payload.length)).toList();
  }

  /// Lê o preset ativo; recarrega as bandas quando ele muda (ou com [force]).
  Future<void> _readEqActive({bool force = false}) async {
    final r = _response(
        await _ask(GaiaFeature.musicProcessing, EqCmd.getActivePreset),
        GaiaFeature.musicProcessing,
        EqCmd.getActivePreset);
    if (r == null || r.payload.isEmpty) return;
    final id = r.payload[0];
    if (eqEditing) return;
    if (!force && id == eqActive && eqBands.isNotEmpty) return;
    eqActive = id;
    final c = _response(
        await _ask(GaiaFeature.musicProcessing, EqCmd.getBandCount),
        GaiaFeature.musicProcessing,
        EqCmd.getBandCount);
    final count = (c != null && c.payload.isNotEmpty) ? c.payload[0] : 0;
    if (count == 0) return;
    final b = _response(
        await _ask(GaiaFeature.musicProcessing, EqCmd.getBands, [0, count - 1]),
        GaiaFeature.musicProcessing,
        EqCmd.getBands);
    if (b != null) {
      final parsed = parseEqBands(b.payload);
      eqBands = parsed.bands;
      eqPreGain = parsed.preGainDb;
    }
  }

  /// Atualiza só na tela (enquanto o slider se move); [applyEq] manda ao fone.
  void editBandLocal(int bandIndex, {double? gainDb, int? freqHz, double? q}) {
    eqEditing = true;
    eqDirty = true;
    eqBands = [
      for (final b in eqBands)
        b.index == bandIndex ? b.copyWith(gainDb: gainDb, freqHz: freqHz, q: q) : b
    ];
    notifyListeners();
  }

  void editPreGainLocal(double db) {
    eqEditing = true;
    eqDirty = true;
    eqPreGain = db;
    notifyListeners();
  }

  /// Calcula o pregain automático para a curva atual (não envia).
  void autoPreGainLocal() {
    eqEditing = true;
    eqDirty = true;
    eqPreGain = autoPreGainDb(eqBands);
    notifyListeners();
  }

  /// Descarta as edições locais e relê as bandas do fone.
  Future<void> resetEq() async {
    if (!connected) return;
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _busy = true;
    try {
      eqEditing = false;
      eqDirty = false;
      await _readEqActive(force: true);
      error = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Envia as bandas editadas ao preset personalizado (feature 5, cmd 6) e confirma relendo.
  /// O fone não manda ack para este comando.
  Future<void> applyEq() async {
    if (!connected) return;
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _busy = true;
    final wanted = eqBands;
    final wantedPre = eqPreGain;
    try {
      if (eqActive != kCustomPreset) {
        await _ask(GaiaFeature.musicProcessing, EqCmd.setActivePreset, [kCustomPreset]);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      for (final payload in buildEqSetPayloads(wanted, wantedPre)) {
        await _ask(GaiaFeature.musicProcessing, EqCmd.setBands, payload);
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      eqEditing = false;
      await _readEqActive(force: true);
      var ok = eqActive == kCustomPreset && eqBands.length == wanted.length;
      if (ok) {
        for (var i = 0; i < wanted.length; i++) {
          if ((eqBands[i].gainDb - wanted[i].gainDb).abs() > 0.05 ||
              eqBands[i].freqHz != wanted[i].freqHz ||
              (eqBands[i].q - wanted[i].q).abs() > 0.01) {
            ok = false;
          }
        }
      }
      eqDirty = !ok;
      error = ok ? null : 'O fone não confirmou as bandas enviadas.';
    } catch (e) {
      error = e.toString();
    } finally {
      eqEditing = false;
      _busy = false;
      notifyListeners();
    }
  }

  /// Troca o preset de EQ (feature 5, cmd 3) e confirma relendo o preset ativo.
  Future<void> setEqPreset(int id) async {
    if (!connected) return;
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _busy = true;
    final before = eqActive;
    eqActive = id; // otimista
    notifyListeners();
    try {
      await _ask(GaiaFeature.musicProcessing, EqCmd.setActivePreset, [id]);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _readEqActive(force: true);
      if (eqActive != id) {
        error = 'O fone não aplicou o ${eqPresetName(id)}.';
      } else {
        error = null;
      }
    } catch (e) {
      eqActive = before;
      error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Define o modo de ANC. O fone não manda ack, então relê o modo depois.
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
        error = 'O fone não aplicou o modo ${mode.label}.';
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
    _retry?.cancel();
    _poll?.cancel();
    _conn?.close();
    super.dispose();
  }
}

