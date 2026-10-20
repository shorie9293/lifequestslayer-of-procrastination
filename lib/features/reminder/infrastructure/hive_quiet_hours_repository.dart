import 'dart:convert';

import 'package:hive/hive.dart';

import '../data/quiet_hours_repository.dart';
import '../domain/quiet_hours_settings.dart';

/// Hive 実装。box `quiet_hours_box` / key `quiet_hours_settings` に
/// JSON 文字列で保存する。
///
/// [Hive.init] は呼ばない（呼び出し側が初期化済みである前提）。
/// テストでは [box] を注入でき、未注入時は [Hive.openBox] を使う。
/// open 失敗・破損レコードは [QuietHoursSettings.defaults] へ
/// フォールバックする。
class HiveQuietHoursRepository implements QuietHoursRepository {
  HiveQuietHoursRepository({Box<String>? box, this.openIfMissing = true})
      : _injected = box;

  static const String boxName = 'quiet_hours_box';
  static const String keyName = 'quiet_hours_settings';

  final Box<String>? _injected;

  /// false なら「既に open 済みの box を読むだけ」にし、無ければ
  /// [QuietHoursSettings.defaults] を返す。
  ///
  /// 通知経路の既定ガードはこれを false で使う。Hive 未初期化のまま
  /// `openBox` を呼ぶと Hive 内部で未処理の非同期エラーが発生し得るため、
  /// box の open はアプリ起動時（main.dart）と保存時のみに限定する。
  final bool openIfMissing;

  Box<String>? _opened;

  Future<Box<String>?> _box() async {
    if (_injected != null) return _injected;
    if (_opened != null && _opened!.isOpen) return _opened;
    try {
      // Hive 未初期化・path 未設定なら openBox は HiveError を投げる。
      // ここで握り潰し null を返すため、呼び出し側は defaults に落ちる
      // （通知経路が例外やハングで止まらない）。
      if (Hive.isBoxOpen(boxName)) {
        _opened = Hive.box<String>(boxName);
        return _opened;
      }
      if (!openIfMissing) return null;
      _opened = await Hive.openBox<String>(boxName);
      return _opened;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<QuietHoursSettings> load() async {
    try {
      final box = await _box();
      if (box == null) return QuietHoursSettings.defaults();
      final raw = box.get(keyName);
      if (raw is! String) return QuietHoursSettings.defaults();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return QuietHoursSettings.defaults();
      }
      return QuietHoursSettings.fromJson(decoded);
    } catch (_) {
      return QuietHoursSettings.defaults();
    }
  }

  @override
  Future<void> save(QuietHoursSettings settings) async {
    final box = await _box();
    if (box == null) return;
    try {
      await box.put(keyName, jsonEncode(settings.toJson()));
    } catch (_) {
      // 保存失敗は握り潰す（設定画面を壊さない）。
    }
  }
}
