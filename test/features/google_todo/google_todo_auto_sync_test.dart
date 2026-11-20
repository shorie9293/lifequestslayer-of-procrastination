import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/features/google_todo/data/google_todo_auto_sync.dart';
import 'package:rpg_todo/features/google_todo/data/google_todo_gateway.dart';
import 'package:rpg_todo/features/google_todo/domain/google_todo_status.dart';

class _FakeGateway implements GoogleTodoGateway {
  _FakeGateway({this.linked = true, this.failStatus = false, this.failSync = false});

  final bool linked;
  final bool failStatus;
  final bool failSync;
  int syncCalls = 0;

  @override
  Future<GoogleTodoStatus> fetchStatus() async {
    if (failStatus) throw const GoogleTodoException('取得失敗', statusCode: 500);
    return GoogleTodoStatus(linked: linked);
  }

  @override
  Future<GoogleTodoSyncResult> sync() async {
    syncCalls++;
    if (failSync) throw const GoogleTodoException('同期失敗', statusCode: 500);
    return const GoogleTodoSyncResult(pulled: 1, pushed: 1);
  }

  @override
  Future<String> startLink() async => 'https://example.com';
  @override
  Future<List<GoogleTodoList>> fetchLists() async => const <GoogleTodoList>[];
  @override
  Future<void> selectList({required String id, String? title}) async {}
  @override
  Future<void> unlink() async {}
}

void main() {
  test('連携済みなら起動時に1回同期する', () async {
    final gateway = _FakeGateway();
    final result = await GoogleTodoAutoSync(gateway: gateway).runOnce();
    expect(gateway.syncCalls, 1);
    expect(result!.pulled, 1);
  });

  test('未連携なら同期しない', () async {
    final gateway = _FakeGateway(linked: false);
    final result = await GoogleTodoAutoSync(gateway: gateway).runOnce();
    expect(gateway.syncCalls, 0);
    expect(result, isNull);
  });

  test('失敗しても起動を妨げない（nullを返す）', () async {
    expect(await GoogleTodoAutoSync(gateway: _FakeGateway(failStatus: true)).runOnce(), isNull);
    final gw = _FakeGateway(failSync: true);
    expect(await GoogleTodoAutoSync(gateway: gw).runOnce(), isNull);
    expect(gw.syncCalls, 1);
  });
}
