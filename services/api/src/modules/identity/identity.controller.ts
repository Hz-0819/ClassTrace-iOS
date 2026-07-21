import { Body, Controller, HttpCode, Post } from "@nestjs/common";
import { IdentityService } from "./identity.service";
import { AppleLoginDto, RefreshTokenDto, RequestPhoneCodeDto, VerifyPhoneCodeDto } from "./identity.dto";
import { TokenService } from "./token.service";

@Controller("auth")
export class IdentityController {
  constructor(private readonly identity: IdentityService, private readonly tokens: TokenService) {}

  @Post("phone/code")
  requestPhoneCode(@Body() dto: RequestPhoneCodeDto) {
    return this.identity.requestPhoneCode(dto);
  }

  @Post("phone/verify")
  @HttpCode(200)
  verifyPhoneCode(@Body() dto: VerifyPhoneCodeDto) {
    return this.identity.verifyPhoneCode(dto);
  }

  @Post("apple")
  @HttpCode(200)
  apple(@Body() dto: AppleLoginDto) { return this.identity.loginWithApple(dto); }

  @Post("refresh")
  @HttpCode(200)
  refresh(@Body() dto: RefreshTokenDto) {
    return this.tokens.rotate(dto.refreshToken);
  }

  @Post("logout")
  @HttpCode(204)
  async logout(@Body() dto: RefreshTokenDto): Promise<void> {
    await this.tokens.revoke(dto.refreshToken);
  }
}
