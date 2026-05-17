/// 四天守護神の文字列表現 → 絵文字・ラベル マッピング
///
/// Kozuchi アプリの guardianDeity 文字列表現と、
/// rpg-task で表示に使う絵文字・ラベルを対応付ける。
const Map<String, _GuardianDeityInfo> _guardianDeityMap = {
  'daikokuten': _GuardianDeityInfo(emoji: '🪘', label: '大黒天'),
  'benzaiten': _GuardianDeityInfo(emoji: '🎵', label: '弁財天'),
  'bishamonten': _GuardianDeityInfo(emoji: '⚔️', label: '毘沙門天'),
  'kisshoten': _GuardianDeityInfo(emoji: '🌸', label: '吉祥天'),
};

class _GuardianDeityInfo {
  final String emoji;
  final String label;

  const _GuardianDeityInfo({
    required this.emoji,
    required this.label,
  });
}

/// Kozuchi（打ち出の小槌）アプリから共有されるアクティブな試練クエスト
///
/// 不変クラス。共有ストレージの JSON をパースして生成する。
/// guardianDeityEmoji と guardianDeityLabel は
/// 文字列表現からマッピングされる（画面表示用）。
class KozuchiQuest {
  /// 試練のタイトル
  final String title;

  /// 試練の説明
  final String description;

  /// 喜捨金額の目安（円）
  final int suggestedOffering;

  /// 守護神の絵文字（表示用）
  final String guardianDeityEmoji;

  /// 守護神のラベル（表示用）
  final String guardianDeityLabel;

  /// クエスト完了状態
  final bool isCompleted;

  const KozuchiQuest({
    required this.title,
    required this.description,
    required this.suggestedOffering,
    required this.guardianDeityEmoji,
    required this.guardianDeityLabel,
    this.isCompleted = false,
  });

  /// JSON マップから KozuchiQuest を生成する。
  ///
  /// 必須フィールド（title, description, guardianDeity）が欠落している場合は
  /// [ArgumentError] を投げる。
  /// guardianDeity の値が未知の文字列の場合はデフォルトで
  /// 大黒天（🪘）の情報を使用する。
  /// suggestedOffering が null の場合は 0、
  /// isCompleted が null の場合は false として扱う。
  factory KozuchiQuest.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final description = json['description'];
    final guardianDeity = json['guardianDeity'] as String?;

    if (title == null || title is! String || title.isEmpty) {
      throw ArgumentError('title is required and must be a non-empty string');
    }
    if (description == null || description is! String || description.isEmpty) {
      throw ArgumentError(
        'description is required and must be a non-empty string',
      );
    }
    if (guardianDeity == null || guardianDeity.isEmpty) {
      throw ArgumentError('guardianDeity is required');
    }

    final deityInfo = _guardianDeityMap[guardianDeity] ??
        const _GuardianDeityInfo(emoji: '🪘', label: '大黒天');

    return KozuchiQuest(
      title: title,
      description: description,
      suggestedOffering: (json['suggestedOffering'] as num?)?.toInt() ?? 0,
      guardianDeityEmoji: deityInfo.emoji,
      guardianDeityLabel: deityInfo.label,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'KozuchiQuest('
        'title: $title, '
        'guardianDeity: $guardianDeityLabel, '
        'isCompleted: $isCompleted'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KozuchiQuest &&
        other.title == title &&
        other.description == description &&
        other.suggestedOffering == suggestedOffering &&
        other.guardianDeityEmoji == guardianDeityEmoji &&
        other.guardianDeityLabel == guardianDeityLabel &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      title,
      description,
      suggestedOffering,
      guardianDeityEmoji,
      guardianDeityLabel,
      isCompleted,
    );
  }
}
