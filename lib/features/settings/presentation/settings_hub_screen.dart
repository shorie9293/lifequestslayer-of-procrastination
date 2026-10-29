import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_settings_screen.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';
import 'package:rpg_todo/features/about/presentation/about_app_keys.dart';
import 'package:rpg_todo/features/about/presentation/about_screen.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_sharer_impl.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_app_keys.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/reminder/presentation/quiet_hours_settings_screen.dart';
import 'package:rpg_todo/features/reminder/presentation/reminder_settings_screen.dart';
import 'package:rpg_todo/features/settings/presentation/reduce_motion_settings_screen.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/streak_freeze/presentation/streak_freeze_app_keys.dart';
import 'package:rpg_todo/features/streak_freeze/presentation/streak_freeze_screen.dart';
import 'package:rpg_todo/features/temple/data/backup_storage.dart';
import 'package:rpg_todo/features/town/presentation/reflection_grove_screen.dart';
import 'package:rpg_todo/features/town/presentation/widgets/sfx_volume_section.dart';
import 'package:rpg_todo/features/town/presentation/widgets/theme_section.dart';

/// 勤行リマインダー画面から静穏時間画面への導線（本番結線）。
Widget _buildQuietHoursScreen(BuildContext context) =>
    const QuietHoursSettingsScreen();

/// 自動バックアップ画面を本番依存で開く（唯一の導線）。
void _openAutoBackup(BuildContext context) {
  final store = FileAutoBackupStore();
  final storage = HiveBackupStorage();
  final playerVM = context.read<PlayerViewModel>();
  final taskVM = context.read<TaskViewModel>();

  Future<String> buildCurrentJson() async {
    final boxes = await storage.capture();
    return FullBackupService().encode(
      player: playerVM.player,
      tasks: taskVM.tasks,
      boxes: boxes,
      exportedAt: DateTime.now(),
    );
  }

  Future<void> applyBackup(String json) async {
    final data = FullBackupService().decode(json);
    if (data == null) {
      throw const FormatException('バックアップ形式が不正です');
    }
    playerVM.restorePlayer(data.player);
    taskVM.setTasks(data.tasks);
    await storage.restore(data.boxes);
  }

  final restorer = AutoBackupRestorerImpl(
    store: store,
    buildCurrentJson: buildCurrentJson,
    applyBackup: applyBackup,
  );

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AutoBackupScreen(
        store: store,
        restorer: restorer,
        sharer: const AutoBackupSharerImpl(),
        onBackupNow: () async {
          final json = await buildCurrentJson();
          await store.write(
            AutoBackupPolicy.fileNameFor(DateTime.now()),
            json,
          );
        },
      ),
    ),
  );
}

/// 設定ハブ画面（#86）— 分散していた設定を一覧・操作する単一画面。
class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({
    super.key,
    this.reminderScreenBuilder,
    this.streakFreezeScreenBuilder,
    this.reflectionGroveScreenBuilder,
  });

  final WidgetBuilder? reminderScreenBuilder;

  /// お休み券画面のビルダー（試練での注入用。未指定なら実画面）。
  final WidgetBuilder? streakFreezeScreenBuilder;

  /// 振り返りの杜画面のビルダー（試練での注入用。未指定なら実画面）。
  final WidgetBuilder? reflectionGroveScreenBuilder;

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
                builder: reminderScreenBuilder ??
                    (_) => const ReminderSettingsScreen(
                          quietHoursScreenBuilder: _buildQuietHoursScreen,
                        ),
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
          ListTile(
            key: AppKeys.appLockSettingsTile,
            title: const Text('アプリロック'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AppLockSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            key: StreakFreezeKeys.entryFromSettings,
            title: const Text('連続記録お休み券'),
            subtitle: const Text('連続記録を1日分守る券の残数と履歴'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: streakFreezeScreenBuilder ??
                    (_) => const StreakFreezeScreen(),
              ),
            ),
          ),
          ListTile(
            key: AboutAppKeys.entryFromSettings,
            title: const Text('アプリについて'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AboutScreen(),
              ),
            ),
          ),
          // 末尾追加: 「動きを減らす」（WCAG 2.3.3 配慮）
          ListTile(
            key: AppKeys.settingsReduceMotionTile,
            title: const Text('動きを減らす'),
            subtitle: const Text('アニメーションの抑制（前庭障害への配慮）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReduceMotionSettingsScreen(),
              ),
            ),
          ),
          // 末尾追加: 振り返りの杜（学びログ・週次報告・内省バッジ）
          ListTile(
            key: AppKeys.reflectionGroveEntry,
            title: const Text('振り返りの杜'),
            subtitle: const Text('学びログ・週次報告・内省バッジ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: reflectionGroveScreenBuilder ??
                    (_) => const ReflectionGroveScreen(),
              ),
            ),
          ),
          // 末尾追加: 自動バックアップの閲覧・復元・共有
          ListTile(
            key: AutoBackupKeys.entryFromSettings,
            title: const Text('自動バックアップ'),
            subtitle: const Text('保存済みバックアップの閲覧・復元・共有'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openAutoBackup(context),
          ),
        ],
      ),
    );
  }
}
