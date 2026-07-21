import { Module } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { IdentityModule } from "../identity/identity.module";
import { StudentsController } from "./students.controller";
import { StudentsService } from "./students.service";

@Module({ imports: [IdentityModule], controllers: [StudentsController], providers: [StudentsService, AuthGuard], exports: [StudentsService] })
export class StudentsModule {}
