import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/player.dart';

/// アバター・称号・ジョブ・コイン・コンボを表示するLeft-side Widget
class PlayerAvatarSection extends StatelessWidget {
  final Player player;

  const PlayerAvatarSection({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            getSkinIcon(player.equippedSkin),
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (player.equippedTitle != null &&
                  player.equippedTitle!.isNotEmpty)
                Text(
                  "【${player.equippedTitle}】",
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              Text(
                "Lv.${player.level} ${getJobName(player.currentJob)}",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  const Icon(Icons.monetization_on,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "${player.coins}",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber),
                  ),
                ],
              ),
              if (player.currentJob == Job.warrior)
                Text(
                  "Combo: ${player.comboCount}",
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ジョブ名を日本語で返す
String getJobName(Job job) {
  switch (job) {
    case Job.warrior:
      return "侍";
    case Job.cleric:
      return "法師";
    case Job.wizard:
      return "陰陽師";
    case Job.adventurer:
      return "浪人";
  }
}

/// スキンIDに対応する絵文字を返す
String getSkinIcon(String? skinId) {
  if (skinId == "skin_1") return "🧥";
  if (skinId == "skin_2") return "🎖️";
  if (skinId == "skin_3") return "🪄";
  if (skinId == "skin_4") return "👑";
  return "👤";
}
