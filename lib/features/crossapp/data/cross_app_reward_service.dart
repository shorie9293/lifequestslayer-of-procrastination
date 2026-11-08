import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/core/infrastructure/shared_file_store.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_reward_event.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';

/// 連携（クロスアプリ受け渡し）の状態。連携画面はこの1つを表示すればよい。
class CrossAppLinkStatus {
  const CrossAppLinkStatus({
    this.lastSentAt,
    this.lastReceivedAt,
    this.lastError,
    this.sharedFolderReady = false,
  });

  final DateTime? lastSentAt;
  final DateTime? lastReceivedAt;
  final String? lastError;
  final bool sharedFolderReady;

  bool get isHealthy => lastError == null && sharedFolderReady;

  CrossAppLinkStatus copyWith({
    DateTime? lastSentAt,
    DateTime? lastReceivedAt,
    String? lastError,
    bool? sharedFolderReady,
    bool clearError = false,
  }) {
    return CrossAppLinkStatus(
      lastSentAt: lastSentAt ?? this.lastSentAt,
      lastReceivedAt: lastReceivedAt ?? this.lastReceivedAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      sharedFolderReady: sharedFolderReady ?? this.sharedFolderReady,
    );
  }
}

/// 連携状態の通知口（連携画面が listen する）。
final ValueNotifier<CrossAppLinkStatus> crossAppLinkStatus =
    ValueNotifier<CrossAppLinkStatus>(const CrossAppLinkStatus());

/// クロスアプリ報酬サービスのインターフェース
///
/// 単体テストで Mock に差し替え可能にするための抽象インターフェース。
abstract class ICrossAppRewardService {
  /// 共有ストレージから未処理の報酬イベントを読み込み、報酬を返す。
  ///
  /// 処理済みの event_id は Hive box `cross_app_rewards` で追跡し、
  /// 同じイベントは二度と処理しない（冪等性）。
  ///
  /// [linkedUserId] は設定画面で手動リンクした tsundoku user_id（先頭8文字）。
  /// null の場合はイベントに含まれる user_id とマッチせず、報酬は付与されない。
  Future<List<CrossAppReward>> processPendingEvents({
    required String? linkedUserId,
  });
}

/// ファイルベースの [ICrossAppRewardService] 実装
///
/// tsundoku-quest / election-game / book-review-app が書き出す
/// 共有ストレージの JSONL ファイルを読み込む。
/// [filePath] は主ファイル（後方互換のため単一指定APIを維持）、
/// [additionalFilePaths] は追加で走査するファイル群。
/// 冪等性は同一 Hive box の event_id で横断的に担保する。
class FileCrossAppRewardService implements ICrossAppRewardService {
  /// tsundoku-quest が書き出す報酬イベント（契約: ファイル名）
  static const String kDefaultTsundokuEventsFile =
      SharedCrossAppFiles.tsundokuRewardEvents;

  /// election-game が書き出す報酬イベント（契約 v1）
  static const String kDefaultElectionEventsFile =
      SharedCrossAppFiles.electionRewardEvents;

  /// book-review-app が書き出す報酬イベント（契約 v1: book_completed）
  static const String kDefaultBookReviewEventsFile =
      SharedCrossAppFiles.bookReviewRewardEvents;

  /// 走査する既定のファイル名一覧（順序は互換維持）
  static const List<String> kDefaultEventFiles = <String>[
    kDefaultTsundokuEventsFile,
    kDefaultElectionEventsFile,
    kDefaultBookReviewEventsFile,
  ];

  /// 試練用の明示パス。null なら共有ストア（SharedFileStore）経由。
  final String? filePath;
  final List<String> additionalFilePaths;
  final String hiveBoxName;

  const FileCrossAppRewardService({
    this.filePath,
    this.additionalFilePaths = const [],
    this.hiveBoxName = 'cross_app_rewards',
  });

  /// 走査対象の全パス（試練モード: [filePath] を明示した場合のみ）
  List<String> get allFilePaths {
    final paths = <String>[];
    for (final path in [filePath, ...additionalFilePaths]) {
      if (path == null || path.isEmpty) continue;
      if (!paths.contains(path)) paths.add(path);
    }
    return paths;
  }

  /// 走査対象のファイル名（本番モード: 共有ストア経由）
  List<String> get allFileNames {
    final names = <String>[];
    for (final name in [filePath, ...additionalFilePaths]) {
      if (name == null || name.isEmpty) continue;
      if (!names.contains(name)) names.add(name);
    }
    return names.isEmpty ? kDefaultEventFiles : names;
  }

  @override
  Future<List<CrossAppReward>> processPendingEvents({
    required String? linkedUserId,
  }) async {
    final rewards = <CrossAppReward>[];

    if (linkedUserId == null || linkedUserId.isEmpty) {
      return rewards; // リンクされていないので何もしない
    }

    try {
      if (filePath != null) {
        await _processPaths(linkedUserId, rewards);
      } else {
        await _processStore(linkedUserId, rewards);
      }
      crossAppLinkStatus.value = crossAppLinkStatus.value.copyWith(
        lastReceivedAt: DateTime.now(),
        clearError: true,
      );
    } on SharedStorageException catch (e) {
      // 握りつぶさず、連携画面が読める状態として残す。
      crossAppLinkStatus.value = crossAppLinkStatus.value.copyWith(
        lastError: e.toString(),
      );
    }

    return rewards;
  }

  /// 試練モード: 明示パスのファイルを走査する（従来の契約をそのまま保持）。
  Future<void> _processPaths(
    String linkedUserId,
    List<CrossAppReward> rewards,
  ) async {
    final existingPaths = <String>[];
    for (final path in allFilePaths) {
      if (await File(path).exists()) {
        existingPaths.add(path);
      }
    }
    if (existingPaths.isEmpty) return;

    final box = await _openBox();
    final consumedIds = _getConsumedIds(box);

    for (final path in existingPaths) {
      final lines = await File(path).readAsLines();
      await _consumeLines(lines, linkedUserId, box, consumedIds, rewards);
    }
  }

  /// 本番モード: 共有ストア（Android 実機では SAF の共有フォルダ）を走査する。
  Future<void> _processStore(
    String linkedUserId,
    List<CrossAppReward> rewards,
  ) async {
    final store = SharedFileStore.instance;
    final ready = await store.ensureDirectory();
    if (!ready) {
      crossAppLinkStatus.value = crossAppLinkStatus.value.copyWith(
        sharedFolderReady: false,
        lastError: '共有フォルダが未設定です（連携機能は停止中）',
      );
      return;
    }

    final box = await _openBox();
    final consumedIds = _getConsumedIds(box);

    for (final name in allFileNames) {
      final content = await store.readString(name);
      if (content == null || content.trim().isEmpty) continue;
      await _consumeLines(
        const LineSplitter().convert(content),
        linkedUserId,
        box,
        consumedIds,
        rewards,
      );
    }
  }

  /// JSONL の行群を走査し、未処理イベントを報酬へ変換する。
  Future<void> _consumeLines(
    List<String> lines,
    String linkedUserId,
    Box box,
    Set<String> consumedIds,
    List<CrossAppReward> rewards,
  ) async {

    for (final line in lines) {
      try {
        final event = CrossAppRewardEvent.parseLine(line);

        // 冪等性チェック（全ファイル横断）
        if (consumedIds.contains(event.eventId)) {
          continue;
        }

        // ユーザーマッチング: user_id の先頭8文字で照合
        if (!event.userId.startsWith(linkedUserId)) {
          continue;
        }

        // 報酬計算
        final reward = _computeReward(event);

        // 処理済みとして記録
        await box.put(event.eventId, true);
        consumedIds.add(event.eventId);

        if (reward.hasReward) {
          rewards.add(reward);
        }
      } catch (_) {
        // スキーマ違反の行はスキップ
        continue;
      }
    }
  }

  /// metadata から整数値を取り出す（int / num / 文字列を許容）
  int _metaInt(Map<String, dynamic> metadata, String key, int fallback) {
    final value = metadata[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  CrossAppReward _computeReward(CrossAppRewardEvent event) {
    final coins = kCrossAppCoinRewards[event.eventType] ?? 0;
    final exp = kCrossAppExpRewards[event.eventType] ?? 0;

    // タイトル判定
    int currentCount = 0;
    switch (event.eventType) {
      case 'book_completed':
        currentCount = event.metadata['count'] as int? ?? 1;
        break;
      case 'reading_streak':
        currentCount = event.metadata['streak_days'] as int? ?? 0;
        break;
      case 'xp_milestone':
        currentCount = event.metadata['xp'] as int? ?? 0;
        break;
      case 'pages_milestone':
        currentCount = event.metadata['pages'] as int? ?? 0;
        break;
      case 'election_completed':
        // 契約 v1: metadata.wins = 累計当選回数。欠落時は初当選として 1
        currentCount = _metaInt(event.metadata, 'wins', 1);
        break;
      case 'quiz_completed':
        // 契約 v1: metadata.correct_count = 正解数。欠落時は 0（称号なし）
        currentCount = _metaInt(event.metadata, 'correct_count', 0);
        break;
    }

    final titles = getMatchingCrossAppTitles(event.eventType, currentCount)
        .map((t) => t.id)
        .toList();

    return CrossAppReward(coins: coins, exp: exp, titles: titles);
  }

  /// Hive box から既処理の event_id セットを取得
  Set<String> _getConsumedIds(Box box) {
    try {
      return box.keys.cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Box> _openBox() async {
    try {
      return await Hive.openBox(hiveBoxName);
    } catch (_) {
      // 既に開かれている場合はそれを返す
      if (Hive.isBoxOpen(hiveBoxName)) {
        return Hive.box(hiveBoxName);
      }
      throw Exception('Hive box "$hiveBoxName" を開けませんでした');
    }
  }
}
