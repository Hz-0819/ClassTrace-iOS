import { Injectable } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { extname } from "node:path";
import COS = require("cos-nodejs-sdk-v5");
import { DomainException } from "../../common/http/domain.exception";
import { PrismaService } from "../../database/prisma.service";

@Injectable()
export class StorageService {
  constructor(private readonly prisma: PrismaService) {}
  private configuration() {
    const SecretId = process.env.TENCENT_SECRET_ID, SecretKey = process.env.TENCENT_SECRET_KEY;
    const Bucket = process.env.COS_BUCKET, Region = process.env.COS_REGION;
    if (!SecretId || !SecretKey || !Bucket || !Region) throw new DomainException("STORAGE_NOT_CONFIGURED", "对象存储尚未配置", 503);
    return { cos: new COS({ SecretId, SecretKey }), Bucket, Region };
  }
  createUploadIntent(userId: string, fileName: string, mimeType: string, sizeBytes: number) {
    const allowed = ["image/jpeg", "image/png", "image/heic", "application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"];
    if (!allowed.includes(mimeType)) throw new DomainException("FILE_TYPE_NOT_ALLOWED", "不支持该文件类型", 422);
    if (sizeBytes <= 0 || sizeBytes > 50_000_000) throw new DomainException("FILE_TOO_LARGE", "文件大小必须在 50MB 以内", 422);
    const extension = extname(fileName).replace(/[^a-zA-Z0-9.]/g, "").slice(0, 12);
    const objectKey = `users/${userId}/${new Date().toISOString().slice(0, 10)}/${randomUUID()}${extension}`;
    const { cos, Bucket, Region } = this.configuration();
    return { objectKey, uploadUrl: cos.getObjectUrl({ Bucket, Region, Key: objectKey, Method: "PUT", Sign: true, Expires: 600 }), method: "PUT", headers: { "Content-Type": mimeType }, expiresIn: 600 };
  }
  async downloadUrl(userId: string, objectKey: string) {
    const allowed = objectKey.startsWith(`users/${userId}/`) || await this.prisma.material.count({ where: { objectKey, deletedAt: null, OR: [{ uploaderId: userId }, { classroom: { members: { some: { student: { guardians: { some: { guardianUserId: userId } } } } } } }] } }) > 0;
    if (!allowed) throw new DomainException("FILE_NOT_FOUND", "文件不存在或无权访问", 404);
    const { cos, Bucket, Region } = this.configuration();
    return { url: cos.getObjectUrl({ Bucket, Region, Key: objectKey, Method: "GET", Sign: true, Expires: 300 }), expiresIn: 300 };
  }
}
