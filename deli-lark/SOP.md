# deli-lark — 飞书文档同步 SOP

把飞书内容（会议纪要 / 逐字稿 / 知识库）落到本地，打包 zip 供另一台无权限电脑还原。

---

## 零、四条主流程速查

| 场景 | 命令 | 产物 |
|---|---|---|
| **会议纪要+逐字稿** | `scripts\meetings.cmd -Days 7` | `会议归档\日期\会议名\{纪要,逐字稿}.md` |
| 按链接抓文档 | `scripts\grab.cmd -Url "url1,url2"` | `增量\会议纪要\YYYY-MM\标题.md` |
| 知识库增量 | `scripts\wiki.cmd` | `增量\YYYY-MM-DD\files\` + zip |
| 打包传输 | `scripts\pack.cmd` | `_packs\飞书文档导出包-<时间戳>.zip` |

**会议抓取是本项目主线**，详见 [MEETING.md](./MEETING.md)。
关键：`note_id` 不是文档 token，必须用 `note +detail` 转换出
`note_doc_token`（纪要）和 `verbatim_doc_token`（逐字稿）。

---

## 一、先搞清楚：两条通道，权限完全不同

这是本 SOP 最重要的部分，踩过很多坑。

| 通道 | 命令 | 受什么限制 | 结果 |
|---|---|---|---|
| **读取正文** | `docs +fetch` | 只需**阅读权限** | ✅ 能读绝大多数文档 |
| **官方导出** | `drive +export` | 需要**资源下载/导出权限**（资源级，非 OAuth） | ❌ 常报 `1069902 permission_denied` |

**实测例证**：`WAIC 2026 - 我们又来了！` 这篇，`drive +export` 报 `permission_denied(1069902)`，
但 `docs +fetch` 完整读到 6783 字符。**所以永远优先用 fetch，不要依赖 export。**

- docx → fetch 得 Markdown
- bitable → `base +table-list` + `base +record-list` 得 CSV
- sheet / slides → 只能 export，权限不足时记录失败

---

## 二、数据源可用性（2026-10-24 全权限后实测）

| 数据源 | 能否自动发现 | 说明 |
|---|---|---|
| **会议**（`vc +search`） | ✅ 能 | 需传真实 open_id，不认 `me` |
| **会议纪要/逐字稿** | ✅ 能 | `vc +detail` → `note +detail` → `docs +fetch` |
| **知识库节点**（wiki） | ✅ 能 | `wiki nodes list` |
| **云盘文件夹** | ✅ 能 | `drive files list --params`（已获 `space:document:retrieve`）|
| 文档搜索（`docs +search`） | ⚠️ 不可靠 | 调通但常返 0 条 |
| 妙记录音（`minutes +detail`） | ❌ 资源级无权限 | 录音归会议组织者 |

**关键结论**：会议纪要和逐字稿**已经可以全自动抓取**，不依赖搜索、不依赖链接。
详见 [MEETING.md](./MEETING.md)。

知识库（`人工智能研究中心研发知识库`，33 节点）是**部门模板库，不含会议纪要**，
同步它只能得到模板文档。

---

## 三、目录结构

```
C:\Users\Administrator\Documents\人工智能研究中心\
├── <11 个业务文件夹>              # Downloads 迁入，511 文件 / 4.09 GB
├── 会议归档\                       # 会议纪要+逐字稿（主产物）
│   ├── 2026-10-23\技术栈对齐\
│   │   ├── 纪要.md
│   │   ├── 逐字稿.md
│   │   └── assets\*.png
│   ├── .meeting-state.json        # 会议增量基准
│   └── _logs\
├── 增量\
│   ├── 2026-10-23\               # 知识库同步：按日期
│   │   ├── files\                # 按飞书原始层级还原
│   │   ├── index.csv
│   │   └── index.json
│   ├── 2026-10-23.zip
│   └── 会议纪要\                  # 按链接抓取：按月份
│       ├── 2026-10\
│       │   ├── 智能纪要：xxx.md
│       │   └── assets\xxx-1.png
│       └── 2026-09\
├── _packs\                        # 导出包（带时间戳）
│   ├── 飞书文档导出包-20261023-175811.zip
│   └── packs.csv
├── index-会议纪要.csv
├── _logs\
└── .sync-state.json              # 知识库增量基准
```

---

## 四、SOP A：抓单篇/多篇文档（最常用）

**触发**：用户给了飞书链接。

```powershell
# 单篇
powershell -NoProfile -ExecutionPolicy Bypass -File lark_doc_grab.ps1 `
  -Url "https://nbdeli.feishu.cn/docx/LANbdvWjZocl0CxfnJbcObZMnpg"

# 多篇（逗号分隔，最稳）
powershell -NoProfile -ExecutionPolicy Bypass -File lark_doc_grab.ps1 `
  -Url "https://...u1,https://...u2,https://...u3"

# 从文件读（每行一个，# 开头为注释）
powershell -NoProfile -ExecutionPolicy Bypass -File lark_doc_grab.ps1 -UrlFile links.txt

# 不下载图片
powershell -NoProfile -ExecutionPolicy Bypass -File lark_doc_grab.ps1 -Url "..." -NoImages
```

**它做了什么**：
1. `drive +inspect` 取标题 / 类型 / 规范 token
2. 从标题正则提取年月，决定归档到 `会议纪要\YYYY-MM\`
3. `docs +fetch` 取 Markdown 正文
4. 正则扫出 `![](https://*.feishu.cn/file/TOKEN)`，逐个 `docs +media-download` 下载
5. 把 Markdown 里的远程图片链接改写成 `assets/xxx.png`
6. 落盘 + 更新 `index-会议纪要.csv`（同 url 去重）

---

## 四之二、SOP A0：会议纪要 + 逐字稿（主流程）

**触发**：「导出会议纪要」「拉逐字稿」「要原文转写」。

```powershell
scripts\meetings.cmd -Days 7              # 最近 7 天
scripts\meetings.cmd -Days 30 -DryRun     # 预演
scripts\meetings.cmd -StartDate 2026-10-01 -EndDate 2026-10-31
```

**链路**（四步，缺一不可）：

```
vc +search   → 会议列表
vc +detail   → note_id
note +detail → note_doc_token + verbatim_doc_token   ← 关键步骤
docs +fetch  → 读纪要 + 读逐字稿
```

产物：`会议归档\YYYY-MM-DD\会议主题\{纪要.md, 逐字稿.md, assets\}`

完整说明见 **[MEETING.md](./MEETING.md)**。

---

## 五、SOP B：知识库增量同步

```powershell
scripts\wiki.cmd              # 增量（只拉新节点）
scripts\wiki.cmd -Manual      # 批次名带时间戳
scripts\wiki.cmd -Full -Manual  # 全量重拉
```

**定时任务**：`LarkWikiSync-6h`（每 6 小时）。

```powershell
schtasks /Query /TN "LarkWikiSync-6h" /V /FO LIST     # 查看
schtasks /Run   /TN "LarkWikiSync-6h"                 # 立即跑
schtasks /Delete /TN "LarkWikiSync-6h" /F             # 删除
```

⚠️ 注意：知识库是**部门模板库，不含会议纪要**。定时同步它只能拿到 33 个模板文档，
基本不变。会议纪要请走 SOP A0。

无新增时不生成空批次、不生成空 zip。

---

## 六、SOP C：还原到另一台电脑

见 [RESTORE.md](./RESTORE.md)。核心：读 `index.json` 的 `original_path` 字段，
按原层级放回，同名不覆盖而是加后缀。

---

## 七、踩过的坑（务必遵守）

### 1. 中文脚本必须 UTF-8 with BOM
PowerShell 5.1 按 ANSI 解析无 BOM 的 UTF-8，中文字符串会撕裂语法。写完必须：
```powershell
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($true)))
```

### 2. `cmd.exe` 默认 GBK 会撕裂 JSON
`chcp 65001` 后才调 CLI，且 **stdout / stderr 必须分开重定向**：
```
chcp 65001 >nul & lark-cli ... > out.txt 2> err.txt
```
否则中文标题变 `棣栭〉`，半个字节破坏 JSON 结构，解析静默失败（曾导致 `nodes=0`）。

### 3. 定时任务的 `/TR` 不能直接带参数
本机安全策略拦截 `cmd.exe /c ...` 形式的任务命令行。解决办法：
**写一个 `.cmd` 启动器，任务只指向该文件，不带参数**。

### 4. `docs +media-download --output` 有路径白名单
只允许 cwd / temp / `~/files`。必须先落 `$env:TEMP` 再 `Move-Item` 到目标。

### 5. `$arr += $singleObject` 会解包丢属性
用 `New-Object System.Collections.ArrayList` + `.Add()`。

### 6. 路径清洗要逐段做
对整条相对路径 Sanitize 会把 `\` 换成 `_`，层级被拍平。按 `\` 分段后逐段清洗。

### 7. `vc +search` 不认 `me`
必须传真实 open_id：`ou_9efd9de30b4b8b7dee8e180f0757d44f`（李泽宇）。

### 8. `note_id` 不是文档 token
`vc +detail` 的 `note_id` 直接当 token fetch 会报 `Invalid document_id (3380002)`。
必须用 `note +detail --note-id` 转成 `note_doc_token` 和 `verbatim_doc_token`。
**这是拿逐字稿的唯一途径**，详见 MEETING.md。

### 9. `--params` JSON 在 PowerShell 里传参会坏
`lark-cli drive files list --params '{"folder_token":"xxx"}'` 会报
`--params invalid format`。改用：
```
cmd.exe /c 'chcp 65001 >nul & lark-cli drive files list --params "{\"folder_token\":\"xxx\"}"'
```

### 10. token 有效期与续期
access token 2 小时（CLI 自动 refresh），refresh token 7 天。
**每 7 天内至少运行一次**即可滚动续期；连续 7 天不开机需重新 `auth login`。

---

## 八、权限现状（2026-10-24 已全量授权）

已通过 `auth login --domain all` 获得 **216 个 scope**，覆盖：

| 业务域 | 状态 |
|---|---|
| 云文档 / 云盘 | ✅ 含 `space:document:retrieve`、`search:docs:read` |
| 会议 / 妙记 | ✅ 含 `vc:meeting.meetingevent:read`、`vc:record:readonly`、`minutes:minutes.basic:read` |
| 日历 | ✅ 全套（含 `calendar:calendar.event:read/write`）|
| 任务 | ✅ 含 `task:task:write` |
| OKR | ✅ 全套 |
| 邮件 | ✅ 全套（含 `mail:user_mailbox.message:send`）|
| 考勤 | ✅ `attendance:task:readonly` |
| 通讯录 | ✅ 含 `contact:user.basic_profile:readonly` |

**唯一未授予**：`vc:meeting.realtime:read` —— 企业管理员明确禁止（标注「不可申请，勿重试」）。

**资源级限制依然存在**（OAuth scope 无法解决）：
- 妙记录音文件归会议组织者，`minutes +detail` 报 `No read permission`
- 个别文档导出报 `permission_denied(1069902)`，但 `docs +fetch` 通常仍可读
