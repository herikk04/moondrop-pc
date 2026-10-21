import 'dart:typed_data';

/// Pacote GAIA v3 sobre RFCOMM: FF | versão | flags | len | vendor(2) | cmd(2) | payload.
/// Protocolo recuperado por análise do app oficial e confirmado no Space Travel 2.
const int kVendorQualcomm = 0x001D;

class GaiaFeature {
  static const basic = 0;
  static const earbud = 1;
  static const musicProcessing = 5;
  static const audioCuration = 8;
  static const battery = 13;
}

enum AncMode {
  off(0, 0x01, 'Desligado'),
  noise(1, 0x02, 'Cancelamento de ruído'),
  transparency(2, 0x04, 'Transparência');

  const AncMode(this.value, this.setMask, this.label);

  /// Valor devolvido pelo GET (feature 8, cmd 3).
  final int value;

  /// Máscara de bit enviada no SET (feature 8, cmd 4) = 1 << value.
  final int setMask;
  final String label;

  static AncMode? fromValue(int v) {
    for (final m in values) {
      if (m.value == v) return m;
    }
    return null;
  }
}

class GaiaFrame {
  GaiaFrame(this.feature, this.type, this.command, this.payload);

  final int feature;

  /// 0 comando, 1 notificação, 2 resposta, 3 erro.
  final int type;
  final int command;
  final Uint8List payload;

  @override
  String toString() =>
      'GaiaFrame(feature=$feature type=$type cmd=$command payload=${payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join()})';
}

Uint8List buildCommand(int feature, int command, [List<int> payload = const []]) {
  final id = (feature << 9) | command;
  return Uint8List.fromList([
    0xFF,
    0x03,
    0x00,
    payload.length,
    (kVendorQualcomm >> 8) & 0xFF,
    kVendorQualcomm & 0xFF,
    (id >> 8) & 0xFF,
    id & 0xFF,
    ...payload,
  ]);
}

/// Extrai quadros completos de [buf] e devolve o que sobrou.
({List<GaiaFrame> frames, Uint8List rest}) parseFrames(Uint8List buf) {
  final frames = <GaiaFrame>[];
  var i = 0;
  while (i < buf.length) {
    if (buf[i] != 0xFF) {
      i++;
      continue;
    }
    if (buf.length - i < 8) break;
    final len = buf[i + 3];
    final hasChecksum = (buf[i + 2] & 1) != 0;
    final total = 8 + len + (hasChecksum ? 1 : 0);
    if (buf.length - i < total) break;
    final id = (buf[i + 6] << 8) | buf[i + 7];
    frames.add(GaiaFrame(
      id >> 9,
      (id >> 7) & 0x3,
      id & 0x7F,
      Uint8List.fromList(buf.sublist(i + 8, i + 8 + len)),
    ));
    i += total;
  }
  return (frames: frames, rest: Uint8List.fromList(buf.sublist(i)));
}
