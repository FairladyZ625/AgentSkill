---
name: zeyu-ai-brain-sop
version: "2.0"
description: |
  ZeYu AI Brain 知识库标准操作规程（SOP）v2.0
  所有 Agent 操作知识库的唯一权威指南。

  包含：目录治理、计划文档治理、写入模式、检索规则、obsidian-cli 规范、
  外部文章资产治理、Task/Todo 宪章、巡检标准。

  **v2.0 核心变更**：
  - 废弃 Writer-Agent 中转模式，改为 Agent 直接写知识库 + 自己 commit
  - 废弃旧脚本（create-task-skeleton / update-task-status / archive-task）
  - 目录结构更新为当前真实结构
  - 合并 brain-folder-governance 和 knowledge-plan-governance 为统一入口
  - 检索工具统一为 Agent Graph、Obsidian CLI 与受范围约束的文件搜索；不依赖向量检索
tags:
  - knowledge-base
  - sop
  - governance
  - directory
  - plan
applies_to:
  - All Agents
maintainer: 李泽宇
updated: 2026-04-25
---

# ZeYu AI Brain 知识库 SOP v2.0

**单一真相源（SSoT）— 所有 Agent 操作知识库的唯一权威指南。**

---

## 一、核心原则

1. **SSoT**：知识库操作规范只在此 skill 中定义，不在各 workspace 散落维护。
2. **强制阅读**：任何 Agent 操作知识库前必须先读此 skill。
3. **直接写入**：Agent 自己写知识库 → 自己 `git commit` → 自己确认 clean status。不再经 Writer-Agent 中转。
4. **先看结构再落位**：写入任何文件前，先确认目标目录的真实结构和设计意图。
5. **回执标准**：凡对知识库有改动，回执必须附 `commit hash` + `git status --short`（必须为空）。
6. **Brain-native Agent**：Harness/Task 只是执行面，不是正式知识真相源；文字型研究、规划、个人事务和治理产物必须回流 Brain canonical 落点，不能长期留在外部 workspace 形成第二份正式版本。
7. **先检索后写作**：Agent 必须先用 Brain Search 的直接搜索协议查当前事实和已有文档，再写新稿；外部研究必须保留 canonical URL、核验日期和证据边界。搜索必须限定范围、回读原文；空结果不得证明全库不存在。
8. **交付分层**：原始抓取和过程日志进 `LOCAL-LARGE-FILES/`，稳定结论进对应 Brain 正式目录；研究草稿不自动等于正式知识。

---

## 二、Brain-native Harness 回流流程

当 Brain 文字任务由 Harness Agent 执行时，统一采用：

```text
Harness Work/Task → 读 Brain SOP + Brain Search → 检索当前真相源
→ fact / decision / proposal / open question 分层
→ 写入 Brain canonical 落点或 LOCAL-LARGE-FILES 过程层
→ 独立复核 → Agent 自己 commit → clean status 回执
```

Task 的 `planned`、派工受理、`submitted` 都不是完成证据；必须分别报告 `executing`、`reviewed`、`deployed` 等真实阶段。需要外发、部署、付款、购票、签证预约或其它不可逆动作时，仍须泽宇明确批准。

### Harness Task 计划最低完整度

不要直接启动包含默认 scaffold 占位文本的 Task。启动前至少补齐：Goal、Context、Required Reading、Entry Conditions、Dependencies、Execution Surface、Constraints、Checkpoint、Implementation Plan、Deliverable Contract、Evidence Protocol、Verification。

对跨 skill、prompt、cron、脚本或运行时资产的治理变更，先在 Brain canonical 计划目录写出任务计划，再创建 Harness Work；计划必须区分 live dependency 与历史记录，写明回滚、验收和同机制搜索。仅产出计划/审阅包时使用 task-package-artifact/docs-task，不要用无关仓库 HEAD 冒充 repository-diff 交付；只有真实行为变更才提交任务-owned delivery commit。需要独立第二视角时，提交可审阅切片后用 Harness 的 adjudicate/dispatch-review 派给已声明的 reviewer；派工回执不等于评审完成，必须回收评审证据并处理遗漏。用户指定 Agent/模型后，核对 dispatch 的 agent、provider、model 和 runtime；若自动派工落到默认实例，先取消错误 dispatch，再用显式 agent + instance + model 重派，不能把错误 runtime 的成功回执当成指定 Agent 已执行。

## 二、写入模式（v2.0）

### 旧模式（已废弃）
~~Agent 在 workspace 写完 → 通知 Writer-Agent → Writer-Agent 复制到知识库~~

### 新模式（当前生效）
Agent 直接写到知识库对应目录 → 自己 `git add` + `git commit` → 回执附 hash + clean status。

### 提交 Hook 与外部同步边界

- 提交前检查当前生效的 `core.hooksPath` 与相关 hook；`post-commit` 可能自动推送远端或镜像到云盘，这些是外部写入，不是本地 commit 的隐含授权。
- 未获外部同步授权时，只完成本地提交：先手动运行必需的 `brain-git-guard.sh`、只暂存任务-owned 路径并核对 staged list，再用单次命令覆盖 hook 路径（Unix 可用 `git -c core.hooksPath=/dev/null commit ...`）；不要改持久 hook 配置。回执明确说明未推送/未镜像。
- 用户明确授权远端同步时，执行标准提交流程，并按对应平台要求回读验证远端目标；无论哪种模式，都不能绕过 Brain guard 或扩大暂存范围。
- **Brain 仓库长期是脏的，逐路径 add 而不是整目录或 `-A`。** 大量未提交的 INDEX 刷新、其他目录改动会与本次产物同时存在；`git add` 只给本次路径，然后 `git diff --cached --name-status` 复核，只应有本次文件。
- **目录里残留的 `INDEX 2.md`（同步冲突副本）会被一并加进去。** 若 staged list 出现它，先 `git reset -q <该目录>` 重置，再按精确路径重新 add；不要靠 `grep -v` 过滤后继续提交。
- `git status --short` 的 `??` 只意味着未跟踪，不代表不该提交——新建目录全部是 `??` 才正常。判断依据始终是「这个文件是不是本次产出的」。

### 写入前必做检查
1. 这是 prompt 还是正式文档？（prompt → `04-SYSTEM/prompts/`；正式文档 → 对应知识域目录）
2. 目标路径是否在 Brain 知识库下？（不是 workspace）
3. 目标目录是否已存在？（先看再写，不凭印象）
4. 是否需要新建目录？（如需，见下方「目录治理」）

---

## 三、当前目录结构

见 `zeyu-brain-guide`，并以实际 `find` 结果为准。

---

## 四、目录治理规范

### 铁律

> **不要凭印象在 Brain 里造目录。先看现状，再落位置。**

### 新建目录前的强制步骤

**Step 1：先 double check 当前真实结构**

至少执行：
```bash
find <Brain路径>/<目标父目录> -maxdepth 1 -type d | sort
```

关键：新建子目录时，看的是**该层的编号**，不是顶层编号。
例如在 `01-PERSONAL-OPS` 下新建子目录，要看的是 `01-PERSONAL-OPS` 内部已有哪些编号（`01-07`），而不是顶层的 `00-09`。

**Step 1.5：必须看目录内容，不能只看文件夹名**

在往任何目录写入新文件之前，必须先读取该目录下已有文件（至少 2-3 个），理解这些文件的内容类型、格式、服务对象。确认你要写入的内容与该目录的设计意图一致。

典型反例：
- `02-PLANS-AND-SCHEDULES` 看名字像"计划"，但实际内容是泽宇个人的排期面板（本周排期、核心目标、月度里程碑）
- 如果只看文件夹名就往里塞 agent 产出的治理计划，就会搞乱整个目录的设计

**Step 2：判断"复用"还是"新建"**

优先级：
1. 复用已有目录
2. 在已有父目录下新增子目录
3. 最后才考虑新增一级目录

**Step 3：检查编号唯一性**

- 顶层编号不得重复
- 同级下的编号命名要与当前结构一致
- 不允许出现语义冲突的重复编号

### 新建目录后的 INDEX 生成（标准动作）

Brain 的 `INDEX.md` 由 `scripts/gen_vault_index.py` 维护，分两个区：`<!-- AUTO:START -->…<!-- AUTO:END -->` 生成区，和 `## 说明` 人工区。生成器**永不触碰人工区**，只重写 AUTO 区；渲染结果与现有文件相同时不落盘（mtime 不动）。

所以新建目录时**不要手写子目录列表**——手写会被下次运行覆盖，而且格式对不上。正确顺序：

1. 先写骨架，只填人工区，AUTO 区留一对空标记：

```markdown
---
tags: [INDEX]
created: YYYY-MM-DD
---

# <目录名> · 索引


## 说明

<一句话：这目录是什么、谁在用、当前状态>

<!-- AUTO:START generated:YYYY-MM-DD 生成器维护区；行内"——"注释为人工区，刷新时保留 -->
<!-- AUTO:END -->
```

2. 一次性刷新全库：

```bash
cd ~/Brain && python3 scripts/gen_vault_index.py
```

输出形如「新建 N ｜ 刷新 M ｜ 无变化 K ｜ 人工保留 J」。

3. **回读上一级 INDEX 验证**：新目录必须出现在父目录的子目录列表里；若显示成「未建索引」，说明骨架没建或生成器没扫到，不要当成已完工。
4. 只对「有内容或即将有内容」的层级建骨架，空中间目录先不建。
5. 人工维护的 INDEX（无 AUTO 标记）与代码仓 stub 会被生成器跳过，改这种目录只能手改。

### 新建 05-PROJECTS 项目后的强制步骤

每次在 `05-PROJECTS/` 下新建项目目录后，必须同步更新：
1. `05-PROJECTS/INDEX.md`：在对应分类（公司/个人/探索/基础设施）下追加一行。
2. `05-PROJECTS/projects-index.md` 已标记 deprecated，**不再维护**，不要往里加内容。
3. 项目方案、任务、验证结果放项目工作材料；收到的外部原文放项目内清楚标明的 `sources/`（或既有等价目录），保持原样，不把来源文档当成现状真相源。
4. 在 `project-brief.md` 中分开记录“来源方案的主张”“当前已验证事实”和“待确认项”；有交付物不等于已实施，有容量/SLO估算不等于实测。

分类判断：
- 公司项目（Company）：公司出资、公司 GitHub 组织、公司业务相关
- 个人项目（Personal）：泽宇个人出资/主导、个人 GitHub
- 基础设施（Infra）：Agent 治理、Brain OS 运维、工具链
- 探索（Explore）：实验性、未立项、孵化中
- 边界模糊时允许出现在多个分类下

### 公司 WorkDocs 与跨公司迁移

- WorkDocs 按公司分设独立工作区；各公司工作区复用同一套功能分类，项目、合同、发票、会议等不能跨公司混放。
- 迁移前先列出源目录全部一级内容，逐项映射到目标公司的对应分类；确认目标路径冲突、隐藏/忽略文件、软链接和特殊文件，再执行移动。
- **按日期整理汇报材料时，先跨相关项目检索候选文件，按文件内容、最终版本标记和实际汇报日期辨认归属；不要只看用户提到的单一项目路径。** 同一汇报包可能分散在项目的 `explainer/`、`sources/` 和其他项目的历史演讲目录中。
- **为每个汇报日期建立一个简短、可读的主题文件夹，并给 HTML 等交付文件改成描述性文件名；在文件夹内放 README 说明用途和文件角色。** 版本草稿只迁最终/指定版本，除非用户明确要求保留全量版本。
- 迁移后核对源目录已清空、目标文件数量/字节量或哈希相符、版本控制识别为新增/重命名而不是意外删除；检查 `.gitignore` 是否令移动后的文件漏出版本控制，必要时定向纳入原有受控文件。
- 更新 WorkDocs 索引与公司 README，并只提交本次迁移范围；不要把并行产生的其他 Brain 改动带入同一提交。

### 会议纪要与外部资料包入库

从飞书等外部系统拉回的增量包，按内容性质分流而不是整包丢进一个目录：文字类（纪要、逐字稿）进公司工作区的 `05-会议/<日期>/<会议主题>/`；大体积原始附件（pptx / pdf / xlsx）进 `LOCAL-LARGE-FILES/<公司>/`，Git 里只留一页索引指过去。完整步骤（中文文件名转码解压、落点路由表、INDEX 骨架与生成器、入库记录、提交纪律）见 相邻 skill `deli-lark`（`/Users/lizeyu/.agents/skills/deli-lark/references/brain-restore.md`）。

### 项目归档审阅（不是自动清理授权）

- 用户要求“盘点哪些项目可归档/清理”时，先交付候选清单，不因此直接移动、删除项目或停服务；等用户明确选择后再执行。
- 交叉核对项目目录、`project-brief.md` 的状态/说明、索引和近期材料。索引可能过时；目录缺 brief 只代表状态不明，不等于废弃。
- 分开列：明确取消、被取代/历史、状态不明或仍有近期活动。注明每项证据和归档前依赖检查；“不再推进”也不代表关联服务可以自动停止。
- 归档优先于删除，保留 Git 历史、交叉引用和必要入口；永久删除另需明确授权。

### 高风险动作（需泽宇确认）

- 新建顶层编号目录
- 重命名现有顶层编号目录
- 跨大区迁移大量文档
- 新建会影响全局约定的结构层
- 根据项目盘点清单实际归档、删除项目或停止服务（用户逐项明确批准后执行）

---

## 五、计划文档治理

### 一句话判断

> 这份文档是给人审阅/协作/审批的，还是给 agent 执行的？

- 给人审阅、协作、审批、复盘 → **计划文档** → 进知识库
- 给 agent 执行、自动化任务读取 → **prompt / context** → 放 `04-SYSTEM/prompts/`
- 未成形中间稿 → **草稿** → 可暂放 workspace（但一旦正式化必须迁入知识库）

### 正式计划不得长期只放 workspace

满足以下任一条件的计划，必须迁入知识库：
- 可以给泽宇看
- 需要团队协作执行
- 需要后续复盘追踪
- 已经不是临时碎片，而是结构化文档

### 已确认落点速查表

| 计划类型 | 落点 |
|----------|------|
| 某个具体项目的计划 | `05-PROJECTS/<project>/plans/` |
| Agent 治理/流程/规范类计划 | `01-PERSONAL-OPS/06-AGENT-PLANS/` |
| 泽宇个人排期/目标/里程碑 | `01-PERSONAL-OPS/02-PLANS-AND-SCHEDULES/`（⚠️ 仅泽宇个人用） |
| Prompt / 执行材料 | `04-SYSTEM/prompts/` |

### 双版本防呆

如果同一份计划同时在 workspace 和知识库出现：
1. 知识库版本为正式版（SSoT）
2. workspace 版本必须删除或标记为 `draft` / `obsolete`
3. 不允许长期并行维护两份正式版本

---

## 六、People Network 写入规范

`02-PEOPLE-NETWORK/_registry.yaml` 是脚本自动生成的，**不能手动编辑**。正确的工作流：

1. 直接在 `02-PEOPLE-NETWORK/<layer>/<slug>/_profile.md` 新建或编辑 Person Card
2. 在 `02-PEOPLE-NETWORK/relations/org-membership.yaml` 追加 org 成员关系
3. 新建 org 在 `02-PEOPLE-NETWORK/orgs/<org-id>.md`
4. 文件写完后运行脚本重建 registry：
   ```bash
   cd /Users/lizeyu/Brain && python 02-PEOPLE-NETWORK/scripts/build_registry.py
   ```
5. git commit 包含新建的 `_profile.md`、`org-membership.yaml` 变更和脚本重建的 `_registry.yaml`

⚠️ 写入 Person Card 前先读 `02-PEOPLE-NETWORK/_schema.md`，确认字段格式。Dunbar 层级决定物理目录：`00-INNER-CORE / 01-CLOSE-CIRCLE / 02-ACTIVE-NETWORK / 03-KNOWN-CIRCLE / 04-WEAK-TIES`。

---

## 六、obsidian-cli 工具规范

Brain 是 Obsidian vault，已配置 `obsidian-cli`（默认 vault: ZeYu-AI-Brain）。

### 核心规则：移动/重命名必须用 obsidian-cli

| 操作 | 禁止 | 必须用 | 原因 |
|------|------|--------|------|
| 移动/重命名笔记 | `mv` | `obsidian-cli move` | 自动更新所有 `[[wikilinks]]` 和 Markdown 链接，防止断链 |
| 删除笔记 | `rm` | `obsidian-cli delete` | 通过 vault 正规链路删除 |
| 交互式模糊搜索笔记名 | `obsidian-cli search`（不接受位置参数） | 利用 vault 索引并打开选择结果 |
| 非交互式确认笔记可见 | `obsidian-cli list "<目标目录>" --vault ZeYu-AI-Brain` | cron / CI 中列目录确认目标文件名 |
| 搜索笔记内容 | `obsidian-cli search-content "<关键词>" --vault ZeYu-AI-Brain` | 带上下文片段的结构化搜索 |
| 搜索实体关系 | Agent Graph | 从实体/关系入口缩小范围，再回读 canonical note |

### 唯一例外

以下情况可以直接操作 `.md` 文件：
- 纯编辑文件内容（追加、修改文本）— Obsidian 会自动感知文件变化
- 批量脚本操作（如 git commit/push）
- obsidian-cli 不可用时的降级操作 — 但必须在回执中标注「降级：未使用 obsidian-cli，可能存在断链风险」

### move 命令路径格式（重要）

`obsidian-cli move` 接受的路径是**vault 内相对路径，不带 `.md` 扩展名**。路径从 vault 根目录（ZeYu-AI-Brain/）下的子目录开始，不要加 vault 根前缀。

```bash
# ✅ 正确：vault 相对路径，不带 .md
obsidian-cli move "02-PEOPLE-NETWORK/03-KNOWN-CIRCLE/colleagues/zhang-zong-deli/_profile" \
  "02-PEOPLE-NETWORK/06-ARCHIVED/zhang-zong-deli/_profile" --vault ZeYu-AI-Brain

# ✅ 正确：普通笔记
obsidian-cli move "00-INBOX/old-name" "03-KNOWLEDGE/01-DOMAINS/new-name" --vault ZeYu-AI-Brain

# ❌ 错误：带 .md 扩展名
obsidian-cli move "00-INBOX/old-name.md" "03-KNOWLEDGE/new-name.md"

# ❌ 错误：使用绝对路径
obsidian-cli move "/Users/lizeyu/Brain/00-INBOX/old-name" ...
```

路径不匹配时报 `Cannot find note in vault`；检查路径层级，不要包含 vault 根目录名。

### 非交互式可见性验收

`obsidian-cli search` 是交互式 fuzzy picker，**不能**写成 `obsidian-cli search "note-name"`。在 cron / CI 里确认新文件已被 vault 看见，应列出精确父目录：

```bash
obsidian-cli list "03-KNOWLEDGE/99-SYSTEM/03-INTEGRATION-REPORTS/run-reports/YYYY-MM-DD" --vault ZeYu-AI-Brain
```

若要按正文关键字查找，使用：

```bash
obsidian-cli search-content "关键词" --vault ZeYu-AI-Brain
```

---

## 七、外部文章抓取资产治理

### 两层分离

**A. 正式知识层（进 Brain Git）**
- 提炼后的 `.md` 笔记
- cross-analysis / digest / topic / pattern 等结构化知识产物
- 极少量不可替代的关键配图（默认不保留）

**B. 原始抓取层（不进 Brain Git）**
- OCR 图片包、截图
- 原始 PDF / EPUB / Office 附件
- debug html、原始 API 响应
- 任何可再抓取、可再生成的中间产物

### 原始抓取资产默认落点

```
LOCAL-LARGE-FILES/knowledge-sources/<domain>/<yyyy-mm-dd>-<slug>/
```

### 铁律

> **Git 只存知识结论层，本地大文件区存原始抓取证据层。**

---

## 八、检索规则

### 工具选择

| 场景 | 工具 |
|------|------|
| 找长期记忆 / memory 文件 | `memory_search` |
| 找实体、项目关系、引用链 | Agent Graph |
| 找笔记名 | `obsidian-cli search` |
| 找笔记正文 | `obsidian-cli search-content "<关键词>" --vault ZeYu-AI-Brain` |
| 找受范围约束的文件内容 | filesystem keyword search |

### 直接搜索工作流

1. 先读 `zeyu-brain-search` 的 Brain directory map 或对应项目的 `INDEX.md`，确定搜索范围。
2. 对人物、项目、任务和关系问题，先从 Agent Graph 入口查实体关系。
3. 对正文和文件名，使用 `obsidian-cli search-content` 或范围明确的文件搜索。
4. 打开候选原文核验，并保留 canonical path。
5. 写出搜索范围和证据边界；空结果只能说明当前范围未找到。

### 常见误区

- ✖ 用 `memory_search` 查知识库正文（它只搜记忆文件）
- ✖ 未限定范围就扫描全部 raw、session 或 Brain，造成上下文爆炸
- ✖ 只靠文件名或摘要做结论，未回读原文
- ✖ 把当前搜索范围无命中包装成“全库不存在”

---

## 九、Task/Todo 宪章

### 定义

- **Task（任务包）**：跨天、多步骤、多人协作、有交付物、需进度风险管理的工作包。
- **Todo（动作项）**：单动作、短周期、可快速完成的执行项。

### 判定规则（满足任一即建 Task）

1. 预计周期 > 1 天
2. 需要 2 人及以上协作
3. 有正式交付物（文档/代码/报告）
4. 需要进度管理（%/风险/ETA）

不满足以上条件，默认建 Todo。若 Todo 超过 24h 未闭环或出现外部阻塞，升级为 Task。

### Todo 写入位置

统一写入 `00-INBOX/todo-backlog.md`，格式：
```markdown
- [ ] [P1] 任务标题
  - 领域：XXX
  - 重要性：高/中/低
  - 紧急性：高/中/低
  - 截止：YYYY-MM-DD
  - 下一动作：XXX
  - 状态：待办/进行中/已完成
```

### 状态机

**Task 状态**：待启动 → 进行中 → 等待反馈 / 暂停 / 已完成 / 已取消

> `等待反馈` 不等于完成，不可归档。

**Todo 状态**：`[ ]` 待办 → `[x]` 已完成 / `[~]` 已取消

### 归档规则

- Task 仅当状态为「已完成」或「已取消」时可归档，目录移至 `09-ARCHIVE/`
- 无 Task 的已完成 Todo 不进 `09-ARCHIVE/`，在 `todo-backlog.md` 勾选完成后按月转存到 `00-INBOX/todo-archive-YYYY-MM.md`
- 主 backlog 仅保留：未完成 + 近 14 天已完成项

---

## 十、巡检标准

### 巡检重点

1. 正式稿是否写在知识库而非 workspace
2. 目录结构是否符合规范（编号唯一、语义归属正确）
3. 脏仓库检查（未提交的改动）
4. Task/Todo 状态与归档一致性
5. 双版本问题（workspace 和知识库同时存在同一份文档）
6. 外部文章原始资产是否误入 Git

### 报告格式

- 🔴 HIGH（需立即处理）
- 🟡 MEDIUM（需跟进）
- 🟢 LOW（观察）

### 回执最低标准

凡对知识库有改动，回执必须附：
- `commit hash`
- `git status --short`（必须为空）

---

## 十一、特殊目录说明

以下目录由系统/插件生成或自动化流程使用，不遵循 Brain 主编号体系：

| 目录 | 性质 | 说明 |
|------|------|------|
| `ibooks-highlights/` | 插件自动生成 | Apple Books Obsidian 插件导入的原始笔记 |
| `scripts/` | 自动化脚本 | 如 `import-apple-books.sh` |
| `06-PERSONAL-DOCS/09-READING/` | 读书系统 | `00-BOOKS/` 每书一文件夹 + `01-DIGESTS/` 跨书摘要 |
| `LOCAL-LARGE-FILES/` | 本地大文件 | 不进 Git，存原始抓取资产 |

---

## 版本历史

### v2.0 (2026-04-25)
- 废弃 Writer-Agent 中转模式，改为 Agent 直接写知识库 + 自己 commit
- 废弃旧脚本（create-task-skeleton / update-task-status / archive-task）
- 目录结构更新为当前真实结构
- 合并 brain-folder-governance 和 knowledge-plan-governance 为统一入口
- **检索工具统一为 Agent Graph、Obsidian CLI 与受范围约束的文件搜索；不依赖向量检索**
- 新增 obsidian-cli 工具规范
- 新增外部文章抓取资产治理

### v1.3 (2026-03-05)
- 新增交付物同步工作流（已废弃）

### v1.2 (2026-03-04)
- 新增 Task/Todo 宪章

### v1.1 (2026-03-04)
- 新增脚本优先规则（已废弃）

### v1.0 (2026-03-04)
- 初始版本
