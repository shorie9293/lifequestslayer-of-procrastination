import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_settings_screen.dart';
import 'package:rpg_todo/core/crash/crash_log_screen.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';
import 'package:rpg_todo/features/about/presentation/about_app_keys.dart';
import 'package:rpg_todo/features/about/presentation/about_screen.dart';
import 'package:rpg_todo/features/account_deletion/presentation/account_deletion_app_keys.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_sharer_impl.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/data/backup_restore_flow.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_status.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_app_keys.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/reminder/presentation/quiet_hours_settings_screen.dart';
import 'package:rpg_todo/features/reminder/presentation/reminder_settings_screen.dart';
import 'package:rpg_todo/features/settings/presentation/cross_app_link_status_screen.dart';
import 'package:rpg_todo/features/settings/presentation/reduce_motion_settings_screen.dart';
import 'package:rpg_todo/features/shared/presentation/settings_write_error_listener.dart';
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

  Future<void> applyBackup(String json) => applyBackupJson(
        json: json,
        restorePlayer: playerVM.restorePlayer,
        setTasks: taskVM.setTasks,
        restoreBoxes: storage.restore,
        // 復元で設定（通知時刻）が巻き戻るため、起動時と同じ2手で予約を貼り直す。
        // 投げっぱなしにして復元UIを待たせない。例外は関数内で握る。
        onRestored: () async {
          unawaited(rescheduleNotificationsAfterRestore());
        },
      );

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
        statusStore: FileAutoBackupStatusStore(),
        backupStorage: storage,
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
    this.accountDeletionScreenBuilder,
    this.autoBackupStatusStore,
    this.crossAppLinkStatusScreenBuilder,
  });

  final WidgetBuilder? reminderScreenBuilder;

  /// お休み券画面のビルダー（試練での注入用。未指定なら実画面）。
  final WidgetBuilder? streakFreezeScreenBuilder;

  /// 振り返りの杜画面のビルダー（試練での注入用。未指定なら実画面）。
  final WidgetBuilder? reflectionGroveScreenBuilder;

  /// アカウント削除画面のビルダー。
  ///
  /// **未指定（null）ならタイル自体を出さない** — 既存試練の後方互換と、
  /// 認証基盤の無い環境での誤操作防止を兼ねる。本番は town_screen から
  /// `buildProductionAccountDeletionScreen` を渡す。
  final WidgetBuilder? accountDeletionScreenBuilder;

  /// 自動バックアップの成否の読み出し元。
  ///
  /// 未指定なら従来どおりの説明文のみ（後方互換）。指定すると、連続失敗が
  /// 閾値以上なら警告文言と警告アイコンに切り替える。
  final AutoBackupStatusStore? autoBackupStatusStore;

  /// 連携状況（現世間の受け渡し）画面のビルダー。
  ///
  /// 未指定なら実画面 [CrossAppLinkStatusScreen]（アプリ共有の記録口）を開く。
  final WidgetBuilder? crossAppLinkStatusScreenBuilder;

  /// 自動バックアップの導線1行。
  ///
  /// [autoBackupStatusStore] 未注入なら従来の説明文のみ（後方互換）、
  /// 注入時は連続失敗を読み出して警告文言へ切り替える。
  Widget _autoBackupTile(BuildContext context) {
    final store = autoBackupStatusStore;
    if (store == null) {
      return ListTile(
        key: AutoBackupKeys.entryFromSettings,
        title: const Text('自動バックアップ'),
        subtitle: const Text('保存済みバックアップの閲覧・復元・共有'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openAutoBackup(context),
      );
    }
    return _AutoBackupStatusTile(
      statusStore: store,
      onTap: () => _openAutoBackup(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return Scaffold(
      key: AppKeys.settingsHubScreen,
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // 設定の保存失敗を無音にしない（結果型の読み手を必ず1つ置く）
          const SettingsWriteErrorListener(child: SizedBox.shrink()),
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
          _autoBackupTile(context),
          // 末尾追加: 現世間の受け渡し（最終送信／最終受信の可視化）
          ListTile(
            key: AppKeys.crossAppLinkStatusEntry,
            title: const Text('連携状況（現世間の受け渡し）'),
            subtitle: const Text('最終送信・最終受信の成否／時刻／件数'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: crossAppLinkStatusScreenBuilder ??
                    (_) => const CrossAppLinkStatusScreen(),
              ),
            ),
          ),
          // 末尾追加: アカウント削除（退会）。ビルダー未注入なら導線を出さない。
          if (accountDeletionScreenBuilder != null)
            ListTile(
              key: AccountDeletionAppKeys.entryFromSettings,
              title: const Text('アカウント削除'),
              subtitle: const Text('退会して端末内のデータをすべて削除します'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: accountDeletionScreenBuilder!,
                ),
              ),
            ),
          // 末尾追加: 不具合の報告（端末内クラッシュログの閲覧・コピー）
          const CrashReportTile(),
        ],
      ),
    );
  }
}

/// 自動バックアップの状態を読み出して導線を組み立てる小さな器。
///
/// 設定ハブ自体は StatelessWidget のままにし、非同期の読み出しだけを
/// この子へ閉じ込める。連続失敗が閾値以上なら警告文言＋警告アイコン。
class _AutoBackupStatusTile extends StatefulWidget {
  const _AutoBackupStatusTile({
    required this.statusStore,
    required this.onTap,
  });

  final AutoBackupStatusStore statusStore;
  final VoidCallback onTap;

  @override
  State<_AutoBackupStatusTile> createState() => _AutoBackupStatusTileState();
}

class _AutoBackupStatusTileState extends State<_AutoBackupStatusTile> {
  AutoBackupStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    AutoBackupStatus? status;
    try {
      status = await widget.statusStore.read();
    } catch (_) {
      status = null;
    }
    if (!mounted) return;
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final degraded = _status?.isDegraded == true;
    return ListTile(
      key: AutoBackupKeys.entryFromSettings,
      leading: degraded
          ? Icon(
              Icons.warning_amber_outlined,
              color: Theme.of(context).colorScheme.error,
            )
          : null,
      title: const Text('自動バックアップ'),
      subtitle: Text(
        degraded
            ? '自動バックアップに失敗しています'
                '（${_status!.consecutiveFailures}回連続）'
            : '保存済みバックアップの閲覧・復元・共有',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: widget.onTap,
    );
  }
}
