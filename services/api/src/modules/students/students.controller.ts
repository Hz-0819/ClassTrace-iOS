import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { AuthenticatedUser } from "../../common/auth/authenticated-user";
import { CurrentUser } from "../../common/auth/current-user.decorator";
import { BindStudentDto, CreateStudentDto, UpdateStudentDto } from "./students.dto";
import { StudentsService } from "./students.service";

@Controller("students")
@UseGuards(AuthGuard)
export class StudentsController {
  constructor(private readonly students: StudentsService) {}
  @Get() list(@CurrentUser() user: AuthenticatedUser) { return this.students.list(user.id); }
  @Get(":id") detail(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string) { return this.students.detail(user.id, id); }
  @Post() create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateStudentDto) { return this.students.create(user.id, dto); }
  @Patch(":id") update(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string, @Body() dto: UpdateStudentDto) { return this.students.update(user.id, id, dto); }
  @Delete(":id") @HttpCode(204) remove(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string) { return this.students.remove(user.id, id); }
  @Post(":id/guardian-invites") invite(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string) { return this.students.createGuardianInvite(user.id, id); }
  @Post("bind") bind(@CurrentUser() user: AuthenticatedUser, @Body() dto: BindStudentDto) { return this.students.bindGuardian(user.id, dto.code, dto.relationship); }
  @Delete(":id/guardians/:guardianId") @HttpCode(204) unbind(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string, @Param("guardianId") guardianId: string) { return this.students.removeGuardian(user.id, id, guardianId); }
}
