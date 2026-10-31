# deli-lark — 得力飞书同步 skill

飞书内容抓取（检索/会议纪要/逐字稿/知识库/打包）全链路 skill。**拉取脚本仅 Windows 权限机可跑**（PowerShell + lark-cli）；两台 Mac 为消费端（入库/检索），详见 SKILL.md「部署拓扑」。

## 同步方式

- 三台机器（Windows / MacBook / mac-studio）统一从本 GitHub 私仓拉取
- Windows 机更新脚本或文档后 push；Mac 侧 pull 即可
- 远端：github.com/FairladyZ625/deli-lark-skill（private）

## 文档结构

- SKILL.md — 入口：部署拓扑、何时用、SOP 总览
- SOP.md — 完整流程与踩坑记录
- MEETING.md — 会议纪要+逐字稿抓取专项（note_id→token 链路）
- SEARCH.md — 检索专项（docs +search / im +messages-search 的坑）
- RESTORE.md — 资料包还原说明（给消费端 Mac）
- scripts/ — PowerShell 脚本 + .cmd 包装器（Windows 专用）
