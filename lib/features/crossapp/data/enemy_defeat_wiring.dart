import 'package:rpg_todo/features/crossapp/data/rpg_enemy_defeat_exporter.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';

/// TaskViewModel に敵討伐エクスポーターを配線する（契約 v1）。
///
/// [exporter] 省略時は既定パス（共有ストレージ）向けの実体を注入する。
/// 試練からは偽パスの [RpgEnemyDefeatExporter] を渡して差し替えられる。
void wireEnemyDefeatExporter(
  TaskViewModel taskVM, {
  IRpgEnemyDefeatExporter? exporter,
}) {
  taskVM.enemyDefeatExporter = exporter ?? const RpgEnemyDefeatExporter();
}
