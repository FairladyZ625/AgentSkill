# Brain Git 提交与大批清理

Brain 工作区长期同时存在多个来源的改动（本任务产出、并行清理、未跟踪过程文件）。提交纪律的唯一目标：**任何一次提交都能被解释成「属于同一件事」。**

---

## 一、guard 门禁

- pre-commit guard 在**单次提交暂存删除项 > 20** 时拒绝提交，报错形如：
  `BLOCKED: staged deletion count is N (>20)`
- 逃生阀（**仅**用于已逐项复核的整批清理）：

```bash
BRAIN_GUARD_ALLOW_MASS_DELETE=I_REVIEWED_THIS_MASS_DELETE \
  /opt/homebrew/bin/git commit -m "chore(cleanup): remove reviewed legacy files"
```

- 反向规则：**任务提交永远不开逃生阀**。人物关系、计划文档、知识笔记这类提交只 stage 属于该任务的路径，工作区里其他脏文件和删除项原样留着。

---

## 二、标准流程

**1. 盘点（只读）**

```bash
bash <skill_dir>/scripts/brain-change-inventory.sh /Users/lizeyu/Brain
```

**2. 分类**

- ① 本任务文件
- ② 其他任务的已跟踪改动（` M` / ` D`）
- ③ 未跟踪文件（`??`，通常不进提交）

**3. 任务提交**

逐路径 `git add -- <paths>` 再 commit。提交后本任务路径应从 `git status --short` 消失，其他脏文件保持原样 —— 这是切分正确与否的判据。

**4. 大批清理**（需用户明确授权后执行）

- 方案 A：按 **≤20 个删除项一批**提交；
- 方案 B：整批一次提交 + 逃生阀（仅在已逐项复核时）；
- 两者都不得把并行任务的文件混入，也不得与任务提交合并成一次。

**5. 验证**

```bash
git log --oneline -5
git show --name-status --format="" <hash> | awk '{print $1}' | sort | uniq -c
git status --short | awk '{print $1}' | sort | uniq -c
git diff --name-only --diff-filter=D | wc -l    # 目标：0
```

---

## 三、含 CJK / 空格的路径

`git status --porcelain`（**不带** `-z`）会给这类路径加引号并转义，直接按 `/` 切分顶层目录会切错（出现 `"05-PROJECTS`、`"06-PERSONAL-DOCS` 这种带引号的**假目录名**），据此做的分类全是错的。

始终用 `-z` 按 NUL 分割：

```bash
git status --porcelain=v1 -z | python3 -c '按 b"\0" 分割后切顶层目录'
git diff --name-only -z --diff-filter=D
```

或临时 `git -c core.quotePath=false status --porcelain`。

---

## 四、故障对照表

| 现象 | 真实原因 | 处置 |
|------|----------|------|
| commit exit 1，`BLOCKED: staged deletion count is N (>20)` | guard 拦大批删除 | 分批 ≤20，或复核整批后加逃生阀；**不要反复重试同一命令** |
| commit exit 124 / hook 超时 | post-commit 同步 hook 慢 | 先 `git log -1` 确认是否已落地；已落地就不要再跑 |
| 单次调用里跑几十个 commit 全部超时 | 每个 commit 都触发 post-commit hook | 分批，每批一次独立调用；或复核后整批一次提交 |
| 删除项里出现「个人材料 / 简历 / 交接文档」 | 多为目录重构后的**重复副本**，不是数据丢失 | 先 `find . -name "<文件名>" -not -path "./.git/*"` 确认新位置仍在，再提交删除 |
| push 返回 HTTP 400 | PATH 里的旧 git 不支持 cruft pack | 统一用 `/opt/homebrew/bin/git` |
| 循环提交的调用整体超时（kernel 被杀） | git 子进程先于调用方完成，前几批 commit 已静默落地 | 超时后先 `git log --oneline -20` 核对实际进度，从未落地处续跑；不要从头重跑（`git reset` 只影响暂存区，不影响已落地 commit） |
| escape valve 提交混进了 22 个无关 M 文件 | `git add -u` 暂存的是**全部已跟踪改动**，不止删除 | 见下方第五节「不要用 git add -u」 |

---

## 五、不该做的事

- **不要**用 `git add -A` / `git add .` 收尾「顺便清干净」—— 工作区里其他任务的改动会被裹进本次提交，等于替别人做决定。
- **不要**用 `git add -u` 做「纯删除」清理提交 —— `-u` 同样会把所有已跟踪修改（脚本、cron prompt、无关 M 文件）一并暂存进 cleanup commit，事后无法解释。纯删除提交的路径清单只能来自 `git diff --name-only -z --diff-filter=D`，逐路径 stage 后 commit。
- **不要**在没确认删除目标仍有副本的情况下提交大批删除；编号目录重构（如 `NN-` 旧目录 → `12-` 新目录）最容易产生这种重复副本。
- **不要**把 guard 的拒绝当成需要绕过的障碍。它拦下来是在提示「这次提交讲不出一件事」，正确动作是改切分方式，不是加逃生阀。
- **不要**在用户只给了笼统授权（"全部分批提交"）时扩大范围到用户没看过的类别 —— 先给出分类清单，再按授权范围执行。

---

## 六、数字副本清理（`xxx 2.md` 这类未跟踪文件）

Finder / 同步工具产生的编号副本是**未跟踪文件**，不进 git 提交，用 `trash` 清理（可恢复优先，不用 `rm`）。删副本前逐项验证，全部满足才删：

1. 同目录原文件存在（`xxx.md`）；
2. 内容比对用 Python 哈希（`hashlib.md5`）—— shell 的 `for pair in "a b"` 循环在含空格路径上会拆错参数，比对结果不可信；
3. 原文件 mtime ≥ 副本 mtime（原文件在持续更新、副本是旧快照时才可删；若副本更新，先停下来人工看差异）；
4. 原文件已被 git 追踪且干净。

一次 `trash` 传太多路径可能超时：分批（≤10 个/次）并给足 timeout；超时后先核对哪些已进废纸篓（`git status` 复核剩余），只补删未删的。收尾用「编号副本剩余数 = 0」验证。

注意：副本清完后剩余的 `??` 未跟踪文件（rendered PDF、digest、`output/` 抓取资产等）多半是各管线的正常产出——**不是垃圾**，未经对应管线归属判断不动它们。
