// コード適応神書 — 原則③ Semantics体系
// 試練可能＋アクセシブルなUIを実現するSemanticsヘルパー
//
// 命名規則: type_identifier
//   btn_save, tgl_notifications, txt_email, sec_header, nav_back, item_task_0

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Semantics識別子の型プレフィックス定数
class SemanticTypes {
  SemanticTypes._();

  static const String button = 'btn';
  static const String toggle = 'tgl';
  static const String textField = 'txt';
  static const String section = 'sec';
  static const String navigation = 'nav';
  static const String listItem = 'item';
  static const String dialog = 'dlg';
  static const String icon = 'ico';
}

/// 試練可能＋アクセシブルなUIを実現するSemanticsヘルパー
class SemanticHelper {
  SemanticHelper._();

  /// テストIDを生成: type_identifier
  static String createTestId(String type, String identifier) =>
      '${type}_$identifier';

  /// 操作可能要素（ボタン、タップ可能領域）
  static Widget interactive({
    required String testId,
    required Widget child,
    String? label,
    String? hint,
  }) {
    return Semantics(
      identifier: testId,
      label: label ?? testId,
      button: true,
      onTapHint: hint,
      child: child,
    );
  }

  /// コンテナ（領域区切り）
  static Widget container({
    required String testId,
    required Widget child,
    bool explicitChildNodes = false,
    String? label,
  }) {
    return Semantics(
      identifier: testId,
      label: label,
      container: true,
      explicitChildNodes: explicitChildNodes,
      child: child,
    );
  }

  /// トグル（スイッチ、チェックボックス）
  static Widget toggle({
    required String testId,
    required bool value,
    required Widget child,
    ValueChanged<bool>? onChanged,
  }) {
    return Semantics(
      identifier: testId,
      toggled: value,
      onTap: onChanged != null ? () => onChanged(!value) : null,
      child: child,
    );
  }

  /// テキスト入力
  static Widget textField({
    required String testId,
    required Widget child,
    String? label,
  }) {
    return Semantics(
      identifier: testId,
      label: label ?? testId,
      textField: true,
      child: child,
    );
  }

  /// リスト項目
  static Widget listItem({
    required String testId,
    required int index,
    required Widget child,
  }) {
    return Semantics(
      identifier: testId,
      container: true,
      sortKey: OrdinalSortKey(index.toDouble()),
      child: child,
    );
  }

  /// ナビゲーション要素（タブ、メニュー項目）
  static Widget navigation({
    required String testId,
    required Widget child,
    String? label,
  }) {
    return Semantics(
      identifier: testId,
      label: label ?? testId,
      header: true,
      child: child,
    );
  }
}
