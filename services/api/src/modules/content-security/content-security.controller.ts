import { Body, Controller, Post, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { AuthenticatedUser } from "../../common/auth/authenticated-user";
import { CurrentUser } from "../../common/auth/current-user.decorator";
import { IdentityModule } from "../identity/identity.module";
import { CheckFileDto, CheckTextDto } from "./content-security.dto";
import { ContentSecurityService } from "./content-security.service";

@Controller("content-security") @UseGuards(AuthGuard)
export class ContentSecurityController {
  constructor(private readonly service: ContentSecurityService) {}
  @Post("text") text(@CurrentUser() u: AuthenticatedUser, @Body() d: CheckTextDto) { return this.service.checkText(u.id, d.content, d.contextId); }
  @Post("file") file(@CurrentUser() u: AuthenticatedUser, @Body() d: CheckFileDto) { return this.service.checkFile(u.id, d.objectKey, d.mimeType, d.sizeBytes); }
}
