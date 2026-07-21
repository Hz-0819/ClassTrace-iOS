import { Injectable } from "@nestjs/common";
import { readFileSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import { Environment, JWSTransactionDecodedPayload, SignedDataVerifier } from "@apple/app-store-server-library";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";

@Injectable()
export class AppStoreService {
  constructor(private readonly prisma: PrismaService) {}

  private verifier(): SignedDataVerifier {
    const paths = (process.env.APPLE_ROOT_CA_PATHS ?? "").split(",").map((item) => item.trim()).filter(Boolean);
    const bundleId = process.env.APPLE_BUNDLE_ID ?? "com.classtrace.ios";
    if (!paths.length) throw new DomainException("APP_STORE_NOT_CONFIGURED", "App Store 验证证书尚未配置", 503);
    const environment = process.env.APPLE_ENVIRONMENT === "production" ? Environment.PRODUCTION : Environment.SANDBOX;
    const appAppleId = process.env.APPLE_APP_ID ? Number(process.env.APPLE_APP_ID) : undefined;
    return new SignedDataVerifier(paths.map((path) => readFileSync(path)), true, environment, bundleId, appAppleId);
  }

  private async persist(userId: string, payload: JWSTransactionDecodedPayload, signedTransaction: string) {
    const { transactionId, originalTransactionId, productId, purchaseDate } = payload;
    if (!transactionId || !originalTransactionId || !productId || !purchaseDate) throw new DomainException("INVALID_APP_STORE_TRANSACTION", "App Store 交易字段不完整", 422);
    if (payload.appAccountToken && payload.appAccountToken.toLowerCase() !== userId.toLowerCase()) throw new DomainException("APP_STORE_ACCOUNT_MISMATCH", "购买记录不属于当前账号", 403);
    const expiresAt = payload.expiresDate ? new Date(payload.expiresDate) : undefined;
    const revokedAt = payload.revocationDate ? new Date(payload.revocationDate) : undefined;
    const status = revokedAt ? "REVOKED" : expiresAt && expiresAt <= new Date() ? "EXPIRED" : "ACTIVE";
    return this.prisma.$transaction(async (tx) => {
      const subscription = await tx.subscription.upsert({
        where: { originalTransactionId },
        create: { userId, productId, originalTransactionId, status, expiresAt },
        update: { productId, status, expiresAt }
      });
      if (subscription.userId !== userId) throw new DomainException("APP_STORE_TRANSACTION_OWNED", "该购买记录已绑定其他账号", 409);
      await tx.appStoreTransaction.upsert({
        where: { transactionId },
        create: { subscriptionId: subscription.id, transactionId, originalTransactionId, productId, purchasedAt: new Date(purchaseDate), expiresAt, revokedAt, signedTransaction },
        update: { expiresAt, revokedAt, signedTransaction }
      });
      const entitlement = await tx.entitlement.upsert({ where: { key: "VIP" }, create: { key: "VIP", description: "ClassTrace VIP" }, update: {} });
      await tx.entitlementGrant.upsert({
        where: { subscriptionId_entitlementId_startsAt: { subscriptionId: subscription.id, entitlementId: entitlement.id, startsAt: new Date(purchaseDate) } },
        create: { subscriptionId: subscription.id, entitlementId: entitlement.id, startsAt: new Date(purchaseDate), endsAt: revokedAt ?? expiresAt, value: { active: status === "ACTIVE", productId } },
        update: { endsAt: revokedAt ?? expiresAt, value: { active: status === "ACTIVE", productId } }
      });
      return subscription;
    });
  }

  async verifyTransaction(userId: string, signedTransaction: string) {
    try { return await this.persist(userId, await this.verifier().verifyAndDecodeTransaction(signedTransaction), signedTransaction); }
    catch (error) { if (error instanceof DomainException) throw error; throw new DomainException("APP_STORE_VERIFICATION_FAILED", "无法验证 App Store 交易", 422); }
  }

  async processNotification(signedPayload: string) {
    try {
      const payload = await this.verifier().verifyAndDecodeNotification(signedPayload);
      const signedTransaction = payload.data?.signedTransactionInfo;
      if (!signedTransaction) return { processed: true, type: payload.notificationType };
      const transaction = await this.verifier().verifyAndDecodeTransaction(signedTransaction);
      const userId = transaction.appAccountToken;
      if (!userId) throw new DomainException("APP_ACCOUNT_TOKEN_MISSING", "通知中缺少账号标识", 422);
      await this.persist(userId, transaction, signedTransaction);
      return { processed: true, type: payload.notificationType };
    } catch (error) { if (error instanceof DomainException) throw error; throw new DomainException("APP_STORE_NOTIFICATION_INVALID", "App Store 通知验签失败", 422); }
  }

  async entitlements(userId: string) {
    const now = new Date();
    const grants = await this.prisma.entitlementGrant.findMany({ where: { subscription: { userId }, startsAt: { lte: now }, OR: [{ endsAt: null }, { endsAt: { gt: now } }] }, include: { entitlement: true, subscription: true } });
    return { active: grants.some((grant) => grant.entitlement.key === "VIP" && grant.subscription.status === "ACTIVE"), grants };
  }

  async createActivationCode(adminId: string, days: number) {
    const code = randomBytes(10).toString("hex").toUpperCase();
    await this.prisma.activationCode.create({ data: { codeHash: createHash("sha256").update(code).digest("hex"), createdById: adminId, grant: { entitlement: "VIP", days } } });
    return { code, days };
  }

  async redeemActivationCode(userId: string, code: string) {
    const codeHash = createHash("sha256").update(code.trim().toUpperCase()).digest("hex");
    return this.prisma.$transaction(async (tx) => {
      const activation = await tx.activationCode.findUnique({ where: { codeHash } });
      if (!activation || activation.usedAt || activation.expiresAt && activation.expiresAt <= new Date()) throw new DomainException("ACTIVATION_CODE_INVALID", "激活码无效、已使用或已过期", 400);
      const days = Number((activation.grant as { days?: number }).days ?? 0);
      if (days <= 0) throw new DomainException("ACTIVATION_GRANT_INVALID", "激活码权益配置无效", 422);
      const used = await tx.activationCode.updateMany({ where: { id: activation.id, usedAt: null }, data: { usedAt: new Date(), usedById: userId } });
      if (!used.count) throw new DomainException("ACTIVATION_CODE_USED", "激活码已被使用", 409);
      const startsAt = new Date(), endsAt = new Date(startsAt.getTime() + days * 86400_000);
      const subscription = await tx.subscription.create({ data: { userId, productId: "internal.vip", originalTransactionId: `activation:${activation.id}`, status: "ACTIVE", expiresAt: endsAt } });
      const entitlement = await tx.entitlement.upsert({ where: { key: "VIP" }, create: { key: "VIP", description: "ClassTrace VIP" }, update: {} });
      await tx.entitlementGrant.create({ data: { subscriptionId: subscription.id, entitlementId: entitlement.id, value: { active: true, source: "activation" }, startsAt, endsAt } });
      return subscription;
    }, { isolationLevel: "Serializable" });
  }
}
