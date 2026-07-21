import { Injectable } from "@nestjs/common";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";

@Injectable()
export class HourLedgerService {
  constructor(private readonly prisma: PrismaService) {}

  private async teacherMember(userId: string, memberId: string) {
    const member = await this.prisma.classMember.findFirst({ where: { id: memberId, classroom: { teacherId: userId } }, include: { classroom: true, student: true } });
    if (!member) throw new DomainException("MEMBER_NOT_FOUND", "班级成员不存在或无权操作", 404);
    return member;
  }

  async change(userId: string, memberId: string, amount: number, type: "RECHARGE" | "ADJUST" | "REFUND", reason: string, idempotencyKey: string) {
    if (!idempotencyKey) throw new DomainException("IDEMPOTENCY_KEY_REQUIRED", "课时变更必须提供幂等键", 400);
    await this.teacherMember(userId, memberId);
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.hourLedgerEntry.findUnique({ where: { idempotencyKey } });
      if (existing) return existing;
      const current = await tx.classMember.findUniqueOrThrow({ where: { id: memberId } });
      const next = Number(current.remainingHours) + amount;
      if (next < 0) throw new DomainException("INSUFFICIENT_HOURS", "剩余课时不足", 409);
      const member = await tx.classMember.update({ where: { id: memberId }, data: {
        remainingHours: next, totalHours: type === "RECHARGE" ? { increment: amount } : undefined
      } });
      const entry = await tx.hourLedgerEntry.create({ data: {
        memberId, studentId: member.studentId, operatorId: userId, type, delta: amount,
        balanceAfter: member.remainingHours, idempotencyKey, remark: reason
      } });
      await tx.outboxEvent.create({ data: { aggregateType: "ClassMember", aggregateId: memberId, eventType: "HourBalanceChanged", payload: { amount, balance: String(member.remainingHours), type } } });
      return entry;
    }, { isolationLevel: "Serializable" });
  }

  async list(userId: string, memberId?: string, studentId?: string, classId?: string) {
    return this.prisma.hourLedgerEntry.findMany({
      where: {
        ...(memberId ? { memberId } : {}), ...(studentId ? { studentId } : {}),
        ...(classId ? { member: { classId } } : {}),
        OR: [
          { member: { classroom: { teacherId: userId } } },
          { student: { guardians: { some: { guardianUserId: userId } } } }
        ]
      },
      include: { student: true, member: { include: { classroom: true } }, session: true, operator: { select: { id: true, displayName: true } } },
      orderBy: { createdAt: "desc" }
    });
  }

  lowBalances(userId: string, threshold = 2) {
    return this.prisma.classMember.findMany({
      where: { classroom: { teacherId: userId }, status: "APPROVED", remainingHours: { lte: threshold } },
      include: { student: true, classroom: true }, orderBy: { remainingHours: "asc" }
    });
  }
}
