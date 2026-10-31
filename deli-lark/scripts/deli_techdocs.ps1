param(
    [string]$OutRoot = "C:\Users\Administrator\Documents\人工智能研究中心\技术文档",
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$env:PATH = "C:\Program Files\nodejs;C:\Users\Administrator\AppData\Roaming\npm;" + $env:PATH

# ============================================================
# 定向抓取「前后端 / 架构 / 接口 / 接入」类技术文档
# 依据：2026-10-24 用 docs +search 检索出的真实结果
# ============================================================

$docs = @(
    # ---- 前端 / 后端 / 架构 ----
    @{ url='https://www.feishu.cn/docx/AvRvdA3xzojxVqxKHQ0cLzQ7nvc'; cat='前端' ; name='前端技术方案' }
    @{ url='https://nbdeli.feishu.cn/wiki/Tmy4w35uCipCDbkNoltcLKotnFe'; cat='架构' ; name='平台架构与技术方案' }
    @{ url='https://nbdeli.feishu.cn/file/ZF5XbM74xorgLZxAMoIcbzXxnqb'; cat='架构' ; name='小得智能体开发平台-详细架构设计方案' }
    @{ url='https://nbdeli.feishu.cn/file/AhYBbo2o9oRHugxtbhOcWdRaneh'; cat='架构' ; name='小得智能体开发平台-详细架构设计方案-2' }
    @{ url='https://nbdeli.feishu.cn/file/KPYLbOOr3ogcPqxjxKccP88rnzc'; cat='架构' ; name='小得智能体开发平台详细架构设计方案-全文转写' }
    @{ url='https://nbdeli.feishu.cn/file/P0I6b3vQEoEy7hxZcYCcSo6cnoc'; cat='架构' ; name='得力AgentHub-详细架构设计方案' }
    @{ url='https://nbdeli.feishu.cn/file/U2ngbu4rloY0jxxo3nXcCbBXn7c'; cat='架构' ; name='得力AgentHub-总体架构设计方案' }
    @{ url='https://nbdeli.feishu.cn/file/BcJ9bX5EmoXloAxbM5fcpt3hnFg'; cat='架构' ; name='小得智能体快速接入解决方案-v1.0' }
    @{ url='https://nbdeli.feishu.cn/file/K41RbW3NAoLBVKxRIE4cqd19n1c'; cat='架构' ; name='小得智能体快速接入解决方案-v1.0-2' }
    @{ url='https://www.feishu.cn/docx/VeQ6dhWBmozJEoxdXTzcW1NWnQe'; cat='架构' ; name='系统架构图' }
    @{ url='https://www.feishu.cn/docx/doxcn7o8cxJnBvjz9cd59grTEGh'; cat='架构' ; name='组织架构图' }

    # ---- 接口 / API / SDK ----
    @{ url='https://www.feishu.cn/docx/I5K5dH7DUovgFmx5fFOciiJVn2e'; cat='接口'; name='API 参考' }
    @{ url='https://www.feishu.cn/docx/Sh0Fd2BzQooaDfxRFs9c2sktnbg'; cat='接口'; name='API Guide' }
    @{ url='https://nbdeli.feishu.cn/file/BOnbbDAFCo9eEDxHr43cWahQnYd'; cat='接口'; name='AI中台API文档' }
    @{ url='https://www.feishu.cn/docx/LhDcda0xmoLTFRx5hqhcvBCAn4f'; cat='接口'; name='SDK 文档' }
    @{ url='https://www.feishu.cn/docx/VjOddO9APoT9DLxtvcScL4Jdnwg'; cat='接口'; name='SDK Guide' }
    @{ url='https://nbdeli.feishu.cn/docx/Sb78d2St8oaRtpxhF7RcjUsynid'; cat='接口'; name='Joyinside-接口文档流程指引运营平台' }
    @{ url='https://nbdeli.feishu.cn/wiki/TU4lwuuGXiIxomkOGtrcacGBnNe'; cat='接口'; name='SRM接口同步接收异常问题解答' }
    @{ url='https://nbdeli.feishu.cn/docx/U8Tqd55CFovcSGxYKhFclHqrnee'; cat='接口'; name='AI技术中台产品概览' }

    # ---- 接入指南 ----
    @{ url='https://nbdeli.feishu.cn/wiki/IgDrwfOV1iwF7AkBsCdc2HyXn4e'; cat='接入'; name='FDE-前端应用接入得力e+APP' }
    @{ url='https://nbdeli.feishu.cn/wiki/Kf7swxMxMiXPkck7XTAc6MqVnke'; cat='接入'; name='得力Iot平台接入指引' }
    @{ url='https://nbdeli.feishu.cn/file/Gy7obCEDPokpcyxxEM8cbHq6n3f'; cat='接入'; name='JoyInside平台接入指引' }
    @{ url='https://www.feishu.cn/docx/UouodkW65opwuox2y2wcBJSZnnf'; cat='接入'; name='产品接入使用说明' }
    @{ url='https://nbdeli.feishu.cn/docx/B45Cd2rH6owvx7xyrx7cPn2Tn3b'; cat='接入'; name='得力e+功能现状' }
    @{ url='https://nbdeli.feishu.cn/docx/BTkndyratorkrTxZyCYcWFmJnPd'; cat='接入'; name='平台地址资料' }
    @{ url='https://nbdeli.feishu.cn/wiki/FO49w4rNGi1PlMkStZUcgx8znJg'; cat='接入'; name='得力办公开发流程' }

    # ---- 工程规范 ----
    @{ url='https://www.feishu.cn/docx/doxcncQu2CEV3nIm32LFqw5h44f'; cat='规范'; name='技术评审' }
    @{ url='https://www.feishu.cn/docx/doxcnUd0FW7tCwogVi4nz7V2oRg'; cat='规范'; name='测试方案' }
)

Write-Output "DOCS=$($docs.Count)"
if ($DryRun) { $docs | ForEach-Object { Write-Output "  [$($_.cat)] $($_.name)" }; exit 0 }

$ok = 0; $fail = 0
$index = New-Object System.Collections.ArrayList

foreach ($d in $docs) {
    $catDir = Join-Path $OutRoot $d.cat
    New-Item -ItemType Directory -Force -Path $catDir | Out-Null

    # 1) inspect 判断类型
    $ins = & lark-cli drive +inspect --url $d.url 2>$null | Out-String
    $ij = $null
    try { $ij = $ins | ConvertFrom-Json } catch { }
    $title = if ($ij -and $ij.ok -and $ij.data.title) { $ij.data.title } else { $d.name }
    $type  = if ($ij -and $ij.ok) { $ij.data.type } else { '' }

    $rec = [ordered]@{ category=$d.cat; name=$d.name; title=$title; type=$type; url=$d.url; file=''; status='FAIL'; error='' }

    # 2) 按类型取内容
    $saved = $null
    if ($type -eq 'docx' -or $type -eq 'doc') {
        $fr = & lark-cli docs +fetch --doc $d.url --doc-format markdown 2>$null | Out-String
        $fj = $null
        try { $fj = $fr | ConvertFrom-Json } catch { }
        if ($fj -and $fj.ok) {
            $content = $fj.data.document.content
            if ([string]::IsNullOrEmpty($content)) { $content = '<!-- empty -->' }

            # 图片
            $imgTokens = @([regex]::Matches($content, '!\[[^\]]*\]\(https://[^)]*?/file/([A-Za-z0-9]+)\)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
            if ($imgTokens.Count -gt 0) {
                $assetDir = Join-Path $catDir 'assets'
                New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
                $ii = 0
                foreach ($tk in $imgTokens) {
                    $ii++
                    $tmpP = Join-Path $env:TEMP ("td-" + [guid]::NewGuid().ToString('N') + ".png")
                    $null = & lark-cli docs +media-download --token $tk --output $tmpP --overwrite 2>$null | Out-String
                    if (Test-Path $tmpP) {
                        $fn = ($d.name -replace '[\\/:*?"<>|]','_') + "-$ii.png"
                        Move-Item -LiteralPath $tmpP -Destination (Join-Path $assetDir $fn) -Force
                        $content = $content -replace [regex]::Escape("https://feishu.cn/file/$tk"), "assets/$fn"
                        $content = $content -replace [regex]::Escape("/file/$tk"), "assets/$fn"
                    }
                    Remove-Item $tmpP -Force -ErrorAction SilentlyContinue
                }
            }
            $saved = Join-Path $catDir (($d.name -replace '[\\/:*?"<>|]','_') + ".md")
            Set-Content -Path $saved -Value $content -Encoding UTF8
        } else {
            $rec.error = if ($fj -and $fj.error) { "$($fj.error.subtype): $($fj.error.message)" } else { 'fetch failed' }
        }
    }
    elseif ($type -eq 'file') {
        # 从标题推扩展名
        $ext = [System.IO.Path]::GetExtension($title)
        if ([string]::IsNullOrWhiteSpace($ext)) { $ext = [System.IO.Path]::GetExtension($d.name) }
        if ([string]::IsNullOrWhiteSpace($ext)) { $ext = '.bin' }
        $stem = ($d.name -replace '[\\/:*?"<>|]','_')
        $tmpF = Join-Path $env:TEMP ("td-" + [guid]::NewGuid().ToString('N') + $ext)
        $dr = & lark-cli drive +download --url $d.url --output $tmpF --overwrite 2>$null | Out-String
        $dj = $null
        try { $dj = $dr | ConvertFrom-Json } catch { }
        if (Test-Path $tmpF) {
            $saved = Join-Path $catDir ($stem + $ext)
            Move-Item -LiteralPath $tmpF -Destination $saved -Force
        } else {
            $rec.error = if ($dj -and $dj.error) { "$($dj.error.subtype): $($dj.error.message)" } else { 'download failed' }
        }
    }
    elseif ($type -eq 'sheet' -or $type -eq 'slides' -or $type -eq 'bitable') {
        $ext = switch ($type) { 'sheet' {'xlsx'} 'slides' {'pptx'} 'bitable' {'xlsx'} }
        $tmpD = Join-Path $env:TEMP ("td-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $tmpD | Out-Null
        $er = & lark-cli drive +export --url $d.url --file-extension $ext --output-dir $tmpD --overwrite 2>$null | Out-String
        $ej = $null
        try { $ej = $er | ConvertFrom-Json } catch { }
        $pf = Get-ChildItem $tmpD -File | Select-Object -First 1
        if ($pf) {
            $saved = Join-Path $catDir (($d.name -replace '[\\/:*?"<>|]','_') + $ext)
            Move-Item -LiteralPath $pf.FullName -Destination $saved -Force
        } else {
            $rec.error = if ($ej -and $ej.error) { "$($ej.error.subtype): $($ej.error.message)" } else { 'export failed' }
        }
        Remove-Item $tmpD -Recurse -Force -ErrorAction SilentlyContinue
    }
    else { $rec.error = "unsupported type: $type" }

    if ($saved -and (Test-Path $saved)) {
        $rec.file = $saved
        $rec.status = 'OK'
        $ok++
        Write-Output ("OK   [{0}] {1} -> {2} ({3} B)" -f $d.cat, $d.name, (Split-Path $saved -Leaf), (Get-Item $saved).Length)
    } else {
        $fail++
        Write-Output ("FAIL [{0}] {1} :: {2}" -f $d.cat, $d.name, $rec.error)
    }
    $null = $index.Add([pscustomobject]$rec)
    Start-Sleep -Milliseconds 150
}

# 索引
@($index) | Export-Csv -Path (Join-Path $OutRoot 'index.csv') -NoTypeInformation -Encoding UTF8
@($index) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $OutRoot 'index.json') -Encoding UTF8

Write-Output "=== DONE ok=$ok fail=$fail ==="
