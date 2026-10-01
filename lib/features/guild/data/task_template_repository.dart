import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:rpg_todo/features/guild/domain/task_template.dart';

/// 勤行テンプレート（改善提案 #73）の永続化リポジトリ抽象。
abstract class TaskTemplateRepository {
  /// 全定型を取得する（保存順）。
  Future<List<TaskTemplate>> load();

  /// 全定型を差し替えて保存する。
  Future<void> save(List<TaskTemplate> templates);
}

/// [TaskTemplateRepository] の Hive 実装。
///
/// Hive Box `task_templates` に キー = 定型ID / 値 = JSON文字列 で保存する。
/// TypeAdapter 登録を要さないため異種端末・移行に強い。
/// 破損レコードは読み飛ばし、健全な定型を守る（全損させない）。
class HiveTaskTemplateRepository implements TaskTemplateRepository {
  static const String boxName = 'task_templates';

  final Box<String>? _injectedBox;

  /// 試練用: Box を外から注入する（実 Hive を触らずに検証できる）。
  HiveTaskTemplateRepository({Box<String>? box}) : _injectedBox = box;

  Box<String>? _openedBox;

  Future<Box<String>> _getBox() async {
    final injected = _injectedBox;
    if (injected != null) return injected;
    final opened = _openedBox;
    if (opened != null && opened.isOpen) return opened;
    _openedBox = await Hive.openBox<String>(boxName);
    return _openedBox!;
  }

  /// Hive 未初期化（UI試練環境など）では null を返す。
  ///
  /// 定型はベストエフォート永続であるため、永続層の不在で画面を落としてはならない。
  Future<Box<String>?> _getBoxOrNull() async {
    try {
      return await _getBox();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TaskTemplate>> load() async {
    final box = await _getBoxOrNull();
    if (box == null) return const [];
    final templates = <TaskTemplate>[];
    for (final raw in box.values) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        templates.add(TaskTemplate.fromJson(decoded));
      } catch (_) {
        // 破損レコードは無視する（残りの定型を失わせないため）
      }
    }
    return templates;
  }

  @override
  Future<void> save(List<TaskTemplate> templates) async {
    final box = await _getBoxOrNull();
    if (box == null) return;
    await box.clear();
    for (final t in templates) {
      await box.put(t.id, jsonEncode(t.toJson()));
    }
  }
}

/// 試練・フォールバック用のインメモリ実装。
class InMemoryTaskTemplateRepository implements TaskTemplateRepository {
  List<TaskTemplate> _templates = [];

  @override
  Future<List<TaskTemplate>> load() async => List.from(_templates);

  @override
  Future<void> save(List<TaskTemplate> templates) async {
    _templates = List.from(templates);
  }
}
