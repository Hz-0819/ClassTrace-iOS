import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from "class-validator";
export class CheckTextDto { @IsString() @MaxLength(10000) content!: string; @IsOptional() @IsString() contextId?: string; }
export class CheckFileDto { @IsString() objectKey!: string; @IsString() mimeType!: string; @IsInt() @Min(1) @Max(50_000_000) sizeBytes!: number; }
