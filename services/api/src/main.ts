import "reflect-metadata";
import "dotenv/config";
import { ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { AppModule } from "./app.module";
import { ApiExceptionFilter } from "./common/http/api-exception.filter";
import { ApiResponseInterceptor } from "./common/http/api-response.interceptor";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix("api/v1");
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true
  }));
  app.useGlobalFilters(new ApiExceptionFilter());
  app.useGlobalInterceptors(new ApiResponseInterceptor());

  const config = new DocumentBuilder()
    .setTitle("ClassTrace API")
    .setDescription("ClassTrace iOS and multi-client API")
    .setVersion("1.0")
    .addBearerAuth()
    .build();
  SwaggerModule.setup("api/docs", app, SwaggerModule.createDocument(app, config));

  await app.listen(Number(process.env.PORT ?? 3000), "0.0.0.0");
}

void bootstrap();
