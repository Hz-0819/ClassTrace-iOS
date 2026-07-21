# 运行、迁移与发布手册

## 1. 本地后端

1. 将 `services/api/.env.example` 复制为 `.env`，至少更换 `JWT_SECRET` 和 `DEVICE_TOKEN_KEY`。
2. 运行 `docker compose up -d postgres`。
3. 在 `services/api` 运行 `npm ci`、`npm run prisma:generate`、`npx prisma migrate deploy`、`npm run db:seed`、`npm run start:dev`。
4. 健康检查为 `http://localhost:3000/api/v1/health`，接口文档为 `http://localhost:3000/api/docs`。

## 2. 原 CloudBase 数据迁移

先从原环境导出每个集合为 `<collection>.json`、`<collection>.jsonl` 或 `<collection>/data.json`，然后运行：

```text
npm run migrate:cloudbase -- D:\path\to\cloudbase-export
```

迁移器幂等写入全部旧集合，并输出每个集合的读取、迁移和跳过数量。任何跳过项都表示父级用户、学生、班级或订单缺失，切换生产流量前必须清零或人工确认。旧明文密码不会迁移；旧微信 openid 仅作为兼容身份保存，iOS 登录改用手机号验证码或 Apple。

## 3. 必需外部配置

- 腾讯云短信：短信应用 ID、签名、模板和密钥。
- 腾讯云文本安全与 COS：内容安全业务类型、存储桶和地域。
- Apple 登录：Bundle ID/Service ID。
- APNs：Team ID、Key ID 与 `.p8` 文件。
- StoreKit：月度和年度商品 `com.classtrace.vip.monthly`、`com.classtrace.vip.yearly`；App Store Server API 根证书；Server Notifications 回调 `/api/v1/webhooks/app-store`。
- 正式 API 域名必须启用 HTTPS，并将 `project.yml` 的 `API_BASE_URL` 改为真实域名。

这些密钥和运营主体资料不能由代码自动生成，禁止提交到 Git。

## 4. iOS 工程

1. 在 macOS 安装当前稳定版 Xcode 与 XcodeGen。
2. 根目录运行 `xcodegen generate`，打开 `ClassTrace.xcodeproj`。
3. 填写开发团队，启用 Sign in with Apple、Push Notifications、In-App Purchase，并确认 entitlements 的生产推送环境由签名配置生成。
4. 使用 StoreKit 沙盒账号验证购买、续订、退款、撤销与恢复购买。
5. 使用真机验证 APNs、文件上传、相机/照片权限和后台通知。

## 5. 发布门禁

- 后端 build、unit、e2e、Prisma validate 全部通过。
- PostgreSQL 真实事务环境验证课节确认并发、幂等扣课时、撤销补偿流水、退款课时回退。
- 迁移报告逐集合核对，备份并演练回滚。
- Xcode 单元测试及教师/家长两套 UI 冒烟流程通过。
- 运营主体补全并经法务审核隐私政策、用户协议、客服与数据保存期限。
- App Store Connect 补全隐私标签、商品、服务器通知、审核账号和审核说明。
