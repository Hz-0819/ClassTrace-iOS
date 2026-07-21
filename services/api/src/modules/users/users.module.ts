import { Module } from "@nestjs/common";
import { IdentityModule } from "../identity/identity.module";
import { AuthGuard } from "../../common/auth/auth.guard";
import { UsersController } from "./users.controller";
import { UsersService } from "./users.service";

@Module({
  imports: [IdentityModule],
  controllers: [UsersController],
  providers: [UsersService, AuthGuard],
  exports: [UsersService]
})
export class UsersModule {}
