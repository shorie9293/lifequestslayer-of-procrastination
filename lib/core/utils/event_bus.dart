import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// 型安全なアプリ内イベントバス。
///
/// [emit] でイベントを発行し、[on] で型別に購読する。購読者は
/// `on<T>().listen(...)` が返す [StreamSubscription] を `cancel` すること
/// で購読を解除できる（[StreamSubscription] は [StreamSubscription.cancel]
/// のほか [StreamSubscription.dispose] でも破棄可能）。
///
/// 内部は `StreamController.broadcast(sync: true)` を使用するため、
/// ・購読者へは emit と同期的に配送される
/// ・複数購読者がすべてイベントを受信できる
/// ・例外は購読者へ伝播する
/// ・[close] 後は [emit] が [StateError] を投げる
///
/// 依存性注入（get_it/injectable）では [@lazySingleton] として登録され、
/// `getIt<EventBus>()` と [EventBus.instance] は常に同一インスタンスになる。
@lazySingleton
class EventBus {
  EventBus._();

  static EventBus _instance = EventBus._();

  /// グローバルな単一インスタンス（サービスロケーター的簡易アクセス）。
  static EventBus get instance => _instance;

  /// DI（get_it/injectable）からも [instance] と同じインスタンスを返す。
  factory EventBus() => _instance;

  /// テスト等でシングルトンを初期化し直すためのフック。
  @visibleForTesting
  static void resetForTesting() {
    _instance = EventBus._();
  }

  final StreamController<Object?> _controller =
      StreamController<Object?>.broadcast(sync: true);

  /// 型 [T] のイベントを購読する。購読者は戻り値の [Stream] を
  /// `listen` して得られる [StreamSubscription] で購読を解除する。
  Stream<T> on<T>() => _controller.stream.where((e) => e is T).cast<T>();

  /// 型 [T] のイベントを発行する。全購読者へ同期的に配送される。
  void emit<T>(T event) => _controller.add(event);

  /// バスを閉じる。閉じた後は [emit] が [StateError] を投げる。
  Future<void> close() => _controller.close();

  /// バスが閉じているかどうか。
  bool get isClosed => _controller.isClosed;
}
