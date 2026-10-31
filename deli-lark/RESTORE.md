# RESTORE.md — 给「另一台电脑」的 agent

你拿到的是一批从飞书导出的 zip 包。本文件说明如何把它们还原到本地对应位置。

**先读第三节「包的类型」**，两种包的还原逻辑不同。

---

## 一、包在哪里、长什么样

### 知识库包：`增量\<日期>.zip`

```
2026-10-24.zip
├── files\                                      # 文档本体，已按飞书层级排好
│   └── AI产品开发工作流工作组\
│       ├── 得力Iot平台接入指引.md
│       └── FDE-前端应用接入得力e+APP.md
├── index.csv                                   # 人可读索引
└── index.json                                  # 机器可读索引（优先用这个）
```

**特点**：一天一个 zip，当天多次同步会**累积**进同一个 zip。
所以一个 zip 里可能有当天多个批次加进来的文件，索引也是合并后的全量。

### 会议包：`会议归档\<日期>\<会议主题>\`

```
2026-10-23\技术栈对齐\
├── 纪要.md          # AI 智能纪要
├── 逐字稿.md         # 原文转写（带说话人+时间戳）
└── assets\          # 图片
    ├── 技术栈对齐-1.png
    └── ...
```

**特点**：每场会议一个独立文件夹，天然幂等，直接复制即可。

---

## 二、index.json 字段

知识库包（`增量\*.zip`）的字段：

```json
{
  "original_path": "人工智能研究中心研发知识库\\AI产品开发工作流工作组\\得力Iot平台接入指引.md",
  "title": "得力Iot平台接入指引.md",
  "obj_type": "file",
  "obj_token": "HYjnbyBScoXLRgxPmC6c5Q6cnDg",
  "node_token": "...",
  "url": "https://nbdeli.feishu.cn/wiki/...",
  "edit_time": "1792663864",
  "local_relpath": "files\\AI产品开发工作流工作组\\得力Iot平台接入指引.md",
  "bytes": 12114,
  "status": "OK",
  "error": ""
}
```

全量导出包（`飞书文档导出包-*.zip`）的字段：

```json
{
  "original_relpath": "AI品类发展\\学生用品\\xxx.url",
  "name": "xxx",
  "type": "docx",
  "url": "https://www.feishu.cn/docx/XXXX",
  "exported_relpath": "AI品类发展\\学生用品\\xxx.docx",
  "size_bytes": 12345,
  "status": "OK",
  "error": ""
}
```

| 字段 | 含义 |
|---|---|
| `original_path` / `original_relpath` | 在飞书里的**原始层级路径**（第一段是知识库名） |
| `local_relpath` / `exported_relpath` | 在 zip 内的**实际文件位置**，用它找源文件 |
| `obj_type` / `type` | `docx` / `bitable` / `file` / `sheet` / `slides` |
| `status` | `OK` 才处理，`FAIL` 的看 `error` |
| `bytes` / `size_bytes` | 文件大小，可用于校验 |

---

## 三、包的类型与还原方式（重要）

### 类型 A：知识库增量包（`增量\<日期>.zip`）

按 `local_relpath` 取源文件，按 `original_path` 放目标：

```
源  : <解压目录>\files\AI产品开发工作流工作组\得力Iot平台接入指引.md
目标: <目标根>\人工智能研究中心研发知识库\AI产品开发工作流工作组\得力Iot平台接入指引.md
```

去掉 `original_path` 第一段（知识库名）也常见，取决于你希望的组织方式。
**建议保留知识库那一级**，与飞书侧保持一致，避免以后多知识库时冲突。

### 类型 B：会议包（`会议归档\<日期>\<会议主题>\`）

直接整目录复制：

```
<目标根>\会议归档\2026-10-23\技术栈对齐\
  ├── 纪要.md
  ├── 逐字稿.md
  └── assets\
```

`.md` 里的图片已改成相对路径 `assets/xxx.png`，整目录搬过去即可正常显示。

### 类型 C：全量导出包（`飞书文档导出包-<时间戳>.zip`）

这是早期从 `.url` 批量导出的产物：

| url 路径 | 原始类型 | 导出成 | 说明 |
|---|---|---|---|
| `/docx/` | 飞书文档 | `.docx` | 原生 Word |
| `/base/` | **多维表格** | `.xlsx` | 只有数据，无视图/表单逻辑 |
| `/sheets/` | 电子表格 | `.xlsx` | 原生导出 |
| `/slides/` | 幻灯片 | `.pptx` | 原生导出 |

还原：把原 `.url` 位置替换成同名 `.docx`/`.xlsx`/`.pptx`。

---

## 四、冲突策略

目标文件已存在时：

- 大小与 `bytes`/`size_bytes` 一致 → **跳过**
- 大小不一致 → 重命名为 `<原名> (来自<包名>).<ext>`，**绝不覆盖**
- 冲突记录写入 `restore-conflicts.csv`

## 五、幂等性

重复还原同一个包必须安全：

- 知识库包：同一批次重复解压，文件内容相同 → 跳过
- 会议包：直接覆盖即可（内容由飞书侧决定，本地不会改）

---

## 六、失败项怎么看

`status == "FAIL"` 的记录**在包里没有对应文件**，不要去找。

常见 `error`：

| error | 含义 | 处理 |
|---|---|---|
| `permission_denied(1069902)` | 导出时无资源权限 | 无解，跳过 |
| `unsupported obj_type: xxx` | 脚本不支持该类型 | 反馈给维护者 |
| `file not found: xxx` | 源文件已在本地被移动 | 跳过 |

---

## 七、不要做的事

- **不要**试图访问 `url` 字段的链接 —— 你那台电脑没有飞书文档权限
- **不要**修改 `index.json` —— 它是校验依据
- **不要**把 `.md` 当成飞书原生文档再传回飞书 —— 格式会丢

---

## 八、快速校验

```powershell
# 解压后核对文件数与索引条数是否一致
$idx = Import-Csv "index.csv"
$okCount = ($idx | Where-Object status -eq 'OK').Count
$fileCount = (Get-ChildItem files -Recurse -File).Count
Write-Output "索引OK=$okCount  实际文件=$fileCount"   # 两者应相等
```
