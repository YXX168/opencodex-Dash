<#
.SYNOPSIS
  OpenCodex 请求仪表盘安装脚本
.DESCRIPTION
  自动查找本机 opencodex 的 GUI 静态目录，把选定的主题面板安装进去。
  白天版（Day）：macOS 26 液态玻璃风格的浅色界面（opendash-light.html）
  黑夜版（Night）：深空极光风格的深色界面（opendash-dark.html）
  安装后访问 http://localhost:<Port>/opendash.html
.PARAMETER Theme
  要安装的主题：light（白天）/ dark（黑夜）。不指定时进入交互选择。
.PARAMETER DistDir
  可选：直接指定 opencodex 的 gui\dist 目录（或包根目录），跳过自动查找。
.PARAMETER Port
  服务端口，默认 10100，仅用于安装后的访问验证。
.PARAMETER SkipVerify
  跳过安装后的访问验证。
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1
  # 交互选择主题
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1 -Theme dark
  # 直接安装黑夜版
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1 -Theme light -DistDir "D:\opencodex\gui\dist"
#>
param(
  [ValidateSet("", "light", "dark")][string]$Theme = "",
  [string]$DistDir = "",
  [ValidateRange(1, 65535)][int]$Port = 10100,
  [switch]$SkipVerify
)
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$themes = @(
  @{ Key = "light"; File = "opendash-light.html"; Label = "白天版 · 液态玻璃（macOS 26 Liquid Glass 风格浅色界面）" },
  @{ Key = "dark";  File = "opendash-dark.html";  Label = "黑夜版 · 深空极光（深色星海 + 霓虹曲线界面）" }
)
foreach ($t in $themes) {
  $p = Join-Path $scriptDir $t.File
  if (-not (Test-Path $p)) {
    Write-Host "[错误] 未找到 $p ，请把本脚本和两个主题 HTML 放在同一目录。" -ForegroundColor Red
    exit 1
  }
}

# ── 主题选择：参数优先，否则交互 ──────────────────
if (-not $Theme) {
  Write-Host ""
  Write-Host "请选择要安装的主题：" -ForegroundColor Cyan
  Write-Host "  [1] $($themes[0].Label)"
  Write-Host "  [2] $($themes[1].Label)"
  Write-Host ""
  do {
    $choice = Read-Host "输入 1 或 2（直接回车默认 1）"
    if ($choice -eq "") { $choice = "1" }
  } while ($choice -ne "1" -and $choice -ne "2")
  $Theme = if ($choice -eq "1") { "light" } else { "dark" }
}
$selected = $themes | Where-Object { $_.Key -eq $Theme }
$sourceHtml = Join-Path $scriptDir $selected.File
Write-Host ""
Write-Host "已选择：$($selected.Label)" -ForegroundColor Cyan
Write-Host "源文件：$sourceHtml"
Write-Host ""

function Test-GuiDist([string]$path) {
  return $path -and (Test-Path $path) -and (Test-Path (Join-Path $path "index.html"))
}

function Resolve-PackageDist([string]$pkgRoot) {
  if (-not $pkgRoot -or -not (Test-Path $pkgRoot)) { return $null }
  foreach ($rel in @("gui\dist", "src\gui\dist")) {
    $cand = Join-Path $pkgRoot $rel
    if (Test-GuiDist $cand) { return $cand }
  }
  return $null
}

$found = $null

if ($DistDir) {
  if (Test-GuiDist $DistDir) { $found = $DistDir }
  else { $found = Resolve-PackageDist $DistDir }
  if (-not $found) {
    Write-Host "[错误] -DistDir 指定的路径无效：$DistDir" -ForegroundColor Red
    Write-Host "请指定包含 index.html 的 gui\dist 目录，或有效的 opencodex 包根目录。" -ForegroundColor Yellow
    exit 1
  }
}

if (-not $found) {
  $runningOnWindows = $PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows
  if ($runningOnWindows) {
    try {
      $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($connection) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($connection.OwningProcess)" -ErrorAction SilentlyContinue
        if ($process -and $process.CommandLine -match '([A-Za-z]:[\\/][^"]*?@bitkyc08[\\/]opencodex)') {
          $found = Resolve-PackageDist $Matches[1]
        }
      }
    } catch { }
  }
}

if (-not $found) {
  $candidates = @(
    (Join-Path $env:APPDATA "npm\node_modules\@bitkyc08\opencodex"),
    (Join-Path $env:ProgramFiles "nodejs\node_modules\@bitkyc08\opencodex"),
    (Join-Path ${env:ProgramFiles(x86)} "nodejs\node_modules\@bitkyc08\opencodex"),
    (Join-Path $env:USERPROFILE ".opencodex")
  )
  foreach ($candidate in $candidates) {
    $found = Resolve-PackageDist $candidate
    if ($found) { break }
  }
}

if (-not $found) {
  try {
    $npmPrefix = (& npm prefix -g 2>$null | Select-Object -First 1)
    if ($npmPrefix) {
      $found = Resolve-PackageDist (Join-Path $npmPrefix "node_modules\@bitkyc08\opencodex")
    }
  } catch { }
}

if (-not $found) {
  Write-Host "未自动找到 opencodex 安装目录。请手动输入 opencodex 的 gui\dist 目录（或包根目录）：" -ForegroundColor Yellow
  $manual = Read-Host "路径"
  if (Test-GuiDist $manual) { $found = $manual }
  else { $found = Resolve-PackageDist $manual }
}

if (-not $found) {
  Write-Host "[错误] 未能定位 opencodex 静态目录，安装中止。可使用 -DistDir 参数直接指定。" -ForegroundColor Red
  exit 1
}

$targetRoot = Join-Path $found "opendash.html"
$targetSub = Join-Path $found "opendash\index.html"
$backupDir = Join-Path $scriptDir ("deployment-backups\" + (Get-Date -Format "yyyyMMdd-HHmmss-fff") + "-" + $Theme)
$sourceHash = (Get-FileHash -LiteralPath $sourceHtml -Algorithm SHA256).Hash
foreach ($existingTarget in @($targetRoot, $targetSub)) {
  if ((Test-Path -LiteralPath $existingTarget) -and (Get-FileHash -LiteralPath $existingTarget -Algorithm SHA256).Hash -ne $sourceHash) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $backupName = if ($existingTarget -eq $targetRoot) { "opendash.html" } else { "index.html" }
    Copy-Item -LiteralPath $existingTarget -Destination (Join-Path $backupDir $backupName)
  }
}
New-Item -ItemType Directory -Force -Path (Split-Path $targetSub) | Out-Null
Copy-Item -LiteralPath $sourceHtml -Destination $targetRoot -Force
Copy-Item -LiteralPath $sourceHtml -Destination $targetSub -Force
foreach ($installedTarget in @($targetRoot, $targetSub)) {
  if ((Get-FileHash -LiteralPath $installedTarget -Algorithm SHA256).Hash -ne $sourceHash) {
    throw "安装后文件校验失败：$installedTarget"
  }
}
Write-Host "[OK] 已安装（$($selected.Label)）到 $found" -ForegroundColor Green
if (Test-Path -LiteralPath $backupDir) { Write-Host "旧面板备份：$backupDir" -ForegroundColor DarkGray }

if (-not $SkipVerify) {
  try {
    $url = "http://localhost:$Port/opendash.html"
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 8
    if ($response.StatusCode -eq 200 -and $response.Content -match 'id="motionToggle"' -and $response.Content -match 'id="scopeSelect"') {
      Write-Host "[OK] 安装验证通过：$url" -ForegroundColor Green
    } else {
      Write-Host "[提示] 文件已安装，但页面内容校验未通过，请确认 opencodex 服务已启动。" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "[提示] 文件已安装，但服务暂不可访问（可能尚未启动）。启动服务后访问 $url" -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "访问地址: http://localhost:$Port/opendash.html" -ForegroundColor Cyan
Write-Host "切换主题: 重新运行本脚本选择另一主题即可，随时可换。"
Write-Host "提示: 重新安装或升级 opencodex 后，再次运行本脚本即可恢复仪表盘。"
