import { IsBoolean, IsOptional, IsString, Length, MaxLength } from "class-validator";

export class CreateStudentDto {
  @IsString() @MaxLength(40) name!: string;
  @IsOptional() @IsString() @MaxLength(20) gender?: string;
  @IsOptional() @IsString() @MaxLength(30) grade?: string;
  @IsOptional() @IsBoolean() linkAsGuardian?: boolean;
}

export class UpdateStudentDto {
  @IsOptional() @IsString() @MaxLength(40) name?: string;
  @IsOptional() @IsString() @MaxLength(20) gender?: string;
  @IsOptional() @IsString() @MaxLength(30) grade?: string;
}

export class BindStudentDto {
  @IsString() @Length(12, 128) code!: string;
  @IsOptional() @IsString() @MaxLength(30) relationship?: string;
}
