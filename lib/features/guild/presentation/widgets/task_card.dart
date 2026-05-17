import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Widget? trailing;
  final List<Widget> actions;
  final Color? color;
  final bool initiallyExpanded;
  final Function(int index, bool? value)? onSubTaskToggle;
  final String? subtitle;

  final bool isUrgent;

  TaskCard({
    super.key,
    required this.task,
    required this.actions,
    this.trailing,
    this.color,
    this.initiallyExpanded = false,
    this.onSubTaskToggle,
    this.subtitle,
  }) : isUrgent = task.deadline != null &&
           task.deadline!.isBefore(DateTime.now().add(const Duration(days: 1)));

  String _getRankEnemyEmoji(QuestRank rank) {
    switch (rank) {
      case QuestRank.S:
        return '🐉'; // ドラゴン
      case QuestRank.A:
        return '👹'; // オーガ
      case QuestRank.B:
        return '👺'; // ゴブリン（天狗）
    }
  }

  Color _getRankBorderColor(QuestRank rank) {
    switch (rank) {
      case QuestRank.S:
        return Colors.amber; // 金の輝き
      case QuestRank.A:
        return Colors.grey.shade400; // 銀の輝き
      case QuestRank.B:
        return Colors.brown.shade300; // 銅の輝き
    }
  }

  /// 修練場（active）の敵アバターを構築。
  /// 緊急時は炎エフェクト＋拡大で一段階強化する。
  Widget _buildEnemyAvatar(Color textColor) {
    final bool enhanceUrgent = isUrgent; // 修練場の緊急タスクを炎で強化
    final double size = enhanceUrgent ? 64.0 : 56.0;
    final double emojiSize = enhanceUrgent ? 30.0 : 26.0;
    final Color borderColor = enhanceUrgent
        ? Colors.deepOrange
        : _getRankBorderColor(task.rank);
    final double borderWidth = enhanceUrgent ? 3.0 : 2.5;
    final Color glowColor = enhanceUrgent
        ? Colors.orange
        : _getRankBorderColor(task.rank);
    final double glowAlpha = enhanceUrgent ? 0.9 : 0.7;
    final double blurRadius = enhanceUrgent ? 20.0 : 14.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: glowAlpha),
            blurRadius: blurRadius,
            spreadRadius: enhanceUrgent ? 5 : 3,
          ),
          if (enhanceUrgent)
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.4),
              blurRadius: 28,
              spreadRadius: 8,
            ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(enhanceUrgent ? 2.0 : 3.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getRankEnemyEmoji(task.rank),
              style: TextStyle(fontSize: emojiSize),
            ),
            if (enhanceUrgent)
              const Text('🔥', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = color ??
        (task.status == TaskStatus.active
            ? Colors.red[900]
            : const Color(0xFF2A2D34));
    final textColor = (cardColor != null && cardColor.computeLuminance() < 0.5)
        ? Colors.white
        : Colors.black87;

    return SemanticHelper.container(
        testId: '${SemanticTypes.listItem}_task_${task.id}',
        child: Card(
          key: Key('card_task_${task.id}'),
          color: cardColor,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: initiallyExpanded,
                collapsedIconColor: textColor,
                iconColor: textColor,
                collapsedTextColor: textColor,
                textColor: textColor,
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: task.status == TaskStatus.active
                    ? _buildEnemyAvatar(textColor)
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getRankBorderColor(task.rank)
                                .withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(Icons.assignment,
                                size: 24, color: textColor),
                          ),
                        ),
                      ),
                title: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        identifier: 'txt_task_title_${task.id}',
                        child: Text(
                          "[${task.rank.name}] ${task.title}",
                          style: GoogleFonts.vt323(
                              fontSize: 26,
                              color: textColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('緊急',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                subtitle: subtitle != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(subtitle!,
                            style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 13)),
                      )
                    : null,
                children: [
                  if (task.subTasks.isNotEmpty)
                    Container(
                      color: Colors.black.withValues(alpha: 0.1),
                      child: Column(
                        children: task.subTasks.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final sub = entry.value;
                          return ListTile(
                            key: Key('subtask_${task.id}_$idx'),
                            dense: true,
                            title: Text(sub.title,
                                style:
                                    TextStyle(color: textColor, fontSize: 16)),
                            leading: SemanticHelper.toggle(
                              testId:
                                  '${SemanticTypes.toggle}_subtask_${task.id}_$idx',
                              value: sub.isCompleted,
                              child: Checkbox(
                                key: Key('chk_subtask_${task.id}_$idx'),
                                value: sub.isCompleted,
                                onChanged: onSubTaskToggle != null
                                    ? (val) => onSubTaskToggle!(idx, val)
                                    : null,
                                checkColor: Colors.black,
                                activeColor: Colors.amberAccent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
