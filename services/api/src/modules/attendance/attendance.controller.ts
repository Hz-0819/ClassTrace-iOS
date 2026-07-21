import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard"; import { AuthenticatedUser } from "../../common/auth/authenticated-user"; import { CurrentUser } from "../../common/auth/current-user.decorator";
import { AttendanceService } from "./attendance.service"; import { BatchAttendanceDto, RecordAttendanceDto, UpdateAttendanceDto } from "./attendance.dto";
@Controller("attendance") @UseGuards(AuthGuard)
export class AttendanceController { constructor(private readonly service: AttendanceService) {}
  @Post() record(@CurrentUser() u: AuthenticatedUser, @Body() d: RecordAttendanceDto) { return this.service.record(u.id, d); }
  @Post("batch") batch(@CurrentUser() u: AuthenticatedUser, @Body() d: BatchAttendanceDto) { return this.service.batch(u.id, d.records); }
  @Get("students/:id") student(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.service.listByStudent(u.id, id); }
  @Get("students/:id/stats") stats(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.service.stats(u.id, id); }
  @Get("classes/:id") classroom(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.service.listByClass(u.id, id); }
  @Patch(":id") update(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: UpdateAttendanceDto) { return this.service.update(u.id, id, d); }
  @Delete(":id") @HttpCode(204) remove(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.service.remove(u.id, id); }
}
