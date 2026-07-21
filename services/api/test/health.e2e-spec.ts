import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { ApiExceptionFilter } from "../src/common/http/api-exception.filter";
import { ApiResponseInterceptor } from "../src/common/http/api-response.interceptor";

process.env.DATABASE_URL ??= "postgresql://classtrace:classtrace@localhost:5432/classtrace?schema=public";

describe("health contract", () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix("api/v1");
    app.useGlobalFilters(new ApiExceptionFilter());
    app.useGlobalInterceptors(new ApiResponseInterceptor());
    await app.init();
  });

  afterAll(async () => app.close());

  it("wraps successful responses and preserves a caller request id", async () => {
    const response = await request(app.getHttpServer())
      .get("/api/v1/health")
      .set("x-request-id", "test-request-id")
      .expect(200);

    expect(response.headers["x-request-id"]).toBe("test-request-id");
    expect(response.body).toEqual({
      data: { status: "ok", service: "classtrace-api" },
      requestId: "test-request-id"
    });
  });

  it("returns the stable error envelope for an unknown route", async () => {
    const response = await request(app.getHttpServer())
      .get("/api/v1/not-found")
      .expect(404);

    expect(response.body.error.code).toBe("NOT_FOUND");
    expect(response.body.requestId).toEqual(expect.any(String));
  });
});
