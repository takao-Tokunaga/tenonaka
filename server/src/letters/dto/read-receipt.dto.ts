import { IsBoolean, IsInt, IsNumber, Min } from 'class-validator';

/// 読まれ方の記録。内容への返信は含まない。
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
}
