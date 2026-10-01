class AdventurerStatEntry {
  final String id; // 例 'total_tasks'
  final String label; // 例 '総クエスト完了'
  final int value;
  final String unit; // '件' / '回' / '日'
  final String emoji;

  const AdventurerStatEntry({
    required this.id,
    required this.label,
    required this.value,
    required this.unit,
    required this.emoji,
  });

  String get displayValue => '$value$unit';
  String get labelWithValue => '$label $displayValue';
}

class AdventurerStatGroup {
  final String id; // 'quests' / 'battles' / 'streaks' / 'reflections'
  final String title; // 'クエスト完遂' 等
  final String emoji;
  final List<AdventurerStatEntry> entries;

  const AdventurerStatGroup({
    required this.id,
    required this.title,
    required this.emoji,
    required this.entries,
  });

  int get totalValue => entries.fold(0, (s, e) => s + e.value);
  bool get isEmpty => entries.isEmpty;
}

class AdventurerChart {
  final List<AdventurerStatGroup> groups;
  final int adventurerLevel;
  final String rankLabel;

  const AdventurerChart({
    required this.groups,
    required this.adventurerLevel,
    required this.rankLabel,
  });

  bool get isEmpty => groups.every((g) => g.isEmpty);

  List<AdventurerStatEntry> get allEntries =>
      [for (final g in groups) ...g.entries];

  AdventurerStatEntry? entryById(String id) {
    for (final g in groups) {
      for (final e in g.entries) {
        if (e.id == id) return e;
      }
    }
    return null;
  }

  AdventurerStatGroup? groupById(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }
}
