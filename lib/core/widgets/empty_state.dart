import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 空状態（0件画面）の仕様。
///
/// 文言は部品に埋め込まず、呼出側がここへ渡す。
/// 不変条件は非constコンストラクタ本体で ArgumentError として強制する
/// （リリースビルドでも assert は無効になるため assert は使わない）。
class EmptyStateSpec {
  /// 見出し。空文字（空白のみを含む）は禁止。
  final String title;

  /// 補足説明。null なら描かない。
  final String? description;

  /// 行動ボタンの文言。[onAction] と必ず対で指定する。
  final String? actionLabel;

  /// 行動ボタン押下時の処理。[actionLabel] と必ず対で指定する。
  final void Function()? onAction;

  EmptyStateSpec({
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', '見出しは空にできません');
    }
    if (actionLabel != null) {
      if (actionLabel!.trim().isEmpty) {
        throw ArgumentError.value(
            actionLabel, 'actionLabel', '行動ボタンの文言は空にできません');
      }
      if (onAction == null) {
        throw ArgumentError('actionLabel を指定するなら onAction も必須です');
      }
    } else if (onAction != null) {
      throw ArgumentError('onAction を指定するなら actionLabel も必須です');
    }
  }
}

/// 空状態の共通描画部品。
///
/// アイコン（任意）・見出し・説明・行動ボタン（任意）を縦に並べる。
/// [EmptyStateSpec.actionLabel] が null のときはボタンを描かない。
///
/// 文言は呼出側が [spec] で渡す。色や文字サイズだけを画面ごとに
/// [titleStyle] / [descriptionStyle] で調整できる。
class EmptyStateView extends StatelessWidget {
  /// 必須。試練から同定できるよう呼出側が明示的に渡す。
  const EmptyStateView({
    required super.key,
    required this.spec,
    this.icon,
    this.titleStyle,
    this.descriptionStyle,
    this.padding = const EdgeInsets.all(24),
    this.actionSemanticsId = 'btn_empty_state_action',
  });

  final EmptyStateSpec spec;

  /// 見出しの上に置く任意のアイコン（絵文字 Text でも可）。
  final Widget? icon;

  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  final EdgeInsetsGeometry padding;

  /// 行動ボタンの Semantics 識別子。
  final String actionSemanticsId;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (icon != null) {
      children.add(icon!);
      children.add(const SizedBox(height: 12));
    }

    children.add(Text(
      spec.title,
      textAlign: TextAlign.center,
      style: titleStyle ??
          const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ));

    final description = spec.description;
    if (description != null && description.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(Text(
        description,
        textAlign: TextAlign.center,
        style: descriptionStyle ?? const TextStyle(fontSize: 14),
      ));
    }

    final actionLabel = spec.actionLabel;
    final onAction = spec.onAction;
    if (actionLabel != null && onAction != null) {
      children.add(const SizedBox(height: 16));
      children.add(SemanticHelper.interactive(
        testId: actionSemanticsId,
        label: actionLabel,
        child: FilledButton(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ));
    }

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
