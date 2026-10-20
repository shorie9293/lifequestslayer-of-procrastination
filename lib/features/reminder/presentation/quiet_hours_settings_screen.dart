import 'package:flutter/material.dart';

import '../data/quiet_hours_repository.dart';
import '../domain/quiet_hours.dart';
import '../domain/quiet_hours_service.dart';
import '../domain/quiet_hours_settings.dart';
import '../infrastructure/hive_quiet_hours_repository.dart';
import 'quiet_hours_app_keys.dart';

/// 静穏時間（おやすみモード）の設定画面。
///
/// リポジトリ・現在時刻は注入可能（試練で Hive に触れずに検証するため）。
/// 保存時は必ず [QuietHoursRepository.save] に到達してから再読込する。
class QuietHoursSettingsScreen extends StatefulWidget {
  const QuietHoursSettingsScreen({
    super.key,
    QuietHoursRepository? repository,
    DateTime? now,
    ValueChanged<QuietHoursSettings>? onSaved,
  })  : _repository = repository,
        _now = now,
        _onSaved = onSaved;

  final QuietHoursRepository? _repository;
  final DateTime? _now;
  final ValueChanged<QuietHoursSettings>? _onSaved;

  @override
  State<QuietHoursSettingsScreen> createState() =>
      _QuietHoursSettingsScreenState();
}

class _QuietHoursSettingsScreenState extends State<QuietHoursSettingsScreen> {
  late final QuietHoursRepository _repository =
      widget._repository ?? HiveQuietHoursRepository();

  bool _loaded = false;
  QuietHoursSettings _settings = QuietHoursSettings.defaults();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final toSave = _settings;
    await _repository.save(toSave);
    await _load();
    widget._onSaved?.call(toSave);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('静穏時間を保存しました')),
    );
  }

  /// 現在時刻（注入された [QuietHoursSettingsScreen.now] か実時刻）。
  DateTime get _now => widget._now ?? DateTime.now();

  String get _statusText {
    final s = _settings;
    if (!s.enabled || s.startMinutes == s.endMinutes) return '';
    final within = QuietHoursService.isWithinQuietHours(
      _now,
      s.startMinutes,
      s.endMinutes,
    );
    return within ? 'ただいま静穏時間内です' : 'ただいま静穏時間外です';
  }

  String get _previewText {
    final s = _settings;
    if (!s.enabled) return '静穏時間は無効です';
    if (s.startMinutes == s.endMinutes) {
      return '開始と終了が同じため通知は抑止されません';
    }
    final range = '${s.startLabel}〜${s.endLabel}';
    if (s.policy == QuietHoursPolicy.skip) {
      return '$range の通知は行いません';
    }
    final overnight = s.endMinutes < s.startMinutes;
    final when = overnight ? '翌朝 ${s.endLabel}' : s.endLabel;
    return '$range の通知は$when に繰り延べます';
  }

  Widget _hourDropdown({
    required Key key,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      key: key,
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '時'),
      items: [
        for (var h = 0; h < 24; h++)
          DropdownMenuItem<int>(value: h, child: Text('$h時')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _minuteDropdown({
    required Key key,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      key: key,
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '分'),
      items: [
        for (var m = 0; m < 60; m += 5)
          DropdownMenuItem<int>(
            value: m,
            child: Text('${m.toString().padLeft(2, '0')}分'),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      key: QuietHoursAppKeys.screen,
      title: const Text('静穏時間（おやすみモード）'),
    );
    if (!_loaded) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final enabled = _settings.enabled;
    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            key: QuietHoursAppKeys.toggle,
            title: const Text('静穏時間を有効にする'),
            subtitle: const Text('この時間帯の通知を抑止します'),
            value: enabled,
            onChanged: (v) =>
                setState(() => _settings = _settings.copyWith(enabled: v)),
          ),
          if (enabled) ...[
            const SizedBox(height: 8),
            Text('開始時刻', style: Theme.of(context).textTheme.titleSmall),
            Row(
              children: [
                Expanded(
                  child: _hourDropdown(
                    key: QuietHoursAppKeys.startHour,
                    value: _settings.startHour,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(startHour: v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _minuteDropdown(
                    key: QuietHoursAppKeys.startMinute,
                    value: _settings.startMinute,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(startMinute: v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('終了時刻', style: Theme.of(context).textTheme.titleSmall),
            Row(
              children: [
                Expanded(
                  child: _hourDropdown(
                    key: QuietHoursAppKeys.endHour,
                    value: _settings.endHour,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(endHour: v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _minuteDropdown(
                    key: QuietHoursAppKeys.endMinute,
                    value: _settings.endMinute,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(endMinute: v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('静穏時間中の通知', style: Theme.of(context).textTheme.titleSmall),
            for (final policy in QuietHoursPolicy.values)
              RadioListTile<QuietHoursPolicy>(
                key: QuietHoursAppKeys.policyRadio(policy),
                title: Text(policy.label),
                value: policy,
                groupValue: _settings.policy,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _settings = _settings.copyWith(policy: v));
                },
              ),
          ],
          const SizedBox(height: 16),
          Text(
            _previewText,
            key: QuietHoursAppKeys.preview,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_statusText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _statusText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: QuietHoursAppKeys.saveButton,
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
