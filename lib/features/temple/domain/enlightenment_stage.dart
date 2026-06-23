/// 修行段階（悟りの境地）— 法師の智慧が深まるにつれて昇華する精神的段階。
///
/// 知恵ポイント（wisdomPoints）の蓄積に応じて昇格し、
/// 各段階への初到達時には専用のアニメーションが再生される。
enum EnlightenmentStage {
  /// 初転法輪（しょてんぽうりん）— 修行の入り口。法の輪を初めて回す。
  shohorin(displayName: '初転法輪', stageIndex: 0, wisdomRequired: 0),

  /// 縁起（えんぎ）— 万物の繋がりを悟る。曼荼羅が心に開く。
  engi(displayName: '縁起', stageIndex: 1, wisdomRequired: 10),

  /// 空（くう）— 執着を離れ、世界の真実を見る。一切が反転する。
  ku(displayName: '空', stageIndex: 2, wisdomRequired: 30);

  const EnlightenmentStage({
    required this.displayName,
    required this.stageIndex,
    required this.wisdomRequired,
  });

  /// 和名表示。
  final String displayName;

  /// 段階の序数（0始まり）。
  final int stageIndex;

  /// この段階に到達するために必要な知恵ポイント。
  final int wisdomRequired;

  /// 現在の知恵ポイントから本来あるべき段階を返す。
  static EnlightenmentStage forWisdom(int wisdomPoints) {
    // 降順でチェック（高い段階から判定）
    for (final stage in values.reversed) {
      if (wisdomPoints >= stage.wisdomRequired) {
        return stage;
      }
    }
    return shohorin;
  }
}

/// 修行段階の遷移時に再生されるアニメーション種別。
enum EnlightenmentTransitionType {
  /// 曼荼羅展開（初転法輪→縁起）。
  mandala,

  /// 世界反転（縁起→空）。
  reversal,
}
