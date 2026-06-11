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
/// tsundoku-quest が書き出す共有ストレージの JSONL ファイルを読み込む。
class FileCrossAppRewardService implements ICrossAppRewardService {
  final String filePath;
  final String hiveBoxName;

  const FileCrossAppRewardService({
    this.filePath =
        '/data/local/tmp/takamagahara_shared/tsundoku_reward_events.jsonl',
    this.hiveBoxName = 'cross_app_rewards',
  });

  @override
  Future<List<CrossAppReward>> processPendingEvents({
    required String? linkedUserId,
  }) async {
    final rewards = <CrossAppReward>[];

    if (linkedUserId == null || linkedUserId.isEmpty) {
      return rewards; // リンクされていないので何もしない
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return rewards;
      }

      final box = await _openBox();
      final consumedIds = _getConsumedIds(box);

      final lines = await file.readAsLines();
      for (final line in lines) {
        try {
          final event = CrossAppRewardEvent.parseLine(line);

          // 冪等性チェック
          if (consumedIds.contains(event.eventId)) {
            continue;
          }

          // ユーザーマッチング: tsundoku user_id の先頭8文字で照合
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
    } catch (_) {
      // ファイル読み込みエラー等はすべて無視して空を返す
    }

    return rewards;
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
