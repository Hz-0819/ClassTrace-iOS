# ClassTrace iOS 全量重构

这是课迹微信小程序的独立 iOS 与服务端重构项目。原项目 `C:\Users\86184\Desktop\ClassTrace` 始终只读；所有新代码位于本目录。

本项目不是 MVP：已按原小程序 24 个服务域覆盖账号、学生与监护人、课程班级、排课考勤、课时账本、作业资料、学习计划、错题、积分、通知公告、反馈、账单退款、VIP 和历史数据迁移。教学课费默认由家长与教师通过微信、支付宝、现金或银行等外部渠道直接结算；平台记录双方确认的账单、课时和履约，不形成资金池。VIP 是 App 内数字权益，使用 StoreKit 2。

## 目录

- `ClassTrace/`：SwiftUI iOS 客户端
- `ClassTraceTests/`：iOS 单元测试
- `services/api/`：NestJS、Prisma、PostgreSQL 服务端
- `docs/architecture/`：架构、ADR 与全量验收矩阵
- `docs/runbook.md`：本地运行、迁移和发布配置
- `project.yml`：XcodeGen 工程配置
- `docker-compose.yml`：本地 PostgreSQL 与 API

## 快速验证

后端在 `services/api` 运行 `npm ci`、`npm run build`、`npm test`、`npm run test:e2e`。根目录运行 `npm run verify:ios`。iOS 工程必须在 macOS 安装 XcodeGen 后执行 `xcodegen generate`，再由 Xcode 完成签名、真机推送、Sign in with Apple、StoreKit 沙盒和 UI 冒烟测试。

详细步骤与所有必须填写的外部配置见 [运行与发布手册](docs/runbook.md)。

## 免登录功能测试分支

分支 `codex/ios-no-auth-functional-test` 会在 Debug 和 Release 构建中启用本地演示模式：应用直接进入首页，使用本地样例身份和业务数据，不访问真实账号、短信、Apple 登录或生产 API。界面顶部会持续显示橙色演示标识，所有模拟操作在重启后复原。

该分支只用于页面和业务交互验收，不得合并为 App Store 正式版本。真实登录、APNs、StoreKit 和服务端联调仍在正式分支完成。
