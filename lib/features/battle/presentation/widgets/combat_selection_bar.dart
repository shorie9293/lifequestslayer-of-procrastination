import 'package:flutter/material.dart';
import 'package:rpg_todo/features/battle/domain/battle_action.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 戦術選択バー — Attack / Defend / Skill の3択UI
///
/// 修練場の討伐フェイズで表示される戦術選択インターフェース。
/// 画面下部に横並びで3つのアクションボタンを配置し、
/// タップでコールバック [onActionSelected] を発火する。
///
/// レスポンシブ対応:
/// - 横幅 360px 以上: 横並び3ボタン（デフォルト）
/// - 横幅 360px 未満: 各ボタンを小さく表示
class CombatSelectionBar extends StatelessWidget {
  /// アクション選択時のコールバック
  final void Function(BattleAction action)? onActionSelected;

  /// 現在選択中のアクション（ハイライト表示用）
  final BattleAction? selectedAction;

  /// スキルが使用可能か（未使用時はスキルボタンを無効化）
  final bool skillAvailable;

  /// スキル未使用時の説明テキスト
  final String? skillUnavailableReason;

  const CombatSelectionBar({
    super.key,
    this.onActionSelected,
    this.selectedAction,
    this.skillAvailable = true,
    this.skillUnavailableReason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: AppKeys.combatSelectionBar,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black87,
            Colors.black.withValues(alpha: 0.95),
          ],
        ),
        border: const Border(
          top: BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: BattleAction.values.map((action) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ActionButton(
                      action: action,
                      isSelected: selectedAction == action,
                      isEnabled: action != BattleAction.skill || skillAvailable,
                      unavailableReason:
                          action == BattleAction.skill ? skillUnavailableReason : null,
                      compact: isNarrow,
                      onTap: () => onActionSelected?.call(action),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

/// 個別のアクションボタン
class _ActionButton extends StatelessWidget {
  final BattleAction action;
  final bool isSelected;
  final bool isEnabled;
  final String? unavailableReason;
  final bool compact;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.action,
    this.isSelected = false,
    this.isEnabled = true,
    this.unavailableReason,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isEnabled ? action.color : Colors.grey;
    final bgColor = isEnabled ? action.backgroundColor : Colors.grey.withValues(alpha: 0.15);
    final borderColor = isSelected
        ? baseColor
        : isEnabled
            ? baseColor.withValues(alpha: 0.5)
            : Colors.grey.withValues(alpha: 0.3);

    return SemanticHelper.interactive(
      testId: SemanticHelper.createTestId(
        SemanticTypes.button,
        'combat_${action.name}',
      ),
      label: '${action.emoji} ${action.label}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onTap : () => _showUnavailable(context),
            borderRadius: BorderRadius.circular(12),
            splashColor: baseColor.withValues(alpha: 0.2),
            highlightColor: baseColor.withValues(alpha: 0.1),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: compact ? 10 : 14,
                horizontal: compact ? 4 : 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 絵文字アイコン
                  Text(
                    action.emoji,
                    style: TextStyle(
                      fontSize: compact ? 24 : 32,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ラベル
                  Text(
                    action.label,
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.white54,
                      fontSize: compact ? 13 : 15,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    // 説明文（非コンパクト時のみ）
                    Text(
                      action.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(unavailableReason ?? 'このアクションは現在使用できません'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
