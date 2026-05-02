import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task.dart';
import '../core/accessibility/semantic_helper.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Widget? trailing;
  final List<Widget> actions;
  final Color? color;
  final bool initiallyExpanded;
  final Function(int index, bool? value)? onSubTaskToggle;
  final String? subtitle;

  const TaskCard({
    super.key,
    required this.task,
    required this.actions,
    this.trailing,
    this.color,
    this.initiallyExpanded = false,
    this.onSubTaskToggle,
    this.subtitle,
  });

  String _getRankEnemyEmoji(QuestRank rank) {
    switch (rank) {
      case QuestRank.S:
        return '🐉';
      case QuestRank.A:
        return '👹';
      case QuestRank.B:
        return '🐺';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? (task.status == TaskStatus.active ? Colors.red[900] : const Color(0xFF2A2D34));
    final textColor = (cardColor != null && cardColor.computeLuminance() < 0.5) ? Colors.white : Colors.black87;

    return SemanticHelper.container(
      testId: '${SemanticTypes.listItem}_task_${task.id}',
      child: Card(
        key: Key('card_task_${task.id}'),
        color: cardColor,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            collapsedIconColor: textColor,
            iconColor: textColor,
            collapsedTextColor: textColor,
            textColor: textColor,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: task.status == TaskStatus.active
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _getRankEnemyEmoji(task.rank),
                      style: const TextStyle(fontSize: 28),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.assignment, size: 28, color: textColor),
                  ),
            title: Semantics(
              identifier: 'txt_task_title_${task.id}',
              child: Text(
                "[${task.rank.name}] ${task.title}",
                style: GoogleFonts.vt323(fontSize: 26, color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
            subtitle: subtitle != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(subtitle!, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 13)),
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
                        title: Text(sub.title, style: TextStyle(color: textColor, fontSize: 16)),
                        leading: SemanticHelper.toggle(
                          testId: '${SemanticTypes.toggle}_subtask_${task.id}_$idx',
                          value: sub.isCompleted,
                          child: Checkbox(
                            key: Key('chk_subtask_${task.id}_$idx'),
                            value: sub.isCompleted,
                            onChanged: onSubTaskToggle != null
                                ? (val) => onSubTaskToggle!(idx, val)
                                : null,
                            checkColor: Colors.black,
                            activeColor: Colors.amberAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
