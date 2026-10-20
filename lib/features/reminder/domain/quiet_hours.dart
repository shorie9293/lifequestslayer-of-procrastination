/// 静穏時間（おやすみモード）中に予定された通知の扱い方針。
enum QuietHoursPolicy {
  /// 翌朝（静穏時間の終了時刻）まで繰り延べる。
  defer(label: '翌朝に繰り延べ', storageKey: 'defer'),

  /// 通知しない（送出しない）。
  skip(label: '通知しない', storageKey: 'skip');

  const QuietHoursPolicy({required this.label, required this.storageKey});

  /// 画面表示用ラベル。
  final String label;

  /// 永続化用キー。
  final String storageKey;

  /// 永続化キーから復元する。未知・null は [QuietHoursPolicy.defer]。
  static QuietHoursPolicy fromStorageKey(String? key) {
    for (final policy in QuietHoursPolicy.values) {
      if (policy.storageKey == key) return policy;
    }
    return QuietHoursPolicy.defer;
  }
}
