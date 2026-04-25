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

## バグ記録ルール

- バグ発生時は **必ずこのファイルに追記**する
- フォーマット: `BUG-XXX | 日付 | タイトル`
- 重要度: 🔴 Critical（起動不可・データ消失）/ 🟡 Major（機能不全）/ 🟢 Minor（軽微）
- 「再発防止策」を必ず記載すること
