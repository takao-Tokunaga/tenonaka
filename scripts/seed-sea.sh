#!/usr/bin/env bash
# 海に手紙を流しておく。
#
# 海が空だと「拾う」が成立しないので、デモの前に何通か入れておく。
# 手紙は一人にしか拾われないため、繰り返すたびに補充する必要がある。
#
#   ./scripts/seed-sea.sh                              ローカルの海へ
#   BASE_URL=https://xxxx.awsapprunner.com ./scripts/seed-sea.sh
#   RESET=1 ./scripts/seed-sea.sh                      ローカルの海を空にしてから入れる
#
# 本文は scripts/sea-letters/ の *.txt を1通ずつ読む。
# 署名も宛名も付けない(アプリから書けないものを種だけが持つのは不整合なので)。

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3100}"
DIR="$(cd "$(dirname "$0")" && pwd)/sea-letters"

if [[ ! -d "$DIR" ]]; then
  echo "本文が見つかりません: $DIR" >&2
  exit 1
fi

if [[ "${RESET:-}" == "1" ]]; then
  if [[ "$BASE_URL" == *localhost* ]]; then
    docker exec tenonaka-db psql -U tenonaka -d tenonaka -c 'TRUNCATE "Letter";' >/dev/null
    echo "海を空にしました"
  else
    echo "RESET はローカルの海だけに使えます" >&2
    exit 1
  fi
fi

index=0
for file in "$DIR"/*.txt; do
  index=$((index + 1))
  # 脈は手紙ごとに変える。同じ数字が並ぶと作り物に見えるので、
  # 安静時から少し高めまでを散らして持たせる
  BPM_LIST=(66 74 91 69 83 77 62 88 71 79 95 68)
  bpm=${BPM_LIST[$(( (index - 1) % ${#BPM_LIST[@]} ))]}

  payload=$(BODY_FILE="$file" BPM="$bpm" python3 <<'PY'
import json, os
body = open(os.environ["BODY_FILE"], encoding="utf-8").read().strip()
print(json.dumps({"body": body, "senderBpm": float(os.environ["BPM"])}, ensure_ascii=False))
PY
)

  curl -sS -m 20 -X POST "$BASE_URL/letters" \
    -H "Content-Type: application/json" \
    -H "x-user-id: sea-seed-$index" \
    -d "$payload" \
  | BPM="$bpm" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
if "code" not in d:
    m = d.get("message", d)
    print("  失敗:", m if isinstance(m, str) else m[0], file=sys.stderr)
    sys.exit(1)
print("  流した  脈" + os.environ["BPM"] + "  " + d["code"])
'
done

echo
curl -sS -m 10 "$BASE_URL/letters/sea" -H "x-user-id: seed-check" \
  | python3 -c 'import json,sys; print("  海に", json.load(sys.stdin)["drifting"], "通 漂っています")'
