import { Type } from "class-transformer";
import { IsArray, IsIn, IsNumber, IsOptional, IsString, MaxLength, Min, ValidateNested } from "class-validator";
export class RecordAttendanceDto { @IsString() sessionId!: string; @IsString() studentId!: string; @IsIn(["SCHEDULED","PRESENT","LEAVE","ABSENT","INSUFFICIENT"]) status!: any; @IsOptional() @IsNumber() @Min(0) deductHours?: number; @IsOptional() @IsString() @MaxLength(500) remark?: string; }
export class BatchAttendanceDto { @IsArray() @ValidateNested({ each: true }) @Type(() => RecordAttendanceDto) records!: RecordAttendanceDto[]; }
export class UpdateAttendanceDto { @IsIn(["SCHEDULED","PRESENT","LEAVE","ABSENT","INSUFFICIENT"]) status!: any; @IsOptional() @IsNumber() @Min(0) deductHours?: number; @IsOptional() @IsString() @MaxLength(500) remark?: string; }
