---
name: lark-haiknow
description: 查询 haiknow 飞书租户（bcnncgqa2y6v.feishu.cn）的知识库、云文档、表格与多维表格。用于读取「人机协作空间」「赚钱大计」「实操项目变流量」等知识库内容，按标题检索、展开目录树、导出文档正文。当用户提到 haiknow、飞书知识库、wiki、项目看板、团队会议记录时使用。
---

# lark-haiknow

haiknow 飞书租户的**只读查询** skill。走本机已授权的 `lark-cli`（user 身份，账号 `李泽宇`）。

> **和 deli-lark 的区别**：deli-lark 管的是**得力租户**，只有 Company 电脑能访问。
> 这个 skill 管的是 **haiknow 租户**，本机 MacBook / Air 上就能直接查。
> 两者是不同租户、不同权限体系，别混。

## 前置检查（每次会话第一次用先跑）

```bash
lark-cli auth status --json | head -20
```

要看到 `"identity": "user"` 且 `"status": "ready"`。如果 `not_configured` 或未登录：

```bash
lark-cli auth login --domain all --no-wait --json   # 拿 verification_url 给用户
# 用户确认后：
lark-cli auth login --device-code <device_code> --json
```

租户域名：`bcnncgqa2y6v.feishu.cn`

---

## 一、先看有哪些知识库

```bash
lark-cli wiki +space-list --json
# 解析：.data.spaces[] → { name, space_id, visibility, space_type }
```

当前 4 个空间（会变，以实际输出为准）：

| 知识库 | space_id | 可见性 | 内容 |
|---|---|---|---|
| 人机协作空间 | `7655636309114588405` | private | 项目（niubila 等）、调研、hackathon、新人入门 |
| 赚钱大计 | `7685679000068295959` | private | 首页、💰待办事项-运营（多维表格）、宣传资料 |
| 实操项目变流量-haiknow赚钱的第一步 | `7692501984825314486` | public | 项目启动、团队会议、项目变现进度看板 |
| 示例知识库 / Wiki samples | `7655602965438008523` | public | 飞书官方示例，参考价值低 |

---

## 二、展开目录树

```bash
# 顶层
lark-cli wiki +node-list --space-id <SPACE_ID> --json | jq '.data.nodes[]'

# 进子节点（--parent-node-token）
lark-cli wiki +node-list --space-id <SPACE_ID> --parent-node-token <NODE_TOKEN> --json

# 一次性拉全部（大库慎用，配 --page-limit）
lark-cli wiki +node-list --space-id <SPACE_ID> --page-all --page-limit 0 --json
```

**返回字段是 `data.nodes`**（不是 `data.items`，那是 `+space-list` 之外的别处用法），每条含：

```
title            标题
obj_type         docx | sheet | bitable | file | mindnote | slides
node_token       节点 token（做 +node-list 父子遍历用这个）
obj_token        实际文档 token（做 docs +fetch / sheets 用这个）
has_child        是否有子节点
```

**递归全树**（Python 脚本，已验证可用）：

```python
import json, subprocess

def call(args):
    return json.loads(subprocess.run(args, capture_output=True, text=True).stdout)

def children(space, parent=None, depth=0, out=None):
    if out is None: out = []
    cmd = ["lark-cli","wiki","+node-list","--space-id",space,"--page-all","--page-limit","0","--json"]
    if parent: cmd += ["--parent-node-token", parent]
    d = call(cmd)
    if not d.get("ok"):
        out.append("  "*depth + f"<ERR> {d.get('error',{}).get('message')}"); return out
    for n in d["data"].get("nodes", []):
        out.append("  "*depth + f"{n['title']} [{n['obj_type']}] {n['node_token']} obj={n['obj_token']} child={n['has_child']}")
        if n.get("has_child"):
            children(space, n["node_token"], depth+1, out)
    return out
```

---

## 三、读文档正文

```bash
# 最常用：markdown 正文（给人和模型读都友好）
lark-cli docs +fetch --doc "<node_token 或 obj_token 或完整 URL>" --doc-format markdown

# XML 结构（保留表格、cite、block 结构，默认）
lark-cli docs +fetch --doc <token>

# 只有大纲（长文档先看结构）
lark-cli docs +fetch --doc <token> --scope outline

# 按关键词定位（大文档省 context）
lark-cli docs +fetch --doc <token> --scope keyword --keyword "接口|架构"

# 按段落读（配 outline 拿到的 block id）
lark-cli docs +fetch --doc <token> --scope section --start-block-id <block_id>
```

**三种 token 都能传**：`wiki` URL、`node_token`、`obj_token`，CLI 会自动解析。

`--doc-format markdown` 输出的正文里，跨文档引用是 `<cite doc-id="..." file-type="wiki" title="..." type="doc">` 形式——看到它说明这篇引用了另一篇，要顺藤摸瓜就再 fetch 一次那个 doc-id。

---

## 四、读表格与多维表格

### 电子表格（sheet）

```bash
# 1. 先看有哪些 sheet
lark-cli sheets +workbook-info --spreadsheet-token <obj_token>

# 2. 再读区间（必须指定 sheet，不能用 "Sheet1!A1" 这种带前缀写法）
lark-cli sheets +cells-get --spreadsheet-token <obj_token> \
  --sheet-name "Sheet1" --range "A1:F20"

# 大表落盘再分析（避免刷爆 context）
lark-cli sheets +cells-get --spreadsheet-token <obj_token> \
  --sheet-name "Sheet1" --range "A1:Z2000" --output-path /tmp/sheet.json
```

### 多维表格（bitable）

```bash
# 1. 列表
lark-cli base +table-list --base-token <obj_token>

# 2. 读记录
lark-cli base +record-list --base-token <obj_token> --table-id <table_id> \
  --format ndjson --output /tmp/records.ndjson

# 3. 内联小结果
lark-cli base +record-list --base-token <obj_token> --table-id <table_id> --format json --page-size 5
```

> ⚠️ **踩过的坑**：`base +record-list` 用默认 `ndjson` 且不传 `--output` 时，会把
> `<table_id>_<时间戳>.ndjson` 和 `.manifest.json` **写到当前工作目录**。
> 在 `~/.agents/skills` 下跑会污染 skill 仓库。**永远显式传 `--output /tmp/...`**。

---

## 五、检索（按标题搜）

```bash
lark-cli docs +search --query "harness" --json
```

- `--query` 必须是**具体词**，宽泛词结果很差
- 标题字段是 `title_highlighted`，不是 `result_meta.title`
- 搜群聊消息用 `im +messages-search`

> **scope 状态**：`search:docs:read` 和 `space:document:retrieve` 尚未授权（用户授权时跳过了）。
> 如果这两个命令报 `missing_scope`，走 URL/token 直读路径（上面第三、四节），或者让用户补授权：
> ```bash
> lark-cli auth login --scope "search:docs:read space:document:retrieve" --no-wait --json
> ```

---

## 六、当前知识库内容地图（2026-10-31 抓取）

```
人机协作空间 (7655636309114588405)
├── 首页
├── 项目
│   └── niubila
│       ├── 01-architecture
│       ├── 02-data-cohort-contract
│       ├── 03-algorithm-contract
│       ├── 04-federation-contract
│       ├── 05-requirements
│       ├── onboarding
│       └── D0003-治理机制-对抗审loop与事实源保证
├── 新人入门 — 团队、项目与工作方式（待完善）
├── 调研
│   ├── docs        ← 13 篇 reference-*.md（AI repo/wiki/agent memory 等调研）
│   └── overview    ← 13 篇同名 .html 报告
└── hackathon
    └── oaic-harness-2026   ← 参赛策略、防坑手册、群聊纪要

赚钱大计 (7685679000068295959)
├── 首页
├── 💰待办事项-运营  [bitable, 表: ✅Todo跟进]
└── 宣传资料          ← 团队与生态介绍、移动研发平台原型

实操项目变流量 (7692501984825314486)
├── 项目启动
├── 团队会议
│   ├── 每日进展同步
│   └── 团队周会
└── 项目变现进度看板  [sheet, Sheet1]
```

---

## 七、全量拉取脚本（已验证）

`pull-all.py` 是本 skill 自带的批量抓取脚本，2026-10-31 实测跑通 55/55 节点 0 失败。

```bash
python3 pull-all.py       # 输出到 /tmp/hk-pull/stage/，清单写入 /tmp/hk-pull/manifest.json
```

它做的事：递归遍历三个空间（跳过示例知识库）→ docx 抓 markdown → file 下载原文件 → sheet 按 sheet 导出 JSON → bitable 导出 ndjson → 逐条打印状态并汇总失败项。

**注意**：脚本输出用 `--page-limit 0 --page-all` 拉全量；对超大知识库要留意 context 和耗时。

拉完之后**不要直接整包丢进 Brain**——按内容性质分流：

| 内容类型 | 落点 |
|---|---|
| 项目文档、架构契约 | `07-WORK-DOCS/03-HAiKnow/01-项目交付物/<项目>/` |
| 对外材料、申报、赛事 | `03-对外材料/<分类>/` |
| 调研报告 + HTML | `06-参考资料/调研/{references,overview}/` |
| 会议模板/纪要 | `05-会议/会议记录/` |
| 运营待办（多维表格） | `08-运营与推广/待办事项-运营/`，转 markdown 表格 |
| 大体积 HTML（>500K 且与 sources 重复） | **不复制**，建索引指向 `05-PROJECTS/proj-haiknow/sources/` |
| 飞书默认模板页（首页/纯目录页） | `99-归档/飞书知识库首页与目录页/` |

判据：文字内容、要被人检索引用的进 Git；大体积二进制原始附件进 `LOCAL-LARGE-FILES/` 或在 sources 里建索引。

## 八、已入库记录

| 日期 | 内容 | 节点数 | 落点 |
|---|---|---|---|
| 2026-10-31 | 三空间全量（人机协作空间 45 / 赚钱大计 5 / 实操项目变流量 5） | 55 | `Brain/07-WORK-DOCS/03-HAiKnow/` |

入库规则、INDEX 骨架与生成器顺序、提交纪律，见 `deli-lark/references/brain-restore.md`（通用规程，两个租户都适用）。

## 常用组合

| 用户问 | 怎么做 |
|---|---|
| 「haiknow 知识库里有什么」 | `wiki +space-list` → 表格答 |
| 「XX 知识库的结构」 | `wiki +node-list --space-id <id> --page-all` |
| 「把 XX 文档读出来」 | `docs +fetch --doc <token> --doc-format markdown` |
| 「这篇讲了啥，先给我大纲」 | `--scope outline`，再挑重点 `--scope section` |
| 「看板/进度的数据」 | sheet → `+workbook-info` → `+cells-get` |
| 「待办事项」 | bitable → `+table-list` → `+record-list --output /tmp/...` |
| 「搜一下有没有 XX」 | `docs +search`（若缺 scope 则按目录树找） |

## 边界

- **只读**。不要用它改文档、发消息、动权限。
- 不要访问得力飞书内容（那是另一个租户，见 `deli-lark`）。
- `--as user` 是默认身份；`--as bot` 只能读到应用可见的资源，不要用。

---
