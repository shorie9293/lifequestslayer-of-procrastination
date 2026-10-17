import 'package:flutter/material.dart';

/// 「アプリについて」画面の試練用Key。
/// 既存 AppKeys（widget_keys.dart）には触れず、本feature内で一元管理する。
class AboutAppKeys {
  AboutAppKeys._();

  static const Key aboutScreen = Key('screen_about');
  static const Key versionLabel = Key('txt_about_version');
  static const Key licenseTile = Key('tile_about_license');
  static const Key privacyTile = Key('tile_about_privacy');
  static const Key contactTile = Key('tile_about_contact');
  static const Key copyButton = Key('btn_about_copy');
  static const Key entryFromSettings = Key('tile_settings_about');
}
