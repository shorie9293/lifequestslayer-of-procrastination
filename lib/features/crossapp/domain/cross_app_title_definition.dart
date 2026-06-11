/// tsundoku-quest 連携で獲得できるクロスアプリ称号（11種）
///
/// Phase 1: 手動リンクコード（tsundoku user_id の先頭8文字）で本人確認。
/// Phase 2: Supabase Auth 連携で自動マッチング。
class CrossAppTitleDefinition {
  final String id; // 称号名（日本語）
  final String eventType; // トリガーとなるイベントタイプ
  final int threshold; // 獲得に必要なカウント値（metadata内のcount/streak_days/xp/pages）

  const CrossAppTitleDefinition({
    required this.id,
    required this.eventType,
    required this.threshold,
  });
}

/// 全クロスアプリ称号定義（11種）
///
/// イベント到着時に threshold を満たしていれば自動付与。
/// 重複付与は player.titles 重複チェックで防止。
const kCrossAppTitles = <CrossAppTitleDefinition>[
  // ── book_completed (1/5/10/50) ──
  CrossAppTitleDefinition(
    id: '読書家の卵',
    eventType: 'book_completed',
    threshold: 1,
  ),
  CrossAppTitleDefinition(
    id: '書庫の冒険者',
    eventType: 'book_completed',
    threshold: 5,
  ),
  CrossAppTitleDefinition(
    id: '知の探究者',
    eventType: 'book_completed',
    threshold: 10,
  ),
  CrossAppTitleDefinition(
    id: '千巻の賢者',
    eventType: 'book_completed',
    threshold: 50,
  ),

  // ── reading_streak (7/30/100) ──
  CrossAppTitleDefinition(
    id: '読書の継続者',
    eventType: 'reading_streak',
    threshold: 7,
  ),
  CrossAppTitleDefinition(
    id: '日々の読書人',
    eventType: 'reading_streak',
    threshold: 30,
  ),
  CrossAppTitleDefinition(
    id: '不滅の読書家',
    eventType: 'reading_streak',
    threshold: 100,
  ),

  // ── xp_milestone (1000/10000) ──
  CrossAppTitleDefinition(
    id: '知識の探求者',
    eventType: 'xp_milestone',
    threshold: 1000,
  ),
  CrossAppTitleDefinition(
    id: '知の航海者',
    eventType: 'xp_milestone',
    threshold: 10000,
  ),

  // ── pages_milestone (1000/10000) ──
  CrossAppTitleDefinition(
    id: 'ページを征く者',
    eventType: 'pages_milestone',
    threshold: 1000,
  ),
  CrossAppTitleDefinition(
    id: '万頁の読破者',
    eventType: 'pages_milestone',
    threshold: 10000,
  ),
];

/// イベントタイプに応じたクロスアプリ称号を返す
///
/// [currentCount] はイベントの metadata から取得した現在値（count, streak_days, xp, pages など）
List<CrossAppTitleDefinition> getMatchingCrossAppTitles(
    String eventType, int currentCount) {
  return kCrossAppTitles.where((t) {
    if (t.eventType != eventType) return false;
    return currentCount >= t.threshold;
  }).toList();
}

/// イベントタイプ → コイン報酬マッピング
const Map<String, int> kCrossAppCoinRewards = {
  'book_completed': 50,
  'reading_streak': 30,
  'level_up': 100,
  'xp_milestone': 80,
  'trophy_written': 60,
  'daily_mission_complete': 40,
  'pages_milestone': 70,
};

/// イベントタイプ → EXP報酬マッピング
const Map<String, int> kCrossAppExpRewards = {
  'book_completed': 200,
  'reading_streak': 100,
  'level_up': 500,
  'xp_milestone': 300,
  'trophy_written': 250,
  'daily_mission_complete': 150,
  'pages_milestone': 200,
};
