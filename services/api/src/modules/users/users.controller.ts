import { Body, Controller, Delete, Get, HttpCode, Patch, Post, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { AuthenticatedUser } from "../../common/auth/authenticated-user";
import { CurrentUser } from "../../common/auth/current-user.decorator";
import { LinkPhoneDto, SwitchRoleDto, UpdateProfileDto } from "./users.dto";
import { UsersService } from "./users.service";

@Controller("me")
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  getMe(@CurrentUser() user: AuthenticatedUser) { return this.users.getMe(user.id); }

  @Get("export")
  exportMe(@CurrentUser() user: AuthenticatedUser) { return this.users.exportAccount(user.id); }

  @Patch()
  updateMe(@CurrentUser() user: AuthenticatedUser, @Body() dto: UpdateProfileDto) {
    return this.users.updateMe(user.id, dto);
  }

  @Post("roles")
  ensureRole(@CurrentUser() user: AuthenticatedUser, @Body() dto: SwitchRoleDto) {
    return this.users.ensureRole(user.id, dto.role);
  }

  @Post("phone")
  linkPhone(@CurrentUser() user: AuthenticatedUser, @Body() dto: LinkPhoneDto) { return this.users.linkPhone(user.id, dto.phone, dto.code); }

  @Delete()
  @HttpCode(204)
  deleteMe(@CurrentUser() user: AuthenticatedUser) { return this.users.deleteAccount(user.id); }
}
