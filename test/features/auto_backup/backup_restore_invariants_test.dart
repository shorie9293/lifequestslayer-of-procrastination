import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/backup_registry.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/data/backup_restore_flow.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';

/// 自動バックアップ復元の不変条件（回帰試練）。
///
/// 背景: rpg-task の自動バックアップは [BackupBoxRegistry] の許可リスト経由で
/// 設定 box（settingsBox / notification_settings / crossAppSettings /
/// tutorialBox）も控えに載せ、復元で書き戻している。しかし
///   ① 設定 box が許可リストから外れても誰も気づかない
///   ② 設定（通知時刻）が戻っても通知が再予約されず鳴らない
/// という2点が未固定だった。本試練はその双方を固定する。
void main() {
  group('BackupBoxRegistry: 設定が控えに載る不変条件', () {
    test('設定系 box が許可リストに含まれる', () {
      final names = BackupBoxRegistry.boxNames;
      expect(names, contains('settingsBox'));
      expect(names, contains('notification_settings'));
      expect(names, contains('crossAppSettings'));
      expect(names, contains('tutorialBox'));
    });

    test('許可リストに app_lock 系の秘密 box を載せない', () {
      // 実測: app_lock の保存先は HiveAppLockRepository が使う 'settingsBox'
      // （キーは appLock.* 名前空間）。専用の秘密 box は存在しない。
      // ここでは「将来 registry に秘密専用 box が追加されないこと」を固定する。
      final secretLike = RegExp(
        r'app[_-]?lock|passcode|secret|credential|keystore|vault|token',
        caseSensitive: false,
      );
      final offenders =
          BackupBoxRegistry.boxNames.where(secretLike.hasMatch).toList();
      expect(offenders, isEmpty, reason: '秘密を含む box を控え対象にしてはならない: $offenders');
    });
  });

  group('復元後の通知再予約フック', () {
    String validJson() => FullBackupService().encode(
          player: Player(coins: 100),
          tasks: const <Task>[],
          boxes: {
            'notification_settings': {'enabled': true, 'morning_hour': 7},
            'settingsBox': {'fontSizeScale': 1.0},
          },
          exportedAt: DateTime(2026, 11, 9, 7),
        );

    test('復元成功後に onRestored が1回だけ呼ばれる', () async {
      var calls = 0;
      bool? restoredPlayerCalled;
      Map<String, Map<String, dynamic>>? restoredBoxes;

      await applyBackupJson(
        json: validJson(),
        restorePlayer: (_) => restoredPlayerCalled = true,
        setTasks: (_) {},
        restoreBoxes: (boxes) async => restoredBoxes = boxes,
        onRestored: () async => calls++,
      );

      expect(calls, 1);
      expect(restoredPlayerCalled, isTrue);
      expect(restoredBoxes, isNotNull);
      expect(restoredBoxes, contains('notification_settings'));
    });

    test('不正 JSON では onRestored を呼ばず FormatException', () async {
      var calls = 0;
      await expectLater(
        applyBackupJson(
          json: 'not json',
          restorePlayer: (_) {},
          setTasks: (_) {},
          restoreBoxes: (_) async {},
          onRestored: () async => calls++,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 0);
    });

    test('onRestored の例外は握る（復元自体は成功のまま）', () async {
      var boxWritten = false;
      await applyBackupJson(
        json: validJson(),
        restorePlayer: (_) {},
        setTasks: (_) {},
        restoreBoxes: (_) async => boxWritten = true,
        onRestored: () async => throw StateError('通知再予約に失敗'),
      );
      expect(boxWritten, isTrue);
    });

    test('AutoBackupRestorerImpl 経由でも再予約の失敗で ok:true のまま', () async {
      final json = validJson();
      final store = _MemoryStore({'auto_backup_20261108.json': json});
      var calls = 0;

      final restorer = AutoBackupRestorerImpl(
        store: store,
        buildCurrentJson: () async => json,
        applyBackup: (raw) => applyBackupJson(
          json: raw,
          restorePlayer: (_) {},
          setTasks: (_) {},
          restoreBoxes: (_) async {},
          onRestored: () async {
            calls++;
            throw StateError('通知再予約に失敗');
          },
        ),
        now: () => DateTime(2026, 11, 9),
      );

      final result = await restorer.restore('auto_backup_20261108.json');

      expect(calls, 1);
      expect(result.ok, isTrue);
      expect(result.safetyFileName, 'auto_backup_20261109.json');
    });
  });
}

/// 最小のインメモリ AutoBackupStore。
class _MemoryStore implements AutoBackupStore {
  _MemoryStore(this.files);

  final Map<String, String?> files;

  @override
  Future<List<AutoBackupEntry>> list() async => files.keys
      .map((name) => AutoBackupEntry(
            fileName: name,
            createdAt: DateTime(2026, 11, 8),
          ))
      .toList();

  @override
  Future<String?> read(String fileName) async => files[fileName];

  @override
  Future<void> write(String fileName, String json) async =>
      files[fileName] = json;

  @override
  Future<void> delete(String fileName) async => files.remove(fileName);
}
