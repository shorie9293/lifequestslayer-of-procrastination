import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/reminder/presentation/reminder_settings_screen.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/town/presentation/widgets/sfx_volume_section.dart';
import 'package:rpg_todo/features/town/presentation/widgets/theme_section.dart';

/// 設定ハブ画面（#86）— 分散していた設定を一覧・操作する単一画面。
class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key, this.reminderScreenBuilder});

  final WidgetBuilder? reminderScreenBuilder;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return Scaffold(
      key: AppKeys.settingsHubScreen,
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const ThemeSection(),
          ListTile(
            title: const Text('文字サイズ'),
            subtitle: Slider(
              key: AppKeys.settingsFontSizeSlider,
              min: 0.7,
              max: 1.2,
              divisions: 10,
              value: vm.fontSizeScale.clamp(0.7, 1.2),
              onChanged: (v) => vm.setFontSizeScale(v),
            ),
            trailing: Text(
              '${(vm.fontSizeScale * 100).round()}%',
              key: AppKeys.settingsFontSizeLabel,
            ),
          ),
          const SfxVolumeSection(),
          SwitchListTile(
            key: AppKeys.settingsSfxEnabledSwitch,
            title: const Text('効果音'),
            value: vm.isSfxEnabled,
            onChanged: (v) => vm.setSfxEnabled(v),
          ),
          SwitchListTile(
            key: AppKeys.settingsMorningNotificationSwitch,
            title: const Text('朝の通知'),
            value: vm.isMorningNotificationEnabled,
            onChanged: (v) => vm.setMorningNotificationEnabled(v),
          ),
          ListTile(
            key: AppKeys.settingsReminderTile,
            title: const Text('リマインダー設定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: reminderScreenBuilder ?? (_) => const ReminderSettingsScreen(),
              ),
            ),
          ),
          SwitchListTile(
            key: AppKeys.settingsKnowledgeQuestSwitch,
            title: const Text('KNOWLEDGEクエスト'),
            value: vm.isKnowledgeQuestEnabled,
            onChanged: (v) => vm.setKnowledgeQuestEnabled(v),
          ),
          SwitchListTile(
            key: AppKeys.settingsBattleSceneSwitch,
            title: const Text('戦闘シーン演出'),
            value: vm.isBattleSceneEnabled,
            onChanged: (v) => vm.setBattleSceneEnabled(v),
          ),
        ],
      ),
    );
  }
}
