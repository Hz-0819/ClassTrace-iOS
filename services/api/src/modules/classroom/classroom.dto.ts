import { IsIn, IsNumber, IsObject, IsOptional, IsString, MaxLength, Min } from "class-validator";

export class CreateCourseDto {
  @IsString() @MaxLength(80) name!: string;
  @IsOptional() @IsString() @MaxLength(50) subject?: string;
  @IsOptional() @IsString() @MaxLength(2000) description?: string;
}
export class UpdateCourseDto {
  @IsOptional() @IsString() @MaxLength(80) name?: string;
  @IsOptional() @IsString() @MaxLength(50) subject?: string;
  @IsOptional() @IsString() @MaxLength(2000) description?: string;
}

export class CreateClassDto {
  @IsString() @MaxLength(80) name!: string;
  @IsOptional() @IsString() courseId?: string;
  @IsIn(["ONE_ON_ONE", "SMALL_GROUP"]) classType!: "ONE_ON_ONE" | "SMALL_GROUP";
  @IsOptional() @IsIn(["PREPAID", "CASH"]) billingMode?: "PREPAID" | "CASH";
  @IsOptional() @IsString() @MaxLength(200) location?: string;
  @IsOptional() @IsObject() scheduleRule?: Record<string, unknown>;
}
export class UpdateClassDto {
  @IsOptional() @IsString() @MaxLength(80) name?: string;
  @IsOptional() @IsString() courseId?: string;
  @IsOptional() @IsIn(["DRAFT", "ACTIVE", "PAUSED", "COMPLETED", "CANCELLED"]) status?: "DRAFT" | "ACTIVE" | "PAUSED" | "COMPLETED" | "CANCELLED";
  @IsOptional() @IsString() @MaxLength(200) location?: string;
  @IsOptional() @IsObject() scheduleRule?: Record<string, unknown>;
}
export class AddMemberDto {
  @IsString() studentId!: string;
  @IsOptional() @IsNumber() @Min(0) initialHours?: number;
  @IsOptional() @IsNumber() @Min(0) pricePerHour?: number;
}
export class JoinClassDto { @IsString() inviteCode!: string; @IsString() studentId!: string; }
export class UpdateMemberDto {
  @IsOptional() @IsNumber() @Min(0) pricePerHour?: number;
  @IsOptional() @IsIn(["APPROVED", "PAUSED", "EXITED", "COMPLETED"]) status?: "APPROVED" | "PAUSED" | "EXITED" | "COMPLETED";
}
