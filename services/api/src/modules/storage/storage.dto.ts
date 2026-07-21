import { IsInt, IsString, Max, MaxLength, Min } from "class-validator";
export class UploadIntentDto { @IsString() @MaxLength(240) fileName!: string; @IsString() mimeType!: string; @IsInt() @Min(1) @Max(50_000_000) sizeBytes!: number; }
