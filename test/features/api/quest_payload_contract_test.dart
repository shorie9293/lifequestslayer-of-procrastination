import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// API が書く `rpg_tasks.data` を、アプリの `Task.fromJson` が読めることの担保。
///
/// `Task.fromJson` は status / isCompleted / rank / repeatInterval を非nullで読む。
/// 1キーでも欠けると読込が例外になり、同期がクラウド側を取りこぼしたまま
/// 書き戻す事故につながるため、API の出力形はここで契約として固定する。
void main() {
  const fixturePath = 'supabase/functions/api/__fixtures__/quest_data_v1.json';

  late Map<String, dynamic> fixture;

  setUpAll(() {
    final file = File(fixturePath);
    expect(file.existsSync(), isTrue,
        reason: '契約フィクスチャが見つかりません: $fixturePath');
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  group('API v1 契約', () {
    test('フィクスチャは Task.fromJson で読める', () {
      final task = Task.fromJson(Map<String, dynamic>.from(fixture)
        ..remove('_comment'));

      expect(task.id, '3f9a1c2e-7b4d-4e8f-9a0b-1c2d3e4f5a6b');
      expect(task.title, '確定申告の書類を揃える');
      expect(task.status, TaskStatus.inGuild);
      expect(task.isCompleted, isFalse);
      expect(task.rank, QuestRank.A);
      expect(task.repeatInterval, RepeatInterval.none);
      expect(task.targetTimeMinutes, 60);
      expect(task.deadline, DateTime(2026, 11, 10, 17));
      expect(task.tags, <String>['手続き', 'API']);
      expect(task.subTasks.single.title, '源泉徴収票を印刷');
      expect(task.subTasks.single.isCompleted, isFalse);
      expect(task.enemyAssetPath, isNull);
      expect(task.enemyXpMultiplier, 1.0);
      expect(task.cancelledAt, isNull);
    });

    test('期限はローカル時刻として復元される（JST naive 前提）', () {
      final task = Task.fromJson(Map<String, dynamic>.from(fixture)
        ..remove('_comment'));

      // 表示（overview_service）は deadline.day / hour を toLocal() 無しで使う。
      // ここが UTC になると画面が9時間ズレる。
      expect(task.deadline!.isUtc, isFalse);
      expect(task.deadline!.hour, 17);
      expect(task.deadline!.day, 10);
    });

    test('API が埋めるべきキーがフィクスチャに揃っている', () {
      const required = <String>[
        'id',
        'title',
        'status',
        'isCompleted',
        'rank',
        'repeatInterval',
        'repeatWeekdays',
        'lastCompletedAt',
        'subTasks',
        'targetTimeMinutes',
        'activeAt',
        'deadline',
        'repeatAfterDays',
        'tags',
        'cancelledAt',
        'enemyAssetPath',
        'enemyXpMultiplier',
        'updatedAt',
      ];
      for (final key in required) {
        expect(fixture.containsKey(key), isTrue,
            reason: 'API の出力に $key が無い（アプリの読込が壊れる）');
      }
    });

    test('Task.toJson は fromJson が要求するキーを全て含む（往復可能）', () {
      final task = Task(id: 't1', title: '往復');
      final json = task.toJson();

      final restored = Task.fromJson(Map<String, dynamic>.from(json));
      expect(restored.id, 't1');
      expect(restored.title, '往復');
      expect(restored.status, TaskStatus.inGuild);
      expect(restored.isCompleted, isFalse);
      expect(restored.rank, QuestRank.B);
      expect(restored.repeatInterval, RepeatInterval.none);
    });
  });
}
