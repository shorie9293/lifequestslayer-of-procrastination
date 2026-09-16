import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

/// 町画面の「茶屋 — 表示設定」セクション（テーマ切替 #45）
class ThemeSection extends StatelessWidget {
  const ThemeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();
    final isLight = settingsVM.themeMode == ThemeMode.light;

    return Column(
      key: AppKeys.themeSection,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.palette, color: Colors.white),
            SizedBox(width: 8),
            Text('表示設定 (ライト/ダーク)',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.black54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'ライトテーマに切り替える',
                    child: ElevatedButton.icon(
                      key: AppKeys.themeLightButton,
                      icon: const Icon(Icons.light_mode, size: 18),
                      label: const Text('明るく'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isLight ? Colors.amber : Colors.grey.shade700,
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () => settingsVM.setThemeMode(ThemeMode.light),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'ダークテーマに切り替える',
                    child: ElevatedButton.icon(
                      key: AppKeys.themeDarkButton,
                      icon: const Icon(Icons.dark_mode, size: 18),
                      label: const Text('暗く'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isLight ? Colors.grey.shade700 : Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => settingsVM.setThemeMode(ThemeMode.dark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
