import 'player.dart';

/// 称号の定義。条件値をコードとUI表示で共有し、マジックナンバーの二重管理を防ぐ。
class TitleDefinition {
  final String id;
  final String condition;
  final int requiredCount;
  final int Function(Player) getProgress;

  const TitleDefinition({
    required this.id,
    required this.condition,
    required this.requiredCount,
    required this.getProgress,
  });
}

/// アプリ全体で参照する称号定義リスト（GameViewModel._checkTitles と TownScreen の両方が利用）
final List<TitleDefinition> kAllTitles = [
  TitleDefinition(
    id: '見習い冒険者',
    condition: '累計クエストを10回討伐',
    requiredCount: 10,
    getProgress: (p) => p.totalTasksCompleted,
  ),
  TitleDefinition(
    id: 'ベテラン',
    condition: '累計クエストを100回討伐',
    requiredCount: 100,
    getProgress: (p) => p.totalTasksCompleted,
  ),
  TitleDefinition(
    id: '鬼退治',
    condition: 'Bランククエストを50回討伐',
    requiredCount: 50,
    getProgress: (p) => p.totalBRankCompleted,
  ),
  TitleDefinition(
    id: '大物祓い',
    condition: 'Aランククエストを20回討伐',
    requiredCount: 20,
    getProgress: (p) => p.totalARankCompleted,
  ),
  TitleDefinition(
    id: '龍神討ち',
    condition: 'Sランククエストを5回討伐',
    requiredCount: 5,
    getProgress: (p) => p.totalSRankCompleted,
  ),
  TitleDefinition(
    id: '刻の番人を討ちし者',
    condition: '刻の番人（期限切れボス）を討伐',
    requiredCount: 1,
    getProgress: (p) => p.timesWardenDefeated,
  ),
  // ── ストリーク称号（UX-10） ──
  TitleDefinition(
    id: '月を跨ぎし者',
    condition: 'ストリーク30日達成',
    requiredCount: 30,
    getProgress: (p) => p.streakDays,
  ),
  TitleDefinition(
    id: '継続の達人',
    condition: 'ストリーク60日達成',
    requiredCount: 60,
    getProgress: (p) => p.streakDays,
  ),
  TitleDefinition(
    id: '時の支配者',
    condition: 'ストリーク100日達成',
    requiredCount: 100,
    getProgress: (p) => p.streakDays,
  ),
];
