import 'package:hive/hive.dart';

/// クロスアプリ連携設定のリポジトリ
///
/// tsundoku user_id の手動リンク情報を Hive で永続化する。
class CrossAppSettingsRepository {
  static const String _boxName = 'crossAppSettings';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.openBox(_boxName);
  }

  /// 保存されている tsundoku 連携 user_id（先頭8文字）を取得
  Future<String?> getTsundokuLinkedUserId() async {
    try {
      final box = await _openBox();
      return box.get('tsundokuLinkedUserId') as String?;
    } catch (_) {
      return null;
    }
  }

  /// tsundoku 連携 user_id（先頭8文字）を保存
  Future<void> setTsundokuLinkedUserId(String? userId) async {
    try {
      final box = await _openBox();
      if (userId == null || userId.isEmpty) {
        await box.delete('tsundokuLinkedUserId');
      } else {
        await box.put('tsundokuLinkedUserId', userId);
      }
    } catch (_) {}
  }
}
