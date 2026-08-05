#!/usr/bin/env bash
# TestFlight に上げる ipa を作る。
#
#   ./scripts/release-ios.sh                     組んで書き出すだけ
#   UPLOAD=1 ./scripts/release-ios.sh            そのまま App Store Connect へ送る
#
# 送るには App Store Connect の認証が要る。どちらか一方でよい。
#
#   A. アプリ用パスワード(権限が要らないので、共有アカウントではこちら)
#        ASC_USER=you@example.com ASC_PASSWORD=xxxx-xxxx-xxxx-xxxx
#      パスワードは appleid.apple.com > サインインとセキュリティ >
#      アプリ用パスワード で作る
#
#   B. API キー(Admin 以上の権限が要る)
#        ASC_KEY_ID / ASC_ISSUER_ID
#      秘密鍵は ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 に置く
#
# 宛先はリポジトリに書かない(公開しているため)。呼ぶときに渡す:
#   API_BASE_URL=https://<id>.<region>.awsapprunner.com ./scripts/release-ios.sh
#
# 本番の宛先を必ず埋め込む。ここを忘れると、配った全員が
# localhost を向いて何も通らないアプリを受け取ることになる。

set -euo pipefail

: "${API_BASE_URL:?API_BASE_URL が要ります(本番の https の宛先)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
BUILD="$IOS/build"
ARCHIVE="$BUILD/Tenonaka.xcarchive"

echo "▸ 埋め込む接続先: $API_BASE_URL"
case "$API_BASE_URL" in
  https://*) ;;
  *) echo "  本番の宛先が https ではありません。配布用には使えません" >&2; exit 1 ;;
esac

echo "▸ 前回の書き出しを捨てる"
rm -rf "$BUILD"

echo "▸ Release で組んで書庫を作る"
xcodebuild -project "$IOS/Tenonaka.xcodeproj" -scheme Tenonaka \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  TENONAKA_API_BASE_URL="$API_BASE_URL" \
  archive

echo "▸ 埋め込まれた宛先を確かめる"
PLIST="$ARCHIVE/Products/Applications/Tenonaka.app/Info.plist"
EMBEDDED="$(/usr/libexec/PlistBuddy -c 'Print :TenonakaAPIBaseURL' "$PLIST")"
echo "  $EMBEDDED"
if [[ "$EMBEDDED" != "$API_BASE_URL" ]]; then
  echo "  埋め込みに失敗しています" >&2
  exit 1
fi

echo "▸ ipa を書き出す"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$IOS/ExportOptions.plist" \
  -exportPath "$BUILD/export" \
  -allowProvisioningUpdates

IPA="$(find "$BUILD/export" -name '*.ipa' | head -1)"
echo "▸ できました: $IPA"

if [[ "${UPLOAD:-}" != "1" ]]; then
  echo "  送るには UPLOAD=1 を付けて実行する"
  exit 0
fi

if [[ -n "${ASC_USER:-}" ]]; then
  : "${ASC_PASSWORD:?ASC_USER を渡すなら ASC_PASSWORD(アプリ用パスワード)も要ります}"
  AUTH=(-u "$ASC_USER" -p "$ASC_PASSWORD")
elif [[ -n "${ASC_KEY_ID:-}" ]]; then
  : "${ASC_ISSUER_ID:?ASC_KEY_ID を渡すなら ASC_ISSUER_ID も要ります}"
  AUTH=(--apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID")
else
  echo "認証がありません。ASC_USER + ASC_PASSWORD か、ASC_KEY_ID + ASC_ISSUER_ID を渡す" >&2
  exit 1
fi

echo "▸ 先に中身を検める"
xcrun altool --validate-app -f "$IPA" -t ios "${AUTH[@]}"

echo "▸ App Store Connect へ送る"
xcrun altool --upload-app -f "$IPA" -t ios "${AUTH[@]}"

echo "▸ 送りました。処理が終わると TestFlight に現れます(数分〜十数分)"
