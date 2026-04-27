import 'package:flutter/material.dart';
import '../models/task.dart';

/// クエストランクごとの色定義（home_screen / guild_screen で重複していたものを集約）
class RankColors {
  static const Color s = Color(0xFF4A148C); // 深い紫
  static const Color a = Color(0xFF8E3A3A); // くすんだ臙脂色
  static const Color b = Color(0xFF455A64); // 青灰色
  static const Color defaultColor = Color(0xFF424242);

  static Color forRank(QuestRank rank) {
    switch (rank) {
      case QuestRank.S: return s;
      case QuestRank.A: return a;
      case QuestRank.B: return b;
    }
  }
}
