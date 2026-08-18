import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/core/utils/event_bus.dart';

/// イベントバスで配送されるテスト用イベント（プレイヤー関連）。
class _PlayerEvent {
  const _PlayerEvent(this.id);
  final String id;
}

/// イベントバスで配送されるテスト用イベント（タスク関連）。
class _TaskEvent {
  const _TaskEvent(this.count);
  final int count;
}

void main() {
  setUp(() {
    // 各テストを独立させるためシングルトンを初期化し直す。
    EventBus.resetForTesting();
  });

  group('EventBus 基本配送', () {
    test('型別購読で正しい型のイベントのみ受信する', () {
      final bus = EventBus();
      final players = <_PlayerEvent>[];
      bus.on<_PlayerEvent>().listen(players.add);

      bus.emit(const _PlayerEvent('hero'));

      expect(players, hasLength(1));
      expect(players.single.id, 'hero');
    });

    test('異なる型のイベントは別々の購読者に配送される', () {
      final bus = EventBus();
      final players = <_PlayerEvent>[];
      final tasks = <_TaskEvent>[];
      bus.on<_PlayerEvent>().listen(players.add);
      bus.on<_TaskEvent>().listen(tasks.add);

      bus.emit(const _TaskEvent(3));
      bus.emit(const _PlayerEvent('mage'));

      expect(players, hasLength(1));
      expect(players.single.id, 'mage');
      expect(tasks, hasLength(1));
      expect(tasks.single.count, 3);
    });

    test('emitは同期購読者に即時配送される', () {
      final bus = EventBus();
      var count = 0;
      bus.on<int>().listen((_) => count++);

      bus.emit(1);
      bus.emit(2);

      // 同期のため emit 直後に反映されている。
      expect(count, 2);
    });

    test('購読解除（cancel）後にイベントが配送されない', () async {
      final bus = EventBus();
      var count = 0;
      final sub = bus.on<String>().listen((_) => count++);

      await sub.cancel();
      bus.emit('x');

      expect(count, 0);
    });

    test('複数購読者が全てイベントを受信する', () {
      final bus = EventBus();
      var a = 0;
      var b = 0;
      bus.on<int>().listen((_) => a++);
      bus.on<int>().listen((_) => b++);

      bus.emit(7);

      expect(a, 1);
      expect(b, 1);
    });

    test('イベントの値が正しく受け渡される', () {
      final bus = EventBus();
      final values = <String>[];
      bus.on<String>().listen(values.add);

      bus.emit('first');
      bus.emit('second');

      expect(values, ['first', 'second']);
    });

    test('購読していない型のイベントは受信しない', () {
      final bus = EventBus();
      final tasks = <_TaskEvent>[];
      bus.on<_TaskEvent>().listen(tasks.add);

      bus.emit(const _PlayerEvent('x'));

      expect(tasks, isEmpty);
    });
  });

  group('EventBus ライフサイクル・シングルトン', () {
    test('EventBus.instance は同一シングルトンインスタンスを返す', () {
      expect(identical(EventBus.instance, EventBus.instance), isTrue);
      // ファクトリ経由でも同一インスタンスが得られる。
      expect(identical(EventBus(), EventBus.instance), isTrue);
    });

    test('close後にemitすると StateError になる', () async {
      final bus = EventBus();
      await bus.close();

      expect(() => bus.emit('x'), throwsStateError);
    });

    test('StreamSubscription.cancel後は以降のイベントを受信しない', () async {
      final bus = EventBus();
      var count = 0;
      final sub = bus.on<String>().listen((_) => count++);

      bus.emit('a');
      expect(count, 1);

      await sub.cancel();
      bus.emit('b');

      expect(count, 1);
    });
  });

  group('EventBus DI', () {
    test('getItから EventBus.instance と同じインスタンスが取得できる', () async {
      await GetIt.instance.reset();
      configureDependencies();

      final fromDi = getIt<EventBus>();

      expect(identical(fromDi, EventBus.instance), isTrue);

      await GetIt.instance.reset();
    });
  });
}
