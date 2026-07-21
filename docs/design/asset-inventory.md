# 素材迁移清单

来源：只读复制自 `C:\Users\86184\Desktop\ClassTrace\miniprogram\images`。

## 统计

- 已复制 PNG：75 个。
- 常规功能图标：大部分为 48x48 PNG。
- 品牌主图：`icon.png`，2884x2884。
- 空状态：`null.png`，200x200。
- 背景装饰：`bgcircle.png`、`wave.png`。

所有原图保存在 `ClassTrace/Resources/LegacyImages`，作为迁移源，不直接等同于最终 Asset Catalog。

## 使用规则

| 类型 | 处理方式 |
|---|---|
| 首页、返回、时间、用户等通用图标 | 优先替换为 SF Symbols |
| 班级、学生、账单、VIP 等品牌图标 | 重新导出矢量 PDF 或 1x/2x/3x |
| App Icon | 使用 `icon.png` 原稿在 macOS 生成完整 AppIcon 集合 |
| 插画和空状态 | 检查深色背景与高分屏后复用 |
| 重复文件 | Asset Catalog 阶段合并，不在代码中出现重复资源名 |

## 第一批品牌资源

- `icon.png`
- `class-blue.png`
- `student-blue.png`
- `time-blue.png`
- `wallet-blue.png`
- `reminder-blue.png`
- `report-blue.png`
- `vip-yellow.png`
- `teacher-mode.png`
- `boy.png`
- `girl.png`

最终资源必须在 Xcode 中通过“缺失资源、重复名称、深色模式、放大显示”四项检查。

