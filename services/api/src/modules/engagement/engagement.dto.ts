import { IsArray, IsBoolean, IsDateString, IsIn, IsOptional, IsString, MaxLength } from "class-validator";

export class RegisterDeviceDto {
  @IsString() token!: string;
  @IsIn(["development", "production"]) environment!: string;
}
export class NotificationPreferenceDto {
  @IsString() eventType!: string;
  @IsIn(["IN_APP", "APNS", "WECHAT", "SMS"]) channel!: "IN_APP" | "APNS" | "WECHAT" | "SMS";
  @IsBoolean() enabled!: boolean;
}
export class CreateAnnouncementDto {
  @IsString() @MaxLength(120) title!: string;
  @IsString() @MaxLength(10000) content!: string;
  @IsOptional() @IsArray() audience?: string[];
  @IsOptional() @IsDateString() publishedAt?: string;
  @IsOptional() @IsDateString() expiresAt?: string;
}
export class SubmitFeedbackDto {
  @IsString() @MaxLength(50) category!: string;
  @IsString() @MaxLength(5000) content!: string;
  @IsOptional() @IsString() @MaxLength(200) contact?: string;
  @IsOptional() @IsArray() attachments?: unknown[];
}
export class ReplyFeedbackDto {
  @IsString() @MaxLength(5000) reply!: string;
  @IsOptional() @IsIn(["PROCESSING", "RESOLVED", "CLOSED"]) status?: "PROCESSING" | "RESOLVED" | "CLOSED";
}
export class ManualCourseDto {
  @IsString() @MaxLength(120) name!: string;
  @IsDateString() startsAt!: string;
  @IsDateString() endsAt!: string;
  @IsOptional() @IsString() @MaxLength(200) location?: string;
  @IsOptional() @IsString() @MaxLength(2000) note?: string;
}
