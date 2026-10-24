import 'cross_app_title_definition.dart';

/// 称号図鑑の絞り込み種別
enum CrossAppTitleFilter { all, earned, unearned }

/// 絞り込み種別の表示ラベル
extension CrossAppTitleFilterLabel on CrossAppTitleFilter {
  String get label {
    switch (this) {
      case CrossAppTitleFilter.all:
        return 'すべて';
      case CrossAppTitleFilter.earned:
        return '獲得済み';
      case CrossAppTitleFilter.unearned:
        return '未獲得';
    }
  }
}

/// イベントタイプ → 表示用ラベル（図鑑のグループ見出しに使用）
const Map<String, String> kCrossAppEventTypeLabels = {
  'book_completed': '読了冊数',
  'reading_streak': '連続読書日数',
  'xp_milestone': '獲得XP',
  'pages_milestone': '読了ページ数',
  'election_completed': '当選回数',
  'quiz_completed': 'クイズ正解数',
};

/// 条件表記の組み立て用テンプレート（接頭辞＋数値＋単位）
class _ConditionTemplate {
  final String prefix;
  final String suffix;

  const _ConditionTemplate(this.prefix, this.suffix);
}

/// イベントタイプ → 条件表記テンプレート（内部表）
const Map<String, _ConditionTemplate> _kConditionTemplates = {
  'book_completed': _ConditionTemplate('読了 ', '冊'),
  'reading_streak': _ConditionTemplate('連続 ', '日'),
  'xp_milestone': _ConditionTemplate('XP ', ''),
  'pages_milestone': _ConditionTemplate('通算 ', 'ページ'),
  'election_completed': _ConditionTemplate('当選 ', '回'),
  'quiz_completed': _ConditionTemplate('正解 ', '問'),
};

/// 整数を3桁区切りカンマ付きで整形する（純粋関数）
String _formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

/// 図鑑の1行分（称号定義＋獲得状態）
class CrossAppTitleEntry {
  final CrossAppTitleDefinition definition;
  final bool isEarned;

  const CrossAppTitleEntry({
    required this.definition,
    required this.isEarned,
  });

  String get id => definition.id;

  /// 獲得条件の表示（例: 読了 1冊 / 連続 7日 / XP 1,000 / 通算 1,000ページ）
  String get conditionLabel {
    final template = _kConditionTemplates[definition.eventType];
    final count = _formatThousands(definition.threshold);
    if (template == null) {
      return '${definition.eventType} $count';
    }
    return '${template.prefix}$count${template.suffix}';
  }

  /// イベント種別の表示（未知は eventType をそのまま返す）
  String get eventTypeLabel =>
      kCrossAppEventTypeLabels[definition.eventType] ?? definition.eventType;

  String get statusLabel => isEarned ? '獲得済み' : '未獲得';
}

/// イベント種別ごとの称号グループ
class CrossAppTitleGroup {
  final String eventType;
  final String label;
  final List<CrossAppTitleEntry> entries;

  const CrossAppTitleGroup({
    required this.eventType,
    required this.label,
    required this.entries,
  });
}

/// 称号図鑑の一覧（定義順を保持する不変コレクション）
class CrossAppTitleCollection {
  final List<CrossAppTitleEntry> entries;

  const CrossAppTitleCollection({required this.entries});

  int get total => entries.length;

  int get earnedCount => entries.where((e) => e.isEarned).length;

  int get unearnedCount => total - earnedCount;

  /// 達成率（0件なら0除算せず 0.0、常に 0..1）
  double get achievementRatio {
    if (total == 0) return 0.0;
    final ratio = earnedCount / total;
    if (ratio.isNaN) return 0.0;
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  /// 例: 獲得 3 / 11
  String get summaryLabel => '獲得 $earnedCount / $total';

  /// 例: 25%
  String get ratioLabel => '${(achievementRatio * 100).round()}%';

  List<CrossAppTitleEntry> get earned =>
      entries.where((e) => e.isEarned).toList(growable: false);

  List<CrossAppTitleEntry> get unearned =>
      entries.where((e) => !e.isEarned).toList(growable: false);

  /// イベント種別ごとに定義順初出順でグループ化する（空グループは含めない）
  List<CrossAppTitleGroup> get groups {
    final order = <String>[];
    final buckets = <String, List<CrossAppTitleEntry>>{};
    for (final entry in entries) {
      final eventType = entry.definition.eventType;
      final bucket = buckets[eventType];
      if (bucket == null) {
        order.add(eventType);
        buckets[eventType] = <CrossAppTitleEntry>[entry];
      } else {
        bucket.add(entry);
      }
    }
    return order
        .map(
          (eventType) => CrossAppTitleGroup(
            eventType: eventType,
            label: kCrossAppEventTypeLabels[eventType] ?? eventType,
            entries: List<CrossAppTitleEntry>.unmodifiable(buckets[eventType]!),
          ),
        )
        .toList(growable: false);
  }

  /// 絞り込み（元コレクションは不変）
  CrossAppTitleCollection filter(CrossAppTitleFilter filter) {
    switch (filter) {
      case CrossAppTitleFilter.all:
        return this;
      case CrossAppTitleFilter.earned:
        return CrossAppTitleCollection(entries: earned);
      case CrossAppTitleFilter.unearned:
        return CrossAppTitleCollection(entries: unearned);
    }
  }

  /// ID一致で1件取得（無ければ null）
  CrossAppTitleEntry? entryFor(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// 獲得済みを先頭に並べ替えた新しいリスト（各群内は定義順）
  List<CrossAppTitleEntry> get sortedByEarnedFirst =>
      <CrossAppTitleEntry>[...earned, ...unearned];
}

/// 称号定義と所持称号名から図鑑を組み立てる純粋サービス
class CrossAppTitleService {
  const CrossAppTitleService();

  /// [ownedTitles] は Player.titles（称号名 = 定義ID）。未知の名前は無視し、
  /// 重複は単一扱い。[definitions] の順序はそのまま保持する。
  CrossAppTitleCollection build({
    required List<String> ownedTitles,
    List<CrossAppTitleDefinition> definitions = kCrossAppTitles,
  }) {
    final owned = ownedTitles.toSet();
    return CrossAppTitleCollection(
      entries: definitions
          .map(
            (definition) => CrossAppTitleEntry(
              definition: definition,
              isEarned: owned.contains(definition.id),
            ),
          )
          .toList(growable: false),
    );
  }
}
