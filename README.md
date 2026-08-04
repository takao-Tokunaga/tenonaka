# 手のなか

**生きた手に握られている間だけ、文字が現れる手紙。**

置くと止まる。飛ばせない。要約できない。
送り主に返るのは内容への返信ではなく、生きた手がその手紙を握っていた時間だけ。

ハッカソンテーマ **「AIにできないこと」** への回答。
設計の考え方は [docs/要件定義書.md](docs/要件定義書.md) に書いた。

## テーマへの立脚点

「AIのほうが下手なこと」を探すと必ず来年には追い抜かれる。
だから **構造的に不可能なこと** を機構に組み込んだ。

判定に使った問いはこれ。

> **このアプリを、AIエージェントは使えるか?**

答えは **使えない**。埋めるフォームがあるかどうかではなく、
送信と読解の両方が**身体の状態**を要求するため。

| 行為 | 要求されるもの | AIに無いもの |
|---|---|---|
| 送る | 指を当てて脈が測れること | 脈 |
| 読む | 端末を握り続けること | 手 |

いずれも**信号処理だけ**で実装している。HealthKit も CoreML も LLM も使っていない
(心拍数すら、カメラの生のピクセルから自分で計算している)。

## 体験の流れ

1. 手紙を書く
2. **背面カメラのレンズに指を当てる。** 脈が2秒安定すると封が押され、その拍数が手紙に刻まれる
3. 発行された符号(例 `HANA`)を相手に口で伝える
4. 相手が符号を入れると、**手に持っている間だけ**毎秒10文字ずつ文字が現れる。
   机に置くと3秒後に止まる。拾い上げると再開する
5. 最後まで現れると、日付・署名・宛名が間を置いて浮かび上がる
6. 送り主に **握っていた時間・置かれた回数・読了したか** が返る

まだ現れていない文字は**描画していない**ので、先を覗くこともスクリーンショットで
先取りすることもできない。手紙の長さも分からないので、残りを推し量れない。

## 計測の仕組み

### 脈 — 光電容積脈波 (PPG)

[`PulseSensor.swift`](ios/Tenonaka/Data/PulseSensor.swift)

指の腹をレンズに当てると、指を透過した光がセンサに届く。心臓が血を送るたびに
毛細血管の血液量が変わり、**画像の赤成分の平均**が心拍に合わせて上下する。

1. 毎フレーム、中央 ROI の赤成分の平均を取る
2. 移動平均を引いて明るさのドリフトを除去(ハイパス)
3. 短い移動平均でノイズを潰す(ローパス)
4. 不応期 0.30 秒を設けて山を検出
5. 拍間隔の**中央値**から心拍数を出す(平均だと1つの誤検出でずれる)

**露出とホワイトバランスを固定**するのが要点。自動のままだとカメラが血液量の変化を
「明るさのブレ」として補正で打ち消してしまい、波形が出ない。

当て方の失敗は原因を判別して指示を返す。誰に渡しても数秒で当てられるように。

| 状態 | 表示 |
|---|---|
| 覆えていない | 背面のレンズを指の腹で覆う |
| 外光が漏れている | レンズ全体を隙間なく覆う |
| **押しつけすぎ**(血流が止まって波形が平坦) | 力を抜いて、そっと触れるだけ |
| 拍がばらついている | 動かさずに待つ |
| 光量不足 | 明るい場所で試す |

ライトは**既定で消灯**。環境光で足りないと2秒判定してから、やむなく弱く点ける。

### 微動 — 生理的微動 (8〜12Hz)

[`TremorSensor.swift`](ios/Tenonaka/Data/TremorSensor.swift)

人間の手には常に 8〜12Hz の細かい震えがある。運動単位の発火に由来する不随意なもので、
止めようとしても止まらない。机に置いた端末には存在しない。

加速度と角速度を 100Hz で取り、1秒窓にハン窓をかけて **Goertzel 法**で
8〜12Hz の各周波数だけを直接計算する(FFT を持ち出すほどの帯域数ではない)。

iPhone 15 での実測値:

| 条件 | 8〜12Hz の強さ | 「置く」比 |
|---|---|---|
| 手に持つ | 0.00352 | **23倍** |
| 机に肘をついて構える | 0.00184 | **12倍** |
| 持って歩く | 0.02512 | 167倍 |
| 机に置く | 0.00015 | — |

しきい値は **0.0008**。「置く」の5.3倍上、「机に構える」の2.3倍下で、両側に余裕がある。

離す判定だけ **3秒遅らせている**(非対称なヒステリシス)。読書中の一瞬の取りこぼしで
文字が止まると体験が壊れるが、再開は即時でよいため。

## 構成

```
tenonaka/
├── docker-compose.yml          ローカル用 PostgreSQL (ポート 5433)
├── server/                     NestJS + Prisma
│   ├── Dockerfile              マルチステージ。App Runner にそのまま載る
│   ├── prisma/schema.prisma
│   ├── prisma/migrations/
│   └── src/letters/            手紙・封印・読了報告
└── ios/                        Swift / SwiftUI
    ├── Tenonaka.xcodeproj
    ├── Supporting/Info.plist
    └── Tenonaka/
        ├── Models/Letter.swift
        ├── Data/               PulseSensor, TremorSensor, LetterStore
        ├── Theme/              紙の質感・明朝体
        └── Views/              書く・封をする・読む
```

## 動かし方

### ローカル

```bash
docker compose up -d
cd server
npm install
cp .env.example .env
npx prisma migrate deploy
npm run dev                      # http://localhost:3100
```

```bash
open ios/Tenonaka.xcodeproj
```

**脈と微動はシミュレータでは測れません**(カメラも加速度センサも無い)。実機が必要。

### 実機

署名は自動署名で設定済み(`DEVELOPMENT_TEAM = XXXXXXXXXX`)。

iOS 16 以降は **デベロッパモード** が必要:
設定 → プライバシーとセキュリティ → デベロッパモード → オン → 再起動。
項目が見えないときは、一度 Xcode から実行を試みると現れる。

```bash
cd ios
xcodebuild -project Tenonaka.xcodeproj -scheme Tenonaka \
  -destination 'id=<DEVICE_UDID>' -configuration Debug \
  TENONAKA_API_BASE_URL="https://SERVICE_ID.ap-northeast-1.awsapprunner.com" \
  -allowProvisioningUpdates build

xcrun devicectl device install app --device <DEVICE_ID> <APP_PATH>
```

接続先はビルド設定 `TENONAKA_API_BASE_URL` が既定値になる。
**ホーム画面のタイトル「手のなか」を長押し**すると実行中に差し替えられる
(会場で接続先が変わったとき用の逃げ道)。

## 本番環境 (AWS)

| | |
|---|---|
| API | `https://SERVICE_ID.ap-northeast-1.awsapprunner.com` |
| 実行 | App Runner `tenonaka-api` (0.5 vCPU / 1GB) |
| DB | RDS PostgreSQL 18.3 `tenonaka-db`(非公開・単一AZ) |
| 経路 | App Runner → VPC コネクタ → RDS。SG 参照で 5432 のみ許可 |
| リージョン | ap-northeast-1 |

**App Runner を選んだ理由は HTTPS。** AWS でドメインを持たずに有効な証明書つき
エンドポイントが得られるのはここだけで、ALB や EC2 は ACM 証明書=自前ドメインが必要になる。
常時起動なのでコールドスタートも無い。

### 更新手順

```bash
source ~/.tenonaka-deploy.env
cd server
docker buildx build --platform linux/amd64 --provenance=false --sbom=false \
  -t ${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/tenonaka-api:latest --push .
aws apprunner start-deployment --service-arn "$SERVICE_ARN"
```

`--provenance=false --sbom=false` は**毎回必要**。付けないと buildx が
OCI image index (マニフェストリスト) を作り、**App Runner が pull できない**。

`--platform linux/amd64` も必須(App Runner は x86_64、開発機は arm64)。

起動時に `prisma migrate deploy` が走る。

### 構築時に踏んだ落とし穴

- **App Runner は `apne1-az3` に対応していない。** VPC コネクタのサブネットは
  `ap-northeast-1c` (apne1-az1) と `1d` (apne1-az2) を使う。論理AZ名ではなく物理AZで判断する
- **`AWSServiceRoleForAppRunner` は自動作成されない。** VPC コネクタ作成時に
  ネットワーク用のロールだけが作られるので、本体用は `create-service-linked-role` で明示的に作る
- **zsh では `$ACCOUNT:role/...` が壊れる。** `:r` がパラメータ修飾子として解釈されるため
  `${ACCOUNT}` と囲む必要がある

## API

認証は `x-user-id` ヘッダのみ(未指定なら `local-user`)。
端末ごとに UUID を発行して送っている。レート制限は 60回/分。

| メソッド | パス | 内容 |
|---|---|---|
| POST | `/letters` | 手紙を送る。**`senderBpm` は必須**(脈が無いと送れない) |
| GET | `/letters/:code` | 符号で受け取る。**最初に開いた端末に紐づく** |
| POST | `/letters/:code/receipt` | 読まれ方を返す。受け取った端末からのみ |
| GET | `/letters/sent` | 自分が送った手紙と読まれ方 |
| GET | `/health` | 死活確認 |

### 符号は「言える言葉」にする

符号は**声に出して人に渡すもの**なので、読める言葉として発行する。

```
GONOHOHOBU   REZEHUGAPE   YUZADATAZE   MISUHABOGI
```

仮名の音節(`KA` `SU` `HO` …58種)を5つ並べた10文字。日本語話者はそのまま読める。
ランダムな英数字だと `2UJECG` のようになり、「にーゆーじぇいいーしーじー」では手渡しの言葉にならない。

- **数字を使わない。** `I` と `1`、`O` と `0` の見間違いが構造的に起きない
- 58<sup>5</sup> = **約6億5000万通り**
- 生成には `crypto.randomInt` を使う(符号は秘密として機能するので、
  予測可能な `Math.random()` は使えない)
- `code` を指定して作ることもできる(5〜12文字の英字。`SAKURA` `KOMOREBI` など)

読了報告は**上書きではなく、より長く握られた記録が残る**。読み直しで時間が減らないように。

### 一度しか渡らない

手紙は **最初に開いた端末に紐づき、以後は他の端末から読めない**。

手渡しは一人にしか渡せない、という意味論をそのまま機構にしたもの。
副作用として、符号を総当たりしても当たった手紙のほとんどが既に受け取られ済みになり、
**総当たりの価値が消える**。

- 送り主が自分の手紙を確認しても受け取り済みにはならない(相手の手紙を潰さないため)
- 受け取った本人の読み直しは許す(一度しか読めない、ではなく一人しか読めない)
- 読了報告も受け取った端末からのみ(符号を知っているだけでは偽造できない)

### 守りの水準について

**本物の認証ではない。** 端末が発行した UUID を `x-user-id` としてそのまま渡しており、
推測できない文字列をベアラトークンとして使っているだけである。

- 既定値は持たせていない(以前は `local-user` に落としており、推測できる ID で
  他人の送信履歴が全部見えていた)
- 脈は個人識別に使えないので、**誰が読んだかは証明できない**。
  証明できるのは「生きた身体がその瞬間そこに居たこと」まで

## デモ用の手紙を用意する

手紙は一度開かれると他の端末から読めなくなるので、デモを繰り返すなら毎回用意する。

```bash
./scripts/new-demo-letter.sh              # 符号は自動生成
./scripts/new-demo-letter.sh SAKURA       # 符号を指定
BASE_URL=http://localhost:3100 ./scripts/new-demo-letter.sh
```

本文は [`scripts/demo-letter.txt`](scripts/demo-letter.txt) を編集する。
後半に転換があり、**途中で置くと肝心なところに届かない**構成にしてある。

## 動作確認用の起動フラグ (Debug ビルドのみ)

```bash
xcrun devicectl device process launch --device <DEVICE_ID> --terminate-existing \
  --environment-variables '{"LETTER":"1"}' dev.takao.tenonaka
```

| 環境変数 | 内容 |
|---|---|
| `LETTER=1` | サンプルの手紙を読む画面だけを出す |
| `PULSE_TEST=1` | 脈の検証画面(波形・心拍数・当て方の指示・明るさ) |
| `TREMOR_TEST=1` | 微動の検証画面(帯域エネルギー・しきい値スライダ) |

シミュレータの場合は `SIMCTL_CHILD_` 接頭辞をつけて `xcrun simctl launch` に渡す。

## 正直な限界

- **これは DRM ではない。** 別の端末で撮影して要約させることは可能で、技術的に防げない。
  この機構が保証するのは「防止」ではなく **「費やされたかどうかの申告」**
- **なりすましは防げない。** 脈は個人識別に使えない(常に変動し、他人と重なる)。
  証明できるのは「生きた身体がその瞬間そこに居たこと」までで、それが誰かは分からない
- **医療的な精度は主張しない。** 心拍数は妥当な値が出ることを確認しただけで、
  正解と突き合わせた検証はしていない
- 微動の判定はバイブレーターで偽装しうる。脈より弱い証明である
