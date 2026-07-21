import { Injectable } from "@nestjs/common";
import { createHash } from "node:crypto";
import { tms } from "tencentcloud-sdk-nodejs";
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";

@Injectable()
export class ContentSecurityService {
  constructor(private readonly prisma: PrismaService) {}
  async checkText(userId: string, content: string, contextId?: string) {
    const contentHash = createHash("sha256").update(content).digest("hex");
    let suggestion = "Pass", label = "Normal", provider = "local";
    if (process.env.TENCENT_SECRET_ID && process.env.TENCENT_SECRET_KEY) {
      const client = new tms.v20201229.Client({ credential: { secretId: process.env.TENCENT_SECRET_ID, secretKey: process.env.TENCENT_SECRET_KEY }, region: process.env.TENCENT_TMS_REGION ?? "ap-guangzhou", profile: { httpProfile: { endpoint: "tms.tencentcloudapi.com" } } });
      const result = await client.TextModeration({ Content: Buffer.from(content, "utf8").toString("base64"), BizType: process.env.TENCENT_TMS_BIZ_TYPE, DataId: contextId, User: { UserId: userId, AccountType: 7 }, SourceLanguage: "zh", Type: "TEXT" });
      suggestion = result.Suggestion ?? "Review"; label = result.Label ?? "Unknown"; provider = "tencent-tms";
    } else if (process.env.NODE_ENV === "production") {
      throw new DomainException("CONTENT_SECURITY_NOT_CONFIGURED", "内容安全服务尚未配置", 503);
    }
    await this.prisma.contentSecurityLog.create({ data: { userId, contentType: "text", contentHash, result: suggestion, provider, metadata: { label } } });
    return { allowed: suggestion === "Pass", suggestion, label };
  }
  async checkFile(userId: string, objectKey: string, mimeType: string, sizeBytes: number) {
    const allowedTypes = ["image/jpeg", "image/png", "image/heic", "application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"];
    const allowed = allowedTypes.includes(mimeType) && sizeBytes <= 50_000_000;
    await this.prisma.contentSecurityLog.create({ data: { userId, contentType: "file", contentHash: createHash("sha256").update(objectKey).digest("hex"), result: allowed ? "Pass" : "Block", provider: "file-policy", metadata: { mimeType, sizeBytes } } });
    return { allowed, suggestion: allowed ? "Pass" : "Block", label: allowed ? "Normal" : "FilePolicy" };
  }
}
