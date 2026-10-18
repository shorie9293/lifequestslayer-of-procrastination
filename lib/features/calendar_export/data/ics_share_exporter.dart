import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// .ics 文字列を外部共有する抽象化（試練で差し替え可能）。
abstract class IcsShareExporter {
  const IcsShareExporter();

  Future<void> share({
    required String ics,
    required String fileName,
    required String text,
  });
}

/// share_plus による実装。
class SharePlusIcsShareExporter implements IcsShareExporter {
  const SharePlusIcsShareExporter();

  @override
  Future<void> share({
    required String ics,
    required String fileName,
    required String text,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(ics));
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'text/calendar',
            name: fileName,
          ),
        ],
        text: text,
      ),
    );
  }
}
