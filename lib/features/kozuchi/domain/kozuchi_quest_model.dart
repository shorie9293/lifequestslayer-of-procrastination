/// 四天アドバイザーの文字列表現 → 絵文字・ラベル マッピング
///
/// Kozuchi アプリの advisor 文字列表現と、
/// rpg-task で表示に使う絵文字・ラベルを対応付ける。
const Map<String, _AdvisorInfo> _advisorMap = {
  'lifePlanner': _AdvisorInfo(emoji: '🪘', label: 'ライフプランナー'),
  'careerCoach': _AdvisorInfo(emoji: '🎵', label: 'キャリアコーチ'),
  'investmentMentor': _AdvisorInfo(emoji: '⚔️', label: '投資メンター'),
  'wellnessAdvisor': _AdvisorInfo(emoji: '🌸', label: 'ウェルネスアドバイザー'),
};

class _AdvisorInfo {
  final String emoji;
  final String label;

  const _AdvisorInfo({
    required this.emoji,
    required this.label,
  });
}

/// Kozuchi（打ち出の小槌）アプリから共有されるアクティブな試練クエスト
///
/// 不変クラス。共有ストレージの JSON をパースして生成する。
/// advisorEmoji と advisorLabel は
/// 文字列表現からマッピングされる（画面表示用）。
class KozuchiQuest {
  /// 試練のタイトル
  final String title;

  /// 試練の説明
  final String description;

  /// 支出金額の目安（円）
  final int suggestedOffering;

  /// アドバイザーの絵文字（表示用）
  final String advisorEmoji;

  /// アドバイザーのラベル（表示用）
  final String advisorLabel;

  /// クエスト完了状態
  final bool isCompleted;

  const KozuchiQuest({
    required this.title,
    required this.description,
    required this.suggestedOffering,
    required this.advisorEmoji,
    required this.advisorLabel,
    this.isCompleted = false,
  });

  /// JSON マップから KozuchiQuest を生成する。
  ///
  /// 必須フィールド（title, description, advisor）が欠落している場合は
  /// [ArgumentError] を投げる。
  /// advisor の値が未知の文字列の場合はデフォルトで
  /// ライフプランナー（🪘）の情報を使用する。
  /// suggestedOffering が null の場合は 0、
  /// isCompleted が null の場合は false として扱う。
  factory KozuchiQuest.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final description = json['description'];
    final advisor = json['advisor'] as String?;

    if (title == null || title is! String || title.isEmpty) {
      throw ArgumentError('title is required and must be a non-empty string');
    }
    if (description == null || description is! String || description.isEmpty) {
      throw ArgumentError(
        'description is required and must be a non-empty string',
      );
    }
    if (advisor == null || advisor.isEmpty) {
      throw ArgumentError('advisor is required');
    }

    final deityInfo = _advisorMap[advisor] ??
        const _AdvisorInfo(emoji: '🪘', label: 'ライフプランナー');

    return KozuchiQuest(
      title: title,
      description: description,
      suggestedOffering: (json['suggestedOffering'] as num?)?.toInt() ?? 0,
      advisorEmoji: deityInfo.emoji,
      advisorLabel: deityInfo.label,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'KozuchiQuest('
        'title: $title, '
        'advisor: $advisorLabel, '
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
        other.advisorEmoji == advisorEmoji &&
        other.advisorLabel == advisorLabel &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      title,
      description,
      suggestedOffering,
      advisorEmoji,
      advisorLabel,
      isCompleted,
    );
  }
}
