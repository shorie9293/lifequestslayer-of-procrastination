import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status.dart';

/// 連携状態の保存先。
abstract class ICrossAppLinkStatusStore {
  Future<CrossAppLinkSnapshot> load();

  Future<void> save(CrossAppLinkSnapshot snapshot);
}

/// 端末に保存する実装（再起動を跨いで「最後の送信／受信」を残す）。
class SharedPreferencesCrossAppLinkStatusStore
    implements ICrossAppLinkStatusStore {
  const SharedPreferencesCrossAppLinkStatusStore();

  static const String prefsKey = 'cross_app_link_status_v1';

  @override
  Future<CrossAppLinkSnapshot> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return CrossAppLinkSnapshot.decode(prefs.getString(prefsKey));
    } on Object {
      return CrossAppLinkSnapshot.empty;
    }
  }

  @override
  Future<void> save(CrossAppLinkSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, snapshot.encode());
    } on Object {
      // 保存の失敗は本処理を止めない（状態はメモリ側に残る）。
    }
  }
}

/// 試練用のメモリ実装。
class InMemoryCrossAppLinkStatusStore implements ICrossAppLinkStatusStore {
  InMemoryCrossAppLinkStatusStore([CrossAppLinkSnapshot? initial])
      : _snapshot = initial ?? CrossAppLinkSnapshot.empty;

  CrossAppLinkSnapshot _snapshot;

  /// 保存が呼ばれた回数（試練の観測用）。
  int saveCount = 0;

  /// true にすると保存が失敗する（握り潰しの検証用）。
  bool throwOnSave = false;

  @override
  Future<CrossAppLinkSnapshot> load() async => _snapshot;

  @override
  Future<void> save(CrossAppLinkSnapshot snapshot) async {
    if (throwOnSave) throw StateError('save failed');
    _snapshot = snapshot;
    saveCount++;
  }
}

/// 送受信の記録口。**送受信の経路はここだけを呼ぶ**。
///
/// 契約:
/// - どのメソッドも**絶対に throw しない**（記録の失敗で本処理を止めない）
/// - 書込は直列化する（同時送信で記録を取りこぼさない）
/// - 初回の記録前に保存済みの状態を読み込む（前回起動分を消さない）
class CrossAppLinkStatusRecorder {
  CrossAppLinkStatusRecorder({
    ICrossAppLinkStatusStore? store,
    DateTime Function()? now,
  })  : _store = store ?? const SharedPreferencesCrossAppLinkStatusStore(),
        _now = now ?? DateTime.now;

  /// アプリ全体で共有する 1 つの記録口（試練では [reset] で差し替える）。
  static CrossAppLinkStatusRecorder instance = CrossAppLinkStatusRecorder();

  static void reset([CrossAppLinkStatusRecorder? recorder]) {
    instance = recorder ?? CrossAppLinkStatusRecorder();
  }

  final ICrossAppLinkStatusStore _store;
  final DateTime Function() _now;

  Future<void> _tail = Future<void>.value();
  CrossAppLinkSnapshot _cache = CrossAppLinkSnapshot.empty;
  bool _loaded = false;

  /// 直近の状態（同期的に読める）。
  CrossAppLinkSnapshot get cached => _cache;

  /// 保存済みの状態を読み込む。失敗しても空を返す（throw しない）。
  Future<CrossAppLinkSnapshot> load() async {
    try {
      _cache = await _store.load();
      _loaded = true;
    } on Object {
      _loaded = true;
    }
    return _cache;
  }

  Future<void> recordSent({int count = 1, String? fileName}) => _record(
        sent: true,
        ok: true,
        count: count,
        fileName: fileName,
        error: null,
      );

  Future<void> recordSendFailure(
    Object error, {
    int count = 0,
    String? fileName,
  }) =>
      _record(
        sent: true,
        ok: false,
        count: count,
        fileName: fileName,
        error: error.toString(),
      );

  Future<void> recordReceived({int count = 1, String? fileName}) => _record(
        sent: false,
        ok: true,
        count: count,
        fileName: fileName,
        error: null,
      );

  Future<void> recordReceiveFailure(
    Object error, {
    int count = 0,
    String? fileName,
  }) =>
      _record(
        sent: false,
        ok: false,
        count: count,
        fileName: fileName,
        error: error.toString(),
      );

  Future<void> recordFolderReady(bool ready) =>
      _mutate((s) => s.copyWith(sharedFolderReady: ready));

  Future<void> _record({
    required bool sent,
    required bool ok,
    required int count,
    String? fileName,
    String? error,
  }) {
    final record = CrossAppTransferRecord(
      at: _now(),
      ok: ok,
      count: count,
      fileName: fileName,
      error: error,
    );
    return _mutate(
      (s) => sent
          ? s.copyWith(lastSent: record)
          : s.copyWith(lastReceived: record),
    );
  }

  /// 直列化して書く。**絶対に throw しない**。
  Future<void> _mutate(
    CrossAppLinkSnapshot Function(CrossAppLinkSnapshot) transform,
  ) {
    final next = _tail.then((_) async {
      if (!_loaded) {
        try {
          _cache = await _store.load();
        } on Object {
          // 読めなければ空から始める。
        }
        _loaded = true;
      }
      final updated = transform(_cache);
      _cache = updated;
      try {
        await _store.save(updated);
      } on Object {
        // 保存失敗は握る（状態はメモリに残す）。
      }
    });
    _tail = next;
    return next;
  }
}
