import 'package:rpg_todo/features/google_todo/data/google_todo_gateway.dart';
import 'package:rpg_todo/features/google_todo/domain/google_todo_status.dart';

/// 起動時の自動同期。
///
/// アプリを閉じている間の変更を取り込むため、起動直後に一度だけ静かに同期する。
/// 失敗しても起動を妨げない（例外は握りつぶし、画面は手動同期で回復できる）。
/// 同期はサーバー側で走るため、ここは「合図を送る」だけの薄い層に留める。
class GoogleTodoAutoSync {
  GoogleTodoAutoSync({GoogleTodoGateway? gateway})
      : _gateway = gateway ?? EdgeFunctionGoogleTodoGateway();

  final GoogleTodoGateway _gateway;

  /// 連携済みなら1回同期する。未連携・失敗時は null を返す。
  Future<GoogleTodoSyncResult?> runOnce() async {
    try {
      final status = await _gateway.fetchStatus();
      if (!status.linked) return null;
      return await _gateway.sync();
    } on GoogleTodoException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
