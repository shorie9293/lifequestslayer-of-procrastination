import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/player.dart';

class TempleScreen extends StatelessWidget {
  const TempleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final player = gameState.player;
    // Unlock Condition: Adventurer Lv 10 to switch to others? 
    // Previous: player.level >= 10. (Which uses current job level).
    // If I switch to Warrior Lv1, player.level becomes 1.
    // So "canChangeJob" might fail if I am Warrior Lv1.
    // BUT user said "Warrior Lv20 -> Wizard".
    // So if I am Warrior Lv1, I should still be able to switch back to Adventurer or others if I ALREADY unlocked them?
    // Let's use: If Adventurer Level >= 10 OR Current Level >= 10?
    // Actually, persistence means once I unlock, I should keep access?
    // Simplest interpretation: You need Adventurer Lv10 to unlock the Temple functionality (other jobs).
    final adventurerLv = player.jobLevels[Job.adventurer] ?? 1;
    final canChangeJob = adventurerLv >= 10;

    return Scaffold(
      appBar: AppBar(
        title: const Text('転職の神殿'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "新たな道を歩むがよい...",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
           if (!canChangeJob)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.withOpacity(0.2),
              child: Text(
                "転職は冒険者レベル10から可能です (現在 Lv.$adventurerLv)",
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),
          _buildJobCard(
            context,
            gameState,
            Job.adventurer,
            "冒険者 (Adventurer)",
            Icons.hiking,
            "基本の職業。まずはここから。",
            Colors.brown,
            player.currentJob == Job.adventurer,
            true, // Always allowed if it's default/fallback? Or should we allow switching back? Yes.
          ),
          _buildJobCard(
            context,
            gameState,
            Job.warrior,
            "戦士 (Warrior)",
            Icons.shield,
            "攻撃特化。\n特性: コンボボーナス (連続達成でEXP増)",
            Colors.red,
            player.currentJob == Job.warrior,
            canChangeJob,
          ),
          _buildJobCard(
            context,
            gameState,
            Job.cleric,
            "僧侶 (Cleric)",
            Icons.health_and_safety,
            "回復・支援。\n特性: 繰り返しタスク (日/週)",
            Colors.cyan,
            player.currentJob == Job.cleric,
            canChangeJob,
          ),
          _buildJobCard(
            context,
            gameState,
            Job.wizard,
            "魔法使い (Wizard)",
            Icons.auto_fix_high,
            "知識・管理。\n特性: プロジェクト管理 (サブタスク)",
            Colors.deepPurple,
            player.currentJob == Job.wizard,
            canChangeJob,
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(
    BuildContext context,
    GameState gameState,
    Job job,
    String title,
    IconData icon,
    String description,
    Color color,
    bool isSelected,
    bool isUnlocked,
  ) {
    final player = gameState.player;
    final level = player.jobLevels[job] ?? 1;
    final isMastered = player.isMastered(job);
    final isSkillActive = player.activeSkills.contains(job);

    return Card(
      color: isSelected ? color.withOpacity(0.2) : null,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: isSelected ? BorderSide(color: color, width: 2) : BorderSide.none,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isUnlocked || isSelected ? () {
          if (!isSelected) {
             gameState.changeJob(job);
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("$title に転職しました！")),
             );
          }
        } : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUnlocked ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: isUnlocked ? color : Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked ? (isSelected ? color : Colors.white) : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text("Lv.$level", style: const TextStyle(color: Colors.white)),
                            if (isMastered) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                                child: const Text("MASTER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                              )
                            ]
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description, 
                          style: TextStyle(color: isUnlocked ? Colors.white70 : Colors.grey),
                        ),
                        if (!isUnlocked)
                           Text(
                             "冒険者Lv.10 解放",
                             style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                           ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: color),
                  if (!isSelected && !isUnlocked)
                    const Icon(Icons.lock, color: Colors.grey),
                ],
              ),
              // Skill Toggle for Mastered Jobs (if not current job)
              if (isMastered && !isSelected && job != Job.adventurer) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("スキル継承 (ON/OFF)"),
                    Switch(
                      value: isSkillActive, 
                      onChanged: (val) {
                        gameState.toggleSkill(job);
                      },
                      activeColor: color,
                    )
                  ],
                )
              ],
              if (isMastered && job == Job.adventurer && !isSelected) ...[
                 const Divider(),
                 const Row(
                   children: [
                     Icon(Icons.star, size: 16, color: Colors.amber),
                     SizedBox(width: 4),
                     Text("常時スキル発動中 (ランク・枠数)", style: TextStyle(color: Colors.grey))
                   ],
                 )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
