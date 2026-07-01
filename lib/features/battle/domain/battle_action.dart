import 'package:flutter/material.dart';

/// 戦術行動 — RPG戦闘における冒険者の選択肢
enum BattleAction {
  /// ⚔️ 攻撃 — 正面から討伐。標準的なダメージ。
  attack,

  /// 🛡️ 防御 — 守りを固めて討伐。討伐成功率UP、経験値減少。
  defend,

  /// ✨ スキル — 特殊能力を発動。装備スキルに応じたボーナス効果。
  skill,
}

/// BattleAction の表示用メタデータ拡張
extension BattleActionMeta on BattleAction {
  /// アクションの絵文字アイコン
  String get emoji {
    switch (this) {
      case BattleAction.attack:
        return '⚔️';
      case BattleAction.defend:
        return '🛡️';
      case BattleAction.skill:
        return '✨';
    }
  }

  /// アクションの日本語ラベル
  String get label {
    switch (this) {
      case BattleAction.attack:
        return '攻撃';
      case BattleAction.defend:
        return '防御';
      case BattleAction.skill:
        return 'スキル';
    }
  }

  /// アクションの説明文
  String get description {
    switch (this) {
      case BattleAction.attack:
        return '正面から討伐。\n標準ダメージ';
      case BattleAction.defend:
        return '守りを固める。\n討伐成功率↑ 経験値↓';
      case BattleAction.skill:
        return '特殊能力を発動。\n装備スキルで効果変化';
    }
  }

  /// アクションのテーマカラー
  Color get color {
    switch (this) {
      case BattleAction.attack:
        return const Color(0xFFE53935); // 赤 — 攻撃的
      case BattleAction.defend:
        return const Color(0xFF1E88E5); // 青 — 防御的
      case BattleAction.skill:
        return const Color(0xFF8E24AA); // 紫 — 魔法的
    }
  }

  /// アクションの薄い背景色
  Color get backgroundColor {
    switch (this) {
      case BattleAction.attack:
        return const Color(0x33E53935);
      case BattleAction.defend:
        return const Color(0x331E88E5);
      case BattleAction.skill:
        return const Color(0x338E24AA);
    }
  }
}
