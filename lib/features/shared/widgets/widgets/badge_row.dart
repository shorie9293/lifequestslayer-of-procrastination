import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';

/// ストリーク・ミッションバッジ表示Widget
class BadgeRow extends StatelessWidget {
  final int streakDays;
  final int dailyMissionProgress;
  final bool isDailyMissionComplete;
  final int weeklyMissionProgress;
  final bool isWeeklyMissionComplete;
  final int dailyMissionGoal;
  final int weeklyMissionGoal;

  const BadgeRow({
    super.key,
    required this.streakDays,
    required this.dailyMissionProgress,
    required this.isDailyMissionComplete,
    required this.weeklyMissionProgress,
    required this.isWeeklyMissionComplete,
    this.dailyMissionGoal = 3,
    this.weeklyMissionGoal = 1,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildStreakBadge(palette),
        _buildMissionBadge(
          palette: palette,
          icon: "📅",
          label: isDailyMissionComplete
              ? "デイリー達成！"
              : "デイリー: あと${dailyMissionGoal - dailyMissionProgress}クエスト",
          progress: dailyMissionProgress / dailyMissionGoal,
          isDone: isDailyMissionComplete,
        ),
        _buildMissionBadge(
          palette: palette,
          icon: "🏆",
          label: isWeeklyMissionComplete
              ? "週次ミッション達成！"
              : "週次Sランク: $weeklyMissionProgress/$weeklyMissionGoal",
          progress: weeklyMissionProgress / weeklyMissionGoal,
          isDone: isWeeklyMissionComplete,
        ),
      ],
    );
  }

  /// 旧 Colors.white24（枠・ドット）。ライトは墨24%へ。
  Color _hairline(GamePalette p) =>
      p.isLight ? const Color(0x3D000000) : Colors.white24;

  Widget _buildStreakBadge(GamePalette palette) {
    // 次のマイルストーンを求める
    final nextMilestone = streakDays < 3
        ? 3
        : streakDays < 7
            ? 7
            : 30;
    final progress = (streakDays / nextMilestone).clamp(0.0, 1.0);
    final isHot = streakDays >= 7;
    final dotCount = min(nextMilestone, 7); // 最大7ドット（1週間サイクル）

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHot ? Colors.orange.withValues(alpha: 0.2) : palette.track,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHot ? Colors.orange : _hairline(palette),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🔥 $streakDays 日連続",
            style: TextStyle(
              fontSize: 10,
              // ダークは従来の orangeAccent / white70。ライトは地色に対して
              // 4.5:1 を満たすまで濃色化する。
              color: isHot
                  ? palette.readable(Colors.orangeAccent)
                  : palette.onSurfaceMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(dotCount, (i) {
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < streakDays ? Colors.orange : _hairline(palette),
                ),
              );
            }),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor:
                  palette.isLight ? palette.track : Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isHot ? Colors.orange : Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionBadge({
    required GamePalette palette,
    required String icon,
    required String label,
    required double progress,
    required bool isDone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withValues(alpha: 0.2) : palette.track,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDone ? Colors.green : _hairline(palette),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$icon $label",
            style: TextStyle(
              fontSize: 10,
              color: isDone
                  ? palette.readable(Colors.greenAccent)
                  : palette.onSurfaceMuted,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor:
                  palette.isLight ? palette.track : Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? Colors.green : Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
