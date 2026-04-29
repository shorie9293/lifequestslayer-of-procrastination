# バグ履歴・エラー記録

品質保証のため、発生したバグ・エラーを記録する。
同じ問題を繰り返さないことが目的。

---

## BUG-001 | 2026-04-12 | リリースビルドで黒画面フリーズ

**重要度**: 🔴 Critical  
**ステータス**: 修正済み（v1.1.1+7）

### 症状
Play Storeからインストールしたアプリが起動せず、黒い画面のまま固まる。

### 原因
Androidのリリースビルドにおいて、R8（ProGuard）のコード縮小機能（minify）が有効になっており、
Hiveのアダプタークラス（`TaskAdapter`, `PlayerAdapter` 等）が「未使用コード」と判断されて削除された。
アプリ起動時にHiveがデータ読み込みを試みるが、アダプタークラスが存在しないためクラッシュ。

### 根本原因（なぜ気づかなかったか）
- `flutter run`（デバッグビルド）では minify が無効のため再現しない
- USBデバッグ接続でのテストのみで、リリースビルドでの動作確認を行っていなかった

### 修正内容
`android/app/build.gradle.kts` の `release` ブロックに以下を追加：
```kotlin
isMinifyEnabled = false
isShrinkResources = false
```

### 再発防止策
- リリースビルド後は必ず **「flutter install --release」または実機でのリリースビルドテスト**を行う
- Play Storeへのアップロード前に内部テストトラックで動作確認する
- Hiveなどリフレクションを使うライブラリを追加する際は ProGuard ルールを確認する

---

## BUG-002 | 2026-04-12 | ビルドエラー：pendingCompletionData が存在しない

**重要度**: 🟡 Major  
**ステータス**: 修正済み（v1.1.0+6）

### 症状
`flutter build appbundle` 実行時にコンパイルエラー。
```
lib/services/iap_service.dart:78:24: Error: The getter 'pendingCompletionData' isn't defined for the type 'PurchaseDetails'.
```

### 原因
`in_app_purchase_platform_interface-1.4.0` で `pendingCompletionData` が廃止されたが、コードが旧APIのまま残っていた。

### 修正内容
`lib/services/iap_service.dart` の該当行を削除し、`completePurchase` を直接呼ぶように変更。

### 再発防止策
- パッケージ更新時は CHANGELOG を確認し、破壊的変更がないかチェックする

---

## BUG-003 | 2026-04-12 | ビルドエラー：flutter_local_notifications の desugaring 未設定

**重要度**: 🟡 Major  
**ステータス**: 修正済み（v1.1.0+6）

### 症状
`flutter build appbundle` 実行時にビルドエラー。
```
Dependency ':flutter_local_notifications' requires core library desugaring to be enabled for :app.
```

### 原因
`flutter_local_notifications` が Java 8+ の機能を使用するが、Android ビルド設定で `coreLibraryDesugaringEnabled` が未設定だった。

### 修正内容
`android/app/build.gradle.kts` に以下を追加：
```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    ...
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### 再発防止策
- 通知系・日付系ライブラリを追加する際は desugar 設定が必要か確認する

---

## BUG-004 | 2026-04-29 | 実機リリースビルドで起動画面フリーズ（BUG-001 再発）

**重要度**: 🔴 Critical  
**ステータス**: 修正済み（v1.2.1+11 差し戻し修正）

### 症状
Play Store 内部テスト向けのリリースビルドを実機にインストールしたところ、
アプリが起動せず、スプラッシュ画面またはローディング表示のまま固まった。
デバッグビルド（`flutter run`）では発生しなかった。

### 原因（三重の禍津）
1. **R8コード縮小の再発（BUG-001の再来）**: `android/app/build.gradle.kts` にて `isMinifyEnabled = true` が再有効化されており、HiveのTypeAdapterクラス（`TaskAdapter`, `PlayerAdapter`等）がR8によって削除されていた。コミット `4821af0` のAndroidビルド構成近代化の際に意図せず再有効化。
2. **通知スケジュールのブロッキング**: `main()` で `notificationService.scheduleAll()` を `runApp()` 前に `await` しており、実機のAndroid 12+環境で `canScheduleExactAlarms()` がブロックすることがあった。
3. **GameViewModel.loadData() のエラーハンドリング欠如**: `loadData()` が例外を投げても `_isLoaded = true` に到達せず、UIが永遠にローディング表示に留まる構造的欠陥。

### 修正内容
1. `android/app/build.gradle.kts`: `isMinifyEnabled = false`, `isShrinkResources = false` に戻し、再発防止の警告コメントを追記
2. `android/app/proguard-rules.pro`: Hive TypeAdapter, GeneratedPluginRegistrant, アプリパッケージ全体の保持ルールを追加（将来minify再開時の備え）
3. `lib/main.dart`: `scheduleAll()` を `runApp()` 後に `Future.microtask()` で移動
4. `lib/services/notification_service.dart`: `canScheduleExactAlarms()` に 2秒タイムアウト追加。朝・夜の `_getScheduleMode()` 呼び出しを1回に統合
5. `lib/viewmodels/game_view_model.dart`: `loadData()` 全体を `try-catch-finally` で保護。例外時はデフォルト値で継続起動。`finally` で必ず `_isLoaded = true`

### 再発防止策（追加）
- **ビルド設定変更時のチェックリスト必須化**: `android/app/build.gradle.kts` を変更する際は、Bug History の参照とリリースビルド実機確認を必須とする
- **CIへのリリースビルドスモークテスト追加**: 今後の課題
- **ProGuardルールの定期的見直し**: 新ライブラリ追加時に ProGuard ルールの充足を確認
- **起動フローの堅牢化**: 全ChangeNotifierの非同期初期化は try-catch + タイムアウトを必須パターンとする

### 教訓
**「過去に討伐した禍津は蘇る」**——BUG-001 は単独のコード修正だけでなく、神事（プロセス）の改善を伴わなければ、必ず再来する。本修正ではコードだけでなく再発防止コメントの埋め込みとBug Historyの拡充により、これを防ぐ。

---

## バグ記録ルール

- バグ発生時は **必ずこのファイルに追記**する
- フォーマット: `BUG-XXX | 日付 | タイトル`
- 重要度: 🔴 Critical（起動不可・データ消失）/ 🟡 Major（機能不全）/ 🟢 Minor（軽微）
- 「再発防止策」を必ず記載すること
