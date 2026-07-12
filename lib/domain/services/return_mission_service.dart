import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/return_mission.dart';

/// 帰還ミッションの生成を担当するサービス。
///
/// ストリーク切断時に呼び出され、
/// [Player.activeReturnMission] にミッションをセットする。
class ReturnMissionService {
  /// 帰還ミッションを生成し、プレイヤーにセットする。
  ///
  /// [previousStreak] は切断前のストリーク日数。
  /// [now] は現在日時（テスト容易性のため注入可能）。
  static void generateReturnMission(
    Player player, {
    required int previousStreak,
    required DateTime now,
  }) {
    player.activeReturnMission = ReturnMission(
      previousStreak: previousStreak,
      issuedAt: now,
    );
    player.lastReturnMissionIssuedAt = now;
  }
}
