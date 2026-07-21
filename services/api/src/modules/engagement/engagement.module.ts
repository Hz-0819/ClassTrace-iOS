import { Module } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { RolesGuard } from "../../common/auth/roles.guard";
import { IdentityModule } from "../identity/identity.module";
import { EngagementController } from "./engagement.controller";
import { EngagementService } from "./engagement.service";
import { ApnsService } from "./apns.service";
import { NotificationWorkerService } from "./notification-worker.service";

@Module({ imports: [IdentityModule], controllers: [EngagementController], providers: [EngagementService, ApnsService, NotificationWorkerService, AuthGuard, RolesGuard], exports: [EngagementService, NotificationWorkerService] })
export class EngagementModule {}
