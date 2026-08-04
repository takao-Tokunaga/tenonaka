import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Letter } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateLetterDto } from './dto/create-letter.dto';
import { ReadReceiptDto } from './dto/read-receipt.dto';

/// 口で伝える符号なので、見間違えやすい文字(I O 0 1)を外している
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
/// 6文字で約10億通り。声で伝えられる長さを保ちつつ総当たりを困難にする
const CODE_LENGTH = 6;

function randomCode(): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i += 1) {
    code += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  }
  return code;
}

@Injectable()
export class LettersService {
  constructor(private readonly prisma: PrismaService) {}

  /// 読む側に返す形。送り主の情報のうち、読み手に見せるものだけ。
  private toReaderResponse(letter: Letter) {
    return {
      code: letter.code,
      body: letter.body,
      senderName: letter.senderName,
      recipientName: letter.recipientName,
      senderBpm: letter.senderBpm,
      sentAt: letter.sentAt.toISOString(),
      alreadyRead: letter.readAt !== null,
    };
  }


  /// 送り主に返す形。読まれ方の記録がつく。
  private toSenderResponse(letter: Letter) {
    return {
      code: letter.code,
      body: letter.body,
      senderName: letter.senderName,
      recipientName: letter.recipientName,
      senderBpm: letter.senderBpm,
      sentAt: letter.sentAt.toISOString(),
      // 受け取られたか(読み終えたかとは別の状態)
      claimedAt: letter.claimedAt?.toISOString() ?? null,
      receipt:
        letter.readAt === null
          ? null
          : {
              heldSeconds: letter.readHeldSeconds ?? 0,
              releaseCount: letter.readReleaseCount ?? 0,
              completed: letter.readCompleted ?? false,
              readAt: letter.readAt.toISOString(),
            },
    };
  }

  async create(userId: string, dto: CreateLetterDto) {
    // 符号を指定された場合は引き直さず、埋まっていればそのまま失敗させる
    if (dto.code) {
      const code = dto.code.toUpperCase();
      const existing = await this.prisma.letter.findUnique({ where: { code } });
      if (existing) {
        throw new ConflictException(`符号 ${code} は既に使われています`);
      }
      const letter = await this.prisma.letter.create({
        data: {
          code,
          body: dto.body,
          senderName: dto.senderName ?? null,
          recipientName: dto.recipientName ?? null,
          senderBpm: dto.senderBpm,
          senderUserId: userId,
        },
      });
      return this.toSenderResponse(letter);
    }

    // 符号は短いので、まれに衝突する。数回引き直す
    for (let attempt = 0; attempt < 8; attempt += 1) {
      const code = randomCode();
      const existing = await this.prisma.letter.findUnique({ where: { code } });
      if (existing) continue;

      const letter = await this.prisma.letter.create({
        data: {
          code,
          body: dto.body,
          senderName: dto.senderName ?? null,
          recipientName: dto.recipientName ?? null,
          senderBpm: dto.senderBpm,
          senderUserId: userId,
        },
      });
      return this.toSenderResponse(letter);
    }
    throw new ConflictException('符号を発行できませんでした');
  }

  /**
   * 符号で手紙を受け取る。
   *
   * 最初に開いた端末に手紙を紐づけ、以後は他の端末から読めなくする。
   * 手渡しは一人にしか渡せない、という意味論をそのまま機構にしたもの。
   * 副作用として、符号を総当たりしても当たった手紙のほとんどが
   * 既に受け取られ済みになり、総当たりの価値が消える。
   */
  async findByCode(userId: string, code: string) {
    const letter = await this.prisma.letter.findUnique({
      where: { code: code.toUpperCase() },
    });
    if (!letter) throw new NotFoundException('その符号の手紙はありません');

    // 送り主が自分の手紙を確認するだけなら受け取り済みにしない。
    // でないと下書き確認のつもりで相手の手紙を潰してしまう
    if (letter.senderUserId === userId) {
      return this.toReaderResponse(letter);
    }

    if (letter.claimedByUserId === null) {
      const claimed = await this.prisma.letter.update({
        where: { id: letter.id },
        data: { claimedByUserId: userId, claimedAt: new Date() },
      });
      return this.toReaderResponse(claimed);
    }

    if (letter.claimedByUserId !== userId) {
      throw new ForbiddenException(
        'この手紙は既に他の人が受け取っています。手紙は一人にしか渡りません。',
      );
    }

    // 受け取った本人の読み直しは許す
    return this.toReaderResponse(letter);
  }

  /// 自分が送った手紙の一覧。読まれ方がここに返ってくる。
  async listSent(userId: string) {
    const letters = await this.prisma.letter.findMany({
      where: { senderUserId: userId },
      orderBy: { sentAt: 'desc' },
      take: 50,
    });
    return letters.map((letter) => this.toSenderResponse(letter));
  }

  /**
   * 読まれ方を記録する。
   * 上書きではなく、より長く握られた記録が残るようにする。
   * 同じ手紙を読み直したときに、費やされた時間が減らないようにするため。
   */
  async recordReceipt(userId: string, code: string, dto: ReadReceiptDto) {
    const letter = await this.prisma.letter.findUnique({
      where: { code: code.toUpperCase() },
    });
    if (!letter) throw new NotFoundException('その符号の手紙はありません');

    // 受け取った本人以外は報告を送れない。
    // これがないと、符号を知っているだけで「10分持っていた」を偽造できる
    if (letter.claimedByUserId !== userId) {
      throw new ForbiddenException('この手紙を受け取った端末ではありません');
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
        readAt: letter.readAt ?? new Date(),
      },
    });
    return this.toSenderResponse(updated);
  }
}
