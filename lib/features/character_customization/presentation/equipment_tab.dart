import 'package:flutter/material.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';
import 'package:rpg_todo/features/character_customization/presentation/widgets/avatar_preview_widget.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// キャラクター装備タブ — 5部位のスキン選択UI。
///
/// [TownScreen] 内のタブとして表示され、
/// プレイヤーの解放済みスキンから各部位の装備を変更できる。
class EquipmentTab extends StatefulWidget {
  final CharacterSkin currentSkin;
  final int playerLevel;
  final int streakDays;
  final int totalTasks;
  final List<String> titles;
  final void Function(SkinSlot slot, String skinId) onEquip;

  const EquipmentTab({
    super.key,
    required this.currentSkin,
    required this.playerLevel,
    required this.streakDays,
    required this.totalTasks,
    required this.titles,
    required this.onEquip,
  });

  @override
  State<EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends State<EquipmentTab> {
  SkinSlot? _selectedSlot;
  String? _previewSkinId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              Icon(Icons.face, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '装備',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // アバタープレビューエリア
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                AvatarPreviewWidget(
                  characterSkin: widget.currentSkin,
                  previewSlot: _selectedSlot,
                  previewSkinId: _previewSkinId,
                  size: 140,
                ),
                const SizedBox(height: 8),
                if (_selectedSlot != null && _previewSkinId != null)
                  Text(
                    '「${SkinCatalog.findById(_previewSkinId!)?.name ?? ''}」をプレビュー中',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // スロット選択チップ
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: SkinSlot.values.map((slot) {
              final isSelected = _selectedSlot == slot;
              final currentId = widget.currentSkin.getSlot(slot);
              final skinDef = SkinCatalog.findById(currentId);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'equip_slot_${slot.name}'),
                  label: '${slot.displayName}を選択',
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(skinDef?.icon ?? '❓'),
                        const SizedBox(width: 4),
                        Text(slot.displayName),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedSlot = isSelected ? null : slot;
                        _previewSkinId = null;
                      });
                    },
                    selectedColor: Colors.amber.shade700,
                    backgroundColor: Colors.brown.shade800,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // 選択されたスロットのスキン一覧
        if (_selectedSlot != null)
          Expanded(
            child: _buildSkinList(_selectedSlot!),
          )
        else
          const Expanded(
            child: Center(
              child: Text(
                '装備部位を選んでね',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSkinList(SkinSlot slot) {
    final allSkins = SkinCatalog.skinsForSlot(slot);
    final currentId = widget.currentSkin.getSlot(slot);

    final unlocked = allSkins.where((s) {
      return s.isUnlocked(
        level: widget.playerLevel,
        streakDays: widget.streakDays,
        totalTasks: widget.totalTasks,
        titles: widget.titles,
      );
    }).toList();

    final locked = allSkins
        .where((s) =>
            !s.isUnlocked(
              level: widget.playerLevel,
              streakDays: widget.streakDays,
              totalTasks: widget.totalTasks,
              titles: widget.titles,
            ) &&
            s.id != 'default')
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // 解放済みスキン
        ...unlocked.map((skin) {
          final isEquipped = skin.id == currentId;
          return _buildSkinTile(skin, isEquipped: isEquipped, locked: false);
        }),
        // 未解放スキン（ロック表示）
        if (locked.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '── 未解放 ──',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          ...locked.map((skin) {
            return _buildSkinTile(skin, isEquipped: false, locked: true);
          }),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSkinTile(
    SkinDefinition skin, {
    required bool isEquipped,
    required bool locked,
  }) {
    final isPreviewing = _previewSkinId == skin.id;
    return Card(
      color: isPreviewing
          ? Colors.amber.shade900.withValues(alpha: 0.4)
          : Colors.black54,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: locked
            ? null
            : () {
                setState(() {
                  _previewSkinId = skin.id;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
        leading: Text(skin.icon, style: const TextStyle(fontSize: 28)),
        title: Text(
          skin.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: locked ? Colors.white38 : Colors.white,
          ),
        ),
        subtitle: Text(
          locked ? skin.unlockConditionDescription : skin.description,
          style: TextStyle(
            color: locked ? Colors.white30 : Colors.white54,
            fontSize: 12,
          ),
        ),
        trailing: locked
            ? const Icon(Icons.lock, color: Colors.white30, size: 20)
            : isEquipped
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '装備中',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                      SemanticTypes.button, 'equip_${skin.id}'),
                    label: '${skin.name}を装備する',
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('装備'),
                      onPressed: () {
                        widget.onEquip(skin.slot, skin.id);
                        setState(() {
                          _previewSkinId = skin.id;
                        });
                      },
                    ),
                  ),
      ),
      ),
    );
  }
}
