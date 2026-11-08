import 'dart:convert';
import 'dart:io';

import 'package:rpg_todo/core/infrastructure/shared_file_store.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';

/// Kozuchi アプリとのデータ連携サービスインターフェース
///
/// 単体テストで Mock に差し替え可能にするための抽象インターフェース。
/// rpg-task の既存パターン（ITaskRepository）に準拠。
abstract class IKozuchiQuestService {
  /// 共有ストレージからアクティブな試練クエストを読み込む。
  ///
  /// ファイルが存在しない場合、JSON のパースに失敗した場合、
  /// または必須フィールドが欠落している場合は null を返す。
  Future<KozuchiQuest?> fetchActiveQuest();
}

/// [IKozuchiQuestService] の実装。
///
/// 保存先は [SharedFileStore] が解決する（Android 実機では SAF の共有フォルダ）。
/// [filePath] を明示した場合のみ、そのパスを直接読む（試練用の後方互換）。
class FileKozuchiQuestService implements IKozuchiQuestService {
  /// 試練用の明示パス。null なら共有ストア経由。
  final String? filePath;

  const FileKozuchiQuestService({this.filePath});

  @override
  Future<KozuchiQuest?> fetchActiveQuest() async {
    try {
      final String? content;
      if (filePath != null) {
        final file = File(filePath!);
        content = await file.exists() ? await file.readAsString() : null;
      } else {
        final store = SharedFileStore.instance;
        if (!await store.ensureDirectory()) return null;
        content = await store.readString(SharedCrossAppFiles.kozuchiQuest);
      }

      if (content == null || content.trim().isEmpty) {
        return null;
      }

      final Map<String, dynamic> decoded =
          json.decode(content) as Map<String, dynamic>;
      return KozuchiQuest.fromJson(decoded);
    } catch (_) {
      // ファイル読み込みエラー、JSONパースエラー、
      // 必須フィールド欠落はすべて null として扱う
      return null;
    }
  }
}
