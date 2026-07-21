import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { PrismaService } from "../../database/prisma.service";
import { ApnsService } from "./apns.service";

@Injectable()
export class NotificationWorkerService implements OnModuleInit, OnModuleDestroy {
  private timer?: NodeJS.Timeout;
  private running = false;
  private readonly logger = new Logger(NotificationWorkerService.name);
  constructor(private readonly prisma: PrismaService, private readonly apns: ApnsService) {}
  onModuleInit() {
    if (process.env.NOTIFICATION_WORKER_ENABLED === "false") return;
    this.timer = setInterval(() => void this.tick(), Number(process.env.NOTIFICATION_WORKER_INTERVAL_MS ?? 15000));
    this.timer.unref();
  }
  onModuleDestroy() { if (this.timer) clearInterval(this.timer); }
  private async tick() {
    if (this.running) return;
    this.running = true;
    try { await this.scheduleReminders(); await this.materialize(); await this.deliver(); }
    catch (error) { this.logger.error("Notification worker tick failed; it will retry", error instanceof Error ? error.stack : String(error)); }
    finally { this.running = false; }
  }
  private async recipients(event: { aggregateType: string; aggregateId: string; eventType: string; payload: unknown }): Promise<string[]> {
    const payload = event.payload as Record<string, string>;
    const direct = [payload.guardianId, payload.teacherId, payload.userId].filter(Boolean);
    if (direct.length) return [...new Set(direct)];
    const classId = payload.classId;
    if (classId) {
      const classroom = await this.prisma.classroom.findUnique({ where: { id: classId }, include: { members: { include: { student: { include: { guardians: true } } } } } });
      return [...new Set([classroom?.teacherId, ...(classroom?.members.flatMap((member) => member.student.guardians.map((item) => item.guardianUserId)) ?? [])].filter((id): id is string => Boolean(id)))];
    }
    if (event.aggregateType === "ClassMember") {
      const member = await this.prisma.classMember.findUnique({ where: { id: event.aggregateId }, include: { student: { include: { guardians: true } } } });
      return member?.student.guardians.map((item) => item.guardianUserId) ?? [];
    }
    return [];
  }
  private copy(eventType: string): { title: string; body: string } {
    const table: Record<string, { title: string; body: string }> = {
      SessionCompleted: { title: "课程已完成", body: "教师已确认本次上课，请查看考勤、课时和课后反馈。" },
      SessionCompletionUndone: { title: "上课确认已撤销", body: "本次课程确认已撤销，相关课时已经回退。" },
      HomeworkPublished: { title: "新作业", body: "教师发布了新作业，请及时查看并提交。" },
      HomeworkReviewed: { title: "作业已批改", body: "教师已完成作业批改，请查看评语。" },
      MaterialUploaded: { title: "新教学资料", body: "教师上传了新的教学资料。" },
      HourBalanceChanged: { title: "课时余额变更", body: "学生课时余额发生变化，请查看课时流水。" },
      OrderPaid: { title: "收款记录已确认", body: "订单收款和购课课时已经登记。" },
      RefundRequested: { title: "收到退款申请", body: "有一笔订单退款申请等待协商处理。" }
    };
    return table[eventType] ?? { title: "课迹提醒", body: "您有一条新的业务动态。" };
  }
  async scheduleReminders() {
    const now = new Date(), from = now, to = new Date(now.getTime() + 65 * 60_000);
    const sessions = await this.prisma.classSession.findMany({ where: { status: "SCHEDULED", startsAt: { gte: from, lte: to } }, include: { classroom: { include: { members: { where: { status: "APPROVED" }, include: { student: { include: { guardians: true } } } } } } } });
    let created = 0;
    for (const session of sessions) {
      const recipients = [...new Set([session.classroom.teacherId, ...session.classroom.members.flatMap((member) => member.student.guardians.map((guardian) => guardian.guardianUserId))])];
      for (const userId of recipients) {
        const notification = await this.prisma.notification.upsert({ where: { dedupeKey: `session-reminder:${session.id}:${userId}` }, create: { userId, type: "SESSION_REMINDER", title: "一小时后上课", body: `${session.classroom.name} 将在一小时后开始，请提前做好准备。`, resourceType: "ClassSession", resourceId: session.id, dedupeKey: `session-reminder:${session.id}:${userId}` }, update: {} });
        const preference = await this.prisma.notificationPreference.findUnique({ where: { userId_eventType_channel: { userId, eventType: "SESSION_REMINDER", channel: "APNS" } } });
        if (preference?.enabled !== false) await this.prisma.notificationDelivery.upsert({ where: { notificationId_channel: { notificationId: notification.id, channel: "APNS" } }, create: { notificationId: notification.id, channel: "APNS" }, update: {} });
        created++;
      }
    }
    return { sessions: sessions.length, notifications: created };
  }
  async materialize(limit = 50) {
    const events = await this.prisma.outboxEvent.findMany({ where: { processedAt: null }, orderBy: { occurredAt: "asc" }, take: limit });
    let created = 0;
    for (const event of events) {
      const recipients = await this.recipients(event);
      const copy = this.copy(event.eventType);
      for (const userId of recipients) {
        const notification = await this.prisma.notification.upsert({
          where: { dedupeKey: `${event.id}:${userId}` },
          create: { userId, type: event.eventType, title: copy.title, body: copy.body, resourceType: event.aggregateType, resourceId: event.aggregateId, dedupeKey: `${event.id}:${userId}` }, update: {}
        });
        const disabled = await this.prisma.notificationPreference.findUnique({ where: { userId_eventType_channel: { userId, eventType: event.eventType, channel: "APNS" } } });
        if (disabled?.enabled !== false) await this.prisma.notificationDelivery.upsert({ where: { notificationId_channel: { notificationId: notification.id, channel: "APNS" } }, create: { notificationId: notification.id, channel: "APNS" }, update: {} });
        created++;
      }
      await this.prisma.outboxEvent.update({ where: { id: event.id }, data: { processedAt: new Date() } });
    }
    return { events: events.length, notifications: created };
  }
  async deliver(limit = 100) {
    const deliveries = await this.prisma.notificationDelivery.findMany({ where: { channel: "APNS", status: { in: ["PENDING", "FAILED"] }, OR: [{ nextAttemptAt: null }, { nextAttemptAt: { lte: new Date() } }] }, include: { notification: { include: { user: { include: { deviceTokens: { where: { revokedAt: null } } } } } } }, take: limit });
    let sent = 0;
    for (const delivery of deliveries) {
      const devices = delivery.notification.user.deviceTokens;
      if (!devices.length) { await this.prisma.notificationDelivery.update({ where: { id: delivery.id }, data: { status: "SKIPPED", lastErrorCode: "NO_DEVICE" } }); continue; }
      try {
        for (const device of devices) await this.apns.send(device.tokenCiphertext, device.environment, delivery.notification.title, delivery.notification.body, { notificationId: delivery.notification.id, resourceType: delivery.notification.resourceType ?? "", resourceId: delivery.notification.resourceId ?? "" });
        await this.prisma.notificationDelivery.update({ where: { id: delivery.id }, data: { status: "SENT", sentAt: new Date(), attemptCount: { increment: 1 }, lastErrorCode: null } }); sent++;
      } catch (error) {
        const attempts = delivery.attemptCount + 1, delay = Math.min(3600, 2 ** attempts * 30);
        await this.prisma.notificationDelivery.update({ where: { id: delivery.id }, data: { status: "FAILED", attemptCount: attempts, lastErrorCode: error instanceof Error ? error.message.slice(0, 200) : "UNKNOWN", nextAttemptAt: new Date(Date.now() + delay * 1000) } });
      }
    }
    return { attempted: deliveries.length, sent };
  }
}
