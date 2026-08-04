#!/usr/bin/env bash
# デモ用の手紙を1通用意する。
#
# 手紙は最初に開いた端末に紐づいて他からは読めなくなるため、
# デモを繰り返すなら毎回新しい符号で用意する必要がある。
#
#   ./scripts/new-demo-letter.sh              符号は自動生成 (6文字)
#   ./scripts/new-demo-letter.sh SAKURA       符号を指定 (5〜8文字, I O 0 1 は不可)
#   BASE_URL=http://localhost:3100 ./scripts/new-demo-letter.sh
#
# 本文は scripts/demo-letter.txt を編集する。

set -euo pipefail

BASE_URL="${BASE_URL:-https://SERVICE_ID.ap-northeast-1.awsapprunner.com}"
SENDER_ID="${SENDER_ID:-demo-sender}"
SENDER_NAME="${SENDER_NAME:-母より}"
RECIPIENT_NAME="${RECIPIENT_NAME:-あなたへ}"
SENDER_BPM="${SENDER_BPM:-74}"
CODE="${1:-}"

BODY_FILE="$(cd "$(dirname "$0")" && pwd)/demo-letter.txt"
if [[ ! -f "$BODY_FILE" ]]; then
  echo "本文が見つかりません: $BODY_FILE" >&2
  exit 1
fi

# 本文を JSON 文字列として安全に埋め込む(改行やクォートをエスケープ)
PAYLOAD=$(
  CODE="$CODE" SENDER_NAME="$SENDER_NAME" RECIPIENT_NAME="$RECIPIENT_NAME" \
  SENDER_BPM="$SENDER_BPM" BODY_FILE="$BODY_FILE" python3 <<'PY'
import json, os

payload = {
    "body": open(os.environ["BODY_FILE"], encoding="utf-8").read().strip(),
    "senderName": os.environ["SENDER_NAME"],
    "recipientName": os.environ["RECIPIENT_NAME"],
    "senderBpm": float(os.environ["SENDER_BPM"]),
}
code = os.environ.get("CODE", "").strip()
if code:
    payload["code"] = code
print(json.dumps(payload, ensure_ascii=False))
PY
)

RESPONSE=$(
  curl -sS -m 20 -X POST "$BASE_URL/letters" \
    -H "Content-Type: application/json" \
    -H "x-user-id: $SENDER_ID" \
    -d "$PAYLOAD"
)

echo "$RESPONSE" | python3 -c '
import json, sys

data = json.load(sys.stdin)
if "code" not in data:
    message = data.get("message", data)
    if isinstance(message, list):
        message = message[0]
    print(f"失敗: {message}", file=sys.stderr)
    sys.exit(1)

print()
print(f"  符号   {data['"'"'code'"'"']}")
print(f"  宛名   {data.get('"'"'recipientName'"'"') or '"'"'(なし)'"'"'}")
print(f"  封の脈 {int(data.get('"'"'senderBpm'"'"') or 0)}")
print(f"  本文   {len(data['"'"'body'"'"'])} 文字")
print()
print("  この符号をアプリの「符号で受け取る」に入れる。")
print("  一度開かれると他の端末からは読めなくなる。")
print()
'
