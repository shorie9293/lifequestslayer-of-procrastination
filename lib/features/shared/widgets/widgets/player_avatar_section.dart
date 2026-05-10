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
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber.shade700, width: 2),
          ),
          alignment: Alignment.center,
          child: ClipOval(
            child: Image.asset(
              'assets/images/${skinIconPath(player.equippedSkin)}',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person, color: Colors.white54, size: 28),
            ),
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

/// スキンIDに対応するアイコン画像パスを返す（和風アイコン）
String skinIconPath(String? skinId) {
  switch (skinId) {
    case "skin_1": return "skin_icon_1.png";
    case "skin_2": return "skin_icon_2.png";
    case "skin_3": return "skin_icon_3.png";
    case "skin_4": return "skin_icon_4.png";
    default: return "skin_icon_default.png";
  }
}
