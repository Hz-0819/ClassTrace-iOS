import { MiddlewareConsumer, Module, NestModule } from "@nestjs/common";
import { RequestContextMiddleware } from "./common/http/request-context.middleware";
import { DatabaseModule } from "./database/database.module";
import { HealthModule } from "./modules/health/health.module";
import { IdentityModule } from "./modules/identity/identity.module";
import { UsersModule } from "./modules/users/users.module";
import { StudentsModule } from "./modules/students/students.module";
import { ClassroomModule } from "./modules/classroom/classroom.module";
import { SessionsModule } from "./modules/sessions/sessions.module";
import { LearningModule } from "./modules/learning/learning.module";
import { EngagementModule } from "./modules/engagement/engagement.module";
import { CommerceModule } from "./modules/commerce/commerce.module";
import { ContentSecurityModule } from "./modules/content-security/content-security.module";
import { StorageModule } from "./modules/storage/storage.module";
import { AttendanceModule } from "./modules/attendance/attendance.module";

@Module({
  imports: [DatabaseModule, HealthModule, IdentityModule, UsersModule, StudentsModule, ClassroomModule, SessionsModule, LearningModule, EngagementModule, CommerceModule, ContentSecurityModule, StorageModule, AttendanceModule]
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestContextMiddleware).forRoutes("*");
  }
}
