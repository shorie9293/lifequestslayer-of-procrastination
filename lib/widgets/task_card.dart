import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Widget? trailing; // For header trailing if needed, though ExpansionTile has trailing.
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

  @override
  Widget build(BuildContext context) {
    // Default styling checks
    final cardColor = color ?? (task.status == TaskStatus.active ? Colors.red[900] : null);
    final textColor = (cardColor != null && cardColor.computeLuminance() < 0.5) ? Colors.white : null;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        collapsedIconColor: textColor,
        iconColor: textColor,
        collapsedTextColor: textColor,
        textColor: textColor,
        leading: Icon(
          task.status == TaskStatus.active ? Icons.bug_report : Icons.assignment,
          size: 40,
          color: textColor,
        ),
        title: Text(
          "[${task.rank.name}] ${task.title}",
          style: GoogleFonts.vt323(fontSize: 24, color: textColor),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!, style: TextStyle(color: textColor?.withOpacity(0.7)))
            : null,
        children: [
          if (task.subTasks.isNotEmpty)
            ...task.subTasks.asMap().entries.map((entry) {
              final idx = entry.key;
              final sub = entry.value;
              return ListTile(
                title: Text(sub.title, style: TextStyle(color: textColor)),
                leading: Checkbox(
                  value: sub.isCompleted,
                  onChanged: onSubTaskToggle != null
                      ? (val) => onSubTaskToggle!(idx, val)
                      : null, // Read-only if no callback
                  checkColor: Colors.black,
                  activeColor: Colors.white,
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ),
        ],
      ),
    );
  }
}
