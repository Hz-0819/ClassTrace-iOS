import { Injectable } from "@nestjs/common";
import { createHash, randomBytes } from "node:crypto";
import jwt from "jsonwebtoken";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";

export type AccessClaims = { sub: string; roles: string[]; sessionId: string };

@Injectable()
export class TokenService {
  constructor(private readonly prisma: PrismaService) {}

  private secret(): string {
    const value = process.env.JWT_SECRET;
    if (!value || value.length < 32) {
      if (process.env.NODE_ENV === "production") throw new Error("JWT_SECRET must contain at least 32 characters");
      return "classtrace-local-development-secret-change-me";
    }
    return value;
  }

  hash(value: string): string {
    return createHash("sha256").update(value).digest("hex");
  }

  verifyAccessToken(token: string): AccessClaims {
    return jwt.verify(token, this.secret(), { algorithms: ["HS256"] }) as AccessClaims;
  }

  async issue(userId: string, roles: string[]): Promise<{ accessToken: string; refreshToken: string; expiresIn: number }> {
    const refreshToken = randomBytes(48).toString("base64url");
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    const session = await this.prisma.authSession.create({
      data: { userId, refreshTokenHash: this.hash(refreshToken), expiresAt }
    });
    const expiresIn = 15 * 60;
    const accessToken = jwt.sign({ roles, sessionId: session.id }, this.secret(), {
      algorithm: "HS256",
      subject: userId,
      expiresIn
    });
    return { accessToken, refreshToken, expiresIn };
  }

  async rotate(refreshToken: string): Promise<{ accessToken: string; refreshToken: string; expiresIn: number }> {
    const now = new Date();
    const session = await this.prisma.authSession.findUnique({
      where: { refreshTokenHash: this.hash(refreshToken) },
      include: { user: { include: { roles: true } } }
    });
    if (!session || session.revokedAt || session.expiresAt <= now || session.user.status !== "ACTIVE") {
      throw new DomainException("INVALID_REFRESH_TOKEN", "登录状态已失效，请重新登录", 401);
    }
    await this.prisma.authSession.update({ where: { id: session.id }, data: { revokedAt: now, lastUsedAt: now } });
    return this.issue(session.userId, session.user.roles.map((item) => item.role));
  }

  async revoke(refreshToken: string): Promise<void> {
    await this.prisma.authSession.updateMany({
      where: { refreshTokenHash: this.hash(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() }
    });
  }
}
