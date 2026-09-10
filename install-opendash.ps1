<#
.SYNOPSIS
  OpenCodex 请求仪表盘安装脚本
.DESCRIPTION
  自动查找本机 opencodex 的 GUI 静态目录，把选定的主题面板安装进去。
  一体化双主题面板：默认白天版（macOS 26 液态玻璃风格），页面内支持一键无感切换黑夜版（深空极光风格）。
  安装后访问 http://localhost:<Port>/opendash.html
.PARAMETER Theme
  初始默认主题：light（白天液态玻璃，默认）/ dark（黑夜深空极光）。
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
  [ValidateSet("", "light", "dark")][string]$Theme = "light",
  [string]$DistDir = "",
  [ValidateRange(1, 65535)][int]$Port = 10100,
  [switch]$SkipVerify
)
if (-not $Theme) { $Theme = "light" }
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceHtml = Join-Path $scriptDir "opendash.html"
if (-not (Test-Path $sourceHtml)) {
  $sourceHtml = Join-Path $scriptDir "opendash-light.html"
}
if (-not (Test-Path $sourceHtml)) {
  Write-Host "[错误] 未找到 opendash.html，请把本脚本和仪表盘 HTML 放在同一目录。" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "正在安装 OpenCodex 一体化请求用量观测台..." -ForegroundColor Cyan
Write-Host "默认主题：$($Theme)（白天液态玻璃，页面右上角支持随时一键无感切换黑夜版）"
Write-Host "源文件：$sourceHtml"
Write-Host ""

function Test-GuiDist([string]$path) {
  return $path -and (Test-Path $path) -and (Test-Path (Join-Path $path "index.html"))
}

function Get-Sha256([string]$filePath) {
  if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
    return (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
  }
  $hasher = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.IO.File]::ReadAllBytes($filePath)
  return [System.BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace("-", "")
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
$sourceHash = Get-Sha256 $sourceHtml
foreach ($existingTarget in @($targetRoot, $targetSub)) {
  if ((Test-Path -LiteralPath $existingTarget) -and (Get-Sha256 $existingTarget) -ne $sourceHash) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $backupName = if ($existingTarget -eq $targetRoot) { "opendash.html" } else { "index.html" }
    Copy-Item -LiteralPath $existingTarget -Destination (Join-Path $backupDir $backupName)
  }
}
New-Item -ItemType Directory -Force -Path (Split-Path $targetSub) | Out-Null
Copy-Item -LiteralPath $sourceHtml -Destination $targetRoot -Force
Copy-Item -LiteralPath $sourceHtml -Destination $targetSub -Force
Copy-Item -LiteralPath (Join-Path $scriptDir "opendash-light.html") -Destination (Join-Path $found "opendash-light.html") -Force
Copy-Item -LiteralPath (Join-Path $scriptDir "opendash-dark.html") -Destination (Join-Path $found "opendash-dark.html") -Force
foreach ($installedTarget in @($targetRoot, $targetSub)) {
  if ((Get-Sha256 $installedTarget) -ne $sourceHash) {
    throw "安装后文件校验失败：$installedTarget"
  }
}
Write-Host "[OK] 已安装一体化观测台（默认液态玻璃，支持页面内一键切换深空极光）到 $found" -ForegroundColor Green
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
Write-Host "切换主题: 直接在页面右上角点击「☾ 深空极光」或「☼ 液态玻璃」按钮即可无缝秒切。"
Write-Host "提示: 重新安装或升级 opencodex 后，再次运行本脚本即可恢复仪表盘。"
