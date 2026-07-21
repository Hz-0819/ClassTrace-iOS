import { Injectable } from "@nestjs/common";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";
import { AttendanceInputDto, CreateSessionDto, GenerateSessionsDto, RescheduleDto, SessionFeedbackDto } from "./sessions.dto";

@Injectable()
export class SessionsService {
  constructor(private readonly prisma: PrismaService) {}

  private async teacherClass(userId: string, classId: string) {
    const item = await this.prisma.classroom.findFirst({ where: { id: classId, teacherId: userId } });
    if (!item) throw new DomainException("FORBIDDEN", "只有班级教师可以执行此操作", 403);
    return item;
  }

  list(userId: string, from?: string, to?: string, classId?: string) {
    return this.prisma.classSession.findMany({
      where: {
        ...(classId ? { classId } : {}),
        ...(from || to ? { startsAt: { ...(from ? { gte: new Date(from) } : {}), ...(to ? { lte: new Date(to) } : {}) } } : {}),
        classroom: { OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] }
      },
      include: { classroom: true, attendances: { include: { student: true } }, feedback: true },
      orderBy: { startsAt: "asc" }
    });
  }

  async detail(userId: string, id: string) {
    const item = await this.prisma.classSession.findFirst({
      where: { id, classroom: { OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] } },
      include: { classroom: true, attendances: { include: { student: true } }, feedback: true, hourEntries: true }
    });
    if (!item) throw new DomainException("SESSION_NOT_FOUND", "课节不存在或无权查看", 404);
    return item;
  }

  async create(userId: string, dto: CreateSessionDto) {
    await this.teacherClass(userId, dto.classId);
    const startsAt = new Date(dto.startsAt), endsAt = new Date(dto.endsAt);
    if (endsAt <= startsAt) throw new DomainException("INVALID_TIME_RANGE", "结束时间必须晚于开始时间", 422);
    return this.prisma.classSession.create({ data: { classId: dto.classId, startsAt, endsAt, plannedHours: dto.plannedHours ?? (endsAt.getTime() - startsAt.getTime()) / 3_600_000, source: "MANUAL" } });
  }

  async generate(userId: string, dto: GenerateSessionsDto) {
    await this.teacherClass(userId, dto.classId);
    const from = new Date(dto.from), to = new Date(dto.to);
    if (to < from || to.getTime() - from.getTime() > 370 * 86400_000) throw new DomainException("INVALID_DATE_RANGE", "排课范围无效或超过一年", 422);
    const match = /^(\d{2}):(\d{2})$/.exec(dto.startTime);
    if (!match) throw new DomainException("INVALID_START_TIME", "上课时间格式应为 HH:mm", 422);
    const rows: { classId: string; startsAt: Date; endsAt: Date; plannedHours: number; source: "SCHEDULE" }[] = [];
    for (let cursor = new Date(from); cursor <= to; cursor = new Date(cursor.getTime() + 86400_000)) {
      const weekday = cursor.getUTCDay() || 7;
      if (!dto.weekdays.includes(weekday)) continue;
      const offset = dto.timezoneOffsetMinutes ?? 480;
      const startsAt = new Date(Date.UTC(cursor.getUTCFullYear(), cursor.getUTCMonth(), cursor.getUTCDate(), Number(match[1]), Number(match[2])) - offset * 60_000);
      rows.push({ classId: dto.classId, startsAt, endsAt: new Date(startsAt.getTime() + dto.durationMinutes * 60_000), plannedHours: dto.durationMinutes / 60, source: "SCHEDULE" });
    }
    const result = await this.prisma.classSession.createMany({ data: rows, skipDuplicates: true });
    return { created: result.count, requested: rows.length };
  }

  async reschedule(userId: string, id: string, dto: RescheduleDto) {
    const session = await this.prisma.classSession.findUnique({ where: { id }, include: { classroom: true } });
    if (!session || session.classroom.teacherId !== userId) throw new DomainException("SESSION_NOT_FOUND", "课节不存在", 404);
    if (session.status !== "SCHEDULED") throw new DomainException("INVALID_SESSION_STATE", "只有待上课课节可以调课", 409);
    const startsAt = new Date(dto.startsAt), endsAt = new Date(dto.endsAt);
    if (endsAt <= startsAt) throw new DomainException("INVALID_TIME_RANGE", "结束时间必须晚于开始时间", 422);
    return this.prisma.classSession.update({ where: { id }, data: { startsAt, endsAt, status: "SCHEDULED", version: { increment: 1 } } });
  }

  async cancel(userId: string, id: string, reason?: string) {
    const session = await this.prisma.classSession.findUnique({ where: { id }, include: { classroom: true } });
    if (!session || session.classroom.teacherId !== userId) throw new DomainException("SESSION_NOT_FOUND", "课节不存在", 404);
    if (session.status === "COMPLETED") throw new DomainException("INVALID_SESSION_STATE", "已完成课节需先撤销确认", 409);
    return this.prisma.classSession.update({ where: { id }, data: { status: "CANCELLED", cancelReason: reason, version: { increment: 1 } } });
  }

  async confirm(userId: string, id: string, attendances: AttendanceInputDto[], idempotencyKey: string) {
    if (!idempotencyKey) throw new DomainException("IDEMPOTENCY_KEY_REQUIRED", "确认上课必须提供幂等键", 400);
    return this.prisma.$transaction(async (tx) => {
      const session = await tx.classSession.findUnique({ where: { id }, include: { classroom: true, attendances: true } });
      if (!session || session.classroom.teacherId !== userId) throw new DomainException("SESSION_NOT_FOUND", "课节不存在", 404);
      if (session.status === "COMPLETED") return tx.classSession.findUniqueOrThrow({ where: { id }, include: { attendances: true, hourEntries: true } });
      if (session.status !== "SCHEDULED") throw new DomainException("INVALID_SESSION_STATE", "当前课节状态不可确认", 409);
      if (!attendances.length) throw new DomainException("ATTENDANCE_REQUIRED", "至少需要一条考勤记录", 422);

      for (const attendance of attendances) {
        const member = await tx.classMember.findUnique({ where: { classId_studentId: { classId: session.classId, studentId: attendance.studentId } } });
        if (!member || member.status !== "APPROVED") throw new DomainException("MEMBER_NOT_FOUND", "考勤学生不在当前班级", 422);
        let status = attendance.status;
        let deductHours = 0;
        if (status === "PRESENT" && session.classroom.billingMode === "PREPAID") {
          deductHours = attendance.deductHours ?? Number(session.plannedHours);
          const updated = await tx.classMember.updateMany({
            where: { id: member.id, remainingHours: { gte: deductHours } },
            data: { remainingHours: { decrement: deductHours }, consumedHours: { increment: deductHours } }
          });
          if (!updated.count) { status = "INSUFFICIENT" as typeof status; deductHours = 0; }
          else {
            const fresh = await tx.classMember.findUniqueOrThrow({ where: { id: member.id } });
            await tx.hourLedgerEntry.create({ data: {
              memberId: member.id, studentId: attendance.studentId, sessionId: id, operatorId: userId,
              type: "CONSUME", delta: -deductHours, balanceAfter: fresh.remainingHours,
              idempotencyKey: `${idempotencyKey}:${member.id}`, remark: attendance.remark ?? "上课消耗"
            } });
          }
        } else if (status === "PRESENT") {
          await tx.hourLedgerEntry.create({ data: {
            memberId: member.id, studentId: attendance.studentId, sessionId: id, operatorId: userId,
            type: "SESSION", delta: 0, balanceAfter: member.remainingHours,
            idempotencyKey: `${idempotencyKey}:${member.id}`, remark: attendance.remark ?? "现结上课记录"
          } });
        }
        await tx.sessionAttendance.upsert({
          where: { sessionId_studentId: { sessionId: id, studentId: attendance.studentId } },
          create: { sessionId: id, studentId: attendance.studentId, status, deductHours, remark: attendance.remark },
          update: { status, deductHours, remark: attendance.remark }
        });
      }
      const changed = await tx.classSession.updateMany({ where: { id, status: "SCHEDULED" }, data: { status: "COMPLETED", completedAt: new Date(), version: { increment: 1 } } });
      if (!changed.count) throw new DomainException("SESSION_ALREADY_CHANGED", "课节已被其他操作更新", 409);
      await tx.outboxEvent.create({ data: { aggregateType: "ClassSession", aggregateId: id, eventType: "SessionCompleted", payload: { classId: session.classId } } });
      return tx.classSession.findUniqueOrThrow({ where: { id }, include: { attendances: true, hourEntries: true } });
    }, { isolationLevel: "Serializable" });
  }

  async undo(userId: string, id: string, idempotencyKey: string) {
    if (!idempotencyKey) throw new DomainException("IDEMPOTENCY_KEY_REQUIRED", "撤销确认必须提供幂等键", 400);
    return this.prisma.$transaction(async (tx) => {
      const session = await tx.classSession.findUnique({ where: { id }, include: { classroom: true, hourEntries: true } });
      if (!session || session.classroom.teacherId !== userId) throw new DomainException("SESSION_NOT_FOUND", "课节不存在", 404);
      if (session.status === "SCHEDULED") return session;
      if (session.status !== "COMPLETED") throw new DomainException("INVALID_SESSION_STATE", "只有已确认课节可以撤销", 409);
      for (const entry of session.hourEntries.filter((item) => item.type === "CONSUME")) {
        const member = await tx.classMember.update({ where: { id: entry.memberId }, data: { remainingHours: { increment: entry.delta.negated() }, consumedHours: { decrement: entry.delta.negated() } } });
        await tx.hourLedgerEntry.create({ data: {
          memberId: entry.memberId, studentId: entry.studentId, sessionId: id, operatorId: userId,
          type: "UNDO", delta: entry.delta.negated(), balanceAfter: member.remainingHours,
          reversalOfId: entry.id, idempotencyKey: `${idempotencyKey}:${entry.id}`, remark: "撤销上课确认"
        } });
      }
      await tx.sessionAttendance.updateMany({ where: { sessionId: id }, data: { status: "SCHEDULED", deductHours: 0 } });
      await tx.classSession.update({ where: { id }, data: { status: "SCHEDULED", completedAt: null, version: { increment: 1 } } });
      await tx.outboxEvent.create({ data: { aggregateType: "ClassSession", aggregateId: id, eventType: "SessionCompletionUndone", payload: { classId: session.classId } } });
      return tx.classSession.findUniqueOrThrow({ where: { id }, include: { attendances: true, hourEntries: true } });
    }, { isolationLevel: "Serializable" });
  }

  async feedback(userId: string, id: string, dto: SessionFeedbackDto) {
    const session = await this.prisma.classSession.findUnique({ where: { id }, include: { classroom: true } });
    if (!session || session.classroom.teacherId !== userId) throw new DomainException("SESSION_NOT_FOUND", "课节不存在", 404);
    return this.prisma.sessionFeedback.upsert({
      where: { sessionId: id }, create: { sessionId: id, summary: dto.summary, performance: dto.performance, homeworkNote: dto.homeworkNote, attachments: dto.attachments as never },
      update: { summary: dto.summary, performance: dto.performance, homeworkNote: dto.homeworkNote, attachments: dto.attachments as never }
    });
  }
}
