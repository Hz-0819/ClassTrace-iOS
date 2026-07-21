import { IsIn, IsOptional, IsPhoneNumber, IsString, IsUrl, Length, MaxLength } from "class-validator";

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  displayName?: string;

  @IsOptional()
  @IsUrl({ require_protocol: true })
  avatarUrl?: string;
}

export class SwitchRoleDto {
  @IsIn(["TEACHER", "GUARDIAN"])
  role!: "TEACHER" | "GUARDIAN";
}
export class LinkPhoneDto { @IsPhoneNumber("CN") phone!: string; @Length(6, 6) code!: string; }
