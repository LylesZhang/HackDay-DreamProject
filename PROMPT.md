# Vibecoding Prompt：昼夜日记 (Day & Dream Journal)

这里有两段 prompt，都可以直接复制给 AI 编程助手（Claude Code、Cursor 等）：
- **Prompt A**：从零生成整个 iOS demo。本仓库的代码就是按这份 prompt 做出来的
- **Prompt B**：在本仓库的基础上继续迭代新功能

---

## Prompt A：从零生成 demo

```
你是一名资深 iOS 工程师兼产品设计师。请用 SwiftUI 帮我做一个可以直接在 iPhone 模拟器里演示的 App：「昼夜日记」。

## 产品定位
“现实日记 + 梦境日记 + AI 联合分析报告”。用户白天用几句话记下发生了什么，早上醒来记下昨晚的梦。
对某个梦点击“AI 分析”时，系统会找出时间上、内容上和这个梦相关的白天日记和过往梦境，生成一份联合分析报告，
告诉用户这个梦可能在消化哪段现实经历。

## 技术约束
- iOS 17+，SwiftUI，Observation（@Observable），不用任何第三方库
- 用 XcodeGen 的 project.yml 生成工程；SWIFT_VERSION 5；只支持 iPhone 竖屏
- 数据用 JSON 存在 Documents/journal.json；首次启动自动导入示例数据
- 后端由队友实现（调用 Gemini）。前端用 protocol 抽象出分析服务，同时提供 Mock 和 Remote 两种实现，在设置里切换

## 视觉设计
- 白天：暖白 / 淡橙。背景 #FFF8F0→#FFEBD6，卡片 #FFFFFF→#FFE8D1 渐变，强调色 #FF9F5A，正文 #4A3426
- 梦境：暗紫 / 深空蓝。背景 #0B1026→#1B1640→#2A1B3D，卡片 #2E2150 半透明加 #B79CFF 描边，强调色 #B79CFF，正文 #E8E3FF
- 夜间背景要有用 Canvas + TimelineView 画的缓慢闪烁的星空
- 卡片圆角 20（continuous），带柔和阴影

## 页面
1. 主页时间轴：顶部是“日间 / 夜间 / 昼夜”三段胶囊开关（matchedGeometryEffect 滑块），切换时背景渐变带动画
   - 日间：只列出白天卡片（日期、心情图标、标题、2 行预览、标签）
   - 夜间：只列出梦境卡片（月相图标、标题、预览、情绪标签、1–5 星清晰度，已分析的显示 sparkles 图标加“已分析”）
   - 昼夜：按日期分组，每天一行，左边白天卡、右边当晚的梦境卡，缺的一侧显示虚线占位卡“+ 记录”
   - 右下角悬浮 + 按钮，按当前模式打开对应的录入表单（昼夜模式下先让用户选）
2. 白天录入：日期、标题、正文、5 种心情（用 SF Symbols 天气图标表示：晴 / 叶 / 云 / 闪电 / 雨，不要用 emoji）、标签（空格分隔）。暖色主题
3. 梦境录入：做梦的那一晚、标题、正文、情绪多选（不安/愉快/困惑/恐惧/怀念/兴奋/悲伤/平静/自由）、清晰度星级、是否清醒梦、标签。深色主题加星空
4. 白天详情：全文；如果当晚有梦，附上梦境卡片
5. 梦境详情：全文，加“生成 AI 联合分析”按钮。分析中显示全屏遮罩，星星旋转，文案轮播“正在检索梦前几天的白天日记…”。
   出错时弹窗，提供“改用 Mock 重试”
6. 联合分析报告（深色）：标题和主题胶囊 → 梦境概要 → 关联的白天（暖色小卡，显示 reason，可以点进原日记）
   → 相似的过往梦境 → 意象解读 → 情绪基调 → 小建议；底部注明生成来源，并提示“仅供自我觉察参考”
7. 设置：分析服务选 Mock 或后端，后端 Base URL，重置示例数据

## 数据模型
- DayEntry { id, date, title, content, mood(happy/calm/neutral/stressed/sad), tags }
- DreamEntry { id, dreamDate, recordedAt, title, content, emotions, isLucid, tags, analysis: DreamAnalysis? }
- Keyword { id, name, kind(person/imagery/scene), subtitle, note, aliases }：正文出现名字或别名即自动链接
- DreamAnalysis { summary, themes, symbols[{symbol, interpretation}], relatedDays[{entryId, date, snippet, reason}],
  relatedDreams[...], emotionalTone, suggestion, generatedAt, source(mock/gemini), model }

## 服务层
protocol AnalysisService {
  func sync(days: [DayEntry], dreams: [DreamEntry]) async throws
  func analyze(dream: DreamEntry, store: JournalStore) async throws -> DreamAnalysis
}
- RemoteAnalysisService：POST {base}/api/v1/entries/sync，然后 POST {base}/api/v1/dreams/analyze，日期用 ISO8601，超时 30 秒，
  错误体是 { "error": { "code", "message" } }。请求和响应结构见 docs/API.md
- MockAnalysisService：在本地模拟后端，让离线演示的结果看起来是真的：
  1) 时间：梦前 0–7 天的白天日记，当天 +3、前一天 +2、2–3 天 +1
  2) 内容：中文 2-gram（去掉含虚词的）加标签匹配，共同标签 +3，共同 2-gram +1；
     展示线索时把相邻的 2-gram 合并成完整词（陌生+生城+城市 → 陌生城市）
  3) 取白天 Top 3、过往梦境 Top 2；用意象词典（考试/坠落/飞/水/海/鲸鱼/迷路/城市/老房子/家人/裂缝…）
     加模板生成概要、主题、情绪基调和建议；sleep 1.6 秒模拟网络延迟

## 示例数据（很重要，决定演示效果）
最近 7 天，白天和梦境内容要能互相呼应，例如：
老同学说奶奶家老房子要拆 → 梦回奶奶家院子，墙上出现裂缝；熬夜准备面试 → 梦见找不到考场；
暴雨走回家 → 梦见城市被水淹没、有鲸鱼；一面紧张 → 梦见从高楼坠落然后飞起来；
去海边看日落 → 清醒梦里和鲸鱼一起飞；面试通过但要搬家 → 梦见在陌生城市迷路；今天打包行李（当晚还没有梦，用来展示占位卡）

## 演示用启动参数
-initialMode day|night|dual，-openDream N（直接打开第 N 个梦，0 是最新的），-autoAnalyze YES，-resetData

## 验收标准
- 用 xcodegen generate 生成工程后，xcodebuild 编译 iPhone 模拟器版本没有错误
- 打开就能看到昼夜双卡时间轴；三种模式切换顺滑；能新增和编辑白天、梦境日记，重启后数据还在
- 对任意示例梦点击分析，1–2 秒后出现报告，并且能正确关联到相应的白天日记
- 先保证能演示，再打磨细节；代码按 Models / Store / Services / Theme / Views 分目录
```

---

## Prompt B：在现有仓库上迭代

```
这是一个 SwiftUI iOS 17 项目「昼夜日记」（用 XcodeGen 生成工程，见 project.yml）。
先读 PROMPT.md 的 Prompt A 和 docs/API.md，了解产品、配色和接口约定，再完成下面的需求：

<在这里写需求，例如：给梦境录入加语音输入，用 Speech 框架转成文字>

要求：
- 保持现有的分层：Models / Store / Services / Theme / Views
- 白天界面用 DayPalette，梦境界面用 NightPalette，不要引入新的配色
- 如果改了接口字段，同步更新 docs/API.md、APIModels.swift 和 MockAnalysisService
- 改完运行 xcodegen generate，再用 xcodebuild 编译 iPhone 模拟器版本，确认没有错误
```

### 可以继续迭代的方向
- 🎙️ 语音录梦：醒来时迷迷糊糊不想打字，用 Speech 框架转文字
- ☁️ 梦境词云和意象统计：最近一个月最常出现的意象
- 📅 周报：每周日自动生成一份“昼夜周报”，总结白天压力源和梦境主题的对应关系
- 🔔 早晨通知：“记得记录昨晚的梦”，晚上通知：“今天过得怎么样？”
- 🔗 报告里画一张关系图，把梦和白天日记用连线连起来
- ☁️ iCloud / SwiftData 同步
- 🔒 Face ID 锁定（日记很私密）
