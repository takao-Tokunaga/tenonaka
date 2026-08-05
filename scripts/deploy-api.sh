#!/usr/bin/env bash
# サーバーを本番(App Runner)に出す。
#
#   source ~/.tenonaka-deploy.env
#   ./scripts/deploy-api.sh          出して、切り替わるまで見張る
#   WAIT=0 ./scripts/deploy-api.sh   出すだけで待たない
#
# 事前に aws sso login と Docker の起動が必要。

set -euo pipefail

# 宛先はリポジトリに書かない。公開しているので、手元の設定から読む。
#   ~/.tenonaka-deploy.env に次を書いておく:
#     export AWS_REGION=ap-northeast-1
#     export ACCOUNT=<自分のAWSアカウントID>
#     export SERVICE_ARN=<App Runner のサービスARN>
REGION="${AWS_REGION:-ap-northeast-1}"
: "${ACCOUNT:?ACCOUNT が要ります(~/.tenonaka-deploy.env を読み込む)}"
: "${SERVICE_ARN:?SERVICE_ARN が要ります(~/.tenonaka-deploy.env を読み込む)}"
REPO="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/tenonaka-api"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export AWS_PAGER=""

digest() {
  aws ecr describe-images --repository-name tenonaka-api --image-ids imageTag=latest \
    --query 'imageDetails[0].imageDigest' --output text --region "$REGION" 2>/dev/null || echo "なし"
}

echo "▸ 認証を確かめる"
aws sts get-caller-identity --query Arn --output text

echo "▸ ECR にログインする"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

BEFORE="$(digest)"
echo "▸ 出す前のイメージ: $BEFORE"

# --platform: App Runner は amd64 なので、Apple Silicon で作ると指定が要る
# --provenance/--sbom: 付けると OCI image index になり App Runner が引けない
echo "▸ 組んで押し上げる"
docker buildx build \
  --platform linux/amd64 \
  --provenance=false --sbom=false \
  -t "${REPO}:latest" \
  --push \
  "${ROOT}/server"

AFTER="$(digest)"
echo "▸ 出した後のイメージ: $AFTER"
if [[ "$BEFORE" == "$AFTER" ]]; then
  echo "  イメージが変わっていない。中身が同じか、押し上げに失敗している" >&2
  exit 1
fi

echo "▸ 切り替えを始める"
OPERATION="$(aws apprunner start-deployment --service-arn "$SERVICE_ARN" \
  --query OperationId --output text --region "$REGION")"
echo "  操作 ID: $OPERATION"

if [[ "${WAIT:-1}" != "1" ]]; then
  exit 0
fi

echo "▸ 切り替わるまで見張る(数分かかる)"
while :; do
  STATUS="$(aws apprunner list-operations --service-arn "$SERVICE_ARN" \
    --query "OperationSummaryList[?Id=='${OPERATION}'].Status | [0]" \
    --output text --region "$REGION")"
  echo "  $STATUS"
  case "$STATUS" in
    SUCCEEDED) break ;;
    FAILED|ROLLBACK_SUCCEEDED|ROLLBACK_FAILED)
      echo "  失敗した。CloudWatch の /aws/apprunner/tenonaka-api を見る" >&2
      exit 1 ;;
  esac
  sleep 20
done

URL="https://$(aws apprunner describe-service --service-arn "$SERVICE_ARN" \
  --query Service.ServiceUrl --output text --region "$REGION")"
echo "▸ 生きているか確かめる"
curl -fsS "${URL}/health" && echo
echo "▸ 完了: $URL"
