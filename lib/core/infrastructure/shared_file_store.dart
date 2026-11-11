import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:rpg_todo/core/infrastructure/cross_app_link_status.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status_store.dart';

/// 現世（アプリ）をまたいで受け渡す共有ファイルの**契約**。
///
/// ファイル名は 5 現世で共有される契約なので、**ここ以外に文字列を書かない**。
/// 変更するときは 5 現世すべてを同時に変えること。
class SharedCrossAppFiles {
  const SharedCrossAppFiles._();

  /// rpg-task → kozuchi: 敵討伐イベント（単一 JSON・kozuchi が読取後に削除）
  static const String rpgEnemyDefeatJson = 'rpg_enemy_defeat_events.json';

  /// rpg-task → kozuchi: 敵討伐イベント（追記専用 jsonl）
  static const String rpgEnemyDefeatJsonl = 'rpg_enemy_defeat_events.jsonl';

  /// tsundoku-quest → rpg-task: 読了報酬イベント（追記専用 jsonl）
  static const String tsundokuRewardEvents = 'tsundoku_reward_events.jsonl';

  /// tsundoku-quest → kozuchi: 読了イベント（単一 JSON）
  static const String tsundokuBookEvents = 'tsundoku_book_events.json';

  /// tsundoku-quest → kozuchi: 読了通知（単一 JSON・読了時のみ）
  ///
  /// rpg-task 自身は読まないが、ファイル名は**5現世共通の契約**ゆえ
  /// 表に載せておく（各現世が独自に文字列を持ち始めると静かに0件になる）。
  static const String tsundokuBookCompleted = 'tsundoku_book_completed.json';

  /// election-game → rpg-task: 選挙参加報酬イベント（追記専用 jsonl）
  static const String electionRewardEvents = 'election_reward_events.jsonl';

  /// book-review-app → rpg-task: 読了報酬イベント（追記専用 jsonl）
  static const String bookReviewRewardEvents = 'book_review_reward_events.jsonl';

  /// kozuchi → rpg-task: アクティブな試練クエスト（単一 JSON）
  static const String kozuchiQuest = 'kozuchi_quest.json';
}

/// 共有ストレージの読み書きで起きた失敗。
///
/// かつて `catch (_) {}` で無音に捨てていた失敗を、**必ず上位へ伝える**ための型。
/// 呼び出し側は「ベストエフォート」と言いつつも、この例外をログに残すこと。
class SharedStorageException implements Exception {
  const SharedStorageException(this.operation, this.fileName, this.cause);

  /// 失敗した操作（write / append / read / delete / list / ensureDirectory）
  final String operation;

  /// 対象ファイル名
  final String fileName;

  /// 元の例外（握りつぶさず保持する）
  final Object? cause;

  @override
  String toString() =>
      'SharedStorageException($operation, $fileName): $cause';
}

/// 共有ファイルストアの抽象。
///
/// 実装は 2 つ:
/// - [FileSharedFileStore] — 実ファイルパス（テスト・デスクトップ・Linux）
/// - `AndroidSharedFileStore` — Storage Access Framework（Android 実機）
///
/// 13 ファイルの直書きを全てこの抽象の裏に隠す。
abstract class ISharedFileStore {
  /// 保存先が既に使える状態か確かめる。**UI は出さない**。
  /// false を返したら「共有は無効」＝連携機能は動かない（黙って成功にしない）。
  Future<bool> ensureDirectory();

  /// ユーザーにフォルダ選択を求める（連携画面から明示的に呼ぶ）。
  Future<bool> chooseDirectory();

  /// ファイルを丸ごと上書きする。
  Future<void> writeString(String fileName, String content);

  /// ファイルに1行追記する（末尾に改行を付ける）。
  Future<void> appendLine(String fileName, String line);

  /// ファイル全体を読む。存在しなければ null。
  Future<String?> readString(String fileName);

  /// ファイルを削除する。存在しなければ false。
  Future<bool> delete(String fileName);

  /// ファイルが存在するか。
  Future<bool> exists(String fileName);

  /// 共有フォルダ直下のファイル名一覧。
  Future<List<String>> listFiles();
}

/// 実ファイルパスを使う [ISharedFileStore]。
///
/// テスト（一時ディレクトリ）とデスクトップ/Linux で使う。
class FileSharedFileStore implements ISharedFileStore {
  FileSharedFileStore(this.directory);

  final Directory directory;

  File _file(String fileName) => File('${directory.path}/$fileName');

  @override
  Future<bool> ensureDirectory() async {
    try {
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
      unawaited(
        CrossAppLinkStatusRecorder.instance.recordFolderReady(true),
      );
      return true;
    } on Object {
      unawaited(
        CrossAppLinkStatusRecorder.instance.recordFolderReady(false),
      );
      return false;
    }
  }

  /// 実ファイル実装では選択 UI は不要（常に [ensureDirectory] と同じ）。
  @override
  Future<bool> chooseDirectory() => ensureDirectory();

  @override
  Future<void> writeString(String fileName, String content) async {
    final file = _file(fileName);
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(content, flush: true);
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSent(count: 1, fileName: fileName),
      );
    } on Object catch (e) {
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSendFailure(e, fileName: fileName),
      );
      throw SharedStorageException('write', fileName, e);
    }
  }

  @override
  Future<void> appendLine(String fileName, String line) async {
    final file = _file(fileName);
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSent(count: 1, fileName: fileName),
      );
    } on Object catch (e) {
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSendFailure(e, fileName: fileName),
      );
      throw SharedStorageException('append', fileName, e);
    }
  }

  @override
  Future<String?> readString(String fileName) async {
    final file = _file(fileName);
    try {
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      unawaited(
        CrossAppLinkStatusRecorder.instance.recordReceived(
          count: CrossAppLinkStatusText.countLines(content),
          fileName: fileName,
        ),
      );
      return content;
    } on Object catch (e) {
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordReceiveFailure(e, fileName: fileName),
      );
      throw SharedStorageException('read', fileName, e);
    }
  }

  @override
  Future<bool> delete(String fileName) async {
    final file = _file(fileName);
    try {
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } on Object catch (e) {
      throw SharedStorageException('delete', fileName, e);
    }
  }

  @override
  Future<bool> exists(String fileName) async {
    try {
      return await _file(fileName).exists();
    } on Object catch (e) {
      throw SharedStorageException('exists', fileName, e);
    }
  }

  @override
  Future<List<String>> listFiles() async {
    try {
      if (!directory.existsSync()) return const [];
      return directory
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList(growable: false);
    } on Object catch (e) {
      throw SharedStorageException('list', '*', e);
    }
  }
}

/// Android の Storage Access Framework 経由で共有フォルダを読み書きする。
///
/// `SharedStorageBridge.kt` の MethodChannel を叩く。
/// - 初回: [ensureDirectory] がフォルダ選択 UI を出し、URI を永続化する
/// - 2回目以降: 保存済み URI を使う（再起動後も有効）
///
/// **MediaStore.Downloads 単独では他アプリから読めない**（公式ドキュメント明記）
/// ため、読み取りも SAF で行う。
class AndroidSharedFileStore implements ISharedFileStore {
  AndroidSharedFileStore({
    MethodChannel channel =
        const MethodChannel('com.shorie.lifequest/shared_storage'),
  }) : _channel = channel;

  final MethodChannel _channel;

  bool _ready = false;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw SharedStorageException(method, (args?['name'] as String?) ?? '*', e);
    } on MissingPluginException catch (e) {
      throw SharedStorageException(method, '*', e);
    }
  }

  @override
  Future<bool> ensureDirectory() async {
    if (_ready) {
      unawaited(
        CrossAppLinkStatusRecorder.instance.recordFolderReady(true),
      );
      return true;
    }
    final ok = await _invoke<bool>('ensureDirectory') ?? false;
    _ready = ok;
    unawaited(
      CrossAppLinkStatusRecorder.instance.recordFolderReady(ok),
    );
    return ok;
  }

  /// フォルダ選択 UI を出す（連携画面から明示的に呼ぶ）。
  @override
  Future<bool> chooseDirectory() async {
    final ok = await _invoke<bool>('chooseDirectory') ?? false;
    _ready = ok;
    unawaited(
      CrossAppLinkStatusRecorder.instance.recordFolderReady(ok),
    );
    return ok;
  }

  @override
  Future<void> writeString(String fileName, String content) async {
    if (!await ensureDirectory()) {
      final error = const SharedStorageException('write', '*', 'no directory');
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSendFailure(error, fileName: fileName),
      );
      throw error;
    }
    try {
      await _invoke<void>('writeString', {'name': fileName, 'content': content});
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSent(count: 1, fileName: fileName),
      );
    } on Object catch (e) {
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSendFailure(e, fileName: fileName),
      );
      rethrow;
    }
  }

  @override
  Future<void> appendLine(String fileName, String line) async {
    if (!await ensureDirectory()) {
      final error = const SharedStorageException('append', '*', 'no directory');
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSendFailure(error, fileName: fileName),
      );
      throw error;
    }
    try {
      await _invoke<void>('appendLine', {'name': fileName, 'line': line});
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSent(count: 1, fileName: fileName),
      );
    } on Object catch (e) {
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordSendFailure(e, fileName: fileName),
      );
      rethrow;
    }
  }

  @override
  Future<String?> readString(String fileName) async {
    if (!await ensureDirectory()) return null;
    try {
      final content = await _invoke<String>('readString', {'name': fileName});
      if (content != null) {
        unawaited(
          CrossAppLinkStatusRecorder.instance.recordReceived(
            count: CrossAppLinkStatusText.countLines(content),
            fileName: fileName,
          ),
        );
      }
      return content;
    } on Object catch (e) {
      unawaited(
        CrossAppLinkStatusRecorder.instance
            .recordReceiveFailure(e, fileName: fileName),
      );
      rethrow;
    }
  }

  @override
  Future<bool> delete(String fileName) async {
    if (!await ensureDirectory()) return false;
    return await _invoke<bool>('delete', {'name': fileName}) ?? false;
  }

  @override
  Future<bool> exists(String fileName) async {
    if (!await ensureDirectory()) return false;
    return await _invoke<bool>('exists', {'name': fileName}) ?? false;
  }

  @override
  Future<List<String>> listFiles() async {
    if (!await ensureDirectory()) return const [];
    final names = await _invoke<List<Object?>>('listFiles');
    return (names ?? const []).whereType<String>().toList(growable: false);
  }
}

/// アプリ全体で共有する 1 つのストア。
///
/// `main.dart` で [configure] を呼んで初期化する。未初期化なら
/// アプリ専用の Documents ディレクトリ（現世内だけ）にフォールバックする。
class SharedFileStore {
  const SharedFileStore._();

  static ISharedFileStore? _instance;
  static bool _configured = false;

  /// 現在のストア。未設定なら現世内フォールバック（端末の一時領域）。
  ///
  /// フォールバックは**現世の外からは読めない**ため、連携機能は動かない。
  /// それでも落ちないようにするための最後の砦で、[isConfigured] が false なら
  /// 連携画面に「共有フォルダ未設定」を出すこと。
  static ISharedFileStore get instance =>
      _instance ??= _fallback ?? FileSharedFileStore(Directory.systemTemp);

  static ISharedFileStore? _fallback;

  /// 起動時に呼ぶ。Android では SAF 実装を、それ以外はファイル実装を渡す。
  static void configure(ISharedFileStore store) {
    _instance = store;
    _configured = true;
  }

  /// 現世内フォールバック（共有は成立しないが、書込自体は成功する）。
  ///
  /// アプリ固有ディレクトリを渡す。**他現世からは読めない**ので、
  /// 連携機能は動かない。失敗を無音にしないための最後の砦。
  static void configureFallback(ISharedFileStore store) {
    _fallback = store;
    if (!_configured) _instance = store;
  }

  /// テスト用にリセットする。
  static void reset() {
    _instance = null;
    _fallback = null;
    _configured = false;
  }

  /// 設定済みか（連携が有効か）。
  static bool get isConfigured => _configured;
}
