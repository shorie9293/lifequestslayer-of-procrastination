#!/bin/bash
set -euo pipefail

# ============================================
# Google Play 自動デプロイ セットアップ支援スクリプト
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANDROID_DIR="${PROJECT_ROOT}/android"

green() { echo -e "\e[32m$*\e[0m"; }
yellow() { echo -e "\e[33m$*\e[0m"; }
blue() { echo -e "\e[34m$*\e[0m"; }
red() { echo -e "\e[31m$*\e[0m"; }

echo ""
blue "╔══════════════════════════════════════════╗"
blue "║  Google Play 自動デプロイ セットアップ   ║"
blue "╚══════════════════════════════════════════╝"
echo ""

# ============================================
# Step 1: Keystoreの確認
# ============================================
KEYSTORE="${ANDROID_DIR}/upload-keystore.jks"

if [ ! -f "${KEYSTORE}" ]; then
  red "❌ Keystoreが見つかりません: ${KEYSTORE}"
  echo ""
  echo "初めての場合は、以下でKeystoreを作成してください:"
  echo "  cd android && keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
  exit 1
fi

green "✅ Keystore確認完了: ${KEYSTORE}"

# ============================================
# Step 2: Base64エンコード
# ============================================
echo ""
yellow "📋 Step 1: KeystoreのBase64エンコード"
echo "────────────────────────────────────────"

KEYSTORE_BASE64=$(base64 -w 0 "${KEYSTORE}")
echo ""
green "✅ Base64エンコード完了"
echo ""
yellow "以下の文字列をコピーしてください（クリップボードに保存する場合は次のコマンドを実行）:"
echo ""
echo "${KEYSTORE_BASE64}" | head -c 100
echo "...（長い文字列が続きます）"
echo ""

# macOSならpbcopy、Linuxならxclip/xselでクリップボードにコピー
if command -v pbcopy >/dev/null 2>&1; then
  echo "${KEYSTORE_BASE64}" | pbcopy
  green "📋 クリップボードにコピーしました！"
elif command -v xclip >/dev/null 2>&1; then
  echo "${KEYSTORE_BASE64}" | xclip -selection clipboard
  green "📋 クリップボードにコピーしました！"
elif command -v xsel >/dev/null 2>&1; then
  echo "${KEYSTORE_BASE64}" | xsel --clipboard --input
  green "📋 クリップボードにコピーしました！"
else
  yellow "⚠️ クリップボードツールが見つかりません。上記文字列を手動でコピーしてください。"
fi

# ============================================
# Step 3: key.propertiesの表示
# ============================================
echo ""
yellow "📋 Step 2: key.propertiesの内容"
echo "────────────────────────────────────────"

if [ -f "${ANDROID_DIR}/key.properties" ]; then
  cat "${ANDROID_DIR}/key.properties"
  echo ""
  green "✅ 上記の内容をコピーしてください"
else
  red "❌ key.propertiesが見つかりません"
  exit 1
fi

# ============================================
# Step 4: GitHub Secrets自動登録（ghコマンド利用）
# ============================================
echo ""
yellow "📋 Step 3: GitHub Secrets登録"
echo "────────────────────────────────────────"

if command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) が見つかりました。自動登録を試みます..."
  echo ""
  
  # リポジトリ情報取得
  REPO_URL=$(cd "${PROJECT_ROOT}" && git remote get-url origin 2>/dev/null || echo "")
  if [ -z "${REPO_URL}" ]; then
    yellow "⚠️ GitリモートURLが取得できません。手動登録が必要です。"
  else
    # https://github.com/owner/repo.git → owner/repo
    REPO=$(echo "${REPO_URL}" | sed 's/.*github.com[:/]\([^/]*\)\/\(.*\)\.git/\1\/\2/')
    
    echo "リポジトリ: ${REPO}"
    echo ""
    
    # KEYSTORE_BASE64
    echo "🔐 KEYSTORE_BASE64 を登録中..."
    echo "${KEYSTORE_BASE64}" | gh secret set KEYSTORE_BASE64 --repo="${REPO}" 2>/dev/null && \
      green "✅ KEYSTORE_BASE64 登録完了" || \
      red "❌ KEYSTORE_BASE64 登録失敗"
    
    # KEY_PROPERTIES
    echo "🔐 KEY_PROPERTIES を登録中..."
    cat "${ANDROID_DIR}/key.properties" | gh secret set KEY_PROPERTIES --repo="${REPO}" 2>/dev/null && \
      green "✅ KEY_PROPERTIES 登録完了" || \
      red "❌ KEY_PROPERTIES 登録失敗"
    
    echo ""
    green "══════════════════════════════════════════"
    green "  ✅ Secrets自動登録完了！"
    green "══════════════════════════════════════════"
    echo ""
    echo "残りは GOOGLE_PLAY_JSON_KEY のみです。"
    echo ""
  fi
else
  yellow "GitHub CLI (gh) がインストールされていません。手動登録が必要です。"
  echo ""
fi

# ============================================
# 次のステップ表示
# ============================================
blue "╔══════════════════════════════════════════╗"
blue "║  次のステップ: Google Play Console設定   ║"
blue "╚══════════════════════════════════════════╝"
echo ""
echo "1. Google Play Consoleにアクセス"
echo "   https://play.google.com/console/u/2/api-access"
echo ""
echo "2. 「Google Cloud プロジェクトをリンク」をクリック"
echo "   → プロジェクトID: make-drive-connect-492409"
echo ""
echo "3. 「サービスアカウントを作成」をクリック"
echo "   → 名前: github-actions-deploy"
echo "   → ロール: Editor"
echo "   → 鍵タイプ: JSON"
echo "   → JSONファイルがダウンロードされる"
echo ""
echo "4. ダウンロードしたJSONファイルの内容をコピー"
echo ""
echo "5. GitHub Secretsに登録:"
echo "   https://github.com/shorie9293/lifequestslayer-of-procrastination/settings/secrets/actions"
echo ""
echo "   Secret名: GOOGLE_PLAY_JSON_KEY"
echo "   値: JSONファイルの全文（{ で始まる文字列）"
echo ""
echo "6. 完了！初回テスト:"
echo "   GitHubのActionsタブ → Deploy to Google Play → Run workflow"
echo ""
