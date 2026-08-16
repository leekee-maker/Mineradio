# SelfRadio 设计验收

- 视觉基准：方案 1（舞台灯光、深色沉浸感、大号品牌字、双平台下载入口）
- 实现截图：`design-implementation.png`
- 移动端截图：`design-mobile.png`
- 对照截图：`design-comparison.png`
- 桌面视口：1440 × 900
- 移动视口：390 × 844
- 页面状态：默认首页，macOS 平台优先

## 验收结果

- 品牌、舞台氛围、主标题、双平台下载区和产品预览与方案 1 一致。
- 中部产品预览替换为 SelfRadio 实际启动界面。
- Windows、macOS 下载入口均指向可配置地址；默认使用 GitHub Releases。
- 390px 下无横向溢出，下载按钮保持完整。
- 页面控制台无错误或警告。
- 生产构建成功，静态入口与回退测试 4/4 通过。

## 调整记录

- 将 Mineradio 全部替换为 SelfRadio。
- 域名更新为 `radio.remjdor.cn`。
- 根据访客系统自动优先展示 macOS 或 Windows 下载按钮。
- 保留方案 1 的三段式结构：下载主视觉、产品预览、功能与最终下载。

最终结果：通过。
