import { IsArray, IsDateString, IsIn, IsNumber, IsObject, IsOptional, IsString, MaxLength } from "class-validator";

export class CreateHomeworkDto {
  @IsString() classId!: string;
  @IsString() @MaxLength(120) title!: string;
  @IsString() @MaxLength(10000) content!: string;
  @IsOptional() @IsDateString() dueAt?: string;
  @IsOptional() @IsArray() attachments?: unknown[];
  @IsOptional() @IsIn(["DRAFT", "PUBLISHED"]) status?: "DRAFT" | "PUBLISHED";
}
export class UpdateHomeworkDto {
  @IsOptional() @IsString() @MaxLength(120) title?: string;
  @IsOptional() @IsString() @MaxLength(10000) content?: string;
  @IsOptional() @IsDateString() dueAt?: string;
  @IsOptional() @IsArray() attachments?: unknown[];
  @IsOptional() @IsIn(["DRAFT", "PUBLISHED", "CLOSED"]) status?: "DRAFT" | "PUBLISHED" | "CLOSED";
}
export class SubmitHomeworkDto {
  @IsString() studentId!: string;
  @IsOptional() @IsString() @MaxLength(10000) content?: string;
  @IsOptional() @IsArray() attachments?: unknown[];
}
export class ReviewHomeworkDto {
  @IsOptional() @IsNumber() score?: number;
  @IsOptional() @IsString() @MaxLength(5000) comment?: string;
  @IsOptional() @IsIn(["REVIEWED", "RETURNED"]) status?: "REVIEWED" | "RETURNED";
}
export class CreateMaterialDto {
  @IsOptional() @IsString() classId?: string;
  @IsString() @MaxLength(240) name!: string;
  @IsString() objectKey!: string;
  @IsString() mimeType!: string;
  @IsNumber() sizeBytes!: number;
  @IsOptional() @IsString() @MaxLength(50) category?: string;
}
export class CreatePlanDto {
  @IsOptional() @IsString() studentId?: string;
  @IsString() @MaxLength(120) title!: string;
  @IsOptional() @IsString() @MaxLength(3000) description?: string;
  @IsOptional() @IsObject() frequency?: Record<string, unknown>;
  @IsOptional() @IsDateString() startsAt?: string;
  @IsOptional() @IsDateString() endsAt?: string;
}
export class UpdatePlanDto {
  @IsOptional() @IsString() @MaxLength(120) title?: string;
  @IsOptional() @IsString() @MaxLength(3000) description?: string;
  @IsOptional() @IsObject() frequency?: Record<string, unknown>;
  @IsOptional() @IsDateString() startsAt?: string;
  @IsOptional() @IsDateString() endsAt?: string;
  @IsOptional() @IsIn(["ACTIVE", "COMPLETED", "ARCHIVED"]) status?: "ACTIVE" | "COMPLETED" | "ARCHIVED";
}
export class CheckInDto { @IsOptional() @IsString() @MaxLength(1000) note?: string; }
export class CreateMistakeDto {
  @IsOptional() @IsString() studentId?: string;
  @IsOptional() @IsString() @MaxLength(50) subject?: string;
  @IsString() @MaxLength(200) title!: string;
  @IsOptional() @IsString() @MaxLength(10000) content?: string;
  @IsOptional() @IsString() @MaxLength(10000) answer?: string;
  @IsOptional() @IsString() @MaxLength(10000) analysis?: string;
  @IsOptional() @IsArray() tags?: string[];
  @IsOptional() @IsArray() images?: unknown[];
}
export class UpdateMistakeDto extends CreateMistakeDto {}
