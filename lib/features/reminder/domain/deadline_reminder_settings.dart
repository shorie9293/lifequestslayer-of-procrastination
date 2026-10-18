/// 締切リマインド（期限間近クエストの通知）の設定値オブジェクト。
///
/// 勤行リマインダー（[ReminderSettings]）とは **完全に独立**した設定であり、
/// 永続キーも別（`deadlineReminder`）である。不変（immutable）。
class DeadlineReminderSettings {
  DeadlineReminderSettings({
    this.enabled = false,
    this.hour = 8,
    this.minute = 0,
    this.withinDays = 3,
    this.updatedAt,
  }) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', '0-23 の範囲で指定せよ');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', '0-59 の範囲で指定せよ');
    }
    if (withinDays < 1 || withinDays > 30) {
      throw ArgumentError.value(withinDays, 'withinDays', '1-30 の範囲で指定せよ');
    }
  }

  /// 既定値: 無効・8:00・3日以内。
  factory DeadlineReminderSettings.defaults() => DeadlineReminderSettings();

  final bool enabled;
  final int hour;
  final int minute;

  /// 何日先までを「期限間近」とみなすか（1=当日のみ、3=当日〜2日後）。
  final int withinDays;

  final DateTime? updatedAt;

  DeadlineReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? withinDays,
    DateTime? updatedAt,
  }) {
    return DeadlineReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      withinDays: withinDays ?? this.withinDays,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'withinDays': withinDays,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  /// 型不一致・欠落・範囲外は [FormatException]。
  factory DeadlineReminderSettings.fromJson(Map<String, dynamic> json) {
    try {
      final enabled = json['enabled'];
      final hour = json['hour'];
      final minute = json['minute'];
      final withinDays = json['withinDays'];
      final updatedAt = json['updatedAt'];
      if (enabled is! bool) throw const FormatException('enabled');
      if (hour is! int) throw const FormatException('hour');
      if (minute is! int) throw const FormatException('minute');
      if (withinDays is! int) throw const FormatException('withinDays');
      DateTime? updatedAtParsed;
      if (updatedAt is String) {
        updatedAtParsed = DateTime.tryParse(updatedAt);
        if (updatedAtParsed == null) throw const FormatException('updatedAt');
      } else if (updatedAt != null) {
        throw const FormatException('updatedAt');
      }
      return DeadlineReminderSettings(
        enabled: enabled,
        hour: hour,
        minute: minute,
        withinDays: withinDays,
        updatedAt: updatedAtParsed,
      );
    } on ArgumentError {
      throw const FormatException('DeadlineReminderSettings の範囲外の値');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeadlineReminderSettings &&
          other.enabled == enabled &&
          other.hour == hour &&
          other.minute == minute &&
          other.withinDays == withinDays &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(enabled, hour, minute, withinDays, updatedAt);
}
