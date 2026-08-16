## iOS「我的」页方案 1（2026-08-08）

**Comparison target**

- Source visual truth: `docs/ui-design/ios-profile-option1-reference.png`
- Implementation screenshot: `docs/ui-design/ios-profile-option1-implementation.png`
- Combined comparison: `docs/ui-design/ios-profile-option1-comparison.png`
- Viewport: iPhone 16 simulator，393 × 852 pt，3×，深色外观。
- Source: 852 × 1846 px；implementation: 1179 × 2556 px。
- Density normalization: source 按相同宽高比缩放至 1179 × 2556 px 后并排比较。
- State: 3 首最近播放、Debug 预览歌单 3 项；正式数据与交互逻辑未被替换。

**Full-view comparison evidence**

- 双入口、最近常听三列、无容器歌单列表和底部导航的结构与方案一致。
- iOS 状态栏和 Home Indicator 属于系统运行时区域，不作为应用内容偏差。

**Focused region evidence**

- 顶部快捷入口、最近常听标题区和长歌单名称均在并排图中清晰可读；单行标题、元数据基线和尾部箭头保持对齐，无需额外局部放大。

**Required fidelity surfaces**

- Typography: 使用系统 SF Pro；30 pt 页面标题、17 pt 分区标题、15 pt 内容标题、12 pt 辅助文字；歌单名称单行尾部截断。
- Spacing/layout: 20 pt 页面边距、12 pt 双入口间距、108 pt 最近常听封面、78 pt 歌单行高；首屏密度与方案一致。
- Colors/tokens: 语义黑底、白/灰文字、rose/blue 双入口和 violet 账号入口沿用现有 token。
- Image quality/assets: 使用真实平台封面和 SF Symbols，没有新增占位图、自绘 SVG 或低清替代。
- Copy/content: 删除顶部重复的“收藏歌单”，保留“我的喜欢、最近播放、最近常听、我的歌单、查看全部”。

**Comparison history**

- P2: 首轮实现的最近常听封面为 132 pt，导致三列展示密度低于方案；标题区也缺少“查看全部”。
- Fix: 封面缩为 108 pt，并补齐“查看全部 + chevron”入口。
- Post-fix evidence: `docs/ui-design/ios-profile-option1-comparison.png` 显示三张封面完整进入首屏，标题区与方案层级一致。

**Findings**

- 无未解决的 P0/P1/P2 问题。

**Interactions tested**

- Debug 参数直达“我的”页并注入非持久预览数据；应用启动、页面加载和远程封面显示正常。
- 双入口、歌曲卡片、歌单行和查看全部均保留原有 NavigationLink/Button 实现。

**Follow-up polish**

- P3: 实际封面内容由用户数据决定，色彩节奏不会与静态效果图完全相同。

final result: passed

---

**Comparison target**

- Source visual truth: `docs/ui-design/selfradio-option-2-top-nav.png`
- Implementation: `docs/ui-design/selfradio-option-2-implementation.png`
- Source: 1487 × 1058 px; implementation: 1080 × 608 px (native app window capture, 1×)
- State: dark desktop home, logged-in account, current track available

**Full-view evidence**

- The implementation preserves the source hierarchy: persistent top navigation, one dominant continue card, three recommendation cards, animated particle background, account controls, and persistent bottom player.
- The 1080 × 608 app window uses a denser responsive composition than the larger source image. This is an intentional viewport adaptation rather than a density-normalized pixel match.

**Focused evidence**

- Navigation: active underline, labels, account area, and window controls remain readable without overlap.
- Content: the featured card retains primary emphasis and the recommendation cards remain independently actionable.
- Player: current-track identity, progress, transport, queue, volume, and visual-control affordances remain visible above the fold.

**Required fidelity surfaces**

- Typography: hierarchy and weight are consistent; narrower cards wrap Chinese recommendation titles at the compact viewport.
- Spacing/layout: major regions match the source structure; margins and gaps were reduced proportionally for 1080 × 608.
- Colors/tokens: dark neutral glass surfaces, white type, and restrained accent treatment are consistent.
- Image quality: existing album artwork and the native particle renderer are used; no placeholder or handcrafted replacement assets were introduced.
- Copy/content: real local library and current-track content replaces the illustrative mock data.

**Comparison history**

- P1: initial capture exposed the legacy library panel over the home screen. Fixed by unpinning/closing legacy panels when returning Home.
- P2: the global search field remained visible on Home. Fixed by showing it only for the Search navigation state.
- P1: the bottom player was hidden by the legacy home-control lock. Fixed by keeping the player visible in the home state.
- Post-fix evidence: `docs/ui-design/selfradio-option-2-implementation.png` shows the stable home state with all five navigation items, four content cards, and the bottom player visible.

**Findings**

- No actionable P0/P1/P2 findings remain at the tested viewport.

**Follow-up polish**

- P3: add navigation icons when the project adopts a consistent icon set.
- P3: reduce recommendation-title size slightly below 1100 px to minimize line wrapping.

**Interactions tested**

- Enter startup screen, open Home, open Settings, return Home, and verify legacy panels close.
- Electron accessibility tree exposed the five navigation actions and playback controls. No blocking runtime dialog appeared.

**Implementation checklist**

- [x] Stable top navigation
- [x] Simplified home composition
- [x] Search hidden until requested
- [x] Persistent compact player
- [x] macOS arm64 directory build

final result: passed

---

## iOS 融合开屏（2026-08-08）

**Comparison target**

- Source visual truth: `/Users/tcg/.codex/generated_images/019fbe17-b71d-72e1-ad15-49ab546ad14f/exec-cbc44d7a-768d-4c8e-b345-5c5edf57e1c3.png`
- Implementation screenshot: `docs/ui-design/ios-launch-fusion-implementation.png`
- Initial comparison: `docs/ui-design/ios-launch-fusion-comparison-initial.png`
- Final comparison: `docs/ui-design/ios-launch-fusion-comparison-final.png`
- Viewport: iPhone 16 simulator，393 × 852 pt，3×。
- Source: 852 × 1846 px；implementation: 1179 × 2556 px。
- Density normalization: 两图按相同 1024 px 高度等比缩放后并排；内容宽高比一致。
- State: App 冷启动开屏已完全显现；截图复检后已移除临时延时，仅保留正式过渡时长。

**Full-view comparison evidence**

- 第二轮合并对照中，渐变流光、音符/波形、标题、副标题和加载环的构图、比例、颜色与源图一致。
- iOS 状态栏与 Home Indicator 是系统运行时区域；未栅格化进应用素材，也未作为设计偏差处理。

**Focused region evidence**

- 全屏对照在 1024 px 高度下已能清晰判断标题、细字、音符边缘、波形与加载环，没有需要额外放大的细小控件或交互状态。

**Required fidelity surfaces**

- Typography: 标题、副标题直接来自选定视觉资产，字重、间距、抗锯齿和换行均与源图一致。
- Spacing/layout: 采用 `scaledToFill` 全屏裁切；393 × 852 pt 画面与源图宽高比一致，核心构图无位移。
- Colors/tokens: 深黑底、青蓝/紫/玫红光带和白色品牌符号保持一致；无额外蒙层污染。
- Image quality/assets: 使用选定融合图的原始 PNG 作为 Asset Catalog 资源，没有占位符、自绘 SVG 或低清替代。
- Copy/content: “随心听 / 你的私人音乐现场”与源图完全一致。

**Comparison history**

- P1: 首轮截图中应用底部导航覆盖在开屏上，破坏沉浸式全屏效果。
- Fix: 将开屏从主 ZStack 内部移到根视图最终 overlay，覆盖 safe-area inset 产生的底部导航。
- Post-fix evidence: `docs/ui-design/ios-launch-fusion-comparison-final.png` 显示底部导航已消失，系统 Home Indicator 保持原生。

**Findings**

- 无未解决的 P0/P1/P2 问题。

**Interactions tested**

- 冷启动显示开屏；正常模式约 1.8 秒后进入首页。
- “减少动态效果”开启时约 0.8 秒进入首页。

**Follow-up polish**

- P3: 后续可按真实设备性能微调 1.45 秒停留时间，但当前总过渡节奏已在推荐范围内。

final result: passed

---

## iOS「我的哥」内容优先方案（2026-08-05）

**Comparison target**

- Source visual truth: `docs/ui-design/profile-content-first-reference.png`
- Implementation screenshot: `docs/ui-design/profile-content-first-implementation.png`
- Combined comparison: `docs/ui-design/profile-content-first-comparison.png`
- Viewport: iPhone 17 simulator，402 × 874 pt，深色外观。
- Source: 852 × 1846 px；implementation: 1206 × 2622 px at 3×。
- Density normalization: implementation 缩放至 852 × 1846 px，与 source 并排比较。
- State: source 使用完整示例数据；implementation 使用模拟器现有真实状态（1 首最近播放、0 个收藏歌单、2/3 平台可播放）。

**Full-view comparison evidence**

- 实现保留了图2的内容优先顺序：三项快捷入口、最近常听、我的歌单、平台状态、迷你播放器/Dock 区域。
- 真实数据不足时采用明确空状态，没有伪造收藏数或歌单。
- 系统状态栏和安全区属于 iOS 运行时区域，不作为应用内容偏差。

**Focused region evidence**

- 顶部快捷区、最近常听卡片和歌单空状态在合并对照图中均可清晰读取；主要触控入口没有重叠或截断，因此不需要额外局部放大。

**Required fidelity surfaces**

- Typography: 使用系统 SF Pro；30 pt 页面标题、17 pt 分区标题、15 pt 内容标题、12 pt 辅助文字，层级接近源图且真实长标题会单行截断。
- Spacing/layout: 20 pt 页面边距、26 pt 分区节奏、132 pt 最近常听封面；快捷入口使用分隔线而非卡片堆叠。
- Colors/tokens: 沿用语义黑色背景和现有 violet/blue/rose token，连接状态使用绿色/次级灰。
- Image quality/assets: 最近播放直接使用真实平台封面；图标全部使用清晰的 SF Symbols，没有占位图或自绘替代。
- Copy/content: 保留“我的哥、我的喜欢、最近播放、收藏歌单、最近常听、我的歌单、查看全部”等选定方案文案，数量和歌曲来自本地真实数据。

**Comparison history**

- P2: 首次类型检查发现 `EnumeratedSequence` 的 RandomAccessCollection 支持仅限 iOS 26。已改为兼容 iOS 17 的数组遍历。
- Post-fix evidence: iOS 17 目标类型检查和 iOS 26 模拟器完整构建均通过；实现截图无布局警告表现。

**Findings**

- 无未解决的 P0/P1/P2 视觉问题。

**Follow-up polish**

- P3: 当前真实状态只有 1 首最近播放，横向区域留白较多；随着用户播放记录增加会自然填充，无需伪造数据。
- P3: 当前未播放歌曲，因此截图中没有迷你播放器；实际播放时沿用已实现的固定迷你播放器。

**Interactions tested**

- 快捷入口、最近常听卡片、歌单入口、平台状态和偏好设置均为原生可交互控件。
- 模拟器安装并启动成功；未出现启动崩溃或布局阻塞。

final result: passed

---

## iOS「我的」页方案 2（2026-08-04）

**Comparison target**

- Source visual truth: `/Users/tcg/.codex/generated_images/019fa99e-323f-77e0-84cf-089369853b31/exec-8d896edf-8ca5-40e2-9134-d12bc0b46f15.png`
- Implementation screenshot: `/Users/tcg/Documents/cursor_project/Mineradio音乐播放器/profile-device-dark-final.png`
- Combined comparison: `/Users/tcg/Documents/cursor_project/Mineradio音乐播放器/profile-design-comparison-dark-final.png`
- Viewport: iPhone 17 simulator, 402 × 874 pt; dark appearance.
- Source: 853 × 1844 px; implementation: 1206 × 2622 px at 3×.
- Density normalization: both rendered to 844 px height; source 390 × 844 px, implementation 388 × 844 px.
- State: QQ 音乐、网易云可播放，汽水未连接，深色主题选中。

**Full-view comparison evidence**

- 实现保留了方案 2 的账号优先层级、三平台状态条、两组紧凑列表和内联外观切换。
- 实际数据替代模拟数量；底部导航沿用 SelfRadio 已有可交互组件，不影响信息层级。
- 系统状态栏属于 iOS 运行时区域，比较时不计为应用内容偏差。

**Focused region evidence**

- 归一化后整屏中的 10–17 pt 字号、分隔线、主题分段控件和平台状态仍清晰可读，无需额外局部放大图。

**Required fidelity surfaces**

- Typography: 系统 SF Pro，10/11/12/13/15/17 pt 分层，无截断、重叠或过大标题。
- Spacing/layout: 20 pt 外边距、56 pt 行高、16 pt 圆角，主要触控区均不小于 44 pt。
- Colors/tokens: 背景、容器、主文字、次文字和分隔线改为 iOS 语义色，浅色和深色均可读。
- Image quality/assets: 页面无栅格图占位符；头部使用清晰可缩放的 SF Symbols 波形品牌符号。
- Copy/content: 使用实际连接状态、最近播放数和收藏数，不展示虚构指标。

**Comparison history**

- P2: 首次尝试直接读取 AppIcon 资源时头像区为空。已改为原生 SF Symbols 波形标识。
- Post-fix evidence: `profile-device-dark-final.png` 头部图标清晰显示，与页面其他图标线宽一致。

**Interactions tested**

- 点击平台状态条可进入「音乐平台」，返回正常。
- 点击「播放与音质」可进入设置页。
- 深色、浅色值均已写入 AppStorage 并重启验证；屏幕与底部导航无遮挡。
- Accessibility tree 可识别主要入口、状态和「外观主题」分段控件。

**Findings**

- 无未解决的 P0/P1/P2 问题。

**Follow-up polish**

- P3: 后续如增加可供页内调用的正式品牌标识 assets，可替换当前波形 SF Symbol。

final result: passed

---

## iOS 播放页 UI 优化（2026-08-03）

**对照与环境**

- 原始界面：`/var/folders/94/q8fw6ndj7cvb9bgd78102vgr0000gn/T/codex-clipboard-3da7b902-4a8f-4b20-a9eb-a9bc5eaee0c2.png`（1179 × 2556）
- 实现截图：`/private/tmp/selfradio-player-device-after.png`（1206 × 2622，iPhone 17 模拟器）
- 并排对照：`/private/tmp/selfradio-player-ui-comparison.png`
- 状态：真实平台歌曲播放中

**本轮修正**

- P1：播放页仍显示全局底部导航，削弱沉浸感。已在播放页隐藏，退出后恢复。
- P1：缺少明确返回入口。已增加左上角返回按钮，并验证可回到首页。
- P2：顶部与歌手下方重复展示音质、平台、匹配警告。已从主视觉移除，保留到“智能/歌曲信息”入口。
- P2：进度条、时间与四张大功能卡导致纵向层级拥挤。已移除进度区，将功能入口收敛为圆形轻按钮。
- P2：标题区域与封面占比失衡。已重排为居中标题、主封面、歌曲/歌手、核心控制的单一层级。

**视觉核对**

- 字体：标题、歌曲名、歌手三级清晰，无截断或重叠。
- 间距：封面、文字、控制区留白均衡；底部安全区无遮挡。
- 色彩：沿用现有柔光渐变与深紫文字体系。
- 素材：使用真实歌曲封面，无占位资源。
- 交互：返回、收藏、上一首、播放/暂停、下一首、循环、队列、智能、歌曲信息均保留；右滑歌词、下滑下一首手势保留。

**验证记录**

- 无底部导航：播放页可访问性树仅包含播放控件及系统模拟器工具栏。
- 返回验证：点击“返回首页”后，首页及“首页/播放/我的”导航恢复。
- 对比结论：原始页面的重复信息、进度区和底部导航已移除，主任务层级更聚焦。

final result: passed

---

## iOS 2.5D 动态开屏（2026-08-08）

**Comparison target**

- Source visual truth: `/Users/tcg/.codex/generated_images/019fbe17-b71d-72e1-ad15-49ab546ad14f/exec-cbc44d7a-768d-4c8e-b345-5c5edf57e1c3.png`
- Dynamic background asset: `ios/SelfRadioIOS/SelfRadioIOS/Assets.xcassets/LaunchSplashFusionDynamic.imageset/launch-splash-fusion-dynamic.png`
- Implementation screenshot: `docs/ui-design/ios-launch-fusion-dynamic-implementation.png`
- Combined comparison: `docs/ui-design/ios-launch-fusion-dynamic-comparison.png`
- Motion evidence: `docs/ui-design/ios-launch-fusion-dynamic-demo-final.mov`
- Viewport: iPhone 16 simulator，393 × 852 pt，3×。
- Source: 852 × 1846 px；implementation: 1179 × 2556 px；motion: 1178 × 2556 px。
- Density normalization: source 与 implementation 均按 1024 px 高度等比缩放并排；系统状态栏与 Home Indicator 作为原生运行时区域保留。
- State: 2.5D 纵深运动完成帧，彩色加载圆环正在旋转。

**Full-view comparison evidence**

- 原有青蓝/紫/玫红光带、音符波形、标题、副标题与深色背景保持同一构图和视觉语言。
- 实现帧因 1.6° 透视与 1.045 倍缩放产生轻微纵深位移；这是用户要求的动态效果，不是布局漂移。
- 静态素材中的加载圈已被无痕移除，代码驱动的三段彩色圆环位于原位置，未与文字或 Home Indicator 重叠。

**Focused region evidence**

- 1024 px 高度的合并图可清晰判断音符边缘、中文排版、光带细节和加载圈位置；没有更小的复杂控件需要额外局部放大。

**Required fidelity surfaces**

- Typography: “随心听 / 你的私人音乐现场”继续来自高保真栅格资产，字形、字重、间距和抗锯齿与源图一致。
- Spacing/layout: 仅增加 ±1.6° 透视、4 pt 位移和 1.025→1.045 缩放；关键内容保持安全区内，圆环按屏高 8% 定位。
- Colors/tokens: 背景资产保持原色；动态圆环复用现有 blue/violet/rose token 与柔光阴影。
- Image quality/assets: 使用 ImageGen 精确移除静态圆环后的项目内 PNG；无占位符、低清图或第三方素材。
- Copy/content: 中文标题与副标题未改变、未重绘、未截断。

**Comparison history**

- 本轮首次动态对照未发现可执行的 P0/P1/P2 问题，因此无需视觉修正迭代。
- 需求实现记录：静态整图升级为 SwiftUI 轻量 2.5D 透视运动；静态圆环升级为 0.85 秒一圈的原生彩色旋转圆环。

**Findings**

- 无未解决的 P0/P1/P2 问题。

**Interactions tested**

- 冷启动显示 2.5D 开屏并自动进入首页；正式过渡约 2.2 秒。
- 3.228 秒 H.264 模拟器录屏包含完整启动、旋转圆环、纵深变化和进入首页过程。
- 5 项自动化测试覆盖开屏显示、2.5D 变换、圆环持续旋转及减少动态效果路径。

**Follow-up polish**

- P3: 真正的 SceneKit/RealityKit 3D 分层需要拆分光带、Logo 和文字资产，成本与启动性能开销明显更高；当前 2.5D 是低成本方案。

final result: passed
