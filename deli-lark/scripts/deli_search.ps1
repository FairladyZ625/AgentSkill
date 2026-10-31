param(
    [string]$Query,
    [string[]]$Queries,
    [string[]]$Keywords = @(),
    [ValidateSet('all','docs','messages','links')]
    [string]$Source = 'all',
    [int]$Days = 90,
    [int]$Limit = 20,
    [string]$OutDir = "C:\Users\Administrator\Documents\人工智能研究中心\_search",
    [switch]$ShowUrl,
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$env:PATH = "C:\Program Files\nodejs;C:\Users\Administrator\AppData\Roaming\npm;" + $env:PATH

# ============================================================
# deli_search.ps1 — 飞书内容检索
#   来源1: 知识库/云文档 (docs +search)
#   来源2: 群聊消息里的链接 (im +messages-search)
# ============================================================

# ---- 组装查询词 ----
$qlist = New-Object System.Collections.ArrayList
if ($Query) { foreach ($p in ($Query -split "[,，]")) { $t = $p.Trim(); if ($t) { $null = $qlist.Add($t) } } }
if ($Queries) { foreach ($q0 in $Queries) { foreach ($p in ($q0 -split "[,，\r\n]")) { $t = $p.Trim(); if ($t) { $null = $qlist.Add($t) } } } }
if ($Keywords) { foreach ($k in $Keywords) { $t = $k.Trim(); if ($t) { $null = $qlist.Add($t) } } }
$qlist = @($qlist | Select-Object -Unique)
if ($qlist.Count -eq 0) {
    Write-Output "ERROR: 需要 -Query 或 -Queries 或 -Keywords"
    exit 1
}

# -Json 模式下所有进度输出走 stderr，保证 stdout 是纯 JSON（可被 ConvertFrom-Json 直接消费）
function Out-Progress($msg) {
    if ($Json) { [Console]::Error.WriteLine($msg) } else { Write-Output $msg }
}

Out-Progress "QUERIES=$($qlist -join ' | ')  SOURCE=$Source"

$results = New-Object System.Collections.ArrayList

function Strip-Highlight($s) {
    if (-not $s) { return '' }
    return ($s -replace '</?h>','' -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>')
}

# ============================================================
# 来源 1：知识库 / 云文档
# ============================================================
if ($Source -eq 'all' -or $Source -eq 'docs') {
    foreach ($q in $qlist) {
        $raw = & lark-cli docs +search --query $q --page-size $Limit 2>$null | Out-String
        $j = $null
        try { $j = $raw | ConvertFrom-Json } catch { continue }
        if (-not ($j -and $j.ok)) { Out-Progress "  [docs] '$q' 调用失败"; continue }

        foreach ($r in $j.data.results) {
            $meta = $r.result_meta
            $title = Strip-Highlight $r.title_highlighted
            $null = $results.Add([pscustomobject]@{
                source     = 'docs'
                kind       = $meta.doc_types
                entity     = $r.entity_type
                title      = $title
                token      = $meta.token
                url        = $meta.url
                owner      = $meta.owner_name
                editor     = $meta.edit_user_name
                updated    = $meta.update_time_iso
                created    = $meta.create_time_iso
                chat       = ''
                sender     = ''
                msg_time   = ''
                query      = $q
                snippet    = Strip-Highlight $r.summary_highlighted
            })
        }
    }
    Out-Progress "  [docs] 累计 $($results.Count) 条"
}

# ============================================================
# 来源 2：群聊消息（含链接）
# ============================================================
if ($Source -eq 'all' -or $Source -eq 'messages' -or $Source -eq 'links') {
    $start = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:sszzz')
    $end   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')

    foreach ($q in $qlist) {
        $raw = & lark-cli im +messages-search --query $q --start $start --end $end --page-size $Limit --no-reactions 2>$null | Out-String
        $j = $null
        try { $j = $raw | ConvertFrom-Json } catch { continue }
        if (-not ($j -and $j.ok)) { Out-Progress "  [im] '$q' 调用失败"; continue }

        foreach ($m in $j.data.messages) {
            $content = "$($m.content)"
            # 从消息内容里抽出飞书链接
            $links = @([regex]::Matches($content, 'https?://[^\s"''<>]+') | ForEach-Object { $_.Value })
            $feishuLinks = $links | Where-Object { $_ -match 'feishu\.cn|feishu\.com|larksuite\.com' }

            $null = $results.Add([pscustomobject]@{
                source   = 'message'
                kind     = if ($feishuLinks.Count -gt 0) { 'LINK' } else { 'TEXT' }
                entity   = $m.chat_type
                title    = if ($feishuLinks.Count -gt 0) { $feishuLinks[0] } else { $content.Substring(0,[Math]::Min(120,$content.Length)) }
                token    = ''
                url      = if ($feishuLinks.Count -gt 0) { $feishuLinks[0] } else { '' }
                owner    = ''
                editor   = ''
                updated  = ''
                created  = ''
                chat     = if ($m.chat_name) { $m.chat_name } else { "(私聊)" }
                sender   = if ($m.sender -and $m.sender.name) { $m.sender.name } else { '' }
                msg_time = $m.create_time
                query    = $q
                snippet  = $content.Substring(0,[Math]::Min(200,$content.Length))
            })
        }
    }
    Out-Progress "  [im] 累计 $($results.Count) 条"
}

# ============================================================
# 去重
# ============================================================
$unique = New-Object System.Collections.ArrayList
$seen = @{}
foreach ($r in $results) {
    # docs 用 token 去重；message 用 url+时间 去重
    $key = if ($r.source -eq 'docs') { "d:$($r.token)" }
           elseif ($r.url) { "m:$($r.url)" }
           else { "m:$($r.chat)|$($r.msg_time)|$($r.snippet)" }
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = 1
    $null = $unique.Add($r)
}

# ============================================================
# 输出
# ============================================================
if ($Json) {
    @($unique) | ConvertTo-Json -Depth 4
    exit 0
}

Write-Output ""
Write-Output "================ 检索结果（去重后 $($unique.Count) 条）================"

$docRows = @($unique | Where-Object source -eq 'docs')
$msgRows = @($unique | Where-Object source -eq 'message')

if ($docRows.Count -gt 0) {
    Write-Output ""
    Write-Output "### 云文档 / 知识库（$($docRows.Count) 条）"
    $i = 0
    foreach ($r in $docRows) {
        $i++
        Write-Output ("{0,2}. [{1,-8}] {2}" -f $i, $r.kind, $r.title)
        Write-Output ("    来源={0}  所有者={1}  更新={2}" -f $r.entity, $r.owner, $r.updated)
        if ($ShowUrl -and $r.url) { Write-Output ("    {0}" -f $r.url) }
    }
}

if ($msgRows.Count -gt 0) {
    Write-Output ""
    Write-Output "### 群聊链接 / 消息（$($msgRows.Count) 条）"
    $i = 0
    foreach ($r in $msgRows) {
        $i++
        Write-Output ("{0,2}. [{1}] {2}" -f $i, $r.chat, $r.sender)
        Write-Output ("    {0}" -f $r.title)
        Write-Output ("    时间={0}" -f $r.msg_time)
    }
}

# ============================================================
# 落盘
# ============================================================
if ($unique.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $csv = Join-Path $OutDir "search-$stamp.csv"
    @($unique) | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
    # 变量名不能叫 $json —— PS 变量名不区分大小写，会和 [switch]$Json 参数冲突
    $jsonPath = Join-Path $OutDir "search-$stamp.json"
    @($unique) | ConvertTo-Json -Depth 4 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Output ""
    Write-Output "CSV  -> $csv"
    Write-Output "JSON -> $jsonPath"
}
