# 昼夜日记：前后端接口约定 v1

iOS 前端 ↔ 团队后端（后端负责检索相关日记并调用 Gemini）。

- Base URL：在 App 的 **设置 → 分析服务 → 后端（Gemini）** 里填写，默认 `http://localhost:8000`（iOS 模拟器可以直接访问本机）
- 所有请求和响应都是 `Content-Type: application/json`，UTF-8 编码
- 日期统一用 **ISO8601** 字符串，例如 `2026-10-30T21:00:00Z`。带不带毫秒都能解析
- `id` 都是 UUID 字符串，由前端生成
- `userId` 是前端首次启动时生成的匿名 UUID，后端用它区分不同用户的数据
- **Gemini API Key 只放在后端**，App 里不保存任何 Key

前端调用顺序：用户点“生成 AI 联合分析”后，先调 `sync`，再调 `analyze`，代码在 [RemoteAnalysisService.swift](../DreamJournal/Services/RemoteAnalysisService.swift)。

---

## 1. `POST /api/v1/entries/sync`

把本地的全部白天日记和梦境日记推给后端（全量上传，后端按 `id` 做 upsert）。后端检索相关内容时需要这些数据。

### Request
```json
{
  "userId": "8C1F2E7A-0B9D-4C55-9E0A-6F3B1D2C4A11",
  "days": [
    {
      "id": "1D7A…",
      "date": "2026-10-28T13:00:00Z",
      "title": "第一轮面试",
      "content": "上午一面。面试官问了一个系统设计的问题，我一下子大脑空白…",
      "mood": "stressed",
      "tags": ["面试", "紧张", "工作"]
    }
  ],
  "dreams": [
    {
      "id": "9B42…",
      "title": "从高楼坠落",
      "content": "我站在公司的高楼顶上，脚下一滑掉了下去…",
      "dreamDate": "2026-10-28T15:00:00Z",
      "recordedAt": "2026-10-29T01:00:00Z",
      "emotions": ["恐惧", "兴奋"],
      "vividness": 5,
      "isLucid": false,
      "tags": ["坠落", "飞", "工作"]
    }
  ]
}
```

| 字段 | 说明 |
|---|---|
| `days[].mood` | `happy` / `calm` / `neutral` / `stressed` / `sad` |
| `dreams[].dreamDate` | 做梦的**那一晚**，和同一天的白天日记配对 |
| `dreams[].recordedAt` | 实际记录的时间（通常是第二天早上） |
| `dreams[].vividness` | 清晰度，1–5 |

### Response `200`
```json
{ "ok": true, "days": 7, "dreams": 6 }
```
前端不读响应内容，只检查返回的是不是 2xx。

---

## 2. `POST /api/v1/dreams/analyze`

### Request
```json
{
  "userId": "8C1F2E7A-0B9D-4C55-9E0A-6F3B1D2C4A11",
  "dream": {
    "id": "9B42…",
    "title": "从高楼坠落",
    "content": "我站在公司的高楼顶上…",
    "dreamDate": "2026-10-28T15:00:00Z",
    "recordedAt": "2026-10-29T01:00:00Z",
    "emotions": ["恐惧", "兴奋"],
    "vividness": 5,
    "isLucid": false,
    "tags": ["坠落", "飞", "工作"]
  },
  "options": { "lookbackDays": 7, "maxRelated": 5, "language": "zh" }
}
```

### Response `200`
```json
{
  "analysisId": "a1b2c3",
  "summary": "「从高楼坠落」里出现了坠落和飞翔两种意象。结合你当天记录的「第一轮面试」…",
  "themes": ["压力与评价", "自由与释放"],
  "symbols": [
    { "symbol": "坠落", "interpretation": "失控感的典型象征…" },
    { "symbol": "飞翔", "interpretation": "代表摆脱束缚、掌控感提升…" }
  ],
  "relatedDays": [
    {
      "entryId": "1D7A…",
      "date": "2026-10-28T13:00:00Z",
      "snippet": "上午一面。面试官问了一个系统设计的问题…",
      "reason": "梦的当天 · 共同线索：工作、面试"
    }
  ],
  "relatedDreams": [
    {
      "entryId": "77E0…",
      "date": "2026-10-26T15:00:00Z",
      "snippet": "梦里要参加一场很重要的考试…",
      "reason": "2 天前的梦 · 同样是被评估的焦虑"
    }
  ],
  "emotionalTone": "梦中以「恐惧、兴奋」为主，与白天「焦虑」的心情相互呼应。",
  "suggestion": "试着把让你紧张的事情拆成几个小步骤写下来…",
  "model": "gemini-2.5-flash",
  "generatedAt": "2026-10-29T01:02:03Z"
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `summary` | ✅ | 2–4 句话，**要明确点出它和哪些白天经历有关** |
| `themes` | ✅ | 1–3 个短主题，显示成报告顶部的胶囊标签 |
| `symbols` | ✅ | 梦中意象及解读，可以是空数组 |
| `relatedDays` / `relatedDreams` | ✅ | `entryId` **必须是 sync 上传过的 id**，前端靠它跳转到原日记；可以是空数组 |
| `reason` | ✅ | 一句话说明为什么相关（时间和共同线索），显示在关联卡片上 |
| `emotionalTone` / `suggestion` | ✅ | 字符串 |
| `model` | 可选 | 显示在报告底部 |

### 错误响应（任何非 2xx 状态码）
```json
{ "error": { "code": "GEMINI_TIMEOUT", "message": "模型响应超时，请稍后再试" } }
```
前端会把 `message` 显示在弹窗里，并提供“改用 Mock 重试”。

后端实际会返回的错误码：

| HTTP | `code` | 场景 |
|---|---|---|
| 400 | `INVALID_REQUEST` | 请求字段缺失或类型不对 |
| 503 | `GEMINI_NOT_CONFIGURED` | 后端没有配置 `GEMINI_API_KEY` |
| 504 | `GEMINI_TIMEOUT` | 模型超过 20 秒没有返回 |
| 429 | `GEMINI_RATE_LIMITED` | 触发 Gemini 限流 |
| 502 | `GEMINI_ERROR` / `GEMINI_BAD_OUTPUT` | 模型调用失败 / 输出无法解析 |
| 500 | `INTERNAL` | 其他未预期的错误 |

### 后端实现约定（backend/）
- `sync` 是全量覆盖：本次没上传的旧日记会从后端删除，所以分析结果不会引用已经删掉的日记
- `id` 比较不区分大小写，后端统一转成大写（和 Swift `UUID` 的编码一致）
- 接口里不带时区。“当天 / 前一天”按后端 `USER_TZ` 划分，默认 `Asia/Shanghai`
- 响应里的日期一律是 `2026-10-29T01:02:03Z` 格式（不带微秒）

---

## 给后端同学的实现建议

1. **存储**：按 `userId` 保存 sync 上来的 days 和 dreams。HackDay 阶段用内存 dict 或 SQLite 就够了
2. **检索候选**
   - 时间维度：`dreamDate` 往前 `lookbackDays` 天内的白天日记，时间越近权重越高（当天 > 前一天 > 更早）
   - 内容维度：用 Gemini embedding 计算梦境和每篇日记、每个过往梦境的余弦相似度。如果没时间做，可以先用关键词或标签重叠，参考前端 Mock 的打分方式 [MockAnalysisService.swift](../DreamJournal/Services/MockAnalysisService.swift)
   - 合并打分，取白天 Top 3–5、过往梦境 Top 2–3
3. **调用 Gemini**：把梦境和候选日记（带上 id 和日期）拼进 prompt，开启 `responseMimeType: "application/json"` 和 `responseSchema`，让输出直接符合上面的 Response 结构。在 prompt 里明确要求：
   - 只能从提供的候选里引用 `entryId`，不能编造
   - 语气温和，不做医学或心理诊断
   - 输出使用 `options.language` 指定的语言
4. **校验**：过滤掉不在候选列表里的 `entryId`，补上 `analysisId`、`generatedAt`、`model` 后返回

### Prompt 骨架（后端用）
```
你是一位温和的梦境分析师，擅长把梦和做梦者最近的现实经历联系起来。
【今晚的梦】{date} {title}：{content}（情绪：{emotions}，清晰度 {vividness}/5，清醒梦：{isLucid}）
【候选白天日记】
- id={id} 日期={date} 心情={mood} 标题={title} 内容={content}
【候选过往梦境】
- id={id} 日期={date} 标题={title} 内容={content}
请按 JSON Schema 输出：summary, themes, symbols, relatedDays, relatedDreams, emotionalTone, suggestion。
relatedDays 和 relatedDreams 只能从候选里挑真正相关的，并在 reason 里写明时间关系和共同线索。
```

### 本地联调
```bash
# 后端跑在本机 8000 端口后，App 里：设置 → 分析服务选“后端（Gemini）”→ 地址填 http://localhost:8000
curl -X POST http://localhost:8000/api/v1/dreams/analyze -H 'Content-Type: application/json' -d @backend/tests/sample_request.json
```
真机调试时把地址换成电脑的局域网 IP，例如 `http://192.168.1.23:8000`。Info.plist 已经允许 HTTP 和本地网络访问。
