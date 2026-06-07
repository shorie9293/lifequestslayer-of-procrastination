/// コンボシステム: 連続討伐によるEXP倍率上昇。
///
/// 討伐成功のたびにコンボ数が増加し、それに応じてEXP倍率が上昇する。
/// 前回討伐から [comboTimeout] を超えるとコンボがリセットされる。
/// 討伐失敗（撤退）ではコンボ数は増加しないが、即座にリセットもされない。
///
/// 使用例:
/// ```dart
/// final combo = ComboSystem(comboTimeout: const Duration(minutes: 30));
/// combo.onVictory(); // comboCount=1, multiplier=1.0
/// combo.onVictory(); // comboCount=2, multiplier=1.1
/// // 30分経過後に再度 onVictory → comboCount=1 にリセット
/// ```
class ComboSystem {
  /// コンボが途切れるまでの猶予時間（デフォルト30分）。
  final Duration comboTimeout;

  /// コンボ倍率の上昇率（1コンボあたりの加算値）。
  /// デフォルト 0.1 → 2コンボで 1.1倍、10コンボで 2.0倍。
  final double multiplierStep;

  /// コンボ倍率の上限。
  final double maxMultiplier;

  /// 現在のコンボ数。
  int _comboCount = 0;

  /// 前回討伐成功時刻。
  DateTime? _lastCombatTime;

  /// 現在のコンボ倍率を計算するために使う時刻源（テスト用）。
  final DateTime Function() _clock;

  ComboSystem({
    this.comboTimeout = const Duration(minutes: 30),
    this.multiplierStep = 0.1,
    this.maxMultiplier = 5.0,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now());

  /// 現在のコンボ数。
  int get comboCount => _comboCount;

  /// 前回討伐時刻。
  DateTime? get lastCombatTime => _lastCombatTime;

  /// 現在のコンボ倍率。
  ///
  /// 時間切れの場合は 1.0 にリセットされてから返る。
  double get currentMultiplier {
    _checkTimeout();
    if (_comboCount == 0) return 1.0;
    final multiplier = 1.0 + (_comboCount - 1) * multiplierStep;
    return multiplier.clamp(1.0, maxMultiplier);
  }

  /// コンボが有効かどうか（コンボ数 >= 2 かつタイムアウトしていない）。
  bool get isComboActive {
    _checkTimeout();
    return _comboCount >= 2;
  }

  /// コンボの残り時間。
  /// コンボが無効またはタイムアウト済みの場合は Duration.zero。
  Duration get remainingComboTime {
    if (_comboCount == 0 || _lastCombatTime == null) return Duration.zero;
    final elapsed = _clock().difference(_lastCombatTime!);
    final remaining = comboTimeout - elapsed;
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  /// コンボボーナスEXPを計算する（基本EXP × コンボ倍率の上乗せ分）。
  int calcComboBonusExp(int baseExp) {
    final multiplier = currentMultiplier;
    if (multiplier <= 1.0) return 0;
    return (baseExp * (multiplier - 1.0)).round();
  }

  /// 討伐成功時の処理。
  ///
  /// タイムアウトしている場合はコンボをリセットしてから +1。
  /// そうでなければコンボ数を +1。
  ///
  /// [now] に討伐時刻を渡す（テスト用。省略時は DateTime.now()）。
  void onVictory({DateTime? now}) {
    final time = now ?? _clock();
    _lastCombatTime = time;
    _comboCount++;
  }

  /// 討伐失敗（撤退）時の処理。
  ///
  /// コンボ数は増加しないが、即座にリセットもされない。
  /// タイムアウトが来るまでは既存のコンボが維持される。
  void onDefeat() {
    // 何もしない — タイムアウトの自然切れを待つ
  }

  /// コンボを強制リセットする。
  void reset() {
    _comboCount = 0;
    _lastCombatTime = null;
  }

  /// タイムアウトチェック。
  /// 前回討伐から [comboTimeout] 以上経過していたらコンボをリセットする。
  void _checkTimeout() {
    if (_comboCount == 0 || _lastCombatTime == null) return;
    final elapsed = _clock().difference(_lastCombatTime!);
    if (elapsed >= comboTimeout) {
      _comboCount = 0;
      _lastCombatTime = null;
    }
  }
}
