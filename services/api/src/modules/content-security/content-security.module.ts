import { Module } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { IdentityModule } from "../identity/identity.module";
import { ContentSecurityController } from "./content-security.controller";
import { ContentSecurityService } from "./content-security.service";
@Module({ imports: [IdentityModule], controllers: [ContentSecurityController], providers: [ContentSecurityService, AuthGuard], exports: [ContentSecurityService] })
export class ContentSecurityModule {}
