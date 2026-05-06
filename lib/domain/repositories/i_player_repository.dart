import 'package:rpg_todo/domain/models/player.dart';

/// プレイヤーデータ永続化の抽象インターフェース
/// 試練時はMockを注入することで、Hiveに依存しないWidgetテストが可能になる
abstract class IPlayerRepository {
  Future<Player> loadPlayer();
  Future<void> savePlayer(Player player);
  Future<void> close();
}
