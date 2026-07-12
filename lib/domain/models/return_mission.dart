/// 帰還ミッション（ストリーク切断時の再エンゲージメント）。
///
/// ストリークが切断された際に発行され、
/// プレイヤーに特定のタスク達成を促す。
class ReturnMission {
  /// 切断前のストリーク日数。
  final int previousStreak;

  /// ミッション発行日時。
  final DateTime issuedAt;

  const ReturnMission({
    required this.previousStreak,
    required this.issuedAt,
  });

  Map<String, dynamic> toJson() => {
        'previousStreak': previousStreak,
        'issuedAt': issuedAt.toIso8601String(),
      };

  factory ReturnMission.fromJson(Map<String, dynamic> json) => ReturnMission(
        previousStreak: json['previousStreak'] as int,
        issuedAt: DateTime.parse(json['issuedAt'] as String),
      );
}
