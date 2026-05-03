#!/bin/bash
set -e

# =========================================================
# NetlifyでのFlutterアプリ自動ビルド用スクリプト
# Flutter 3.27.4 固定（GitHub Actions deploy.yml と一致）
# =========================================================

FLUTTER_VERSION="3.27.4"

# 1. Flutter SDKのダウンロード（バージョン固定・shallow cloneで高速化）
if [ ! -d "flutter" ]; then
  echo "==> Cloning Flutter ${FLUTTER_VERSION}..."
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git flutter
else
  echo "==> Flutter SDK already present, skipping clone"
fi

# 2. PATHを通す
export PATH="$PATH:$(pwd)/flutter/bin"

# 3. パッケージの取得
echo "==> Installing dependencies..."
flutter pub get

# 4. Flutter Webプロジェクトのビルド
echo "==> Building web..."
flutter build web --release --no-tree-shake-icons

echo "==> Build complete: build/web/"
