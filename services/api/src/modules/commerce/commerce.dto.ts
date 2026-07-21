import { IsIn, IsInt, IsNumber, IsOptional, IsString, Length, MaxLength, Min } from "class-validator";

export class CreateOrderDto {
  @IsString() classId!: string;
  @IsString() studentId!: string;
  @IsInt() @Min(0) totalAmountCents!: number;
  @IsNumber() @Min(0.01) purchasedHours!: number;
  @IsOptional() @IsIn(["DIRECT_FULL", "PARTIAL_RESERVE", "PER_SESSION"]) settlementPolicy?: "DIRECT_FULL" | "PARTIAL_RESERVE" | "PER_SESSION";
}
export class RecordPaymentDto {
  @IsString() provider!: string;
  @IsString() providerTransactionId!: string;
  @IsInt() @Min(1) amountCents!: number;
}
export class RequestRefundDto {
  @IsInt() @Min(1) amountCents!: number;
  @IsNumber() @Min(0) hours!: number;
  @IsOptional() @IsString() @MaxLength(1000) reason?: string;
}
export class ResolveRefundDto {
  @IsIn(["APPROVED", "REJECTED", "REFUNDED"]) status!: string;
  @IsOptional() @IsString() providerRefundId?: string;
}
export class StoreKitTransactionDto { @IsString() signedTransaction!: string; }
export class StoreKitNotificationDto { @IsString() signedPayload!: string; }
export class CreateActivationCodeDto { @IsInt() @Min(1) days!: number; }
export class RedeemActivationCodeDto { @IsString() @Length(8, 64) code!: string; }
