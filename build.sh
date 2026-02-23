#!/bin/bash

# =========================================================
# NetlifyでのFlutterアプリ自動ビルド用スクリプト
# =========================================================

# 1. Flutter SDKのダウンロード (stable ブランチ)
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. PATHを通す
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Flutterの依存関係と環境の確認
flutter doctor

# 4. パッケージの取得
flutter pub get

# 5. Flutter Webプロジェクトのビルド
# --releaseオプションで本番向け(最適化済み)ビルドを実行する
flutter build web --release
