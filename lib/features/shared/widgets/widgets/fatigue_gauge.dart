import 'package:flutter/material.dart';

/// 疲労ゲージ・体調表示Widget
class FatigueGauge extends StatelessWidget {
  final String fatigueStatus;
  final double fatigueProgress;
  final int fatigueLevel;
  final int dailyTasksCompleted;
  final int fatigueSevereThreshold;

  const FatigueGauge({
    super.key,
    required this.fatigueStatus,
    required this.fatigueProgress,
    required this.fatigueLevel,
    required this.dailyTasksCompleted,
    required this.fatigueSevereThreshold,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("体調: $fatigueStatus",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              "本日の完遂: $dailyTasksCompleted / $fatigueSevereThreshold",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: 1.0 - fatigueProgress,
          minHeight: 8,
          backgroundColor: Colors.grey[800],
          valueColor: AlwaysStoppedAnimation<Color>(
            fatigueProgress >= 1.0
                ? Colors.red
                : fatigueProgress >= 0.5
                    ? Colors.orange
                    : Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        _buildFatigueGauge(),
      ],
    );
  }

  Widget _buildFatigueGauge() {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    switch (fatigueLevel) {
      case 0: // 快調
        bgColor = Colors.blue.withValues(alpha: 0.25);
        borderColor = Colors.blueAccent;
        textColor = Colors.lightBlueAccent;
        break;
      case 1: // やや疲れ
        bgColor = Colors.amber.withValues(alpha: 0.25);
        borderColor = Colors.amber;
        textColor = Colors.amberAccent;
        break;
      case 2: // 疲労
        bgColor = Colors.orange.withValues(alpha: 0.3);
        borderColor = Colors.orange;
        textColor = Colors.orangeAccent;
        break;
      case 3: // 限界
        bgColor = Colors.red.withValues(alpha: 0.3);
        borderColor = Colors.redAccent;
        textColor = Colors.redAccent;
        break;
      default:
        bgColor = Colors.blue.withValues(alpha: 0.25);
        borderColor = Colors.blueAccent;
        textColor = Colors.lightBlueAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Text(
        fatigueStatus,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
