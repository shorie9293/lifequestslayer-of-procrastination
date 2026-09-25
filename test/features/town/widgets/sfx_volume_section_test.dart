import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/battle/domain/sfx_volume.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/town/presentation/widgets/sfx_volume_section.dart';

/// Hive実機を用いないフェイク（Hive×widget試練の既知の禍津を回避）
class FakeSettingsRepository extends SettingsRepository {
  double _sfxVolume = SfxVolumeSetting.defaultValue;
  bool volumeSaved = false;

  @override
  Future<double> getSfxVolume() async => _sfxVolume;

  @override
  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = SfxVolumeSetting(volume).value;
    volumeSaved = true;
  }
}

/// 改善提案#67: 音の設定セクション（音量スライダー＋定型値チップ）
void main() {
  late FakeSettingsRepository fakeRepo;
  late SettingsViewModel settingsVM;

  setUp(() {
    fakeRepo = FakeSettingsRepository();
    settingsVM = SettingsViewModel(fakeRepo);
  });

  Widget buildSubject() {
    return ChangeNotifierProvider<SettingsViewModel>.value(
      value: settingsVM,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SfxVolumeSection()),
        ),
      ),
    );
  }

  testWidgets('音の設定セクションが表示される（AppKeys.sfxVolumeSection）', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.byKey(AppKeys.sfxVolumeSection), findsOneWidget);
    expect(find.text('音の設定 (効果音)'), findsOneWidget);
    expect(find.byKey(AppKeys.sfxVolumeSlider), findsOneWidget);
  });

  testWidgets('定型値チップのタップでVMと永続化が更新される', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(settingsVM.sfxVolume, SfxVolumeSetting.defaultValue);

    // presets[4] = 1.0（最大）
    await tester.tap(find.byKey(AppKeys.sfxVolumePreset(4)));
    await tester.pump();
    expect(settingsVM.sfxVolume, 1.0);
    expect(fakeRepo.volumeSaved, isTrue);
  });

  testWidgets('消音（0.0）にするとラベルに「消音」が出る', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.byKey(AppKeys.sfxVolumePreset(0)));
    await tester.pump();

    expect(settingsVM.sfxVolume, 0.0);
    expect(find.text('0% 消音'), findsOneWidget);
  });

  testWidgets('スライダーのドラッグで音量が下がり表示が追従する', (tester) async {
    await tester.pumpWidget(buildSubject());
    final slider = find.byKey(AppKeys.sfxVolumeSlider);
    expect(tester.widget<Slider>(slider).value, SfxVolumeSetting.defaultValue);

    await tester.drag(slider, const Offset(-200, 0));
    await tester.pump();

    expect(settingsVM.sfxVolume, lessThan(SfxVolumeSetting.defaultValue));
    expect(fakeRepo.volumeSaved, isTrue);
    // 表示ラベルが現在値と一致する（合成の不変条件）
    final setting = SfxVolumeSetting(settingsVM.sfxVolume);
    expect(
      find.text(setting.isMuted
          ? '${setting.percentLabel} 消音'
          : '${setting.percentLabel} ${setting.label}'),
      findsOneWidget,
    );
  });
}
