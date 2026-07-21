import { Injectable } from "@nestjs/common";
import { verify } from "argon2";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";
import { UpdateProfileDto } from "./users.dto";

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { roles: true, identities: { select: { provider: true, verifiedAt: true } } }
    });
    if (!user || user.status !== "ACTIVE") throw new DomainException("USER_NOT_FOUND", "用户不存在", 404);
    return user;
  }

  updateMe(userId: string, dto: UpdateProfileDto) {
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(dto.displayName !== undefined ? { displayName: dto.displayName.trim() } : {}),
        ...(dto.avatarUrl !== undefined ? { avatarUrl: dto.avatarUrl } : {})
      }
    });
  }

  async ensureRole(userId: string, role: "TEACHER" | "GUARDIAN") {
    await this.prisma.userRole.upsert({
      where: { userId_role: { userId, role } },
      create: { userId, role },
      update: {}
    });
    return this.getMe(userId);
  }

  async linkPhone(userId: string, phone: string, code: string) {
    const challenge = await this.prisma.otpChallenge.findFirst({ where: { phone, purpose: "bind", consumedAt: null }, orderBy: { createdAt: "desc" } });
    if (!challenge || challenge.expiresAt <= new Date() || challenge.attemptCount >= 5 || !await verify(challenge.codeHash, code)) throw new DomainException("OTP_INVALID", "验证码无效或已过期", 401);
    const occupied = await this.prisma.userIdentity.findUnique({ where: { provider_providerSubject: { provider: "PHONE", providerSubject: phone } } });
    if (occupied && occupied.userId !== userId) throw new DomainException("PHONE_ALREADY_LINKED", "该手机号已绑定其他账号", 409);
    await this.prisma.$transaction([
      this.prisma.otpChallenge.update({ where: { id: challenge.id }, data: { consumedAt: new Date() } }),
      this.prisma.userIdentity.upsert({ where: { provider_providerSubject: { provider: "PHONE", providerSubject: phone } }, create: { userId, provider: "PHONE", providerSubject: phone, verifiedAt: new Date() }, update: { verifiedAt: new Date() } })
    ]);
    return this.getMe(userId);
  }

  async exportAccount(userId: string) {
    const user = await this.getMe(userId);
    const [students, classes, sessions, ledger, homework, plans, mistakes, notifications, orders, feedback] = await Promise.all([
      this.prisma.student.findMany({ where: { OR: [{ createdByUserId: userId }, { guardians: { some: { guardianUserId: userId } } }] }, include: { guardians: true } }),
      this.prisma.classroom.findMany({ where: { OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] }, include: { members: true } }),
      this.prisma.classSession.findMany({ where: { classroom: { OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] } }, include: { attendances: true } }),
      this.prisma.hourLedgerEntry.findMany({ where: { OR: [{ operatorId: userId }, { student: { guardians: { some: { guardianUserId: userId } } } }] } }),
      this.prisma.homework.findMany({ where: { classroom: { OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] } }, include: { submissions: true } }),
      this.prisma.studyPlan.findMany({ where: { ownerUserId: userId }, include: { checkIns: true } }),
      this.prisma.mistake.findMany({ where: { ownerUserId: userId } }),
      this.prisma.notification.findMany({ where: { userId } }),
      this.prisma.courseOrder.findMany({ where: { OR: [{ guardianId: userId }, { teacherId: userId }] }, include: { payments: true, refunds: true, settlements: true } }),
      this.prisma.feedback.findMany({ where: { userId } })
    ]);
    return { exportedAt: new Date(), user, students, classes, sessions, ledger, homework, plans, mistakes, notifications, orders, feedback };
  }

  async deleteAccount(userId: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.authSession.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } }),
      this.prisma.deviceToken.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } }),
      this.prisma.user.update({
        where: { id: userId },
        data: { status: "DELETED", deletedAt: new Date(), displayName: "已注销用户", avatarUrl: null }
      })
    ]);
  }
}
