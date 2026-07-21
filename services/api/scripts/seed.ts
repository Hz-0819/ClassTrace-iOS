import { prisma } from "./prisma";

async function main() {
  const teacher = await prisma.user.upsert({ where: { id: "10000000-0000-4000-8000-000000000001" }, update: {}, create: { id: "10000000-0000-4000-8000-000000000001", displayName: "演示教师", identities: { create: { provider: "PHONE", providerSubject: "+8613800000001", verifiedAt: new Date() } }, roles: { create: { role: "TEACHER" } } } });
  const guardian = await prisma.user.upsert({ where: { id: "10000000-0000-4000-8000-000000000002" }, update: {}, create: { id: "10000000-0000-4000-8000-000000000002", displayName: "演示家长", identities: { create: { provider: "PHONE", providerSubject: "+8613800000002", verifiedAt: new Date() } }, roles: { create: { role: "GUARDIAN" } } } });
  const student = await prisma.student.upsert({ where: { id: "20000000-0000-4000-8000-000000000001" }, update: {}, create: { id: "20000000-0000-4000-8000-000000000001", createdByUserId: guardian.id, name: "小课同学", grade: "三年级", guardians: { create: { guardianUserId: guardian.id, relationship: "家长", isPrimary: true } } } });
  const course = await prisma.course.upsert({ where: { id: "30000000-0000-4000-8000-000000000001" }, update: {}, create: { id: "30000000-0000-4000-8000-000000000001", teacherId: teacher.id, name: "小学数学思维", subject: "数学" } });
  const classroom = await prisma.classroom.upsert({ where: { id: "40000000-0000-4000-8000-000000000001" }, update: {}, create: { id: "40000000-0000-4000-8000-000000000001", teacherId: teacher.id, courseId: course.id, name: "数学思维演示班", classType: "SMALL_GROUP", billingMode: "PREPAID", status: "ACTIVE", inviteCode: "DEMO2026", location: "线上教室" } });
  const member = await prisma.classMember.upsert({ where: { classId_studentId: { classId: classroom.id, studentId: student.id } }, update: {}, create: { classId: classroom.id, studentId: student.id, totalHours: 20, remainingHours: 20, pricePerHour: 180 } });
  await prisma.hourLedgerEntry.upsert({ where: { idempotencyKey: "seed:initial-hours" }, update: {}, create: { memberId: member.id, studentId: student.id, operatorId: teacher.id, type: "RECHARGE", delta: 20, balanceAfter: 20, idempotencyKey: "seed:initial-hours", remark: "演示初始课时" } });
  const startsAt = new Date(); startsAt.setDate(startsAt.getDate() + 1); startsAt.setHours(18, 30, 0, 0);
  await prisma.classSession.upsert({ where: { classId_startsAt: { classId: classroom.id, startsAt } }, update: {}, create: { classId: classroom.id, startsAt, endsAt: new Date(startsAt.getTime() + 60 * 60_000), plannedHours: 1 } });
  await prisma.homework.upsert({ where: { id: "50000000-0000-4000-8000-000000000001" }, update: {}, create: { id: "50000000-0000-4000-8000-000000000001", classId: classroom.id, authorId: teacher.id, title: "思维训练第 1 课", content: "完成课堂练习并拍照上传。", status: "PUBLISHED", dueAt: new Date(Date.now() + 3 * 86400_000) } });
  console.log("Seed complete: teacher +8613800000001, guardian +8613800000002");
}
main().finally(() => prisma.$disconnect());
