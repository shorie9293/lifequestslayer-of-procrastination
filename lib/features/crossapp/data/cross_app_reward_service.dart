import 'dart:io';

import 'package:hive/hive.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_reward_event.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';

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
  /// tsundoku-quest が書き出す報酬イベント
  static const kDefaultTsundokuEventsPath =
      '/data/local/tmp/takamagahara_shared/tsundoku_reward_events.jsonl';

  /// election-game が書き出す報酬イベント（契約 v1）
  static const kDefaultElectionEventsPath =
      '/data/local/tmp/takamagahara_shared/election_reward_events.jsonl';

  /// book-review-app が書き出す報酬イベント（契約 v1: book_completed）
  static const kDefaultBookReviewEventsPath =
      '/data/local/tmp/takamagahara_shared/book_review_reward_events.jsonl';

  final String filePath;
  final List<String> additionalFilePaths;
  final String hiveBoxName;

  const FileCrossAppRewardService({
    this.filePath = kDefaultTsundokuEventsPath,
    this.additionalFilePaths = const [
      kDefaultElectionEventsPath,
      kDefaultBookReviewEventsPath,
    ],
    this.hiveBoxName = 'cross_app_rewards',
  });

  /// 走査対象の全パス（主ファイル + 追加ファイル・重複除去）
  List<String> get allFilePaths {
    final paths = <String>[];
    for (final path in [filePath, ...additionalFilePaths]) {
      if (path.isEmpty) continue;
      if (!paths.contains(path)) paths.add(path);
    }
    return paths;
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
      // 存在するファイルのみを走査対象にする
      final existingPaths = <String>[];
      for (final path in allFilePaths) {
        if (await File(path).exists()) {
          existingPaths.add(path);
        }
      }
      if (existingPaths.isEmpty) {
        return rewards;
      }

      final box = await _openBox();
      final consumedIds = _getConsumedIds(box);

      for (final path in existingPaths) {
        await _consumeFile(
          path: path,
          linkedUserId: linkedUserId,
          box: box,
          consumedIds: consumedIds,
          rewards: rewards,
        );
      }
    } catch (_) {
      // ファイル読み込みエラー等はすべて無視して空を返す
    }

    return rewards;
  }

  /// 1ファイル分の JSONL を走査し、未処理イベントを報酬へ変換する。
  Future<void> _consumeFile({
    required String path,
    required String linkedUserId,
    required Box box,
    required Set<String> consumedIds,
    required List<CrossAppReward> rewards,
  }) async {
    List<String> lines;
    try {
      lines = await File(path).readAsLines();
    } catch (_) {
      return; // 読めないファイルはスキップして次のファイルへ
    }

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
