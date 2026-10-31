import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/utils/load_state.dart';

void main() {
  group('LoadState', () {
    test('loading は読込中のみ true', () {
      final s = LoadState<List<int>>.loading();
      expect(s.isLoading, isTrue);
      expect(s.isData, isFalse);
      expect(s.isEmpty, isFalse);
      expect(s.isError, isFalse);
      expect(s.valueOrNull, isNull);
      expect(s.message, isNull);
    });

    test('data は値を持ち when が data 側へ分岐する', () {
      final s = LoadState<List<int>>.data(const [1, 2, 3]);
      expect(s.isData, isTrue);
      expect(s.valueOrNull, const [1, 2, 3]);
      expect(
        s.when(
          loading: () => 'loading',
          data: (v) => 'data:${v.length}',
          empty: () => 'empty',
          error: (m, r) => 'error:$m',
        ),
        'data:3',
      );
    });

    test('empty は失敗ではない（error と別相）', () {
      final s = LoadState<List<int>>.empty();
      expect(s.isEmpty, isTrue);
      expect(s.isError, isFalse);
      expect(s.valueOrNull, isNull);
      expect(
        s.when(
          loading: () => 'loading',
          data: (_) => 'data',
          empty: () => 'empty',
          error: (_, __) => 'error',
        ),
        'empty',
      );
    });

    test('error は文言・再試行可否・原因を保持し when が error 側へ分岐する', () {
      final cause = StateError('hive closed');
      final s = LoadState<List<int>>.error(
        '読み込めませんでした',
        retryable: false,
        cause: cause,
      );
      expect(s.isError, isTrue);
      expect(s.isEmpty, isFalse);
      expect(s.message, '読み込めませんでした');
      expect(s.retryable, isFalse);
      expect(s.cause, same(cause));
      expect(
        s.when(
          loading: () => 'loading',
          data: (_) => 'data',
          empty: () => 'empty',
          error: (m, r) => '$m/$r',
        ),
        '読み込めませんでした/false',
      );
    });

    test('等価性と hashCode は相・値・文言・再試行可否で決まる', () {
      expect(
        LoadState<List<int>>.data(const [1]),
        equals(LoadState<List<int>>.data(const [1])),
      );
      expect(
        LoadState<List<int>>.data(const [1]).hashCode,
        LoadState<List<int>>.data(const [1]).hashCode,
      );
      expect(
        LoadState<List<int>>.empty(),
        isNot(equals(LoadState<List<int>>.loading())),
      );
      expect(
        LoadState<List<int>>.error('失敗'),
        equals(LoadState<List<int>>.error('失敗')),
      );
      expect(
        LoadState<List<int>>.error('失敗'),
        isNot(equals(LoadState<List<int>>.error('失敗', retryable: false))),
      );
    });

    test('不正引数は ArgumentError', () {
      expect(
        () => LoadState<List<int>?>.data(null),
        throwsArgumentError,
      );
      expect(() => LoadState<List<int>>.error(''), throwsArgumentError);
    });
  });

  group('LoadResult', () {
    test('success は値を持ち failure ではない', () {
      final r = LoadResult<List<int>>.success(const [1, 2]);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.valueOrNull, const [1, 2]);
      expect(r.message, isNull);
      expect(
        r.when(success: (v) => v.length, failure: (_, __) => -1),
        2,
      );
    });

    test('空リストの success は「0件の成功」であり失敗ではない', () {
      final r = LoadResult<List<int>>.success(const <int>[]);
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull, isEmpty);
    });

    test('failure は文言・再試行可否・原因を保持する', () {
      final cause = Exception('boom');
      final r = LoadResult<List<int>>.failure(
        '取得に失敗しました',
        retryable: false,
        cause: cause,
      );
      expect(r.isFailure, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.valueOrNull, isNull);
      expect(r.message, '取得に失敗しました');
      expect(r.retryable, isFalse);
      expect(r.cause, same(cause));
      expect(
        r.when(success: (_) => 'ok', failure: (m, retry) => '$m/$retry'),
        '取得に失敗しました/false',
      );
    });

    test('等価性は値・文言・再試行可否で決まる', () {
      expect(
        LoadResult<List<int>>.success(const [1]),
        equals(LoadResult<List<int>>.success(const [1])),
      );
      expect(
        LoadResult<List<int>>.failure('失敗'),
        equals(LoadResult<List<int>>.failure('失敗')),
      );
      expect(
        LoadResult<List<int>>.failure('失敗'),
        isNot(equals(LoadResult<List<int>>.success(const []))),
      );
    });

    test('不正引数は ArgumentError', () {
      expect(
        () => LoadResult<List<int>?>.success(null),
        throwsArgumentError,
      );
      expect(() => LoadResult<List<int>>.failure(''), throwsArgumentError);
    });
  });
}
