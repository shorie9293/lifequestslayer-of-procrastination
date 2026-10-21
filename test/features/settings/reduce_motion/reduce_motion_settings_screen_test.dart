import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/settings/presentation/reduce_motion_settings_screen.dart';
import 'package:rpg_todo/features/shared/data/reduce_motion_repository.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';
import 'package:rpg_todo/features/shared/viewmodels/reduce_motion_view_model.dart';

void main() {
  group('ReduceMotionSettingsScreen', () {
    testWidgets('3択（システム／動きを有効／動きを減らす）が描画される', (tester) async {
      final repo = InMemoryReduceMotionRepository();
      await tester.pumpWidget(MaterialApp(
        home: ReduceMotionSettingsScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      for (final option in ReduceMotionSetting.values) {
        expect(
          find.byKey(ValueKey('reduce_motion_option_${option.storageKey}')),
          findsOneWidget,
          reason: '${option.storageKey} の選択肢が無い',
        );
        expect(find.text(option.label), findsOneWidget);
      }
      expect(find.textContaining('WCAG'), findsOneWidget);
      expect(find.textContaining('前庭'), findsWidgets);
    });

    testWidgets('「動きを減らす」タップで repository.save に到達する', (tester) async {
      final repo = InMemoryReduceMotionRepository();
      await tester.pumpWidget(MaterialApp(
        home: ReduceMotionSettingsScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('reduce_motion_option_on')));
      await tester.pumpAndSettle();

      expect(repo.saveCount, 1);
      expect(repo.saved, ReduceMotionSetting.on);
    });

    testWidgets('注入 repository があれば VM 無しでも動作する', (tester) async {
      final repo = InMemoryReduceMotionRepository(ReduceMotionSetting.off);
      await tester.pumpWidget(MaterialApp(
        home: ReduceMotionSettingsScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      // 保存済みの値が初期選択として復元される（VM 不在でも落ちない）
      final group = tester.widget<RadioGroup<ReduceMotionSetting>>(
        find.byType(RadioGroup<ReduceMotionSetting>),
      );
      expect(group.groupValue, ReduceMotionSetting.off);

      await tester.tap(find.byKey(const ValueKey('reduce_motion_option_on')));
      await tester.pumpAndSettle();
      expect(repo.saved, ReduceMotionSetting.on);
    });

    testWidgets('VM 経由でも save に到達し、状態が更新される', (tester) async {
      final repo = InMemoryReduceMotionRepository();
      final vm = ReduceMotionViewModel(repo);
      await tester.pumpWidget(ChangeNotifierProvider<ReduceMotionViewModel>.value(
        value: vm,
        child: const MaterialApp(home: ReduceMotionSettingsScreen()),
      ));
      await tester.pumpAndSettle();

      final group = tester.widget<RadioGroup<ReduceMotionSetting>>(
        find.byType(RadioGroup<ReduceMotionSetting>),
      );
      expect(group.groupValue, ReduceMotionSetting.system, reason: '既定は system');

      await tester.tap(find.byKey(const ValueKey('reduce_motion_option_on')));
      await tester.pumpAndSettle();

      expect(vm.setting, ReduceMotionSetting.on);
      expect(repo.saved, ReduceMotionSetting.on);
      expect(repo.saveCount, 1);
    });
  });
}
