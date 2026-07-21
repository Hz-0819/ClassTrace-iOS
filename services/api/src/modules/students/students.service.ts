import { Injectable } from "@nestjs/common";
import { createHash, randomBytes } from "node:crypto";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";
import { CreateStudentDto, UpdateStudentDto } from "./students.dto";

@Injectable()
export class StudentsService {
  constructor(private readonly prisma: PrismaService) {}

  private accessWhere(userId: string) {
    return {
      OR: [
        { createdByUserId: userId },
        { guardians: { some: { guardianUserId: userId } } },
        { classMembers: { some: { classroom: { teacherId: userId } } } }
      ]
    };
  }

  list(userId: string) {
    return this.prisma.student.findMany({
      where: { status: "active", ...this.accessWhere(userId) },
      include: { guardians: true, classMembers: { where: { status: "APPROVED" }, include: { classroom: true } } },
      orderBy: { createdAt: "desc" }
    });
  }

  async detail(userId: string, id: string) {
    const student = await this.prisma.student.findFirst({
      where: { id, ...this.accessWhere(userId) },
      include: {
        guardians: true,
        classMembers: { include: { classroom: true } },
        attendances: { orderBy: { updatedAt: "desc" }, take: 30 },
        homeworkSubmissions: { orderBy: { submittedAt: "desc" }, take: 30 },
        studyPlans: { where: { status: "ACTIVE" } },
        mistakes: { where: { masteredAt: null }, take: 30 }
      }
    });
    if (!student) throw new DomainException("STUDENT_NOT_FOUND", "学生不存在或无权查看", 404);
    return student;
  }

  create(userId: string, dto: CreateStudentDto) {
    return this.prisma.student.create({
      data: {
        createdByUserId: userId,
        name: dto.name.trim(), gender: dto.gender, grade: dto.grade,
        ...(dto.linkAsGuardian ? { guardians: { create: { guardianUserId: userId, relationship: "监护人", isPrimary: true } } } : {})
      }
    });
  }

  async update(userId: string, id: string, dto: UpdateStudentDto) {
    await this.detail(userId, id);
    return this.prisma.student.update({
      where: { id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
        ...(dto.gender !== undefined ? { gender: dto.gender } : {}),
        ...(dto.grade !== undefined ? { grade: dto.grade } : {})
      }
    });
  }

  async remove(userId: string, id: string): Promise<void> {
    const student = await this.prisma.student.findFirst({ where: { id, createdByUserId: userId }, include: { classMembers: true } });
    if (!student) throw new DomainException("FORBIDDEN", "只有档案创建人可以删除学生", 403);
    if (student.classMembers.some((member) => member.status === "APPROVED")) {
      throw new DomainException("STUDENT_IN_ACTIVE_CLASS", "学生仍在班级中，不能删除", 409);
    }
    await this.prisma.student.update({ where: { id }, data: { status: "deleted" } });
  }

  async createGuardianInvite(userId: string, studentId: string) {
    await this.detail(userId, studentId);
    const code = randomBytes(18).toString("base64url");
    await this.prisma.studentGuardianInvite.create({
      data: {
        studentId, createdById: userId,
        codeHash: createHash("sha256").update(code).digest("hex"),
        expiresAt: new Date(Date.now() + 24 * 60 * 60_000)
      }
    });
    return { code, expiresIn: 86400 };
  }

  async bindGuardian(userId: string, code: string, relationship?: string) {
    const codeHash = createHash("sha256").update(code).digest("hex");
    const invite = await this.prisma.studentGuardianInvite.findUnique({ where: { codeHash } });
    if (!invite || invite.consumedAt || invite.expiresAt <= new Date()) {
      throw new DomainException("INVITE_INVALID", "绑定邀请无效或已过期", 400);
    }
    await this.prisma.$transaction([
      this.prisma.studentGuardian.upsert({
        where: { studentId_guardianUserId: { studentId: invite.studentId, guardianUserId: userId } },
        create: { studentId: invite.studentId, guardianUserId: userId, relationship },
        update: { relationship }
      }),
      this.prisma.studentGuardianInvite.update({ where: { id: invite.id }, data: { consumedAt: new Date() } })
    ]);
    return this.detail(userId, invite.studentId);
  }

  async removeGuardian(userId: string, studentId: string, guardianUserId: string) {
    const student = await this.prisma.student.findUnique({ where: { id: studentId } });
    if (!student || (student.createdByUserId !== userId && guardianUserId !== userId)) throw new DomainException("FORBIDDEN", "无权解除该监护关系", 403);
    const result = await this.prisma.studentGuardian.deleteMany({ where: { studentId, guardianUserId } });
    if (!result.count) throw new DomainException("GUARDIAN_LINK_NOT_FOUND", "监护关系不存在", 404);
  }
}
