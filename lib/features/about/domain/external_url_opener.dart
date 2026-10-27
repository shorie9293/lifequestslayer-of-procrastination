/// 外部URL（ブラウザ・メールアプリ等）を開く口。
///
/// 画面はこの [ExternalUrlOpener] 越しに外部遷移を行う。試練では
/// 「渡された URI」を記録するフェイクを注入し、実網・実ブラウザを撃たない。
typedef ExternalUrlOpener = Future<bool> Function(Uri uri);

/// 表示用の生文字列を外部遷移用の [Uri] へ正規化する。
///
/// 前後の空白は除去する。スキームを持たない文字列（例: `example.com`）は
/// 外部アプリで開けないため null を返す（呼び出し側はコピー導線へ退避する）。
Uri? externalUri(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return null;
  return uri;
}

/// メールアドレスを `mailto:` URI へ変換する（前後の空白は除去）。
Uri mailtoUri(String email) => Uri(scheme: 'mailto', path: email.trim());
