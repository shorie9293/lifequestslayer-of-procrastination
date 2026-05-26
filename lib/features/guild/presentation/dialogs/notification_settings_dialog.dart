import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 通知設定ダイアログ
class NotificationSettingsDialog extends StatefulWidget {
  const NotificationSettingsDialog({super.key});

  @override
  State<NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<NotificationSettingsDialog> {
  final _service = NotificationService();
  final _settingsRepository = SettingsRepository();

  bool _enabled = true;
  bool _morningEnabled = true;
  bool _eveningEnabled = true;
  bool _noonEnabled = true;
  int _morningHour = 9;
  int _morningMinute = 0;
  int _eveningHour = 21;
  int _eveningMinute = 0;
  int _noonHour = 12;
  int _noonMinute = 0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _service.isEnabled();
    final mh = await _service.getMorningHour();
    final mm = await _service.getMorningMinute();
    final eh = await _service.getEveningHour();
    final em = await _service.getEveningMinute();
    final nh = await _service.getNoonHour();
    final nm = await _service.getNoonMinute();
    final morningEnabled =
        await _settingsRepository.getMorningNotificationEnabled();
    final eveningEnabled =
        await _settingsRepository.getEveningNotificationEnabled();
    final noonEnabled =
        await _settingsRepository.getNoonNotificationEnabled();
    setState(() {
      _enabled = enabled;
      _morningEnabled = morningEnabled;
      _eveningEnabled = eveningEnabled;
      _noonEnabled = noonEnabled;
      _morningHour = mh;
      _morningMinute = mm;
      _eveningHour = eh;
      _eveningMinute = em;
      _noonHour = nh;
      _noonMinute = nm;
      _loading = false;
    });
  }

  Future<void> _pickTime({required bool isMorning, bool isNoon = false}) async {
    final initial = TimeOfDay(
      hour: isMorning
          ? _morningHour
          : isNoon
              ? _noonHour
              : _eveningHour,
      minute: isMorning
          ? _morningMinute
          : isNoon
              ? _noonMinute
              : _eveningMinute,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isMorning) {
        _morningHour = picked.hour;
        _morningMinute = picked.minute;
      } else if (isNoon) {
        _noonHour = picked.hour;
        _noonMinute = picked.minute;
      } else {
        _eveningHour = picked.hour;
        _eveningMinute = picked.minute;
      }
    });
  }

  Future<void> _save() async {
    // 権限リクエスト
    final granted = await _service.requestPermission();
    if (!granted && mounted) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_off, color: Colors.red),
              SizedBox(width: 8),
              Text('通知が許可されていません'),
            ],
          ),
          content: const Text(
            '通知を有効にするには、アプリの設定画面で「通知」を許可してください。\n\n'
            '設定画面を開きますか？',
          ),
          actions: [
            SemanticHelper.interactive(
              testId: SemanticHelper.createTestId(
                  SemanticTypes.button, 'cancel_perm_denied'),
              label: 'キャンセル',
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル'),
              ),
            ),
            SemanticHelper.interactive(
              testId: SemanticHelper.createTestId(
                  SemanticTypes.button, 'open_settings'),
              label: '設定画面を開く',
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('設定を開く'),
              ),
            ),
          ],
        ),
      );
      if (shouldOpenSettings == true) {
        await _service.openAppNotificationSettings();
      }
      return;
    }

    // Android 12+ 正確なアラーム権限
    if (_enabled) {
      final canExact = await _service.canScheduleExactAlarms();
      if (!canExact && mounted) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('正確な通知時刻について'),
            content: const Text(
              'Android 12以降では、正確な時刻に通知を届けるために特別な権限が必要です。'
              '設定画面で「正確なアラームの設定」を許可すると、'
              '指定した時刻により正確に通知が届くようになります。\n\n'
              '許可しない場合でも通知は届きますが、数分程度遅れることがあります。',
            ),
            actions: [
              SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'continue_without_exact'),
                label: '正確な通知なしで続ける',
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('このまま続ける'),
                ),
              ),
              SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'open_alarm_settings'),
                label: 'アラーム設定を開く',
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('設定を開く'),
                ),
              ),
            ],
          ),
        );
        if (shouldContinue == true) {
          await _service.openAlarmSettings();
        }
      }
    }

    await _settingsRepository.setMorningNotificationEnabled(
        _enabled && _morningEnabled);
    await _settingsRepository.setEveningNotificationEnabled(
        _enabled && _eveningEnabled);
    await _settingsRepository.setNoonNotificationEnabled(
        _enabled && _noonEnabled);

    await _service.saveSettings(
      enabled: _enabled,
      morningHour: _morningHour,
      morningMinute: _morningMinute,
      noonHour: _noonHour,
      noonMinute: _noonMinute,
      eveningHour: _eveningHour,
      eveningMinute: _eveningMinute,
    );
    await _service.scheduleAll(
      morningEnabled: _enabled && _morningEnabled,
      noonEnabled: _enabled && _noonEnabled,
      eveningEnabled: _enabled && _eveningEnabled,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_enabled ? '通知を設定しました！' : '通知をOFFにしました'),
        ),
      );
    }
  }

  String _fmt(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      key: AppKeys.notificationSettingsDialog,
      title: const Row(
        children: [
          Icon(Icons.notifications_active, color: Colors.amber),
          SizedBox(width: 8),
          Text('通知設定'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('通知を有効にする'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            contentPadding: EdgeInsets.zero,
          ),
          if (_enabled) ...[
            const Divider(),
            SwitchListTile(
              title: const Text('☀️ 朝の伝令（暁の刻）'),
              subtitle: Text(
                _morningEnabled
                    ? '「暁の刻だ。戦場へ赴け！」'
                    : '朝の通知は無効',
                style: const TextStyle(fontSize: 12),
              ),
              value: _morningEnabled,
              onChanged: (v) => setState(() => _morningEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_morningEnabled)
              ListTile(
                leading: const Text('☀️', style: TextStyle(fontSize: 22)),
                title: const Text('朝の伝令'),
                subtitle: const Text('「暁の刻だ。戦場へ赴け！」'),
                trailing: SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      SemanticTypes.button, 'pick_morning_time'),
                  label: '朝の通知時刻を変更',
                  child: TextButton(
                    onPressed: () => _pickTime(isMorning: true),
                    child: Text(
                      _fmt(_morningHour, _morningMinute),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            SwitchListTile(
              title: const Text('☀️ 昼の伝令（昼の刻）'),
              subtitle: Text(
                _noonEnabled
                    ? '「昼の刻。戦況を確認せよ。」'
                    : '昼の通知は無効',
                style: const TextStyle(fontSize: 12),
              ),
              value: _noonEnabled,
              onChanged: (v) => setState(() => _noonEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_noonEnabled)
              ListTile(
                leading: const Text('☀️', style: TextStyle(fontSize: 22)),
                title: const Text('昼の伝令'),
                subtitle: const Text('「昼の刻。戦況を確認せよ。」'),
                trailing: SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      SemanticTypes.button, 'pick_noon_time'),
                  label: '昼の通知時刻を変更',
                  child: TextButton(
                    onPressed: () => _pickTime(isMorning: false, isNoon: true),
                    child: Text(
                      _fmt(_noonHour, _noonMinute),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            SwitchListTile(
              title: const Text('🌙 夜の催促（宵の刻）'),
              subtitle: Text(
                _eveningEnabled
                    ? '「宵の刻。本日の戦果を記録せよ。」'
                    : '夜の通知は無効',
                style: const TextStyle(fontSize: 12),
              ),
              value: _eveningEnabled,
              onChanged: (v) => setState(() => _eveningEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_eveningEnabled)
              ListTile(
                leading: const Text('🌙', style: TextStyle(fontSize: 22)),
                title: const Text('夜の催促'),
                subtitle: const Text('「宵の刻。戦果を記録せよ。」'),
                trailing: SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      SemanticTypes.button, 'pick_evening_time'),
                  label: '夜の通知時刻を変更',
                  child: TextButton(
                    onPressed: () => _pickTime(isMorning: false),
                    child: Text(
                      _fmt(_eveningHour, _eveningMinute),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
          ],
          const Divider(),
          ListTile(
            leading:
                const Icon(Icons.bug_report, color: Colors.orange, size: 22),
            title: const Text('テスト通知を送信'),
            subtitle: const Text('即座に通知を表示して動作確認'),
            trailing: SemanticHelper.interactive(
              testId: SemanticHelper.createTestId(
                  SemanticTypes.button, 'send_test_notification'),
              label: 'テスト通知を送信',
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send, size: 16),
                label: const Text('送信'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final granted = await _service.requestPermission();
                  if (!granted && mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('通知の許可が得られませんでした')),
                    );
                    return;
                  }
                  await _service.sendTestNotification();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text(
                              'テスト通知を送信しました！ステータスバーを確認してください')),
                    );
                  }
                },
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'cancel_notification_settings'),
          label: '通知設定をキャンセル',
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
            child: const Text('キャンセル'),
          ),
        ),
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'save_notification_settings'),
          label: '通知設定を保存',
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}
