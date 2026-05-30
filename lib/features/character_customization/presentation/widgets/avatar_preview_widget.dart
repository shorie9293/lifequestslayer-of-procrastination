import 'package:flutter/material.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';

/// 5部位スキンを合成表示するアバタープレビューウィジェット。
///
/// 装備画面やスキン選択画面で、現在の装備状態をリアルタイムに表示する。
/// [CharacterSkin] の各スロットに対応する絵文字を重ねて表示する。
///
/// [previewSlot] を指定すると、そのスロットだけ一時的に差し替えた
/// プレビュー表示ができる（装備前の確認用）。
class AvatarPreviewWidget extends StatelessWidget {
  /// 現在の装備状態。
  final CharacterSkin characterSkin;

  /// 旧スキンID（characterSkin がすべて default の場合のフォールバック）。
  final String? legacySkinId;

  /// プレビュー対象のスロット（null なら現在の装備をそのまま表示）。
  final SkinSlot? previewSlot;

  /// プレビュー対象スロットのスキンID。
  final String? previewSkinId;

  /// アバター表示サイズ。
  final double size;

  /// 背景色。
  final Color? backgroundColor;

  const AvatarPreviewWidget({
    super.key,
    required this.characterSkin,
    this.legacySkinId,
    this.previewSlot,
    this.previewSkinId,
    this.size = 120,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // プレビュー用にスキンを差し替え
    final effectiveSkin = previewSlot != null && previewSkinId != null
        ? characterSkin.withSlot(previewSlot!, previewSkinId!)
        : characterSkin;

    final isAllDefault = effectiveSkin.faceId == 'default' &&
        effectiveSkin.hairId == 'default' &&
        effectiveSkin.armorId == 'default' &&
        effectiveSkin.weaponId == 'default' &&
        effectiveSkin.shieldId == 'default';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: 3,
        ),
        color: backgroundColor ?? Colors.black38,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: isAllDefault
          ? _buildLegacyAvatar()
          : _buildCompositeAvatar(effectiveSkin),
    );
  }

  Widget _buildLegacyAvatar() {
    final path = _legacySkinPath(legacySkinId);
    final iconSize = size * 0.6;
    return ClipOval(
      child: Image.asset(
        'assets/images/$path',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.person, color: Colors.white54, size: iconSize * 0.6),
      ),
    );
  }

  Widget _buildCompositeAvatar(CharacterSkin skin) {
    final faceDef = SkinCatalog.findById(skin.faceId);
    final hairDef = SkinCatalog.findById(skin.hairId);
    final armorDef = SkinCatalog.findById(skin.armorId);
    final weaponDef = SkinCatalog.findById(skin.weaponId);
    final shieldDef = SkinCatalog.findById(skin.shieldId);

    final faceIcon =
        skin.faceId != 'default' ? (faceDef?.icon ?? '😶') : null;
    final hairIcon =
        skin.hairId != 'default' ? (hairDef?.icon ?? '💇') : null;
    final armorIcon =
        skin.armorId != 'default' ? (armorDef?.icon ?? '👘') : null;
    final weaponIcon =
        skin.weaponId != 'default' ? (weaponDef?.icon ?? '👊') : null;
    final shieldIcon =
        skin.shieldId != 'default' ? (shieldDef?.icon ?? '🤚') : null;

    // サイズに応じた絵文字スケーリング
    final faceFontSize = size * 0.35;
    final partFontSize = size * 0.18;
    final subPartFontSize = size * 0.15;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 顔パーツ（中央、一番目立つ）
        if (faceIcon != null)
          Text(faceIcon, style: TextStyle(fontSize: faceFontSize)),
        // 髪型（上部に配置）
        if (hairIcon != null)
          Positioned(
            top: size * 0.05,
            child:
                Text(hairIcon, style: TextStyle(fontSize: partFontSize)),
          ),
        // 鎧（左下）
        if (armorIcon != null)
          Positioned(
            bottom: size * 0.05,
            left: size * 0.08,
            child: Text(armorIcon,
                style: TextStyle(fontSize: subPartFontSize)),
          ),
        // 武器（右上）
        if (weaponIcon != null)
          Positioned(
            right: size * 0.05,
            top: size * 0.15,
            child: Text(weaponIcon,
                style: TextStyle(fontSize: subPartFontSize)),
          ),
        // 盾（左上）
        if (shieldIcon != null)
          Positioned(
            left: size * 0.05,
            top: size * 0.15,
            child: Text(shieldIcon,
                style: TextStyle(fontSize: subPartFontSize)),
          ),
        // 全部位defaultの場合のベースアイコン
        if (faceIcon == null &&
            hairIcon == null &&
            armorIcon == null &&
            weaponIcon == null &&
            shieldIcon == null)
          Icon(Icons.person, color: Colors.white54, size: size * 0.5),
      ],
    );
  }
}

/// 旧スキンID → PNGファイル名マッピング
String _legacySkinPath(String? skinId) {
  switch (skinId) {
    case 'skin_1':
      return 'skin_icon_1.png';
    case 'skin_2':
      return 'skin_icon_2.png';
    case 'skin_3':
      return 'skin_icon_3.png';
    case 'skin_4':
      return 'skin_icon_4.png';
    default:
      return 'skin_icon_default.png';
  }
}
