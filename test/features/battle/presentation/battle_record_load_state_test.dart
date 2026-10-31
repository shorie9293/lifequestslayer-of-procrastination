import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/utils/load_state.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/presentation/battle_record_screen.dart';

BattleRecord _rec(String id, String title) => BattleRecord(
      id: id,
      title: title,
      occurredAt: DateTime(2026, 10, 1, 10),
      isVictory: true,
      comboCount: 0,
      remainingSubTasks: 0,
    );

/// 呼出順に台本どおりの結果を返すリポジトリ（呼出回数を数える）。
class _ScriptedRepository implements BattleRecordRepository {
  _ScriptedRepository(this._script);

  final List<LoadResult<List<BattleRecord>>> _script;
  int calls = 0;

  @override
  Future<LoadResult<List<BattleRecord>>> tryLoad() async {
    final index = calls < _script.length ? calls : _script.length - 1;
    calls++;
    return _script[index];
  }

  @override
  Future<List<BattleRecord>> load() async =>
      (await tryLoad()).valueOrNull ?? const [];

  @override
  Future<void> add(BattleRecord record) async {}

  @override
  Future<void> clear() async {}
}

/// tryLoad 自体が例外を投げる最悪ケース。
class _ThrowingRepository implements BattleRecordRepository {
  @override
  Future<LoadResult<List<BattleRecord>>> tryLoad() async =>
      throw StateError('hive box is closed');

  @override
  Future<List<BattleRecord>> load() async => const [];

  @override
  Future<void> add(BattleRecord record) async {}

  @override
  Future<void> clear() async {}
}

Future<void> _pump(WidgetTester tester, BattleRecordRepository repo) async {
  await tester.pumpWidget(
    MaterialApp(home: BattleRecordScreen(repository: repo)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('読込失敗では ErrorView を出し、空状態は出さない', (tester) async {
    await _pump(
      tester,
      _ScriptedRepository([
        LoadResult<List<BattleRecord>>.failure('討伐戦績を読み込めませんでした'),
      ]),
    );
    expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
    expect(find.text('討伐戦績を読み込めませんでした'), findsOneWidget);
    expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
    expect(find.byKey(AppKeys.battleRecordEmpty), findsNothing);
    expect(find.byKey(AppKeys.battleRecordHistoryList), findsNothing);
  });

  testWidgets('0件では EmptyView を出し、ErrorView は出さない', (tester) async {
    await _pump(
      tester,
      _ScriptedRepository([
        LoadResult<List<BattleRecord>>.success(const []),
      ]),
    );
    expect(find.byKey(const ValueKey('load_empty_view')), findsOneWidget);
    expect(find.byKey(AppKeys.battleRecordEmpty), findsOneWidget);
    expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
    expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
  });

  testWidgets('再試行タップで2回目のロードが走り、成功で ErrorView が消える', (tester) async {
    final repo = _ScriptedRepository([
      LoadResult<List<BattleRecord>>.failure('討伐戦績を読み込めませんでした'),
      LoadResult<List<BattleRecord>>.success([_rec('a', '再試行クエスト')]),
    ]);
    await _pump(tester, repo);
    expect(repo.calls, 1);
    expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('load_retry_button')));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
    expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
    expect(find.text('再試行クエスト'), findsOneWidget);
  });

  testWidgets('失敗しても既存データを消さない（帯で知らせ一覧は残す）', (tester) async {
    await _pump(
      tester,
      _ScriptedRepository([
        LoadResult<List<BattleRecord>>.success([_rec('a', '既存クエスト')]),
      ]),
    );
    expect(find.text('既存クエスト'), findsOneWidget);

    await _pump(
      tester,
      _ScriptedRepository([
        LoadResult<List<BattleRecord>>.failure('討伐戦績を読み込めませんでした'),
      ]),
    );

    expect(find.text('既存クエスト'), findsOneWidget);
    expect(find.byKey(const ValueKey('load_error_banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('load_retry_button')), findsOneWidget);
  });

  testWidgets('retryable=false の失敗では再試行ボタンを出さない', (tester) async {
    await _pump(
      tester,
      _ScriptedRepository([
        LoadResult<List<BattleRecord>>.failure(
          '保存領域を開けませんでした',
          retryable: false,
        ),
      ]),
    );
    expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
    expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
  });

  testWidgets('リポジトリが例外を投げても ErrorView に落とす（クラッシュしない）', (tester) async {
    await _pump(tester, _ThrowingRepository());
    expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
    expect(find.byKey(AppKeys.battleRecordEmpty), findsNothing);
    expect(find.byKey(const ValueKey('load_retry_button')), findsOneWidget);
  });

  group('repository.tryLoad', () {
    test('InMemory 実装は成功として戦績を返す（既存 load と同値）', () async {
      final repo = InMemoryBattleRecordRepository();
      await repo.add(_rec('a', 'クエスト'));
      final result = await repo.tryLoad();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.length, 1);
      expect((await repo.load()).length, 1);
    });

    test('Noop 実装は「0件の成功」を返す（失敗ではない）', () async {
      final result = await NoopBattleRecordRepository().tryLoad();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('失敗実装は文言と再試行可否を保ったまま failure を返す', () async {
      final result = await _ScriptedRepository([
        LoadResult<List<BattleRecord>>.failure('読込失敗', retryable: false),
      ]).tryLoad();
      expect(result.isFailure, isTrue);
      expect(result.message, '読込失敗');
      expect(result.retryable, isFalse);
      expect(result.valueOrNull, isNull);
    });
  });
}
