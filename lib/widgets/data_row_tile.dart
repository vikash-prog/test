import 'package:flutter/material.dart';
import '../models/sensor_sample.dart';

class DataRowTile extends StatelessWidget {
  final SensorSample sample;
  final int index;

  const DataRowTile({super.key, required this.sample, required this.index});

  @override
  Widget build(BuildContext context) {
    final ts = Duration(milliseconds: sample.timestamp);
    final tsStr =
        '${ts.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${ts.inSeconds.remainder(60).toString().padLeft(2, '0')}.'
        '${(ts.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0')}';

    return Container(
      color: index.isEven
          ? Colors.transparent
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
        child: Row(
          children: [
            _cell(tsStr, 58, color: Colors.grey),
            _cell(sample.accelX.toStringAsFixed(3), 54),
            _cell(sample.accelY.toStringAsFixed(3), 54),
            _cell(sample.accelZ.toStringAsFixed(3), 54),
            _cell(sample.gyroX.toStringAsFixed(3), 54),
            _cell(sample.gyroY.toStringAsFixed(3), 54),
            _cell(sample.gyroZ.toStringAsFixed(3), 54),
            _cell(sample.speed.toStringAsFixed(3), 50),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, double width, {Color? color}) => SizedBox(
        width: width,
        child: Text(text,
            textAlign: TextAlign.right,
            style: color != null ? TextStyle(color: color) : null),
      );
}