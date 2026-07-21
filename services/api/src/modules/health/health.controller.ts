import { Controller, Get } from "@nestjs/common";
import { ApiOkResponse, ApiTags } from "@nestjs/swagger";

interface HealthStatus {
  status: "ok";
  service: "classtrace-api";
}

@ApiTags("health")
@Controller("health")
export class HealthController {
  @Get()
  @ApiOkResponse({ description: "API process is healthy" })
  getHealth(): HealthStatus {
    return { status: "ok", service: "classtrace-api" };
  }
}

