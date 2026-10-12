/// シェアカード画像キャプチャ抽象と RepaintBoundary 実装
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// カード画像キャプチャの抽象（試練でフェイク注入可能に）
abstract class AdventureShareCardCapture {
  const AdventureShareCardCapture();

  Future<Uint8List?> capture();
}

/// RepaintBoundary から PNG バイト列を生成する実装
class RepaintBoundaryAdventureShareCardCapture
    implements AdventureShareCardCapture {
  final GlobalKey boundaryKey;

  const RepaintBoundaryAdventureShareCardCapture(this.boundaryKey);

  @override
  Future<Uint8List?> capture() async {
    final context = boundaryKey.currentContext;
    if (context == null) return null;
    final boundary = context.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
