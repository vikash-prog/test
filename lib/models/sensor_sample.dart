import 'dart:typed_data';

class SensorSample {
  static const int bytesPerSample = 32;
  static const int samplesPerPacket = 16;

  final int timestamp;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double speed;

  const SensorSample({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.speed,
  });

  factory SensorSample.fromBytes(ByteData data, int offset) {
    return SensorSample(
      timestamp: data.getUint32(offset + 0, Endian.little),
      accelX:    data.getFloat32(offset + 4,  Endian.little),
      accelY:    data.getFloat32(offset + 8,  Endian.little),
      accelZ:    data.getFloat32(offset + 12, Endian.little),
      gyroX:     data.getFloat32(offset + 16, Endian.little),
      gyroY:     data.getFloat32(offset + 20, Endian.little),
      gyroZ:     data.getFloat32(offset + 24, Endian.little),
      speed:     data.getFloat32(offset + 28, Endian.little),
    );
  }

  static List<SensorSample> parsePacket(List<int> raw) {
    if (raw.length < samplesPerPacket * bytesPerSample) return [];
    final bd = ByteData.sublistView(Uint8List.fromList(raw));
    return List.generate(
      samplesPerPacket,
      (i) => SensorSample.fromBytes(bd, i * bytesPerSample),
    );
  }
}