import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Conexão RFCOMM (SPP) usando Winsock Bluetooth direto via FFI.
/// O trabalho bloqueante roda num isolate para não travar a interface.
class SppConnection {
  SppConnection._(this._send, this._events);

  final SendPort _send;
  final ReceivePort _events;
  var _closed = false;
  Completer<Uint8List>? _pending;

  static Future<SppConnection> connect(String mac) async {
    final events = ReceivePort();
    final ready = Completer<SendPort>();
    final first = Completer<String?>();
    late final SppConnection conn;

    events.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is List && m[0] == 'connected') {
        first.complete(m[1] as String?);
      } else if (m is List && m[0] == 'data') {
        conn._pending?.complete(m[1] as Uint8List);
        conn._pending = null;
      }
    });

    await Isolate.spawn(_worker, events.sendPort);
    final port = await ready.future;
    conn = SppConnection._(port, events);
    port.send(['connect', mac]);
    final err = await first.future.timeout(const Duration(seconds: 25),
        onTimeout: () => 'Tempo esgotado ao conectar');
    if (err != null) {
      conn.close();
      throw StateError(err);
    }
    return conn;
  }

  /// Envia [frame] e devolve os bytes recebidos até [quietMs] sem novos dados.
  Future<Uint8List> request(Uint8List frame,
      {int waitMs = 1500, int quietMs = 120}) {
    if (_closed) return Future.error(StateError('Conexão fechada'));
    final c = Completer<Uint8List>();
    _pending = c;
    _send.send(['req', frame, waitMs, quietMs]);
    return c.future.timeout(Duration(milliseconds: waitMs + 4000), onTimeout: () {
      _pending = null;
      return Uint8List(0);
    });
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _send.send(['close']);
    _events.close();
  }
}

// ---------------------------------------------------------------- worker

const int _afBth = 32;
const int _sockStream = 1;
const int _bthprotoRfcomm = 3;
const int _solSocket = 0xFFFF;
const int _soRcvTimeo = 0x1006;

void _worker(SendPort main) {
  final cmds = ReceivePort();
  main.send(cmds.sendPort);

  final ws2 = DynamicLibrary.open('ws2_32.dll');
  final wsaStartup = ws2.lookupFunction<
      Int32 Function(Uint16, Pointer<Uint8>),
      int Function(int, Pointer<Uint8>)>('WSAStartup');
  final socketFn = ws2.lookupFunction<IntPtr Function(Int32, Int32, Int32),
      int Function(int, int, int)>('socket');
  final connectFn = ws2.lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>, Int32),
      int Function(int, Pointer<Uint8>, int)>('connect');
  final sendFn = ws2.lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>, Int32, Int32),
      int Function(int, Pointer<Uint8>, int, int)>('send');
  final recvFn = ws2.lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>, Int32, Int32),
      int Function(int, Pointer<Uint8>, int, int)>('recv');
  final closeFn = ws2.lookupFunction<Int32 Function(IntPtr),
      int Function(int)>('closesocket');
  final setsockopt = ws2.lookupFunction<
      Int32 Function(IntPtr, Int32, Int32, Pointer<Uint8>, Int32),
      int Function(int, int, int, Pointer<Uint8>, int)>('setsockopt');
  final lastError =
      ws2.lookupFunction<Int32 Function(), int Function()>('WSAGetLastError');

  var sock = -1;

  void setTimeout(int ms) {
    final v = calloc<Uint8>(4);
    v.asTypedList(4).buffer.asByteData().setUint32(0, ms, Endian.little);
    setsockopt(sock, _solSocket, _soRcvTimeo, v, 4);
    calloc.free(v);
  }

  String? doConnect(String mac) {
    final wsa = calloc<Uint8>(512);
    final r = wsaStartup(0x0202, wsa);
    calloc.free(wsa);
    if (r != 0) return 'WSAStartup falhou ($r)';

    sock = socketFn(_afBth, _sockStream, _bthprotoRfcomm);
    if (sock == -1) {
      return 'socket Bluetooth falhou (erro ${lastError()})';
    }

    final addr = int.parse(mac.replaceAll(RegExp('[:\\-]'), ''), radix: 16);
    // SOCKADDR_BTH é packed: family(2) btAddr(8) serviceClassId(16) port(4) = 30
    final sa = calloc<Uint8>(30);
    final bd = sa.asTypedList(30).buffer.asByteData();
    bd.setUint16(0, _afBth, Endian.little);
    bd.setUint64(2, addr, Endian.little);
    // GUID SPP 00001101-0000-1000-8000-00805F9B34FB
    bd.setUint32(10, 0x00001101, Endian.little);
    bd.setUint16(14, 0x0000, Endian.little);
    bd.setUint16(16, 0x1000, Endian.little);
    const d4 = [0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB];
    for (var i = 0; i < 8; i++) {
      bd.setUint8(18 + i, d4[i]);
    }
    bd.setUint32(26, 0, Endian.little); // porta 0 => resolve por SDP

    final rc = connectFn(sock, sa, 30);
    calloc.free(sa);
    if (rc != 0) {
      final e = lastError();
      closeFn(sock);
      sock = -1;
      return 'connect falhou (WSA $e). Fone ligado, pareado e livre?';
    }
    return null;
  }

  Uint8List doRequest(Uint8List frame, int waitMs, int quietMs) {
    final out = BytesBuilder();
    final tx = calloc<Uint8>(frame.length);
    tx.asTypedList(frame.length).setAll(0, frame);
    sendFn(sock, tx, frame.length, 0);
    calloc.free(tx);

    final rx = calloc<Uint8>(512);
    final sw = Stopwatch()..start();
    var lastData = -1;
    setTimeout(60);
    while (sw.elapsedMilliseconds < waitMs) {
      final n = recvFn(sock, rx, 512, 0);
      if (n > 0) {
        out.add(rx.asTypedList(n));
        lastData = sw.elapsedMilliseconds;
      } else if (n == 0) {
        break; // fechado pelo fone
      } else if (lastData >= 0 &&
          sw.elapsedMilliseconds - lastData >= quietMs) {
        break;
      }
    }
    calloc.free(rx);
    return out.takeBytes();
  }

  cmds.listen((m) {
    final msg = m as List;
    switch (msg[0]) {
      case 'connect':
        main.send(['connected', doConnect(msg[1] as String)]);
      case 'req':
        main.send(['data', doRequest(msg[1] as Uint8List, msg[2] as int, msg[3] as int)]);
      case 'close':
        if (sock != -1) closeFn(sock);
        sock = -1;
        cmds.close();
    }
  });
}


