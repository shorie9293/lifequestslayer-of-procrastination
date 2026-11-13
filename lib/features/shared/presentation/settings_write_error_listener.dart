import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

/// 設定の保存失敗を創造主様へ1度だけ知らせる聴取器。
///
/// [SettingsViewModel] は保存失敗を `lastWriteError` に載せるが、読み手が
/// 居なければ無音のままである（結果型を足しただけで黙るのは同じ禍津）。
/// 本widgetを画面の先頭に1つ置くと、失敗した瞬間にSnackBarで理由を出す。
class SettingsWriteErrorListener extends StatefulWidget {
  const SettingsWriteErrorListener({super.key, required this.child});

  final Widget child;

  @override
  State<SettingsWriteErrorListener> createState() =>
      _SettingsWriteErrorListenerState();
}

class _SettingsWriteErrorListenerState
    extends State<SettingsWriteErrorListener> {
  SettingsViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<SettingsViewModel>();
    if (identical(vm, _vm)) return;
    _vm?.removeListener(_onSettingsChanged);
    _vm = vm..addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    final message = _vm?.lastWriteError;
    if (message == null) return;
    _vm?.clearWriteError(); // 同じ失敗を二度出さない
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        key: const Key('settings_write_error_snackbar'),
        content: Text('設定を保存できませんでした: $message'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _vm?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
