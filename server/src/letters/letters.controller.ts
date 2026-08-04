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

  /// 海に流す。脈が無いと流せない(CreateLetterDto で senderBpm を必須にしている)
  @Post()
  async cast(
    @Headers('x-user-id') userId: string | undefined,
    @Body() dto: CreateLetterDto,
  ) {
    return this.letters.cast(this.requireUserId(userId), dto);
  }

  /// 海から一通拾う。流した数だけ拾える
  @Post('pickup')
  async pickUp(@Headers('x-user-id') userId: string | undefined) {
    return this.letters.pickUp(this.requireUserId(userId));
  }

  /// いま海に何通あるか、あと何通拾えるか
  @Get('sea')
  async sea(@Headers('x-user-id') userId: string | undefined) {
    return this.letters.seaCount(this.requireUserId(userId));
  }

  /// 自分が流した手紙と、返ってきた身体の記録
  @Get('sent')
  async listSent(@Headers('x-user-id') userId: string | undefined) {
    return this.letters.listSent(this.requireUserId(userId));
  }

  /// 自分が拾った手紙の一覧。本文は含まない(読むには取り直させる)
  @Get('received')
  async listReceived(@Headers('x-user-id') userId: string | undefined) {
    return this.letters.listReceived(this.requireUserId(userId));
  }

  /// 拾った手紙を読み直す。
  /// この経路より前に sent / received / sea を宣言しないと :code に食われる
  @Get(':code')
  async findByCode(
    @Headers('x-user-id') userId: string | undefined,
    @Param('code') code: string,
  ) {
    return this.letters.findByCode(this.requireUserId(userId), code);
  }

  /// 読まれ方を流した人に返す。拾った端末からのみ
  @Post(':code/receipt')
  async recordReceipt(
    @Headers('x-user-id') userId: string | undefined,
    @Param('code') code: string,
    @Body() dto: ReadReceiptDto,
  ) {
    return this.letters.recordReceipt(this.requireUserId(userId), code, dto);
  }
}
