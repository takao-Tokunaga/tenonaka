import { Injectable, NotFoundException } from '@nestjs/common';
import { randomInt } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import {
  ADDRESS_SEPARATOR,
  ADDRESS_WORD_COUNT,
  ADDRESS_WORDS,
} from './address-words';

@Injectable()
export class AddressesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * 意味のある言葉を3つ繋いだ住所を作る。
   * 秘密ではないが推測で当てられても困るので、乱数は crypto を使う。
   */
  private generate(): string {
    const words: string[] = [];
    while (words.length < ADDRESS_WORD_COUNT) {
      const word = ADDRESS_WORDS[randomInt(ADDRESS_WORDS.length)];
      // 同じ語が並ぶと情景にならないので避ける
      if (words.includes(word)) continue;
      words.push(word);
    }
    return words.join(ADDRESS_SEPARATOR);
  }

  /**
   * 自分の住所。持っていなければ発行する。
   *
   * 一度決まったら変わらない。現実の住所と同じで、気軽に変えるものではないし、
   * 変えられると相手が覚えた住所が使えなくなる。
   */
  async ensureForUser(userId: string): Promise<string> {
    const existing = await this.prisma.address.findUnique({ where: { userId } });
    if (existing) return existing.address;

    for (let attempt = 0; attempt < 8; attempt += 1) {
      const address = this.generate();
      const taken = await this.prisma.address.findUnique({ where: { address } });
      if (taken) continue;
      const created = await this.prisma.address.create({
        data: { address, userId },
      });
      return created.address;
    }
    // 語彙は約170万通りなので、8回引いて全部埋まっていることは実質起きない
    throw new NotFoundException('住所を発行できませんでした');
  }

  /// 住所から宛先の端末を引く。無ければ null
  async resolve(address: string): Promise<string | null> {
    const found = await this.prisma.address.findUnique({
      where: { address: address.trim().toLowerCase() },
    });
    return found?.userId ?? null;
  }
}
