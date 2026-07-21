import { Injectable } from "@nestjs/common";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";
import { ContentSecurityService } from "../content-security/content-security.service";
import { CreateHomeworkDto, CreateMaterialDto, CreateMistakeDto, CreatePlanDto, ReviewHomeworkDto, SubmitHomeworkDto, UpdateHomeworkDto, UpdateMistakeDto, UpdatePlanDto } from "./learning.dto";

@Injectable()
export class LearningService {
  constructor(private readonly prisma: PrismaService, private readonly security: ContentSecurityService) {}
  private async ensureText(userId: string, values: Array<string | undefined>, contextId?: string) {
    const content = values.filter(Boolean).join("\n").trim();
    if (!content) return;
    const result = await this.security.checkText(userId, content, contextId);
    if (!result.allowed) throw new DomainException("CONTENT_BLOCKED", "内容未通过安全检查，请修改后重试", 422);
  }
  private async teacherClass(userId: string, classId: string) {
    const item = await this.prisma.classroom.findFirst({ where: { id: classId, teacherId: userId } });
    if (!item) throw new DomainException("FORBIDDEN", "只有班级教师可以执行此操作", 403);
    return item;
  }
  private async accessibleStudent(userId: string, studentId: string) {
    const item = await this.prisma.student.findFirst({ where: { id: studentId, OR: [{ createdByUserId: userId }, { guardians: { some: { guardianUserId: userId } } }, { classMembers: { some: { classroom: { teacherId: userId } } } }] } });
    if (!item) throw new DomainException("STUDENT_NOT_FOUND", "学生不存在或无权操作", 404);
  }

  listHomework(userId: string, classId?: string) {
    return this.prisma.homework.findMany({
      where: { ...(classId ? { classId } : {}), classroom: { OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] } },
      include: { classroom: true, _count: { select: { submissions: true } } }, orderBy: { createdAt: "desc" }
    });
  }
  async homeworkDetail(userId: string, id: string) {
    const item = await this.prisma.homework.findFirst({
      where: { id, classroom: { OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] } },
      include: { classroom: true, submissions: { include: { student: true } } }
    });
    if (!item) throw new DomainException("HOMEWORK_NOT_FOUND", "作业不存在或无权查看", 404);
    return item;
  }
  async createHomework(userId: string, dto: CreateHomeworkDto) {
    await this.teacherClass(userId, dto.classId);
    await this.ensureText(userId, [dto.title, dto.content], dto.classId);
    const item = await this.prisma.homework.create({ data: { classId: dto.classId, authorId: userId, title: dto.title.trim(), content: dto.content, dueAt: dto.dueAt ? new Date(dto.dueAt) : undefined, status: dto.status ?? "DRAFT", attachments: dto.attachments as never } });
    if (item.status === "PUBLISHED") await this.prisma.outboxEvent.create({ data: { aggregateType: "Homework", aggregateId: item.id, eventType: "HomeworkPublished", payload: { classId: item.classId } } });
    return item;
  }
  async updateHomework(userId: string, id: string, dto: UpdateHomeworkDto) {
    const item = await this.prisma.homework.findFirst({ where: { id, classroom: { teacherId: userId } } });
    if (!item) throw new DomainException("HOMEWORK_NOT_FOUND", "作业不存在", 404);
    await this.ensureText(userId, [dto.title, dto.content], id);
    const updated = await this.prisma.homework.update({ where: { id }, data: { ...dto, dueAt: dto.dueAt ? new Date(dto.dueAt) : undefined, attachments: dto.attachments as never } });
    if (item.status !== "PUBLISHED" && updated.status === "PUBLISHED") await this.prisma.outboxEvent.create({ data: { aggregateType: "Homework", aggregateId: id, eventType: "HomeworkPublished", payload: { classId: item.classId } } });
    return updated;
  }
  async deleteHomework(userId: string, id: string) {
    const result = await this.prisma.homework.deleteMany({ where: { id, classroom: { teacherId: userId } } });
    if (!result.count) throw new DomainException("HOMEWORK_NOT_FOUND", "作业不存在", 404);
  }
  async submitHomework(userId: string, id: string, dto: SubmitHomeworkDto) {
    const homework = await this.prisma.homework.findUnique({ where: { id }, include: { classroom: true } });
    if (!homework || homework.status !== "PUBLISHED") throw new DomainException("HOMEWORK_NOT_OPEN", "作业未发布或已关闭", 409);
    const guardian = await this.prisma.studentGuardian.findUnique({ where: { studentId_guardianUserId: { studentId: dto.studentId, guardianUserId: userId } } });
    const member = await this.prisma.classMember.findUnique({ where: { classId_studentId: { classId: homework.classId, studentId: dto.studentId } } });
    await this.ensureText(userId, [dto.content], id);
    if (!guardian || !member || member.status !== "APPROVED") throw new DomainException("FORBIDDEN", "无权为该学生提交作业", 403);
    return this.prisma.homeworkSubmission.upsert({
      where: { homeworkId_studentId: { homeworkId: id, studentId: dto.studentId } },
      create: { homeworkId: id, studentId: dto.studentId, content: dto.content, attachments: dto.attachments as never },
      update: { content: dto.content, attachments: dto.attachments as never, status: "SUBMITTED", submittedAt: new Date(), reviewedAt: null }
    });
  }
  async reviewHomework(userId: string, submissionId: string, dto: ReviewHomeworkDto) {
    const item = await this.prisma.homeworkSubmission.findFirst({ where: { id: submissionId, homework: { classroom: { teacherId: userId } } } });
    if (!item) throw new DomainException("SUBMISSION_NOT_FOUND", "作业提交不存在", 404);
    await this.ensureText(userId, [dto.comment], submissionId);
    const updated = await this.prisma.homeworkSubmission.update({ where: { id: submissionId }, data: { score: dto.score, comment: dto.comment, status: dto.status ?? "REVIEWED", reviewedAt: new Date() } });
    await this.prisma.outboxEvent.create({ data: { aggregateType: "HomeworkSubmission", aggregateId: submissionId, eventType: "HomeworkReviewed", payload: { homeworkId: item.homeworkId, studentId: item.studentId } } });
    return updated;
  }

  listMaterials(userId: string, classId?: string) {
    return this.prisma.material.findMany({ where: { deletedAt: null, ...(classId ? { classId } : {}), OR: [{ uploaderId: userId }, { classroom: { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } } }] }, orderBy: { createdAt: "desc" } });
  }
  async createMaterial(userId: string, dto: CreateMaterialDto) {
    if (dto.classId) await this.teacherClass(userId, dto.classId);
    await this.ensureText(userId, [dto.name, dto.category], dto.classId);
    const fileCheck = await this.security.checkFile(userId, dto.objectKey, dto.mimeType, dto.sizeBytes);
    if (!fileCheck.allowed) throw new DomainException("FILE_BLOCKED", "文件未通过安全检查", 422);
    const item = await this.prisma.material.create({ data: { ...dto, uploaderId: userId } });
    if (dto.classId) await this.prisma.outboxEvent.create({ data: { aggregateType: "Material", aggregateId: item.id, eventType: "MaterialUploaded", payload: { classId: dto.classId } } });
    return item;
  }
  async deleteMaterial(userId: string, id: string) {
    const result = await this.prisma.material.updateMany({ where: { id, uploaderId: userId, deletedAt: null }, data: { deletedAt: new Date() } });
    if (!result.count) throw new DomainException("MATERIAL_NOT_FOUND", "资料不存在", 404);
  }

  plans(userId: string, studentId?: string) { return this.prisma.studyPlan.findMany({ where: { ownerUserId: userId, ...(studentId ? { studentId } : {}) }, include: { checkIns: { orderBy: { checkedAt: "desc" }, take: 30 } }, orderBy: { updatedAt: "desc" } }); }
  async createPlan(userId: string, dto: CreatePlanDto) {
    if (dto.studentId) await this.accessibleStudent(userId, dto.studentId);
    await this.ensureText(userId, [dto.title, dto.description], dto.studentId);
    return this.prisma.studyPlan.create({ data: { ownerUserId: userId, studentId: dto.studentId, title: dto.title.trim(), description: dto.description, frequency: dto.frequency as never, startsAt: dto.startsAt ? new Date(dto.startsAt) : undefined, endsAt: dto.endsAt ? new Date(dto.endsAt) : undefined } });
  }
  async updatePlan(userId: string, id: string, dto: UpdatePlanDto) {
    await this.ensureText(userId, [dto.title, dto.description], id);
    const result = await this.prisma.studyPlan.updateMany({ where: { id, ownerUserId: userId }, data: { ...dto, frequency: dto.frequency as never, startsAt: dto.startsAt ? new Date(dto.startsAt) : undefined, endsAt: dto.endsAt ? new Date(dto.endsAt) : undefined } });
    if (!result.count) throw new DomainException("PLAN_NOT_FOUND", "学习计划不存在", 404);
    return this.prisma.studyPlan.findUniqueOrThrow({ where: { id } });
  }
  async deletePlan(userId: string, id: string) { const result = await this.prisma.studyPlan.deleteMany({ where: { id, ownerUserId: userId } }); if (!result.count) throw new DomainException("PLAN_NOT_FOUND", "学习计划不存在", 404); }
  async checkIn(userId: string, id: string, note?: string) {
    const plan = await this.prisma.studyPlan.findFirst({ where: { id, ownerUserId: userId, status: "ACTIVE" } });
    if (!plan) throw new DomainException("PLAN_NOT_FOUND", "学习计划不存在或已结束", 404);
    return this.prisma.$transaction(async (tx) => {
      const item = await tx.planCheckIn.create({ data: { planId: id, note } });
      const idempotencyKey = `plan:${id}:${new Date().toISOString().slice(0, 10)}`;
      await tx.pointLedgerEntry.upsert({
        where: { idempotencyKey },
        create: { userId, delta: 1, reason: "学习计划打卡", idempotencyKey },
        update: {}
      });
      return item;
    });
  }

  mistakes(userId: string, studentId?: string) { return this.prisma.mistake.findMany({ where: { ownerUserId: userId, ...(studentId ? { studentId } : {}) }, orderBy: { createdAt: "desc" } }); }
  async createMistake(userId: string, dto: CreateMistakeDto) { if (dto.studentId) await this.accessibleStudent(userId, dto.studentId); await this.ensureText(userId, [dto.title, dto.content, dto.answer, dto.analysis], dto.studentId); return this.prisma.mistake.create({ data: { ...dto, ownerUserId: userId, tags: dto.tags ?? [], images: dto.images as never } }); }
  async updateMistake(userId: string, id: string, dto: UpdateMistakeDto) { await this.ensureText(userId, [dto.title, dto.content, dto.answer, dto.analysis], id); const result = await this.prisma.mistake.updateMany({ where: { id, ownerUserId: userId }, data: { ...dto, images: dto.images as never } }); if (!result.count) throw new DomainException("MISTAKE_NOT_FOUND", "错题不存在", 404); return this.prisma.mistake.findUniqueOrThrow({ where: { id } }); }
  async deleteMistake(userId: string, id: string) { const result = await this.prisma.mistake.deleteMany({ where: { id, ownerUserId: userId } }); if (!result.count) throw new DomainException("MISTAKE_NOT_FOUND", "错题不存在", 404); }
  async markMastered(userId: string, id: string) { const result = await this.prisma.mistake.updateMany({ where: { id, ownerUserId: userId }, data: { masteredAt: new Date() } }); if (!result.count) throw new DomainException("MISTAKE_NOT_FOUND", "错题不存在", 404); return this.prisma.mistake.findUniqueOrThrow({ where: { id } }); }
  async points(userId: string) { const entries = await this.prisma.pointLedgerEntry.findMany({ where: { userId }, orderBy: { createdAt: "desc" } }); return { balance: entries.reduce((sum, item) => sum + item.delta, 0), entries }; }
}
