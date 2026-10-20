import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// main.dart / settings_hub_screen.dart の配線検証（ソースレベル）。
/// 実アプリ起動は DI・Supabase・Firebase が絡み重いため、
/// 配線そのものをソース断言で固める。
void main() {
  test('main.dart の home は AppLockGate 経由の AuthGate である', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source,
      contains('home: AppLockGate(unlockedBuilder: (context) => const AuthGate())'),
    );
    expect(source, contains("import 'package:rpg_todo/core/infrastructure/app_lock_gate.dart';"));
  });

  test('settings_hub_screen.dart に アプリロック タイルが配線されている', () {
    final source =
        File('lib/features/settings/presentation/settings_hub_screen.dart')
            .readAsStringSync();
    expect(source, contains("title: const Text('アプリロック')"));
    expect(source, contains('AppKeys.appLockSettingsTile'));
    expect(
      source,
      contains("builder: (_) => const AppLockSettingsScreen()"),
    );
  });

  test('pubspec.yaml は crypto 依存と新版数 1.5.44+140 を持つ', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('crypto: ^3.0.7'));
    expect(pubspec, contains('version: 1.5.44+140'));
  });
}
