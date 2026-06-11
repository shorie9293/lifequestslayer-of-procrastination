import 'dart:convert';

/// tsundoku-quest から送られてくる報酬イベント
///
/// JSONL の1行1イベント。event_id で冪等性を保証。
class CrossAppRewardEvent {
  final String eventId; // UUID v4
  final String eventType;
  final DateTime timestamp;
  final String userId;
  final Map<String, dynamic> metadata;

  const CrossAppRewardEvent({
    required this.eventId,
    required this.eventType,
    required this.timestamp,
    required this.userId,
    required this.metadata,
  });

  /// 既知のイベントタイプ一覧
  static const knownEventTypes = {
    'book_completed',
    'reading_streak',
    'level_up',
    'xp_milestone',
    'trophy_written',
    'daily_mission_complete',
    'pages_milestone',
  };

  factory CrossAppRewardEvent.fromJson(Map<String, dynamic> json) {
    final eventId = json['event_id'] as String?;
    final eventType = json['event_type'] as String?;
    final timestampStr = json['timestamp'] as String?;
    final userId = json['user_id'] as String?;
    final metadata = json['metadata'] as Map<String, dynamic>?;

    if (eventId == null || eventId.isEmpty) {
      throw const FormatException('event_id は必須です');
    }
    if (eventType == null || eventType.isEmpty) {
      throw const FormatException('event_type は必須です');
    }
    if (!knownEventTypes.contains(eventType)) {
      // 未知のイベントタイプは許容するが、警告ログを残すのが望ましい
    }
    if (timestampStr == null || timestampStr.isEmpty) {
      throw const FormatException('timestamp は必須です');
    }
    if (userId == null || userId.isEmpty) {
      throw const FormatException('user_id は必須です');
    }

    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) {
      throw FormatException('timestamp の形式が不正です: $timestampStr');
    }

    return CrossAppRewardEvent(
      eventId: eventId,
      eventType: eventType,
      timestamp: timestamp,
      userId: userId,
      metadata: metadata ?? {},
    );
  }

  /// JSONLの1行をパースする。不正な行は FormatException を投げる。
  static CrossAppRewardEvent parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('空行です');
    }
    try {
      final decoded = json.decode(trimmed) as Map<String, dynamic>;
      return CrossAppRewardEvent.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('JSON パースエラー: $e');
    }
  }
}

/// イベント処理結果として付与される報酬
class CrossAppReward {
  final int coins;
  final int exp;
  final List<String> titles;

  const CrossAppReward({
    this.coins = 0,
    this.exp = 0,
    this.titles = const [],
  });

  bool get hasReward => coins > 0 || exp > 0 || titles.isNotEmpty;

  CrossAppReward merge(CrossAppReward other) {
    return CrossAppReward(
      coins: coins + other.coins,
      exp: exp + other.exp,
      titles: [...titles, ...other.titles],
    );
  }
}
