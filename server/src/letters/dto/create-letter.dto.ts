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
   * 符号を指定する。デモで意味のある言葉を使いたいときのため
   * (SAKURA など)。省略すれば読める符号が自動発行される。
   *
   * 数字を許さない。声に出して渡す前提なので、I と 1、O と 0 の
   * 見間違いを構造的に排除している。
   *
   * 5文字未満を許すと総当たりが現実的になるため下限を設けている。
   */
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{5,12}$/, {
    message: 'code must be 5-12 letters (no digits)',
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
