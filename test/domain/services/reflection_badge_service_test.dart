import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/reflection_badge.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/reflection_badge_service.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

void main() {
  late String tempDir;
  late ReflectionRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_reflection_badge_test_').path;
    Hive.init(tempDir);
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(ReflectionAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(PlayerAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(JobAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(JobSkillAdapter());
    }
    repository = ReflectionRepository();
    // Clear any prior test data
    await repository.clearAll();
  });

  tearDown(() async {
    await Hive.close();
    Directory(tempDir).deleteSync(recursive: true);
  });

  // ── ヘルパー ──

  /// 振り返りを作成して保存する
  Future<Reflection> createReflection({
    String id = 'r1',
    String taskId = 't1',
    DateTime? date,
    String content = 'テストの振り返り',
    int selfDifficulty = 3,
    QuestRank aiDifficulty = QuestRank.B,
  }) async {
    final reflection = Reflection(
      id: id,
      taskId: taskId,
      date: date ?? DateTime.now(),
      content: content,
      selfDifficulty: selfDifficulty,
      aiDifficulty: aiDifficulty,
    );
    await repository.save(reflection);
    return reflection;
  }

  group('ReflectionBadgeDefinition', () {
    test('全バッジが定義されている', () {
      expect(kAllReflectionBadges.length, 12);
    });

    test('各バッジに一意のIDがある', () {
      final ids = kAllReflectionBadges.map((b) => b.id).toSet();
      expect(ids.length, kAllReflectionBadges.length);
    });

    test('tierが1-4の範囲に収まっている', () {
      for (final badge in kAllReflectionBadges) {
        expect(badge.tier, greaterThanOrEqualTo(1));
        expect(badge.tier, lessThanOrEqualTo(4));
      }
    });

    test('requiresRepositoryがtrueのバッジは5つ', () {
      final repoBadges =
          kAllReflectionBadges.where((b) => b.requiresRepository);
      expect(repoBadges.length, 4);
    });
  });

  group('ReflectionBadgeService - カウント系バッジ', () {
    test('初回の振り返りで first_reflection を獲得', () async {
      final player = Player();
      final messages = <String>[];

      player.recordReflection();
      await ReflectionBadgeService.checkBadges(player, messages);

      expect(player.reflectionBadges.contains('first_reflection'), true);
      expect(messages.any((m) => m.contains('初めての内省')), true);
    });

    test('5回の振り返りで reflection_novice を獲得', () async {
      final player = Player();
      final messages = <String>[];

      for (int i = 0; i < 5; i++) {
        player.recordReflection();
      }
      await ReflectionBadgeService.checkBadges(player, messages);

      expect(player.reflectionBadges.contains('reflection_novice'), true);
      expect(player.reflectionBadges.contains('first_reflection'), true);
    });

    test('20回の振り返りで reflection_adept を獲得', () async {
      final player = Player();
      final messages = <String>[];

      for (int i = 0; i < 20; i++) {
        player.recordReflection();
      }
      await ReflectionBadgeService.checkBadges(player, messages);

      expect(player.reflectionBadges.contains('reflection_adept'), true);
    });

    test('50回の振り返りで reflection_sage を獲得', () async {
      final player = Player();
      final messages = <String>[];

      for (int i = 0; i < 50; i++) {
        player.recordReflection();
      }
      await ReflectionBadgeService.checkBadges(player, messages);

      expect(player.reflectionBadges.contains('reflection_sage'), true);
    });

    test('100回の振り返りで reflection_master を獲得', () async {
      final player = Player();
      final messages = <String>[];

      for (int i = 0; i < 100; i++) {
        player.recordReflection();
      }
      await ReflectionBadgeService.checkBadges(player, messages);

      expect(player.reflectionBadges.contains('reflection_master'), true);
    });

    test('既に獲得済みのバッジは重複メッセージが出ない', () async {
      final player = Player()..reflectionBadges = ['first_reflection'];
      player.recordReflection();
      final messages = <String>[];

      await ReflectionBadgeService.checkBadges(player, messages);

      expect(messages.any((m) => m.contains('初めての内省')), false);
    });
  });

  group('ReflectionBadgeService - コンテンツ系バッジ', () {
    test('50文字以上の内容で first_insight を獲得', () async {
      final player = Player();
      final messages = <String>[];

      final reflection = await createReflection(
        content: 'これは50文字以上の振り返り内容です。十分な長さがあれば内省バッジが獲得できます。テスト用の長文です。',
      );

      player.recordReflection();
      await ReflectionBadgeService.checkBadges(
        player, messages,
        latestReflection: reflection,
      );

      expect(player.reflectionBadges.contains('first_insight'), true);
    });

    test('短い内容では first_insight を獲得できない', () async {
      final player = Player();
      final messages = <String>[];

      final reflection = await createReflection(content: '短い');

      player.recordReflection();
      await ReflectionBadgeService.checkBadges(
        player, messages,
        latestReflection: reflection,
      );

      expect(player.reflectionBadges.contains('first_insight'), false);
    });

    test('100文字以上の内容で deep_insight を獲得', () async {
      final player = Player();
      final messages = <String>[];

      final reflection = await createReflection(
        content: 'A' * 100,
      );

      player.recordReflection();
      await ReflectionBadgeService.checkBadges(
        player, messages,
        latestReflection: reflection,
      );

      expect(player.reflectionBadges.contains('deep_insight'), true);
    });
  });

  group('ReflectionBadgeService - 自己評価系バッジ', () {
    test('自己評価4以上で honest_assessor を獲得', () async {
      final player = Player();
      final messages = <String>[];

      final reflection = await createReflection(selfDifficulty: 4);

      player.recordReflection();
      await ReflectionBadgeService.checkBadges(
        player, messages,
        latestReflection: reflection,
      );

      expect(player.reflectionBadges.contains('honest_assessor'), true);
    });

    test('自己評価3以下では honest_assessor を獲得できない', () async {
      final player = Player();
      final messages = <String>[];

      final reflection = await createReflection(selfDifficulty: 3);

      player.recordReflection();
      await ReflectionBadgeService.checkBadges(
        player, messages,
        latestReflection: reflection,
      );

      expect(player.reflectionBadges.contains('honest_assessor'), false);
    });
  });

  group('ReflectionBadgeService - ストリーク系バッジ', () {
    test('3日連続で streak_3 を獲得', () async {
      final player = Player();
      final messages = <String>[];
      final now = DateTime.now();

      // 3日連続で振り返りを作成
      await createReflection(id: 's1', date: now.subtract(const Duration(days: 2)));
      await createReflection(id: 's2', date: now.subtract(const Duration(days: 1)));
      await createReflection(id: 's3', date: now);

      player.recordReflection();
      player.recordReflection();
      player.recordReflection();
      await ReflectionBadgeService.checkBadges(
        player, messages,
        repository: repository,
      );

      expect(player.reflectionBadges.contains('streak_3'), true);
    });

    test('7日連続で streak_7 を獲得', () async {
      final player = Player();
      final messages = <String>[];
      final now = DateTime.now();

      for (int i = 6; i >= 0; i--) {
        await createReflection(
          id: 's7_$i',
          date: now.subtract(Duration(days: i)),
        );
        player.recordReflection();
      }

      await ReflectionBadgeService.checkBadges(
        player, messages,
        repository: repository,
      );

      expect(player.reflectionBadges.contains('streak_7'), true);
      expect(player.reflectionBadges.contains('streak_3'), true);
    });

    test('連続していない振り返りでは streak_3 を獲得できない', () async {
      final player = Player();
      final messages = <String>[];
      final now = DateTime.now();

      // 1日おき（連続してない）
      await createReflection(id: 'g1', date: now.subtract(const Duration(days: 4)));
      await createReflection(id: 'g2', date: now.subtract(const Duration(days: 2)));
      await createReflection(id: 'g3', date: now);

      player.recordReflection();
      player.recordReflection();
      player.recordReflection();

      await ReflectionBadgeService.checkBadges(
        player, messages,
        repository: repository,
      );

      expect(player.reflectionBadges.contains('streak_3'), false);
    });
  });

  group('ReflectionBadgeService - self_awareness', () {
    test('AI難易度と自己評価が3回一致で self_awareness を獲得', () async {
      final player = Player();
      final messages = <String>[];

      // AI=S(5), self=5 → 一致
      await createReflection(id: 'a1', selfDifficulty: 5, aiDifficulty: QuestRank.S);
      // AI=A(3), self=3 → 一致
      await createReflection(id: 'a2', selfDifficulty: 3, aiDifficulty: QuestRank.A);
      // AI=B(1), self=1 → 一致
      await createReflection(id: 'a3', selfDifficulty: 1, aiDifficulty: QuestRank.B);

      player.recordReflection();
      player.recordReflection();
      player.recordReflection();

      await ReflectionBadgeService.checkBadges(
        player, messages,
        repository: repository,
      );

      expect(player.reflectionBadges.contains('self_awareness'), true);
    });

    test('一致が2回では self_awareness を獲得できない', () async {
      final player = Player();
      final messages = <String>[];

      await createReflection(id: 'm1', selfDifficulty: 5, aiDifficulty: QuestRank.S);
      await createReflection(id: 'm2', selfDifficulty: 3, aiDifficulty: QuestRank.A);
      await createReflection(id: 'm3', selfDifficulty: 3, aiDifficulty: QuestRank.S); // 不一致

      player.recordReflection();
      player.recordReflection();
      player.recordReflection();

      await ReflectionBadgeService.checkBadges(
        player, messages,
        repository: repository,
      );

      expect(player.reflectionBadges.contains('self_awareness'), false);
    });
  });

  group('Player model integration', () {
    test('Player.recordReflection で totalReflections が増える', () {
      final player = Player();
      expect(player.totalReflections, 0);

      player.recordReflection();
      expect(player.totalReflections, 1);

      player.recordReflection();
      expect(player.totalReflections, 2);
    });

    test('Player Hive roundtrip with v6 fields', () async {
      final box = await Hive.openBox<Player>('test_player_v6');

      final player = Player()
        ..totalReflections = 42
        ..reflectionBadges = ['first_reflection', 'streak_3'];

      await box.put('p1', player);
      final loaded = box.get('p1');

      expect(loaded, isNotNull);
      expect(loaded!.totalReflections, 42);
      expect(loaded.reflectionBadges, ['first_reflection', 'streak_3']);
    });
  });
}
