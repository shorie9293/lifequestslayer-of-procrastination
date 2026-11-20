import 'package:flutter/material.dart';

import 'package:rpg_todo/features/guild/domain/quest_grouping.dart';

/// パネル見出しの帯色。危険度（期限）と重さ（ランク）を色で分ける。
Color questGroupColor(QuestGroupBand band) => switch (band) {
      QuestGroupBand.overdue => const Color(0xFFE0684A),
      QuestGroupBand.today => const Color(0xFFE0684A),
      QuestGroupBand.tomorrow => const Color(0xFFC8A15A),
      QuestGroupBand.thisWeek => const Color(0xFFC8A15A),
      QuestGroupBand.later => const Color(0xFF7FA07A),
      QuestGroupBand.none => const Color(0xFF565049),
      QuestGroupBand.rankS => const Color(0xFFE0684A),
      QuestGroupBand.rankA => const Color(0xFFD8A849),
      QuestGroupBand.rankB => const Color(0xFF7FA07A),
    };

/// 寄合所のグルーピング見出し（1パネル分）。
///
/// クエスト行そのものは既存の [TaskCard] を再利用するため、ここは
/// 「何件・どんな内訳・たためるか」だけを担う薄いウィジェットにする。
class QuestGroupHeader extends StatelessWidget {
  const QuestGroupHeader({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
    this.isLight = false,
  });

  final QuestGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final accent = questGroupColor(group.band);
    final fg = isLight ? const Color(0xFF2E2A24) : const Color(0xFFF0E8DA);
    final sub = isLight ? const Color(0xFF6B6255) : const Color(0xFF9A8F7D);

    return Semantics(
      button: true,
      label: '${group.label} ${group.count}件 ${expanded ? 'たたむ' : 'ひらく'}',
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isLight ? 0.10 : 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accent.withValues(alpha: isLight ? 0.45 : 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                group.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  group.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: sub),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${group.count}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    // 帯色の明暗に応じて文字色を反転（3.0:1 以上を保つ）
                    color: accent.computeLuminance() > 0.45
                        ? const Color(0xFF12100E)
                        : const Color(0xFFF7F1E6),
                  ),
                ),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: sub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
