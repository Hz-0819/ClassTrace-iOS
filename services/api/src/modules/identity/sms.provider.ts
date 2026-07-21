import { Injectable } from "@nestjs/common";
import { sms } from "tencentcloud-sdk-nodejs";

export interface SmsProvider {
  sendVerificationCode(phone: string, code: string): Promise<void>;
}

export const SMS_PROVIDER = Symbol("SMS_PROVIDER");

@Injectable()
export class DevelopmentSmsProvider implements SmsProvider {
  async sendVerificationCode(_phone: string, _code: string): Promise<void> {
    if (process.env.NODE_ENV === "production") {
      throw new Error("A production SMS provider must be configured");
    }
  }
}

@Injectable()
export class TencentSmsProvider implements SmsProvider {
  async sendVerificationCode(phone: string, code: string): Promise<void> {
    const secretId = process.env.TENCENT_SECRET_ID, secretKey = process.env.TENCENT_SECRET_KEY;
    const SmsSdkAppId = process.env.TENCENT_SMS_APP_ID, SignName = process.env.TENCENT_SMS_SIGN_NAME, TemplateId = process.env.TENCENT_SMS_TEMPLATE_ID;
    if (!secretId || !secretKey || !SmsSdkAppId || !SignName || !TemplateId) {
      if (process.env.NODE_ENV === "production") throw new Error("Tencent SMS is not configured");
      return;
    }
    const client = new sms.v20210111.Client({ credential: { secretId, secretKey }, region: process.env.TENCENT_SMS_REGION ?? "ap-guangzhou", profile: { httpProfile: { endpoint: "sms.tencentcloudapi.com" } } });
    const result = await client.SendSms({ PhoneNumberSet: [phone], SmsSdkAppId, SignName, TemplateId, TemplateParamSet: [code, "5"] });
    const status = result.SendStatusSet?.[0];
    if (!status || status.Code !== "Ok") throw new Error(`SMS_SEND_FAILED:${status?.Code ?? "UNKNOWN"}`);
  }
}
