# ClassTrace iOS 设计系统

## 1. 视觉原则

- 保留原小程序的温和莫兰迪气质与蓝色主品牌。
- 使用 iOS 原生层级、导航、手势和权限交互。
- 信息密度适合教师快速记课和确认上课，不追求装饰性堆叠。
- 支持动态字体、VoiceOver、深色模式与“减少动态效果”。

## 2. 品牌色

| Token | Light | Dark | 用途 |
|---|---|---|---|
| `brand.primary` | `#7BA3C0` | `#8FB5CF` | 主按钮、选中状态 |
| `brand.pink` | `#E8B4A8` | `#C99A91` | 课程主题 |
| `brand.green` | `#6AA08A` | `#7DB39C` | 成功与课程主题 |
| `brand.orange` | `#D4A574` | `#E0B483` | 提醒与课程主题 |
| `brand.purple` | `#B8A8C8` | `#BFAFD0` | 课程主题 |
| `surface.page` | `#F5F7FA` | `#111418` | 页面背景 |
| `surface.card` | `#FFFFFF` | `#1C2025` | 卡片背景 |
| `text.primary` | `#222222` | `#F2F4F7` | 主要文字 |
| `text.secondary` | `#6F7782` | `#AEB6C1` | 次要文字 |
| `status.danger` | `#D9576B` | `#EE7183` | 删除、失败 |

文本与背景组合必须达到 WCAG AA。颜色不是状态的唯一表达方式，需同时使用图标或文本。

## 3. 字体与间距

只使用系统字体并支持 Dynamic Type。标题使用系统语义样式，不硬编码固定字号。

```text
Spacing: 4, 8, 12, 16, 20, 24, 32, 40
Radius: 8, 12, 16, 24
Minimum tap target: 44 x 44 pt
Page horizontal padding: 16 pt
Card padding: 16 pt
```

## 4. 导航

第一版三栏：

- 首页：角色化工作台。
- 班级：班级列表、详情和管理入口。
- 我的：账号、通知、账单、VIP 与设置。

日程作为教师首页和班级页的一级入口，不额外增加第四个 Tab，避免破坏现有心智。使用原生 `NavigationStack`、sheet、confirmation dialog 和 swipe action。

## 5. 组件

- `CTPrimaryButton`：主操作，加载时禁用并显示进度。
- `CTCard`：统一卡片背景、圆角和内容间距。
- `CTStatusBadge`：图标 + 文本 + 颜色。
- `CTEmptyState`：标题、解释、单一主操作。
- `CTErrorState`：可理解错误和重试操作。
- `CTSkeleton`：列表与首页加载状态。
- `CTMoneyText`：统一分转元、货币与负数格式。
- `CTHoursText`：统一 0.5/1/1.5 等课时显示。

## 6. 素材策略

- `icon.png` 可作为 App Icon 原始来源，需在 macOS 重新导出完整 AppIcon 尺寸。
- 48x48 PNG 只作为视觉参考或低密度装饰，不直接用于高分辨率核心图标。
- 常用操作优先使用 SF Symbols，以获得动态字体、粗细和深色模式适配。
- 具有品牌识别度的课程、课时和角色图标可复制到 Asset Catalog，并补充 1x/2x/3x 或转换为矢量 PDF。
- 所有复用素材保留来源清单，避免无法追踪的重复图片。

## 7. 必测状态

每个页面至少覆盖 loading、empty、content、error、offline、permission denied。表单还需覆盖键盘、安全区域、验证错误、重复提交和弱网恢复。

