import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 22050;

void main() async {
  const cues = <String, (double, List<_Tone>)>{
    'dispatch.wav': (
      0.15,
      [
        _Tone(0, 0.15, 587.33, 783.99, 0.20),
        _Tone(0.025, 0.12, 1174.66, 1567.98, 0.045),
      ],
    ),
    'boarding.wav': (
      0.31,
      [_Tone(0, 0.17, 698.46, 880, 0.16), _Tone(0.075, 0.2, 880, 1046.5, 0.14)],
    ),
    'depot_clear.wav': (
      0.52,
      [
        _Tone(0, 0.17, 659.25, 783.99, 0.13),
        _Tone(0.115, 0.2, 783.99, 987.77, 0.15),
        _Tone(0.245, 0.275, 987.77, 1318.51, 0.15),
      ],
    ),
    'stuck.wav': (
      0.25,
      [
        _Tone(0, 0.19, 392, 311.13, 0.14),
        _Tone(0.035, 0.215, 293.66, 220, 0.11),
      ],
    ),
  };

  final directory = Directory('assets/audio');
  await directory.create(recursive: true);
  for (final entry in cues.entries) {
    final bytes = _renderWave(entry.value.$1, entry.value.$2);
    await File(
      '${directory.path}${Platform.pathSeparator}${entry.key}',
    ).writeAsBytes(bytes, flush: true);
  }
}

Uint8List _renderWave(double duration, List<_Tone> tones) {
  final frameCount = (duration * _sampleRate).round();
  final dataBytes = frameCount * 2;
  final output = Uint8List(44 + dataBytes);
  final header = ByteData.sublistView(output);
  _writeAscii(output, 0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  _writeAscii(output, 8, 'WAVE');
  _writeAscii(output, 12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, _sampleRate, Endian.little);
  header.setUint32(28, _sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  _writeAscii(output, 36, 'data');
  header.setUint32(40, dataBytes, Endian.little);

  for (var sampleIndex = 0; sampleIndex < frameCount; sampleIndex++) {
    final time = sampleIndex / _sampleRate;
    var mixed = 0.0;
    for (final tone in tones) {
      final localTime = time - tone.start;
      if (localTime < 0 || localTime >= tone.duration) continue;
      final progress = localTime / tone.duration;
      final attack = (localTime / 0.009).clamp(0.0, 1.0);
      final release = ((tone.duration - localTime) / 0.03).clamp(0.0, 1.0);
      final envelope = attack * release * math.pow(1 - progress, 1.25);
      final phase =
          2 *
          math.pi *
          (tone.startFrequency * localTime +
              (tone.endFrequency - tone.startFrequency) *
                  localTime *
                  localTime /
                  (2 * tone.duration));
      final harmonics = math.sin(phase) + 0.18 * math.sin(phase * 2);
      mixed += tone.amplitude * envelope * harmonics;
      // A quiet third partial gives the short tones a little enamel-like ring.
      mixed += tone.amplitude * envelope * 0.035 * math.sin(phase * 3);
    }
    final pcm = (mixed.clamp(-0.94, 0.94) * 32767).round();
    header.setInt16(44 + sampleIndex * 2, pcm, Endian.little);
  }
  return output;
}

void _writeAscii(Uint8List target, int offset, String value) {
  for (var i = 0; i < value.length; i++) {
    target[offset + i] = value.codeUnitAt(i);
  }
}

class _Tone {
  const _Tone(
    this.start,
    this.duration,
    this.startFrequency,
    this.endFrequency,
    this.amplitude,
  );

  final double start;
  final double duration;
  final double startFrequency;
  final double endFrequency;
  final double amplitude;
}
