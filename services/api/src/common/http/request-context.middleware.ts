import { Injectable, NestMiddleware } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { NextFunction, Response } from "express";
import { RequestWithId } from "./request-with-id";

@Injectable()
export class RequestContextMiddleware implements NestMiddleware {
  use(request: RequestWithId, response: Response, next: NextFunction): void {
    const incoming = request.header("x-request-id");
    request.requestId = incoming && incoming.length <= 128 ? incoming : randomUUID();
    response.setHeader("x-request-id", request.requestId);
    next();
  }
}

