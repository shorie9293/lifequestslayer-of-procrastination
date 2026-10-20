import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/streak_freeze/data/streak_freeze_repository.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_service.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_state.dart';
import 'package:rpg_todo/features/streak_freeze/presentation/streak_freeze_app_keys.dart';

/// 連続記録お休み券（#153）の画面。
///
/// 残数・使用提案・使用履歴を提示する。券の消費とプレイヤー復元は
/// 「使う」を押した時のみ行う（自動消費しない）。
class StreakFreezeScreen extends StatefulWidget {
  const StreakFreezeScreen({
    super.key,
    this.repository,
    this.playerViewModel,
    this.clock,
  });

  /// 未指定なら Hive 実装。試練ではメモリ実装を注入する。
  final StreakFreezeRepository? repository;

  /// 未指定なら Provider から取得する。
  final PlayerViewModel? playerViewModel;

  /// 時計（試練での固定用）。未指定なら [DateTime.now]。
  final DateTime Function()? clock;

  @override
  State<StreakFreezeScreen> createState() => _StreakFreezeScreenState();
}

class _StreakFreezeScreenState extends State<StreakFreezeScreen> {
  late final StreakFreezeRepository _repository =
      widget.repository ?? HiveStreakFreezeRepository();

  StreakFreezeState? _state;
  String? _error;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  PlayerViewModel _vm(BuildContext context) =>
      widget.playerViewModel ?? context.read<PlayerViewModel>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await _repository.load();
      if (!mounted) return;
      final vm = _vm(context);
      // 到達済みマイルストーン（7日ごと）の券をここで付与する（冪等）。
      final (reconciled, granted) =
          StreakFreezeService.reconcile(loaded, vm.player.streakDays);
      if (granted > 0) {
        await _repository.save(reconciled);
      }
      if (!mounted) return;
      setState(() {
        _state = reconciled;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _use(PlayerViewModel vm, StreakFreezeOffer offer) async {
    final state = _state;
    if (state == null) return;
    if (!StreakFreezeService.canCover(state, offer.missedDays)) return;

    final now = _now();
    final next = StreakFreezeService.consume(
      state,
      missedDays: offer.missedDays,
      previousStreak: offer.previousStreak,
      now: now,
      coveredDates: offer.missedDateKeys,
    );
    // 券の消費を先に永続化する（プレイヤー復元だけ進んで券が減らない事故を防ぐ）。
    await _repository.save(next);
    final restored =
        StreakFreezeService.restorePlayer(vm.player, previousStreak: offer.previousStreak, now: now);
    vm.applyStreakFreeze(now);
    if (!mounted) return;
    setState(() => _state = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'お休み券を使って連続記録を守りました（連続 ${restored.streakDays}日）'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm(context);
    final state = _state;
    return Scaffold(
      key: StreakFreezeKeys.screen,
      appBar: AppBar(title: const Text('連続記録お休み券')),
      body: _buildBody(context, vm, state),
    );
  }

  Widget _buildBody(
      BuildContext context, PlayerViewModel vm, StreakFreezeState? state) {
    if (_error != null) {
      return Center(child: Text('お休み券を読み込めませんでした: $_error'));
    }
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final offer = vm.pendingStreakFreezeOffer;
    final needed = offer == null
        ? 0
        : StreakFreezeService.ticketsNeeded(offer.missedDays);
    final canUse = offer != null && StreakFreezeService.canCover(state, offer.missedDays);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  StreakFreezeService.ticketsLabel(state),
                  key: StreakFreezeKeys.ticketCount,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${StreakFreezeService.grantIntervalDays}日連続するごとに1枚授かり、'
                  '1枚で1日分の空白を埋められます（最大${StreakFreezeService.maxTickets}枚）。',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildOfferSection(context, vm, state, offer, needed, canUse),
        const SizedBox(height: 16),
        const Text('使用履歴', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (state.history.isEmpty)
          const Text('まだお休み券を使ったことはありません。',
              key: StreakFreezeKeys.emptyHistory)
        else
          ...state.history.reversed.toList().asMap().entries.map((entry) {
            final usage = entry.value;
            return ListTile(
              key: StreakFreezeKeys.historyTile(entry.key),
              dense: true,
              leading: const Icon(Icons.confirmation_number_outlined),
              title: Text('連続 ${usage.keptStreak}日を守った'
                  '（${usage.coveredMissedDays}日分）'),
              subtitle: Text(_formatDate(usage.usedAt)),
            );
          }),
      ],
    );
  }

  Widget _buildOfferSection(
    BuildContext context,
    PlayerViewModel vm,
    StreakFreezeState state,
    StreakFreezeOffer? offer,
    int needed,
    bool canUse,
  ) {
    if (offer == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '現在、守るべき連続記録の切断はありません。',
            key: StreakFreezeKeys.noOfferLabel,
          ),
        ),
      );
    }

    return Card(
      key: StreakFreezeKeys.offerCard,
      color: canUse ? Colors.amber.shade50 : Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '連続 ${offer.previousStreak}日 が途切れました。',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(offer.missedDays > 1
                ? '${offer.missedDays}日休んだため、お休み券が$needed枚必要です。'
                : 'お休み券1枚でこの空白を埋め、連続記録を守れます。'),
            const SizedBox(height: 12),
            if (canUse)
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  key: StreakFreezeKeys.useButton,
                  onPressed: () => _use(vm, offer),
                  icon: const Icon(Icons.confirmation_number),
                  label: const Text('お休み券を使う'),
                ),
              )
            else
              Text(
                'お休み券が足りません（必要 $needed枚 / 所持 ${state.tickets}枚）',
                key: StreakFreezeKeys.insufficientLabel,
                style: const TextStyle(color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$m-$day $h:$min';
  }
}
