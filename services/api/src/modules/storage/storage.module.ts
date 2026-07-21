import { Module } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { IdentityModule } from "../identity/identity.module";
import { StorageController } from "./storage.controller";
import { StorageService } from "./storage.service";
@Module({ imports: [IdentityModule], controllers: [StorageController], providers: [StorageService, AuthGuard], exports: [StorageService] })
export class StorageModule {}
