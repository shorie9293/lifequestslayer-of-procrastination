import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;
import 'package:uuid/uuid.dart';

import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/calendar_link/data/calendar_gateway.dart';
import 'package:rpg_todo/features/calendar_link/domain/calendar_import_service.dart';
import 'package:rpg_todo/features/calendar_link/domain/linked_calendar_event.dart';

import 'calendar_link_keys.dart';

/// 読み込みの進行状態。
enum CalendarImportPhase { loading, ready, denied, unsupported, error }

/// 端末カレンダーの予定をクエストとして取り込む画面。
///
/// [gateway]・[onImport]・[now]・[idGenerator] を注入でき、Provider/端末API に
/// 依存せず試練できる。本番は寄合所の⋯メニューから実タスクと TaskViewModel を渡す。
class CalendarImportScreen extends StatefulWidget {
  const CalendarImportScreen({
    super.key,
    this.tasksOverride,
    this.gateway,
    this.now,
    this.onImport,
    this.idGenerator,
  });

  /// 重複判定に使う既存クエスト。未指定時は空。
  final List<Task>? tasksOverride;

  /// カレンダー読み取り実装。未指定時は MethodChannel 実装。
  final CalendarGateway? gateway;

  /// 現在日時（試練用に固定できる）。
  final DateTime? now;

  /// 取り込み確定時の受け渡し先。未指定時は画面内で完結する。
  final void Function(List<Task> tasks)? onImport;

  /// クエストIDの採番器（試練用に固定できる）。
  final String Function()? idGenerator;

  @override
  State<CalendarImportScreen> createState() => _CalendarImportScreenState();
}

class _CalendarImportScreenState extends State<CalendarImportScreen> {
  late final CalendarGateway _gateway;
  late final DateTime _now;

  CalendarImportPhase _phase = CalendarImportPhase.loading;
  String _errorMessage = '';
  CalendarImportRange _range = CalendarImportRange.today;
  List<LinkedCalendarEvent> _events = const <LinkedCalendarEvent>[];
  final Set<String> _selectedIds = <String>{};
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? MethodChannelCalendarGateway();
    _now = widget.now ?? DateTime.now();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _phase = CalendarImportPhase.loading;
      _errorMessage = '';
    });

    if (!_gateway.isSupported) {
      setState(() => _phase = CalendarImportPhase.unsupported);
      return;
    }

    try {
      final status = await _gateway.ensureAccess();
      switch (status) {
        case CalendarAccessStatus.denied:
          setState(() => _phase = CalendarImportPhase.denied);
          return;
        case CalendarAccessStatus.unsupported:
          setState(() => _phase = CalendarImportPhase.unsupported);
          return;
        case CalendarAccessStatus.granted:
          break;
      }

      final from = DateTime(_now.year, _now.month, _now.day);
      final to = from
          .add(Duration(days: CalendarImportRange.next7Days.days))
          .subtract(const Duration(seconds: 1));
      final events = await _gateway.readEvents(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _events = events;
        _phase = CalendarImportPhase.ready;
        _syncSelection();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is CalendarGatewayException
            ? e.message
            : 'カレンダーの読み取りに失敗しました';
        _phase = CalendarImportPhase.error;
      });
    }
  }

  List<LinkedCalendarEvent> get _candidates =>
      CalendarImportService.selectCandidates(
        _events,
        now: _now,
        range: _range,
        existing: widget.tasksOverride ?? const <Task>[],
      );

  /// 表示中の予定のうち、未選択のものを既定で選択状態にする。
  void _syncSelection() {
    final candidates = _candidates;
    final visible = candidates.map((e) => e.eventId).toSet();
    _selectedIds.removeWhere((id) => !visible.contains(id));
    for (final e in candidates) {
      _selectedIds.add(e.eventId);
    }
  }

  List<LinkedCalendarEvent> get _selectedEvents =>
      _candidates.where((e) => _selectedIds.contains(e.eventId)).toList();

  void _import() {
    final selected = _selectedEvents;
    if (selected.isEmpty || _importing) return;
    setState(() => _importing = true);
    final tasks = CalendarImportService.buildTasks(
      selected,
      idGenerator: widget.idGenerator ?? () => const Uuid().v4(),
    );
    widget.onImport?.call(tasks);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tasks.length}件のクエストを追加しました')),
    );
    Navigator.of(context).maybePop(tasks.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: CalendarLinkAppKeys.screen,
      appBar: AppBar(title: const Text('カレンダーから取り込む')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _body(),
        ),
      ),
    );
  }

  List<Widget> _body() {
    switch (_phase) {
      case CalendarImportPhase.loading:
        return const <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(key: CalendarLinkAppKeys.loading),
            ),
          ),
        ];
      case CalendarImportPhase.unsupported:
        return <Widget>[
          const Text(
            'この端末ではカレンダー連携を使えません。\n（Android 版のみ対応）',
            key: CalendarLinkAppKeys.unsupported,
          ),
          const SizedBox(height: 16),
          _retryButton(),
        ];
      case CalendarImportPhase.denied:
        return <Widget>[
          const Text(
            'カレンダーの読み取りが許可されていません。\n'
            '端末の設定から権限を許可したうえで、もう一度お試しください。',
            key: CalendarLinkAppKeys.permissionDenied,
          ),
          const SizedBox(height: 16),
          _retryButton(),
        ];
      case CalendarImportPhase.error:
        return <Widget>[
          Text(
            _errorMessage,
            key: CalendarLinkAppKeys.errorState,
            style: const TextStyle(color: Color(0xFFB3261E)),
          ),
          const SizedBox(height: 16),
          _retryButton(),
        ];
      case CalendarImportPhase.ready:
        return _readyBody();
    }
  }

  List<Widget> _readyBody() {
    final candidates = _candidates;
    final selectedCount = _selectedEvents.length;
    return <Widget>[
      Wrap(
        key: CalendarLinkAppKeys.rangeChips,
        spacing: 8,
        children: <Widget>[
          for (final range in CalendarImportRange.values)
            SemanticHelper.interactive(
              testId: SemanticHelper.createTestId(
                  SemanticTypes.button, 'calendar_import_${range.name}'),
              label: range.label,
              child: FilterChip(
                key: CalendarLinkAppKeys.rangeChip(range),
                label: Text(range.label),
                selected: _range == range,
                onSelected: (_) => setState(() {
                  _range = range;
                  _syncSelection();
                }),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        '${candidates.length}件の予定（$selectedCount件を選択中）',
        key: CalendarLinkAppKeys.countLabel,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      if (candidates.isEmpty)
        const Text(
          'この期間に取り込める予定がありません',
          key: CalendarLinkAppKeys.emptyState,
          style: TextStyle(color: Color(0xFF888888)),
        )
      else
        Column(
          key: CalendarLinkAppKeys.eventList,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final event in candidates) _eventTile(event),
          ],
        ),
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerRight,
        child: SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'calendar_import'),
          label: '取り込む',
          child: ElevatedButton.icon(
            key: CalendarLinkAppKeys.importButton,
            onPressed:
                selectedCount == 0 || _importing ? null : _import,
            icon: const Icon(Icons.download_done),
            label: Text('$selectedCount件を取り込む'),
          ),
        ),
      ),
    ];
  }

  Widget _eventTile(LinkedCalendarEvent event) {
    final checked = _selectedIds.contains(event.eventId);
    return CheckboxListTile(
      key: CalendarLinkAppKeys.eventTile(event.eventId),
      value: checked,
      onChanged: (value) => setState(() {
        if (value == true) {
          _selectedIds.add(event.eventId);
        } else {
          _selectedIds.remove(event.eventId);
        }
      }),
      title: Text(event.title.trim()),
      subtitle: Text(_subtitle(event)),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  Widget _retryButton() {
    return SemanticHelper.interactive(
      testId: SemanticHelper.createTestId(
          SemanticTypes.button, 'calendar_import_retry'),
      label: '再試行',
      child: ElevatedButton(
        key: CalendarLinkAppKeys.retryButton,
        onPressed: _load,
        child: const Text('再試行'),
      ),
    );
  }

  /// 例: 「11/03 10:00–11:30」「11/03 終日」
  static String _subtitle(LinkedCalendarEvent event) {
    final date = '${event.start.month.toString().padLeft(2, '0')}/'
        '${event.start.day.toString().padLeft(2, '0')}';
    if (event.allDay) return '$date 終日';
    final from = '${event.start.hour.toString().padLeft(2, '0')}:'
        '${event.start.minute.toString().padLeft(2, '0')}';
    final to = '${event.end.hour.toString().padLeft(2, '0')}:'
        '${event.end.minute.toString().padLeft(2, '0')}';
    return '$date $from–$to';
  }
}
