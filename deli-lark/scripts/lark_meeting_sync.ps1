param(
    [int]$Days       = 30,
    [string]$StartDate,
    [string]$EndDate,
    [string]$OutRoot  = "C:\Users\Administrator\Documents\人工智能研究中心\会议归档",
    [switch]$WithVerbatim = $true,
    [switch]$NoImages,
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$env:PATH = "C:\Program Files\nodejs;C:\Users\Administrator\AppData\Roaming\npm;" + $env:PATH

$ME = "ou_9efd9de30b4b8b7dee8e180f0757d44f"

if (-not $StartDate) { $StartDate = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-dd') }
if (-not $EndDate)   { $EndDate   = (Get-Date).ToString('yyyy-MM-dd') }

$stateFile = Join-Path $OutRoot ".meeting-state.json"
$logDir    = Join-Path $OutRoot "_logs"
New-Item -ItemType Directory -Force -Path $OutRoot, $logDir | Out-Null

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $logDir "meeting-$stamp.log"
function Log($m) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
    Write-Output $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

function Sanitize($s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return "untitled" }
    foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) { $s = $s.Replace($c, '_') }
    return $s.Trim().TrimEnd('.')
}

# 已抓过的 meeting_id（增量基准）
$known = @{}
if (Test-Path $stateFile) {
    try {
        $st = Get-Content $stateFile -Raw | ConvertFrom-Json
        if ($st.meetings) { $st.meetings.PSObject.Properties | ForEach-Object { $known[$_.Name] = $_.Value } }
    } catch { Log "WARN state load failed" }
}

Log "=== MEETING SYNC START range=$StartDate..$EndDate known=$($known.Count) ==="

# ---------- 1) 列出会议 ----------
$searchRaw = & lark-cli vc +search --participant-ids $ME --start $StartDate --end $EndDate --page-size 30 --format json 2>$null | Out-String
$searchJ = $null
try { $searchJ = $searchRaw | ConvertFrom-Json } catch { }
if (-not ($searchJ -and $searchJ.ok)) {
    Log "FATAL: vc +search failed"
    Write-Output ($searchRaw -replace '\s+',' ')
    exit 1
}

$meetings = @($searchJ.data.items)
Log "会议数 = $($meetings.Count)"

# 解析 display_info 里的时间/主题作为兜底
function Parse-Display($di) {
    $lines = $di -split "`n"
    $topic = if ($lines.Count -gt 0) { $lines[0].Trim() } else { 'unknown' }
    $dt = $null
    if ($di -match '(今天|昨天|\d+月\d+日)\s+(\d{1,2}:\d{2})') {
        $label = $Matches[1]; $tm = $Matches[2]
        $base = Get-Date
        if ($label -eq '昨天') { $base = $base.AddDays(-1) }
        elseif ($label -match '(\d+)月(\d+)日') {
            $mm = [int]$Matches[1]; $dd = [int]$Matches[2]
            $base = Get-Date -Year $base.Year -Month $mm -Day $dd
        }
        $dt = $base.Date.Add([timespan]::Parse($tm))
    }
    return @{ topic = $topic; datetime = $dt }
}

# ---------- 2) 批量取 note_id ----------
$ids = $meetings | ForEach-Object { $_.id }
$detailJ = $null
if ($ids.Count -gt 0) {
    $detailRaw = & lark-cli vc +detail --meeting-ids ($ids -join ',') --format json 2>$null | Out-String
    try { $detailJ = $detailRaw | ConvertFrom-Json } catch { }
}
$detailMap = @{}
if ($detailJ -and $detailJ.ok) {
    foreach ($m in $detailJ.data.meetings) { $detailMap[$m.meeting_id] = $m }
}

$stats = @{ ok = 0; skip = 0; fail = 0; note = 0; verbatim = 0 }

foreach ($mt in $meetings) {
    $mid = $mt.id
    $parsed = Parse-Display $mt.display_info
    $d = $detailMap[$mid]

    $topic = if ($d -and $d.topic) { $d.topic } else { $parsed.topic }
    $startTime = if ($d -and $d.start_time) { $d.start_time } else { $null }
    $noteId = if ($d) { $d.note_id } else { $null }

    # 日期目录：优先 start_time
    $dateDir = if ($startTime -match '^(\d{4}-\d{2}-\d{2})') { $Matches[1] }
               elseif ($parsed.datetime) { $parsed.datetime.ToString('yyyy-MM-dd') }
               else { 'unknown-date' }

    if ($known.ContainsKey($mid)) {
        $stats.skip++
        Log "SKIP $topic ($mid)"
        continue
    }

    if ([string]::IsNullOrEmpty($noteId)) {
        $stats.fail++
        Log "NO-NOTE $topic ($mid) :: hint=$(if($d){$d.hint}else{'n/a'})"
        continue
    }

    if ($DryRun) {
        Log "DRY  $topic  date=$dateDir note=$noteId"
        continue
    }

    # ---------- 3) note_id -> tokens ----------
    $noteRaw = & lark-cli note +detail --note-id $noteId --format json 2>$null | Out-String
    $noteJ = $null
    try { $noteJ = $noteRaw | ConvertFrom-Json } catch { }
    if (-not ($noteJ -and $noteJ.ok)) {
        $stats.fail++
        Log "FAIL note+detail $topic :: $((($noteRaw -replace '\s+',' ')).Substring(0,[Math]::Min(150,($noteRaw -replace '\s+',' ').Length)))"
        continue
    }
    $noteDocToken = $noteJ.data.note.note_doc_token
    $verbatimToken = $noteJ.data.note.verbatim_doc_token

    # ---------- 4) 落目录 ----------
    $safeTopic = Sanitize $topic
    $dir = Join-Path (Join-Path $OutRoot $dateDir) $safeTopic
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $grabbed = New-Object System.Collections.ArrayList

    # 纪要
    if ($noteDocToken) {
        $fr = & lark-cli docs +fetch --doc $noteDocToken --doc-format markdown 2>$null | Out-String
        $fj = $null
        try { $fj = $fr | ConvertFrom-Json } catch { }
        if ($fj -and $fj.ok) {
            $content = $fj.data.document.content
            if ([string]::IsNullOrEmpty($content)) { $content = '<!-- empty -->' }

            if (-not $NoImages) {
                $imgTokens = @()
                foreach ($m in [regex]::Matches($content, '!\[[^\]]*\]\(https://[^)]*?/file/([A-Za-z0-9]+)\)')) { $imgTokens += $m.Groups[1].Value }
                $imgTokens = $imgTokens | Select-Object -Unique
                if ($imgTokens.Count -gt 0) {
                    $assetDir = Join-Path $dir 'assets'
                    New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
                    $i = 0
                    foreach ($tk in $imgTokens) {
                        $i++
                        $tmpP = Join-Path $env:TEMP ("mtg-" + [guid]::NewGuid().ToString('N') + ".png")
                        $null = & lark-cli docs +media-download --token $tk --output $tmpP --overwrite 2>$null | Out-String
                        if (Test-Path $tmpP) {
                            $fn = Sanitize ("{0}-{1}.png" -f $safeTopic, $i)
                            Move-Item -LiteralPath $tmpP -Destination (Join-Path $assetDir $fn) -Force
                            $content = $content -replace [regex]::Escape("https://feishu.cn/file/$tk"), "assets/$fn"
                            $content = $content -replace [regex]::Escape("/file/$tk"), "assets/$fn"
                        }
                        Remove-Item $tmpP -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            $p = Join-Path $dir "纪要.md"
            Set-Content -Path $p -Value $content -Encoding UTF8
            $null = $grabbed.Add('纪要.md')
            $stats.note++
        } else { Log "WARN 纪要抓取失败 $topic" }
    }

    # 逐字稿
    if ($WithVerbatim -and $verbatimToken) {
        $vr = & lark-cli docs +fetch --doc $verbatimToken --doc-format markdown 2>$null | Out-String
        $vj = $null
        try { $vj = $vr | ConvertFrom-Json } catch { }
        if ($vj -and $vj.ok) {
            $vc = $vj.data.document.content
            if ([string]::IsNullOrEmpty($vc)) { $vc = '<!-- empty -->' }
            $p2 = Join-Path $dir "逐字稿.md"
            Set-Content -Path $p2 -Value $vc -Encoding UTF8
            $null = $grabbed.Add('逐字稿.md')
            $stats.verbatim++
        } else { Log "WARN 逐字稿抓取失败 $topic" }
    }

    if ($grabbed.Count -gt 0) {
        $stats.ok++
        $known[$mid] = @{
            topic = $topic; date = $dateDir; note_id = $noteId
            grabbed_at = (Get-Date -Format 'o'); files = ($grabbed -join ',')
        }
        Log "OK   $topic [$dateDir] -> $($grabbed -join ',')"
    } else {
        $stats.fail++
        Log "FAIL $topic :: nothing grabbed"
    }

    Start-Sleep -Milliseconds 200
}

# ---------- 5) 保存 state ----------
[pscustomobject]@{
    lastRun = (Get-Date -Format 'o'); meetings = $known
} | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile -Encoding UTF8

Log "=== DONE ok=$($stats.ok) skip=$($stats.skip) fail=$($stats.fail) notes=$($stats.note) verbatim=$($stats.verbatim) ==="
Write-Output "SUMMARY ok=$($stats.ok) skip=$($stats.skip) fail=$($stats.fail) notes=$($stats.note) verbatim=$($stats.verbatim)"
