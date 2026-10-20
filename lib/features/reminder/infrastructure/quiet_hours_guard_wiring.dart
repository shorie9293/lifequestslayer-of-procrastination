import 'package:rpg_todo/features/reminder/data/quiet_hours_repository.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_service.dart';

import 'hive_quiet_hours_repository.dart';

/// 本番既定の [QuietHoursGuard] 生成点。
///
/// スケジューラの `guard` を省略した場合は必ずここを通るため、
/// 設定画面（`HiveQuietHoursRepository`）で保存した静穏時間設定が
/// 本番の通知経路へ自動的に反映される。
///
/// 試練では [repositoryFactory] を差し替えることで、
/// **既定コンストラクタ経路のまま**任意のリポジトリを注入できる
/// （Hive に触れずに既定結線を検証するための差し替えシーム）。
abstract final class QuietHoursGuardWiring {
  /// 既定リポジトリの生成関数。null なら本番の [HiveQuietHoursRepository]。
  static QuietHoursRepository Function()? repositoryFactory;

  /// 差し替えを既定へ戻す（試練の tearDown で呼ぶ）。
  static void reset() => repositoryFactory = null;

  /// 明示指定が無いときに使うガードを生成する。
  ///
  /// Hive 未初期化・box 未 open でも [HiveQuietHoursRepository.load] が
  /// defaults（enabled=false）へフォールバックするため、例外もハングもせず
  /// 「静穏時間なし＝従来通り」に落ちる。
  static QuietHoursGuard create() {
    final factory = repositoryFactory;
    final QuietHoursRepository repository = factory != null
        ? factory()
        // 通知経路では box を新規 open しない（未初期化 Hive での
        // 非同期エラーを避ける）。box は main.dart 起動時と保存時に open される。
        : HiveQuietHoursRepository(openIfMissing: false);
    return QuietHoursRepositoryGuard(repository);
  }
}
