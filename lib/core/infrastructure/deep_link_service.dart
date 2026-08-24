/// アプリ間送客用ディープリンクの解析を担当するサービス。
///
/// URL パースロジックを分離し、単体テスト可能にする。
/// kozuchi の `DeepLinkService` を踏襲した static utility。
///
/// 対応URL形式:
///   app://cross-reward?source=<送客元現世>&reward=<報酬タイプ>
///
/// 例:
///   app://cross-reward?source=rpg-task&reward=quest_complete
class DeepLinkService {
  DeepLinkService._(); // インスタンス化不要（static utility）

  static const String _scheme = 'app';
  static const String _host = 'cross-reward';

  /// アプリ間送客用URIを生成する。
  ///
  /// [source] は送客元現世（例: "rpg-task"）、[reward] は報酬タイプ
  /// （例: "quest_complete"）。
  static Uri build({required String source, required String reward}) {
    return Uri(
      scheme: _scheme,
      host: _host,
      queryParameters: <String, String>{
        'source': source,
        'reward': reward,
      },
    );
  }

  /// [uri] が `app://cross-reward?source=...&reward=...` 形式にマッチする場合、
  /// source と reward を抽出した [CrossRewardLink] を返す。
  ///
  /// scheme が "app" でない、host が "cross-reward" でない、または
  /// source / reward パラメータが存在しない場合は `null`。
  static CrossRewardLink? parse(Uri uri) {
    if (uri.scheme != _scheme || uri.host != _host) {
      return null;
    }
    final source = uri.queryParameters['source'];
    final reward = uri.queryParameters['reward'];
    if (source == null || reward == null) {
      return null;
    }
    return CrossRewardLink(source: source, reward: reward);
  }

  /// [uri] がアプリ間送客用ディープリンクかどうかを判定する。
  static bool isCrossRewardLink(Uri uri) => parse(uri) != null;
}

/// アプリ間送客用ディープリンクの解析結果。
class CrossRewardLink {
  /// 送客元現世（例: "rpg-task"）。
  final String source;

  /// 報酬タイプ（例: "quest_complete"）。
  final String reward;

  const CrossRewardLink({required this.source, required this.reward});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrossRewardLink &&
          other.source == source &&
          other.reward == reward;

  @override
  int get hashCode => Object.hash(source, reward);

  @override
  String toString() =>
      'CrossRewardLink(source: $source, reward: $reward)';
}
