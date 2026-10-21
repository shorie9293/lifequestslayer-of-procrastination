import 'package:flutter/material.dart';

/// アニメーション（動き）の抑制設定。
///
/// OS の「視差効果を減らす」設定に従うか、アプリ独自に上書きするかを選ぶ。
/// WCAG 2.3.3（インタラクションによるアニメーション）への配慮として、
/// 前庭障害（めまい・動揺病）のある利用者が演出を止められるようにする。
enum ReduceMotionSetting {
  /// 端末の設定に従う（既定）。OS が動きを減らす設定ならそれに合わせる。
  system('system', 'システムに従う', Icons.brightness_auto_outlined),

  /// 利用者が明示的に「動きを有効化」する。
  ///
  /// **この値は端末設定より優先される** — OS で視差効果を減らしていても、
  /// アプリ内ではアニメーションを通常どおり再生する（明示的な意思表示を尊重）。
  off('off', '動きを有効', Icons.animation),

  /// アニメーションを抑止する（端末設定より優先）。
  on('on', '動きを減らす', Icons.motion_photos_off_outlined);

  const ReduceMotionSetting(this.storageKey, this.label, this.icon);

  /// 永続化に用いる文字列表現。列挙名に依存せず、値の意味を保つ。
  final String storageKey;

  /// 画面に表示するラベル。
  final String label;

  /// 選択肢のアイコン。
  final IconData icon;

  /// 保存値から復元する。未知の値・null は [system]（安全側）に落とす。
  static ReduceMotionSetting fromStorageKey(String? key) {
    for (final setting in values) {
      if (setting.storageKey == key) return setting;
    }
    return ReduceMotionSetting.system;
  }

  /// 次の選択肢（system → off → on → system）。
  ReduceMotionSetting get next {
    switch (this) {
      case ReduceMotionSetting.system:
        return ReduceMotionSetting.off;
      case ReduceMotionSetting.off:
        return ReduceMotionSetting.on;
      case ReduceMotionSetting.on:
        return ReduceMotionSetting.system;
    }
  }

  /// `MediaQueryData.disableAnimations` に強制する値。
  ///
  /// [on] → true（抑止）、[off] → false（明示的に有効化）、
  /// [system] → null（端末設定をそのまま尊重）。
  bool? get forceDisableAnimations {
    switch (this) {
      case ReduceMotionSetting.on:
        return true;
      case ReduceMotionSetting.off:
        return false;
      case ReduceMotionSetting.system:
        return null;
    }
  }
}

/// [setting] を [data] に適用した [MediaQueryData] を返す。
///
/// 強制値が無い（[ReduceMotionSetting.system]）場合は [data] をそのまま返し、
/// 端末設定・テキストスケーラ等の既存属性を一切変更しない。
MediaQueryData applyReduceMotion(
  MediaQueryData data,
  ReduceMotionSetting setting,
) {
  final forced = setting.forceDisableAnimations;
  if (forced == null) return data;
  return data.copyWith(disableAnimations: forced);
}
