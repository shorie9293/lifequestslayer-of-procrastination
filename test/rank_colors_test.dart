import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rpg_todo/utils/rank_colors.dart';
import 'package:rpg_todo/models/task.dart';

void main() {
  group('RankColors', () {
    test('forRank - Sランクは深い紫', () {
      expect(RankColors.forRank(QuestRank.S), const Color(0xFF4A148C));
    });

    test('forRank - Aランクはくすんだ臙脂色', () {
      expect(RankColors.forRank(QuestRank.A), const Color(0xFF8E3A3A));
    });

    test('forRank - Bランクは青灰色', () {
      expect(RankColors.forRank(QuestRank.B), const Color(0xFF455A64));
    });

    test('static colors - Sランク色が正しい', () {
      expect(RankColors.s, const Color(0xFF4A148C));
    });

    test('static colors - Aランク色が正しい', () {
      expect(RankColors.a, const Color(0xFF8E3A3A));
    });

    test('static colors - Bランク色が正しい', () {
      expect(RankColors.b, const Color(0xFF455A64));
    });

    test('static colors - defaultColorが正しい', () {
      expect(RankColors.defaultColor, const Color(0xFF424242));
    });
  });
}
