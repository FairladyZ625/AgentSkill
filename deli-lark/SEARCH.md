# SEARCH.md — 检索能力专项说明

本文件讲 `deli-lark` 的检索能力：如何在飞书里找到文档和群聊链接。

---

## 一、三种检索来源

飞书的内容分散在三个不同的地方，各有各的 API，**不能互相替代**：

| 来源 | 命令 | 覆盖范围 | 局限 |
|---|---|---|---|
| **云文档 + 知识库** | `docs +search` | 标题匹配的 docx/sheet/base/slides/file/mindnote/shortcut | 只搜**标题**，不搜正文 |
| **群聊消息** | `im +messages-search` | 消息正文、群名、发送人、时间 | 只能搜**你所在**的群 |
| **云盘目录** | `drive files list` | 按文件夹层级遍历 | 需要知道 folder_token |

这就是为什么「群聊里发的链接」必须走 `im +messages-search` 单独抓。

---

## 二、`docs +search` 的正确用法

### 坑 1：`--query` 必须是具体词

```powershell
lark-cli docs +search --query "智能纪要"     # → 0 条  ✗
lark-cli docs +search --query "架构"          # → 8 条  ✓
lark-cli docs +search --query "接口"          # → 6 条  ✓
```

传长词组或编号会搜不到。**用 2-4 个字的实词效果最好**。

### 坑 2：标题在 `title_highlighted`，不在 `result_meta`

```jsonc
{
  "entity_type": "WIKI",
  "result_meta": {
    "doc_types": "DOCX",
    "token": "KxsVwP6Y2iwsMYk7464czINRnzf",
    "url": "https://nbdeli.feishu.cn/wiki/...",
    "owner_name": "彭耀",
    "update_time_iso": "2026-10-23T16:53:45+08:00"
    // 注意：这里没有 title 字段
  },
  "title_highlighted": "AI产品开发工作流工作组",   // ← 标题在这
  "summary_highlighted": ""
}
```

标题里的匹配词被 `<h>...</h>` 包裹，需要剥掉：

```powershell
$title = ($r.title_highlighted -replace '</?h>','')
```

### 坑 3：不加 `--query` 会返回全部但翻页失效

不传 query 能列出全部可见文档（实测 20 条真实 + 大量重复），
但 `page_token` 无效，会陷入死循环。**必须带 query**。

### 坑 4：`--page-all` 会失败

`docs +search --page-all` 报错。需要翻页时手动循环传 `--page-token`，
但如上所述 token 不可靠。**实际使用中单页 20 条基本够用**。

---

## 三、`im +messages-search` 的正确用法

### 基础

```powershell
lark-cli im +messages-search --query "feishu.cn/docx" --page-size 20
lark-cli im +messages-search --query "架构" --start "2026-09-01T00:00:00+08:00" --end "2026-10-24T23:59:59+08:00"
```

### 返回结构（关键字段）

```jsonc
{
  "ok": true,
  "data": {
    "has_more": true,
    "messages": [           // ← 注意是 messages，不是 items
      {
        "message_id": "om_x100b62...",
        "chat_id": "oc_0f75966ccb5f80d77efc9a639ea30ae6",
        "chat_name": "小得 AI 工作大群",        // 群名（p2p 时没有）
        "chat_type": "group",                   // group | p2p
        "content": "https://nbdeli.feishu.cn/docx/HaoYd1YmjolTajxZ601cwWRXnng",
        "create_time": "2026-10-20 21:39",
        "msg_type": "text",
        "sender": {
          "name": "闫俊",
          "sender_type": "user"                 // user | app
        },
        "deleted": false
      }
    ],
    "page_token": "...",
    "total": 10
  }
}
```

### 提取链接

消息正文里的链接可能是纯文本，也可能包在 HTML 里：

```
纯文本: https://nbdeli.feishu.cn/docx/HaoYd1YmjolTajxZ601cwWRXnng
HTML  : <p>https://nbdeli.feishu.cn/docx/YwK8dx2r3o2YQLx3I4Fci1krnyQ?from=auth_notice&hash=...</p>
```

用正则统一抽取：

```powershell
$links = [regex]::Matches($content, 'https?://[^\s"''<>]+') | ForEach-Object { $_.Value }
$feishu = $links | Where-Object { $_ -match 'feishu\.cn|feishu\.com|larksuite\.com' }
```

### 搜链接的技巧

| 想找 | query |
|---|---|
| 所有飞书文档链接 | `feishu.cn/docx` |
| 表格链接 | `feishu.cn/sheets` |
| 多维表格 | `feishu.cn/base` |
| 知识库页面 | `feishu.cn/wiki` |
| 特定主题 | 业务关键词，如「架构」「接口」 |

---

## 四、`deli_search.ps1` 做了什么

把上述两源合并、去重、结构化输出。

```powershell
scripts\search.cmd -Query "前端,后端,架构,接口,API"
```

流程：

1. **组装查询词**：`-Query`/`-Queries`/`-Keywords` 都可，逗号分隔多个
2. **搜云文档**：对每个词调 `docs +search`，剥掉 `<h>` 标签
3. **搜群聊**：对每个词调 `im +messages-search`，正则提取链接
4. **去重**：docs 按 `token`，消息按 `url`（无 url 时按 群+时间+内容摘要）
5. **输出**：分两块打印 + 落盘 CSV/JSON

### 参数

| 参数 | 说明 | 默认 |
|---|---|---|
| `-Query` | 单个或多个关键词（逗号分隔） | 必填 |
| `-Source` | `all` / `docs` / `messages` / `links` | `all` |
| `-Days` | 群聊消息回溯天数 | 90 |
| `-Limit` | 每个关键词的返回上限 | 20 |
| `-ShowUrl` | 打印完整 URL | 关 |
| `-Json` | 只输出 JSON | 关 |
| `-OutDir` | 结果落盘目录 | `_search\` |

### 输出示例

```
================ 检索结果（去重后 40 条）================

### 云文档 / 知识库（31 条）
 1. [DOCX    ] 前端技术方案
    来源=DOC  所有者=云文档助手  更新=2024-03-13T14:19:17+08:00
11. [FILE    ] 小得智能体开发平台-详细架构设计方案.pdf
    来源=DOC  所有者=徐超国  更新=2026-10-14T18:46:06+08:00

### 群聊链接 / 消息（9 条）
 1. [B-AI开发工作流工作组] 彭耀
    @徐乾龙 @李泽宇 前后端接入得力e+的文档你们看看吧
    时间=2026-10-23 09:18
```

---

## 五、检索到之后怎么办

搜到文档不等于拿到内容。拿到 `token` 或 `url` 后：

```powershell
# 用链接抓取（最直接）
scripts\grab.cmd -Url "https://nbdeli.feishu.cn/docx/XXXX"

# 或多个一起
scripts\grab.cmd -Url "url1,url2,url3"
```

**注意**：`docs +search` 返回的 `result_meta.token` 对 WIKI 类型的实体，
可能是 node_token 而非文档 token。这种情况直接用 `result_meta.url` 走 `grab.cmd` 更稳
（`grab.cmd` 内部会用 `drive +inspect` 自动解析 wiki）。

---

## 六、排查表

| 现象 | 原因 | 处理 |
|---|---|---|
| `docs +search` 某词 0 条 | 词太长或太宽泛 | 换 2-4 字实词 |
| 标题全是空 | 读错了字段 | 用 `title_highlighted` |
| 结果大量重复 | 翻页 token 失效 | 只取第一页 |
| 群聊搜不到 | 不在该群 / 超出 `-Days` | 检查群成员关系或加大天数 |
| 群聊只回 1 条但实际很多 | 分页未取 | 脚本已处理单页，可加 `--page-token` 循环 |
| `messages` 字段读成 `items` | 字段名错误 | 是 `data.messages` |
