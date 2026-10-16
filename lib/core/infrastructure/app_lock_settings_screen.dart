import 'package:flutter/material.dart';

import 'app_lock_repository.dart';
import 'app_lock_service.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// 設定画面: パスコードによるアプリロックの有効化/無効化。
class AppLockSettingsScreen extends StatefulWidget {
  final AppLockRepository? repository;
  const AppLockSettingsScreen({super.key, this.repository});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  AppLockService? _service;
  bool _enabled = false;
  final _passcodeController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    AppLockService? service;
    try {
      final repo = widget.repository ?? HiveAppLockRepository();
      service = AppLockService(repo);
      service.isLocked;
    } catch (_) {
      service = null;
    }
    if (!mounted) return;
    setState(() {
      _service = service;
      _enabled = service?.isLocked ?? false;
    });
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    setState(() => _error = null);
    final code = _passcodeController.text;
    if (code != _confirmController.text) {
      setState(() => _error = '確認用と一致しません');
      return;
    }
    try {
      await _service!.enableWithPasscode(code);
    } on ArgumentError {
      setState(() => _error = '4桁の数字を入力せよ');
      return;
    }
    if (!mounted) return;
    setState(() => _enabled = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('アプリロックを有効にしました')));
  }

  Future<void> _disable() async {
    await _service!.disable();
    if (!mounted) return;
    setState(() => _enabled = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('アプリロックを無効にしました')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.appLockSettingsScreen,
      appBar: AppBar(title: const Text('アプリロック')),
      body: _service == null
          ? const Center(child: CircularProgressIndicator())
          : _enabled
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, size: 48),
                      const Text('アプリロック有効'),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: AppKeys.appLockDisableButton,
                        onPressed: _disable,
                        child: const Text('無効にする'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        key: AppKeys.appLockPasscodeField,
                        controller: _passcodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '新しいパスコード（4桁）',
                        ),
                      ),
                      TextField(
                        key: AppKeys.appLockConfirmPasscodeField,
                        controller: _confirmController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '確認用パスコード',
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          key: AppKeys.appLockErrorText,
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: AppKeys.appLockEnableButton,
                        onPressed: _enable,
                        child: const Text('有効にする'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
