// 聴取器の試練: 保存失敗が「誰にも見えない」状態へ戻らないことを固定する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/presentation/settings_write_error_listener.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

class _FailingRepo extends SettingsRepository {
  @override
  Future<void> setSfxEnabled(bool enabled) async =>
      throw StateError('disk full');
}

class _OkRepo extends SettingsRepository {
  @override
  Future<void> setSfxEnabled(bool enabled) async {}
}

Widget _harness(SettingsViewModel vm) => MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<SettingsViewModel>.value(
          value: vm,
          child: SettingsWriteErrorListener(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => context
                    .read<SettingsViewModel>()
                    .setSfxEnabled(false),
                child: const Text('効果音OFF'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('保存失敗はSnackBarで理由が出て、理由は消費される', (tester) async {
    final vm = SettingsViewModel(_FailingRepo());
    await tester.pumpWidget(_harness(vm));

    await tester.tap(find.text('効果音OFF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('設定を保存できませんでした'), findsOneWidget);
    expect(find.textContaining('効果音設定'), findsWidgets);
    expect(vm.lastWriteError, isNull, reason: '同じ失敗を二度出さないため消費される');
  });

  testWidgets('保存成功ではSnackBarを出さない', (tester) async {
    final vm = SettingsViewModel(_OkRepo());
    await tester.pumpWidget(_harness(vm));

    await tester.tap(find.text('効果音OFF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsNothing);
    expect(vm.isSfxEnabled, isFalse);
  });
}
