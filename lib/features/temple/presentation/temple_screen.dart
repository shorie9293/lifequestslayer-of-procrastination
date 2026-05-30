import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class TempleScreen extends StatelessWidget {
  const TempleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerVM = context.watch<PlayerViewModel>();
    final player = playerVM.player;
    final adventurerLv = player.jobLevels[Job.adventurer] ?? 1;
    final currentJobLv = player.level;
    final canUnlockOtherJobs = adventurerLv >= 10;
    final canLeaveCurrentJob =
        player.currentJob == Job.adventurer || currentJobLv >= 10;
    final canChangeJob = canUnlockOtherJobs && canLeaveCurrentJob;
    final maxSlots = JobSkill.maxSkillSlots(player.jobLevels);

    // Get current job's skills (unlocked/locked)
    final currentJobSkills = JobSkill.values.where((s) => s.job == player.currentJob).toList();

    return Scaffold(
      key: AppKeys.templeScreen,
      appBar: AppBar(
        title: const Text('社'),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/temple_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: ListView(
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
                color: Colors.red.withValues(alpha: 0.2),
                child: Text(
                  "転職は浪人レベル10から可能です (現在 Lv.$adventurerLv)",
                  style: const TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            _buildJobCard(
              context,
              playerVM,
              Job.adventurer,
              "浪人",
              Icons.hiking,
              "基本の職業。まずはここから。",
              Colors.brown,
              player.currentJob == Job.adventurer,
              true,
              AppKeys.templeJobCardAdventurer,
            ),
            _buildJobCard(
              context,
              playerVM,
              Job.warrior,
              "侍",
              Icons.shield,
              "攻撃特化。\n特性: コンボボーナス (連続達成でEXP増)",
              Colors.red,
              player.currentJob == Job.warrior,
              canChangeJob,
              AppKeys.templeJobCardWarrior,
            ),
            _buildJobCard(
              context,
              playerVM,
              Job.cleric,
              "法師",
              Icons.health_and_safety,
              "回復・支援。\n特性: 繰り返しクエスト (日/週)",
              Colors.cyan,
              player.currentJob == Job.cleric,
              canChangeJob,
              AppKeys.templeJobCardCleric,
            ),
            _buildJobCard(
              context,
              playerVM,
              Job.wizard,
              "陰陽師",
              Icons.auto_fix_high,
              "知識・管理。\n特性: プロジェクト管理 (サブクエスト)",
              Colors.deepPurple,
              player.currentJob == Job.wizard,
              canChangeJob,
              AppKeys.templeJobCardWizard,
            ),

            // ━━━ スキルスロットセクション ━━━
            const SizedBox(height: 16),
            _buildSkillSlotSection(context, playerVM, player, maxSlots),

            // ━━━ 現在の職業スキル一覧 ━━━
            const SizedBox(height: 16),
            _buildCurrentJobSkillsSection(playerVM, player, currentJobSkills),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillSlotSection(
    BuildContext context,
    PlayerViewModel viewModel,
    Player player,
    int maxSlots,
  ) {
    final equipped = player.equippedSkills;
    return Container(
      key: AppKeys.templeSkillSlotSection,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.extension, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                "スキルスロット (${equipped.length}/$maxSlots)",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (maxSlots == 0)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                "浪人Lv.8以上でスキルスロットが解放されます",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ...List.generate(maxSlots, (index) {
            final isSlotFilled = index < equipped.length;
            final eqSkill = isSlotFilled ? equipped[index] : null;
            return _buildSlotRow(
              context, viewModel, player, index, eqSkill, isSlotFilled);
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '他の職業を育てると、そのスキルをスロットに装備できます。'
                    'Lv到達で解放されたスキルが候補に表示されます。',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotRow(
    BuildContext context,
    PlayerViewModel viewModel,
    Player player,
    int slotIndex,
    EquippedSkill? eqSkill,
    bool isFilled,
  ) {
    // Collect all unlockable skills from OTHER jobs (not current job)
    final allSkills = JobSkill.values.where((s) {
      if (s.job == player.currentJob) return false; // Current job skills are always active
      if (s.job == Job.adventurer) return false; // Ronin skills always active
      return (player.jobLevels[s.job] ?? 0) >= 1; // At least Lv1 to consider
    }).toList();

    // Filter to only skills that can actually be learned (level requirement met)
    final learnableSkills = allSkills.where((s) {
      final jobLevel = player.jobLevels[s.job] ?? 1;
      return jobLevel >= s.requiredLevel;
    }).toList();

    return Container(
      key: Key('slot_$slotIndex'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFilled
            ? Colors.blueGrey.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text("枠${slotIndex + 1}: ",
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(
            child: isFilled
                ? Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: Colors.greenAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${_jobDisplayName(eqSkill!.skill.job)}・${eqSkill.skill.displayName}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : const Text("空きスロット",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          if (isFilled && eqSkill != null) ...[
            // ON/OFF toggle
            SizedBox(
              height: 24,
              child: Switch(
                value: eqSkill.isActive,
                onChanged: (val) {
                  viewModel.toggleEquippedSkill(slotIndex);
                  viewModel.save();
                },
                activeColor: Colors.cyanAccent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          if (eqSkill != null && eqSkill.skill.isMasterSkill)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text("常時発動",
                  style: TextStyle(
                      color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          if (isFilled)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  size: 18, color: Colors.redAccent),
              onPressed: () {
                viewModel.unequipSkill(slotIndex);
                viewModel.save();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (!isFilled && learnableSkills.isNotEmpty)
            PopupMenuButton<JobSkill>(
              key: AppKeys.templeSkillSlotDropdown,
              icon: const Icon(Icons.add_circle_outline,
                  size: 18, color: Colors.cyanAccent),
              onSelected: (skill) {
                viewModel.equipSkill(skill);
                viewModel.save();
              },
              itemBuilder: (context) =>
                  learnableSkills.map((skill) {
                return PopupMenuItem<JobSkill>(
                  value: skill,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${_jobDisplayName(skill.job)}・${skill.displayName}",
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        skill.description,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentJobSkillsSection(
    PlayerViewModel viewModel,
    Player player,
    List<JobSkill> skills,
  ) {
    final currentJobLevel = player.level;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                "${_jobDisplayName(player.currentJob)}のスキル (Lv.$currentJobLevel)",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...skills.map((skill) {
            final isUnlocked = currentJobLevel >= skill.requiredLevel;
            final isMastered = skill.isMasterSkill && skill.isMastered(currentJobLevel);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isUnlocked ? Icons.check_circle : Icons.lock,
                    size: 16,
                    color: isUnlocked ? Colors.greenAccent : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill.displayName,
                          style: TextStyle(
                            color: isUnlocked ? Colors.white : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          skill.description,
                          style: TextStyle(
                            color: isUnlocked
                                ? Colors.white54
                                : Colors.grey.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "Lv.${skill.requiredLevel}",
                    style: TextStyle(
                      color: isUnlocked ? Colors.white60 : Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                  if (isMastered) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("MASTER",
                          style: TextStyle(
                              color: Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _jobDisplayName(Job job) {
    switch (job) {
      case Job.adventurer:
        return '浪人';
      case Job.warrior:
        return '侍';
      case Job.cleric:
        return '法師';
      case Job.wizard:
        return '陰陽師';
    }
  }
  Widget _buildJobCard(
    BuildContext context,
    PlayerViewModel viewModel,
    Job job,
    String title,
    IconData icon,
    String description,
    Color color,
    bool isSelected,
    bool isUnlocked,
    Key cardKey,
  ) {
    final player = viewModel.player;
    final level = player.jobLevels[job] ?? 1;
    final isMastered = player.isMastered(job);
    final isSkillActive = player.activeSkills.contains(job);

    return Card(
      key: cardKey,
      color: isSelected ? color.withValues(alpha: 0.2) : null,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: isSelected ? BorderSide(color: color, width: 2) : BorderSide.none,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SemanticHelper.interactive(
        testId: SemanticHelper.createTestId(
            SemanticTypes.button, 'job_${job.name}'),
        label: isUnlocked ? '$titleに転職する' : '$title（ロック中）',
        child: InkWell(
        onTap: isUnlocked || isSelected
            ? () {
                if (!isSelected) {
                  viewModel.changeJob(job);
                  context.read<PlayerViewModel>().save();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$title に転職しました！")),
                  );
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? color.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        size: 32, color: isUnlocked ? color : Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isUnlocked
                                      ? (isSelected ? color : Colors.white)
                                      : Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text("Lv.$level",
                                style: const TextStyle(color: Colors.white)),
                            if (isMastered) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text("MASTER",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10)),
                              )
                            ]
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                              color: isUnlocked ? Colors.white70 : Colors.grey),
                        ),
                        if (!isUnlocked)
                          Text(
                            (player.jobLevels[Job.adventurer] ?? 1) < 10
                                ? '浪人Lv.10 解放'
                                : '現在の職業でLv.10 解放',
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold),
                          ),
              ],
            ),
          ),
          if (isSelected) Icon(Icons.check_circle, color: color),
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
                    SemanticHelper.toggle(
                      testId: SemanticHelper.createTestId(
                          SemanticTypes.toggle, 'skill_${job.name}'),
                      value: isSkillActive,
                      onChanged: (val) {
                        viewModel.toggleSkill(job); context.read<PlayerViewModel>().save();
                      },
                      child: Switch(
                      key: AppKeys.templeSkillToggle,
                      value: isSkillActive,
                      onChanged: (val) {
                        viewModel.toggleSkill(job); context.read<PlayerViewModel>().save();
                      },
                      activeColor: color,
                    ),
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
                    Text("常時スキル発動中 (ランク・枠数)",
                        style: TextStyle(color: Colors.grey))
                  ],
                )
              ]
            ],
          ),
        ),
      ),
      ),
    );
  }
}
