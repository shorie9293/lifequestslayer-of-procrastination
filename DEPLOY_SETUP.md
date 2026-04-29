# 🚀 Google Play 自動デプロイ セットアップガイド

## 概要

GitHub Actions + Fastlane で、mainブランチへのpush時に自動的にGoogle Play ConsoleへAABをアップロードします。

## 自動デプロイの流れ

```
pubspec.yamlのバージョン更新 → mainブランチpush
    ↓
GitHub Actions発火
    ↓
Flutterビルド (appbundle)
    ↓
FastlaneでGoogle Playへアップロード
    ↓
Internal Testingで配信開始
```

## 必要な準備

### 1. Google Play Console でサービスアカウント作成

1. [Google Play Console](https://play.google.com/console) にアクセス
2. **設定 > APIアクセス** を開く
3. **Google Cloud プロジェクトをリンク**（未リンクの場合）
4. **サービスアカウントを作成** をクリック
5. Google Cloud Consoleが開くので、以下を設定：
   - サービスアカウント名: `github-actions-deploy`
   - ロール: `Owner` または `Editor`
   - 鍵のタイプ: **JSON**
   - 作成後、JSONファイルが自動ダウンロードされる

6. Google Play Consoleに戻り、作成したサービスアカウントに**招待を送信**
   - 権限: **管理者**（または「アプリのリリース」権限）

### 2. Keystore を Base64 エンコード

```bash
cd android
base64 -w 0 upload-keystore.jks
```

出力された長い文字列をコピーしておく。

### 3. GitHub Secrets に登録

[GitHubリポジトリ] > Settings > Secrets and variables > Actions > New repository secret

以下3つを登録：

| Secret名 | 値 |
|----------|-----|
| `KEYSTORE_BASE64` | Step 2 で取得したBase64文字列 |
| `KEY_PROPERTIES` | `android/key.properties` の全文をコピペ |
| `GOOGLE_PLAY_JSON_KEY` | Step 1 でダウンロードしたJSONファイルの全文 |

### 4. 手動デプロイ（初回テスト）

GitHubのActionsタブから「Deploy to Google Play」を手動実行：
- **Track**: `internal`（推奨）

### 5. 自動デプロイ（通常運用）

`pubspec.yaml` の `version` を更新してmainブランチへpush：

```yaml
version: 1.2.2+11  # ← バージョンアップ
```

```bash
git add pubspec.yaml
git commit -m "chore: bump version to 1.2.2+11"
git push origin main
```

→ GitHub Actionsが自動発火し、Internal Testingへアップロードされます。

---

## ファイル構成

```
rpg-task/
├── .github/
│   └── workflows/
│       └── deploy.yml      # GitHub Actions定義
├── android/
│   ├── fastlane/
│   │   ├── Appfile         # パッケージ名設定
│   │   └── Fastfile        # デプロイ設定
│   ├── Gemfile             # Fastlane依存
│   ├── key.properties      # 署名設定（Git管理外）
│   └── upload-keystore.jks # 署名鍵（Git管理外）
└── DEPLOY_SETUP.md         # このファイル
```

## トラブルシューティング

### `Upload keystore not found`
- `secrets.KEYSTORE_BASE64` が正しく登録されているか確認
- Base64エンコード時に `-w 0` オプションを付けたか確認

### `Google Api Error: Invalid JSON`
- `secrets.GOOGLE_PLAY_JSON_KEY` にJSON全文が含まれているか確認
- 余計な改行やスペースが入っていないか確認

### `Version code already used`
- `pubspec.yaml` の `version` 末尾の `+X`（ビルド番号）をインクリメント
- 例: `1.2.1+10` → `1.2.1+11`

## 配信トラック

| トラック | 用途 |
|----------|------|
| `internal` | 開発者テスト（即時配信） |
| `alpha` | クローズドテスト |
| `beta` | オープンテスト |
| `production` | 本番リリース |

**注意**: `production` への自動デプロイは慎重に。基本的に `internal` で運用し、Google Play Console側でプロモーションしてください。
