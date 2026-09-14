/// 勤行リマインダーの設定値オブジェクト。
///
/// 不変（immutable）。[weekdays] は `DateTime.weekday` 準拠
/// （1=月 .. 7=日）の昇順ユニーク。空リストは「通知日なし」を表す。
class ReminderSettings {
  ReminderSettings({
    this.enabled = false,
    this.hour = 6,
    this.minute = 30,
    List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.updatedAt,
  }) : weekdays = List.unmodifiable(weekdays) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', '0-23 の範囲で指定せよ');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', '0-59 の範囲で指定せよ');
    }
    for (final w in this.weekdays) {
      if (w < 1 || w > 7) {
        throw ArgumentError.value(w, 'weekdays', '1(月)-7(日) の範囲で指定せよ');
      }
    }
  }

  /// 既定値: 無効・6:30・毎日。
  factory ReminderSettings.defaults() => ReminderSettings();

  final bool enabled;
  final int hour;
  final int minute;
  final List<int> weekdays;
  final DateTime? updatedAt;

  /// 毎日（月〜日すべて）通知するか。
  bool get isDaily => weekdays.length == 7;

  ReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    List<int>? weekdays,
    DateTime? updatedAt,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'weekdays': List<int>.of(weekdays),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  /// 型不一致・欠落・範囲外は [FormatException]。
  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    try {
      final enabled = json['enabled'];
      final hour = json['hour'];
      final minute = json['minute'];
      final weekdays = json['weekdays'];
      final updatedAt = json['updatedAt'];
      if (enabled is! bool) throw const FormatException('enabled');
      if (hour is! int) throw const FormatException('hour');
      if (minute is! int) throw const FormatException('minute');
      if (weekdays is! List) throw const FormatException('weekdays');
      if (weekdays.any((w) => w is! int)) {
        throw const FormatException('weekdays');
      }
      final weekdayList = List<int>.from(weekdays.cast<int>());
      DateTime? updatedAtParsed;
      if (updatedAt is String) {
        updatedAtParsed = DateTime.tryParse(updatedAt);
        if (updatedAtParsed == null) throw const FormatException('updatedAt');
      } else if (updatedAt != null) {
        throw const FormatException('updatedAt');
      }
      return ReminderSettings(
        enabled: enabled,
        hour: hour,
        minute: minute,
        weekdays: weekdayList,
        updatedAt: updatedAtParsed,
      );
    } on ArgumentError {
      throw const FormatException('ReminderSettings の範囲外の値');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettings &&
          other.enabled == enabled &&
          other.hour == hour &&
          other.minute == minute &&
          other.updatedAt == updatedAt &&
          _listEquals(other.weekdays, weekdays);

  @override
  int get hashCode =>
      Object.hash(enabled, hour, minute, updatedAt, Object.hashAll(weekdays));

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
