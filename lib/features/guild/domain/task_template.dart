import 'package:rpg_todo/domain/models/task.dart';

/// 勤行の定型タスク（クイックテンプレート・改善提案 #73）。
///
/// 頻出の勤行（名前・難易度・サブタスク・繰り返し）を定型として保存し、
/// ワンタップで寄合所に起票できるようにする。
///
/// 不変条件:
/// - [name]（定型名）と [title]（クエスト名）は空文字を許さない（ArgumentError）
/// - [subTaskTitles] は空行を除去して保持する
class TaskTemplate {
  final String id;

  /// 定型名（一覧に表示される名前・重複禁止）
  final String name;

  /// 起票されるクエスト名
  final String title;
  final QuestRank rank;
  final RepeatInterval repeatInterval;
  final List<int> repeatWeekdays; // 1=Mon, ..., 7=Sun
  final List<String> subTaskTitles;
  final int? targetTimeMinutes;

  TaskTemplate({
    required this.id,
    required this.name,
    required this.title,
    this.rank = QuestRank.B,
    this.repeatInterval = RepeatInterval.none,
    List<int>? repeatWeekdays,
    List<String>? subTaskTitles,
    this.targetTimeMinutes,
  })  : repeatWeekdays = _cleanWeekdays(repeatWeekdays),
        subTaskTitles = _cleanSubTasks(subTaskTitles) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', '定型名が空です');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'クエスト名が空です');
    }
  }

  static List<int> _cleanWeekdays(List<int>? raw) {
    if (raw == null) return const [];
    final seen = <int>{};
    final out = <int>[];
    for (final d in raw) {
      if (d >= 1 && d <= 7 && seen.add(d)) out.add(d);
    }
    return out;
  }

  static List<String> _cleanSubTasks(List<String>? raw) {
    if (raw == null) return const [];
    return [
      for (final s in raw)
        if (s.trim().isNotEmpty) s.trim(),
    ];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'rank': rank.name,
        'repeatInterval': repeatInterval.name,
        'repeatWeekdays': repeatWeekdays,
        'subTaskTitles': subTaskTitles,
        'targetTimeMinutes': targetTimeMinutes,
      };

  /// 破損JSONは例外を投げる（リポジトリ側で読み飛ばす）。
  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    final rankName = json['rank'] as String?;
    final repeatName = json['repeatInterval'] as String?;
    final weekdaysRaw = json['repeatWeekdays'];
    final subTasksRaw = json['subTaskTitles'];
    final target = json['targetTimeMinutes'];
    return TaskTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      title: json['title'] as String,
      rank: QuestRank.values
          .where((r) => r.name == rankName)
          .firstOrNull ?? QuestRank.B,
      repeatInterval: RepeatInterval.values
          .where((r) => r.name == repeatName)
          .firstOrNull ?? RepeatInterval.none,
      repeatWeekdays: weekdaysRaw is List
          ? weekdaysRaw.whereType<int>().toList()
          : null,
      subTaskTitles: subTasksRaw is List
          ? subTasksRaw.whereType<String>().toList()
          : null,
      targetTimeMinutes: target is int ? target : null,
    );
  }

  /// 編集ダイアログ等での複製。
  TaskTemplate copyWith({
    String? id,
    String? name,
    String? title,
    QuestRank? rank,
    RepeatInterval? repeatInterval,
    List<int>? repeatWeekdays,
    List<String>? subTaskTitles,
    int? targetTimeMinutes,
    bool clearTargetTime = false,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      rank: rank ?? this.rank,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatWeekdays:
          repeatWeekdays ?? List<int>.from(this.repeatWeekdays),
      subTaskTitles:
          subTaskTitles ?? List<String>.from(this.subTaskTitles),
      targetTimeMinutes:
          clearTargetTime ? null : (targetTimeMinutes ?? this.targetTimeMinutes),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskTemplate &&
      other.id == id &&
      other.name == name &&
      other.title == title &&
      other.rank == rank &&
      other.repeatInterval == repeatInterval &&
      _listEq(other.repeatWeekdays, repeatWeekdays) &&
      _listEq(other.subTaskTitles, subTaskTitles) &&
      other.targetTimeMinutes == targetTimeMinutes;

  @override
  int get hashCode => Object.hash(id, name, title, rank, repeatInterval,
      Object.hashAll(repeatWeekdays), Object.hashAll(subTaskTitles),
      targetTimeMinutes);

  static bool _listEq(List a, List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 勤行テンプレートの純粋サービス（改善提案 #73）。
///
/// すべての関数は入力を破壊せず、例外も投げない（validateNew は列挙を返す）。
class TaskTemplateService {
  const TaskTemplateService();

  /// 定型名の正規化（全角英数・全角スペース→半角・小文字化・空白圧縮）。
  String normalizeName(String raw) {
    final half = _toHalfWidth(raw).trim();
    final parts =
        half.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return parts.join(' ').toLowerCase();
  }

  String _toHalfWidth(String raw) {
    final sb = StringBuffer();
    for (final code in raw.runes) {
      var c = code;
      // 全角英数・数字・記号 (0xFF01-0xFF5E) → 半角
      if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0;
      // 全角スペース
      if (c == 0x3000) c = 0x20;
      sb.writeCharCode(c);
    }
    return sb.toString();
  }

  /// 重複判定用の比較キー（正規化 + 全空白除去）。
  String comparisonKey(String raw) =>
      normalizeName(raw).replaceAll(' ', '');

  /// 新規定型名の検証。問題の列挙を返す（空なら無問題）。
  List<String> validateNew(
      {required String name, required List<TaskTemplate> existing}) {
    final problems = <String>[];
    if (name.trim().isEmpty) {
      problems.add('定型名が空です');
      return problems;
    }
    final key = comparisonKey(name);
    final dup = existing.any((t) => comparisonKey(t.name) == key);
    if (dup) problems.add('同名の定型が既に存在します');
    return problems;
  }

  /// 定型からクエストを組立（id は呼出側で採番する）。
  ///
  /// サブタスクは未完了で生成する（定型の起票は常に新規クエスト）。
  Task buildTask(TaskTemplate template, {required String id}) {
    return Task(
      id: id,
      title: template.title,
      rank: template.rank,
      repeatInterval: template.repeatInterval,
      repeatWeekdays:
          template.repeatWeekdays.isEmpty ? null : template.repeatWeekdays,
      subTasks: template.subTaskTitles.isEmpty
          ? null
          : [
              for (final st in template.subTaskTitles)
                SubTask(title: st, isCompleted: false),
            ],
      targetTimeMinutes: template.targetTimeMinutes,
    );
  }

  /// 既存クエストを定型として取り込む（実行状態は落とす）。
  TaskTemplate fromTask(
      {required String id, required String name, required Task task}) {
    return TaskTemplate(
      id: id,
      name: name,
      title: task.title,
      rank: task.rank,
      repeatInterval: task.repeatInterval,
      repeatWeekdays: List<int>.from(task.repeatWeekdays),
      subTaskTitles: [
        for (final st in task.subTasks) st.title,
      ],
      targetTimeMinutes: task.targetTimeMinutes,
    );
  }

  /// 定型名の昇順ソート（非破壊・同値は id 昇順）。
  List<TaskTemplate> sortByName(List<TaskTemplate> templates) {
    final list = templates.toList();
    list.sort((a, b) {
      final byName =
          normalizeName(a.name).compareTo(normalizeName(b.name));
      if (byName != 0) return byName;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  /// 定型名・クエスト名の部分一致検索（正規化比較・非破壊）。
  List<TaskTemplate> searchByName(
      {required List<TaskTemplate> templates, required String query}) {
    final q = normalizeName(query);
    if (q.isEmpty) return List<TaskTemplate>.from(templates);
    return [
      for (final t in templates)
        if (normalizeName(t.name).contains(q) ||
            normalizeName(t.title).contains(q))
          t,
    ];
  }
}
