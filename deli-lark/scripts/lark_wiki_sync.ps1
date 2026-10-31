param(
    [string]$SpaceId   = "7698217434058132412",
    [string]$SpaceName = "人工智能研究中心研发知识库",
    [string]$BaseDir   = "C:\Users\Administrator\Documents\人工智能研究中心",
    [switch]$Full,
    [switch]$Manual,
    [int]$MaxDepth     = 8
)

$ErrorActionPreference = 'Continue'
$env:PATH = "C:\Program Files\nodejs;C:\Users\Administrator\AppData\Roaming\npm;" + $env:PATH

$incDir    = Join-Path $BaseDir "增量"
$stateFile = Join-Path $BaseDir ".sync-state.json"
$logDir    = Join-Path $BaseDir "_logs"
New-Item -ItemType Directory -Force -Path $incDir, $logDir | Out-Null

$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$dayTag = Get-Date -Format 'yyyy-MM-dd'

# 设计约定：每天一个批次目录 + 一个同名 zip，目录只累积不重建。
# 同一天多次运行 -> 复用同一个 dayTag 目录，只往里加新文件。
# zip 每次都从整个目录重建，所以即使你把 zip 删了再跑一次，也会重新生成完整包。
$batchName = $dayTag

$batchDir = Join-Path $incDir $batchName
$filesDir = Join-Path $batchDir 'files'
New-Item -ItemType Directory -Force -Path $filesDir | Out-Null

$logFile = Join-Path $logDir "sync-$stamp.log"
function Log($m) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
    Write-Output $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

# ---------- state ----------
$known = @{}
if (-not $Full -and (Test-Path $stateFile)) {
    try {
        $st = Get-Content $stateFile -Raw | ConvertFrom-Json
        if ($st.knownTokens) {
            $st.knownTokens.PSObject.Properties | ForEach-Object { $known[$_.Name] = $_.Value }
        }
    } catch { Log "WARN state load failed" }
}

Log "=== SYNC START space=$SpaceId full=$($Full.IsPresent) manual=$($Manual.IsPresent) known=$($known.Count) batch=$batchName ==="

# ---------- walk ----------
$nodes = New-Object System.Collections.ArrayList
function Get-Nodes {
    param([string]$ParentNode, [int]$Depth)
    if ($Depth -gt $MaxDepth) { return }
    $a = @('wiki','nodes','list','--space-id',$SpaceId,'--page-all','--page-size','50')
    if (-not [string]::IsNullOrEmpty($ParentNode)) { $a += @('--parent-node-token',$ParentNode) }

    # 必须把 stdout 与 stderr 分开，并强制 UTF-8 代码页：
    #  1) --page-all 会往 stderr 打 "[page N] fetching..."，混入会破坏 JSON
    #  2) cmd.exe 默认代码页是 GBK，中文标题会被转成乱码并撕裂 JSON 结构
    # 这两个问题曾导致计划任务下 nodes=0 的静默失败
    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()
    try {
        $cliLine = 'chcp 65001 >nul & lark-cli ' + ($a -join ' ') + ' > "' + $tmpOut + '" 2> "' + $tmpErr + '"'
        $null = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $cliLine) `
            -NoNewWindow -Wait -PassThru -ErrorAction Stop
        $rawBytes = [System.IO.File]::ReadAllBytes($tmpOut)
        $raw = [System.Text.Encoding]::UTF8.GetString($rawBytes)
        if ([string]::IsNullOrWhiteSpace($raw.Trim())) {
            $errTxt = Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($errTxt)) { Log "WARN cli empty stdout depth=$Depth :: $(($errTxt -replace '\s+',' ').Trim())" }
        }
        $j = $null
        try { $j = $raw | ConvertFrom-Json } catch { Log "WARN json parse fail depth=$Depth len=$($raw.Length)"; return }
        if (-not $j -or -not $j.ok) {
            $m = if ($j -and $j.error) { "$($j.error.type)/$($j.error.subtype): $($j.error.message)" } else { 'not ok / empty' }
            Log "WARN list fail depth=$Depth :: $m"
            return
        }
        foreach ($it in $j.data.items) {
        $null = $nodes.Add([pscustomobject]@{
            node_token = $it.node_token; obj_token = $it.obj_token
            obj_type   = $it.obj_type;   title     = $it.title
            parent     = $ParentNode;    depth     = $Depth
            edit_time  = $it.obj_edit_time; url    = $it.url
        })
        if ($it.has_child) { Get-Nodes -ParentNode $it.node_token -Depth ($Depth + 1) }
        }
    }
    finally {
        Remove-Item $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue
    }
}
Get-Nodes -ParentNode '' -Depth 0
Log "tree nodes = $($nodes.Count)"

$byNode = @{}
foreach ($n in $nodes) { $byNode[$n.node_token] = $n }

function Get-RelPath($node) {
    $parts = New-Object System.Collections.ArrayList
    $cur = $node; $g = 0
    while ($cur -and $g -lt 20) {
        $nm = if ([string]::IsNullOrWhiteSpace($cur.title)) { "(untitled-$($cur.node_token.Substring(0,6)))" } else { $cur.title }
        $parts.Insert(0, $nm)
        if ([string]::IsNullOrEmpty($cur.parent) -or -not $byNode.ContainsKey($cur.parent)) { break }
        $cur = $byNode[$cur.parent]; $g++
    }
    return ($parts -join '\')
}
function Sanitize($s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return "untitled" }
    foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) { $s = $s.Replace($c, '_') }
    return $s.Trim().TrimEnd('.')
}

# ---------- fetch ----------
$index = New-Object System.Collections.ArrayList
$okc = 0; $skip = 0; $fail = 0

foreach ($n in $nodes) {
    if ([string]::IsNullOrEmpty($n.obj_token)) { continue }

    $rel   = Get-RelPath $n
    $isNew = -not $known.ContainsKey($n.obj_token)
    if (-not $isNew -and -not $Full) { $skip++; continue }

    $rec = [ordered]@{
        original_path = "$SpaceName\$rel"
        title = $n.title; obj_type = $n.obj_type; obj_token = $n.obj_token
        node_token = $n.node_token; url = $n.url; edit_time = $n.edit_time
        local_relpath = $null; bytes = 0; status = 'FAIL'; error = ''
    }

    # 逐段清洗，保留层级结构（不能对整条相对路径 Sanitize，否则 \ 会被替换成 _）
    $dirRel   = Split-Path $rel -Parent
    $baseName = Sanitize $n.title
    if ($dirRel) {
        $segs = $dirRel -split '\\' | Where-Object { $_ -ne '' } | ForEach-Object { Sanitize $_ }
        $targetDir = $filesDir
        foreach ($s in $segs) { $targetDir = Join-Path $targetDir $s }
    } else {
        $targetDir = $filesDir
    }
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

    if ($n.obj_type -eq 'docx' -or $n.obj_type -eq 'doc') {
        $raw = & lark-cli docs +fetch --doc $n.url --doc-format markdown 2>$null | Out-String
        $j = $null
        try { $j = $raw | ConvertFrom-Json } catch { }
        if ($j -and $j.ok) {
            $content = $j.data.document.content
            if ([string]::IsNullOrEmpty($content)) { $content = "<!-- empty document -->" }
            $target = Join-Path $targetDir "$baseName.md"
            $k = 1
            while (Test-Path -LiteralPath $target) { $target = Join-Path $targetDir "$baseName ($k).md"; $k++ }
            Set-Content -Path $target -Value $content -Encoding UTF8
            $rec.local_relpath = $target.Substring($batchDir.Length + 1)
            $rec.bytes = (Get-Item $target).Length
            $rec.status = 'OK'
            $known[$n.obj_token] = (Get-Date -Format 'o')
            $okc++
            Log "OK   $($rec.original_path) ($($rec.bytes) B)"
        } else {
            $msg = if ($j -and $j.error) { "$($j.error.type)/$($j.error.subtype): $($j.error.message)" } else { ($raw -replace '\s+',' ').Trim() }
            if ($msg.Length -gt 250) { $msg = $msg.Substring(0,250) }
            $rec.error = $msg; $fail++
            Log "FAIL $($rec.original_path) :: $msg"
        }
    }
    elseif ($n.obj_type -eq 'bitable') {
        # 多维表格：官方导出受限，改用 base API 读表 -> 每表生成 CSV + MD
        $tal = & lark-cli base +table-list --base-token $n.obj_token 2>$null | Out-String
        $tj = $null
        try { $tj = $tal | ConvertFrom-Json } catch { }
        if (-not ($tj -and $tj.ok)) {
            $msg = if ($tj -and $tj.error) { "$($tj.error.type)/$($tj.error.subtype): $($tj.error.message)" } else { 'table-list failed' }
            $rec.error = $msg; $fail++
            Log "FAIL $($rec.original_path) :: $msg"
        }
        else {
            $subDir = Join-Path $targetDir $baseName
            New-Item -ItemType Directory -Force -Path $subDir | Out-Null
            $subOk = 0
            foreach ($t in $tj.data.tables) {
                $tName = Sanitize $t.name
                $dl = Join-Path $env:TEMP ("basetbl-" + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Force -Path $dl | Out-Null
                Push-Location $dl
                try {
                    $null = & lark-cli base +record-list --base-token $n.obj_token --table-id $t.id --page-size 500 --format ndjson 2>$null | Out-String
                    $nd = Get-ChildItem $dl -Filter '*.ndjson' | Select-Object -First 1
                    if ($nd) {
                        $lines = Get-Content $nd.FullName -Encoding UTF8 | Where-Object { $_.Trim() }
                        $objs = @()
                        foreach ($l in $lines) { try { $objs += ($l | ConvertFrom-Json) } catch { } }
                        if ($objs.Count -gt 0) {
                            $flat = $objs | ForEach-Object {
                                $r = [ordered]@{}
                                if ($_.fields) {
                                    foreach ($p in $_.fields.PSObject.Properties) {
                                        $v = $p.Value
                                        if ($v -is [array]) { $v = ($v | ForEach-Object { if ($_ -is [string]) { $_ } elseif ($_.text) { $_.text } else { "$_" } }) -join '; ' }
                                        elseif ($v -is [pscustomobject]) { if ($v.text) { $v = $v.text } else { $v = ($v | ConvertTo-Json -Compress -Depth 3) } }
                                        $r[$p.Name] = $v
                                    }
                                }
                                [pscustomobject]$r
                            }
                            $flat | Export-Csv -Path (Join-Path $subDir "$tName.csv") -NoTypeInformation -Encoding UTF8
                            $subOk++
                        } else {
                            New-Item -ItemType File -Force -Path (Join-Path $subDir "$tName.empty") | Out-Null
                            $subOk++
                        }
                    }
                } catch { }
                finally { Pop-Location; Remove-Item $dl -Recurse -Force -ErrorAction SilentlyContinue }
            }
            if ($subOk -gt 0) {
                $rec.local_relpath = $subDir.Substring($batchDir.Length + 1)
                $rec.status = 'OK'
                $known[$n.obj_token] = (Get-Date -Format 'o')
                $okc++
                Log "OK   $($rec.original_path) (bitable, $subOk tables)"
            } else {
                $rec.error = 'all tables failed'; $fail++
                Log "FAIL $($rec.original_path) :: all tables failed"
            }
        }
    }
    elseif ($n.obj_type -eq 'sheet' -or $n.obj_type -eq 'slides') {
        $ext = switch ($n.obj_type) { 'sheet' { 'xlsx' } 'slides' { 'pptx' } }
        $stage = Join-Path $env:TEMP ("larksync-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $stage | Out-Null
        $raw = & lark-cli drive +export --url $n.url --file-extension $ext --output-dir $stage --overwrite 2>$null | Out-String
        $ej = $null
        try { $ej = $raw | ConvertFrom-Json } catch { }
        if ($LASTEXITCODE -eq 0 -and $ej -and $ej.ok) {
            $p = Get-ChildItem $stage -File | Select-Object -First 1
            if ($p) {
                $target = Join-Path $targetDir "$baseName.$ext"
                $k = 1
                while (Test-Path -LiteralPath $target) { $target = Join-Path $targetDir "$baseName ($k).$ext"; $k++ }
                Move-Item -LiteralPath $p.FullName -Destination $target -Force
                $rec.local_relpath = $target.Substring($batchDir.Length + 1)
                $rec.bytes = (Get-Item $target).Length
                $rec.status = 'OK'
                $known[$n.obj_token] = (Get-Date -Format 'o')
                $okc++
                Log "OK   $($rec.original_path) ($($rec.bytes) B)"
            } else { $rec.error = 'no file produced'; $fail++; Log "FAIL $($rec.original_path) :: no file" }
        } else {
            $msg = if ($ej -and $ej.error) { "$($ej.error.type)/$($ej.error.subtype): $($ej.error.message)" } else { 'export failed' }
            if ($msg.Length -gt 250) { $msg = $msg.Substring(0,250) }
            $rec.error = $msg; $fail++
            Log "FAIL $($rec.original_path) :: $msg"
        }
        Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    elseif ($n.obj_type -eq 'file') {
        # 知识库里"上传的文件"（非云文档），如 .md / .pdf / .docx 附件
        # 注意 obj_token 是 file_token，用 drive +download 下载
        $stageF = Join-Path $env:TEMP ("wfile-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $stageF | Out-Null
 
        # 从标题推断扩展名；无扩展名时给 .bin
        $fileExt = [System.IO.Path]::GetExtension($n.title)
        if ([string]::IsNullOrWhiteSpace($fileExt)) { $fileExt = '.bin' }
        $stemF = if ($fileExt -and $n.title.EndsWith($fileExt)) { $n.title.Substring(0, $n.title.Length - $fileExt.Length) } else { $n.title }
        $stemF = Sanitize $stemF
        $stagePath = Join-Path $stageF ($stemF + $fileExt)
 
        $rawF = & lark-cli drive +download --file-token $n.obj_token --output $stagePath --overwrite 2>$null | Out-String
        $fj2 = $null
        try { $fj2 = $rawF | ConvertFrom-Json } catch { }
        if ($LASTEXITCODE -eq 0 -and $fj2 -and $fj2.ok -and (Test-Path $stagePath)) {
            $targetF = Join-Path $targetDir ($stemF + $fileExt)
            $kf = 1
            while (Test-Path -LiteralPath $targetF) {
                $targetF = Join-Path $targetDir ("$stemF ($kf)$fileExt"); $kf++
            }
            Move-Item -LiteralPath $stagePath -Destination $targetF -Force
            $rec.local_relpath = $targetF.Substring($batchDir.Length + 1)
            $rec.bytes = (Get-Item $targetF).Length
            $rec.status = 'OK'
            $known[$n.obj_token] = (Get-Date -Format 'o')
            $okc++
            Log "OK   $($rec.original_path) (file $fileExt, $($rec.bytes) B)"
        } else {
            $msg = if ($fj2 -and $fj2.error) { "$($fj2.error.type)/$($fj2.error.subtype): $($fj2.error.message)" } else { 'download failed' }
            if ($msg.Length -gt 250) { $msg = $msg.Substring(0,250) }
            $rec.error = $msg; $fail++
            Log "FAIL $($rec.original_path) :: $msg"
        }
        Remove-Item $stageF -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        $rec.status = 'SKIPPED_TYPE'
        $rec.error = "unsupported obj_type: $($n.obj_type)"
        $null = $index.Add([pscustomobject]$rec)
        continue
    }

    $null = $index.Add([pscustomobject]$rec)
    Start-Sleep -Milliseconds 150
}

# ---------- index（累积合并，不覆盖当天已有条目）----------
$idxCsv  = Join-Path $batchDir 'index.csv'
$idxJson = Join-Path $batchDir 'index.json'

$merged = New-Object System.Collections.ArrayList
$mergedKeys = @{}
if (Test-Path $idxCsv) {
    try {
        foreach ($old in (Import-Csv $idxCsv)) {
            if ([string]::IsNullOrWhiteSpace($old.obj_token)) { continue }
            $mergedKeys[$old.obj_token] = $true
            $null = $merged.Add($old)
        }
    } catch { Log "WARN 读取当天已有 index 失败，将重建" }
}
foreach ($r in $index) {
    if (-not [string]::IsNullOrWhiteSpace($r.obj_token) -and $mergedKeys.ContainsKey($r.obj_token)) {
        # 已存在则替换（同一天重跑同一节点）
        for ($i = $merged.Count - 1; $i -ge 0; $i--) {
            if ($merged[$i].obj_token -eq $r.obj_token) { $merged.RemoveAt($i) }
        }
    }
    $null = $merged.Add($r)
    if (-not [string]::IsNullOrWhiteSpace($r.obj_token)) { $mergedKeys[$r.obj_token] = $true }
}

if ($merged.Count -gt 0) {
    @($merged) | Export-Csv -Path $idxCsv -NoTypeInformation -Encoding UTF8
    @($merged) | ConvertTo-Json -Depth 6 | Set-Content -Path $idxJson -Encoding UTF8
    Log "INDEX 当天累计 $($merged.Count) 条"
}

# ---------- zip（每次从整个当天目录重建）----------
$zipPath = $null
$dayFileCount = (Get-ChildItem $filesDir -Recurse -File -ErrorAction SilentlyContinue).Count
if ($dayFileCount -gt 0) {
    $zipPath = Join-Path $incDir "$batchName.zip"
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    try {
        # 压缩整个批次目录（含 files/ 与索引），保证对方拿到完整当天包
        Compress-Archive -Path (Join-Path $batchDir '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
        $zipMb = [math]::Round((Get-Item $zipPath).Length/1MB, 2)
        Log "ZIP -> $zipPath ($zipMb MB, 当天累计 $dayFileCount 个文件)"
    } catch {
        Log "ZIP FAIL: $($_.Exception.Message)"
        $zipPath = $null
    }
} else {
    Log "当天无文件，跳过 zip"
}

# ---------- state ----------
[pscustomobject]@{
    spaceId = $SpaceId; lastRun = (Get-Date -Format 'o'); knownTokens = $known
} | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile -Encoding UTF8

Log "=== DONE ok=$okc skip=$skip fail=$fail nodes=$($nodes.Count) zip=$zipPath ==="
Write-Output "SUMMARY ok=$okc skip=$skip fail=$fail zip=$zipPath"
