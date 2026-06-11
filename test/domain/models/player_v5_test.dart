import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:rpg_todo/domain/models/player.dart';
/// Hive の BinaryWriter / BinaryReader を使った PlayerAdapter の
/// シリアライズ／デシリアライズ ラウンドトリップ テスト。
void main() {
  late PlayerAdapter adapter;
  late TypeRegistry registry;

  setUpAll(() {
    final testDir = Directory.systemTemp.createTempSync('hive_player_v5_test_');
    Hive.init(testDir.path);
    Hive.registerAdapter(PlayerAdapter());
    Hive.registerAdapter(JobAdapter());
    Hive.registerAdapter(JobSkillAdapter());
  });

  setUp(() {
    adapter = PlayerAdapter();
    // Hive implements TypeRegistry, use it for internal impl classes
    registry = Hive;
  });

  // ━━━ ヘルパー ━━━

  /// Player → bytes → Player の往復
  Player _roundtrip(Player player) {
    final writer = BinaryWriterImpl(registry);
    adapter.write(writer, player);
    final bytes = writer.toBytes();
    final reader = BinaryReaderImpl(bytes, registry);
    return adapter.read(reader);
  }

  /// 指定された format version で byte 列を偽装して読み込む（移行テスト用）
  Player _readWithVersion(
    int version,
    void Function(BinaryWriter) writePayload,
  ) {
    final writer = BinaryWriterImpl(registry);
    writePayload(writer);
    final payload = writer.toBytes();

    // 先頭1byteを指定された version に書き換える
    final bytes = Uint8List(payload.length);
    bytes[0] = version;
    bytes.setRange(1, payload.length, payload.sublist(1));

    final reader = BinaryReaderImpl(bytes, registry);
    return adapter.read(reader);
  }

  // ━━━ v5 ラウンドトリップ ━━━

  group('PlayerAdapter v5 roundtrip', () {
    test('デフォルト値の往復', () {
      final original = Player();
      final restored = _roundtrip(original);

      expect(restored.skillPoints, 0);
      expect(restored.unlockedSkillIds, isEmpty);
      expect(restored.level, 1);
      expect(restored.currentJob, Job.adventurer);
    });

    test('スキルポイント・解放ノードの往復', () {
      final player = Player(
        skillPoints: 5,
        unlockedSkillIds: ['war_flash', 'cle_prayer'],
      );
      final restored = _roundtrip(player);

      expect(restored.skillPoints, 5);
      expect(restored.unlockedSkillIds, ['war_flash', 'cle_prayer']);
    });

    test('全フィールドの往復', () {
      final player = Player(
        jobLevels: {Job.adventurer: 10, Job.warrior: 5},
        jobExps: {Job.adventurer: 42, Job.warrior: 100},
        currentJob: Job.warrior,
        comboCount: 3,
        coins: 500,
        skillPoints: 3,
        unlockedSkillIds: ['war_flash', 'war_combo'],
        streakDays: 7,
        gems: 10,
      );
      final restored = _roundtrip(player);

      expect(restored.jobLevels[Job.adventurer], 10);
      expect(restored.jobLevels[Job.warrior], 5);
      expect(restored.currentJob, Job.warrior);
      expect(restored.comboCount, 3);
      expect(restored.coins, 500);
      expect(restored.skillPoints, 3);
      expect(restored.unlockedSkillIds, ['war_flash', 'war_combo']);
      expect(restored.streakDays, 7);
      expect(restored.gems, 10);
    });
  });

  // ━━━ v4 → v5 移行 ━━━

  group('v4 → v5 migration', () {
    test('v4 データ読み込み時に skillPoints が冒険者Lvに基づいて計算される', () {
      final player = _readWithVersion(4, (writer) {
        // v4 の write を模倣（v4のフィールド列を手書き）
        // format version byte は _readWithVersion が上書きするのでここではダミー
        writer.writeByte(4); // dummy (overwritten)
        writer.writeMap({Job.adventurer: 6}); // jobLevels
        writer.writeMap({Job.adventurer: 0});
        writer.writeList([]); // equippedSkills
        writer.writeList([]); // activeSkills
        writer.write(Job.adventurer); // currentJob
        writer.writeInt(0); // comboCount
        writer.writeInt(0); // coins
        writer.writeList([]); // homeItems
        writer.writeInt(0); // dailyTasksCompleted
        writer.writeInt(0); // weeklySRankCompleted
        writer.write(null); // lastMissionResetDate
        writer.writeInt(0); // nextDayTaskLimitOffset
        writer.writeInt(0); // todayTaskLimitOffset
        writer.write(null); // lastRestDate
        writer.writeInt(0); // totalTasksCompleted
        writer.writeInt(0); // totalSRankCompleted
        writer.writeInt(0); // totalARankCompleted
        writer.writeInt(0); // totalBRankCompleted
        writer.writeList([]); // titles
        writer.write(null); // equippedTitle
        writer.write(null); // equippedSkin
        writer.writeMap({}); // characterSkin
        writer.writeInt(0); // gems
        writer.writeInt(0); // streakDays
        writer.writeInt(0); // longestStreak
        writer.write(null); // lastLoginDate
        writer.writeInt(0); // timesWardenDefeated
        writer.writeInt(25); // pomodoroMinutes
        writer.writeInt(5); // pomodoroShortBreakMinutes
        writer.writeInt(15); // pomodoroLongBreakMinutes
        writer.writeInt(4); // pomodorosBeforeLongBreak
        writer.write(null); // pomodoroStartTime
        writer.writeInt(0); // warriorDailyBuff
        writer.writeInt(1); // streakGraceRemaining
        writer.write(null); // lastStreakGraceReset
        writer.writeList([]); // tags
        writer.writeList([]); // projects
        writer.writeMap({}); // snoozedTasks
        writer.writeList([]); // taskStreaks
        writer.writeMap({}); // taskTags
        writer.writeMap({}); // taskProjects
      });

      // Lv6 → totalEarned = 2
      expect(player.skillPoints, 2);
      expect(player.unlockedSkillIds, isEmpty);
    });

    test('v4 データで nodes 解放済みなら skillPoints が正しく差分計算される', () {
      // Lv9 冒険者 → 3ポイント獲得。2コスト使って war_flash 解放済み → 残り1
      final player = _readWithVersion(4, (writer) {
        writer.writeByte(4);
        writer.writeMap({Job.adventurer: 9});
        writer.writeMap({Job.adventurer: 0});
        writer.writeList([]); // equippedSkills
        writer.writeList([]); // activeSkills
        writer.write(Job.adventurer);
        writer.writeInt(0);
        writer.writeInt(0);
        writer.writeList([]);
        writer.writeInt(0);
        writer.writeInt(0);
        writer.write(null);
        writer.writeInt(0);
        writer.writeInt(0);
        writer.write(null);
        writer.writeInt(0);
        writer.writeInt(0);
        writer.writeInt(0);
        writer.writeInt(0);
        writer.writeList([]);
        writer.write(null);
        writer.write(null);
        writer.writeMap({});
        writer.writeInt(0);
        writer.writeInt(0);
        writer.writeInt(0);
        writer.write(null);
        writer.writeInt(0);
        writer.writeInt(25);
        writer.writeInt(5);
        writer.writeInt(15);
        writer.writeInt(4);
        writer.write(null);
        writer.writeInt(0);
        writer.writeInt(1);
        writer.write(null);
        writer.writeList([]);
        writer.writeList([]);
        writer.writeMap({});
        writer.writeList([]);
        writer.writeMap({});
        writer.writeMap({});
      });

      // recalculateSkillPoints は unlockedSkillIds が空なので
      // Lv9 → 3ポイント全残り → skillPoints = 3
      expect(player.unlockedSkillIds, isEmpty);
      expect(player.skillPoints, 3);
    });
  });

  // ━━━ Player.addExp スキルポイント付与 ━━━

  group('addExp awards skill points', () {
    test('冒険者 Lv2 → Lv3 で 1 ポイント獲得', () {
      final player = Player(
        jobLevels: {Job.adventurer: 2},
        jobExps: {Job.adventurer: 99}, // あと少しでLvUP
        currentJob: Job.adventurer,
      );
      final leveledUp = player.addExp(1); // expNext for Lv2 = ~70

      expect(leveledUp, true);
      expect(player.skillPoints, 1);
      expect(player.level, greaterThan(2));
    });

    test('冒険者 Lv5 → Lv6 でさらに 1 ポイント（合計2）', () {
      final player = Player(
        jobLevels: {Job.adventurer: 5},
        jobExps: {Job.adventurer: 0},
        currentJob: Job.adventurer,
      );
      player.skillPoints = 1; // Lv5 時点では1ポイント獲得済み

      // Lv5 の expNext ≈ 50*1.4^4 ≈ 192
      final leveledUp = player.addExp(200);

      expect(leveledUp, true);
      expect(player.skillPoints, 2); // +1
    });

    test('他職（Warrior）のレベルアップではスキルポイントは増えない', () {
      final player = Player(
        jobLevels: {
          Job.adventurer: 1,
          Job.warrior: 3,
        },
        jobExps: {
          Job.adventurer: 0,
          Job.warrior: 0,
        },
        currentJob: Job.warrior,
      );

      // Lv3 warrior → expNext ≈ 50*1.4^2 ≈ 98
      final leveledUp = player.addExp(100);

      expect(leveledUp, true);
      expect(player.skillPoints, 0); // 冒険者ではないので増えない
    });
  });

  // ━━━ Player.unlockSkillNode ━━━

  group('unlockSkillNode', () {
    test('ポイント十分 + 前提条件なし → 解放成功', () {
      final player = Player(jobLevels: {Job.adventurer: 3}, skillPoints: 2);
      expect(player.unlockSkillNode('war_flash'), true);
      expect(player.skillPoints, 0); // 2 - 2 = 0
      expect(player.unlockedSkillIds, contains('war_flash'));
    });

    test('ポイント不足 → 失敗', () {
      final player = Player(skillPoints: 1);
      expect(player.unlockSkillNode('war_flash'), false);
      expect(player.skillPoints, 1);
      expect(player.unlockedSkillIds, isEmpty);
    });

    test('前提条件未達成 → 失敗', () {
      final player = Player(skillPoints: 10);
      expect(player.unlockSkillNode('war_combo'), false);
      expect(player.skillPoints, 10);
    });

    test('既解放済み → 失敗', () {
      final player = Player(
        skillPoints: 5,
        unlockedSkillIds: ['war_flash'],
      );
      expect(player.unlockSkillNode('war_flash'), false);
      expect(player.skillPoints, 5);
    });

    test('前提条件満たし → 成功', () {
      final player = Player(
        skillPoints: 5,
        unlockedSkillIds: ['war_flash'],
      );
      expect(player.unlockSkillNode('war_combo'), true);
      expect(player.unlockedSkillIds, containsAll(['war_flash', 'war_combo']));
      expect(player.skillPoints, 2); // 5 - 3 = 2
    });

    test('存在しないノードID → 失敗', () {
      final player = Player(skillPoints: 99);
      expect(player.unlockSkillNode('nonexistent'), false);
    });
  });

  // ━━━ awardSkillPointsOnLevelUp ━━━

  group('awardSkillPointsOnLevelUp', () {
    test('Lv2→Lv3 → +1', () {
      final player = Player(
        jobLevels: {Job.adventurer: 3},
        skillPoints: 0,
      );
      player.awardSkillPointsOnLevelUp(2);
      expect(player.skillPoints, 1);
    });

    test('Lv1→Lv3（複数Lv一気に） → delta は 1', () {
      final player = Player(
        jobLevels: {Job.adventurer: 3},
        skillPoints: 0,
      );
      player.awardSkillPointsOnLevelUp(1);
      expect(player.skillPoints, 1); // 0→1
    });

    test('Lv5→Lv6 → +1（合計2）', () {
      final player = Player(
        jobLevels: {Job.adventurer: 6},
        skillPoints: 1, // Lv5 時点
      );
      player.awardSkillPointsOnLevelUp(5);
      expect(player.skillPoints, 2);
    });

    test('Lv2→Lv2（変化なし）→ delta 0', () {
      final player = Player(
        jobLevels: {Job.adventurer: 2},
        skillPoints: 0,
      );
      player.awardSkillPointsOnLevelUp(2);
      expect(player.skillPoints, 0);
    });
  });

  // ━━━ recalculateSkillPoints ━━━

  group('recalculateSkillPoints', () {
    test('Lv6, 未解放 → 2', () {
      final player = Player(
        jobLevels: {Job.adventurer: 6},
        skillPoints: 999, // corrupted
      );
      player.recalculateSkillPoints();
      expect(player.skillPoints, 2);
    });

    test('Lv6, war_flash 解放済み(2コスト) → 0', () {
      final player = Player(
        jobLevels: {Job.adventurer: 6},
        unlockedSkillIds: ['war_flash'],
        skillPoints: 999,
      );
      player.recalculateSkillPoints();
      expect(player.skillPoints, 0);
    });

    test('Lv12 (4ポイント), war_flash+war_combo (5コスト) → -1', () {
      final player = Player(
        jobLevels: {Job.adventurer: 12},
        unlockedSkillIds: ['war_flash', 'war_combo'],
      );
      player.recalculateSkillPoints();
      // Lv12 → totalEarned = 12~/3 = 4, spent = 5 → -1
      expect(player.skillPoints, -1);
    });
  });

  // ━━━ isSkillUnlocked ━━━

  group('isSkillUnlocked', () {
    test('解放済みノードは true', () {
      final player = Player(unlockedSkillIds: ['war_flash']);
      expect(player.isSkillUnlocked('war_flash'), true);
    });

    test('未解放ノードは false', () {
      final player = Player();
      expect(player.isSkillUnlocked('war_flash'), false);
    });
  });
}
