/// クロスアプリ報酬の「発生元現世」を表す純粋ロジック。
///
/// 報酬イベントのファイル名と送客先ディープリンク（`app://<world>`）の
/// 唯一の対応表。I/O も Flutter 依存も持たないので、単体試練で直接検証できる。
///
/// ファイル名は 5 現世共通の契約（`SharedCrossAppFiles`）だが、domain 層から
/// infrastructure 層へ依存させないため、ここではリテラルで持ち、
/// 契約との一致は `cross_app_world_test.dart` がドリフト検知する。
class CrossAppWorld {
  const CrossAppWorld._({
    required this.id,
    required this.displayName,
    required this.eventsFileName,
  });

  /// ディープリンク host に使う識別子（`app://<id>`）。
  final String id;

  /// 人間向け表示名（ボタンラベルに使う）。
  final String displayName;

  /// この現世が書き出す報酬イベントのファイル名。
  final String eventsFileName;

  static const CrossAppWorld tsundoku = CrossAppWorld._(
    id: 'tsundoku',
    displayName: 'tsundoku-quest',
    eventsFileName: 'tsundoku_reward_events.jsonl',
  );

  static const CrossAppWorld election = CrossAppWorld._(
    id: 'election',
    displayName: 'election-game',
    eventsFileName: 'election_reward_events.jsonl',
  );

  static const CrossAppWorld bookReview = CrossAppWorld._(
    id: 'book-review',
    displayName: 'book-review-app',
    eventsFileName: 'book_review_reward_events.jsonl',
  );

  /// 既知の全現世（順序は走査既定順と一致）。
  static const List<CrossAppWorld> values = <CrossAppWorld>[
    tsundoku,
    election,
    bookReview,
  ];

  /// 送客先ディープリンク文字列（正準形は `app://<world>`）。
  String get deepLink => 'app://$id';

  /// 送客ボタンの試練用 testId 断片（`book-review` → `open_book_review`）。
  String get openButtonKey => 'open_${id.replaceAll('-', '_')}';

  /// パスでもファイル名でも受け取り、対応する現世を返す。未知なら null。
  static CrossAppWorld? fromFileName(String pathOrName) {
    final base = pathOrName.split('/').last.split(r'\').last;
    for (final world in values) {
      if (world.eventsFileName == base) return world;
    }
    return null;
  }

  /// world id から現世を引く。未知なら null。
  static CrossAppWorld? fromId(String id) {
    for (final world in values) {
      if (world.id == id) return world;
    }
    return null;
  }
}
