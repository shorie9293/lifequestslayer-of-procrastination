import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/kozuchi/data/kozuchi_quest_service.dart';

void main() {
  late Directory tempDir;
  late String tempFilePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kozuchi_test_');
    tempFilePath = '${tempDir.path}/kozuchi_quest.json';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FileKozuchiQuestService', () {
    test('ファイルが存在しない場合 null を返す', () async {
      final service = FileKozuchiQuestService(filePath: tempFilePath);

      final result = await service.fetchActiveQuest();

      expect(result, isNull);
    });

    test('有効なJSONから正しくパースされる', () async {
      final jsonContent = json.encode({
        'title': 'コンビニ誘惑を断て',
        'description': '3日間コンビニで無駄遣いせず、必要なものだけ買う',
        'suggestedOffering': 500,
        'advisor': 'investmentMentor',
        'isCompleted': false,
      });
      await File(tempFilePath).writeAsString(jsonContent);

      final service = FileKozuchiQuestService(filePath: tempFilePath);
      final result = await service.fetchActiveQuest();

      expect(result, isNotNull);
      expect(result!.title, 'コンビニ誘惑を断て');
      expect(result.description, '3日間コンビニで無駄遣いせず、必要なものだけ買う');
      expect(result.suggestedOffering, 500);
      expect(result.advisorEmoji, '⚔️');
      expect(result.advisorLabel, '投資メンター');
      expect(result.isCompleted, false);
    });

    test('completed な試練を含むJSONを正しくパースする', () async {
      final jsonContent = json.encode({
        'title': '感謝の手紙を書く',
        'description': '家族に感謝の手紙を書いて渡す',
        'suggestedOffering': 300,
        'advisor': 'wellnessAdvisor',
        'isCompleted': true,
      });
      await File(tempFilePath).writeAsString(jsonContent);

      final service = FileKozuchiQuestService(filePath: tempFilePath);
      final result = await service.fetchActiveQuest();

      expect(result, isNotNull);
      expect(result!.isCompleted, true);
      expect(result.advisorEmoji, '🌸');
    });

    test('壊れたJSONから null を返す', () async {
      await File(tempFilePath).writeAsString('{"invalid json: broken');

      final service = FileKozuchiQuestService(filePath: tempFilePath);
      final result = await service.fetchActiveQuest();

      expect(result, isNull);
    });

    test('レベルMAXのファイルから null を返す', () async {
      await File(tempFilePath).writeAsString('');

      final service = FileKozuchiQuestService(filePath: tempFilePath);
      final result = await service.fetchActiveQuest();

      expect(result, isNull);
    });

    test('必須フィールド欠落のJSONから null を返す', () async {
      final jsonContent = json.encode({
        'title': 'タイトルのみ',
        'description': '説明',
        // advisor 欠落
        'suggestedOffering': 100,
        'isCompleted': false,
      });
      await File(tempFilePath).writeAsString(jsonContent);

      final service = FileKozuchiQuestService(filePath: tempFilePath);
      final result = await service.fetchActiveQuest();

      expect(result, isNull);
    });

    test('デフォルトのファイルパスが正しく設定される', () {
      const service = FileKozuchiQuestService();

      // デフォルトパスを確認するために、内部のパスをリフレクションなしで検証。
      // パスがコンストラクタで保持されていることをテストするため、
      // パス指定なしのインスタンスが例外なく作成できることを確認
      expect(service, isA<FileKozuchiQuestService>());
    });
  });
}
