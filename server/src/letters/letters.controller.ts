import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
} from '@nestjs/common';
import { CreateLetterDto } from './dto/create-letter.dto';
import { ReadReceiptDto } from './dto/read-receipt.dto';
import { LettersService } from './letters.service';

@Controller('letters')
export class LettersController {
  constructor(private readonly letters: LettersService) {}

  /**
   * 端末の識別子。
   *
   * 認証は簡易実装で、端末が発行した UUID をそのまま渡している。
   * 本物の認証ではなく、推測できない文字列をベアラトークンとして
   * 使っているだけである、という点は正直に書いておく。
   *
   * 既定値は持たせない。以前は local-user に落としていたが、
   * 推測できる ID だと他人の送信履歴が全部見えてしまう。
   */
  private requireUserId(userId: string | undefined): string {
    const trimmed = userId?.trim();
    if (!trimmed) {
      throw new BadRequestException('x-user-id ヘッダが必要です');
    }
    return trimmed;
  }

  /// 手紙を送る。脈が無いと作れない(CreateLetterDto で senderBpm を必須にしている)
  @Post()
  async create(
    @Headers('x-user-id') userId: string | undefined,
    @Body() dto: CreateLetterDto,
  ) {
    return this.letters.create(this.requireUserId(userId), dto);
  }

  /// 自分が送った手紙と、その読まれ方
  @Get('sent')
  async listSent(@Headers('x-user-id') userId: string | undefined) {
    return this.letters.listSent(this.requireUserId(userId));
  }

  /// 自分が受け取った手紙の一覧。本文は含まない(読むには取り直させる)
  @Get('received')
  async listReceived(@Headers('x-user-id') userId: string | undefined) {
    return this.letters.listReceived(this.requireUserId(userId));
  }

  /// 符号で手紙を受け取る。最初に開いた端末に紐づく
  /// この経路より前に sent / received を宣言しないと :code に食われる
  @Get(':code')
  async findByCode(
    @Headers('x-user-id') userId: string | undefined,
    @Param('code') code: string,
  ) {
    return this.letters.findByCode(this.requireUserId(userId), code);
  }

  /// 読まれ方を返す。受け取った端末からのみ
  @Post(':code/receipt')
  async recordReceipt(
    @Headers('x-user-id') userId: string | undefined,
    @Param('code') code: string,
    @Body() dto: ReadReceiptDto,
  ) {
    return this.letters.recordReceipt(this.requireUserId(userId), code, dto);
  }
}
