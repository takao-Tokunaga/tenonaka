import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Letter } from '@prisma/client';
import { randomInt } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { CreateLetterDto } from './dto/create-letter.dto';
import { ReadReceiptDto } from './dto/read-receipt.dto';

/**
 * 手紙の識別子。UI には出さないが、読み直しの取得に使う。
 * 声に出して読める形にしてあるのは、開発中に口で伝えられると楽なため。
 */
const SYLLABLES = [
  'KA', 'KI', 'KU', 'KE', 'KO',
  'SA', 'SU', 'SE', 'SO',
  'TA', 'TE', 'TO',
  'NA', 'NI', 'NU', 'NE', 'NO',
  'HA', 'HI', 'HU', 'HE', 'HO',
  'MA', 'MI', 'MU', 'ME', 'MO',
  'YA', 'YU', 'YO',
  'RA', 'RI', 'RU', 'RE', 'RO',
  'WA',
  'GA', 'GI', 'GU', 'GE', 'GO',
  'ZA', 'ZU', 'ZE', 'ZO',
  'DA', 'DE', 'DO',
  'BA', 'BI', 'BU', 'BE', 'BO',
  'PA', 'PI', 'PU', 'PE', 'PO',
];

const CODE_SYLLABLES = 5;

/// /letters/:code と衝突する経路名
const RESERVED_CODES = new Set([
  'SENT',
  'RECEIVED',
  'PICKUP',
  'SEA',
  'HEALTH',
]);

/// 符号は秘密として機能するので、暗号論的に安全な乱数を使う
function randomCode(): string {
  let code = '';
  for (let i = 0; i < CODE_SYLLABLES; i += 1) {
    code += SYLLABLES[randomInt(SYLLABLES.length)];
  }
  return code;
}

@Injectable()
export class LettersService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * 拾った人に見せる形。
   * 差出人を辿る手がかりは何も出さない。海は匿名である。
   */
  private toReaderResponse(letter: Letter) {
    return {
      code: letter.code,
      body: letter.body,
      senderName: letter.senderName,
      recipientName: letter.recipientName,
      senderBpm: letter.senderBpm,
      sentAt: letter.sentAt.toISOString(),
    };
  }

  /// 流した人に返す形。返るのは身体の事実だけ。
  private toSenderResponse(letter: Letter) {
    return {
      code: letter.code,
      body: letter.body,
      senderName: letter.senderName,
      recipientName: letter.recipientName,
      senderBpm: letter.senderBpm,
      sentAt: letter.sentAt.toISOString(),
      /// 拾われたか(読み終えたかとは別の状態)
      claimedAt: letter.claimedAt?.toISOString() ?? null,
      receipt:
        letter.readAt === null
          ? null
          : {
              heldSeconds: letter.readHeldSeconds ?? 0,
              releaseCount: letter.readReleaseCount ?? 0,
              completed: letter.readCompleted ?? false,
              /// 読み終えたときの、見知らぬ誰かの脈
              readerBpm: letter.readReaderBpm,
              readAt: letter.readAt.toISOString(),
            },
    };
  }

  /// 海に流す。宛先はない
  async cast(userId: string, dto: CreateLetterDto) {
    const shared = {
      body: dto.body,
      senderName: dto.senderName ?? null,
      recipientName: dto.recipientName ?? null,
      senderBpm: dto.senderBpm,
      senderUserId: userId,
    };

    if (dto.code) {
      const code = dto.code.toUpperCase();
      if (RESERVED_CODES.has(code)) {
        throw new BadRequestException(`符号 ${code} は使えません`);
      }
      const existing = await this.prisma.letter.findUnique({ where: { code } });
      if (existing) {
        throw new ConflictException(`符号 ${code} は既に使われています`);
      }
      const letter = await this.prisma.letter.create({
        data: { ...shared, code },
      });
      return this.toSenderResponse(letter);
    }

    for (let attempt = 0; attempt < 8; attempt += 1) {
      const code = randomCode();
      const existing = await this.prisma.letter.findUnique({ where: { code } });
      if (existing) continue;
      const letter = await this.prisma.letter.create({
        data: { ...shared, code },
      });
      return this.toSenderResponse(letter);
    }
    throw new ConflictException('符号を発行できませんでした');
  }

  /// いま海に漂っている手紙の数
  async seaCount(userId: string) {
    const [drifting, mine] = await Promise.all([
      this.prisma.letter.count({ where: { claimedByUserId: null } }),
      this.prisma.letter.count({
        where: { claimedByUserId: null, senderUserId: userId },
      }),
    ]);
    const balance = await this.pickupBalance(userId);
    return {
      /// 自分が流したものを除いた、拾える手紙の数
      drifting: drifting - mine,
      /// あと何通拾えるか
      canPickUp: balance,
    };
  }

  /**
   * 拾う権利。流した数から拾った数を引いたもの。
   *
   * 一通流さないと一通拾えない。海が枯れないための規則であり、
   * 「先に自分が差し出す」という順序そのものが体験の一部でもある。
   */
  private async pickupBalance(userId: string): Promise<number> {
    const [cast, picked] = await Promise.all([
      this.prisma.letter.count({ where: { senderUserId: userId } }),
      this.prisma.letter.count({ where: { claimedByUserId: userId } }),
    ]);
    return cast - picked;
  }

  /**
   * 海から一通拾う。
   *
   * 自分が流したものは拾わない。順番ではなく無作為に選ぶ
   * (海は待ち行列ではないので)。
   *
   * 同時に別の端末が同じ手紙を掴む可能性があるため、
   * updateMany の条件に「まだ拾われていない」を入れて取り合いを解決する。
   * 掴めなければ別の手紙で引き直す。
   */
  async pickUp(userId: string) {
    if ((await this.pickupBalance(userId)) <= 0) {
      throw new ForbiddenException(
        '拾うには、まず一通流してください。差し出した数だけ受け取れます。',
      );
    }

    for (let attempt = 0; attempt < 6; attempt += 1) {
      const candidates = await this.prisma.letter.findMany({
        where: { claimedByUserId: null, senderUserId: { not: userId } },
        select: { id: true },
        take: 40,
      });
      if (candidates.length === 0) {
        throw new NotFoundException(
          'いま海に手紙はありません。誰かが流すのを待ってください。',
        );
      }

      const chosen = candidates[randomInt(candidates.length)];
      const claimed = await this.prisma.letter.updateMany({
        where: { id: chosen.id, claimedByUserId: null },
        data: { claimedByUserId: userId, claimedAt: new Date() },
      });
      // 他の端末に先を越されたら引き直す
      if (claimed.count === 0) continue;

      const letter = await this.prisma.letter.findUniqueOrThrow({
        where: { id: chosen.id },
      });
      return this.toReaderResponse(letter);
    }
    throw new ConflictException('手紙を拾えませんでした。もう一度お試しください。');
  }

  /// 拾った手紙を読み直す。拾った本人だけ
  async findByCode(userId: string, code: string) {
    const letter = await this.prisma.letter.findUnique({
      where: { code: code.toUpperCase() },
    });
    if (!letter) throw new NotFoundException('その手紙はありません');

    // 流した本人が自分の手紙を見るのは許す(拾ったことにはしない)
    if (letter.senderUserId === userId) {
      return this.toReaderResponse(letter);
    }
    if (letter.claimedByUserId !== userId) {
      throw new ForbiddenException('この手紙はあなたが拾ったものではありません');
    }
    return this.toReaderResponse(letter);
  }

  /// 自分が流した手紙と、返ってきた身体の記録
  async listSent(userId: string) {
    const letters = await this.prisma.letter.findMany({
      where: { senderUserId: userId },
      orderBy: { sentAt: 'desc' },
      take: 50,
    });
    return letters.map((letter) => this.toSenderResponse(letter));
  }

  /**
   * 自分が拾った手紙。
   *
   * **本文は返さない。** 読み直すときもサーバーから取り直させ、
   * 握らないと読めないという機構を通させるため。
   */
  async listReceived(userId: string) {
    const letters = await this.prisma.letter.findMany({
      where: { claimedByUserId: userId },
      orderBy: { claimedAt: 'desc' },
      take: 50,
    });

    return letters.map((letter) => ({
        code: letter.code,
        senderName: letter.senderName,
        senderBpm: letter.senderBpm,
        sentAt: letter.sentAt.toISOString(),
        claimedAt: letter.claimedAt?.toISOString() ?? null,
        receipt:
          letter.readAt === null
            ? null
            : {
                heldSeconds: letter.readHeldSeconds ?? 0,
                releaseCount: letter.readReleaseCount ?? 0,
                completed: letter.readCompleted ?? false,
                readerBpm: letter.readReaderBpm,
                readAt: letter.readAt.toISOString(),
              },
    }));
  }

  /**
   * 読まれ方を流した人に返す。
   *
   * 上書きではなく、より長く握られた記録が残るようにする。
   * 読み手の脈は一度返したら変えない(最初に読み終えたときの身体が記録)。
   */
  async recordReceipt(userId: string, code: string, dto: ReadReceiptDto) {
    const letter = await this.prisma.letter.findUnique({
      where: { code: code.toUpperCase() },
    });
    if (!letter) throw new NotFoundException('その手紙はありません');

    if (letter.claimedByUserId !== userId) {
      throw new ForbiddenException('この手紙を拾った端末ではありません');
    }

    const heldSeconds = Math.max(letter.readHeldSeconds ?? 0, dto.heldSeconds);
    const completed = (letter.readCompleted ?? false) || dto.completed;
    const releaseCount =
      dto.heldSeconds >= (letter.readHeldSeconds ?? 0)
        ? dto.releaseCount
        : (letter.readReleaseCount ?? dto.releaseCount);

    const updated = await this.prisma.letter.update({
      where: { id: letter.id },
      data: {
        readHeldSeconds: heldSeconds,
        readReleaseCount: releaseCount,
        readCompleted: completed,
        readReaderBpm: letter.readReaderBpm ?? dto.readerBpm ?? null,
        readAt: letter.readAt ?? new Date(),
      },
    });
    return this.toSenderResponse(updated);
  }
}
