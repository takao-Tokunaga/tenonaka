import { IsBoolean, IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';

/// 読まれ方の記録。内容への返信は含まない。返るのは身体の事実だけ。
export class ReadReceiptDto {
  /// 生きた手が握っていた合計秒数
  @IsNumber()
  @Min(0)
  heldSeconds!: number;

  /// 途中で置かれた回数
  @IsInt()
  @Min(0)
  releaseCount!: number;

  @IsBoolean()
  completed!: boolean;

  /**
   * 読み終えたときの読み手の脈。
   *
   * これが返ると、手紙の効果が読んだ人の身体で測られたことになる。
   * 封をせずに閉じることもできるので任意。
   */
  @IsOptional()
  @IsNumber()
  @Min(25)
  @Max(220)
  readerBpm?: number;
}
