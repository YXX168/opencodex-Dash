<#
.SYNOPSIS
  OpenCodex 请求仪表盘安装脚本
.DESCRIPTION
  自动查找本机 opencodex 的 GUI 静态目录，把同目录下的 opendash.html 安装进去。
  安装后访问 http://localhost:<Port>/opendash.html
.PARAMETER DistDir
  可选：直接指定 opencodex 的 gui\dist 目录（或包根目录），跳过自动查找。
.PARAMETER Port
  服务端口，默认 10100，仅用于安装后的访问验证。
.PARAMETER SkipVerify
  跳过安装后的访问验证。
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1 -DistDir "D:\opencodex\gui\dist"
#>
param(
  [string]$DistDir = "",
  [int]$Port = 10100,
  [switch]$SkipVerify
)
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceHtml = Join-Path $scriptDir "opendash.html"
if (-not (Test-Path $sourceHtml)) {
  Write-Host "[错误] 未找到 $sourceHtml ，请把本脚本和 opendash.html 放在同一目录。" -ForegroundColor Red
  exit 1
}

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
  $isWindows = $PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows
  if ($isWindows) {
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
New-Item -ItemType Directory -Force -Path (Split-Path $targetSub) | Out-Null
Copy-Item -LiteralPath $sourceHtml -Destination $targetRoot -Force
Copy-Item -LiteralPath $sourceHtml -Destination $targetSub -Force
Write-Host "[OK] 已安装到 $found" -ForegroundColor Green

if (-not $SkipVerify) {
  try {
    $url = "http://localhost:$Port/opendash.html"
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 8
    if ($response.StatusCode -eq 200 -and $response.Content -match 'id="modelBars"') {
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
Write-Host "提示: 重新安装或升级 opencodex 后，再次运行本脚本即可恢复仪表盘。"
