import { Injectable } from "@nestjs/common";
import { randomBytes } from "node:crypto";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";
import { CreateOrderDto, RecordPaymentDto, RequestRefundDto, ResolveRefundDto } from "./commerce.dto";

@Injectable()
export class CommerceService {
  constructor(private readonly prisma: PrismaService) {}
  listOrders(userId: string) {
    return this.prisma.courseOrder.findMany({ where: { OR: [{ guardianId: userId }, { teacherId: userId }] }, include: { student: true, classroom: true, payments: true, refunds: true, fulfillments: true }, orderBy: { createdAt: "desc" } });
  }
  async order(userId: string, id: string) {
    const item = await this.prisma.courseOrder.findFirst({ where: { id, OR: [{ guardianId: userId }, { teacherId: userId }] }, include: { student: true, classroom: true, payments: true, refunds: true, settlements: true, fulfillments: true } });
    if (!item) throw new DomainException("ORDER_NOT_FOUND", "订单不存在", 404);
    return item;
  }
  async createOrder(userId: string, dto: CreateOrderDto) {
    const guardian = await this.prisma.studentGuardian.findUnique({ where: { studentId_guardianUserId: { studentId: dto.studentId, guardianUserId: userId } } });
    const classroom = await this.prisma.classroom.findUnique({ where: { id: dto.classId } });
    const member = await this.prisma.classMember.findUnique({ where: { classId_studentId: { classId: dto.classId, studentId: dto.studentId } } });
    if (!guardian || !classroom || !member) throw new DomainException("FORBIDDEN", "无权为该学生创建订单", 403);
    return this.prisma.courseOrder.create({ data: {
      guardianId: userId, teacherId: classroom.teacherId, studentId: dto.studentId, classId: dto.classId,
      orderNumber: `CT${Date.now()}${randomBytes(3).toString("hex").toUpperCase()}`,
      totalAmountCents: dto.totalAmountCents, purchasedHours: dto.purchasedHours,
      settlementPolicy: dto.settlementPolicy ?? "DIRECT_FULL",
      refundPolicy: { mode: "negotiated", consumedHoursNonRefundable: true }
    } });
  }
  async recordPayment(userId: string, id: string, dto: RecordPaymentDto) {
    const order = await this.prisma.courseOrder.findFirst({ where: { id, teacherId: userId }, include: { classroom: true } });
    if (!order) throw new DomainException("ORDER_NOT_FOUND", "订单不存在或无权收款", 404);
    if (dto.amountCents !== order.totalAmountCents) throw new DomainException("PAYMENT_AMOUNT_MISMATCH", "收款金额与订单金额不一致", 422);
    return this.prisma.$transaction(async (tx) => {
      const payment = await tx.paymentTransaction.upsert({
        where: { providerTransactionId: dto.providerTransactionId },
        create: { orderId: id, provider: dto.provider, providerTransactionId: dto.providerTransactionId, status: "SUCCEEDED", amountCents: dto.amountCents, occurredAt: new Date() }, update: {}
      });
      if (payment.orderId !== id) throw new DomainException("PAYMENT_EVENT_CONFLICT", "支付流水已被其他订单使用", 409);
      const member = await tx.classMember.findUniqueOrThrow({ where: { classId_studentId: { classId: order.classId, studentId: order.studentId } } });
      const alreadyCredited = await tx.hourLedgerEntry.findUnique({ where: { idempotencyKey: `order:${id}:paid` } });
      if (!alreadyCredited) {
        const updated = await tx.classMember.update({ where: { id: member.id }, data: { totalHours: { increment: order.purchasedHours }, remainingHours: { increment: order.purchasedHours } } });
        await tx.hourLedgerEntry.create({ data: { memberId: member.id, studentId: order.studentId, operatorId: userId, type: "RECHARGE", delta: order.purchasedHours, balanceAfter: updated.remainingHours, idempotencyKey: `order:${id}:paid`, remark: `订单 ${order.orderNumber} 购课` } });
      }
      await tx.courseOrder.update({ where: { id }, data: { status: "ACTIVE", paidAt: new Date() } });
      const providerSettlementId = `${dto.provider}:${dto.providerTransactionId}`;
      await tx.settlement.upsert({
        where: { providerSettlementId },
        create: { orderId: id, amountCents: dto.amountCents, status: "SETTLED", settledAt: new Date(), providerSettlementId },
        update: {}
      });
      await tx.outboxEvent.create({ data: { aggregateType: "CourseOrder", aggregateId: id, eventType: "OrderPaid", payload: { guardianId: order.guardianId, teacherId: order.teacherId } } });
      return tx.courseOrder.findUniqueOrThrow({ where: { id }, include: { payments: true, settlements: true } });
    }, { isolationLevel: "Serializable" });
  }
  async requestRefund(userId: string, id: string, dto: RequestRefundDto) {
    const order = await this.prisma.courseOrder.findFirst({ where: { id, guardianId: userId } });
    if (!order || !["PAID", "ACTIVE", "COMPLETED"].includes(order.status)) throw new DomainException("ORDER_NOT_REFUNDABLE", "订单当前不可申请退款", 409);
    if (dto.amountCents > order.totalAmountCents || dto.hours > Number(order.purchasedHours) - Number(order.consumedHours)) throw new DomainException("REFUND_EXCEEDS_REMAINDER", "退款超过剩余金额或课时", 422);
    return this.prisma.$transaction(async (tx) => {
      const refund = await tx.refund.create({ data: { orderId: id, amountCents: dto.amountCents, hours: dto.hours, reason: dto.reason, status: "REQUESTED" } });
      await tx.courseOrder.update({ where: { id }, data: { status: "REFUND_PENDING" } });
      await tx.outboxEvent.create({ data: { aggregateType: "Refund", aggregateId: refund.id, eventType: "RefundRequested", payload: { orderId: id, teacherId: order.teacherId } } });
      return refund;
    });
  }
  async resolveRefund(userId: string, refundId: string, dto: ResolveRefundDto) {
    const refund = await this.prisma.refund.findFirst({ where: { id: refundId, order: { teacherId: userId } }, include: { order: true } });
    if (!refund) throw new DomainException("REFUND_NOT_FOUND", "退款申请不存在", 404);
    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.refund.update({ where: { id: refundId }, data: { status: dto.status, providerRefundId: dto.providerRefundId } });
      if (dto.status === "REFUNDED") {
        const member = await tx.classMember.findUniqueOrThrow({ where: { classId_studentId: { classId: refund.order.classId, studentId: refund.order.studentId } } });
        if (Number(member.remainingHours) < Number(refund.hours)) throw new DomainException("REFUND_HOURS_ALREADY_USED", "拟退课时已被使用，需重新协商", 409);
        const balance = Number(member.remainingHours) - Number(refund.hours);
        await tx.classMember.update({ where: { id: member.id }, data: { remainingHours: balance, totalHours: { decrement: refund.hours } } });
        await tx.hourLedgerEntry.create({ data: { memberId: member.id, studentId: member.studentId, operatorId: userId, type: "REFUND", delta: refund.hours.negated(), balanceAfter: balance, idempotencyKey: `refund:${refundId}`, remark: refund.reason ?? "订单退款" } });
        await tx.courseOrder.update({ where: { id: refund.orderId }, data: { status: "REFUNDED" } });
      } else if (dto.status === "REJECTED") await tx.courseOrder.update({ where: { id: refund.orderId }, data: { status: "ACTIVE" } });
      await tx.outboxEvent.create({ data: { aggregateType: "Refund", aggregateId: refundId, eventType: `Refund${dto.status}`, payload: { orderId: refund.orderId, guardianId: refund.order.guardianId } } });
      return updated;
    }, { isolationLevel: "Serializable" });
  }
  async stats(userId: string) {
    const [teacher, guardian] = await Promise.all([
      this.prisma.courseOrder.aggregate({ where: { teacherId: userId }, _count: true, _sum: { totalAmountCents: true } }),
      this.prisma.courseOrder.aggregate({ where: { guardianId: userId }, _count: true, _sum: { totalAmountCents: true } })
    ]);
    return { asTeacher: teacher, asGuardian: guardian };
  }
}
