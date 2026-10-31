---
name: deli-lark
description: 得力飞书（Lark）操作入口，三机分工：Company 电脑拉取、本机 MacBook 与 Air 只查询。用于检索/导出/归档得力飞书云文档、知识库、会议纪要与逐字稿，以及消费端按资料包还原入库。Agent 使用前必须先判定当前是哪台机器。
---

# deli-lark

得力飞书工作流统一 skill：**检索**飞书内容 → **抓取**到本地 → **归档** → **打包**给其他电脑。

> **⚠️ 使用前必读**：这个 skill 跨三台机器，**只有 Company 电脑有得力飞书权限**。
> 不知道自己在哪台机器上就跑 `hostname`，然后对照下面的拓扑表。
> 本机（MacBook Pro）和 Air **只能查询本地已落回的内容，不能连得力飞书**。
> 如果你要找的是 **haiknow 租户**（`bcnncgqa2y6v.feishu.cn`）的内容，
> 用 `lark-haiknow` skill，不是这个。

## 部署拓扑（先读这个，决定你能不能跑脚本）

### 第一步：先搞清楚自己是谁

得力飞书文档在**企业内网**里，只有 Company 电脑能连。你（Agent）在动手前**必须先判断当前机器，
再决定走「拉取」还是「查询」**。不要假设，跑下面这行：

```bash
hostname; scutil --get ComputerName 2>/dev/null; uname -a
```

判定规则：

| 探测结果 | 你是 | 该走什么 |
|---|---|---|
| `hostname` 或 ComputerName 含 **Company 机器标识**，且 `curl -s -m 3 https://<得力内网域名>` 有响应 | **Company 电脑**（唯一权限机） | 全部 SOP 都能跑，包括 `scripts/*.cmd` 拉取 |
| ComputerName 为 `MacBook Pro` / hostname `MacBook-Pro.local` | **本机 MacBook**（消费端） | **只查询**，不跑拉取脚本 |
| ComputerName 含 `MacBook Air` | **Air**（消费端） | **只查询**，不跑拉取脚本 |
| 以上都不匹配 | 未知机器 | 按**消费端**处理（保守），除非用户明确说这是 Company 机器 |

**辅助判断**（可选，更稳）：看 `lark-cli` 绑的是**哪个租户**，这比看主机名更本质。

```bash
# 看 appId + 是否已有 user 身份
lark-cli auth status --json 2>/dev/null | head -20
```

| 看到什么 | 说明 |
|---|---|
| `"appId": "cli_..."` + `"user": {"status": "ready"}`，且能 `wiki +space-list` 列出 haiknow 的空间 | 这是 **haiknow 租户** → 走 `lark-haiknow` skill，**不是**得力 |
| 没有任何 config / 未登录 | 大概率是消费端（本机 / Air） |
| 已登录且 `docs +search` 能搜到得力内部技术文档 | 这才是 **Company 电脑** |

> 关键认知：`lark-cli` 绑定的是**哪个租户**，不是装没装 CLI。本机 lark-cli 已授权给 **haiknow
> （`bcnncgqa2y6v.feishu.cn`）**，**不是得力租户**。所以本机即使有 lark-cli、命令全绿，
> 也**读不到得力飞书的内容**——那是另一个租户、另一套权限。

### 三台机器的分工

| 机器 | 角色 | 能做什么 | 不能做什么 |
|---|---|---|---|
| **Company 电脑**（唯一权限机） | 执行拉取 | 跑 `scripts/*.cmd`（PowerShell + lark-cli，已授权得力租户）。产出落在 `C:\Users\Administrator\Documents\人工智能研究中心\`，通过资料包 zip 传出 | — |
| **本机 MacBook Pro**（消费端） | 查询 + 入库 | 检索已落回本地的内容、按 RESTORE.md 还原入库、理解文档结构 | ❌ 不跑拉取脚本（无得力权限） |
| **Air**（消费端） | 查询 | 同本机：读本地已落回内容、检索、理解结构 | ❌ 不跑拉取脚本 |

**消费端（本机 / Air）的唯一数据来源**：Company 电脑打包出来的资料包 zip，或已还原进
Brain 知识库 / `LOCAL-LARGE-FILES` 的本地文件。**不要在消费端 attempt 访问得力飞书 URL**——
一定失败，浪费时间。

**消费端拿到资料包后的标准动作**：读包内 README.md → 按 RESTORE.md 的类型 A/B/C 还原入库
→ 更新 INDEX → 提交。不要在 Mac 上尝试访问包内 `url`（无权限）。

**还原到 Brain 知识库时走 [references/brain-restore.md](./references/brain-restore.md)**：那里写清中文文件名乱码的正确解压方式（zip 无 UTF-8 标志位，需 cp437→gbk 转码）、`会议纪要/` 与 `公司制度/` 的分流落点（文字进 Git、大体积原始附件进 LocalLargeFiles）、INDEX 骨架 + `gen_vault_index.py` 的先后顺序、入库记录写法，以及只 add 本次路径的提交纪律。

## 何时用

**先按上面的「第一步：先搞清楚自己是谁」判定机器身份**，再对照本表。

| 用户说 | Company 电脑 | 本机 MacBook / Air（消费端） |
|---|---|---|
| 「找一下 XX 相关文档」「群里发过的链接」 | **SOP 0：检索** → 跑 `search.cmd` | ❌ 拉不到 → 改查本地已还原副本 / 查 Brain 知识库 |
| 「导出会议纪要」「拉逐字稿」「原文转写」 | **SOP A：会议** → 跑 `meetings.cmd` | ❌ 同上，只能读已还原的 `会议纪要/` |
| 「同步知识库」「拉最新文档」 | **SOP B：知识库** → 跑 `wiki.cmd` | ❌ 同上 |
| 「抓这个链接」 | **SOP C：单篇** → 跑 `grab.cmd` | ❌ 无权限，只能解释结构 |
| 「打个包给对方」「传给另一台电脑」 | **SOP E：打包** → 跑 `packall.cmd` | — |
| 「把这包入库」「这些会议纪要归档」 | 也能做 | ✅ **这是消费端的主责** → 按 RESTORE.md 还原 |
| 「这份文档讲了什么」「结构是怎样的」 | ✅ | ✅ 读本地副本回答，**不需要连飞书** |

> 消费端被问到「得力飞书里有没有 XX」时：**先说明本机无得力租户权限**，再给出
> 「让 Company 电脑跑检索、把结果打成包过来」的路径。不要假装能查。

---

## SOP 0：检索（找文档 / 找链接）

> 仅 Company 电脑可执行。消费端（本机 / Air）跳过，改查本地副本。

**这是最常用的一条**，支持同时搜「云文档/知识库」和「群聊消息里的链接」。

```powershell
# 搜技术文档（多关键词，自动去重合并）
scripts\search.cmd -Query "前端,后端,架构,接口,API"

# 只搜云文档
scripts\search.cmd -Query "架构" -Source docs

# 只搜群聊里的链接（默认最近 90 天）
scripts\search.cmd -Query "docx" -Source messages -Days 30

# 显示完整 URL
scripts\search.cmd -Query "架构" -ShowUrl

# 输出 JSON 供程序处理
scripts\search.cmd -Query "架构" -Json
```

输出分两块：**云文档/知识库**（带类型、所有者、更新时间）和 **群聊链接/消息**（带群名、发送人、时间）。
结果同时落盘到 `人工智能研究中心\_search\search-<时间戳>.{csv,json}`。

### 检索的三种来源差异

| 来源 | 命令 | 能搜到什么 |
|---|---|---|
| 云文档 + 知识库 | `docs +search` | 标题匹配的 docx/sheet/base/slides/file/mindnote/shortcut |
| 群聊消息 | `im +messages-search` | 消息正文、群名、发送人、时间，可提取其中链接 |
| 云盘目录 | `drive files list` | 按文件夹层级遍历（不靠搜索） |

**注意**：`docs +search` 的 `--query` 必须是**具体词**（如「架构」「接口」），
传宽泛词或不传会得到不相关结果或重复项。搜索结果里标题字段是 `title_highlighted`，
不是 `result_meta.title`（后者不存在）。

---

## SOP A：会议纪要 + 逐字稿（核心能力）

> 仅 Company 电脑可执行。

```powershell
scripts\meetings.cmd -Days 7                 # 最近 7 天
scripts\meetings.cmd -StartDate 2026-10-01 -EndDate 2026-10-31
scripts\meetings.cmd -Days 30 -DryRun        # 预演
scripts\meetings.cmd -Days 7 -WithVerbatim:$false   # 只要纪要
```

**四步链路（缺一不可）**：

```
vc +search   → 会议列表
vc +detail   → note_id
note +detail → note_doc_token + verbatim_doc_token   ← 关键
docs +fetch  → 读纪要 + 读逐字稿
```

产物：

```
会议归档\2026-10-23\技术栈对齐\
├── 纪要.md          # AI 智能纪要
├── 逐字稿.md         # 原文转写，带说话人+时间戳
└── assets\*.png     # 图片，链接已本地化
```

详见 **[MEETING.md](./MEETING.md)**。

---

## SOP B：知识库增量（每天一个 zip）

> 仅 Company 电脑可执行。

```powershell
scripts\wiki.cmd          # 增量
scripts\wiki.cmd -Full    # 全量重拉
```

**归档约定**：

```
增量\
├── 2026-10-24\           # 当天目录，只累积不重建
│   ├── files\
│   ├── index.csv
│   └── index.json
└── 2026-10-24.zip        # 每次运行从整个目录重建
```

关键行为：

1. 一天一个目录 + 一个同名 zip，同天多次运行**不产生多批次**
2. 新文件**累积**进当天目录，索引也合并累积
3. **zip 每次重建** → 你把 zip 传走删掉，再跑一次会重新生成**完整当天包**
4. 跨天自动新建目录

支持类型：`docx`→.md、`bitable`→每表 .csv、`file`→原样下载、`sheet`→.xlsx、`slides`→.pptx。

---

## SOP C：按链接抓单篇/多篇

> 仅 Company 电脑可执行。

```powershell
scripts\grab.cmd -Url "https://xxx.feishu.cn/docx/AAA"
scripts\grab.cmd -Url "url1,url2,url3"
scripts\grab.cmd -UrlFile links.txt
```

产物：`增量\会议纪要\YYYY-MM\<标题>.md` + `assets\`，更新 `index-会议纪要.csv`。

---

## SOP D：技术文档专项抓取

> 仅 Company 电脑可执行。

按内置清单抓取「前后端 / 架构 / 接口 / 接入 / 规范」五类技术文档（28 篇）。

```powershell
scripts\techdocs.cmd -DryRun     # 先看清单
scripts\techdocs.cmd             # 实际抓取
```

产物按分类落盘：

```
技术文档\
├── 前端\    前端技术方案.md
├── 架构\    小得智能体开发平台-详细架构设计方案.pdf、得力AgentHub-总体架构设计方案.pdf …
├── 接口\    API 参考.md、AI中台API文档.md、SDK 文档.md …
├── 接入\    FDE-前端应用接入得力e+APP.md、得力Iot平台接入指引.md …
├── 规范\    技术评审.md、测试方案.md
└── index.csv / index.json
```

清单是**硬编码在脚本里的**（`$docs` 数组，含 url 和分类），因为飞书搜索排序不稳定，
硬编码能保证每次抓到同一批核心文档。要增删直接改数组。

---

## SOP E：打总包（技术文档 + 会议 + 知识库 + skill）

> 仅 Company 电脑可执行。

**这是给另一台电脑的完整交付包**。

```powershell
scripts\packall.cmd
```

产物：`_packs\得力飞书资料包-<yyyyMMdd-HHmmss>.zip`

包内结构：

```
得力飞书资料包-<时间戳>\
├── 技术文档\            28 篇，按 前端/架构/接口/接入/规范 分类
├── 会议纪要\            每场会议：纪要.md + 逐字稿.md + assets\
├── 知识库增量\          按 YYYY-MM-DD 批次
├── deli-lark-skill\     完整 skill（文档 + 全部脚本）
├── README.md            总说明（格式注意事项、使用方法）
└── MANIFEST.csv         各部分文件数与大小
```

特点：

- 自动排除 `_logs`、`.meeting-state.json`、旧 zip 等噪音文件
- 自带 README，对面不用问就能看懂格式差异（`.md` 不是原生 `.docx` 等）
- `packs.csv` 累积记录每次打包（stamp / label / 文件数 / 大小）

---

## SOP F：早期全量导出包

> 仅 Company 电脑可执行。

```powershell
scripts\pack.cmd
```

用于把历史 `.url` 批量转成的真实文档打包（最初 280 个 `.url` → 279 个真实文档那次）。
**日常不需要**，用 SOP E 即可。

---

## 脚本清单（**仅 Company 电脑可跑**）

全部在 `scripts/`，`.cmd` 是包装器（规避执行策略与引号问题）。
**本机 MacBook / Air 上这些脚本一律不可用**（没有得力租户授权，且脚本是 Windows PowerShell）。

| 脚本 | 用途 |
|---|---|
| `search.cmd` | **检索**云文档/知识库/群聊链接 |
| `meetings.cmd` | 会议纪要 + 逐字稿 |
| `wiki.cmd` | 知识库增量 + zip |
| `techdocs.cmd` | **技术文档专项抓取**（28 篇，按类归档） |
| `packall.cmd` | **打总包**（技术文档+会议+知识库+skill） |
| `grab.cmd` | 按链接抓文档 |
| `pack.cmd` | 早期全量导出包 |

**消费端（本机 / Air）能用的只有两个**：读本地已还原文件、按 RESTORE.md 入库。没有 CLI 路径。

## 权限现状（2026-10-24 全量授权）

已获 216 个 scope，覆盖云文档、云盘、会议、妙记、日历、任务、OKR、邮件、考勤、通讯录。

**两个资源级限制**（OAuth scope 无法解决）：

- **妙记录音**：`minutes +detail` 报 `No read permission`，录音归会议组织者
- **个别文档导出**：`drive +export` 报 `permission_denied(1069902)`，但 `docs +fetch` 通常仍可读

**唯一被企业管理员禁止的 scope**：`vc:meeting.realtime:read`（不可申请）。

## 详细文档

- [SOP.md](./SOP.md) — 完整流程与踩坑记录
- [MEETING.md](./MEETING.md) — 会议抓取专项（note_id 转换等关键细节）
- [RESTORE.md](./RESTORE.md) — 给另一台电脑的还原说明（包的三种类型与字段）
- [references/brain-restore.md](./references/brain-restore.md) — 还原进 ZeYu-AI-Brain 的完整规程（解压转码、落点路由、INDEX、入库记录、提交）
- [SEARCH.md](./SEARCH.md) — 检索能力专项说明
