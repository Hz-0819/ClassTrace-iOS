import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, Query, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { AuthenticatedUser } from "../../common/auth/authenticated-user";
import { CurrentUser } from "../../common/auth/current-user.decorator";
import { CheckInDto, CreateHomeworkDto, CreateMaterialDto, CreateMistakeDto, CreatePlanDto, ReviewHomeworkDto, SubmitHomeworkDto, UpdateHomeworkDto, UpdateMistakeDto, UpdatePlanDto } from "./learning.dto";
import { LearningService } from "./learning.service";

@Controller()
@UseGuards(AuthGuard)
export class LearningController {
  constructor(private readonly learning: LearningService) {}
  @Get("homework") homework(@CurrentUser() u: AuthenticatedUser, @Query("classId") classId?: string) { return this.learning.listHomework(u.id, classId); }
  @Get("homework/:id") homeworkDetail(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.learning.homeworkDetail(u.id, id); }
  @Post("homework") createHomework(@CurrentUser() u: AuthenticatedUser, @Body() d: CreateHomeworkDto) { return this.learning.createHomework(u.id, d); }
  @Patch("homework/:id") updateHomework(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: UpdateHomeworkDto) { return this.learning.updateHomework(u.id, id, d); }
  @Delete("homework/:id") @HttpCode(204) deleteHomework(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.learning.deleteHomework(u.id, id); }
  @Post("homework/:id/submissions") submit(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: SubmitHomeworkDto) { return this.learning.submitHomework(u.id, id, d); }
  @Patch("homework-submissions/:id/review") review(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: ReviewHomeworkDto) { return this.learning.reviewHomework(u.id, id, d); }
  @Get("materials") materials(@CurrentUser() u: AuthenticatedUser, @Query("classId") classId?: string) { return this.learning.listMaterials(u.id, classId); }
  @Post("materials") createMaterial(@CurrentUser() u: AuthenticatedUser, @Body() d: CreateMaterialDto) { return this.learning.createMaterial(u.id, d); }
  @Delete("materials/:id") @HttpCode(204) deleteMaterial(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.learning.deleteMaterial(u.id, id); }
  @Get("plans") plans(@CurrentUser() u: AuthenticatedUser, @Query("studentId") studentId?: string) { return this.learning.plans(u.id, studentId); }
  @Post("plans") createPlan(@CurrentUser() u: AuthenticatedUser, @Body() d: CreatePlanDto) { return this.learning.createPlan(u.id, d); }
  @Patch("plans/:id") updatePlan(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: UpdatePlanDto) { return this.learning.updatePlan(u.id, id, d); }
  @Delete("plans/:id") @HttpCode(204) deletePlan(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.learning.deletePlan(u.id, id); }
  @Post("plans/:id/check-ins") checkIn(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: CheckInDto) { return this.learning.checkIn(u.id, id, d.note); }
  @Get("mistakes") mistakes(@CurrentUser() u: AuthenticatedUser, @Query("studentId") studentId?: string) { return this.learning.mistakes(u.id, studentId); }
  @Post("mistakes") createMistake(@CurrentUser() u: AuthenticatedUser, @Body() d: CreateMistakeDto) { return this.learning.createMistake(u.id, d); }
  @Patch("mistakes/:id") updateMistake(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: UpdateMistakeDto) { return this.learning.updateMistake(u.id, id, d); }
  @Delete("mistakes/:id") @HttpCode(204) deleteMistake(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.learning.deleteMistake(u.id, id); }
  @Post("mistakes/:id/mastered") mastered(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.learning.markMastered(u.id, id); }
  @Get("points") points(@CurrentUser() u: AuthenticatedUser) { return this.learning.points(u.id); }
}
