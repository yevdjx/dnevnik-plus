import 'dart:typed_data';

/// Wrap 16 kHz mono 16-bit little-endian PCM into a standard WAV file.
Uint8List pcmToWav(Uint8List pcm) {
  final out = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(out);
  void str(int at, String value) {
    for (var i = 0; i < value.length; i++) { out[at + i] = value.codeUnitAt(i); }
  }
  str(0, 'RIFF');
  data.setUint32(4, 36 + pcm.length, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  out.setRange(44, out.length, pcm);
  return out;
}
