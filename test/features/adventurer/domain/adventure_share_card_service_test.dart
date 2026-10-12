import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card_service.dart';

Player _player({
  int totalTasks = 0,
  int s = 0,
  int warden = 0,
  int streak = 0,
  int longest = 0,
  int reflections = 0,
  int level = 3,
}) {
  return Player(
    jobLevels: {Job.adventurer: level},
    totalTasksCompleted: totalTasks,
    totalSRankCompleted: s,
    timesWardenDefeated: warden,
    streakDays: streak,
    longestStreak: longest,
    totalReflections: reflections,
  );
}

void main() {
  group('AdventureShareCardService.build', () {
    test('全フィールドがPlayerから正しく写像される', () {
      final card = AdventureShareCardService.build(_player(
        totalTasks: 42,
        s: 5,
        warden: 7,
        streak: 4,
        longest: 12,
        reflections: 20,
        level: 9,
      ));
      expect(card.rankLabel, '熟練冒険者');
      expect(card.level, 9);
      expect(card.totalTasksCompleted, 42);
      expect(card.totalSRankCompleted, 5);
      expect(card.wardenDefeated, 7);
      expect(card.currentStreak, 4);
      expect(card.longestStreak, 12);
      expect(card.totalReflections, 20);
    });

    test('rankLabelが閾値0で駆け出し', () {
      expect(AdventureShareCardService.build(_player(totalTasks: 0)).rankLabel,
          '駆け出し');
    });

    test('rankLabelが閾値1で見習い冒険者', () {
      expect(AdventureShareCardService.build(_player(totalTasks: 1)).rankLabel,
          '見習い冒険者');
    });

    test('rankLabelが閾値10で一人前冒険者', () {
      expect(AdventureShareCardService.build(_player(totalTasks: 10)).rankLabel,
          '一人前冒険者');
    });

    test('rankLabelが閾値30で熟練冒険者', () {
      expect(AdventureShareCardService.build(_player(totalTasks: 30)).rankLabel,
          '熟練冒険者');
    });

    test('rankLabelが閾値100で伝説の冒険者', () {
      expect(
          AdventureShareCardService.build(_player(totalTasks: 100)).rankLabel,
          '伝説の冒険者');
    });

    test('負値のtotalTasksCompletedが0にクランプされる', () {
      final card = AdventureShareCardService.build(_player(totalTasks: -3));
      expect(card.totalTasksCompleted, 0);
    });

    test('負値のtotalSRankCompletedが0にクランプされる', () {
      final card = AdventureShareCardService.build(_player(s: -2));
      expect(card.totalSRankCompleted, 0);
    });

    test('負値のwardenDefeatedが0にクランプされる', () {
      final card = AdventureShareCardService.build(_player(warden: -1));
      expect(card.wardenDefeated, 0);
    });

    test('負値のcurrentStreakが0にクランプされる', () {
      final card = AdventureShareCardService.build(_player(streak: -5));
      expect(card.currentStreak, 0);
    });

    test('負値のlongestStreakが0にクランプされる', () {
      final card = AdventureShareCardService.build(_player(longest: -7));
      expect(card.longestStreak, 0);
    });

    test('負値のtotalReflectionsが0にクランプされる', () {
      final card = AdventureShareCardService.build(_player(reflections: -4));
      expect(card.totalReflections, 0);
    });
  });

  group('AdventureShareCard.hasProgress', () {
    test('全0ならfalse', () {
      const card = AdventureShareCard(
        rankLabel: '駆け出し',
        level: 1,
        totalTasksCompleted: 0,
        totalSRankCompleted: 0,
        wardenDefeated: 0,
        currentStreak: 0,
        longestStreak: 0,
        totalReflections: 0,
      );
      expect(card.hasProgress, isFalse);
    });

    test('1つでも>0ならtrue（totalTasksCompleted）', () {
      const card = AdventureShareCard(
        rankLabel: '駆け出し',
        level: 1,
        totalTasksCompleted: 1,
        totalSRankCompleted: 0,
        wardenDefeated: 0,
        currentStreak: 0,
        longestStreak: 0,
        totalReflections: 0,
      );
      expect(card.hasProgress, isTrue);
    });

    test('1つでも>0ならtrue（wardenDefeated）', () {
      const card = AdventureShareCard(
        rankLabel: '駆け出し',
        level: 1,
        totalTasksCompleted: 0,
        totalSRankCompleted: 0,
        wardenDefeated: 1,
        currentStreak: 0,
        longestStreak: 0,
        totalReflections: 0,
      );
      expect(card.hasProgress, isTrue);
    });

    test('1つでも>0ならtrue（totalReflections）', () {
      const card = AdventureShareCard(
        rankLabel: '駆け出し',
        level: 1,
        totalTasksCompleted: 0,
        totalSRankCompleted: 0,
        wardenDefeated: 0,
        currentStreak: 0,
        longestStreak: 0,
        totalReflections: 3,
      );
      expect(card.hasProgress, isTrue);
    });
  });

  group('AdventureShareCard.levelLabel', () {
    test('Lv.形式で返す', () {
      const card = AdventureShareCard(
        rankLabel: '駆け出し',
        level: 12,
        totalTasksCompleted: 0,
        totalSRankCompleted: 0,
        wardenDefeated: 0,
        currentStreak: 0,
        longestStreak: 0,
        totalReflections: 0,
      );
      expect(card.levelLabel, 'Lv.12');
    });
  });

  group('AdventureShareCardService.shareText', () {
    test('複数行であること', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(
          totalTasks: 42,
          s: 5,
          warden: 7,
          streak: 4,
          longest: 12,
          reflections: 20,
        )),
      );
      expect(text.split('\n').length, greaterThan(1));
    });

    test('末尾が#RPGタスクであること', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(totalTasks: 5)),
      );
      expect(text.trim(), endsWith('#RPGタスク'));
    });

    test('称号が含まれること', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(totalTasks: 30)),
      );
      expect(text, contains('熟練冒険者'));
    });

    test('Lvラベルが含まれること', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(level: 8)),
      );
      expect(text, contains('Lv.8'));
    });

    test('総クエスト完了数が含まれること', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(totalTasks: 42)),
      );
      expect(text, contains('42'));
    });

    test('Sランク件数が含まれること', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(totalTasks: 10, s: 5)),
      );
      expect(text, contains('5'));
      expect(text, contains('Sランク'));
    });

    test('刻の番人討伐回数が含まれること', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(totalTasks: 10, warden: 7)),
      );
      expect(text, contains('7'));
      expect(text, contains('刻の番人'));
    });

    test('最長ストリークが含まれること', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(totalTasks: 10, longest: 12)),
      );
      expect(text, contains('12'));
      expect(text, contains('最長ストリーク'));
    });

    test('0値の項目は行に現れない（Sランク）', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(totalTasks: 10, s: 0)),
      );
      expect(text, isNot(contains('Sランク')));
    });

    test('0値の項目は行に現れない（刻の番人）', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(totalTasks: 10, warden: 0)),
      );
      expect(text, isNot(contains('刻の番人')));
    });

    test('0値の項目は行に現れない（最長ストリーク）', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(totalTasks: 10, longest: 0)),
      );
      expect(text, isNot(contains('最長ストリーク')));
    });

    test('0値の項目は行に現れない（振り返り）', () {
      final text = AdventureShareCardService.shareText(
        const AdventureShareCard(
          rankLabel: '一人前冒険者',
          level: 1,
          totalTasksCompleted: 10,
          totalSRankCompleted: 0,
          wardenDefeated: 0,
          currentStreak: 0,
          longestStreak: 0,
          totalReflections: 0,
        ),
      );
      expect(text, isNot(contains('振り返り')));
    });

    test('非0項目は全て行に現れること', () {
      final text = AdventureShareCardService.shareText(
        AdventureShareCardService.build(_player(
          totalTasks: 42,
          s: 5,
          warden: 7,
          streak: 4,
          longest: 12,
          reflections: 20,
        )),
      );
      expect(text, contains('Sランク'));
      expect(text, contains('刻の番人'));
      expect(text, contains('最長ストリーク'));
      expect(text, contains('振り返り'));
    });
  });
}
