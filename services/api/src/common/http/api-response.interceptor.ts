import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor
} from "@nestjs/common";
import { Observable, map } from "rxjs";
import { RequestWithId } from "./request-with-id";

export interface ApiSuccess<T> {
  data: T;
  requestId: string;
}

@Injectable()
export class ApiResponseInterceptor<T> implements NestInterceptor<T, ApiSuccess<T>> {
  intercept(context: ExecutionContext, next: CallHandler<T>): Observable<ApiSuccess<T>> {
    const request = context.switchToHttp().getRequest<RequestWithId>();
    return next.handle().pipe(map((data) => ({ data, requestId: request.requestId })));
  }
}

