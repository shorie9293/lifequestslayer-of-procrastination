import 'package:rpg_todo/domain/models/player.dart';

/// プレイヤーデータ永続化の抽象インターフェース
/// 試練時はMockを注入することで、Hiveに依存しないWidgetテストが可能になる
/// v1.3: 読み込み失敗時はnullを返す。データ破損時にBox削除しない。
/// v1.6: loadFailedDueToCorruption で「データあり but 読み込み失敗」を通知。
///       ViewModel/View はこのフラグを見て旧データの上書き保存を防止する。
abstract class IPlayerRepository {
  Future<Player?> loadPlayer();
  Future<void> savePlayer(Player player);
  Future<void> close();

  /// v1.6: loadPlayer() がデータのデシリアライズに失敗した場合 true。
  /// デフォルトは false（Mock実装ではオーバーライド不要）。
  bool get loadFailedDueToCorruption => false;
}
