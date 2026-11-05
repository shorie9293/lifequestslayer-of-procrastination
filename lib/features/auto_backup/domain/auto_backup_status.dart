/// 自動バックアップの直近の状態（純粋な値オブジェクト）。
///
/// 「一度も走っていない」と「毎回失敗している」を区別するために持つ。
/// IO も現在時刻も持たない（[DateTime] は必ず呼び出し側が渡す）。
class AutoBackupStatus {
  /// 連続失敗がこの回数に達したら「劣化」とみなす。
  static const int degradedThreshold = 3;

  /// 直近の成功時刻（一度も成功していなければ null）。
  final DateTime? lastSuccessAt;

  /// 直近の試行時刻（一度も試行していなければ null）。
  final DateTime? lastAttemptAt;

  /// 直近の失敗理由（成功・未試行なら null）。
  final String? lastError;

  /// 連続失敗回数（成功で 0 に戻る）。
  final int consecutiveFailures;

  /// 状態を生成する。
  ///
  /// 不変条件は本体で [ArgumentError] を投げて強制する
  /// （`assert` は release で消え、破損データも通してしまうため）。
  AutoBackupStatus({
    this.lastSuccessAt,
    this.lastAttemptAt,
    this.lastError,
    this.consecutiveFailures = 0,
  }) {
    if (consecutiveFailures < 0) {
      throw ArgumentError.value(
        consecutiveFailures,
        'consecutiveFailures',
        '0以上でなければならない',
      );
    }
    if (consecutiveFailures > 0 && (lastError == null || lastError!.isEmpty)) {
      throw ArgumentError(
        '連続失敗回数が1以上なら lastError が必要である',
      );
    }
  }

  /// 何も記録がない初期状態。
  static final AutoBackupStatus initial = AutoBackupStatus();

  /// 一度でも試行したか。
  bool get hasAttempted => lastAttemptAt != null;

  /// 直近の試行が失敗か。
  bool get hasFailed => consecutiveFailures > 0;

  /// 連続失敗が閾値に達しているか（設定ハブの警告バッジ用）。
  bool get isDegraded => consecutiveFailures >= degradedThreshold;

  /// 成功を記録する（失敗カウンタは 0 に戻る）。
  AutoBackupStatus recordSuccess(DateTime at) => AutoBackupStatus(
        lastSuccessAt: at,
        lastAttemptAt: at,
        consecutiveFailures: 0,
      );

  /// 失敗を記録する（成功時刻は保持し、カウンタを1つ進める）。
  AutoBackupStatus recordFailure(DateTime at, Object error) => AutoBackupStatus(
        lastSuccessAt: lastSuccessAt,
        lastAttemptAt: at,
        lastError: summarizeError(error),
        consecutiveFailures: consecutiveFailures + 1,
      );

  /// 例外を1行の短い説明へ落とす（画面に出すため）。
  static String summarizeError(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '原因不明の失敗';
    const limit = 120;
    if (text.length <= limit) return text;
    return '${text.substring(0, limit)}…';
  }

  /// JSON へ変換する。
  Map<String, Object?> toJson() => <String, Object?>{
        'lastSuccessAt': lastSuccessAt?.toIso8601String(),
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
        'lastError': lastError,
        'consecutiveFailures': consecutiveFailures,
      };

  /// JSON から復元する（破損・欠損は初期状態へ落とし、例外を投げない）。
  static AutoBackupStatus fromJson(Map<String, Object?> json) {
    try {
      final failures = json['consecutiveFailures'];
      final count = failures is int ? failures : 0;
      final error = json['lastError'];
      final errorText = error is String && error.isNotEmpty ? error : null;
      return AutoBackupStatus(
        lastSuccessAt: _parseDate(json['lastSuccessAt']),
        lastAttemptAt: _parseDate(json['lastAttemptAt']),
        lastError: count > 0 ? (errorText ?? '原因不明の失敗') : errorText,
        consecutiveFailures: count < 0 ? 0 : count,
      );
    } catch (_) {
      return AutoBackupStatus.initial;
    }
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  @override
  String toString() => 'AutoBackupStatus(success: $lastSuccessAt, '
      'attempt: $lastAttemptAt, failures: $consecutiveFailures)';
}
