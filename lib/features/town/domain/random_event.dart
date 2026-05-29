/// Event type enumeration for random town events.
enum EventType { merchant, bard, mysteriousOldMan }

/// Model for a random town event that appears in the town screen.
class RandomEvent {
  final EventType type;
  final String title;
  final String description;
  final String emoji;
  final Map<String, dynamic>? reward;

  const RandomEvent({
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    this.reward,
  });

  static const List<RandomEvent> merchantEvents = [
    RandomEvent(
      type: EventType.merchant,
      title: '旅の商人',
      description: '「特別な品を仕入れてきたぞ…コインと交換しないか？」\nゴールド: 500 を消費して 貴重なアイテムを手に入れた！',
      emoji: '🏪',
      reward: {'xp': 50, 'gems': 3},
    ),
    RandomEvent(
      type: EventType.merchant,
      title: '行商人',
      description: '珍しい魔導書の一節を譲ってもらった。経験値が微増した。',
      emoji: '🧳',
      reward: {'xp': 80},
    ),
  ];

  static const List<RandomEvent> bardEvents = [
    RandomEvent(
      type: EventType.bard,
      title: '吟遊詩人',
      description: '「遥か昔、この地には伝説の勇者がおった…」\n詩人の物語に心を打たれ、活力が湧いてくる。',
      emoji: '🎵',
      reward: {'xp': 100, 'fatigue_recovery': 1},
    ),
    RandomEvent(
      type: EventType.bard,
      title: '旅の芸人',
      description: '軽快な音楽と踊りで場が和む。疲れが少し癒された。',
      emoji: '🎶',
      reward: {'fatigue_recovery': 1},
    ),
  ];

  static const List<RandomEvent> oldManEvents = [
    RandomEvent(
      type: EventType.mysteriousOldMan,
      title: '謎の老人',
      description: '「フフ…その目はまだ、本当の世界を見ておらぬな。」\nヒントを残して、老人は去っていった。',
      emoji: '🔮',
      reward: {'xp': 30, 'hint': '深夜の討伐に隠された力あり'},
    ),
    RandomEvent(
      type: EventType.mysteriousOldMan,
      title: '賢者',
      description: '「継続は力なり。されど休息もまた力なり。」\n知恵の言葉が心に響く。',
      emoji: '📜',
      reward: {'xp': 50},
    ),
  ];
}
