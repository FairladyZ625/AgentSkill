# MEETING.md — 会议纪要与逐字稿抓取专项说明

本文件专门讲「会议纪要 + 原文转写」这条链路，是本项目最核心的能力。

---

## 一、为什么不能直接用 `vc +detail` 的 note_id

`vc +detail` 返回的 `note_id` 长这样：

```json
{
  "meeting_id": "7699769447715736580",
  "topic": "技术栈对齐",
  "note_id": "7699777047895608255",
  "hint": "no minute file for this meeting"
}
```

直觉上会以为 `note_id` 就是文档 token，于是去 fetch：

```powershell
lark-cli docs +fetch --doc 7699777047895608255
```

**结果必然失败**：

```json
{
  "code": 3380002,
  "message": "Invalid document_id or document not found"
}
```

`note_id` 是**会议笔记的内部 ID**，不是云文档 token。这是个已经踩过的坑。

---

## 二、正确链路

```
第 1 步  vc +search --participant-ids <open_id> --start ... --end ...
          → 得到会议列表，每条有 id 和 display_info

第 2 步  vc +detail --meeting-ids <id1,id2,...>
          → 每场得到 note_id（可能为空）、minute_token、hint

第 3 步  note +detail --note-id <note_id>
          → 关键！转出两个文档 token：
             note_doc_token      = 智能纪要文档
             verbatim_doc_token  = 文字记录（逐字稿/原文转写）

第 4 步  docs +fetch --doc <token> --doc-format markdown
          → 读全文（纪要和逐字稿各 fetch 一次）
```

### 第 3 步的实际返回

```json
{
  "ok": true,
  "data": {
    "note": {
      "note_id": "7699777047895608255",
      "note_display_type": "normal",
      "note_doc_token": "RQcAdJ4PjoCixuxkMIJcmUUZnEf",
      "verbatim_doc_token": "LlrJdeJONoGm7oxh31lcNI7Mn7c",
      "create_time": "2026-10-23 16:29",
      "creator_id": "ou_95bdd93e73939a1bb6f32a96bf69d396"
    }
  }
}
```

注意 `verbatim_doc_token` —— **这就是逐字稿的入口**，
之前误判「拿不到逐字稿」就是因为没找到这一步。

---

## 三、`hint` 字段的含义

`vc +detail` 里的 `hint` 能直接告诉你这场会议有什么：

| hint | 含义 | 能否抓 |
|---|---|---|
| `no minute file for this meeting` | 无录音，但有纪要文档 | ✅ 纪要+逐字稿都能抓 |
| `note_id not found for this meeting` | **没有生成纪要** | ❌ 两个都没有 |
| 无 hint | 正常 | ✅ |

**重要**：很多时候没有 `minute file`（无录音）**不代表没有逐字稿**。
实测「技术栈对齐」提示 `no minute file`，但 `verbatim_doc_token` 正常返回，
抓到了 39 KB、168 个时间戳的完整逐字稿。

所以：**不要因为 hint 说没有 minute file 就跳过**，只要 `note_id` 存在就继续走第 3 步。

---

## 四、逐字稿的实际质量

以「技术栈对齐 2026-10-23」为例：

```
# 文字记录：技术栈对齐 2026年10月23日

> 会议主题：技术栈对齐
> 会议时间：2026年10月23日（周五） 15:58 - 16:28 （GMT+08）
> 智能纪要：[技术栈对齐 2026年10月23日](https://nbdeli.feishu.cn/docx/RQcAdJ4PjoCixuxkMIJcmUUZnEf)

说话人 1 用 王义 的设备 00:03:56
几个孔？然后我们现在把这个设备是已经激活，已经绑定，我们就搞一个新设备…

说话人 1 用 王义 的设备 00:04:30
OK， 现在已经绑定成功了。然后我们的服务端这边就是咱们开发的…
```

特征：
- **带说话人编号**（说话人 1/2/3/4）
- **带人名归属**（`用 王义 的设备`）——来自飞书声纹识别
- **带时间戳**（`00:03:56`），可定位回放
- 纯文本，无误识别乱码

实测 5 场会议的逐字稿大小：39 KB / 53 KB / 57 KB / 109 KB / 132 KB。
体量与会议时长正相关。

---

## 五、脚本用法

```powershell
# 最近 7 天
scripts\meetings.cmd -Days 7

# 指定日期范围
scripts\meetings.cmd -StartDate 2026-10-01 -EndDate 2026-10-31

# 预演：只列出会抓什么，不下载
scripts\meetings.cmd -Days 30 -DryRun

# 不要逐字稿，只抓纪要
scripts\meetings.cmd -Days 7 -WithVerbatim:$false

# 不下载图片
scripts\meetings.cmd -Days 7 -NoImages
```

### 产物结构

```
会议归档\
├── 2026-10-23\技术栈对齐\
│   ├── 纪要.md              # 智能纪要
│   ├── 逐字稿.md            # 原文转写
│   └── assets\
│       ├── 技术栈对齐-1.png
│       ├── 技术栈对齐-2.png
│       └── 技术栈对齐-3.png
├── 2026-10-23\得力办公技术架构沟通\
├── .meeting-state.json      # 已抓 meeting_id（增量基准）
└── _logs\meeting-*.log
```

图片链接在 md 中已改写为 `assets/xxx.png` 相对路径，本地可直接显示。

### 增量机制

`.meeting-state.json` 记录每个已抓会议的：

```json
{
  "7699769447715736580": {
    "topic": "技术栈对齐",
    "date": "2026-10-23",
    "note_id": "7699777047895608255",
    "grabbed_at": "2026-10-24T10:51:02",
    "files": "纪要.md,逐字稿.md"
  }
}
```

重复运行只处理新会议，已抓的 SKIP。

**注意**：如果会议纪要**后来更新了**（比如会后补写），
因为 meeting_id 已记录，增量模式不会重抓。需要重抓时删掉 state 里对应条目，
或用 `-StartDate/-EndDate` 缩小范围配合手动删除目标目录。

---

## 六、仍然拿不到的：妙记录音

`minutes +detail --transcript` 会报：

```
No read permission for minute obcnr8yo...
```

这是**资源级权限**，录音文件归会议组织者所有（尤其是外部会议）。
OAuth scope 再全也没用。

但**不影响使用** —— 逐字稿已经通过 `verbatim_doc_token` 拿到了，
录音只是在需要回放原声时才有价值。

如需尝试申请：`lark-cli minutes +apply-permission --minute-token <token> --perm view`

---

## 七、快速排查

| 现象 | 原因 | 处理 |
|---|---|---|
| `Invalid document_id` | 把 note_id 当 token 用了 | 先走 `note +detail` |
| `note_id not found` | 会议没生成纪要 | 无解，跳过 |
| 会议列表为空 | open_id 传错或用了 `me` | 用 `ou_9efd9de30b4b8b7dee8e180f0757d44f` |
| 逐字稿为空文件 | 会议无有效语音内容 | 检查原文 |
| 图片 404 | media token 失效或权限不足 | 单张重试 |
