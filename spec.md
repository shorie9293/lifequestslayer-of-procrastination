# 仕様書: RPG風タスク管理＆学習アプリ（rpg_todo）

**ステータス**: 開発中（v1.0.4+5）
**最終更新**: 2026-04-07
**リポジトリ**: `projects/rpg-task/`（旧: `E:\workspace\todo`）

---

## コンセプト
タスク管理をRPGゲームとして体験するFlutterアプリ。
「冒険者ギルド」UIでタスクをクエストとして管理し、完了するたびにXPを獲得してレベルアップする。

## 現在の実装状況

### 技術スタック
- **フレームワーク**: Flutter（Dart SDK ^3.5.4）
- **状態管理**: Provider（^6.1.5+1）
- **ストレージ**: Hive（ローカル永続化）
- **フォント**: Google Fonts
- **対応プラットフォーム**: Android / Web

### アーキテクチャ
MVVM パターンを採用：
```
screens/ → viewmodels/ → repositories/ → models/
```

### 主要コンポーネント
| ファイル/フォルダ | 役割 |
|----------------|-----|
| `lib/viewmodels/GameViewModel` | プレイヤー状態・タスクロジックの中心 |
| `lib/screens/` | ホーム・ギルド・メイン画面 |
| `lib/widgets/TaskCard` | タスク表示カード |
| `lib/repositories/` | データアクセス層（Hive） |
| `lib/models/` | データモデル定義 |

### 実装済み機能
- タスクをクエストとして登録・表示（冒険者ギルド画面）
- タスク完了でXP獲得・レベルアップ
- チュートリアルオーバーレイ
- Hiveによるローカルデータ永続化
- Webビルド対応（netlify.toml 設定済み）

---

## 今後の開発方向（未定）
- タスク管理の学習要素の追加
- アプリ間連携（選挙ゲームとのエコシステム接続）
- iOS対応

---

## よく使うコマンド
```bash
flutter run          # 実行
flutter build appbundle  # Androidビルド
flutter build web    # Webビルド
flutter test         # テスト実行
flutter pub get      # 依存関係取得
```

---
*このファイルはPMエージェントが管理します。仕様変更の都度更新してください。*
