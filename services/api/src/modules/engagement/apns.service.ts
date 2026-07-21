import { Injectable } from "@nestjs/common";
import { createDecipheriv, createHash } from "node:crypto";
import { connect } from "node:http2";
import { readFileSync } from "node:fs";
import jwt from "jsonwebtoken";

@Injectable()
export class ApnsService {
  private decrypt(ciphertext: string): string {
    const material = process.env.DEVICE_TOKEN_KEY;
    if (!material) throw new Error("DEVICE_TOKEN_KEY is required");
    const value = Buffer.from(ciphertext, "base64"), iv = value.subarray(0, 12), tag = value.subarray(12, 28), encrypted = value.subarray(28);
    const decipher = createDecipheriv("aes-256-gcm", createHash("sha256").update(material).digest(), iv); decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString("utf8");
  }
  async send(tokenCiphertext: string, environment: string, title: string, body: string, data: Record<string, string>) {
    const keyPath = process.env.APNS_KEY_PATH, keyId = process.env.APNS_KEY_ID, teamId = process.env.APNS_TEAM_ID, topic = process.env.APPLE_BUNDLE_ID ?? "com.classtrace.ios";
    if (!keyPath || !keyId || !teamId) throw new Error("APNs credentials are not configured");
    const authorization = jwt.sign({}, readFileSync(keyPath), { algorithm: "ES256", keyid: keyId, issuer: teamId, expiresIn: "50m" });
    const origin = environment === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
    const client = connect(origin), token = this.decrypt(tokenCiphertext);
    return new Promise<{ providerId?: string }>((resolve, reject) => {
      const request = client.request({ ":method": "POST", ":path": `/3/device/${token}`, authorization: `bearer ${authorization}`, "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10" });
      let status = 0, providerId: string | undefined, response = "";
      request.on("response", (headers) => { status = Number(headers[":status"]); providerId = String(headers["apns-id"] ?? ""); });
      request.on("data", (chunk) => { response += chunk; });
      request.on("end", () => { client.close(); status >= 200 && status < 300 ? resolve({ providerId }) : reject(new Error(`APNS_${status}:${response}`)); });
      request.on("error", (error) => { client.close(); reject(error); });
      request.end(JSON.stringify({ aps: { alert: { title, body }, sound: "default" }, ...data }));
    });
  }
}
