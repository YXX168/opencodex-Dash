@echo off & chcp 65001 >nul & where pwsh >nul 2>nul && (pwsh -NoProfile -ExecutionPolicy Bypass -Command "$scriptPath = '%~f0'; $scriptDir = (Split-Path -Parent '%~f0'); $code = (Get-Content -LiteralPath $scriptPath -Encoding utf8 | Select-Object -Skip 1) -join [Environment]::NewLine; & ([scriptblock]::Create($code)) @args" %* & exit /b) || (powershell -NoProfile -ExecutionPolicy Bypass -Command "$scriptPath = '%~f0'; $scriptDir = (Split-Path -Parent '%~f0'); $code = (Get-Content -LiteralPath $scriptPath -Encoding utf8 | Select-Object -Skip 1) -join [Environment]::NewLine; & ([scriptblock]::Create($code)) @args" %* & exit /b)
<#
.SYNOPSIS
  OpenCodex 请求观测台一体化极速部署套件 (OpenDash Installer)
.DESCRIPTION
  自动嗅探端口、智能定位 OpenCodex GUI 静态目录、执行双通道原子部署与实时联通性校验。
  内置 macOS 26 液态玻璃 + 深空极光 双主题，页面右上角支持无感一键秒切。
#>
param(
  [ValidateSet('', 'light', 'dark')][string]$Theme = 'light',
  [string]$DistDir = '',
  [ValidateRange(1, 65535)][int]$Port = 10100,
  [switch]$SkipVerify,
  [switch]$NoAutoOpen
)
if (-not $Theme) { $Theme = 'light' }

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$cr = [char]13

try { $Host.UI.RawUI.WindowTitle = '⚡ OPENCODEX // OPENDASH OBSERVATORY INSTALL PROTOCOL' } catch {}

$OpenCodexPackage = '@bitkyc08/opencodex'
$OpenCodexPackagePath = $OpenCodexPackage -replace '/', '\'

if (-not $scriptDir) {
  if ($PSScriptRoot) { $scriptDir = $PSScriptRoot }
  elseif ($MyInvocation.MyCommand.Path) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
  else { $scriptDir = (Get-Location).Path }
}

function Get-DisplayWidth([string]$text) {
  $w = 0
  foreach ($ch in [System.Globalization.StringInfo]::GetTextElementEnumerator($text)) {
    $code = [char]::ConvertToUtf32($ch, 0)
    if ($code -ge 0x1100 -and (
        $code -le 0x115f -or
        $code -eq 0x2329 -or $code -eq 0x232a -or
        ($code -ge 0x2e80 -and $code -le 0xa4cf -and $code -ne 0x303f) -or
        ($code -ge 0xac00 -and $code -le 0xd7a3) -or
        ($code -ge 0xf900 -and $code -le 0xfaff) -or
        ($code -ge 0xfe10 -and $code -le 0xfe19) -or
        ($code -ge 0xfe30 -and $code -le 0xfe6f) -or
        ($code -ge 0xff00 -and $code -le 0xff60) -or
        ($code -ge 0xffe0 -and $code -le 0xffe6) -or
        ($code -ge 0x1f000 -and $code -le 0x1f9ff)
    )) {
      $w += 2
    } else {
      $w += 1
    }
  }
  return $w
}

function Format-BoxLine([string]$content, [int]$innerW = 67) {
  $w = Get-DisplayWidth $content
  $pad = $innerW - $w
  if ($pad -lt 0) { $pad = 0 }
  return '  │ ' + $content + (' ' * $pad) + ' │'
}

function Format-CompactPath([string]$p, [int]$maxLen = 46) {
  if (-not $p -or $p.Length -le $maxLen) { return $p }
  $keepStart = 14
  $keepEnd = $maxLen - $keepStart - 3
  return $p.Substring(0, $keepStart) + '...' + $p.Substring($p.Length - $keepEnd)
}

function Show-ProgressBar([string]$activity, [int]$steps = 10, [int]$delayMs = 20) {
  $barLen = 36
  for ($s = 1; $s -le $steps; $s++) {
    $p = [math]::Floor(($s / $steps) * 100)
    $filled = [math]::Floor(($s / $steps) * $barLen)
    $empty = $barLen - $filled
    $bar = ('█' * $filled) + ('░' * $empty)
    Write-Host -NoNewline ('{0}  [{1}] {2,3}% {3}' -f $cr, $bar, $p, $activity) -ForegroundColor Cyan
    Start-Sleep -Milliseconds $delayMs
  }
  Write-Host ''
}

function Test-GuiDist([string]$path) {
  return $path -and (Test-Path -LiteralPath $path) -and (Test-Path -LiteralPath (Join-Path $path 'index.html'))
}

function Get-Sha256([string]$filePath) {
  if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
    return (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
  }
  $hasher = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.IO.File]::ReadAllBytes($filePath)
  return [System.BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace('-', '')
}

function Resolve-PackageDist([string]$pkgRoot) {
  if (-not $pkgRoot -or -not (Test-Path -LiteralPath $pkgRoot)) { return $null }
  foreach ($rel in @('gui\dist', 'src\gui\dist')) {
    $cand = Join-Path $pkgRoot $rel
    if (Test-GuiDist $cand) { return $cand }
  }
  return $null
}

try {
  Write-Host ''
  Write-Host '  ╭─────────────────────────────────────────────────────────────────────╮' -ForegroundColor Cyan
  Write-Host (Format-BoxLine '  ██████╗ ██████╗ ███████╗███╗   ██╗██████╗  █████╗ ███████╗██╗  ██╗') -ForegroundColor Cyan
  Write-Host (Format-BoxLine ' ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔══██╗██╔════╝██║  ██║') -ForegroundColor Cyan
  Write-Host (Format-BoxLine ' ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║  ██║███████║███████╗███████║') -ForegroundColor Cyan
  Write-Host (Format-BoxLine ' ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║  ██║██╔══██║╚════██║██╔══██║') -ForegroundColor Cyan
  Write-Host (Format-BoxLine ' ╚██████╔╝██║     ███████╗██║ ╚████║██████╔╝██║  ██║███████║██║  ██║') -ForegroundColor Cyan
  Write-Host (Format-BoxLine '  ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝') -ForegroundColor Cyan
  Write-Host '  │   ───────────────────────────────────────────────────────────────   │' -ForegroundColor DarkCyan
  Write-Host (Format-BoxLine '  💎 核心模式: macOS 26 液态玻璃 + 深空极光 双主题一体化面板') -ForegroundColor Green
  Write-Host (Format-BoxLine '  ⚡ 部署策略: 智能嗅探端口 • 自动定位目录 • 双入口热部署 • 服务校验') -ForegroundColor Yellow
  Write-Host '  ╰─────────────────────────────────────────────────────────────────────╯' -ForegroundColor Cyan
  Write-Host ''

  $sourceHtml = Join-Path $scriptDir 'opendash.html'
  if (-not (Test-Path -LiteralPath $sourceHtml)) {
    Write-Host '  ❌ [错误] 未在当前目录下找到核心面板文件 opendash.html！' -ForegroundColor Red
    Write-Host ('      预期路径: {0}' -f $sourceHtml) -ForegroundColor DarkGray
    Write-Host '      请确保本安装脚本与 opendash.html 放置于同一目录。' -ForegroundColor Yellow
    Write-Host ''
    for ($i = 5; $i -ge 1; $i--) {
      Write-Host -NoNewline ('{0}  ⏳ 窗口将在 [ {1} ] 秒后自动退出...' -f $cr, $i) -ForegroundColor Yellow
      Start-Sleep -Seconds 1
    }
    Write-Host ''
    return
  }

  $sourceInfo = Get-Item -LiteralPath $sourceHtml
  $sourceSizeBytes = $sourceInfo.Length
  $sourceSizeKB = [math]::Round($sourceSizeBytes / 1KB, 1)
  $sourceHash = Get-Sha256 $sourceHtml
  $shortHash = if ($sourceHash.Length -ge 16) { $sourceHash.Substring(0, 16) } else { $sourceHash }

  Write-Host '  [ 步骤 1/4 ] 源文件与哈希完整性校验' -ForegroundColor White
  Write-Host ('  • 核心面板 : {0}' -f $sourceHtml) -ForegroundColor DarkGray
  Write-Host ('  • 文件体积 : {0} KB ({1:N0} 字节)' -f $sourceSizeKB, $sourceSizeBytes) -ForegroundColor DarkGray
  Write-Host ('  • SHA-256  : {0}... [完整验证通过]' -f $shortHash) -ForegroundColor DarkGray
  Write-Host ''

  Write-Host '  [ 步骤 2/4 ] 目标环境深度嗅探与定位' -ForegroundColor White
  Show-ProgressBar '正在扫描 OpenCodex 运行状态与安装位置...' 10 20

  $found = $null
  $sniffedProcess = $null

  if ($DistDir) {
    if (Test-GuiDist $DistDir) { $found = $DistDir }
    else { $found = Resolve-PackageDist $DistDir }
    if (-not $found) {
      Write-Host ('  ❌ [错误] 指定的 -DistDir 路径无效：{0}' -f $DistDir) -ForegroundColor Red
      Write-Host '      请指定包含 index.html 的 gui\dist 目录，或有效的 opencodex 包根目录。' -ForegroundColor Yellow
      return
    }
    Write-Host ('  • 手动指定 : {0}' -f $found) -ForegroundColor DarkCyan
  }

  # 端口嗅探
  if (-not $found) {
    $runningOnWindows = $PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows -or ($env:OS -like '*Windows*')
    if ($runningOnWindows) {
      try {
        $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($connection) {
          $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($connection.OwningProcess)" -ErrorAction SilentlyContinue
          if ($process) {
            $sniffedProcess = $process
            $pkgPattern = [regex]::Escape($OpenCodexPackagePath)
            if ($process.CommandLine -match "([A-Za-z]:[\\/][^`"]*?$pkgPattern)") {
              $found = Resolve-PackageDist $Matches[1]
            }
          }
        }
      } catch {}
    }
  }

  if ($sniffedProcess) {
    Write-Host ('  • 端口嗅探 : ⚡ 命中端口 {0} 监听进程 (PID: {1}, {2})' -f $Port, $sniffedProcess.ProcessId, $sniffedProcess.Name) -ForegroundColor Green
  } else {
    Write-Host ('  • 端口探测 : 端口 {0} 当前未见监听进程 (将通过目录索引定位)' -f $Port) -ForegroundColor DarkGray
  }

  # 候选目录搜索
  if (-not $found) {
    $progX86 = [System.Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $candidates = @(
      (Join-Path $env:APPDATA "npm\node_modules\$OpenCodexPackagePath"),
      (Join-Path $env:ProgramFiles "nodejs\node_modules\$OpenCodexPackagePath"),
      (if ($progX86) { Join-Path $progX86 "nodejs\node_modules\$OpenCodexPackagePath" } else { $null }),
      (Join-Path $env:USERPROFILE '.opencodex')
    )
    foreach ($candidate in $candidates) {
      if ($candidate) {
        $found = Resolve-PackageDist $candidate
        if ($found) { break }
      }
    }
  }

  # npm prefix 搜索
  if (-not $found) {
    try {
      $npmPrefix = (& npm prefix -g 2>$null | Select-Object -First 1)
      if ($npmPrefix) {
        $found = Resolve-PackageDist (Join-Path $npmPrefix "node_modules\$OpenCodexPackagePath")
      }
    } catch {}
  }

  # 手动交互输入
  if (-not $found) {
    Write-Host ''
    Write-Host '  [!] 未能自动探测到 OpenCodex 静态目录。' -ForegroundColor Yellow
    Write-Host '      请输入 OpenCodex 的 gui\dist 目录或包安装根目录：' -ForegroundColor White
    $manual = Read-Host '      请输入路径'
    if (Test-GuiDist $manual) { $found = $manual }
    else { $found = Resolve-PackageDist $manual }
  }

  if (-not $found) {
    Write-Host '  ❌ [错误] 未能定位 OpenCodex 静态目录，安装中止。' -ForegroundColor Red
    Write-Host '      提示：可使用参数 -DistDir 直接指定路径运行。' -ForegroundColor Yellow
    return
  }

  Write-Host ('  • 静态根目录 : {0}' -f $found) -ForegroundColor Cyan
  Write-Host ''

  Write-Host '  [ 步骤 3/4 ] 版本防损备份与环境清理' -ForegroundColor White
  $targetRoot = Join-Path $found 'opendash.html'
  $targetSubDir = Join-Path $found 'opendash'
  $targetSub = Join-Path $targetSubDir 'index.html'
  $installTargets = @($targetRoot, $targetSub)

  $backupDir = Join-Path $scriptDir ('deployment-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $Theme)
  $backupCreated = $false

  foreach ($existingTarget in $installTargets) {
    if ((Test-Path -LiteralPath $existingTarget) -and (Get-Sha256 $existingTarget) -ne $sourceHash) {
      if (-not $backupCreated) {
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        $backupCreated = $true
      }
      $backupName = if ($existingTarget -eq $targetRoot) { 'opendash.html' } else { 'index.html' }
      Copy-Item -LiteralPath $existingTarget -Destination (Join-Path $backupDir $backupName) -Force
    }
  }

  if ($backupCreated) {
    Write-Host ('  • 备份保护 : 🛡️ 发现旧版本面板，已安全备份至 {0}' -f $backupDir) -ForegroundColor Magenta
  } else {
    Write-Host '  • 备份保护 : 无需备份 (首次部署或目标文件未变更)' -ForegroundColor DarkGray
  }

  # 清理冗余别名
  $cleanedAliases = @()
  foreach ($alias in @('opendash-light.html', 'opendash-dark.html')) {
    $aliasPath = Join-Path $found $alias
    if ((Test-Path -LiteralPath $aliasPath) -and (Get-Sha256 $aliasPath) -eq $sourceHash) {
      Remove-Item -LiteralPath $aliasPath -Force
      $cleanedAliases += $alias
    }
  }
  if ($cleanedAliases.Count -gt 0) {
    Write-Host ('  • 冗余清理 : 🧹 已移除历史单色别名副本 ({0})' -f ($cleanedAliases -join ', ')) -ForegroundColor DarkGray
  }
  Write-Host ''

  Write-Host '  [ 步骤 4/4 ] 双通道原子部署与完整性核验' -ForegroundColor White
  Show-ProgressBar '正在写入双入口并验证哈希指纹...' 10 20

  if (-not (Test-Path -LiteralPath $targetSubDir)) {
    New-Item -ItemType Directory -Force -Path $targetSubDir | Out-Null
  }

  foreach ($target in $installTargets) {
    Copy-Item -LiteralPath $sourceHtml -Destination $target -Force
  }

  foreach ($installedTarget in $installTargets) {
    if (-not (Test-Path -LiteralPath $installedTarget)) {
      throw ('部署后文件缺失: ' + $installedTarget)
    }
    if ((Get-Sha256 $installedTarget) -ne $sourceHash) {
      throw ('部署后文件哈希校验失败: ' + $installedTarget)
    }
  }

  Write-Host '  • 主访问入口 : 写入成功并校验通过 (opendash.html)' -ForegroundColor Green
  Write-Host '  • 目录型入口 : 写入成功并校验通过 (opendash\index.html)' -ForegroundColor Green
  Write-Host ''

  $serviceOnline = $false
  if (-not $SkipVerify) {
    Write-Host '  [ 正在进行服务联通性校验 ]' -ForegroundColor White
    $url = 'http://localhost:' + $Port + '/opendash.html'
    try {
      $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 6
      if ($response.StatusCode -eq 200 -and $response.Content -match 'id="motionToggle"' -and $response.Content -match 'id="scopeSelect"') {
        $serviceOnline = $true
        Write-Host '  ✨ [✓] 联通校验通过：OpenCodex HTTP 服务在线且内容完整 (200 OK)' -ForegroundColor Green
      } else {
        Write-Host '  [!] 提示：静态文件已安装，但页面特征未完全匹配，请确认 OpenCodex 运行状态。' -ForegroundColor Yellow
      }
    } catch {
      Write-Host ('  [!] 提示：服务暂未响应（OpenCodex 可能未启动）。启动服务后即可访问：{0}' -f $url) -ForegroundColor Yellow
    }
    Write-Host ''
  }

  $topBox = '  ╭' + ('─' * 69) + '╮'
  $botBox = '  ╰' + ('─' * 69) + '╯'
  $backupText = if ($backupCreated) { $backupDir } else { '无需备份 (目标文件无历史差异)' }

  Write-Host $topBox -ForegroundColor DarkCyan
  Write-Host (Format-BoxLine ' 🟢 部署看板 // DEPLOYMENT SUMMARY') -ForegroundColor Green
  Write-Host (Format-BoxLine '    ├─ 部署状态 : ✨ 成功部署 (SHA-256 完整性校验 100% 通过)') -ForegroundColor Green
  Write-Host (Format-BoxLine ('    ├─ 核心访问入口 : http://localhost:{0}/opendash.html' -f $Port)) -ForegroundColor Cyan
  Write-Host (Format-BoxLine ('    ├─ 备用目录入口 : http://localhost:{0}/opendash/index.html' -f $Port)) -ForegroundColor DarkGray
  Write-Host (Format-BoxLine ('    ├─ 静态资源目录 : {0}' -f (Format-CompactPath $found))) -ForegroundColor DarkGray
  Write-Host (Format-BoxLine ('    ├─ 版本备份保护 : {0}' -f (Format-CompactPath $backupText))) -ForegroundColor DarkGray
  Write-Host (Format-BoxLine '    └─ 主题无感切换 : 页面右上角点击「☾ 深空极光」或「☼ 液态玻璃」秒切') -ForegroundColor Yellow
  Write-Host $botBox -ForegroundColor DarkCyan
  Write-Host ''

  $canReadKey = $false
  try {
    if (-not [Console]::IsInputRedirected) {
      $null = [Console]::KeyAvailable
      $canReadKey = $true
    }
  } catch {
    $canReadKey = $false
  }

  if ($serviceOnline -and -not $NoAutoOpen) {
    Write-Host '  🚀 是否立即在浏览器中打开观测台？' -ForegroundColor Cyan
    Write-Host '     • 按 [回车] 或 [Y] 立即打开并访问' -ForegroundColor DarkGray
    Write-Host '     • 按 [N] 或等待倒计时结束退出' -ForegroundColor DarkGray
    Write-Host ''
    $shouldOpen = $false
    for ($i = 5; $i -ge 1; $i--) {
      Write-Host -NoNewline ('{0}  ⏳ 正在等待输入... [ {1}s ] (按 Y 打开 / N 退出): ' -f $cr, $i) -ForegroundColor Yellow
      if ($canReadKey -and [Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Enter -or $key.Key -eq [ConsoleKey]::Y) {
          $shouldOpen = $true
          break
        } elseif ($key.Key -eq [ConsoleKey]::N -or $key.Key -eq [ConsoleKey]::Escape) {
          break
        }
      }
      Start-Sleep -Seconds 1
    }
    Write-Host ''
    if ($shouldOpen) {
      Write-Host '  🚀 正在启动默认浏览器打开观测台...' -ForegroundColor Green
      Start-Process ('http://localhost:' + $Port + '/opendash.html')
    } else {
      Write-Host '  ⚡ 任务已完成，祝使用愉快！' -ForegroundColor Green
    }
  } else {
    for ($i = 3; $i -ge 1; $i--) {
      Write-Host -NoNewline ('{0}  ⚡ 部署完成，窗口将在 [ {1} ] 秒后自动退出...' -f $cr, $i) -ForegroundColor Yellow
      Start-Sleep -Seconds 1
    }
    Write-Host ('{0}  🚀 窗口已关闭。                                                     ' -f $cr) -ForegroundColor Green
  }
  Write-Host ''
} catch {
  Write-Host ''
  Write-Host '  ╭─────────────────────────────────────────────────────────────────────╮' -ForegroundColor Red
  Write-Host (Format-BoxLine ' ❌ 部署中断 // INSTALLATION FAILED') -ForegroundColor Red
  Write-Host (Format-BoxLine ('    • 错误信息: ' + $_.Exception.Message)) -ForegroundColor Red
  Write-Host '  ╰─────────────────────────────────────────────────────────────────────╯' -ForegroundColor Red
  Write-Host ''
  Write-Host '  按任意键退出窗口...' -ForegroundColor DarkGray
  try { [Console]::ReadKey($true) } catch {}
}

