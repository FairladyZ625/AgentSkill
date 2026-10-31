# 飞书增量包 → ZeYu-AI-Brain 入库规程

RESTORE.md 讲的是「包里有哪三种类型、怎么还原」。本文件讲的是**还原到 Brain 知识库时的具体落点、目录约定和收尾动作**，是 Mac 端每次收到飞书增量包都要走的完整流程。

---

## 一、解压：先解决中文文件名乱码

飞书包由 Windows 侧 PowerShell 打出，zip 条目的文件名通常**没有置 UTF-8 标志位**（`flag_bits & 0x800 == 0`），macOS 的 `unzip` 会把中文文件名解成乱码。

**不要直接 `unzip`**，用 Python 按 `cp437 → gbk` 转码后再落盘：

```python
import zipfile, pathlib
z = zipfile.ZipFile(src_zip)
out = pathlib.Path("/tmp/deli-extract")
for info in z.infolist():
    raw = info.filename
    if not (info.flag_bits & 0x800):
        try:
            name = raw.encode('cp437').decode('gbk')
        except Exception:
            name = raw
    else:
        name = raw
    target = out / name
    if info.is_dir():
        target.mkdir(parents=True, exist_ok=True); continue
    target.parent.mkdir(parents=True, exist_ok=True)
    with z.open(info) as s, open(target, 'wb') as d:
        d.write(s.read())
```

解压后**先打印全部文件名核对结构**，再动手复制。

---

## 二、落点路由

增量包顶层通常是 `会议纪要/` + `公司制度/`（有时还有 `知识库增量/`、`技术文档/`）。按内容性质分流，不要整包丢进一个目录。

| 包内目录 | 落点 | 进 Git |
|---|---|---|
| `会议纪要/<日期>/<会议名>/` | `07-WORK-DOCS/01-得力/05-会议/<日期>/<会议名>/` | 是（md + png） |
| `公司制度/` 原始附件（pptx/pdf/xlsx） | 大文件区 `LOCAL-LARGE-FILES/deli/公司制度-<日期>/` | **否** |
| `公司制度/` 的 md（政策说明） | 原位放大文件区，另建索引页进 Git | 索引进 Git |
| `知识库增量/` | 按 RESTORE.md 类型 A 还原到知识库对应层级 | 视文件而定 |
| `技术文档/` | `07-WORK-DOCS/01-得力/10-技术文档/<分类>/` | 是 |

**判据**：只有文字内容、要被人检索和引用的进 Git；大体积二进制原始附件一律进 `LocalLargeFiles`，在 Git 里留一页索引指过去。这样仓库不会被 3MB 的 pptx 撑起来，同时内容又能被找到。

会议目录名用**会议主题原名**，不翻译、不加日期前缀——日期已经是上一级目录。

---

## 三、建 INDEX 骨架，再跑生成器

Brain 的 INDEX.md 由 `scripts/gen_vault_index.py` 维护 `AUTO:START/END` 区，人工区（`## 说明`）永不被覆盖。

**先写骨架**（带空 AUTO 区），再跑生成器填充：

```markdown
---
tags: [INDEX]
created: YYYY-MM-DD
---

# <名称> · 索引


## 说明

<一句话：这目录是什么、几场会、各自时间与内容>

<!-- AUTO:START generated:YYYY-MM-DD 生成器维护区；行内"——"注释为人工区，刷新时保留 -->
<!-- AUTO:END -->
```

需要骨架的层级：

- 日期目录（`05-会议/2026-10-26/`）
- 会议目录（`.../人工智能研究中心周例会/`）
- `assets/` 目录

然后一次性刷新全库：

```bash
cd ~/Brain && python3 scripts/gen_vault_index.py
```

正常输出形如「新建 N ｜ 刷新 M ｜ 无变化 K ｜ 人工保留 J」。**跑完必须回读上一级 INDEX**（如 `05-会议/INDEX.md`），确认新日期目录已出现在子目录列表里——生成器只写 AUTO 区，若骨架缺失会显示成「未建索引」。

---

## 四、写一页入库记录

在落点根目录写 `入库记录-飞书增量包-<时间戳>.md`，记四件事：

1. **来源**：包名、生成时间、增量起点（读包内 `README.md`）；
2. **分包落点表**：包内目录 → Brain 路径 / 大文件区路径 / 是否进 Git；
3. **会议明细表**：日期 / 会议名 / 时段 / 文件构成；
4. **要点摘要**：每场会两三句，尤其是**挂在本人名下的待办**和确定的时间节点。

第 4 项最容易被跳过，但它是下次会话唯一能快速接上脉络的东西——纪要本身上千字，入库记录让人三分钟内知道这次会定了什么、我要做什么。

---

## 五、提交：只 add 本次产物

Brain 是长期脏的工作区（大量 INDEX 刷新、其他目录改动并存）。**不要 `git add -A`**。

```bash
# 先只加本次路径
git add "07-WORK-DOCS/01-得力/05-会议/<新日期>/" \
        "07-WORK-DOCS/01-得力/05-会议/INDEX.md" \
        "07-WORK-DOCS/01-得力/06-参考资料/<索引>.md"
git diff --cached --name-status      # 复核：只应有本次文件
```

**坑**：目录里残留的 `INDEX 2.md`（同步冲突副本）会被一并加进去。若 `git diff --cached` 里出现 `INDEX 2.md`，先 `git reset -q <该目录>` 重置，再按精确路径重新 add。

另一个坑：`git status --short` 的 `??` 只表示未跟踪，**不代表不该提交**——新会议目录全是 `??`，正常。判断依据是「这个文件是不是本次入库产生的」。

提交后回读 `git status --short -- <本次路径>`，为空才算 clean。

---

## 六、自检清单

- [ ] 解压后中文文件名正常，无乱码
- [ ] 文件数与包内 `MANIFEST.csv` 对得上
- [ ] 会议目录结构 = `纪要.md` + `逐字稿.md` + `assets/*.png`
- [ ] 大体积原始附件（pptx/pdf/xlsx）在大文件区，不在 Git
- [ ] 骨架 INDEX 已建，`gen_vault_index.py` 已跑，上级 INDEX 已回读
- [ ] 入库记录已写，含挂在本人名下的待办
- [ ] `git diff --cached --name-status` 只含本次文件，无 `INDEX 2.md`
- [ ] 提交后本次路径 `git status` clean
