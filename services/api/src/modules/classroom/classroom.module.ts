import { Module } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { IdentityModule } from "../identity/identity.module";
import { ClassroomController } from "./classroom.controller";
import { ClassroomService } from "./classroom.service";

@Module({ imports: [IdentityModule], controllers: [ClassroomController], providers: [ClassroomService, AuthGuard], exports: [ClassroomService] })
export class ClassroomModule {}
