import { Type } from "class-transformer";
import { IsArray, IsDateString, IsIn, IsInt, IsNumber, IsObject, IsOptional, IsString, Max, MaxLength, Min, ValidateNested } from "class-validator";

export class CreateSessionDto {
  @IsString() classId!: string;
  @IsDateString() startsAt!: string;
  @IsDateString() endsAt!: string;
  @IsOptional() @IsNumber() @Min(0.25) @Max(24) plannedHours?: number;
}
export class GenerateSessionsDto {
  @IsString() classId!: string;
  @IsDateString() from!: string;
  @IsDateString() to!: string;
  @IsArray() @IsInt({ each: true }) weekdays!: number[];
  @IsString() startTime!: string;
  @IsInt() @Min(15) @Max(720) durationMinutes!: number;
  @IsOptional() @IsInt() @Min(-720) @Max(840) timezoneOffsetMinutes?: number;
}
export class RescheduleDto { @IsDateString() startsAt!: string; @IsDateString() endsAt!: string; }
export class AttendanceInputDto {
  @IsString() studentId!: string;
  @IsIn(["PRESENT", "LEAVE", "ABSENT"]) status!: "PRESENT" | "LEAVE" | "ABSENT";
  @IsOptional() @IsNumber() @Min(0) @Max(24) deductHours?: number;
  @IsOptional() @IsString() @MaxLength(500) remark?: string;
}
export class ConfirmSessionDto {
  @IsArray() @ValidateNested({ each: true }) @Type(() => AttendanceInputDto)
  attendances!: AttendanceInputDto[];
}
export class CancelSessionDto { @IsOptional() @IsString() @MaxLength(500) reason?: string; }
export class AdjustHoursDto {
  @IsNumber() amount!: number;
  @IsString() @MaxLength(500) reason!: string;
}
export class RechargeHoursDto {
  @IsNumber() @Min(0.01) hours!: number;
  @IsOptional() @IsString() @MaxLength(500) remark?: string;
}
export class SessionFeedbackDto {
  @IsOptional() @IsString() @MaxLength(3000) summary?: string;
  @IsOptional() @IsString() @MaxLength(3000) performance?: string;
  @IsOptional() @IsString() @MaxLength(3000) homeworkNote?: string;
  @IsOptional() @IsObject() attachments?: Record<string, unknown>;
}
