import { Module } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { RolesGuard } from "../../common/auth/roles.guard";
import { IdentityModule } from "../identity/identity.module";
import { AppStoreService } from "./app-store.service";
import { AppStoreWebhookController, CommerceController } from "./commerce.controller";
import { CommerceService } from "./commerce.service";

@Module({ imports: [IdentityModule], controllers: [CommerceController, AppStoreWebhookController], providers: [CommerceService, AppStoreService, AuthGuard, RolesGuard], exports: [CommerceService, AppStoreService] })
export class CommerceModule {}
