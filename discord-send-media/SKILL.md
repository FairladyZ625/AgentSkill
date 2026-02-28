---
name: discord-send-media
description: 在 Discord 频道稳定发送附件（文档/图片/音频/视频）。用于 bot 批量实测、日常交付、失败排障与统一回执。
---

# Discord Send Media（标准技能）

## 适用场景
- 需要把本地文件发到 Discord 频道
- 需要批量验证各 bot 的文件发送能力
- 遇到 `Discord bot token missing` 或 `Local media path is not under an allowed directory` 报错

## 标准命令（推荐）
```bash
openclaw message send \
  --channel discord \
  --account <account> \
  --target 1475328660373372940 \
  --message "文件发送测试 - <bot名>" \
  --media /Users/lizeyu/.openclaw/workspace/outbound/<file>
```

## 硬规则（必须）
1. 必须显式带 `--account`（不要依赖 default）。
2. `--target` 用频道 ID，不用频道名。
3. `--media` 路径必须在允许目录（建议统一：`/Users/lizeyu/.openclaw/workspace/outbound/`）。
4. 测试文件不要放 `/tmp`。

## 快速自检
### 1) 看可用账号
```bash
openclaw channels list
```

### 2) 常见报错与处理
- `Discord bot token missing for account "default"`
  - 原因：没带 `--account` 或该账号没 token
  - 处理：改为 `--account <已配置账号>`

- `Local media path is not under an allowed directory`
  - 原因：文件不在允许目录
  - 处理：移动到 `/Users/lizeyu/.openclaw/workspace/outbound/` 后再发

## 推荐测试模板
```bash
mkdir -p /Users/lizeyu/.openclaw/workspace/outbound
printf "file send test - %s - %s\n" "<bot名>" "$(date '+%F %T')" \
  > /Users/lizeyu/.openclaw/workspace/outbound/<bot名>-file-send-test.txt

openclaw message send \
  --channel discord \
  --account <account> \
  --target 1475328660373372940 \
  --message "文件发送测试 - <bot名>" \
  --media /Users/lizeyu/.openclaw/workspace/outbound/<bot名>-file-send-test.txt \
  --json
```

## 回执格式（统一）
`ACK + account + 文件名 + messageId + 结果(成功/失败原因)`


## 账号速查（本环境常用）
- `main`
- `codex`
- `gpt52`
- `glm47`
- `glm5`
- `sonnet`
- `opus`
- `haiku`
- `gemini31pro`
- `gemini3flash`

以 `openclaw channels list` 实际输出为准。

## 回执质量检查
- `messageId` 应为 Discord 雪花 ID（通常 18-20 位数字）
- 建议带 `--json` 并从返回中复制 `messageId`
- 若 messageId 明显异常（位数不对），以 CLI JSON 回包为准重新校对
