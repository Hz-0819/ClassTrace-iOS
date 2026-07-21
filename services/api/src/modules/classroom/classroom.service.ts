import { Injectable } from "@nestjs/common";
import { randomBytes } from "node:crypto";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";
import { AddMemberDto, CreateClassDto, CreateCourseDto, JoinClassDto, UpdateClassDto, UpdateCourseDto, UpdateMemberDto } from "./classroom.dto";

@Injectable()
export class ClassroomService {
  constructor(private readonly prisma: PrismaService) {}

  listCourses(userId: string) {
    return this.prisma.course.findMany({
      where: { OR: [{ teacherId: userId }, { classes: { some: { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } } } }] },
      include: { classes: { where: { status: { not: "CANCELLED" } } } }, orderBy: { updatedAt: "desc" }
    });
  }
  createCourse(userId: string, dto: CreateCourseDto) { return this.prisma.course.create({ data: { teacherId: userId, name: dto.name.trim(), subject: dto.subject, description: dto.description } }); }
  async updateCourse(userId: string, id: string, dto: UpdateCourseDto) {
    const result = await this.prisma.course.updateMany({
      where: { id, teacherId: userId },
      data: { name: dto.name?.trim(), subject: dto.subject, description: dto.description }
    });
    if (!result.count) throw new DomainException("COURSE_NOT_FOUND", "课程不存在或无权修改", 404);
    return this.prisma.course.findUniqueOrThrow({ where: { id } });
  }
  async deleteCourse(userId: string, id: string) {
    const course = await this.prisma.course.findFirst({ where: { id, teacherId: userId }, include: { classes: { where: { status: { in: ["ACTIVE", "PAUSED"] } } } } });
    if (!course) throw new DomainException("COURSE_NOT_FOUND", "课程不存在", 404);
    if (course.classes.length) throw new DomainException("COURSE_HAS_CLASSES", "课程仍有关联班级，不能删除", 409);
    await this.prisma.course.update({ where: { id }, data: { status: "deleted" } });
  }

  listClasses(userId: string) {
    return this.prisma.classroom.findMany({
      where: { OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] },
      include: { course: true, members: { where: { status: { in: ["PENDING", "APPROVED", "PAUSED"] } }, include: { student: true } } },
      orderBy: { updatedAt: "desc" }
    });
  }
  async classDetail(userId: string, id: string) {
    const item = await this.prisma.classroom.findFirst({
      where: { id, OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] },
      include: { course: true, members: { include: { student: true } }, sessions: { orderBy: { startsAt: "desc" }, take: 60 } }
    });
    if (!item) throw new DomainException("CLASS_NOT_FOUND", "班级不存在或无权查看", 404);
    return item;
  }
  createClass(userId: string, dto: CreateClassDto) {
    return this.prisma.classroom.create({ data: {
      teacherId: userId, courseId: dto.courseId, name: dto.name.trim(), classType: dto.classType,
      billingMode: dto.billingMode ?? "PREPAID", location: dto.location,
      scheduleRule: dto.scheduleRule as never, status: "ACTIVE", inviteCode: randomBytes(6).toString("base64url").toUpperCase()
    } });
  }
  async updateClass(userId: string, id: string, dto: UpdateClassDto) {
    const result = await this.prisma.classroom.updateMany({ where: { id, teacherId: userId }, data: {
      ...(dto.name !== undefined ? { name: dto.name.trim() } : {}), ...(dto.courseId !== undefined ? { courseId: dto.courseId } : {}),
      ...(dto.status !== undefined ? { status: dto.status } : {}), ...(dto.location !== undefined ? { location: dto.location } : {}),
      ...(dto.scheduleRule !== undefined ? { scheduleRule: dto.scheduleRule as never } : {}), version: { increment: 1 }
    } });
    if (!result.count) throw new DomainException("CLASS_NOT_FOUND", "班级不存在或无权修改", 404);
    return this.classDetail(userId, id);
  }
  async deleteClass(userId: string, id: string) {
    const result = await this.prisma.classroom.updateMany({ where: { id, teacherId: userId }, data: { status: "CANCELLED", version: { increment: 1 } } });
    if (!result.count) throw new DomainException("CLASS_NOT_FOUND", "班级不存在", 404);
  }
  private async assertTeacher(userId: string, classId: string) {
    const item = await this.prisma.classroom.findFirst({ where: { id: classId, teacherId: userId } });
    if (!item) throw new DomainException("FORBIDDEN", "只有班级教师可以执行此操作", 403);
    return item;
  }
  async addMember(userId: string, classId: string, dto: AddMemberDto) {
    await this.assertTeacher(userId, classId);
    const hours = dto.initialHours ?? 0;
    return this.prisma.$transaction(async (tx) => {
      const member = await tx.classMember.upsert({
        where: { classId_studentId: { classId, studentId: dto.studentId } },
        create: { classId, studentId: dto.studentId, totalHours: hours, remainingHours: hours, pricePerHour: dto.pricePerHour ?? 0 },
        update: { status: "APPROVED", ...(dto.pricePerHour !== undefined ? { pricePerHour: dto.pricePerHour } : {}) }
      });
      if (hours > 0) await tx.hourLedgerEntry.create({ data: { memberId: member.id, studentId: dto.studentId, operatorId: userId, type: "RECHARGE", delta: hours, balanceAfter: hours, remark: "加入班级初始课时" } });
      return member;
    });
  }
  async joinClass(userId: string, dto: JoinClassDto) {
    const guardian = await this.prisma.studentGuardian.findUnique({ where: { studentId_guardianUserId: { studentId: dto.studentId, guardianUserId: userId } } });
    if (!guardian) throw new DomainException("FORBIDDEN", "只能为已绑定的孩子加入班级", 403);
    const classroom = await this.prisma.classroom.findUnique({ where: { inviteCode: dto.inviteCode.toUpperCase() } });
    if (!classroom || classroom.status !== "ACTIVE") throw new DomainException("INVITE_INVALID", "班级邀请码无效", 400);
    return this.prisma.classMember.upsert({
      where: { classId_studentId: { classId: classroom.id, studentId: dto.studentId } },
      create: { classId: classroom.id, studentId: dto.studentId, status: "PENDING" }, update: { status: "PENDING" }
    });
  }
  async updateMember(userId: string, classId: string, memberId: string, dto: UpdateMemberDto) {
    await this.assertTeacher(userId, classId);
    const result = await this.prisma.classMember.updateMany({ where: { id: memberId, classId }, data: dto });
    if (!result.count) throw new DomainException("MEMBER_NOT_FOUND", "班级成员不存在", 404);
    return this.prisma.classMember.findUniqueOrThrow({ where: { id: memberId }, include: { student: true } });
  }
  async removeMember(userId: string, classId: string, memberId: string) {
    await this.assertTeacher(userId, classId);
    const result = await this.prisma.classMember.updateMany({ where: { id: memberId, classId }, data: { status: "EXITED" } });
    if (!result.count) throw new DomainException("MEMBER_NOT_FOUND", "班级成员不存在", 404);
  }
}
