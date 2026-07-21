# iOS 本地优先测试模式

当前 `codex/ios-miniprogram-parity` 分支在 `DEMO_MODE` 下使用 iPhone 本地存储，不依赖腾讯云或新服务端。

## 存储范围

- 班级、学生、课程模板、课节、作业、资料索引、学习计划、错题、反馈、日程和账单写入 Application Support 下的账号独立 JSON 数据库。
- 上传的教学资料复制到 Application Support/ClassTrace/LocalMaterials，资料记录保存相应本地路径。
- 测试账号资料保存在 UserDefaults；密码只保存在 iOS Keychain，不进入 JSON、日志或 Git。
- 每个本地账号使用独立业务数据库。默认测试账号为 `demo`，密码为 `123456`。

## 服务端迁移边界

SwiftUI 页面只调用 `ClassTraceRepository`，不直接读取本地文件。以后接入服务端时继续沿用相同领域模型和仓库接口，把 `HTTPClient` 的测试路由切换为真实 API，并增加一次本地数据上传/合并流程即可。

## 测试提示

- 第一次安装会直接进入默认演示账号，方便连续验证功能。
- 在“我的”点击“退出演示模式”后会进入与小程序一致的账号密码登录页，可测试本地注册和登录。
- 卸载 App 会同时删除沙盒里的业务数据；钥匙串项目可能由系统保留，因此重新安装时同名测试账号可能仍需要原密码。
