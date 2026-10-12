import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// シェアカード画像を外部共有する抽象化。
abstract class AdventureShareCardExporter {
  const AdventureShareCardExporter();

  /// [png] を画像ファイルとして共有シートに渡す。 [text] は添付テキスト。
  Future<void> shareImage({required Uint8List png, required String text});
}

/// share_plus 実装。
class SharePlusAdventureShareCardExporter implements AdventureShareCardExporter {
  const SharePlusAdventureShareCardExporter();

  @override
  Future<void> shareImage({required Uint8List png, required String text}) async {
    await Share.shareXFiles(
      [
        XFile.fromData(
          png,
          mimeType: 'image/png',
          name: 'adventure_card.png',
        ),
      ],
      text: text,
    );
  }
}
