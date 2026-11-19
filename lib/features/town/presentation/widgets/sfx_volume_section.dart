import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/battle/domain/sfx_volume.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

/// 町画面の「茶屋 — 音の設定」セクション（改善提案#67 効果音の音量調整）。
///
/// 効果音のON/OFF（[SettingsViewModel.isSfxEnabled]）とは独立に、
/// 音量（0.0〜1.0）をスライダーと定型値チップで設定する。
class SfxVolumeSection extends StatelessWidget {
  const SfxVolumeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    final settingsVM = context.watch<SettingsViewModel>();
    final setting = SfxVolumeSetting(settingsVM.sfxVolume);

    return Column(
      key: AppKeys.sfxVolumeSection,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.volume_up, color: palette.onSurface),
            const SizedBox(width: 8),
            Text('音の設定 (効果音)',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: palette.onSurface)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: palette.isLight ? palette.cardBackgroundStrong : Colors.black54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      setting.isMuted ? Icons.volume_off : Icons.volume_down,
                      color: palette.onSurfaceMuted,
                      size: 20,
                    ),
                    Expanded(
                      child: Slider(
                        key: AppKeys.sfxVolumeSlider,
                        value: setting.value,
                        min: SfxVolumeSetting.minValue,
                        max: SfxVolumeSetting.maxValue,
                        divisions: 20,
                        label: setting.percentLabel,
                        activeColor: palette.readable(Colors.amberAccent),
                        onChanged: (v) => settingsVM.setSfxVolume(v),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 64),
                      child: Text(
                        setting.isMuted
                            ? '${setting.percentLabel} 消音'
                            : '${setting.percentLabel} ${setting.label}',
                        key: AppKeys.sfxVolumeValueLabel,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            color: palette.onSurface, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < SfxVolumeSetting.presets.length; i++)
                      ChoiceChip(
                        key: AppKeys.sfxVolumePreset(i),
                        label: Text(
                            SfxVolumeSetting(SfxVolumeSetting.presets[i])
                                .label),
                        selected:
                            setting.value == SfxVolumeSetting.presets[i],
                        onSelected: (_) =>
                            settingsVM.setSfxVolume(SfxVolumeSetting.presets[i]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
