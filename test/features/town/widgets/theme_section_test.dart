import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/town/presentation/widgets/theme_section.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// Hive実機を用いないフェイク（v2.5.98 pitfall: Hive×widget試練はフェイク注入）
class FakeSettingsRepository extends SettingsRepository {
  ThemeMode _themeMode = ThemeMode.dark;
  bool themeSaved = false;

  @override
  Future<ThemeMode> getThemeMode() async => _themeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    themeSaved = true;
  }
}

void main() {
  late FakeSettingsRepository fakeRepo;
  late SettingsViewModel settingsVM;

  setUp(() async {
    fakeRepo = FakeSettingsRepository();
    settingsVM = SettingsViewModel(fakeRepo);
    // load() は Hive 実機を要求するチュートリアル系も読むため、themeModeのみ手動反映
    settingsVM.setThemeMode(fakeRepo._themeMode);
  });

  Widget buildSubject() {
    return ChangeNotifierProvider<SettingsViewModel>.value(
      value: settingsVM,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ThemeSection()),
        ),
      ),
    );
  }

  testWidgets('テーマ切替セクションが表示される（AppKeys.themeSection）', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.byKey(AppKeys.themeSection), findsOneWidget);
    expect(find.text('表示設定 (ライト/ダーク)'), findsOneWidget);
  });

  testWidgets('ライト切替でVMのthemeModeがlightに変わり永続される', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(settingsVM.themeMode, ThemeMode.dark);

    await tester.tap(find.byKey(AppKeys.themeLightButton));
    await tester.pump();
    expect(settingsVM.themeMode, ThemeMode.light);
    expect(fakeRepo.themeSaved, isTrue);
  });

  testWidgets('ダーク切替で元に戻る', (tester) async {
    await settingsVM.setThemeMode(ThemeMode.light);
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(AppKeys.themeDarkButton));
    await tester.pump();
    expect(settingsVM.themeMode, ThemeMode.dark);
  });
}
