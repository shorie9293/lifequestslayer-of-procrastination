import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';
import 'package:rpg_todo/features/temple/presentation/pomodoro_timer_screen.dart';
import 'package:rpg_todo/domain/services/skill_progression_service.dart';
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
    final palette = GamePalette.of(context);

    // Get current job's skills (unlocked/locked)
    final currentJobSkills =
        JobSkill.values.where((s) => s.job == player.currentJob).toList();

    return Scaffold(
      key: AppKeys.templeScreen,
      appBar: AppBar(
        title: const Text('寺院'),
        actions: [
          IconButton(
            key: AppKeys.pomodoroEntry,
            icon: const Icon(Icons.timer_outlined),
            tooltip: '集中の型（ポモドーロ）',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PomodoroTimerScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '神託補佐（ヘルプ）',
            onPressed: () => showHelpDialog(context, screen: HelpScreen.temple),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          // ライトは和紙無地（暗い情景画像の上に墨文字は沈むため敷かない）。
          color: palette.usesBackdropImage
              ? null
              : Theme.of(context).scaffoldBackgroundColor,
          image: palette.usesBackdropImage
              ? DecorationImage(
                  image: const AssetImage('assets/images/temple_bg.png'),
                  fit: BoxFit.cover,
                  colorFilter:
                      ColorFilter.mode(palette.scrim, BlendMode.darken),
                )
              : null,
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
                color: palette.usesBackdropImage
                    ? Colors.red.withValues(alpha: 0.2)
                    : palette.danger.withValues(alpha: 0.12),
                child: Text(
                  "転職は浪人レベル10から可能です (現在 Lv.$adventurerLv)",
                  style: TextStyle(
                      color: palette.usesBackdropImage
                          ? Colors.redAccent
                          : palette.danger,
                      fontWeight: FontWeight.bold),
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
              Job.samurai,
              "侍",
              Icons.shield,
              "攻撃特化。\n特性: コンボボーナス (連続達成でEXP増)",
              Colors.red,
              player.currentJob == Job.samurai,
              canChangeJob,
              AppKeys.templeJobCardSamurai,
            ),
            _buildJobCard(
              context,
              playerVM,
              Job.monk,
              "法師",
              Icons.health_and_safety,
              "回復・支援。\n特性: 繰り返しクエスト (日/週)",
              Colors.cyan,
              player.currentJob == Job.monk,
              canChangeJob,
              AppKeys.templeJobCardMonk,
            ),
            _buildJobCard(
              context,
              playerVM,
              Job.mystic,
              "陰陽師",
              Icons.auto_fix_high,
              "知識・管理。\n特性: プロジェクト管理 (サブクエスト)",
              Colors.deepPurple,
              player.currentJob == Job.mystic,
              canChangeJob,
              AppKeys.templeJobCardMystic,
            ),

            // ━━━ スキルスロットセクション ━━━
            const SizedBox(height: 16),
            _buildSkillSlotSection(context, playerVM, player, maxSlots),

            // ━━━ 現在の職業スキル一覧 ━━━
            const SizedBox(height: 16),
            _buildCurrentJobSkillsSection(
                context, playerVM, player, currentJobSkills),

            // ━━━ 修行の道標（スキル/ジョブ進捗の俯瞰） ━━━
            const SizedBox(height: 16),
            _buildSkillProgressionCard(context, player),
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
    final palette = GamePalette.of(context);
    final equipped = player.equippedSkills;
    return Container(
      key: AppKeys.templeSkillSlotSection,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.usesBackdropImage
            ? Colors.black.withValues(alpha: 0.3)
            : palette.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: palette.usesBackdropImage
                ? Colors.blueGrey.withValues(alpha: 0.5)
                : palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.extension,
                  color: palette.readable(Colors.cyanAccent), size: 20),
              const SizedBox(width: 8),
              Text(
                "スキルスロット (${equipped.length}/$maxSlots)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.readable(Colors.cyanAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (maxSlots == 0)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                "浪人Lv.8以上でスキルスロットが解放されます",
                style: TextStyle(
                    color: palette.usesBackdropImage
                        ? Colors.grey
                        : palette.onSurfaceFaint,
                    fontSize: 12),
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
              color: palette.usesBackdropImage
                  ? Colors.white.withValues(alpha: 0.05)
                  : palette.track,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: palette.onSurfaceFaintest),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '他の職業を育てると、そのスキルをスロットに装備できます。'
                    'Lv到達で解放されたスキルが候補に表示されます。',
                    style: TextStyle(
                      color: palette.usesBackdropImage
                          ? Colors.white.withValues(alpha: 0.4)
                          : palette.onSurfaceFaintest,
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
      if (s.job == player.currentJob)
        return false; // Current job skills are always active
      if (s.job == Job.adventurer) return false; // Ronin skills always active
      return (player.jobLevels[s.job] ?? 0) >= 1; // At least Lv1 to consider
    }).toList();

    // Filter to only skills that can actually be learned (level requirement met)
    final learnableSkills = allSkills.where((s) {
      final jobLevel = player.jobLevels[s.job] ?? 1;
      return jobLevel >= s.requiredLevel;
    }).toList();
    final palette = GamePalette.of(context);

    return Container(
      key: Key('slot_$slotIndex'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.usesBackdropImage
            ? (isFilled
                ? Colors.blueGrey.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1))
            : palette.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text("枠${slotIndex + 1}: ",
              style: TextStyle(color: palette.onSurfaceMuted, fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(
            child: isFilled
                ? Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 14,
                          color: palette.readable(Colors.greenAccent)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${_jobDisplayName(eqSkill!.skill.job)}・${eqSkill.skill.displayName}",
                          style:
                              TextStyle(color: palette.onSurface, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Text("空きスロット",
                    style: TextStyle(
                        color: palette.usesBackdropImage
                            ? Colors.grey
                            : palette.onSurfaceFaint,
                        fontSize: 12)),
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
                activeColor: palette.readable(Colors.cyanAccent),
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
              child: Text("常時発動",
                  style: TextStyle(
                      color: palette.readable(Colors.amber),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          if (isFilled)
            IconButton(
              icon: Icon(Icons.remove_circle_outline,
                  size: 18, color: palette.readable(Colors.redAccent)),
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
              icon: Icon(Icons.add_circle_outline,
                  size: 18, color: palette.readable(Colors.cyanAccent)),
              onSelected: (skill) {
                viewModel.equipSkill(skill);
                viewModel.save();
              },
              itemBuilder: (context) => learnableSkills.map((skill) {
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
                        style: TextStyle(
                            fontSize: 10,
                            color: palette.usesBackdropImage
                                ? Colors.grey
                                : palette.onSurfaceFaint),
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
    BuildContext context,
    PlayerViewModel viewModel,
    Player player,
    List<JobSkill> skills,
  ) {
    final palette = GamePalette.of(context);
    final currentJobLevel = player.level;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.usesBackdropImage
            ? Colors.black.withValues(alpha: 0.3)
            : palette.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: palette.usesBackdropImage
                ? Colors.teal.withValues(alpha: 0.5)
                : palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  color: palette.readable(Colors.tealAccent), size: 20),
              const SizedBox(width: 8),
              Text(
                "${_jobDisplayName(player.currentJob)}のスキル (Lv.$currentJobLevel)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: palette.readable(Colors.tealAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...skills.map((skill) {
            final isUnlocked = currentJobLevel >= skill.requiredLevel;
            final isMastered =
                skill.isMasterSkill && skill.isMastered(currentJobLevel);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isUnlocked ? Icons.check_circle : Icons.lock,
                    size: 16,
                    color: isUnlocked
                        ? palette.readable(Colors.greenAccent)
                        : (palette.usesBackdropImage
                            ? Colors.grey
                            : palette.onSurfaceFaint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill.displayName,
                          style: TextStyle(
                            color: isUnlocked
                                ? palette.onSurface
                                : (palette.usesBackdropImage
                                    ? Colors.grey
                                    : palette.onSurfaceFaint),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          skill.description,
                          style: TextStyle(
                            color: isUnlocked
                                ? palette.onSurfaceFaint
                                : (palette.usesBackdropImage
                                    ? Colors.grey.withValues(alpha: 0.5)
                                    : palette.onSurfaceFaintest),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "Lv.${skill.requiredLevel}",
                    style: TextStyle(
                      color: isUnlocked
                          ? (palette.usesBackdropImage
                              ? Colors.white60
                              : palette.onSurfaceMuted)
                          : palette.readable(Colors.redAccent),
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
                      child: Text("MASTER",
                          style: TextStyle(
                              color: palette.readable(Colors.amber),
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

  /// 修行の道標 — スキルツリーとジョブ習得の進捗俯瞰（道標§五 #30）。
  Widget _buildSkillProgressionCard(BuildContext context, Player player) {
    final palette = GamePalette.of(context);
    final report = SkillProgressionService.compute(player);
    return Container(
      key: AppKeys.templeProgressionSection,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.usesBackdropImage
            ? Colors.black.withValues(alpha: 0.3)
            : palette.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: palette.usesBackdropImage
                ? Colors.amber.withValues(alpha: 0.5)
                : palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline,
                  color: palette.readable(Colors.amber), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '修行の道標（スキル ${report.totalUnlocked}/${report.totalNodes}'
                  '・残りポイント ${report.skillPoints}）',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: palette.readable(Colors.amber),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ジョブ習得進捗
          ...report.jobs.map((j) {
            final label = _jobDisplayName(j.job);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(label,
                        style:
                            TextStyle(color: palette.onSurface, fontSize: 12)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      key: AppKeys.templeProgressionJobBar(j.job),
                      value: j.progressRatio,
                      backgroundColor: palette.usesBackdropImage
                          ? Colors.white24
                          : palette.track,
                      color: j.isMastered
                          ? palette.readable(Colors.amber)
                          : palette.readable(Colors.tealAccent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    j.isMastered
                        ? '習得済み'
                        : 'Lv.${j.level}/習得まであと${j.levelsToMaster}',
                    style: TextStyle(
                      color: j.isMastered
                          ? palette.readable(Colors.amber)
                          : (palette.usesBackdropImage
                              ? Colors.white60
                              : palette.onSurfaceMuted),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          // 次に解放できるスキルノード
          if (report.trees.any((t) => t.hasNextNode)) ...[
            Text('次に解放できる技:',
                style: TextStyle(
                    color: palette.readable(Colors.tealAccent),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            ...report.trees.where((t) => t.hasNextNode).map((t) {
              final node = t.nextNode!;
              final treeLabel = _jobDisplayName(t.tree);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      t.nextNodeAffordable
                          ? Icons.lock_open
                          : Icons.lock_outline,
                      size: 14,
                      color: t.nextNodeAffordable
                          ? palette.readable(Colors.greenAccent)
                          : (palette.usesBackdropImage
                              ? Colors.grey
                              : palette.onSurfaceFaint),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$treeLabel・${node.name}（${node.pointCost}pt）',
                        style:
                            TextStyle(color: palette.onSurface, fontSize: 12),
                      ),
                    ),
                    Text(
                      t.nextNodeAffordable
                          ? '解放可能'
                          : 'あと${t.pointsShortfall}pt',
                      style: TextStyle(
                        color: t.nextNodeAffordable
                            ? palette.readable(Colors.greenAccent)
                            : palette.readable(Colors.redAccent),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('全ての技を極めた！',
                  style: TextStyle(
                      color: palette.readable(Colors.amber), fontSize: 12)),
            ),
        ],
      ),
    );
  }

  String _jobDisplayName(Job job) {
    switch (job) {
      case Job.adventurer:
        return '浪人';
      case Job.samurai:
        return '侍';
      case Job.monk:
        return '法師';
      case Job.mystic:
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
    final palette = GamePalette.of(context);
    final onScene = palette.usesBackdropImage;
    final level = player.jobLevels[job] ?? 1;
    final isMastered = player.isMastered(job);
    final isSkillActive = player.activeSkills.contains(job);
    // 選択カードの実効地（職業色 20% を画面地に重ねた色）。職業色は濃色
    // （例: 浪人の Colors.brown）でダーク地では 2.55:1 まで沈むため、
    // 無変換の readable() ではなく地に対して解決する readableOn() を使う。
    final selectedCardBackground = Color.alphaBlend(
        color.withValues(alpha: 0.2),
        Theme.of(context).scaffoldBackgroundColor);
    final accentOnSelectedCard = palette.isLight
        ? palette.readable(color)
        : palette.readableOn(color, selectedCardBackground);

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
                          size: 32,
                          color: isUnlocked
                              ? accentOnSelectedCard
                              : (onScene
                                  ? Colors.grey
                                  : palette.onSurfaceFaint)),
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
                                        ? (isSelected
                                            ? accentOnSelectedCard
                                            : palette.onSurface)
                                        : (onScene
                                            ? Colors.grey
                                            : palette.onSurfaceFaint),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text("Lv.$level",
                                  style: TextStyle(color: palette.onSurface)),
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
                                color: isUnlocked
                                    ? palette.onSurfaceMuted
                                    : (onScene
                                        ? Colors.grey
                                        : palette.onSurfaceFaint)),
                          ),
                          if (!isUnlocked)
                            Text(
                              (player.jobLevels[Job.adventurer] ?? 1) < 10
                                  ? '浪人Lv.10 解放'
                                  : '現在の職業でLv.10 解放',
                              style: TextStyle(
                                  color: palette.readable(Colors.redAccent),
                                  fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: accentOnSelectedCard),
                    if (!isSelected && !isUnlocked)
                      Icon(Icons.lock,
                          color:
                              onScene ? Colors.grey : palette.onSurfaceFaint),
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
                          viewModel.toggleSkill(job);
                          context.read<PlayerViewModel>().save();
                        },
                        child: Switch(
                          key: AppKeys.templeSkillToggle,
                          value: isSkillActive,
                          onChanged: (val) {
                            viewModel.toggleSkill(job);
                            context.read<PlayerViewModel>().save();
                          },
                          activeColor: palette.readable(color),
                        ),
                      )
                    ],
                  )
                ],
                if (isMastered && job == Job.adventurer && !isSelected) ...[
                  const Divider(),
                  Row(
                    children: [
                      Icon(Icons.star,
                          size: 16, color: palette.readable(Colors.amber)),
                      const SizedBox(width: 4),
                      Text("常時スキル発動中 (ランク・枠数)",
                          style: TextStyle(
                              color: onScene
                                  ? Colors.grey
                                  : palette.onSurfaceFaint))
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
