/// 内省（振り返り）バッジの定義。
///
/// 討伐後の振り返り行動に基づいて獲得できるバッジ群。
/// [ReflectionBadgeService] で評価され、[Player.reflectionBadges] に格納される。
///
/// [requiresRepository]: true の場合、このバッジは [ReflectionRepository] を
/// 介した振り返り履歴の問い合わせが必要（ストリーク判定など）。
/// false の場合は [Player] のフィールドのみで判定可能。
class ReflectionBadgeDefinition {
  /// バッジを一意に識別するID（例: 'first_reflection'）。
  final String id;

  /// 表示名（例: '初めての内省'）。
  final String name;

  /// バッジ獲得条件の説明文。
  final String description;

  /// アイコン絵文字。
  final String icon;

  /// バッジの難易度（1=ブロンズ, 2=シルバー, 3=ゴールド, 4=伝説）。
  final int tier;

  /// このバッジの判定に [ReflectionRepository] が必要か。
  final bool requiresRepository;

  const ReflectionBadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.tier = 1,
    this.requiresRepository = false,
  });
}

/// アプリ全体で参照する内省バッジ定義リスト。
const List<ReflectionBadgeDefinition> kAllReflectionBadges = [
  // ── Tier 1: ブロンズ（数・初回系） ──

  ReflectionBadgeDefinition(
    id: 'first_reflection',
    name: '初めての内省',
    description: '初めて討伐後の振り返りを記した',
    icon: '🌱',
    tier: 1,
  ),

  ReflectionBadgeDefinition(
    id: 'reflection_novice',
    name: '内省の見習い',
    description: '振り返りを5回記した',
    icon: '📝',
    tier: 1,
  ),

  ReflectionBadgeDefinition(
    id: 'first_insight',
    name: '気づきの萌芽',
    description: '初めて50文字以上の学びを記した',
    icon: '💡',
    tier: 1,
  ),

  // ── Tier 2: シルバー（継続・中級） ──

  ReflectionBadgeDefinition(
    id: 'reflection_adept',
    name: '内省の達人',
    description: '振り返りを20回記した',
    icon: '📖',
    tier: 2,
  ),

  ReflectionBadgeDefinition(
    id: 'streak_3',
    name: '三日坊主打破',
    description: '3日連続で振り返りを記した',
    icon: '🔥',
    tier: 2,
    requiresRepository: true,
  ),

  ReflectionBadgeDefinition(
    id: 'honest_assessor',
    name: '誠実なる自己評価',
    description: '体感難易度4以上を記録した',
    icon: '⚖️',
    tier: 2,
  ),

  ReflectionBadgeDefinition(
    id: 'deep_insight',
    name: '深き洞察',
    description: '100文字以上の深い内省を記した',
    icon: '🔮',
    tier: 2,
  ),

  // ── Tier 3: ゴールド（上級） ──

  ReflectionBadgeDefinition(
    id: 'reflection_sage',
    name: '内省の賢者',
    description: '振り返りを50回記した',
    icon: '👁️',
    tier: 3,
  ),

  ReflectionBadgeDefinition(
    id: 'streak_7',
    name: '一週間の黙想',
    description: '7日連続で振り返りを記した',
    icon: '🔥',
    tier: 3,
    requiresRepository: true,
  ),

  ReflectionBadgeDefinition(
    id: 'self_awareness',
    name: '自己認識の開花',
    description: 'AI推定難易度と自己評価が一致した振り返りを3回記録',
    icon: '🌸',
    tier: 3,
    requiresRepository: true,
  ),

  // ── Tier 4: 伝説 ──

  ReflectionBadgeDefinition(
    id: 'reflection_master',
    name: '内省の大賢者',
    description: '振り返りを100回記した',
    icon: '🌟',
    tier: 4,
  ),

  ReflectionBadgeDefinition(
    id: 'streak_30',
    name: '一ヶ月の修行',
    description: '30日連続で振り返りを記した',
    icon: '☀️',
    tier: 4,
    requiresRepository: true,
  ),
];
