param(
    [string]$SrcCsv  = "C:\Users\Administrator\Documents\deepseek-harness\default-workspace\lark-export-index.csv",
    [string]$BaseDir = "C:\Users\Administrator\Documents\人工智能研究中心",
    [string]$PackRoot = "C:\Users\Administrator\Documents\人工智能研究中心\_packs",
    [string]$Label    = "飞书文档导出包",
    [switch]$NoZip
)

$ErrorActionPreference = 'Continue'

# 时间戳精确到秒：一天多轮也不会冲突
$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$packDir = Join-Path $PackRoot "$Label-$stamp"
$filesDir = Join-Path $packDir 'files'
New-Item -ItemType Directory -Force -Path $filesDir | Out-Null

Write-Output "STAMP=$stamp"
Write-Output "PACKDIR=$packDir"

$oldRoot = 'C:\Users\Administrator\Downloads'
$rows = @(Import-Csv $SrcCsv)
Write-Output "输入行数: $($rows.Count)"

$out = New-Object System.Collections.ArrayList
$ok = 0; $fail = 0; $missing = 0; $totalBytes = 0

foreach ($r in $rows) {
    # 修正根目录（导出时文件在 Downloads，之后移到 BaseDir）
    $newPath = $r.path -replace [regex]::Escape($oldRoot), $BaseDir
    $newExp  = $r.exported_file -replace [regex]::Escape($oldRoot), $BaseDir

    $relPath = $newPath.Replace($BaseDir + '\', '')
    $relExp  = if ($newExp) { $newExp.Replace($BaseDir + '\', '') } else { '' }

    $exists = $false
    $size = 0
    $src = $null
    if ($relExp) {
        $src = Join-Path $BaseDir $relExp
        if (Test-Path -LiteralPath $src) {
            $exists = $true
            $size = (Get-Item -LiteralPath $src).Length
        }
    }

    $status = $r.status
    $err = $r.error
    if ($status -eq 'OK' -and -not $exists) {
        $status = 'MISSING_FILE'
        $err = "file not found: $relExp"
        $missing++
    }

    if ($status -eq 'OK') {
        # 复制进包
        $dst = Join-Path $filesDir $relExp
        $dstDir = Split-Path $dst -Parent
        if (-not (Test-Path -LiteralPath $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
        Copy-Item -LiteralPath $src -Destination $dst -Force
        $ok++
        $totalBytes += $size
    } else { $fail++ }

    $null = $out.Add([pscustomobject]@{
        original_relpath = $relPath
        name             = $r.name
        type             = $r.type
        url              = $r.url
        exported_relpath = $relExp
        size_bytes       = $size
        status           = $status
        error            = $err
    })
}

Write-Output "OK=$ok FAIL=$fail MISSING=$missing  size=$([math]::Round($totalBytes/1MB,1)) MB"

# 索引
@($out) | Export-Csv -Path (Join-Path $packDir 'index.csv') -NoTypeInformation -Encoding UTF8
@($out) | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $packDir 'index.json') -Encoding UTF8

# README
$readmeSrc = Join-Path $BaseDir "导出包\README.md"
if (Test-Path $readmeSrc) { Copy-Item $readmeSrc (Join-Path $packDir 'README.md') -Force }

# 压缩
$zipPath = $null
if (-not $NoZip) {
    $zipPath = Join-Path $PackRoot "$Label-$stamp.zip"
    Write-Output "压缩中..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Compress-Archive -Path (Join-Path $packDir '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
    $sw.Stop()
    Write-Output "压缩耗时 $([math]::Round($sw.Elapsed.TotalMinutes,1)) 分钟"
    Write-Output "ZIP=$zipPath ($([math]::Round((Get-Item $zipPath).Length/1MB,1)) MB)"
}

# 清单（累积记录每次打包）
$manifest = Join-Path $PackRoot 'packs.csv'
$rec = [pscustomobject]@{
    stamp      = $stamp
    pack_dir   = $packDir
    zip_path   = $zipPath
    zip_mb     = if ($zipPath) { [math]::Round((Get-Item $zipPath).Length/1MB,1) } else { 0 }
    files_ok   = $ok
    files_fail = $fail
    created_at = (Get-Date -Format 'o')
}
if (Test-Path $manifest) { $rec | Export-Csv -Path $manifest -NoTypeInformation -Encoding UTF8 -Append }
else { $rec | Export-Csv -Path $manifest -NoTypeInformation -Encoding UTF8 }

Write-Output "=== 完成 ==="
Write-Output "目录: $packDir"
Write-Output "ZIP : $zipPath"
