// 端末間の町データ突き合わせ（純粋関数）。
//
// クラウドは常に正ではない。オフラインで育てた端末の方が進んでいる場合も
// あるため「レベル→累積XP」の順で大きい方を正とする。

/// クラウドとローカルのどちらを採用するか。
class TownSyncDecision {
  const TownSyncDecision({required this.takeCloud, required this.pushLocal});

  /// クラウドの町レベルを採用する（クラウドの方が進んでいる）。
  final bool takeCloud;

  /// ローカルの町レベルをクラウドへ書き戻す（ローカルの方が進んでいる）。
  final bool pushLocal;

  bool get inSync => !takeCloud && !pushLocal;
}

/// 町レベルの突き合わせ。
///
/// レベルが大きい方が新しい。同じレベルなら累積XPが大きい方が新しい。
/// 完全一致なら [TownSyncDecision.inSync]（何もしない）。
TownSyncDecision decideTownSync({
  required int localLevel,
  required int localXp,
  required int cloudLevel,
  required int cloudXp,
}) {
  if (cloudLevel != localLevel) {
    final cloudAhead = cloudLevel > localLevel;
    return TownSyncDecision(takeCloud: cloudAhead, pushLocal: !cloudAhead);
  }
  if (cloudXp != localXp) {
    final cloudAhead = cloudXp > localXp;
    return TownSyncDecision(takeCloud: cloudAhead, pushLocal: !cloudAhead);
  }
  return const TownSyncDecision(takeCloud: false, pushLocal: false);
}

/// 建物は「建物ごとに高いレベルを採る」。
///
/// クラウド側のエントリを渡すと、ローカルの方が高いものはローカルを残す。
bool shouldTakeCloudBuilding({required int localLevel, required int cloudLevel}) =>
    cloudLevel > localLevel;
