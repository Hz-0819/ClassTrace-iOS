import { Injectable } from "@nestjs/common";
import { createCipheriv, createHash, randomBytes } from "node:crypto";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";
import { CreateAnnouncementDto, ManualCourseDto, NotificationPreferenceDto, ReplyFeedbackDto, SubmitFeedbackDto } from "./engagement.dto";

@Injectable()
export class EngagementService {
  constructor(private readonly prisma: PrismaService) {}
  private encrypt(value: string): string {
    const keyMaterial = process.env.DEVICE_TOKEN_KEY ?? (process.env.NODE_ENV === "production" ? "" : "classtrace-device-token-development-key");
    if (!keyMaterial) throw new Error("DEVICE_TOKEN_KEY is required");
    const key = createHash("sha256").update(keyMaterial).digest();
    const iv = randomBytes(12), cipher = createCipheriv("aes-256-gcm", key, iv);
    const encrypted = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), encrypted]).toString("base64");
  }
  registerDevice(userId: string, token: string, environment: string) {
    const tokenHash = createHash("sha256").update(token).digest("hex");
    return this.prisma.deviceToken.upsert({
      where: { tokenHash }, create: { userId, platform: "ios", tokenHash, tokenCiphertext: this.encrypt(token), environment },
      update: { userId, tokenCiphertext: this.encrypt(token), environment, revokedAt: null, lastSeenAt: new Date() }
    });
  }
  revokeDevice(userId: string, tokenHash: string) { return this.prisma.deviceToken.updateMany({ where: { userId, tokenHash }, data: { revokedAt: new Date() } }); }
  notifications(userId: string) { return this.prisma.notification.findMany({ where: { userId }, include: { deliveries: true }, orderBy: { createdAt: "desc" }, take: 100 }); }
  async unread(userId: string) { return { count: await this.prisma.notification.count({ where: { userId, readAt: null } }) }; }
  async markRead(userId: string, id: string) { const result = await this.prisma.notification.updateMany({ where: { id, userId, readAt: null }, data: { readAt: new Date() } }); if (!result.count && !await this.prisma.notification.count({ where: { id, userId } })) throw new DomainException("NOTIFICATION_NOT_FOUND", "通知不存在", 404); return { count: result.count }; }
  markAllRead(userId: string) { return this.prisma.notification.updateMany({ where: { userId, readAt: null }, data: { readAt: new Date() } }); }
  preferences(userId: string) { return this.prisma.notificationPreference.findMany({ where: { userId } }); }
  setPreference(userId: string, dto: NotificationPreferenceDto) { return this.prisma.notificationPreference.upsert({ where: { userId_eventType_channel: { userId, eventType: dto.eventType, channel: dto.channel } }, create: { userId, ...dto }, update: { enabled: dto.enabled } }); }

  announcements(userId: string) {
    return this.prisma.announcement.findMany({
      where: { publishedAt: { lte: new Date() }, OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }] },
      orderBy: { publishedAt: "desc" }, take: 50
    }).then(async (items) => {
      const roles = (await this.prisma.userRole.findMany({ where: { userId } })).map((item) => item.role);
      return items.filter((item) => !item.audience || (item.audience as string[]).some((role) => roles.includes(role as never)));
    });
  }
  async announcement(id: string) { const item = await this.prisma.announcement.findUnique({ where: { id } }); if (!item) throw new DomainException("ANNOUNCEMENT_NOT_FOUND", "公告不存在", 404); return item; }
  createAnnouncement(userId: string, dto: CreateAnnouncementDto) { return this.prisma.announcement.create({ data: { authorId: userId, title: dto.title, content: dto.content, audience: dto.audience as never, publishedAt: dto.publishedAt ? new Date(dto.publishedAt) : new Date(), expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined } }); }

  feedback(userId: string) { return this.prisma.feedback.findMany({ where: { userId }, orderBy: { createdAt: "desc" } }); }
  allFeedback() { return this.prisma.feedback.findMany({ include: { user: { select: { id: true, displayName: true } } }, orderBy: { createdAt: "desc" }, take: 200 }); }
  submitFeedback(userId: string, dto: SubmitFeedbackDto) { return this.prisma.feedback.create({ data: { userId, category: dto.category, content: dto.content, contact: dto.contact, attachments: dto.attachments as never } }); }
  replyFeedback(id: string, dto: ReplyFeedbackDto) { return this.prisma.feedback.update({ where: { id }, data: { reply: dto.reply, status: dto.status ?? "RESOLVED" } }); }

  manualCourses(userId: string) { return this.prisma.manualCourse.findMany({ where: { userId }, orderBy: { startsAt: "asc" } }); }
  createManualCourse(userId: string, dto: ManualCourseDto) { return this.prisma.manualCourse.create({ data: { userId, name: dto.name, startsAt: new Date(dto.startsAt), endsAt: new Date(dto.endsAt), location: dto.location, note: dto.note } }); }
  async updateManualCourse(userId: string, id: string, dto: ManualCourseDto) { const result = await this.prisma.manualCourse.updateMany({ where: { id, userId }, data: { name: dto.name, startsAt: new Date(dto.startsAt), endsAt: new Date(dto.endsAt), location: dto.location, note: dto.note } }); if (!result.count) throw new DomainException("COURSE_NOT_FOUND", "日程不存在", 404); return this.prisma.manualCourse.findUniqueOrThrow({ where: { id } }); }
  async deleteManualCourse(userId: string, id: string) { const result = await this.prisma.manualCourse.deleteMany({ where: { id, userId } }); if (!result.count) throw new DomainException("COURSE_NOT_FOUND", "日程不存在", 404); }

  async home(userId: string) {
    const now = new Date(), end = new Date(now); end.setHours(23, 59, 59, 999);
    const [sessions, unread, announcements, lowBalances, homework] = await Promise.all([
      this.prisma.classSession.findMany({ where: { startsAt: { gte: now, lte: end }, classroom: { OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] } }, include: { classroom: true }, orderBy: { startsAt: "asc" } }),
      this.prisma.notification.count({ where: { userId, readAt: null } }),
      this.announcements(userId),
      this.prisma.classMember.findMany({ where: { classroom: { teacherId: userId }, status: "APPROVED", remainingHours: { lte: 2 } }, include: { student: true, classroom: true }, take: 20 }),
      this.prisma.homework.findMany({ where: { status: "PUBLISHED", classroom: { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } } }, orderBy: { dueAt: "asc" }, take: 20 })
    ]);
    return { sessions, unreadNotificationCount: unread, announcements: announcements.slice(0, 5), lowBalances, homework };
  }

  async business(userId: string, from?: string, to?: string) {
    const range = { ...(from ? { gte: new Date(from) } : {}), ...(to ? { lte: new Date(to) } : {}) };
    const [classes, sessions, ledger, orders] = await Promise.all([
      this.prisma.classroom.count({ where: { teacherId: userId, status: { in: ["ACTIVE", "PAUSED"] } } }),
      this.prisma.classSession.count({ where: { classroom: { teacherId: userId }, status: "COMPLETED", ...(from || to ? { completedAt: range } : {}) } }),
      this.prisma.hourLedgerEntry.aggregate({ where: { member: { classroom: { teacherId: userId } }, type: "CONSUME", ...(from || to ? { createdAt: range } : {}) }, _sum: { delta: true } }),
      this.prisma.courseOrder.aggregate({ where: { teacherId: userId, status: { in: ["PAID", "ACTIVE", "COMPLETED"] }, ...(from || to ? { createdAt: range } : {}) }, _sum: { totalAmountCents: true }, _count: true })
    ]);
    return { activeClassCount: classes, completedSessionCount: sessions, consumedHours: Math.abs(Number(ledger._sum.delta ?? 0)), orderCount: orders._count, recordedRevenueCents: orders._sum.totalAmountCents ?? 0 };
  }
}
