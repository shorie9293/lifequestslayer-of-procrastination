import '../models/player.dart';
import '../models/title_definition.dart';

/// 称号の判定・進捗管理を担当するサービス。
class TitleService {
  /// 称号条件をチェックし、新たに獲得した称号をプレイヤーに追加する。
  /// 獲得した称号があれば、bonusMessages にメッセージを追加する。
  static void checkTitles(Player player, List<String> bonusMessages) {
    for (final def in kAllTitles) {
      _unlockTitle(player, def, bonusMessages);
    }
  }

  static void _unlockTitle(Player player, TitleDefinition def, List<String> messages) {
    if (!player.titles.contains(def.id) && def.getProgress(player) >= def.requiredCount) {
      player.titles.add(def.id);
      messages.add('🏅 称号獲得：『${def.id}』');
    }
  }

  /// 各称号の現在進捗を返す
  static List<({TitleDefinition def, int progress, bool isUnlocked})> getTitleProgressList(Player player) {
    return kAllTitles.map((def) {
      final progress = def.getProgress(player);
      final isUnlocked = player.titles.contains(def.id);
      return (def: def, progress: progress, isUnlocked: isUnlocked);
    }).toList();
  }
}
