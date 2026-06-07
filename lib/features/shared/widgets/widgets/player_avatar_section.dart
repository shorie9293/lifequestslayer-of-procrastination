import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/job.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';

/// アバター・称号・ジョブ・コイン・コンボを表示するLeft-side Widget
class PlayerAvatarSection extends StatelessWidget {
  final Player player;

  const PlayerAvatarSection({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CharacterAvatar(
          characterSkin: player.characterSkin,
          legacySkinId: player.equippedSkin,
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

/// 5部位スキンを合成表示するアバターウィジェット。
///
/// [CharacterSkin] の各スロットに対応する絵文字を重ねて表示する。
/// 全スロットが default の場合は旧スキン画像にフォールバック。
class _CharacterAvatar extends StatelessWidget {
  final CharacterSkin characterSkin;
  final String? legacySkinId;

  const _CharacterAvatar({
    required this.characterSkin,
    this.legacySkinId,
  });

  /// 5部位すべてがデフォルトかどうか
  bool get _isAllDefault =>
      characterSkin.faceId == 'default' &&
      characterSkin.hairId == 'default' &&
      characterSkin.armorId == 'default' &&
      characterSkin.weaponId == 'default' &&
      characterSkin.shieldId == 'default';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amber.shade700, width: 2),
        color: Colors.black26,
      ),
      alignment: Alignment.center,
      child: _isAllDefault
          ? _buildLegacyAvatar()
          : _buildCompositeAvatar(),
    );
  }

  /// 旧スキン画像フォールバック（skin_1〜4 or デフォルトアイコン）
  Widget _buildLegacyAvatar() {
    final path = _legacySkinPath(legacySkinId);
    return ClipOval(
      child: Image.asset(
        'assets/images/$path',
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.person, color: Colors.white54, size: 32),
      ),
    );
  }

  /// 5部位の絵文字を合成してアバターを構成する
  Widget _buildCompositeAvatar() {
    // 各スロットのスキン定義からアイコン絵文字を取得
    final faceDef = SkinCatalog.findById(characterSkin.faceId);
    final hairDef = SkinCatalog.findById(characterSkin.hairId);
    final armorDef = SkinCatalog.findById(characterSkin.armorId);
    final weaponDef = SkinCatalog.findById(characterSkin.weaponId);
    final shieldDef = SkinCatalog.findById(characterSkin.shieldId);

    // デフォルト部位は非表示
    final faceIcon = characterSkin.faceId != 'default'
        ? (faceDef?.icon ?? '😶')
        : null;
    final hairIcon = characterSkin.hairId != 'default'
        ? (hairDef?.icon ?? '💇')
        : null;
    final armorIcon = characterSkin.armorId != 'default'
        ? (armorDef?.icon ?? '👘')
        : null;
    final weaponIcon = characterSkin.weaponId != 'default'
        ? (weaponDef?.icon ?? '👊')
        : null;
    final shieldIcon = characterSkin.shieldId != 'default'
        ? (shieldDef?.icon ?? '🤚')
        : null;

    return Stack(
      alignment: Alignment.center,
      children: [
        // ベース: 顔パーツ（中央、一番目立つ）
        if (faceIcon != null)
          Text(faceIcon, style: const TextStyle(fontSize: 28)),
        // 髪型（顔の上に重ねる、やや上にオフセット）
        if (hairIcon != null)
          Positioned(
            top: 0,
            child: Text(hairIcon,
                style: const TextStyle(fontSize: 14)),
          ),
        // 鎧（左下に小さく）
        if (armorIcon != null)
          Positioned(
            bottom: 0,
            left: 0,
            child: Text(armorIcon,
                style: const TextStyle(fontSize: 12)),
          ),
        // 武器（右に小さく）
        if (weaponIcon != null)
          Positioned(
            right: 0,
            top: 8,
            child: Text(weaponIcon,
                style: const TextStyle(fontSize: 12)),
          ),
        // 盾（左に小さく）
        if (shieldIcon != null)
          Positioned(
            left: 0,
            top: 8,
            child: Text(shieldIcon,
                style: const TextStyle(fontSize: 12)),
          ),
        // 全部位defaultの場合のベースアイコン
        if (faceIcon == null &&
            hairIcon == null &&
            armorIcon == null &&
            weaponIcon == null &&
            shieldIcon == null)
          const Icon(Icons.person, color: Colors.white54, size: 32),
      ],
    );
  }
}

/// 旧スキンID → PNGファイル名マッピング
String _legacySkinPath(String? skinId) {
  switch (skinId) {
    case "skin_1":
      return "skin_icon_1.png";
    case "skin_2":
      return "skin_icon_2.png";
    case "skin_3":
      return "skin_icon_3.png";
    case "skin_4":
      return "skin_icon_4.png";
    default:
      return "skin_icon_default.png";
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
/// 注意: 旧ショップスキン用。新5部位スキンには使わない。
@Deprecated('Use CharacterSkin + SkinCatalog instead')
String skinIconPath(String? skinId) {
  return _legacySkinPath(skinId);
}
