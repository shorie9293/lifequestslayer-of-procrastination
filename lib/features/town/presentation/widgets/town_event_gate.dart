import 'package:flutter/material.dart';
import 'package:rpg_todo/features/town/domain/random_event.dart';
import 'package:rpg_todo/features/town/presentation/widgets/town_event_overlay.dart';

/// 町のランダムイベントを「1回だけ抽選し、出会ったら overlay で見せる」宿主。
///
/// [checkEvent] が null のときは**何もしない**（抽選器も Hive も触らない）。
/// これにより `const TownScreen()` を組む既存試練が Hive 未初期化のまま
/// 走って zone 汚染する事故を構造的に防ぐ。
///
/// 抽選は initState で1回だけ（町タブの再描画で何度も抽選しない）。
class TownEventGate extends StatefulWidget {
  final Widget child;

  /// 抽選関数。null なら不活性（試練・Hive 未初期化環境の既定）。
  final Future<RandomEvent?> Function()? checkEvent;

  /// イベントが実際に表示された時に1回だけ呼ばれる（報酬付与の接続点）。
  final void Function(RandomEvent event)? onEventShown;

  const TownEventGate({
    super.key,
    required this.child,
    this.checkEvent,
    this.onEventShown,
  });

  @override
  State<TownEventGate> createState() => _TownEventGateState();
}

class _TownEventGateState extends State<TownEventGate> {
  RandomEvent? _event;
  bool _rolled = false;

  @override
  void initState() {
    super.initState();
    _rollOnce();
  }

  Future<void> _rollOnce() async {
    final checker = widget.checkEvent;
    if (checker == null || _rolled) return;
    _rolled = true;

    RandomEvent? event;
    try {
      event = await checker();
    } catch (_) {
      // 抽選の失敗で町画面を壊さない（イベントは出ないだけ）。
      event = null;
    }
    if (!mounted || event == null) return;

    setState(() => _event = event);
    // 表示された時に一度だけ報酬を接続する（rebuild で二重付与しない）。
    widget.onEventShown?.call(event);
  }

  void _close() {
    if (!mounted) return;
    setState(() => _event = null);
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (event != null) TownEventOverlay(event: event, onClose: _close),
      ],
    );
  }
}
