import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/return_mission.dart';

/// 帰還ミッションの生成を担当するサービス。
///
/// ストリーク切断時に呼び出され、イミュータブルな [Player] の
/// 新しいインスタンス（`activeReturnMission` / `lastReturnMissionIssuedAt` を設定済み）を返す。
class ReturnMissionService {
  /// 帰還ミッションを生成し、設定済みの新しい [Player] を返す。
  ///
  /// 元の [Player] は不変のまま。呼び出し側は戻り値を保存すること。
  /// [previousStreak] は切断前のストリーク日数。
  /// [now] は現在日時（テスト容易性のため注入可能）。
  static Player generateReturnMission(
    Player player, {
    required int previousStreak,
    required DateTime now,
  }) {
    return player.copyWith(
      activeReturnMission: ReturnMission(
        previousStreak: previousStreak,
        issuedAt: now,
      ),
      lastReturnMissionIssuedAt: now,
    );
  }
}
