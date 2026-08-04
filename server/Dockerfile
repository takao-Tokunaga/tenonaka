# どのホストでも同じ手順で動くようにコンテナにしている
FROM node:22-slim AS build

WORKDIR /app

# Prisma の実行に必要
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
COPY prisma ./prisma
# postinstall で prisma generate が走る
RUN npm ci

COPY tsconfig.json nest-cli.json ./
COPY src ./src
RUN npm run build

# 実行用に本番依存だけを入れ直す
FROM node:22-slim AS runtime

WORKDIR /app
ENV NODE_ENV=production
# VPC コネクタ経由だと外に出られないので、Prisma の更新確認を止める。
# 有効なままだと起動時にタイムアウト待ちが入る可能性がある
ENV CHECKPOINT_DISABLE=1

RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
COPY prisma ./prisma
RUN npm ci --omit=dev

COPY --from=build /app/dist ./dist

# ホストが割り当てるポートを使う
ENV PORT=3100
EXPOSE 3100

# 起動時にマイグレーションを当ててから立ち上げる
CMD ["npm", "run", "start:prod"]
