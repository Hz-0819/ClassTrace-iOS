import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, Query, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { AuthenticatedUser } from "../../common/auth/authenticated-user";
import { CurrentUser } from "../../common/auth/current-user.decorator";
import { Roles, RolesGuard } from "../../common/auth/roles.guard";
import { CreateAnnouncementDto, ManualCourseDto, NotificationPreferenceDto, RegisterDeviceDto, ReplyFeedbackDto, SubmitFeedbackDto } from "./engagement.dto";
import { EngagementService } from "./engagement.service";
import { NotificationWorkerService } from "./notification-worker.service";

@Controller()
@UseGuards(AuthGuard, RolesGuard)
export class EngagementController {
  constructor(private readonly service: EngagementService, private readonly worker: NotificationWorkerService) {}
  @Get("home") home(@CurrentUser() u: AuthenticatedUser) { return this.service.home(u.id); }
  @Get("business/overview") @Roles("TEACHER") business(@CurrentUser() u: AuthenticatedUser, @Query("from") from?: string, @Query("to") to?: string) { return this.service.business(u.id, from, to); }
  @Get("notifications") notifications(@CurrentUser() u: AuthenticatedUser) { return this.service.notifications(u.id); }
  @Get("notifications/unread") unread(@CurrentUser() u: AuthenticatedUser) { return this.service.unread(u.id); }
  @Post("notifications/:id/read") markRead(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.service.markRead(u.id, id); }
  @Post("notifications/read-all") markAllRead(@CurrentUser() u: AuthenticatedUser) { return this.service.markAllRead(u.id); }
  @Get("notification-preferences") preferences(@CurrentUser() u: AuthenticatedUser) { return this.service.preferences(u.id); }
  @Post("notification-preferences") preference(@CurrentUser() u: AuthenticatedUser, @Body() d: NotificationPreferenceDto) { return this.service.setPreference(u.id, d); }
  @Post("devices") device(@CurrentUser() u: AuthenticatedUser, @Body() d: RegisterDeviceDto) { return this.service.registerDevice(u.id, d.token, d.environment); }
  @Delete("devices/:tokenHash") @HttpCode(204) revokeDevice(@CurrentUser() u: AuthenticatedUser, @Param("tokenHash") tokenHash: string) { return this.service.revokeDevice(u.id, tokenHash); }
  @Get("announcements") announcements(@CurrentUser() u: AuthenticatedUser) { return this.service.announcements(u.id); }
  @Get("announcements/:id") announcement(@Param("id") id: string) { return this.service.announcement(id); }
  @Post("announcements") @Roles("ADMIN") createAnnouncement(@CurrentUser() u: AuthenticatedUser, @Body() d: CreateAnnouncementDto) { return this.service.createAnnouncement(u.id, d); }
  @Get("feedback") feedback(@CurrentUser() u: AuthenticatedUser) { return this.service.feedback(u.id); }
  @Get("admin/feedback") @Roles("ADMIN") allFeedback() { return this.service.allFeedback(); }
  @Post("feedback") submitFeedback(@CurrentUser() u: AuthenticatedUser, @Body() d: SubmitFeedbackDto) { return this.service.submitFeedback(u.id, d); }
  @Patch("feedback/:id/reply") @Roles("ADMIN") replyFeedback(@Param("id") id: string, @Body() d: ReplyFeedbackDto) { return this.service.replyFeedback(id, d); }
  @Get("manual-courses") manual(@CurrentUser() u: AuthenticatedUser) { return this.service.manualCourses(u.id); }
  @Post("manual-courses") createManual(@CurrentUser() u: AuthenticatedUser, @Body() d: ManualCourseDto) { return this.service.createManualCourse(u.id, d); }
  @Patch("manual-courses/:id") updateManual(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: ManualCourseDto) { return this.service.updateManualCourse(u.id, id, d); }
  @Delete("manual-courses/:id") @HttpCode(204) deleteManual(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.service.deleteManualCourse(u.id, id); }
  @Post("internal/jobs/notifications/materialize") @Roles("ADMIN") materialize() { return this.worker.materialize(); }
  @Post("internal/jobs/notifications/deliver") @Roles("ADMIN") deliver() { return this.worker.deliver(); }
}
