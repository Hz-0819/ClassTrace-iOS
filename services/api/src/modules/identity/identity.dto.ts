import { IsIn, IsOptional, IsPhoneNumber, IsString, Length, MaxLength } from "class-validator";

export class RequestPhoneCodeDto {
  @IsPhoneNumber("CN")
  phone!: string;

  @IsIn(["login", "bind", "delete-account"])
  purpose!: string;
}

export class VerifyPhoneCodeDto {
  @IsPhoneNumber("CN")
  phone!: string;

  @Length(6, 6)
  code!: string;

  @IsIn(["login", "bind", "delete-account"])
  purpose!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  displayName?: string;

  @IsOptional()
  @IsIn(["TEACHER", "GUARDIAN"])
  role?: "TEACHER" | "GUARDIAN";
}

export class RefreshTokenDto {
  @IsString()
  @Length(32, 512)
  refreshToken!: string;
}

export class AppleLoginDto {
  @IsString()
  identityToken!: string;

  @IsString()
  nonce!: string;

  @IsOptional()
  @IsString()
  authorizationCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  fullName?: string;

  @IsOptional()
  @IsIn(["TEACHER", "GUARDIAN"])
  role?: "TEACHER" | "GUARDIAN";
}
