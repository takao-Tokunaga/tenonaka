import {
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateLetterDto {
  /**
   * 符号を指定する。デモで口頭で伝えるときに覚えやすい文字列を使うため。
   * 省略すればランダムに6文字で発行される。
   *
   * 見間違えやすい I O 0 1 は使えない(符号は声で伝える前提なので)。
   * 5文字未満を許すと総当たりが現実的になるため下限を設けている
   * (4文字は約100万通りで、レート制限内でも数日で舐められる)
   */
  @IsOptional()
  @IsString()
  @Matches(/^[A-HJ-NP-Za-hj-np-z2-9]{5,8}$/, {
    message: 'code must be 5-8 characters and must not contain I, O, 0 or 1',
  })
  code?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(20000)
  body!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  senderName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  recipientName?: string;

  /// 封をした瞬間の脈。これが無い手紙は作れない
  @IsNumber()
  @Min(25)
  @Max(220)
  senderBpm!: number;
}
