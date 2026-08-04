import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/// デモ用の手紙。符号 AOI で読める。
/// 要約されると失われるものを含むように書いてある(後半に転換がある)。
const DEMO = {
  code: 'AOI',
  senderName: '母より',
  recipientName: 'あなたへ',
  senderBpm: 74,
  body: `元気にしていますか。

こちらは変わりありません。母の膝は相変わらずで、朝の階段だけは手すりを使うようになりました。それでも庭のことは自分でやると言って聞きません。

去年あなたが植えていった木が、今年は花をつけました。写真を撮ったのですが、どうにも本物のようには写らないので、送るのはやめました。

伝えたいことがあって書きはじめたのに、こうしていると、どうでもいいことばかり並べてしまいます。本当のことを書くのが、少し怖いのだと思います。

先週、病院で検査を受けました。結果はまだ出ていません。何でもないと思います。ただ、何でもなかったとしても、一度ちゃんと言っておきたくなりました。

あのとき、あなたを引き止めなかったのは、行かせたかったからです。寂しくなかったわけではありません。

返事はいりません。読んでくれただけで、じゅうぶんです。`,
};

async function main() {
  await prisma.letter.upsert({
    where: { code: DEMO.code },
    create: { ...DEMO, senderUserId: 'demo-sender' },
    update: { ...DEMO, readAt: null, readHeldSeconds: null, readReleaseCount: null, readCompleted: null },
  });
  console.log(`seeded letter ${DEMO.code}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(() => void prisma.$disconnect());
