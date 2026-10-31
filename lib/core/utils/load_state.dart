import 'package:flutter/foundation.dart';

/// 画面の読込状態を「読込中 / データあり / 0件 / 失敗」の4相で表す基盤。
///
/// 従来は `catch (_)` が失敗を既定値（空リスト・0・null）へ潰していたため、
/// 画面には「0件」として静かに表示され、創造主様は失敗に気づけなかった。
/// 本型は「0件（empty）」と「失敗（error）」を型で分離する。
enum LoadPhase { loading, data, empty, error }

/// 読込状態の不変オブジェクト。
///
/// 不正な引数（data に null / error に空メッセージ）は [ArgumentError] で弾く。
@immutable
class LoadState<T> {
  const LoadState._(
    this.phase,
    this._value,
    this._message,
    this._retryable,
    this._cause,
  );

  /// 読込中。
  factory LoadState.loading() =>
      const LoadState<Never>._(LoadPhase.loading, null, null, true, null)
          .cast<T>();

  /// データあり。
  factory LoadState.data(T value) {
    if (value == null) {
      throw ArgumentError.value(value, 'value', 'data には非null値が必要です');
    }
    return LoadState<T>._(LoadPhase.data, value, null, true, null);
  }

  /// 0件（失敗ではない）。
  factory LoadState.empty() =>
      const LoadState<Never>._(LoadPhase.empty, null, null, true, null)
          .cast<T>();

  /// 失敗。[retryable] が true のとき再試行導線を出してよい。
  factory LoadState.error(
    String message, {
    bool retryable = true,
    Object? cause,
  }) {
    if (message.isEmpty) {
      throw ArgumentError.value(message, 'message', 'error には文言が必要です');
    }
    return LoadState<T>._(LoadPhase.error, null, message, retryable, cause);
  }

  final LoadPhase phase;
  final T? _value;
  final String? _message;
  final bool _retryable;
  final Object? _cause;

  bool get isLoading => phase == LoadPhase.loading;
  bool get isData => phase == LoadPhase.data;
  bool get isEmpty => phase == LoadPhase.empty;
  bool get isError => phase == LoadPhase.error;

  /// データありのときのみ値を持つ。
  T? get valueOrNull => isData ? _value : null;

  /// 失敗のときのみ文言を持つ。
  String? get message => isError ? _message : null;

  bool get retryable => _retryable;

  Object? get cause => _cause;

  /// 4相を網羅的に分岐する。
  R when<R>({
    required R Function() loading,
    required R Function(T value) data,
    required R Function() empty,
    required R Function(String message, bool retryable) error,
  }) {
    switch (phase) {
      case LoadPhase.loading:
        return loading();
      case LoadPhase.data:
        return data(_value as T);
      case LoadPhase.empty:
        return empty();
      case LoadPhase.error:
        return error(_message ?? '', _retryable);
    }
  }

  /// 型引数だけ差し替える（内部用）。
  LoadState<R> cast<R>() => LoadState<R>._(
        phase,
        _value is R ? _value as R : null,
        _message,
        _retryable,
        _cause,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadState<T> &&
          other.phase == phase &&
          other._value == _value &&
          other._message == _message &&
          other._retryable == _retryable &&
          other._cause == _cause;

  @override
  int get hashCode => Object.hash(phase, _value, _message, _retryable, _cause);

  @override
  String toString() => switch (phase) {
        LoadPhase.loading => 'LoadState<$T>.loading()',
        LoadPhase.data => 'LoadState<$T>.data($_value)',
        LoadPhase.empty => 'LoadState<$T>.empty()',
        LoadPhase.error =>
          'LoadState<$T>.error($_message, retryable: $_retryable)',
      };
}

/// リポジトリ層の読込結果。「成功（0件を含む）」と「失敗」を分離する。
///
/// 既存メソッド（`load()` 等）は温存し、後方互換の `tryXxx` が本型を返す。
@immutable
class LoadResult<T> {
  const LoadResult._(this._value, this._message, this._retryable, this._cause);

  /// 成功（空リストも成功）。
  factory LoadResult.success(T value) {
    if (value == null) {
      throw ArgumentError.value(value, 'value', 'success には非null値が必要です');
    }
    return LoadResult<T>._(value, null, true, null);
  }

  /// 失敗。
  factory LoadResult.failure(
    String message, {
    bool retryable = true,
    Object? cause,
  }) {
    if (message.isEmpty) {
      throw ArgumentError.value(message, 'message', 'failure には文言が必要です');
    }
    return LoadResult<T>._(null, message, retryable, cause);
  }

  final T? _value;
  final String? _message;
  final bool _retryable;
  final Object? _cause;

  bool get isSuccess => _message == null;
  bool get isFailure => !isSuccess;

  T? get valueOrNull => _value;
  String? get message => _message;
  bool get retryable => _retryable;
  Object? get cause => _cause;

  R when<R>({
    required R Function(T value) success,
    required R Function(String message, bool retryable) failure,
  }) {
    if (isSuccess) return success(_value as T);
    return failure(_message ?? '', _retryable);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadResult<T> &&
          other._value == _value &&
          other._message == _message &&
          other._retryable == _retryable &&
          other._cause == _cause;

  @override
  int get hashCode => Object.hash(_value, _message, _retryable, _cause);

  @override
  String toString() => isSuccess
      ? 'LoadResult<$T>.success($_value)'
      : 'LoadResult<$T>.failure($_message, retryable: $_retryable)';
}
