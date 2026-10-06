# 把 src/ 打包成可刷入的模块 zip
#
# 用法: pwsh -File build.ps1 [-Out 输出文件名]

param([string]$Out = "tristate-xiaobu-v1.0.0.zip")

$ErrorActionPreference = "Stop"
$root    = $PSScriptRoot
$src     = Join-Path $root 'src'
$outPath = Join-Path $root $Out

if (-not (Test-Path $src)) { throw "找不到源目录: $src" }
if (Test-Path $outPath) { Remove-Item $outPath -Force }

# 1) 统一成 LF 换行 + 无 BOM(Android 的 sh 不喜欢 CRLF 和 BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$count = 0
Get-ChildItem -Path $src -Recurse -File | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName)
    $text = $text -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($_.FullName, $text, $utf8NoBom)
    $count++
}
Write-Host "已规范化 $count 个文件的换行与编码"

# 2) 打包: 模块文件必须位于 zip 根目录(不能再套一层文件夹)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $src, $outPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false)

# 3) 自检
$zip = [System.IO.Compression.ZipFile]::OpenRead($outPath)
try {
    $names = $zip.Entries | ForEach-Object { $_.FullName }
    foreach ($must in @('module.prop', 'customize.sh', 'service.sh',
                        'META-INF/com/google/android/update-binary',
                        'META-INF/com/google/android/updater-script',
                        'bin/daemon.sh', 'bin/trigger.sh', 'bin/cli.sh', 'config.conf',
                        'webroot/index.html', 'webroot/assets/app.js', 'webroot/assets/style.css')) {
        if ($names -notcontains $must) { throw "zip 里缺少必需文件: $must" }
    }
    Write-Host "自检通过, 共 $($names.Count) 个条目"
}
finally { $zip.Dispose() }

$size = [math]::Round((Get-Item $outPath).Length / 1KB, 1)
Write-Host "输出: $outPath ($size KB)"
