import { Module } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { IdentityModule } from "../identity/identity.module";
import { ContentSecurityModule } from "../content-security/content-security.module";
import { LearningController } from "./learning.controller";
import { LearningService } from "./learning.service";

@Module({ imports: [IdentityModule, ContentSecurityModule], controllers: [LearningController], providers: [LearningService, AuthGuard], exports: [LearningService] })
export class LearningModule {}
