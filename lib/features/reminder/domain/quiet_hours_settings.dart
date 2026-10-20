import 'quiet_hours.dart';

/// 静穏時間（おやすみモード）の設定値オブジェクト。
///
/// 不変（immutable）かつ値等価。時刻はローカル時刻の時・分で保持する。
/// 開始 == 終了は「抑止なし」を意味する（[QuietHoursService] 参照）。
class QuietHoursSettings {
  QuietHoursSettings({
    this.enabled = false,
    this.startHour = 22,
    this.startMinute = 0,
    this.endHour = 7,
    this.endMinute = 0,
    this.policy = QuietHoursPolicy.defer,
  }) {
    if (startHour < 0 || startHour > 23) {
      throw ArgumentError.value(startHour, 'startHour', '0-23 の範囲で指定せよ');
    }
    if (startMinute < 0 || startMinute > 59) {
      throw ArgumentError.value(startMinute, 'startMinute', '0-59 の範囲で指定せよ');
    }
    if (endHour < 0 || endHour > 23) {
      throw ArgumentError.value(endHour, 'endHour', '0-23 の範囲で指定せよ');
    }
    if (endMinute < 0 || endMinute > 59) {
      throw ArgumentError.value(endMinute, 'endMinute', '0-59 の範囲で指定せよ');
    }
  }

  /// 既定値: 無効・22:00〜07:00・翌朝に繰り延べ。
  factory QuietHoursSettings.defaults() => QuietHoursSettings();

  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final QuietHoursPolicy policy;

  /// 開始時刻を 0:00 からの分で表す。
  int get startMinutes => startHour * 60 + startMinute;

  /// 終了時刻を 0:00 からの分で表す。
  int get endMinutes => endHour * 60 + endMinute;

  String get startLabel => QuietHoursServiceLabel.formatMinutes(startMinutes);

  String get endLabel => QuietHoursServiceLabel.formatMinutes(endMinutes);

  QuietHoursSettings copyWith({
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    QuietHoursPolicy? policy,
  }) {
    return QuietHoursSettings(
      enabled: enabled ?? this.enabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      policy: policy ?? this.policy,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'policy': policy.storageKey,
      };

  /// 破損・型不正・範囲外は [QuietHoursSettings.defaults] へフォールバックする。
  factory QuietHoursSettings.fromJson(Map<String, dynamic> json) {
    try {
      final enabled = json['enabled'];
      final startHour = json['startHour'];
      final startMinute = json['startMinute'];
      final endHour = json['endHour'];
      final endMinute = json['endMinute'];
      final policy = json['policy'];
      if (enabled is! bool) throw const FormatException('enabled');
      if (startHour is! int) throw const FormatException('startHour');
      if (startMinute is! int) throw const FormatException('startMinute');
      if (endHour is! int) throw const FormatException('endHour');
      if (endMinute is! int) throw const FormatException('endMinute');
      if (policy is! String) throw const FormatException('policy');
      if (!QuietHoursPolicy.values.any((p) => p.storageKey == policy)) {
        throw const FormatException('policy');
      }
      return QuietHoursSettings(
        enabled: enabled,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        policy: QuietHoursPolicy.fromStorageKey(policy),
      );
    } catch (_) {
      return QuietHoursSettings.defaults();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuietHoursSettings &&
          other.enabled == enabled &&
          other.startHour == startHour &&
          other.startMinute == startMinute &&
          other.endHour == endHour &&
          other.endMinute == endMinute &&
          other.policy == policy;

  @override
  int get hashCode => Object.hash(
        enabled,
        startHour,
        startMinute,
        endHour,
        endMinute,
        policy,
      );
}

/// ラベル整形のみを担う内部ヘルパ（設定値とサービス双方から使う）。
abstract final class QuietHoursServiceLabel {
  static String formatMinutes(int minutes) {
    final normalized = ((minutes % 1440) + 1440) % 1440;
    final h = (normalized ~/ 60).toString().padLeft(2, '0');
    final m = (normalized % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
