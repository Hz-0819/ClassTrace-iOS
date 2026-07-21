import { Body, Controller, Get, Headers, Param, Patch, Post, Query, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { AuthenticatedUser } from "../../common/auth/authenticated-user";
import { CurrentUser } from "../../common/auth/current-user.decorator";
import { Roles, RolesGuard } from "../../common/auth/roles.guard";
import { AdjustHoursDto, CancelSessionDto, ConfirmSessionDto, CreateSessionDto, GenerateSessionsDto, RechargeHoursDto, RescheduleDto, SessionFeedbackDto } from "./sessions.dto";
import { HourLedgerService } from "./hour-ledger.service";
import { SessionsService } from "./sessions.service";

@Controller()
@UseGuards(AuthGuard, RolesGuard)
export class SessionsController {
  constructor(private readonly sessions: SessionsService, private readonly ledger: HourLedgerService) {}
  @Get("sessions") list(@CurrentUser() u: AuthenticatedUser, @Query("from") from?: string, @Query("to") to?: string, @Query("classId") classId?: string) { return this.sessions.list(u.id, from, to, classId); }
  @Get("sessions/:id") detail(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.sessions.detail(u.id, id); }
  @Post("sessions") @Roles("TEACHER") create(@CurrentUser() u: AuthenticatedUser, @Body() d: CreateSessionDto) { return this.sessions.create(u.id, d); }
  @Post("sessions/generate") @Roles("TEACHER") generate(@CurrentUser() u: AuthenticatedUser, @Body() d: GenerateSessionsDto) { return this.sessions.generate(u.id, d); }
  @Patch("sessions/:id/reschedule") reschedule(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: RescheduleDto) { return this.sessions.reschedule(u.id, id, d); }
  @Post("sessions/:id/cancel") cancel(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: CancelSessionDto) { return this.sessions.cancel(u.id, id, d.reason); }
  @Post("sessions/:id/confirm") confirm(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: ConfirmSessionDto, @Headers("idempotency-key") key = "") { return this.sessions.confirm(u.id, id, d.attendances, key); }
  @Post("sessions/:id/undo") undo(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Headers("idempotency-key") key = "") { return this.sessions.undo(u.id, id, key); }
  @Patch("sessions/:id/feedback") feedback(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: SessionFeedbackDto) { return this.sessions.feedback(u.id, id, d); }
  @Get("hour-ledger") entries(@CurrentUser() u: AuthenticatedUser, @Query("memberId") memberId?: string, @Query("studentId") studentId?: string, @Query("classId") classId?: string) { return this.ledger.list(u.id, memberId, studentId, classId); }
  @Get("hour-ledger/low-balances") low(@CurrentUser() u: AuthenticatedUser, @Query("threshold") threshold?: string) { return this.ledger.lowBalances(u.id, threshold ? Number(threshold) : 2); }
  @Post("class-members/:id/hours/recharge") recharge(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: RechargeHoursDto, @Headers("idempotency-key") key = "") { return this.ledger.change(u.id, id, d.hours, "RECHARGE", d.remark ?? "课时充值", key); }
  @Post("class-members/:id/hours/adjust") adjust(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: AdjustHoursDto, @Headers("idempotency-key") key = "") { return this.ledger.change(u.id, id, d.amount, "ADJUST", d.reason, key); }
}
