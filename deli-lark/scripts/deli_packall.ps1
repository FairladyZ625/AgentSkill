param(
    [string]$BaseDir = "C:\Users\Administrator\Documents\人工智能研究中心",
    [string]$PackRoot = "C:\Users\Administrator\Documents\人工智能研究中心\_packs",
    [string]$Label = "得力飞书资料包",
    [string]$SkillDir = "C:\Users\Administrator\Documents\deepseek-harness\default-workspace\skills\deli-lark",
    [switch]$NoZip
)

$ErrorActionPreference = 'Continue'

# ============================================================
# 总包：技术文档 + 会议纪要/逐字稿 + 知识库增量 + skill 本体
# ============================================================

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$packDir = Join-Path $PackRoot "$Label-$stamp"
New-Item -ItemType Directory -Force -Path $packDir | Out-Null

Write-Output "STAMP=$stamp"
Write-Output "PACKDIR=$packDir"

$manifest = New-Object System.Collections.ArrayList
function Add-Section($src, $dstName, $desc) {
    if (-not (Test-Path $src)) { Write-Output "  SKIP (不存在): $dstName"; return }
    $dst = Join-Path $packDir $dstName
    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    $files = @(Get-ChildItem $dst -Recurse -File)
    $mb = [math]::Round((($files | Measure-Object Length -Sum).Sum)/1MB, 2)
    Write-Output ("  ADD {0,-16} {1,3} 文件 {2,7} MB  ({3})" -f $dstName, $files.Count, $mb, $desc)
    $null = $manifest.Add([pscustomobject]@{ section=$dstName; desc=$desc; files=$files.Count; mb=$mb })
}

Write-Output "=== 1) 技术文档 ==="
Add-Section (Join-Path $BaseDir "技术文档") "技术文档" "前后端/架构/接口/接入/规范"

Write-Output "=== 2) 会议纪要 + 逐字稿 ==="
$mtgSrc = Join-Path $BaseDir "会议归档"
if (Test-Path $mtgSrc) {
    $tmp = Join-Path $env:TEMP ("mtgcopy-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    # 排除 _logs 和 state
    Get-ChildItem $mtgSrc -Directory | Where-Object { $_.Name -notlike '_*' } | ForEach-Object {
        Copy-Item $_.FullName -Destination (Join-Path $tmp $_.Name) -Recurse -Force
    }
    Add-Section $tmp "会议纪要" "每场会议的纪要.md + 逐字稿.md + 图片"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "=== 3) 知识库增量 ==="
$incSrc = Join-Path $BaseDir "增量"
if (Test-Path $incSrc) {
    $tmp2 = Join-Path $env:TEMP ("inccopy-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp2 | Out-Null
    # 只带当天目录，不带旧 zip
    Get-ChildItem $incSrc -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } | ForEach-Object {
        Copy-Item $_.FullName -Destination (Join-Path $tmp2 $_.Name) -Recurse -Force
    }
    Add-Section $tmp2 "知识库增量" "飞书知识库文档（按日期批次）"
    Remove-Item $tmp2 -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "=== 4) skill 本体 ==="
Add-Section $SkillDir "deli-lark-skill" "skill 文档 + 全部脚本"

# ---------- 顶层 README ----------
$readme = @'
# 得力飞书资料包

本包含四部分：**技术文档**、**会议纪要**、**知识库增量**、**deli-lark skill 本体**。

## 目录

```
技术文档\            28 篇前后端/架构/接口/接入文档（.md / .pdf / .xlsx / .pptx）
会议纪要\            每场会议一个文件夹：纪要.md + 逐字稿.md + assets\
知识库增量\          飞书知识库文档，按 YYYY-MM-DD 批次
deli-lark-skill\     skill 文档（SKILL/SOP/MEETING/SEARCH/RESTORE）+ scripts\
MANIFEST.csv         各部分文件数与大小
```

## 技术文档分类

| 分类 | 内容 |
|---|---|
| `前端` | 前端技术方案 |
| `架构` | 小得智能体开发平台架构、得力AgentHub架构、快速接入方案、系统/组织架构图 |
| `接口` | API 参考/Guide、AI中台API文档、SDK 文档/Guide、Joyinside、SRM 接口 |
| `接入` | FDE 前端接入得力e+、Iot 平台接入、JoyInside 接入、产品接入说明、开发流程 |
| `规范` | 技术评审、测试方案 |

## 会议纪要说明

每场会议一个文件夹，命名 `YYYY-MM-DD\会议主题\`：

- `纪要.md` —— AI 智能纪要（总结 + 待办 + 相关链接）
- `逐字稿.md` —— **原文转写**，带说话人编号、人名归属、时间戳
- `assets\` —— 会议配图，md 内已改为相对路径

## 格式提醒（重要）

| 原始类型 | 落盘格式 | 说明 |
|---|---|---|
| 飞书文档 docx | `.md` | Markdown，**不是原生 .docx**；文字/表格/链接完整，图片已本地化 |
| 上传的附件 file | 原样 | `.pdf` / `.md` 等保持原始格式 |
| 电子表格 sheet | `.xlsx` | 原生导出 |
| 多维表格 base | `.xlsx` | 只有数据，无视图/表单逻辑 |

`.md` 如需 Word 格式，用 pandoc 转换，但会损失部分版式。

## skill 怎么用

`deli-lark-skill\` 是完整的 skill，对方电脑放进 skills 目录后可直接调用（需装
`@larksuite/cli` 并有飞书授权）：

```powershell
deli-lark-skill\scripts\search.cmd -Query "架构"          # 检索
deli-lark-skill\scripts\meetings.cmd -Days 7              # 会议纪要+逐字稿
deli-lark-skill\scripts\wiki.cmd                          # 知识库增量
deli-lark-skill\scripts\techdocs.cmd                      # 技术文档
deli-lark-skill\scripts\grab.cmd -Url "链接"              # 按链接抓
```

先读 `deli-lark-skill\SKILL.md`，再看 `SEARCH.md` / `MEETING.md` / `SOP.md` / `RESTORE.md`。

## 校验

`MANIFEST.csv` 记录了各部分文件数和大小，可用来核对解压完整性。
'@
Set-Content -Path (Join-Path $packDir 'README.md') -Value $readme -Encoding UTF8

# ---------- MANIFEST ----------
@($manifest) | Export-Csv -Path (Join-Path $packDir 'MANIFEST.csv') -NoTypeInformation -Encoding UTF8

$totalFiles = (Get-ChildItem $packDir -Recurse -File).Count
$totalMb = [math]::Round(((Get-ChildItem $packDir -Recurse -File | Measure-Object Length -Sum).Sum)/1MB, 2)
Write-Output ""
Write-Output "=== 总计 $totalFiles 文件 / $totalMb MB ==="

# ---------- zip ----------
if (-not $NoZip) {
    $zipPath = Join-Path $PackRoot "$Label-$stamp.zip"
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Write-Output "压缩中..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Compress-Archive -Path (Join-Path $packDir '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
    $sw.Stop()
    $zmb = [math]::Round((Get-Item $zipPath).Length/1MB, 2)
    Write-Output "耗时 $([math]::Round($sw.Elapsed.TotalSeconds,0)) 秒"
    Write-Output "ZIP=$zipPath ($zmb MB)"
}

# 清单追加
# 注意：历史 packs.csv 是旧结构（stamp,pack_dir,zip_path,zip_mb,files_ok,files_fail,created_at），
# 列不一致会让 Export-Csv -Append 报错。这里用统一结构重建，保留旧记录的关键字段。
$packsCsv = Join-Path $PackRoot 'packs.csv'
$zipMb = 0
if (-not $NoZip) {
    $zp = Join-Path $PackRoot "$Label-$stamp.zip"
    if (Test-Path $zp) { $zipMb = [math]::Round((Get-Item $zp).Length/1MB, 2) }
}

$rows = New-Object System.Collections.ArrayList
if (Test-Path $packsCsv) {
    try {
        foreach ($old in (Import-Csv $packsCsv)) {
            $null = $rows.Add([pscustomobject]@{
                stamp      = $old.stamp
                label      = if ($old.PSObject.Properties.Name -contains 'label') { $old.label } else { '飞书文档导出包' }
                pack_dir   = $old.pack_dir
                zip_path   = if ($old.PSObject.Properties.Name -contains 'zip_path') { $old.zip_path } else { '' }
                zip_mb     = if ($old.PSObject.Properties.Name -contains 'zip_mb') { $old.zip_mb } else { 0 }
                files      = if ($old.PSObject.Properties.Name -contains 'files') { $old.files }
                             elseif ($old.PSObject.Properties.Name -contains 'files_ok') { $old.files_ok } else { 0 }
                mb         = if ($old.PSObject.Properties.Name -contains 'mb') { $old.mb } else { 0 }
                created_at = $old.created_at
            })
        }
    } catch { Write-Output "WARN 读取旧 packs.csv 失败，将重建" }
}
$zipPathForRec = if ($NoZip) { '' } else { Join-Path $PackRoot "$Label-$stamp.zip" }
$null = $rows.Add([pscustomobject]@{
    stamp      = $stamp
    label      = $Label
    pack_dir   = $packDir
    zip_path   = $zipPathForRec
    zip_mb     = $zipMb
    files      = $totalFiles
    mb         = $totalMb
    created_at = (Get-Date -Format 'o')
})
@($rows) | Export-Csv -Path $packsCsv -NoTypeInformation -Encoding UTF8
Write-Output "MANIFEST -> $packsCsv (累计 $($rows.Count) 条)"
