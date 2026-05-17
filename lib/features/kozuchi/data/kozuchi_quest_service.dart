import 'dart:convert';
import 'dart:io';

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

/// ファイルベースの [IKozuchiQuestService] 実装
///
/// Kozuchi アプリが書き出す共有ストレージの JSON ファイルを読み込む。
/// ファイルパスはコンストラクタで注入可能（デフォルト:
/// `/data/local/tmp/takamagahara_shared/kozuchi_quest.json`）。
class FileKozuchiQuestService implements IKozuchiQuestService {
  final String filePath;

  /// [filePath] を指定しない場合、デフォルトの共有ストレージパスを使用する。
  const FileKozuchiQuestService({
    this.filePath = '/data/local/tmp/takamagahara_shared/kozuchi_quest.json',
  });

  @override
  Future<KozuchiQuest?> fetchActiveQuest() async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return null;
      }

      final Map<String, dynamic> decoded = json.decode(content) as Map<String, dynamic>;
      return KozuchiQuest.fromJson(decoded);
    } catch (_) {
      // ファイル読み込みエラー、JSONパースエラー、
      // 必須フィールド欠落はすべて null として扱う
      return null;
    }
  }
}
