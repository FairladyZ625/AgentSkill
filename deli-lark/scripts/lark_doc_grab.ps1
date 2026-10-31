param(
    # 支持多种传入方式：
    #   -Url "u1","u2"        （数组）
    #   -Url "u1,u2"          （逗号分隔字符串）
    #   -UrlFile links.txt    （每行一个）
    [string[]]$Url,
    [string]$UrlFile,
    [string]$BaseDir = "C:\Users\Administrator\Documents\人工智能研究中心",
    [string]$SubDir  = "增量\会议纪要",
    [switch]$NoImages
)

$ErrorActionPreference = 'Continue'
$env:PATH = "C:\Program Files\nodejs;C:\Users\Administrator\AppData\Roaming\npm;" + $env:PATH

# 归一化输入：数组元素可能自带逗号/换行，统一拆开
$UrlList = New-Object System.Collections.ArrayList
if ($Url) {
    foreach ($u0 in $Url) {
        foreach ($part in ($u0 -split "[,\r\n]")) {
            $t = $part.Trim()
            if ($t) { $null = $UrlList.Add($t) }
        }
    }
}
if ($UrlFile -and (Test-Path $UrlFile)) {
    foreach ($ln in (Get-Content $UrlFile -Encoding UTF8)) {
        $t = $ln.Trim()
        if ($t -and -not $t.StartsWith('#')) { $null = $UrlList.Add($t) }
    }
}
if ($UrlList.Count -eq 0) {
    Write-Output "ERROR: no url provided. Use -Url 'u1,u2' or -UrlFile links.txt"
    exit 1
}
# 去重保序
$seen = @{}
$UrlArr = @()
foreach ($u in $UrlList) { if (-not $seen.ContainsKey($u)) { $seen[$u] = 1; $UrlArr += $u } }
$Url = $UrlArr
Write-Output "URLS=$($Url.Count)"

# ============================================================
# lark_doc_grab.ps1 — 抓取单个飞书文档到本地（含图片）
# 核心：docs +fetch 只受"读权限"约束，不受导出权限限制
# ============================================================

function Sanitize($s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return "untitled" }
    foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) { $s = $s.Replace($c, '_') }
    return $s.Trim().TrimEnd('.')
}

$results = @()

foreach ($u in $Url) {
    $u = $u.Trim()
    if ([string]::IsNullOrWhiteSpace($u)) { continue }

    $rec = [ordered]@{
        url = $u; title = $null; token = $null; type = $null
        date = $null; saved_path = $null; images = 0
        status = 'FAIL'; error = ''
    }

    # --- 1) inspect 取标题/类型/规范 token ---
    $iraw = & lark-cli drive +inspect --url $u 2>$null | Out-String
    $ij = $null
    try { $ij = $iraw | ConvertFrom-Json } catch { }
    if (-not ($ij -and $ij.ok)) {
        $rec.error = if ($ij -and $ij.error) { "$($ij.error.type)/$($ij.error.subtype): $($ij.error.message)" } else { 'inspect failed' }
        $results += [pscustomobject]$rec
        Write-Output "FAIL [inspect] $u :: $($rec.error)"
        continue
    }

    $rec.title = $ij.data.title
    $rec.token = $ij.data.token
    $rec.type  = $ij.data.type

    # --- 2) 从标题提取日期，决定归档子目录 ---
    $monthDir = ''
    if ($rec.title -match '(20\d{2})\s*[年\-/]\s*(\d{1,2})\s*[月\-/]') {
        $y = $Matches[1]; $m = [int]$Matches[2]
        $monthDir = "{0}-{1:D2}" -f $y, $m
        $rec.date = "$y-$('{0:D2}' -f $m)"
    } elseif ($rec.title -match '(20\d{2})(\d{2})(\d{2})') {
        $monthDir = "$($Matches[1])-$($Matches[2])"
        $rec.date = "$($Matches[1])-$($Matches[2])-$($Matches[3])"
    } else {
        $monthDir = Get-Date -Format 'yyyy-MM'
    }

    # --- 3) fetch 正文 ---
    if ($rec.type -eq 'docx' -or $rec.type -eq 'doc') {
        $fraw = & lark-cli docs +fetch --doc $u --doc-format markdown 2>$null | Out-String
        $fj = $null
        try { $fj = $fraw | ConvertFrom-Json } catch { }

        if (-not ($fj -and $fj.ok)) {
            $rec.error = if ($fj -and $fj.error) { "$($fj.error.type)/$($fj.error.subtype)(code $($fj.error.code)): $($fj.error.message)" } else { 'fetch failed' }
            $results += [pscustomobject]$rec
            Write-Output "FAIL [fetch] $($rec.title) :: $($rec.error)"
            continue
        }

        $content = $fj.data.document.content
        if ([string]::IsNullOrEmpty($content)) { $content = '<!-- empty document -->' }

        # --- 4) 目标目录 & 文件名 ---
        $dir = Join-Path (Join-Path $BaseDir $SubDir) $monthDir
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $baseName = Sanitize $rec.title
        $mdPath = Join-Path $dir "$baseName.md"

        # --- 5) 下载图片并改写链接 ---
        if (-not $NoImages) {
            # 匹配 ![alt](https://xxx.feishu.cn/file/TOKEN) 与 whiteboard token
            $imgTokens = @()
            foreach ($m in [regex]::Matches($content, '!\[[^\]]*\]\(https://[^)]*?/file/([A-Za-z0-9]+)\)')) {
                $imgTokens += $m.Groups[1].Value
            }
            $imgTokens = $imgTokens | Select-Object -Unique

            if ($imgTokens.Count -gt 0) {
                $assetDir = Join-Path $dir 'assets'
                New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
                $idx = 0
                foreach ($tk in $imgTokens) {
                    $idx++
                    # CLI 白名单限制：先落 temp 再搬
                    $tmpName = "larkimg-$([guid]::NewGuid().ToString('N')).png"
                    $tmpPath = Join-Path $env:TEMP $tmpName
                    $null = & lark-cli docs +media-download --token $tk --output $tmpPath --overwrite 2>$null | Out-String
                    if (Test-Path $tmpPath) {
                        $finalName = "$baseName-$idx.png"
                        $finalName = Sanitize $finalName
                        $destImg = Join-Path $assetDir $finalName
                        Move-Item -LiteralPath $tmpPath -Destination $destImg -Force
                        # 改写 markdown 链接为相对路径
                        $content = $content -replace [regex]::Escape("https://feishu.cn/file/$tk"), "assets/$finalName"
                        $content = $content -replace [regex]::Escape("/file/$tk"), "assets/$finalName"
                        $rec.images++
                    }
                    Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
                }
            }
        }

        # --- 6) 落盘 ---
        Set-Content -Path $mdPath -Value $content -Encoding UTF8
        $rec.saved_path = $mdPath
        $rec.status = 'OK'
        $results += [pscustomobject]$rec
        Write-Output "OK   $($rec.title) -> $mdPath  (images=$($rec.images))"
    }
    elseif ($rec.type -eq 'bitable') {
        # 多维表格：走 base API
        $dir = Join-Path (Join-Path $BaseDir $SubDir) $monthDir
        $baseName = Sanitize $rec.title
        $subDir = Join-Path $dir $baseName
        New-Item -ItemType Directory -Force -Path $subDir | Out-Null
        $tl = & lark-cli base +table-list --base-token $rec.token 2>$null | Out-String
        $tj = $null
        try { $tj = $tl | ConvertFrom-Json } catch { }
        if ($tj -and $tj.ok) {
            foreach ($t in $tj.data.tables) {
                $tn = Sanitize $t.name
                $tmpD = Join-Path $env:TEMP ("bt-" + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Force -Path $tmpD | Out-Null
                Push-Location $tmpD
                $null = & lark-cli base +record-list --base-token $rec.token --table-id $t.id --page-size 500 --format ndjson 2>$null | Out-String
                $nd = Get-ChildItem $tmpD -Filter '*.ndjson' | Select-Object -First 1
                if ($nd) {
                    $rows = @()
                    foreach ($ln in (Get-Content $nd.FullName -Encoding UTF8 | Where-Object { $_.Trim() })) {
                        try {
                            $o = $ln | ConvertFrom-Json
                            $flat = [ordered]@{}
                            if ($o.fields) {
                                foreach ($p in $o.fields.PSObject.Properties) {
                                    $v = $p.Value
                                    if ($v -is [array]) { $v = ($v | ForEach-Object { if ($_ -is [string]) { $_ } elseif ($_.text) { $_.text } else { "$_" } }) -join '; ' }
                                    elseif ($v -is [pscustomobject]) { $v = if ($v.text) { $v.text } else { ($v | ConvertTo-Json -Compress -Depth 3) } }
                                    $flat[$p.Name] = $v
                                }
                            }
                            $rows += [pscustomobject]$flat
                        } catch { }
                    }
                    if ($rows.Count -gt 0) {
                        $rows | Export-Csv -Path (Join-Path $subDir "$tn.csv") -NoTypeInformation -Encoding UTF8
                    }
                }
                Pop-Location
                Remove-Item $tmpD -Recurse -Force -ErrorAction SilentlyContinue
            }
            $rec.saved_path = $subDir
            $rec.status = 'OK'
            $results += [pscustomobject]$rec
            Write-Output "OK   $($rec.title) -> $subDir (bitable)"
        } else {
            $rec.error = 'table-list failed'
            $results += [pscustomobject]$rec
            Write-Output "FAIL $($rec.title) :: table-list failed"
        }
    }
    else {
        $rec.error = "unsupported type: $($rec.type)"
        $results += [pscustomobject]$rec
        Write-Output "SKIP $u :: unsupported type $($rec.type)"
    }
}

# --- 7) 更新总索引 ---
# 注意：用 ArrayList 收集，普通数组 += 单元素会被解包成裸对象，丢失属性
$idxPath = Join-Path $BaseDir 'index-会议纪要.csv'
$existing = New-Object System.Collections.ArrayList
if (Test-Path $idxPath) {
    foreach ($r in (Import-Csv $idxPath)) { $null = $existing.Add($r) }
}
$new = @($results | Where-Object { $_.status -eq 'OK' })
foreach ($n in $new) {
    # 去掉同 url 旧记录
    for ($i = $existing.Count - 1; $i -ge 0; $i--) {
        if ($existing[$i].url -eq $n.url) { $existing.RemoveAt($i) }
    }
    $null = $existing.Add([pscustomobject]@{
        url = $n.url; title = $n.title; date = $n.date
        type = $n.type; images = $n.images
        saved_path = $n.saved_path; grabbed_at = (Get-Date -Format 'o')
    })
}
if ($existing.Count -gt 0) {
    @($existing) | Sort-Object grabbed_at -Descending | Export-Csv -Path $idxPath -NoTypeInformation -Encoding UTF8
}
Write-Output "INDEX=$idxPath  (rows=$($existing.Count))"
