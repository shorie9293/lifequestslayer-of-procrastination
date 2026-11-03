# AGENTS.md — LifeQuest Slayer 作業規約（エージェント共通）

このリポジトリで作業するエージェント（Muse／駿麒、Claude Code、その他）は、コードを書く前に本章を読むこと。
`CLAUDE.md` は Claude Code 向けの補足、`docs/roadmap.md` は改善方針の正本。**矛盾したら本ファイルが優先**。

## 0. 読む順序（毎回・省略禁止）
1. `AGENTS.md`（本章）
2. `SPEC.md`（振る舞いの唯一の正）
3. `docs/decisions.md`（設計判断の履歴）
4. `docs/roadmap.md`（改善方針・版計画）

## 1. 変更の作法
- **振る舞いを変える前に `SPEC.md` を更新**し、差分を1行で示す。コードと仕様が食い違ったら仕様が正。
- 1コミット1目的。メッセージは「何を・なぜ」（例: `fix(guild): 期限表示がJSTで1日ずれるのを修正`）。
- 既存ファイルの大規模改変・データモデル変更・依存追加は、**触るファイルを列挙して承認を得てから**行う。
- 秘密情報（APIキー・トークン・サービスアカウント）はコードに書かない。

## 2. このリポジトリ固有の地雷
- **モノレポ参照**: `pubspec.yaml` は `../../packages/takamagahara_ui` と `takamagahara_core` を path 参照する。
  CI は先に `packages/` を配置してから `flutter pub get` する。単体で `pub get` が落ちるのはこれが原因。
- **pre-push フック**: `.git/hooks/pre-push` が `flutter analyze --no-fatal-infos` を実行し、**警告1件でも push を拒否**する。
- **CI は3シャード固定**: `.github/workflows/flutter-ci.yml` にテストディレクトリが列挙されている。
  **新しい `test/features/<name>/` を追加したら、必ずいずれかのシャードに追記**しないと CI で実行されない（＝試練されない）。
- **バージョン**: `pubspec.yaml` の `version:` は `1.5.xx+NNN`。`pubspec.yaml` を変更して main に merge すると
  `deploy.yml` が AAB を作成し Google Play へ自動デプロイする。**バージョン bump は意図した時だけ**。
  AppBar の表示（`lib/features/guild/presentation/guild_screen.dart`）も `pubspec.yaml` と同期させる。
- **リポジトリは GitHub コネクタ経由だと履歴・削除が残らない**。削除したファイルは必ず報告に明記する。

## 3. TDD（順序を飛ばさない）
🔴 失敗するテストを書く → 🟢 最小実装で通す → 🔵 整理する。
ロジック（判定・変換・集計・日付計算）は**純粋関数に切り出して単体テスト必須**。
プラットフォームAPI（通知・課金・カレンダー等）は**抽象インターフェース越し**に呼び、テストではフェイクを注入する。

## 4. 品質ゲート（ローカルで再現できる）
```bash
flutter pub get
flutter analyze --no-fatal-infos          # 警告0が条件
flutter test --no-pub -j 1 test/<対象>/   # 対象シャードを先に回す
bash scripts/pre-deploy-check.sh          # デプロイ前はこれ（analyze + 3シャード）
```

## 5. 完成度チェックリスト（UI）
- [ ] 全画面に「空状態 / 読み込み中 / エラー」の3状態がある
- [ ] 入力検証とエラーメッセージがある
- [ ] 保存されない操作がない（再起動で消える設定を作らない）
- [ ] 破壊的操作に確認ダイアログがある
- [ ] 操作可能要素に `Semantics`（`SemanticHelper.interactive()`）が付いている
- [ ] 試練用 Key は `lib/core/testing/widget_keys.dart` に一元管理（重複定義禁止）

## 6. 完了の定義（Definition of Done）
1. `SPEC.md` に振る舞いが書かれている
2. テストが存在し全件成功（**コマンドと出力を貼る**）
3. `flutter analyze --no-fatal-infos` 警告0
4. 残る制約を3行以内で報告

## 7. 禁止事項
- 「動作確認しました」等の証拠なし報告（実行コマンドと出力のみ可）
- 原因特定なしの再試行・バージョン番号の連打
- テストなしの「完了」報告
- CI が赤い状態での作業終了
- main への直 push（作業ブランチ＋PR を使う）
