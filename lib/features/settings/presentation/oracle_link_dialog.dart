// 神託連携ダイアログ（旧: 寄合所の設定メニュー内に直書き）。
//
// 整理の一環で設定ハブへ移設した。振る舞いは移設前と同一。
// ユーザー ID をコピーして Hermes（天照）へ渡すと、AI から直接クエストを
// 追加できるようになる、という案内を出す。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rpg_todo/core/infrastructure/supabase_config.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';

/// 神託連携の案内を出す。Supabase 未設定でも開ける（コードが「Supabase未設定」になる）。
Future<void> showOracleLinkDialog(BuildContext context) async {
  final user = SupabaseConfig.url.isNotEmpty
      ? Supabase.instance.client.auth.currentUser
      : null;
  final userId = user?.id ??
      (SupabaseConfig.url.isNotEmpty ? '連携準備中...' : 'Supabase未設定');
  final email = user?.email ?? user?.userMetadata?['email'] as String?;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.link, color: Colors.amber),
          SizedBox(width: 8),
          Text('神託連携'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('このコードをHermes（天照）に伝えると、\nAIから直接タスクを追加できるようになります。'),
          if (email != null) ...[
            const SizedBox(height: 8),
            Text(
              'ログイン中: $email',
              style: TextStyle(fontSize: 12, color: _faintText(ctx)),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    userId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'コピー',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: userId));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('連携コードをコピーしました'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

/// 明度テーマに依らず読める副次文字（旧: guild_screen の `_faintText` と同値）。
Color _faintText(BuildContext context) {
  final palette = GamePalette.of(context);
  return palette.isLight ? palette.onSurfaceFaint : Colors.grey;
}
