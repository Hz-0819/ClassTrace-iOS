import { Inject, Injectable } from "@nestjs/common";
import { createPublicKey, JsonWebKey as CryptoJsonWebKey, randomInt } from "node:crypto";
import jwt, { JwtHeader, JwtPayload } from "jsonwebtoken";
import { hash, verify } from "argon2";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";
import { AppleLoginDto, RequestPhoneCodeDto, VerifyPhoneCodeDto } from "./identity.dto";
import { SMS_PROVIDER, SmsProvider } from "./sms.provider";
import { TokenService } from "./token.service";

@Injectable()
export class IdentityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider
  ) {}

  async requestPhoneCode(dto: RequestPhoneCodeDto): Promise<{ expiresIn: number; developmentCode?: string }> {
    const recent = await this.prisma.otpChallenge.count({
      where: { phone: dto.phone, createdAt: { gte: new Date(Date.now() - 60_000) } }
    });
    if (recent > 0) throw new DomainException("OTP_RATE_LIMITED", "验证码发送过于频繁", 429);
    const code = randomInt(0, 1_000_000).toString().padStart(6, "0");
    const challenge = await this.prisma.otpChallenge.create({
      data: {
        phone: dto.phone,
        purpose: dto.purpose,
        codeHash: await hash(code),
        expiresAt: new Date(Date.now() + 5 * 60_000)
      }
    });
    try { await this.sms.sendVerificationCode(dto.phone, code); }
    catch (error) { await this.prisma.otpChallenge.delete({ where: { id: challenge.id } }); throw error; }
    return process.env.NODE_ENV === "production" ? { expiresIn: 300 } : { expiresIn: 300, developmentCode: code };
  }

  async verifyPhoneCode(dto: VerifyPhoneCodeDto) {
    const challenge = await this.prisma.otpChallenge.findFirst({
      where: { phone: dto.phone, purpose: dto.purpose, consumedAt: null },
      orderBy: { createdAt: "desc" }
    });
    if (!challenge || challenge.expiresAt <= new Date() || challenge.attemptCount >= 5) {
      throw new DomainException("OTP_INVALID", "验证码无效或已过期", 401);
    }
    const valid = await verify(challenge.codeHash, dto.code);
    if (!valid) {
      await this.prisma.otpChallenge.update({ where: { id: challenge.id }, data: { attemptCount: { increment: 1 } } });
      throw new DomainException("OTP_INVALID", "验证码错误", 401);
    }

    const result = await this.prisma.$transaction(async (tx) => {
      await tx.otpChallenge.update({ where: { id: challenge.id }, data: { consumedAt: new Date() } });
      let identity = await tx.userIdentity.findUnique({
        where: { provider_providerSubject: { provider: "PHONE", providerSubject: dto.phone } },
        include: { user: { include: { roles: true } } }
      });
      if (!identity) {
        const role = dto.role ?? "GUARDIAN";
        const user = await tx.user.create({
          data: {
            displayName: dto.displayName?.trim() || `用户${dto.phone.slice(-4)}`,
            identities: { create: { provider: "PHONE", providerSubject: dto.phone, verifiedAt: new Date() } },
            roles: { create: { role } }
          },
          include: { roles: true }
        });
        identity = await tx.userIdentity.findFirstOrThrow({
          where: { userId: user.id, provider: "PHONE" },
          include: { user: { include: { roles: true } } }
        });
      }
      return identity.user;
    });

    const session = await this.tokens.issue(result.id, result.roles.map((item) => item.role));
    return { user: result, ...session };
  }

  async loginWithApple(dto: AppleLoginDto) {
    const decoded = jwt.decode(dto.identityToken, { complete: true });
    const header = decoded?.header as JwtHeader | undefined;
    if (!header?.kid) throw new DomainException("APPLE_TOKEN_INVALID", "Apple 身份令牌无效", 401);
    const response = await fetch("https://appleid.apple.com/auth/keys");
    if (!response.ok) throw new DomainException("APPLE_UNAVAILABLE", "Apple 登录服务暂时不可用", 503);
    const keys = await response.json() as { keys: Array<CryptoJsonWebKey & { kid: string }> };
    const jwk = keys.keys.find((item) => item.kid === header.kid);
    if (!jwk) throw new DomainException("APPLE_KEY_NOT_FOUND", "无法验证 Apple 身份令牌", 401);
    const audience = process.env.APPLE_CLIENT_ID ?? "com.classtrace.ios";
    let claims: JwtPayload;
    try {
      claims = jwt.verify(dto.identityToken, createPublicKey({ key: jwk, format: "jwk" }), { algorithms: ["RS256"], issuer: "https://appleid.apple.com", audience }) as JwtPayload;
    } catch { throw new DomainException("APPLE_TOKEN_INVALID", "Apple 身份令牌验签失败", 401); }
    if (!claims.sub || claims.nonce !== dto.nonce) throw new DomainException("APPLE_NONCE_MISMATCH", "Apple 登录请求已失效，请重试", 401);
    let identity = await this.prisma.userIdentity.findUnique({
      where: { provider_providerSubject: { provider: "APPLE", providerSubject: claims.sub } },
      include: { user: { include: { roles: true } } }
    });
    if (!identity) {
      const user = await this.prisma.user.create({
        data: {
          displayName: dto.fullName?.trim() || "Apple 用户",
          identities: { create: { provider: "APPLE", providerSubject: claims.sub, verifiedAt: new Date() } },
          roles: { create: { role: dto.role ?? "GUARDIAN" } }
        }, include: { roles: true }
      });
      identity = await this.prisma.userIdentity.findFirstOrThrow({ where: { userId: user.id, provider: "APPLE" }, include: { user: { include: { roles: true } } } });
    }
    return { user: identity.user, ...(await this.tokens.issue(identity.user.id, identity.user.roles.map((item) => item.role))) };
  }
}
