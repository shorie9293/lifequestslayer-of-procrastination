import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';

import 'app_lock_repository.dart';
import 'app_lock_service.dart';
import 'lock_attempt_policy.dart';
import 'lock_recovery_policy.dart';
import 'lock_recovery_service.dart';
import 'lock_reload_policy.dart';

/// アプリロック有効時に全UIを隠すゲートWidget。
/// repository は注入可能（試練用）。未注入時は Hive 実装。
/// 読込例外・生成失敗は握りつぶして素通り（fail-open）。
class AppLockGate extends StatefulWidget {
  final WidgetBuilder unlockedBuilder;
  final AppLockRepository? repository;

  /// 試練用の時刻注入（既定は `DateTime.now`）。
  final DateTime Function()? now;

  /// 試練用の猶予上書き（既定はリポジトリの保存値）。
  final Duration? graceOverride;

  /// パスコード忘却時の回復役。未注入時は本番実装を生成する。
  final LockRecoveryService? recoveryService;

  const AppLockGate({
    super.key,
    required this.unlockedBuilder,
    this.repository,
    this.now,
    this.graceOverride,
    this.recoveryService,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  AppLockService? _service;
  LockRecoveryService? _recovery;
  bool _initialized = false;
  bool _locked = false;
  bool _obscure = true;
  final _codeController = TextEditingController();
  String? _error;

  /// 背景化を最初に観測した時刻（猶予判定の起点）。
  DateTime? _backgroundedAt;
  Duration _grace = Duration.zero;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    AppLockService? service;
    LockRecoveryService? recovery;
    var grace = Duration.zero;
    try {
      final repo = widget.repository ?? HiveAppLockRepository();
      service = AppLockService(repo, now: widget.now ?? DateTime.now);
      service.isLocked;
      grace = service.relockGrace;
      recovery = widget.recoveryService ??
          LockRecoveryService.production(service);
    } catch (_) {
      service = null; // fail-open
      recovery = null;
    }
    if (!mounted) return;
    setState(() {
      _service = service;
      _recovery = recovery;
      _locked = service?.isLocked ?? false;
      _initialized = true;
      _grace = widget.graceOverride ?? grace;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      // 最初の背景化時刻を保持する（inactive→paused で上書きしない）。
      _backgroundedAt ??= _now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _handleResumed();
    }
  }

  void _handleResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    final service = _service;
    if (service == null) return;
    // ロック無効時は一切変わらない。
    if (!service.isLocked) return;
    if (!LockReloadPolicy.shouldRelock(backgroundedAt, _now(), _grace)) return;
    if (!mounted) return;
    setState(() {
      _locked = true;
      _error = null;
      _codeController.clear();
    });
  }

  Future<void> _submit() async {
    final service = _service;
    if (service == null) return;
    if (service.isLockedOut) {
      setState(() {
        _error = 'パスコードが正しくありません';
      });
      return;
    }
    final ok = await service.unlock(passcode: _codeController.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _locked = false);
    } else {
      setState(() => _error = 'パスコードが正しくありません');
    }
    _codeController.clear();
  }

  /// パスコード忘却時: 二段確認 → 回復（バックアップ試行 → 解除 → 初期化）。
  Future<void> _openRecoveryDialog() async {
    final recovery = _recovery;
    if (recovery == null) return;
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => const _RecoveryConfirmDialog(),
    );
    if (input == null) return;
    if (!mounted) return;

    final result = await recovery.recover(confirmation: input);
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _locked = false;
        _error = null;
        _codeController.clear();
      });
    } else {
      setState(() => _error = result.reason);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_recoveryMessage(result))),
    );
  }

  String _recoveryMessage(LockRecoveryResult result) {
    final buffer = StringBuffer(
      result.success ? 'ロックを解除しました。' : 'ロックの解除に失敗しました。',
    );
    if (!result.success) {
      final reason = result.reason;
      if (reason != null) buffer.write('（$reason）');
      return buffer.toString();
    }
    if (result.backupFailed) {
      buffer.write(' バックアップの書き出しに失敗しました。');
    } else if (result.backupPath != null) {
      buffer.write(' バックアップを保存しました: ${result.backupPath}');
    } else {
      buffer.write(' バックアップ対象が無いため書き出しを省略しました。');
    }
    buffer.write(result.dataWiped ? ' データを初期化しました。' : ' データの初期化に失敗しました。');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_locked) {
      return widget.unlockedBuilder(context);
    }
    final lockedOut = _service?.isLockedOut ?? false;
    return Scaffold(
      key: AppKeys.appLockGateScreen,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 16),
              const Text('現世はロックされています'),
              const SizedBox(height: 24),
              TextField(
                key: AppKeys.appLockPasscodeField,
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                obscureText: _obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'パスコード',
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (lockedOut)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    LockAttemptPolicy.lockoutLabel(
                      _service?.lockoutRemainingSeconds ?? 0,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: AppKeys.appLockUnlockButton,
                onPressed: lockedOut ? null : _submit,
                child: const Text('解除'),
              ),
              TextButton(
                key: AppKeys.appLockForgotButton,
                onPressed: _recovery == null ? null : _openRecoveryDialog,
                child: const Text('パスコードをお忘れですか？'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 回復の二段確認ダイアログ。入力欄の寿命を自身で管理する
/// （showDialog の pop アニメーション中に controller が破棄されると
/// 「used after being disposed」になるため、StatefulWidget に閉じ込める）。
class _RecoveryConfirmDialog extends StatefulWidget {
  const _RecoveryConfirmDialog();

  @override
  State<_RecoveryConfirmDialog> createState() => _RecoveryConfirmDialogState();
}

class _RecoveryConfirmDialogState extends State<_RecoveryConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(LockRecoveryPolicy.warningTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(LockRecoveryPolicy.warningBody),
            const SizedBox(height: 16),
            TextField(
              key: AppKeys.appLockRecoveryConfirmField,
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: LockRecoveryPolicy.confirmationLabel,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        FilledButton(
          key: AppKeys.appLockRecoveryConfirmButton,
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('初期化して解除'),
        ),
      ],
    );
  }
}
