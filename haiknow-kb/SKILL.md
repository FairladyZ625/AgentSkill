---
name: haiknow-kb
description: 操作 HAiKnow 团队飞书知识库与 OKR 总控台：按十进制分类放资料、更新类目索引、拆解 KR 为里程碑和任务、填写进展。往 HAiKnow 知识库加文档或链接、整理目录、更新 OKR、拆任务、写进展、看 OKR 看板时使用。
---

# HAiKnow 知识库与 OKR

租户 `bcnncgqa2y6v.feishu.cn`，知识空间 ID `7704645063699106840`。命令行用 `lark-cli`（用户身份）。

| 入口 | 链接 |
|---|---|
| 知识库首页 | https://bcnncgqa2y6v.feishu.cn/wiki/UjOEwIHhpidugZkTsUocHkxTn9d |
| OKR 总控台 | https://bcnncgqa2y6v.feishu.cn/wiki/FX5WwOwXIi7DRTkpDCMc473qnUc（base token `IqfGblVTya0V5RsPG4Fc5jMcnuf`） |

团队规范：https://bcnncgqa2y6v.feishu.cn/wiki/VDAzwvGN2iz0nSkDbPwc9YJ9ncc

Skill 在线正文：https://bcnncgqa2y6v.feishu.cn/wiki/Jea4wa30siOSVDkiOdFcft7Sndb

## 一、知识库

### 分类

| 领域 | 类目（节点 token） |
|---|---|
| 10 基础资料 | 11 新人入门 `DZ4cwCWZ8iw3eDk2fZHcPDtKnpf` · 12 模板与规范 `DMDWwpR5XijlpMkLEHOciYsDnw1` · 13 行业与市场调研 `VR7PwDwZeif29NkBhQMcSo1xnUa` · 14 术语与常见问题 `ACr8woAlZik6lTkhk0pcECoGnng` |
| 20 公司 | 21 公司与团队介绍 `JlCZwLUQxiMK3EkTeiKc1BEznWf` · 22 宣传素材 `C23Ww8zSmis9OikcIiqcP2eOnwc` · 23 运营与协作 `RQYEwr4jxiIHlbkj5Qicro8uneE` · 24 政策与资质 `LQzzwXNiki2suBkmqDncL41GnHb` |
| 30 产品 | 31 Studio `UbH6wswD1iTJKJkVeAYckv9snoe` · 32 解决方案 `CXjhw5e3IiO1PGknknecHMZTn6d` · 33 演示与原型 `DoymwAjD0iq4NmkmVxxcocIHnje` · 34 用户反馈 `WrFYwt7n0iTGo4kkesDcXaJGnNg` |
| 40 技术 | 41 HA 部署与上手 `SotFwXgXsiZlPEkdxFdcvZ1Pn9t` · 42 架构与接口 `BN8bwLgLFiu6k7k0CeLcFcsln8c` · 43 技术调研 `JWmhwVnNqi3pfKkK7ugchRzFnjb` |
| 50 项目 | 51 卫华黑客松 `Wk3Pw7boMiwPilkg8TWcFZpWnnf` · 52 斯普信 · 中国移动 `GdrHw01KMijP29k3MKWcwFXWnJh` · 53 童同 `QMXcwVBBqi3gTGkRAPhck5G7nPe` · 54 经开 `OqAGwuh6OilebFklLhtc0Wj4ncb` · 55 比赛与活动 `ED8vwSrQAiXf1XkEOA7cSWYvnte` · 56 niubila `TWBxwKySvijf7Ck2OPacsqpunDf` |
| 60 会议纪要 | 61 例会 `HVbYwgtlEivgcckhmrOcmtVBnLf` · 62 专题会 `N4LYwHW9ais3dvkgvCpceLQ4nfc` |
| 90 归档 | `Rj5Pwbv6Xi06OMkj8SicdFUonNh` |

### 放到哪

| 资料 | 放到 |
|---|---|
| 只属于一个客户或活动 | 50 项目对应类目 |
| 跨项目复用的方案、演示 | 30 产品 |
| 部署、架构、技术调研 | 40 技术 |
| 公司介绍、宣传、运营看板 | 20 公司 |
| 入门、模板、行业资料 | 10 基础资料 |
| 会议记录 | 60 会议纪要 |
| 过期、被新版替代 | 90 归档 |

一份资料只放一处；别处需要时在索引里放链接。新开类目在领域内顺延编号，并同步更新领域索引页和首页。

### 写什么

- 以引用为主：原文件留在原处，类目索引放链接，加一句它是什么。
- 自己产出的材料才整篇入库，写给全体成员：标题、一段概述、表格优先。
- 不写：个人事务（合作条件、股权、注册、社保、个人授权）；代码分支、PR、提交号、Agent 台账任务 ID 这类过程细节；「事实 / 推断 / 待确认」标签；写给某个人的话；解释这页怎么读的句子。
- 文档标题：`类目.序号 标题`，例如 `51.03 现场演示脚本`；更新以飞书版本记录为准，标题不带日期后缀和「初版」「内部」字样。
- 群里的文件先存进对应类目，再在索引里放链接。

### 命令

```bash
# 在类目下新建文档
lark-cli wiki +node-create --space-id 7704645063699106840 --parent-node-token <类目token> --title "51.03 现场演示脚本" --obj-type docx
# 写入正文（markdown 文件须在当前目录下）
lark-cli docs +update --doc <obj_token> --command overwrite --doc-format markdown --content @body.md
# 上传文件到类目
lark-cli drive +upload --file ./a.pdf --wiki-token <类目token> --name "卫华调研报告.pdf"
# 移动已有节点
lark-cli wiki +move --node-token <node> --target-parent-token <类目token>
# 列出类目内容
lark-cli wiki +node-list --space-id 7704645063699106840 --parent-node-token <类目token>
```

类目索引页是一张表：`| 资料 | 类型 | 来源 | 所有者 | 更新 |`。加了资料就在对应类目索引补一行，领域索引的条数同步改。

## 二、OKR 总控台

### 层级

| 表 | 内容 | 谁维护 |
|---|---|---|
| ① 目标 O | 每条线一个目标 | 周安嵩 |
| ② 关键结果 KR | 目标拆成可验收的结果，带负责人、协作人、截止 | 目标负责人 |
| ③ 里程碑 | KR 的阶段节点：日期 + 验收标准 | KR 负责人 |
| ④ 任务 | 里程碑拆成的具体活，一件活一个负责人，带截止、进度 % | KR 负责人拆，任务负责人更新 |
| ⑤ 进展记录 | 每次推进记一条：本次完成、进度 %、下一步、阻塞、产出链接 | 任务负责人（从任务关联记录填写，或用「填写进展」表单） |
| ⑥ 待决问题 | 需要拍板的事，带提请人 | 提出人 |
| ⑦ 会议 | 会议、召集人、结论、纪要链接 | 召集人 |

表之间双向关联：O → KR → 里程碑 → 任务 → 进展记录。人员字段一律选飞书成员，外部人员写在「其他协作方」。

### 拆解与更新

- 各线负责人拆自己负责的 KR；Agent 搭入口、核对关联，不替负责人编造具体执行分工或完成情况。
- 里程碑填写所属 KR、负责人、日期、验收标准。任务填写唯一编号、唯一负责人、截止、验收标准、所属里程碑；任务的所属 KR 必须与里程碑一致。
- 已建「拆解自己负责的 KR」任务分别分配给周安嵩、吴宛真、吴圣洁、李泽宇。交付后由任务负责人更新进度，不把“分配成功”当作“已完成”。
- 任务负责人每次更新：追加⑤进展记录，填写任务、本次完成、日期、填写人、0–100 的进度、下一步、阻塞、产出链接；表单会自动更新④任务的当前进度、状态、完成情况与阻塞。历史进展保留，不覆盖。
- 普通表格可直接选关联「任务」。飞书表单不支持 link 字段：表单必填「任务编号」（如 T1），由「填报进展并同步任务」工作流精确匹配④编号，再补关联并更新当前任务。任务编号必须唯一，不能把人名或任务描述填进编号。
- 表单无需匿名共享；从总控台的⑤「填写进展」打开。未匹配或尚未自动关联的进展，Agent/PM 核对编号后补关联；不因此重复提交或修改他人的进展。
- 表单新增进展会自动更新任务，修改历史进展不会再次触发回写；表内仍可直接修改任务状态与进度。填报须反映当前情况，历史补录先注明，避免覆盖当前进度。
- 点击各行的「建立 KR / 建立里程碑 / 建立任务 / 填写进展」打开表单，会自动预填对应上级编号；不用抄编号。
- 新增 O、KR、里程碑、任务自动编号；旧编号保留。直接表内新增时可选关联上级，任务的所属 KR 需要与里程碑一致。
- 轻量状态机只用 未开始 / 进行中 / 受阻 / 已完成。直接选择状态、拖动状态看板，或点「完成任务」均操作真实记录；完成自动 100% 并记完成时间，重置未开始自动 0%，恢复进行中/受阻保留本人填的进度并清除完成时间。上级 KR/O 的验收由负责人维护，不增加审批层级。
- 进展表单选择「已完成」时隐藏百分比并自动按100%回写；选择「受阻」时必须填阻塞。表单和输入表仍共用原来的7张表，没有另建网站或 BaseApp。

### 输入与操作入口

| 操作 | 独立表单入口 |
|---|---|
| 建立目标 | https://bcnncgqa2y6v.feishu.cn/share/base/shrcnGKEZuLBQWKETH83rZ2TJIN |
| 建立 KR | https://bcnncgqa2y6v.feishu.cn/share/base/shrcnl7sukTC9VcGsDFamTxf9nb |
| 建立里程碑 | https://bcnncgqa2y6v.feishu.cn/share/base/shrcnfECheR1drjF8fbwOuaBvAg |
| 建立任务 | https://bcnncgqa2y6v.feishu.cn/share/base/shrcnU3yZOQKtzNzU9wnd7LNQw5 |

优先从对应上级记录的操作链接进入，表单自动带上归属。侧栏「系统配置」收纳工作流，成员日常在任务表、看板和表单操作。

### 表与视图定位

| 表 | ID | 常用入口 |
|---|---|---|
| ① 目标 O | tbl9CIKoF1a5FBmp | 按线 |
| ② 关键结果 KR | tbl4wvwWkMTU3cWE | 按负责人 / 按目标 |
| ③ 里程碑 | tblHzSEuLh98ayCV | 按日期 / 里程碑看板 |
| ④ 任务 | tblzBsIaxJGdYcBG | 按负责人 / 状态看板 |
| ⑤ 进展记录 | tbl91u8WKb9e4Jph | 按任务 / 按填写人 / 填写进展 |
| ⑥ 待决问题 | tbldlD9E69lnWYV5 | 表格 |
| ⑦ 会议 | tblfzD3Q4KxWbcZk | 表格 |

上述是 2026-11-05 核验坐标；写入前读取真实字段与当前记录。上次超时或中断后先回读，不能只凭本地缓存的成功标记重试创建。

### 节奏

| 时点 | 动作 | 谁 |
|---|---|---|
| KR 分到手当天 | 把 KR 拆成里程碑和任务，每个任务指定负责人和截止 | KR 负责人 |
| 每天下班前 | 在⑤填一条当前进展，自动同步④的进度 % 和状态 | 每个任务负责人 |
| 每周一 | 看「OKR 看板」，延期和受阻的里程碑在周会上过 | 周安嵩召集 |
| 月底 | 每条 KR 计划对实际，写进⑦对账会结论 | 吴圣洁整理 |

状态：O、KR、里程碑、任务均用 未开始 / 进行中 / 受阻 / 已完成；待决问题用 待定 / 已定。延期通过截止日期和未完成状态查看，不另加审批状态。

### 命令

```bash
B=IqfGblVTya0V5RsPG4Fc5jMcnuf
lark-cli base +table-list --base-token $B
# 新建任务（挂到里程碑和 KR）
lark-cli base +record-batch-create --base-token $B --table-id "④ 任务" --json '{"create_records":[{"任务":"写演示脚本第一版","验收标准":"脚本含开场、完整业务链、收尾与备用方案","负责人":[{"id":"ou_xxx"}],"截止":"2026-11-07 18:00","状态":"未开始","进度 %":0,"所属里程碑":[{"id":"rec_xxx"}],"所属 KR":[{"id":"rec_xxx"}]}]}'
# 记一条进展
lark-cli base +record-batch-create --base-token $B --table-id "⑤ 进展记录" --json '{"create_records":[{"任务编号":"实际任务编号","任务状态":"进行中","本次完成":"脚本前三幕写完","日期":"2026-11-06 18:00","填写人":[{"id":"ou_xxx"}],"进度 %":60,"任务":[{"id":"rec_xxx"}]}]}'
# 改状态 / 进度
lark-cli base +record-batch-update --base-token $B --table-id "④ 任务" --json '{"update_records":{"rec_xxx":{"状态":"进行中","进度 %":60}}}'
# 查人员 open_id
lark-cli contact +search-user --queries "吴圣洁"
```

`base +form-submit` 的日期必须用 `yyyy-MM-dd HH:mm:ss`（包含秒）；它与普通 record 写入接受的日期格式不同。

### 回读与边界

写完回读记录及关联；先查任务编号唯一，再创建进展。关联失败时先修编号/层级，不另建一套表。看板计数来自实际记录，0 条进展就显示 0，不填示例冒充成员进度。

单选字段只填已有选项。确需调整时先读字段、保留正在使用的选项，确认属于本次授权范围再 `base +field-update --yes`。用户个人事务不进公共区的记录、枚举选项、备注与文档。该 skill 不授权外发消息、建群或改成员权限。
