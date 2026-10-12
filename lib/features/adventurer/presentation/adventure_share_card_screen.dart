/// 冒険の戦績シェアカード画面（プレビュー＋共有/コピー）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/adventurer/data/adventure_share_card_exporter.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card_service.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventure_share_card_capture.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventure_share_card_view.dart';

/// 戦績カードのプレビュー表示と共有導線を担う画面。
class AdventureShareCardScreen extends StatefulWidget {
  final AdventureShareCard card;
  final AdventureShareCardExporter? exporter;
  final AdventureShareCardCapture? capture;

  const AdventureShareCardScreen({
    super.key,
    required this.card,
    this.exporter,
    this.capture,
  });

  @override
  State<AdventureShareCardScreen> createState() =>
      _AdventureShareCardScreenState();
}

class _AdventureShareCardScreenState extends State<AdventureShareCardScreen> {
  final GlobalKey _previewKey =
      LabeledGlobalKey('view_adventure_share_card_preview');

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share() async {
    final capture =
        widget.capture ?? RepaintBoundaryAdventureShareCardCapture(_previewKey);
    try {
      final png = await capture.capture();
      if (!mounted) return;
      if (png == null) {
        _showSnack('カード画像を生成できませんでした');
        return;
      }
      final exporter = widget.exporter ?? const SharePlusAdventureShareCardExporter();
      await exporter.shareImage(
        png: png,
        text: AdventureShareCardService.shareText(widget.card),
      );
      if (!mounted) return;
      _showSnack('カードを共有しました');
    } on Exception {
      if (!mounted) return;
      _showSnack('カードの共有に失敗しました');
    }
  }

  Future<void> _copy() async {
    // クリップボードの完了を待たず即フィードバック（環境によって失敗しても無視）
    unawaited(
      Clipboard.setData(
        ClipboardData(text: AdventureShareCardService.shareText(widget.card)),
      ),
    );
    if (!mounted) return;
    _showSnack('テキストをコピーしました');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.adventureShareCardScreen,
      appBar: AppBar(title: const Text('戦績カードを共有')),
      body: Center(
        child: SingleChildScrollView(
          child: RepaintBoundary(
            key: _previewKey,
            child: KeyedSubtree(
              key: AppKeys.adventureShareCardPreview,
              child: AdventureShareCardView(card: widget.card),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: AppKeys.adventureShareCardCopy,
                  icon: const Icon(Icons.copy),
                  label: const Text('テキストをコピー'),
                  onPressed: _copy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: AppKeys.adventureShareCardShare,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('カードを共有'),
                  onPressed: _share,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
