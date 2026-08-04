# 香りのしおり

匂いを感じた瞬間の記憶を、その日の日記に「しおり」として挟み込む記録アプリ。

ハッカソンテーマ **「AIにできないこと」** への回答として、
**AIを一切使わない** ことを設計方針にしている。
匂いの言語化と記憶の想起はAIには原理的に体験できない領域であり、
解釈・要約・レコメンドを挟まず、ユーザー自身の言葉だけで完結する。

詳細な要件は [docs/要件定義書.md](docs/要件定義書.md) を参照。

## 体験の核

- 過去のページをスワイプで遡っている途中で、しおりが挟まっているページに**偶然出会う**
- しおりの存在は事前にわからない。ページを開いた **0.3秒後** にアイコンがフェードインして初めて気づく
- 一覧・検索・フィルタは意図的に持たせていない(見つけてしまうと「出会う」体験にならない)

## 構成

```
Nioi/
├── docker-compose.yml       PostgreSQL (ポート 5433)
├── server/                  NestJS + Prisma
│   ├── prisma/schema.prisma
│   ├── prisma/seed.ts       デモ用の過去ページ
│   └── src/
└── ios/                     Swift / SwiftUI
    ├── KaoriNoShiori.xcodeproj
    ├── Supporting/Info.plist
    └── KaoriNoShiori/
        ├── Models/          CalendarDay, ScentTag, DiaryPage
        ├── Data/            PageRepository, PageStore, PageCache
        ├── Theme/           紙の質感・明朝体
        └── Views/           起動演出, ページャ, しおり
```

## 起動手順

### 1. バックエンド

```bash
docker compose up -d                  # PostgreSQL (localhost:5433)
cd server
npm install
npx prisma generate
npx prisma db push
npm run seed                          # デモ用の過去ページを入れる(任意)
npm run dev                           # http://localhost:3100
```

ポートは `server/.env` の `PORT` で変更できる(3000 は他プロセスと衝突しやすいため 3100)。

### 2. iOS(シミュレータ)

```bash
open ios/KaoriNoShiori.xcodeproj
```

iPhone シミュレータを選んで実行する。接続先の既定値は `http://localhost:3100`。

### 3. iOS(実機)

署名は自動署名で設定済み(`DEVELOPMENT_TEAM = XXXXXXXXXX`)。

1. iPhone を USB で Mac に繋ぎ、初回は「このコンピュータを信頼」を許可する
2. Xcode の実行先で自分の iPhone を選んで実行
3. iPhone の **設定 → 一般 → VPN とデバイス管理** で開発者アプリを信頼する(初回のみ)
4. 起動後、**日付を長押し**して「接続先」に Mac の IP を入れて「つなぐ」

接続先はビルド設定 `NIOI_API_BASE_URL` の値が既定になる。実機で毎回入れ直したくない場合はここを
Mac の IP(例 `http://192.168.0.5:3100`)に変える。アプリ内で入れた値はそれを上書きする。

Mac の IP は `ipconfig getifaddr en0` で確認できる。iPhone と Mac が同じ Wi-Fi にいること、
Mac のファイアウォールが `node` の受信を許可していることが前提。

初回の接続時に「ローカルネットワーク上のデバイスの検索」を求めるダイアログが出るので許可する。

> サーバー無しでも起動する(ローカルキャッシュで動き、書いた内容は復帰後に再送される)。
> 指の操作だけ確かめたいならバックエンドを立てなくてもよい。

## 動作確認済みの経路

- 日記の保存 / しおりの保存 / しおりを抜く → PostgreSQL まで反映
- 日記だけの保存でしおりが消えない(逆も同様)
- サーバー停止中に書いた内容はローカルに残り、復帰後の起動で自動再送される
- 未記入の日は「白紙のページ」として表示され、DBに行を作らない

## デモ用の起動フラグ (Debug ビルドのみ)

任意の状態から起動できる。ステージ上で操作をミスしても即座に見せたい画面に戻せる。

```bash
SIMCTL_CHILD_SKIP_COVER=1 \
SIMCTL_CHILD_START_DAY=2026-07-21 \
SIMCTL_CHILD_AUTO_REVEAL=1 \
xcrun simctl launch booted dev.takao.kaorinoshiori
```

| 環境変数 | 内容 |
|---|---|
| `SKIP_COVER=1` | 本を開く演出を飛ばす |
| `START_DAY=YYYY-MM-DD` | その日のページから始める |
| `AUTO_REVEAL=1` | しおりを展開した状態で始める |
| `AUTO_SHEET=bookmark` / `diary` / `connection` | しおり入力 / 日記入力 / 接続先設定を開いた状態で始める |
| `HOLD_TURN=0.45` | ページめくりを途中で止める(見た目の確認用) |

## API

いずれも認証は `x-user-id` ヘッダのみ(未指定なら `local-user`)。

| メソッド | パス | 内容 |
|---|---|---|
| GET | `/pages/:date` | 指定日のページ。未記入なら空ボディ |
| PUT | `/pages/:date` | 指定日のページを更新 |
| GET | `/pages?from=&to=` | 日付範囲を一括取得(ページャの先読み) |
| GET | `/pages?before=&limit=` | 過去ページを遡って取得 |
| GET | `/health` | 死活確認 |

PUT のボディはフィールドの**有無に意味がある**:

```jsonc
{ "diaryText": "…" }          // 日記だけ更新。しおりは触らない
{ "bookmark": { "tag": "SWEET", "scentText": "…", "memoryText": "…" } }
{ "bookmark": null }          // しおりを抜く
```

日記の自動保存としおりの保存が互いを消し合わないようにするための仕様。

## 実装上の判断

- **ページめくり**: 綴じ側(左)を軸に 0°→-90° まで回す 3D 回転。-90° でページは幅ゼロになるので、
  そのタイミングで日付を差し替えると継ぎ目が見えず、裏面が鏡文字になる問題も起きない
- **日付の型**: `CalendarDay`(年月日のみの値型)。`Date` を識別子にせず、
  タイムゾーンや夏時間でページがズレる問題を構造的に排除している
- **読む画面と書く画面を分けた**: ページ上で直接編集すると、めくりのドラッグと
  テキスト編集がジェスチャーを取り合うため
- **しおりのボタンを出す条件**: しおりのあるページには「挟む」ボタンを出さない。
  「直す」と表示してしまうと、開く前にしおりの存在がバレて発見の演出が壊れる
- **タグにアイコンを使わない**: アイコンは匂いの意味を説明してしまう。
  色のついた印だけにして、言語化はユーザーの言葉に委ねる

## 今後の候補(MVP スコープ外)

- プッシュ通知・リマインド
- 検索・フィルタ(体験の核と衝突するため慎重に)
- 複数ユーザー・しおりの共有
- 地図表示
