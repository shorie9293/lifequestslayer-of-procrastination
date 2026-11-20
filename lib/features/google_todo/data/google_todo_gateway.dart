import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rpg_todo/core/infrastructure/supabase_config.dart';
import 'package:rpg_todo/features/google_todo/domain/google_todo_status.dart';

/// Google ToDo 連携の通信抽象。
///
/// 実装を差し替えられるようにして、画面の試練ではフェイクを注入する。
/// 端末・ネットワークに触るのはこの層だけ。
abstract class GoogleTodoGateway {
  /// 連携状態と最終同期を取得する。
  Future<GoogleTodoStatus> fetchStatus();

  /// 同意画面の URL を発行する（PKCE はサーバー側で生成）。
  Future<String> startLink();

  /// Google のタスクリスト一覧。
  Future<List<GoogleTodoList>> fetchLists();

  /// 同期するタスクリストを選ぶ。
  Future<void> selectList({required String id, String? title});

  /// 連携を解除する（トークン破棄）。
  Future<void> unlink();

  /// 双方向同期を1回実行する。
  Future<GoogleTodoSyncResult> sync();
}

/// 通信・認証・権限の失敗。画面は [message] をそのまま出せる。
class GoogleTodoException implements Exception {
  const GoogleTodoException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'GoogleTodoException($statusCode): $message';
}

/// ステータスコードから利用者向け文言を決める（純粋関数）。
String describeGoogleTodoFailure(int statusCode, String? serverMessage) {
  switch (statusCode) {
    case 401:
      return 'ログインが必要です。Googleでログインし直してください。';
    case 403:
      return 'Google ToDo が未連携です。先に連携してください。';
    case 404:
      return '連携機能が見つかりません（アプリの更新が必要です）。';
    case 429:
      return 'Google側の回数を超えました。しばらく待ってから再度お試しください。';
    case 502:
      return 'Google ToDo への通信に失敗しました。時間をおいて再度お試しください。';
  }
  if (serverMessage != null && serverMessage.isNotEmpty) {
    return '同期できませんでした（$serverMessage）';
  }
  return '同期できませんでした（コード$statusCode）';
}

/// Edge Function `google-todo` を叩く実装。
class EdgeFunctionGoogleTodoGateway implements GoogleTodoGateway {
  EdgeFunctionGoogleTodoGateway({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? accessToken,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? '${SupabaseConfig.url}/functions/v1/google-todo',
        _accessToken = accessToken ?? _defaultAccessToken;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _accessToken;

  static Future<String?> _defaultAccessToken() async =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw const GoogleTodoException('ログインが必要です。Googleでログインし直してください。', statusCode: 401);
    }
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    http.Response res;
    try {
      res = switch (method) {
        'POST' => await _client.post(uri, headers: headers, body: jsonEncode(body ?? {})),
        _ => await _client.get(uri, headers: headers),
      };
    } catch (_) {
      throw const GoogleTodoException(
        '通信に失敗しました（ネットワークをご確認ください）',
        statusCode: 0,
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return const <String, dynamic>{};
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    }
    String? message;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] is String) {
        message = decoded['error'] as String;
      }
    } catch (_) {
      message = null;
    }
    throw GoogleTodoException(
      describeGoogleTodoFailure(res.statusCode, message),
      statusCode: res.statusCode,
    );
  }

  @override
  Future<GoogleTodoStatus> fetchStatus() async =>
      GoogleTodoStatus.fromJson(await _request('GET', '/status'));

  @override
  Future<String> startLink() async {
    final json = await _request('POST', '/start');
    final url = json['authorizeUrl'];
    if (url is! String || url.isEmpty) {
      throw const GoogleTodoException('同意画面のURLを取得できませんでした');
    }
    return url;
  }

  @override
  Future<List<GoogleTodoList>> fetchLists() async {
    final json = await _request('GET', '/lists');
    final raw = json['lists'];
    if (raw is! List) return const <GoogleTodoList>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(GoogleTodoList.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> selectList({required String id, String? title}) async {
    await _request('POST', '/select-list', body: {'listId': id, 'listTitle': title});
  }

  @override
  Future<void> unlink() async {
    await _request('POST', '/unlink');
  }

  @override
  Future<GoogleTodoSyncResult> sync() async {
    final json = await _request('POST', '/sync');
    return GoogleTodoSyncResult.fromJson(json);
  }
}
