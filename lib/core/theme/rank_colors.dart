import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// クエストランクごとの色定義（home_screen / guild_screen で重複していたものを集約）
class RankColors {
  static const Color s = Color(0xFFD4A038); // 金
  static const Color a = Color(0xFF9E9E9E); // 銀
  static const Color b = Color(0xFF8D6E63); // 銅
  static const Color defaultColor = Color(0xFF2A2520);

  static Color forRank(QuestRank rank) {
    switch (rank) {
      case QuestRank.S:
        return s;
      case QuestRank.A:
        return a;
      case QuestRank.B:
        return b;
    }
  }
}
