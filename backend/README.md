# 昼夜日记 Backend

FastAPI + SQLite + Gemini。接口约定见 [docs/API.md](../docs/API.md)。

## 启动
```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env          # 填上 GEMINI_API_KEY
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
App 里：设置 → 分析服务选“后端（Gemini）”→ 地址填 `http://localhost:8000`（真机用电脑的局域网 IP）。

## 自测
```bash
.venv/bin/python -m pytest -q                       # 不需要 API Key
curl localhost:8000/health                          # gemini: true 表示 Key 已配置
curl -X POST localhost:8000/api/v1/entries/sync    -H 'Content-Type: application/json' -d @tests/sample_sync.json
curl -X POST localhost:8000/api/v1/dreams/analyze  -H 'Content-Type: application/json' -d @tests/sample_request.json
```
`tests/sample_*.json` 由 `python tests/sample_data.py` 生成，内容与 App 的示例数据一致。

## 结构
| 文件 | 作用 |
|---|---|
| `app/main.py` | 路由、统一错误格式、embedding 缓存调度 |
| `app/schemas.py` | 请求 / 响应模型（日期输出成 `…Z`，不带微秒） |
| `app/store.py` | SQLite：按 userId 存日记，按内容 hash 缓存 embedding |
| `app/retrieval.py` | 候选检索：时间分 + 关键词分（移植自前端 Mock）+ embedding 语义分 |
| `app/llm.py` | Gemini prompt、`responseSchema`（entryId 用 enum 限定在候选里）、超时与错误映射 |
| `app/postprocess.py` | 过滤非法 / 重复 entryId，date 和 snippet 从原文回填 |

## 分析流程
1. `analyze` 先把当前梦存一下，再读出这个用户的全部日记
2. （有 Key 且 `USE_EMBEDDING=true` 时）计算梦和每篇日记的 embedding 余弦相似度；sync 时会在后台预先算好并缓存
3. 白天候选：梦前 0–`lookbackDays` 天，分数 = 时间分（当天 3 / 前一天 2 / 2–3 天 1）+ 关键词分 + 语义分，取前 `maxRelated` 条
   过往梦境候选：只取更早的梦，按关键词和语义分取前 3（完全无关的不给模型）
4. Gemini（`gemini-2.5-flash`，关闭 thinking 以降低延迟）按 JSON Schema 输出，只能从候选里挑选
5. 后处理后返回；embedding 失败时自动退回纯关键词检索，不影响结果返回
