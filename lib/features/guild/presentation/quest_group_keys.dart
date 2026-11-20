import 'package:flutter/widgets.dart';

import 'package:rpg_todo/features/guild/domain/quest_grouping.dart';

/// 寄合所グルーピングの試練用 Key。
class QuestGroupKeys {
  QuestGroupKeys._();

  /// 期日 / ランク の切替。
  static const Key modeToggle = Key('bar_guild_group_mode');

  static Key modeButton(QuestGroupMode mode) =>
      Key('btn_guild_group_mode_${mode.name}');

  /// パネル見出し（タップでたたむ）。
  static Key header(QuestGroupBand band) =>
      Key('row_guild_group_${band.name}');
}
