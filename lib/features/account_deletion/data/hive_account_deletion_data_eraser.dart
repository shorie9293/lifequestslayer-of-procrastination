import 'package:hive/hive.dart';

import 'package:rpg_todo/features/account_deletion/domain/account_deletion_policy.dart';

/// 本番の端末データ消去実装。
///
/// 方針:
/// 1. [AccountDeletionPolicy.targetBoxNames] のうち開いている箱は中身を clear。
/// 2. 開いていない箱はディスクから削除（存在しなければ黙って無視）。
/// 3. 最後に [Hive.deleteFromDisk] で取り残しを掃討する。
///
/// どの段階の失敗も「箱が無い」等の想定内ゆえ握り潰すが、致命的失敗は
/// 呼び出し側（[AccountDeletionService]）が結果型で扱えるよう投げ直す。
class HiveAccountDeletionDataEraser {
  const HiveAccountDeletionDataEraser({
    this.boxNames = AccountDeletionPolicy.targetBoxNames,
  });

  final List<String> boxNames;

  Future<void> erase() async {
    for (final name in boxNames) {
      if (!Hive.isBoxOpen(name)) continue;
      await Hive.box<dynamic>(name).clear();
    }

    for (final name in boxNames) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {
        // 未作成・未初期化の箱は無視する。
      }
    }

    try {
      await Hive.deleteFromDisk();
    } catch (_) {
      // Hive 未初期化など。開いていた箱の clear は済んでいるため致命ではない。
    }
  }

  /// 関数として渡せるようにするための糖衣。
  Future<void> call() => erase();
}
