import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

class TaskCard extends StatefulWidget {
  // ━━━ 緊急度カラー定数 ━━━
  /// 6時間超：余裕あり（青）
  static const Color urgencyColorBlue = Color(0xFF42A5F5);
  /// 1〜6時間：注意（黄）
  static const Color urgencyColorYellow = Color(0xFFFFCA28);
  /// 1時間未満または期限切れ：緊急（赤）
  static const Color urgencyColorRed = Color(0xFFEF5350);

  final Task task;
  final Widget? trailing;
  final List<Widget> actions;
  final Color? color;
  final bool initiallyExpanded;
  final Function(int index, bool? value)? onSubTaskToggle;
  final String? subtitle;

  final bool isUrgent;
  final bool hideCountdown;
  final Widget? expandedDetails;
  final String? titleOverride;

  TaskCard({
    super.key,
    required this.task,
    required this.actions,
    this.trailing,
    this.color,
    this.initiallyExpanded = false,
    this.onSubTaskToggle,
    this.subtitle,
    this.hideCountdown = false,
    this.expandedDetails,
    this.titleOverride,
  }) : isUrgent = task.deadline != null &&
           task.deadline!.isBefore(DateTime.now().add(const Duration(days: 1)));

  /// 期限に基づく緊急度カラー
  /// - 期限なしまたは24時間超：null（通常表示）
  /// - 6時間超：青
  /// - 1〜6時間：黄
  /// - 1時間未満または期限切れ：赤
  Color? get urgencyColor {
    if (task.deadline == null) return null;
    final diff = task.deadline!.difference(DateTime.now());
    if (diff.inHours >= 24) return null;
    if (diff.inHours > 6) return urgencyColorBlue;
    if (diff.inHours > 1) return urgencyColorYellow;
    return urgencyColorRed;
  }

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  String _countdownText = '';
  Color? _currentUrgencyColor;
  final Set<int> _animatingSubtasks = {};

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateCountdown();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final deadline = widget.task.deadline;
    if (deadline == null) {
      setState(() {
        _countdownText = '';
        _currentUrgencyColor = null;
      });
      return;
    }

    final diff = deadline.difference(DateTime.now());
    final color = widget.urgencyColor;
    setState(() {
      _currentUrgencyColor = color;
      if (diff.isNegative) {
        _countdownText = '⚠ 期限切れ';
      } else if (diff.inHours > 0) {
        final mins = diff.inMinutes % 60;
        _countdownText = '⏱ あと${diff.inHours}時間'
            '${mins > 0 ? '$mins分' : ''}';
      } else if (diff.inMinutes > 0) {
        _countdownText = '⏱ あと${diff.inMinutes}分';
      } else {
        _countdownText = '⏱ まもなく締切';
      }
    });
  }

  Task get _task => widget.task;

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

  /// 敵アバター — 修練場・寄合所の両方で表示。緊急時は炎エフェクト＋拡大。
  Widget _buildEnemyAvatar(Color textColor) {
    final bool enhanceUrgent = widget.isUrgent;
    final double size = enhanceUrgent ? 64.0 : 56.0;
    final Color borderColor = enhanceUrgent
        ? Colors.deepOrange
        : _getRankBorderColor(_task.rank);
    final double borderWidth = enhanceUrgent ? 3.0 : 2.5;
    final Color glowColor = enhanceUrgent
        ? Colors.orange
        : _getRankBorderColor(_task.rank);
    final double glowAlpha = enhanceUrgent ? 0.9 : 0.7;
    final double blurRadius = enhanceUrgent ? 20.0 : 14.0;

    final bool hasSprite = _task.enemyAssetPath != null && _task.enemyAssetPath!.isNotEmpty;

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
          shape: BoxShape.circle,
          color: const Color(0xFF1A1A2E),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.3),
              blurRadius: 6,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasSprite
            ? Image.asset(
                _task.enemyAssetPath!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.help_outline,
                        color: Colors.white38, size: 24),
                ),
              )
            : const Center(
                child: Icon(Icons.help_outline,
                    color: Colors.white38, size: 24),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ??
        (_task.status == TaskStatus.active
            ? Colors.red[900]
            : const Color(0xFF2A2D34));
    final textColor = (cardColor != null && cardColor.computeLuminance() < 0.5)
        ? Colors.white
        : Colors.black87;
    final urgencyBorderColor = _currentUrgencyColor;

    return SemanticHelper.container(
        testId: '${SemanticTypes.listItem}_task_${_task.id}',
        child: Card(
          key: Key('card_task_${_task.id}'),
          color: cardColor,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: urgencyBorderColor ??
                    Colors.white.withValues(alpha: 0.1),
                width: urgencyBorderColor != null ? 2.0 : 1.5),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: widget.initiallyExpanded,
                collapsedIconColor: textColor,
                iconColor: textColor,
                collapsedTextColor: textColor,
                textColor: textColor,
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: (_task.status == TaskStatus.active ||
                        (_task.enemyAssetPath != null &&
                            _task.enemyAssetPath!.isNotEmpty))
                    ? _buildEnemyAvatar(textColor)
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getRankBorderColor(_task.rank)
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
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            identifier: 'txt_task_title_${_task.id}',
                            child: Text(
                              widget.titleOverride ??
                                  "[${_task.rank.name}] ${_task.title}",
                              style: GoogleFonts.vt323(
                                  fontSize: 26,
                                  color: textColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (widget.isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('緊急',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    // カウントダウン表示（hideCountdown=true の場合は抑制）
                    if (_countdownText.isNotEmpty && !widget.hideCountdown)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _countdownText,
                          style: TextStyle(
                            color: _currentUrgencyColor ?? Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: widget.subtitle != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(widget.subtitle!,
                            style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 13)),
                      )
                    : null,
                children: [
                  if (widget.expandedDetails != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                      child: widget.expandedDetails!,
                    ),
                  if (_task.subTasks.isNotEmpty)
                    Container(
                      color: Colors.black.withValues(alpha: 0.1),
                      child: Column(
                        children:
                            _task.subTasks.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final sub = entry.value;
                          final isAnimating = _animatingSubtasks.contains(idx);
                          return ListTile(
                            key: Key('subtask_${_task.id}_$idx'),
                            dense: true,
                            title: Text(sub.title,
                                style: TextStyle(
                                    color: textColor, fontSize: 16)),
                            leading: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: isAnimating ? 0.0 : 1.0,
                                end: 1.0,
                              ),
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.elasticOut,
                              builder: (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: SemanticHelper.toggle(
                                testId:
                                    '${SemanticTypes.toggle}_subtask_${_task.id}_$idx',
                                value: sub.isCompleted,
                                child: Checkbox(
                                  key: Key('chk_subtask_${_task.id}_$idx'),
                                  value: sub.isCompleted,
                                  onChanged: widget.onSubTaskToggle != null
                                      ? (val) {
                                          widget.onSubTaskToggle!(idx, val);
                                          setState(() {
                                            _animatingSubtasks.add(idx);
                                          });
                                          Future.delayed(
                                              const Duration(milliseconds: 400),
                                              () {
                                            if (mounted) {
                                              setState(() {
                                                _animatingSubtasks.remove(idx);
                                              });
                                            }
                                          });
                                        }
                                      : null,
                                  checkColor: Colors.black,
                                  activeColor: Colors.amberAccent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4)),
                                ),
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
                      children: widget.actions,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
