import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus
} from "@nestjs/common";
import { Response } from "express";
import { DomainException } from "./domain.exception";
import { RequestWithId } from "./request-with-id";

interface ErrorBody {
  error: {
    code: string;
    message: string;
    details: Record<string, unknown>;
  };
  requestId: string;
}

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const request = http.getRequest<RequestWithId>();
    const response = http.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = "INTERNAL_ERROR";
    let message = "服务暂时不可用";
    let details: Record<string, unknown> = {};

    if (exception instanceof DomainException) {
      status = exception.status;
      code = exception.code;
      message = exception.message;
      details = exception.details;
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      code = this.httpCode(status);
      const payload = exception.getResponse();
      if (typeof payload === "string") {
        message = payload;
      } else if (payload && typeof payload === "object") {
        const body = payload as Record<string, unknown>;
        const payloadMessage = body.message;
        message = Array.isArray(payloadMessage)
          ? payloadMessage.join("; ")
          : String(payloadMessage ?? exception.message);
        if (Array.isArray(payloadMessage)) details = { validation: payloadMessage };
      }
    }

    const body: ErrorBody = {
      error: { code, message, details },
      requestId: request.requestId
    };
    response.status(status).json(body);
  }

  private httpCode(status: number): string {
    const codes: Record<number, string> = {
      400: "BAD_REQUEST",
      401: "UNAUTHENTICATED",
      403: "FORBIDDEN",
      404: "NOT_FOUND",
      409: "CONFLICT",
      422: "VALIDATION_ERROR",
      429: "RATE_LIMITED"
    };
    return codes[status] ?? "HTTP_ERROR";
  }
}

