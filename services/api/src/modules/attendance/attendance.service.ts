import { Injectable } from "@nestjs/common";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";
import { RecordAttendanceDto, UpdateAttendanceDto } from "./attendance.dto";
@Injectable()
export class AttendanceService {
  constructor(private readonly prisma: PrismaService) {}
  private async assertTeacher(userId: string, sessionId: string) { const session = await this.prisma.classSession.findFirst({ where: { id: sessionId, classroom: { teacherId: userId } } }); if (!session) throw new DomainException("SESSION_NOT_FOUND", "课节不存在或无权操作", 404); }
  async record(userId: string, dto: RecordAttendanceDto) { await this.assertTeacher(userId, dto.sessionId); return this.prisma.sessionAttendance.upsert({ where: { sessionId_studentId: { sessionId: dto.sessionId, studentId: dto.studentId } }, create: { sessionId: dto.sessionId, studentId: dto.studentId, status: dto.status, deductHours: dto.deductHours ?? 0, remark: dto.remark }, update: { status: dto.status, deductHours: dto.deductHours ?? 0, remark: dto.remark } }); }
  async batch(userId: string, records: RecordAttendanceDto[]) { const results = []; for (const record of records) results.push(await this.record(userId, record)); return results; }
  listByStudent(userId: string, studentId: string) { return this.prisma.sessionAttendance.findMany({ where: { studentId, student: { OR: [{ guardians: { some: { guardianUserId: userId } } }, { classMembers: { some: { classroom: { teacherId: userId } } } }] } }, include: { session: { include: { classroom: true } } }, orderBy: { session: { startsAt: "desc" } } }); }
  async listByClass(userId: string, classId: string) { const classroom = await this.prisma.classroom.findFirst({ where: { id: classId, OR: [{ teacherId: userId }, { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } }] } }); if (!classroom) throw new DomainException("CLASS_NOT_FOUND", "班级不存在", 404); return this.prisma.sessionAttendance.findMany({ where: { session: { classId } }, include: { student: true, session: true }, orderBy: { session: { startsAt: "desc" } } }); }
  async stats(userId: string, studentId: string) { const items = await this.listByStudent(userId, studentId); const counts = items.reduce<Record<string, number>>((result, item) => ({ ...result, [item.status]: (result[item.status] ?? 0) + 1 }), {}); return { total: items.length, counts, attendanceRate: items.length ? (counts.PRESENT ?? 0) / items.length : 0 }; }
  async update(userId: string, id: string, dto: UpdateAttendanceDto) { const item = await this.prisma.sessionAttendance.findFirst({ where: { id, session: { classroom: { teacherId: userId } } } }); if (!item) throw new DomainException("ATTENDANCE_NOT_FOUND", "考勤记录不存在", 404); return this.prisma.sessionAttendance.update({ where: { id }, data: dto }); }
  async remove(userId: string, id: string) { const item = await this.prisma.sessionAttendance.findFirst({ where: { id, session: { classroom: { teacherId: userId } } } }); if (!item) throw new DomainException("ATTENDANCE_NOT_FOUND", "考勤记录不存在", 404); await this.prisma.sessionAttendance.delete({ where: { id } }); }
}
