import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'package:rpg_todo/domain/models/task.dart';

void main() {
  group('RankColors', () {
    test('forRank - Sランクは金色', () {
      expect(RankColors.forRank(QuestRank.S), const Color(0xFFD4A038));
    });

    test('forRank - Aランクは銀色', () {
      expect(RankColors.forRank(QuestRank.A), const Color(0xFF9E9E9E));
    });

    test('forRank - Bランクは銅色', () {
      expect(RankColors.forRank(QuestRank.B), const Color(0xFF8D6E63));
    });

    test('static colors - Sランク色が正しい', () {
      expect(RankColors.s, const Color(0xFFD4A038));
    });

    test('static colors - Aランク色が正しい', () {
      expect(RankColors.a, const Color(0xFF9E9E9E));
    });

    test('static colors - Bランク色が正しい', () {
      expect(RankColors.b, const Color(0xFF8D6E63));
    });

    test('static colors - defaultColorが正しい', () {
      expect(RankColors.defaultColor, const Color(0xFF2A2520));
    });
  });
}
