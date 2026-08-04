import { Body, Controller, Get, Headers, Param, Post } from '@nestjs/common';
import { CreateLetterDto } from './dto/create-letter.dto';
import { ReadReceiptDto } from './dto/read-receipt.dto';
import { LettersService } from './letters.service';

/// 認証はハッカソン規模のため x-user-id ヘッダのみ。
const DEFAULT_USER_ID = 'local-user';

@Controller('letters')
export class LettersController {
  constructor(private readonly letters: LettersService) {}

  /// 手紙を送る。脈が無いと作れない(CreateLetterDto で senderBpm を必須にしている)
  @Post()
  async create(
    @Headers('x-user-id') userId: string | undefined,
    @Body() dto: CreateLetterDto,
  ) {
    return this.letters.create(userId ?? DEFAULT_USER_ID, dto);
  }

  /// 自分が送った手紙と、その読まれ方
  @Get('sent')
  async listSent(@Headers('x-user-id') userId: string | undefined) {
    return this.letters.listSent(userId ?? DEFAULT_USER_ID);
  }

  /// 符号で手紙を受け取る
  @Get(':code')
  async findByCode(@Param('code') code: string) {
    return this.letters.findByCode(code);
  }

  /// 読まれ方を返す
  @Post(':code/receipt')
  async recordReceipt(
    @Param('code') code: string,
    @Body() dto: ReadReceiptDto,
  ) {
    return this.letters.recordReceipt(code, dto);
  }
}
