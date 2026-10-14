import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/services/backup_registry.dart';
import 'package:rpg_todo/domain/services/reflection_backup_codec.dart';

/// 全データバックアップの Hive I/O 抽象。
///
/// capture: Hive box を Map 形式（boxName -> {key: JSON-safe 値}）で読み出す。
/// restore: Map 形式を Hive box へ書き戻す（許可リスト方式）。
abstract class BackupStorage {
  /// 許可リスト対象 box を全て読み出す。
  Future<Map<String, Map<String, dynamic>>> capture();

  /// 許可リスト内の box のみ復元する（許可リスト外は無視）。
  Future<void> restore(Map<String, Map<String, dynamic>> boxes);
}

/// Hive 実装（許可リスト方式）。
///
/// [boxOpener] を注入するとテストでフェイク Box を使える。
/// 既定は Hive のグローバルレジストリから取得 / openBox する。
class HiveBackupStorage implements BackupStorage {
  final Future<Box<dynamic>> Function(String name) _boxOpener;

  HiveBackupStorage({
    Future<Box<dynamic>> Function(String name)? boxOpener,
  }) : _boxOpener = boxOpener ??
            ((name) => Hive.isBoxOpen(name)
                ? Future.value(Hive.box<dynamic>(name))
                : Hive.openBox<dynamic>(name));

  @override
  Future<Map<String, Map<String, dynamic>>> capture() async {
    final result = <String, Map<String, dynamic>>{};
    for (final spec in BackupBoxRegistry.specs) {
      try {
        final box = await _boxOpener(spec.boxName);
        final entries = <String, dynamic>{};
        box.toMap().forEach((key, value) {
          if (key == null) return;
          switch (spec.kind) {
            case BackupBoxKind.jsonValue:
              final safe = _toJsonSafe(value);
              if (safe != _unsafeMarker) {
                entries[key.toString()] = safe;
              }
              break;
            case BackupBoxKind.reflectionObject:
              if (value is Reflection) {
                entries[key.toString()] = ReflectionBackupCodec.toMap(value);
              }
              break;
          }
        });
        result[spec.boxName] = entries;
      } catch (_) {
        // 開けない box はスキップ（例外を投げない）
      }
    }
    return result;
  }

  @override
  Future<void> restore(Map<String, Map<String, dynamic>> boxes) async {
    for (final entry in boxes.entries) {
      final spec = BackupBoxRegistry.specFor(entry.key);
      if (spec == null) continue; // 許可リスト外は無視
      try {
        final box = await _boxOpener(spec.boxName);
        await box.clear();
        final putEntries = <dynamic, dynamic>{};
        entry.value.forEach((key, value) {
          switch (spec.kind) {
            case BackupBoxKind.jsonValue:
              putEntries[key] = value;
              break;
            case BackupBoxKind.reflectionObject:
              if (value is Map<String, dynamic>) {
                try {
                  putEntries[key] = ReflectionBackupCodec.fromMap(value);
                } on FormatException {
                  // 不正 entry はスキップ
                }
              }
              break;
          }
        });
        await box.putAll(putEntries);
      } catch (_) {
        // 各 box の失敗は他 box を止めない／呼出側へは投げない
      }
    }
  }

  /// JSON 直列化可能値に変換する。非対応は [_unsafeMarker] を返す。
  static dynamic _toJsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List) {
      if (value.any((e) => _toJsonSafe(e) == _unsafeMarker)) {
        return _unsafeMarker;
      }
      return value;
    }
    if (value is Map) {
      if (value.keys.any((k) => k is! String) ||
          value.values.any((v) => _toJsonSafe(v) == _unsafeMarker)) {
        return _unsafeMarker;
      }
      return value;
    }
    return _unsafeMarker;
  }

  /// JSON 非対応値を示す内部マーカー（実データには出現しない一意オブジェクト）。
  static const Object _unsafeMarker = _UnsafeMarker();
}

/// テスト・プレビュー用のメモリ内実装。
class InMemoryBackupStorage implements BackupStorage {
  Map<String, Map<String, dynamic>> _snapshot;

  InMemoryBackupStorage([Map<String, Map<String, dynamic>>? initial])
      : _snapshot = (initial ?? {}).map(
          (k, v) => MapEntry(k, Map<String, dynamic>.of(v)),
        );

  /// 現在のスナップショット（複製）。
  Map<String, Map<String, dynamic>> get snapshot =>
      _snapshot.map((k, v) => MapEntry(k, Map<String, dynamic>.of(v)));

  @override
  Future<Map<String, Map<String, dynamic>>> capture() async => snapshot;

  @override
  Future<void> restore(Map<String, Map<String, dynamic>> boxes) async {
    final next = <String, Map<String, dynamic>>{};
    for (final entry in boxes.entries) {
      final spec = BackupBoxRegistry.specFor(entry.key);
      if (spec == null) continue;
      final converted = <String, dynamic>{};
      entry.value.forEach((key, value) {
        if (spec.kind == BackupBoxKind.reflectionObject &&
            value is Map<String, dynamic>) {
          try {
            converted[key] = ReflectionBackupCodec.fromMap(value);
            return;
          } on FormatException {
            return; // 不正 entry はスキップ
          }
        }
        converted[key] = value;
      });
      next[entry.key] = converted;
    }
    _snapshot = next;
  }
}

class _UnsafeMarker {
  const _UnsafeMarker();
}
