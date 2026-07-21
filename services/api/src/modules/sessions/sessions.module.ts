import { Module } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { IdentityModule } from "../identity/identity.module";
import { HourLedgerService } from "./hour-ledger.service";
import { SessionsController } from "./sessions.controller";
import { SessionsService } from "./sessions.service";

@Module({ imports: [IdentityModule], controllers: [SessionsController], providers: [SessionsService, HourLedgerService, AuthGuard], exports: [SessionsService, HourLedgerService] })
export class SessionsModule {}
