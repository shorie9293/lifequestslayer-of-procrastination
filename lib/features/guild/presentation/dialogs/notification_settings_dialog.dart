import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/infrastructure/notification_service.dart';

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

  bool _enabled = true;
  int _morningHour = 8;
  int _morningMinute = 0;
  int _eveningHour = 21;
  int _eveningMinute = 0;

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
    setState(() {
      _enabled = enabled;
      _morningHour = mh;
      _morningMinute = mm;
      _eveningHour = eh;
      _eveningMinute = em;
      _loading = false;
    });
  }

  Future<void> _pickTime({required bool isMorning}) async {
    final initial = TimeOfDay(
      hour: isMorning ? _morningHour : _eveningHour,
      minute: isMorning ? _morningMinute : _eveningMinute,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isMorning) {
        _morningHour = picked.hour;
        _morningMinute = picked.minute;
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('設定を開く'),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('このまま続ける'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('設定を開く'),
              ),
            ],
          ),
        );
        if (shouldContinue == true) {
          await _service.openAlarmSettings();
        }
      }
    }

    await _service.saveSettings(
      enabled: _enabled,
      morningHour: _morningHour,
      morningMinute: _morningMinute,
      eveningHour: _eveningHour,
      eveningMinute: _eveningMinute,
    );
    await _service.scheduleAll();
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
          const Divider(),
          ListTile(
            enabled: _enabled,
            leading: const Text('☀️', style: TextStyle(fontSize: 22)),
            title: const Text('朝の伝令'),
            subtitle: const Text('「本日の依頼書が届いておるぞ！」'),
            trailing: TextButton(
              onPressed: _enabled ? () => _pickTime(isMorning: true) : null,
              child: Text(
                _fmt(_morningHour, _morningMinute),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            enabled: _enabled,
            leading: const Text('🍺', style: TextStyle(fontSize: 22)),
            title: const Text('夜の催促'),
            subtitle: const Text('「仕留めた報告を忘れるでないぞ！」'),
            trailing: TextButton(
              onPressed: _enabled ? () => _pickTime(isMorning: false) : null,
              child: Text(
                _fmt(_eveningHour, _eveningMinute),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          ListTile(
            leading:
                const Icon(Icons.bug_report, color: Colors.orange, size: 22),
            title: const Text('テスト通知を送信'),
            subtitle: const Text('即座に通知を表示して動作確認'),
            trailing: ElevatedButton.icon(
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
                    const SnackBar(content: Text('通知の許可が得られませんでした')),
                  );
                  return;
                }
                await _service.sendTestNotification();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('テスト通知を送信しました！ステータスバーを確認してください')),
                  );
                }
              },
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
