import { CanActivate, ExecutionContext, Injectable } from "@nestjs/common";
import { DomainException } from "../http/domain.exception";
import { TokenService } from "../../modules/identity/token.service";
import { AuthenticatedUser } from "./authenticated-user";

type RequestWithUser = { headers: Record<string, string | string[] | undefined>; user?: AuthenticatedUser };

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly tokens: TokenService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const header = request.headers.authorization;
    const value = Array.isArray(header) ? header[0] : header;
    if (!value?.startsWith("Bearer ")) throw new DomainException("UNAUTHENTICATED", "请先登录", 401);
    try {
      const claims = this.tokens.verifyAccessToken(value.slice(7));
      request.user = { id: claims.sub, roles: claims.roles, sessionId: claims.sessionId };
      return true;
    } catch {
      throw new DomainException("UNAUTHENTICATED", "登录状态已失效", 401);
    }
  }
}
