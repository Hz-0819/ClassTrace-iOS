import { Module } from "@nestjs/common";
import { IdentityController } from "./identity.controller";
import { IdentityService } from "./identity.service";
import { SMS_PROVIDER, TencentSmsProvider } from "./sms.provider";
import { TokenService } from "./token.service";

@Module({
  controllers: [IdentityController],
  providers: [IdentityService, TokenService, { provide: SMS_PROVIDER, useClass: TencentSmsProvider }],
  exports: [TokenService]
})
export class IdentityModule {}
