import 'package:flutter/material.dart';

import 'app_lock_repository.dart';
import 'app_lock_service.dart';
import 'lock_reload_policy.dart';
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
  int _graceSeconds = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    AppLockService? service;
    var graceSeconds = 0;
    try {
      final repo = widget.repository ?? HiveAppLockRepository();
      service = AppLockService(repo);
      service.isLocked;
      graceSeconds = service.relockGrace.inSeconds;
    } catch (_) {
      service = null;
    }
    if (!mounted) return;
    setState(() {
      _service = service;
      _enabled = service?.isLocked ?? false;
      _graceSeconds = graceSeconds;
    });
  }

  Future<void> _setGrace(int seconds) async {
    final service = _service;
    if (service == null) return;
    setState(() => _graceSeconds = seconds);
    await service.setRelockGrace(Duration(seconds: seconds));
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, size: 48),
                        const Text('アプリロック有効'),
                        const SizedBox(height: 24),
                        DropdownButton<int>(
                          key: AppKeys.appLockGraceDropdown,
                          value: LockReloadPolicy.graceOptionsSeconds
                                  .contains(_graceSeconds)
                              ? _graceSeconds
                              : null,
                          hint: const Text('復帰時に再施錠'),
                          items: [
                            for (final seconds
                                in LockReloadPolicy.graceOptionsSeconds)
                              DropdownMenuItem<int>(
                                value: seconds,
                                child: Text(
                                  '復帰時に再施錠: '
                                  '${LockReloadPolicy.graceLabel(seconds)}',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            _setGrace(value);
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: AppKeys.appLockDisableButton,
                          onPressed: _disable,
                          child: const Text('無効にする'),
                        ),
                      ],
                    ),
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
