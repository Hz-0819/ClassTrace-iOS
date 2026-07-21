import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { AuthenticatedUser } from "../../common/auth/authenticated-user";
import { CurrentUser } from "../../common/auth/current-user.decorator";
import { Roles, RolesGuard } from "../../common/auth/roles.guard";
import { AddMemberDto, CreateClassDto, CreateCourseDto, JoinClassDto, UpdateClassDto, UpdateCourseDto, UpdateMemberDto } from "./classroom.dto";
import { ClassroomService } from "./classroom.service";

@UseGuards(AuthGuard, RolesGuard)
@Controller()
export class ClassroomController {
  constructor(private readonly service: ClassroomService) {}
  @Get("courses") courses(@CurrentUser() u: AuthenticatedUser) { return this.service.listCourses(u.id); }
  @Post("courses") @Roles("TEACHER") createCourse(@CurrentUser() u: AuthenticatedUser, @Body() d: CreateCourseDto) { return this.service.createCourse(u.id, d); }
  @Patch("courses/:id") updateCourse(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: UpdateCourseDto) { return this.service.updateCourse(u.id, id, d); }
  @Delete("courses/:id") @HttpCode(204) deleteCourse(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.service.deleteCourse(u.id, id); }
  @Get("classes") classes(@CurrentUser() u: AuthenticatedUser) { return this.service.listClasses(u.id); }
  @Get("classes/:id") detail(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.service.classDetail(u.id, id); }
  @Post("classes") @Roles("TEACHER") createClass(@CurrentUser() u: AuthenticatedUser, @Body() d: CreateClassDto) { return this.service.createClass(u.id, d); }
  @Patch("classes/:id") updateClass(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: UpdateClassDto) { return this.service.updateClass(u.id, id, d); }
  @Delete("classes/:id") @HttpCode(204) deleteClass(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.service.deleteClass(u.id, id); }
  @Post("classes/join") join(@CurrentUser() u: AuthenticatedUser, @Body() d: JoinClassDto) { return this.service.joinClass(u.id, d); }
  @Post("classes/:id/members") add(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: AddMemberDto) { return this.service.addMember(u.id, id, d); }
  @Patch("classes/:id/members/:memberId") updateMember(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Param("memberId") memberId: string, @Body() d: UpdateMemberDto) { return this.service.updateMember(u.id, id, memberId, d); }
  @Delete("classes/:id/members/:memberId") @HttpCode(204) removeMember(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Param("memberId") memberId: string) { return this.service.removeMember(u.id, id, memberId); }
}
