import 'dart:math' as math;
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

/// Comandos de MUSIC_PROCESSING (feature 5), conferidos no fone e no plugin do app.
class EqCmd {
  static const getState = 0;
  static const getPresets = 1;
  static const getActivePreset = 2;
  static const setActivePreset = 3;
  static const getBandCount = 4;
  static const getBands = 5;

  /// SET das bandas do preset personalizado (0x3F). O fone não manda ack.
  static const setBands = 6;
}

/// Id do preset personalizado (editável).
const int kCustomPreset = 0x3f;

/// Banda de EQ: 7 bytes [freq u16 BE][Q*4096 u16 BE][tipo u8][ganho*60 i16 BE].
class EqBand {
  EqBand(this.index, this.freqHz, this.q, this.type, this.gainDb);

  final int index;
  final int freqHz;
  final double q;
  final int type;
  final double gainDb;

  EqBand copyWith({int? freqHz, double? q, int? type, double? gainDb}) => EqBand(
      index, freqHz ?? this.freqHz, q ?? this.q, type ?? this.type, gainDb ?? this.gainDb);
}

/// Interpreta a resposta de EqCmd.getBands: [ini][fim][pregain*60 i16 BE] + bandas.
({List<EqBand> bands, double preGainDb}) parseEqBands(Uint8List p) {
  if (p.length < 2) return (bands: const <EqBand>[], preGainDb: 0.0);
  final start = p[0];
  final end = p[1];
  if (end < start) return (bands: const <EqBand>[], preGainDb: 0.0);
  final n = end - start + 1;
  final off = p.length >= n * 7 + 4 ? 4 : 2;
  final bd = ByteData.sublistView(p);
  final pre = off == 4 ? bd.getInt16(2) / 60.0 : 0.0;
  final out = <EqBand>[];
  for (var i = 0; i < n; i++) {
    final o = off + i * 7;
    if (o + 7 > p.length) break;
    out.add(EqBand(start + i, bd.getUint16(o), bd.getUint16(o + 2) / 4096.0,
        p[o + 4], bd.getInt16(o + 5) / 60.0));
  }
  return (bands: out, preGainDb: pre);
}

/// Monta os payloads de EqCmd.setBands (como o app oficial: até 7 bandas por pacote,
/// cada um com [ini][fim][pregain*60 i16 BE] + bandas de 7 bytes).
List<List<int>> buildEqSetPayloads(List<EqBand> bands, double preGainDb) {
  final out = <List<int>>[];
  final pre = (preGainDb * 60).truncate().clamp(-32768, 32767);
  for (var s = 0; s < bands.length; s += 7) {
    final chunk = bands.sublist(s, (s + 7).clamp(0, bands.length));
    final b = ByteData(4 + chunk.length * 7);
    b.setUint8(0, s);
    b.setUint8(1, s + chunk.length - 1);
    b.setInt16(2, pre);
    for (var i = 0; i < chunk.length; i++) {
      final o = 4 + i * 7;
      final band = chunk[i];
      b.setUint16(o, band.freqHz);
      b.setUint16(o + 2, (band.q * 4096).truncate().clamp(0, 65535));
      b.setUint8(o + 4, band.type);
      b.setInt16(o + 5, (band.gainDb * 60).truncate().clamp(-32768, 32767));
    }
    out.add(b.buffer.asUint8List());
  }
  return out;
}

/// Pregain automático: compensa o maior pico positivo da curva (+0,2 dB de folga).
double autoPreGainDb(List<EqBand> bands, {int sampleRate = 48000}) {
  var peak = 0.0;
  for (var k = 0; k < 400; k++) {
    final f = 20.0 * math.pow(1000.0, k / 399.0); // 20 Hz .. 20 kHz
    var db = 0.0;
    for (final b in bands) {
      db += _peakingDb(f, b, sampleRate);
    }
    if (db > peak) peak = db;
  }
  if (peak <= 0) return 0.0;
  return -((peak + 0.2) * 10).round() / 10.0;
}

/// Resposta total (dB) das bandas na frequência [f], somando os filtros peaking.
double eqCurveDb(List<EqBand> bands, double f, {int sampleRate = 48000}) {
  var db = 0.0;
  for (final b in bands) {
    db += _peakingDb(f, b, sampleRate);
  }
  return db;
}

double _peakingDb(double f, EqBand b, int fs) {
  if (b.gainDb == 0) return 0.0;
  final a = math.pow(10, b.gainDb / 40).toDouble();
  final w0 = 2 * math.pi * b.freqHz / fs;
  final al = math.sin(w0) / (2 * b.q);
  final c = math.cos(w0);
  final a0 = 1 + al / a;
  final b0 = (1 + al * a) / a0, b1 = -2 * c / a0, b2 = (1 - al * a) / a0;
  final a1 = -2 * c / a0, a2 = (1 - al / a) / a0;
  final w = 2 * math.pi * f / fs;
  final cw = math.cos(w), sw = math.sin(w), c2 = math.cos(2 * w), s2 = math.sin(2 * w);
  final nr = b0 + b1 * cw + b2 * c2, ni = -(b1 * sw + b2 * s2);
  final dr = 1 + a1 * cw + a2 * c2, di = -(a1 * sw + a2 * s2);
  final num = nr * nr + ni * ni, den = dr * dr + di * di;
  return 10 * math.log(num / den) / math.ln10;
}

String eqPresetName(int id) => id == kCustomPreset ? 'Personalizado' : 'Preset $id';

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

