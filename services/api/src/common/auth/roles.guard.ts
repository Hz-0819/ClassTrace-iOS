import { CanActivate, ExecutionContext, Injectable, SetMetadata } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { DomainException } from "../http/domain.exception";
import { AuthenticatedUser } from "./authenticated-user";

export const ROLES_KEY = "roles";
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [context.getHandler(), context.getClass()]) ?? [];
    if (required.length === 0) return true;
    const user = context.switchToHttp().getRequest<{ user?: AuthenticatedUser }>().user;
    if (!user || !required.some((role) => user.roles.includes(role))) {
      throw new DomainException("FORBIDDEN", "当前身份无权执行此操作", 403);
    }
    return true;
  }
}
