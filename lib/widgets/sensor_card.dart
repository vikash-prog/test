import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final String label;
  final String x, y, z;
  final Color color;
  final IconData icon;

  const SensorCard({
    super.key,
    required this.label,
    required this.x,
    required this.y,
    required this.z,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _axis('X', x, color),
                _axis('Y', y, color),
                _axis('Z', z, color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _axis(String axis, String value, Color c) => Column(
        children: [
          Text(axis,
              style: TextStyle(
                  fontSize: 11,
                  color: c.withOpacity(0.7),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      );
}