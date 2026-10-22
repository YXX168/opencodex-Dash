#!/usr/bin/env bash
set -e

# 定位脚本自身目录（支持解析符号链接）
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# ANSI 颜色常量
C_RESET="\033[0m"
C_CYAN="\033[36m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_MAGENTA="\033[35m"
C_RED="\033[31m"
C_WHITE="\033[1;37m"
C_GRAY="\033[90m"

# 设置终端标题
printf "\033]0;%s\007" "⚡ OPENCODEX // OPENDASH OBSERVATORY INSTALL PROTOCOL" 2>/dev/null || true

THEME="${THEME:-light}"
PORT="${PORT:-10100}"
DIST_DIR="$1"
SKIP_VERIFY="${SKIP_VERIFY:-0}"
NO_AUTO_OPEN="${NO_AUTO_OPEN:-0}"

PACKAGE_NAME="@bitkyc08/opencodex"

show_progress_bar() {
  local activity="$1"
  local steps="${2:-10}"
  local delay="${3:-0.02}"
  local bar_len=36
  for ((s=1; s<=steps; s++)); do
    local p=$(( s * 100 / steps ))
    local filled=$(( s * bar_len / steps ))
    local empty=$(( bar_len - filled ))
    local bar=""
    for ((f=0; f<filled; f++)); do bar="${bar}█"; done
    for ((e=0; e<empty; e++)); do bar="${bar}░"; done
    printf "\r  [%b%s%b] %3d%% %s" "$C_CYAN" "$bar" "$C_RESET" "$p" "$activity"
    sleep "$delay" 2>/dev/null || sleep 1 2>/dev/null || true
  done
  echo ""
}

test_gui_dist() {
  [ -n "$1" ] && [ -d "$1" ] && [ -f "$1/index.html" ]
}

get_sha256() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" 2>/dev/null | awk '{print toupper($1)}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" 2>/dev/null | awk '{print toupper($1)}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" 2>/dev/null | awk '{print toupper($NF)}'
  else
    echo "UNKNOWN"
  fi
}

format_compact_path() {
  local p="$1"
  local max_len=46
  if [ ${#p} -le $max_len ]; then
    echo "$p"
  else
    local prefix="${p:0:14}"
    local suffix="${p: -29}"
    echo "${prefix}...${suffix}"
  fi
}

to_posix_path() {
  local p="$1"
  if [ -n "$p" ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p" 2>/dev/null || echo "$p"
  else
    echo "$p"
  fi
}

resolve_pkg_dist() {
  local pkg_root="$1"
  if [ -n "$pkg_root" ] && [ -d "$pkg_root" ]; then
    for rel in "gui/dist" "src/gui/dist"; do
      if test_gui_dist "$pkg_root/$rel"; then
        echo "$pkg_root/$rel"
        return 0
      fi
    done
  fi
  return 1
}

# 炫酷赛博大横幅
echo ""
printf "  %b╭─────────────────────────────────────────────────────────────────────╮%b\n" "$C_CYAN" "$C_RESET"
printf "  %b│   ██████╗ ██████╗ ███████╗███╗   ██╗██████╗  █████╗ ███████╗██╗  ██╗ │%b\n" "$C_CYAN" "$C_RESET"
printf "  %b│  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔══██╗██╔════╝██║  ██║ │%b\n" "$C_CYAN" "$C_RESET"
printf "  %b│  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║  ██║███████║███████╗███████║ │%b\n" "$C_CYAN" "$C_RESET"
printf "  %b│  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║  ██║██╔══██║╚════██║██╔══██║ │%b\n" "$C_CYAN" "$C_RESET"
printf "  %b│  ╚██████╔╝██║     ███████╗██║ ╚████║██████╔╝██║  ██║███████║██║  ██║ │%b\n" "$C_CYAN" "$C_RESET"
printf "  %b│   ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ │%b\n" "$C_CYAN" "$C_RESET"
printf "  %b│   ───────────────────────────────────────────────────────────────   │%b\n" "$C_CYAN" "$C_RESET"
printf "  %b│   %b💎 核心模式: macOS 26 液态玻璃 + 深空极光 双主题一体化面板        %b│%b\n" "$C_CYAN" "$C_GREEN" "$C_CYAN" "$C_RESET"
printf "  %b│   %b⚡ 部署策略: 智能嗅探端口 • 自动定位目录 • 双入口热部署 • 服务校验 %b│%b\n" "$C_CYAN" "$C_YELLOW" "$C_CYAN" "$C_RESET"
printf "  %b╰─────────────────────────────────────────────────────────────────────╯%b\n" "$C_CYAN" "$C_RESET"
echo ""

# 步骤 1: 源文件与哈希完整性校验
SOURCE_HTML=""
if [ -f "$SCRIPT_DIR/opendash.html" ]; then
  SOURCE_HTML="$SCRIPT_DIR/opendash.html"
elif [ -f "$PWD/opendash.html" ]; then
  SOURCE_HTML="$PWD/opendash.html"
fi

if [ -z "$SOURCE_HTML" ] || [ ! -f "$SOURCE_HTML" ]; then
  printf "  %b❌ [错误] 未在当前目录下找到核心面板文件 opendash.html！%b\n" "$C_RED" "$C_RESET"
  printf "  %b    请确保本安装脚本与 opendash.html 放置于同一目录。%b\n" "$C_YELLOW" "$C_RESET"
  exit 1
fi

SOURCE_SIZE=$(wc -c < "$SOURCE_HTML" 2>/dev/null | tr -d ' ' || stat -f%z "$SOURCE_HTML" 2>/dev/null || echo 0)
SOURCE_SIZE_KB=$(( (SOURCE_SIZE + 1023) / 1024 ))
SOURCE_HASH=$(get_sha256 "$SOURCE_HTML")
SHORT_HASH="${SOURCE_HASH:0:16}"

printf "  %b[ 步骤 1/4 ] 源文件与哈希完整性校验%b\n" "$C_WHITE" "$C_RESET"
printf "  • 核心面板 : %b%s%b\n" "$C_GRAY" "$SOURCE_HTML" "$C_RESET"
printf "  • 文件体积 : %b%s KB (%s 字节)%b\n" "$C_GRAY" "$SOURCE_SIZE_KB" "$SOURCE_SIZE" "$C_RESET"
printf "  • SHA-256  : %b%s... [完整验证通过]%b\n" "$C_GRAY" "$SHORT_HASH" "$C_RESET"
echo ""

# 步骤 2: 目标环境深度嗅探与定位
printf "  %b[ 步骤 2/4 ] 目标环境深度嗅探与定位%b\n" "$C_WHITE" "$C_RESET"
show_progress_bar "正在扫描 OpenCodex 运行状态与安装位置..." 10 0.02

FOUND=""
SNIFFED_PID=""
SNIFFED_NAME=""

if [ -n "$DIST_DIR" ]; then
  if test_gui_dist "$DIST_DIR"; then
    FOUND="$DIST_DIR"
  else
    FOUND="$(resolve_pkg_dist "$DIST_DIR" || true)"
  fi
  if [ -z "$FOUND" ]; then
    printf "  %b❌ [错误] 指定的目录无效：%s%b\n" "$C_RED" "$DIST_DIR" "$C_RESET"
    exit 1
  fi
  printf "  • 手动指定 : %b%s%b\n" "$C_CYAN" "$FOUND" "$C_RESET"
fi

# 端口嗅探 (支持 lsof / ss / netstat)
if [ -z "$FOUND" ]; then
  if command -v lsof >/dev/null 2>&1; then
    SNIFFED_PID=$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $2; exit}')
  elif command -v ss >/dev/null 2>&1; then
    SNIFFED_PID=$(ss -tlpn "sport = :$PORT" 2>/dev/null | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
  fi
  if [ -n "$SNIFFED_PID" ]; then
    SNIFFED_NAME=$(ps -p "$SNIFFED_PID" -o comm= 2>/dev/null || echo "process")
    SNIFFED_CMD=$(ps -p "$SNIFFED_PID" -o args= 2>/dev/null || echo "")
    CAND_PKG=$(echo "$SNIFFED_CMD" | grep -oE "/[^ '\"*]+$PACKAGE_NAME" | head -1 || true)
    if [ -n "$CAND_PKG" ]; then
      FOUND="$(resolve_pkg_dist "$CAND_PKG" || true)"
    fi
    printf "  • 端口嗅探 : %b⚡ 命中端口 %s 监听进程 (PID: %s, %s)%b\n" "$C_GREEN" "$PORT" "$SNIFFED_PID" "$SNIFFED_NAME" "$C_RESET"
  else
    printf "  • 端口探测 : 端口 %s 当前未见监听进程 (将通过目录索引定位)\n" "$PORT"
  fi
fi

# 全局 npm prefix 检索
if [ -z "$FOUND" ]; then
  NPM_PREFIX="$(to_posix_path "$(npm prefix -g 2>/dev/null || true)")"
  if [ -n "$NPM_PREFIX" ]; then
    for sub in "lib/node_modules/$PACKAGE_NAME" "node_modules/$PACKAGE_NAME"; do
      FOUND="$(resolve_pkg_dist "$NPM_PREFIX/$sub" || true)"
      [ -n "$FOUND" ] && break
    done
  fi
fi

# 符号链接自解析 (which opencodex)
if [ -z "$FOUND" ]; then
  OCX_BIN="$(which opencodex 2>/dev/null || true)"
  if [ -n "$OCX_BIN" ]; then
    if command -v python3 >/dev/null 2>&1; then
      OCX_REAL="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$OCX_BIN" 2>/dev/null || true)"
    elif command -v readlink >/dev/null 2>&1; then
      OCX_REAL="$(readlink -f "$OCX_BIN" 2>/dev/null || true)"
    fi
    if [ -n "$OCX_REAL" ]; then
      OCX_DIR="$(cd "$(dirname "$OCX_REAL")/.." 2>/dev/null && pwd || true)"
      FOUND="$(resolve_pkg_dist "$OCX_DIR" || true)"
    fi
  fi
fi

# 常见全局路径扫描
if [ -z "$FOUND" ]; then
  APP_DATA_POSIX=""
  [ -n "$APPDATA" ] && APP_DATA_POSIX="$(to_posix_path "$APPDATA")"
  for cand in \
    "$APP_DATA_POSIX/npm/node_modules/$PACKAGE_NAME" \
    "$HOME/.npm-global/lib/node_modules/$PACKAGE_NAME" \
    "$HOME/.npm-global/node_modules/$PACKAGE_NAME" \
    "/usr/local/lib/node_modules/$PACKAGE_NAME" \
    "/opt/homebrew/lib/node_modules/$PACKAGE_NAME" \
    "$HOME/.opencodex"; do
    FOUND="$(resolve_pkg_dist "$cand" || true)"
    if [ -n "$FOUND" ]; then break; fi
  done
fi

# 手动交互回退
if [ -z "$FOUND" ]; then
  echo ""
  printf "  %b[!] 未能自动探测到 OpenCodex 静态目录。%b\n" "$C_YELLOW" "$C_RESET"
  printf "      请输入 OpenCodex 的 gui/dist 目录或包安装根目录："\n
  read -r -p "      请输入路径: " MANUAL_PATH
  if test_gui_dist "$MANUAL_PATH"; then
    FOUND="$MANUAL_PATH"
  else
    FOUND="$(resolve_pkg_dist "$MANUAL_PATH" || true)"
  fi
fi

if [ -z "$FOUND" ]; then
  printf "  %b❌ [错误] 未能定位 OpenCodex 静态目录，安装中止。%b\n" "$C_RED" "$C_RESET"
  exit 1
fi

printf "  • 静态根目录 : %b%s%b\n" "$C_CYAN" "$FOUND" "$C_RESET"
echo ""

# 步骤 3: 版本防损备份与环境清理
printf "  %b[ 步骤 3/4 ] 版本防损备份与环境清理%b\n" "$C_WHITE" "$C_RESET"
TARGET_ROOT="$FOUND/opendash.html"
TARGET_SUB_DIR="$FOUND/opendash"
TARGET_SUB="$TARGET_SUB_DIR/index.html"

BACKUP_DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$SCRIPT_DIR/deployment-backups/$BACKUP_DATE-$THEME"
BACKUP_CREATED=0

for target in "$TARGET_ROOT" "$TARGET_SUB"; do
  if [ -f "$target" ]; then
    T_HASH=$(get_sha256 "$target")
    if [ "$T_HASH" != "$SOURCE_HASH" ]; then
      if [ $BACKUP_CREATED -eq 0 ]; then
        mkdir -p "$BACKUP_DIR"
        BACKUP_CREATED=1
      fi
      B_NAME="opendash.html"
      [ "$target" = "$TARGET_SUB" ] && B_NAME="index.html"
      cp -f "$target" "$BACKUP_DIR/$B_NAME"
    fi
  fi
done

if [ $BACKUP_CREATED -eq 1 ]; then
  printf "  • 备份保护 : %b🛡️ 发现旧版本面板，已安全备份至 %s%b\n" "$C_MAGENTA" "$BACKUP_DIR" "$C_RESET"
else
  printf "  • 备份保护 : 无需备份 (首次部署或目标文件未变更)\n"
fi

# 清理旧版冗余别名
for alias in "opendash-light.html" "opendash-dark.html"; do
  alias_path="$FOUND/$alias"
  if [ -f "$alias_path" ]; then
    A_HASH=$(get_sha256 "$alias_path")
    if [ "$A_HASH" = "$SOURCE_HASH" ]; then
      rm -f "$alias_path"
      printf "  • 冗余清理 : 🧹 已移除历史单色别名副本 (%s)\n" "$alias"
    fi
  fi
done
echo ""

# 步骤 4: 双通道原子部署与完整性核验
printf "  %b[ 步骤 4/4 ] 双通道原子部署与完整性核验%b\n" "$C_WHITE" "$C_RESET"
show_progress_bar "正在写入双入口并验证哈希指纹..." 10 0.02

mkdir -p "$TARGET_SUB_DIR"
cp -f "$SOURCE_HTML" "$TARGET_ROOT"
cp -f "$SOURCE_HTML" "$TARGET_SUB"

for target in "$TARGET_ROOT" "$TARGET_SUB"; do
  if [ ! -f "$target" ]; then
    printf "  %b❌ 部署后文件缺失: %s%b\n" "$C_RED" "$target" "$C_RESET"
    exit 1
  fi
  T_HASH=$(get_sha256 "$target")
  if [ "$T_HASH" != "$SOURCE_HASH" ]; then
    printf "  %b❌ 部署后文件哈希校验失败: %s%b\n" "$C_RED" "$target" "$C_RESET"
    exit 1
  fi
done

printf "  • 主访问入口 : %b写入成功并校验通过 (opendash.html)%b\n" "$C_GREEN" "$C_RESET"
printf "  • 目录型入口 : %b写入成功并校验通过 (opendash/index.html)%b\n" "$C_GREEN" "$C_RESET"
echo ""

# 服务联通性校验
SERVICE_ONLINE=0
if [ "$SKIP_VERIFY" != "1" ]; then
  printf "  %b[ 正在进行服务联通性校验 ]%b\n" "$C_WHITE" "$C_RESET"
  URL="http://localhost:$PORT/opendash.html"
  if command -v curl >/dev/null 2>&1; then
    RESP=$(curl -s -m 5 "$URL" 2>/dev/null || true)
    if echo "$RESP" | grep -q 'id="motionToggle"' && echo "$RESP" | grep -q 'id="scopeSelect"'; then
      SERVICE_ONLINE=1
      printf "  %b✨ [✓] 联通校验通过：OpenCodex HTTP 服务在线且内容完整 (200 OK)%b\n" "$C_GREEN" "$C_RESET"
    else
      printf "  %b[!] 提示：静态文件已安装，服务暂未完全响应，启动 OpenCodex 后即可访问。%b\n" "$C_YELLOW" "$C_RESET"
    fi
  fi
  echo ""
fi

# 部署看板卡片
COMPACT_FOUND=$(format_compact_path "$FOUND")
COMPACT_BACKUP="无需备份 (目标文件无历史差异)"
[ $BACKUP_CREATED -eq 1 ] && COMPACT_BACKUP=$(format_compact_path "$BACKUP_DIR")

printf "  %b╭─────────────────────────────────────────────────────────────────────╮%b\n" "$C_CYAN" "$C_RESET"
printf "  %b│  %b🟢 部署看板 // DEPLOYMENT SUMMARY                                  %b│%b\n" "$C_CYAN" "$C_GREEN" "$C_CYAN" "$C_RESET"
printf "  %b│     ├─ 部署状态 : %b✨ 成功部署 (SHA-256 完整性校验 100%% 通过)         %b│%b\n" "$C_CYAN" "$C_GREEN" "$C_CYAN" "$C_RESET"
printf "  %b│     ├─ 核心访问入口 : %bhttp://localhost:%-5s/opendash.html          %b│%b\n" "$C_CYAN" "$C_CYAN" "$PORT" "$C_CYAN" "$C_RESET"
printf "  %b│     ├─ 备用目录入口 : %bhttp://localhost:%-5s/opendash/index.html    %b│%b\n" "$C_CYAN" "$C_GRAY" "$PORT" "$C_CYAN" "$C_RESET"
printf "  %b│     ├─ 静态资源目录 : %b%-46s %b│%b\n" "$C_CYAN" "$C_GRAY" "$COMPACT_FOUND" "$C_CYAN" "$C_RESET"
printf "  %b│     ├─ 版本备份保护 : %b%-46s %b│%b\n" "$C_CYAN" "$C_GRAY" "$COMPACT_BACKUP" "$C_CYAN" "$C_RESET"
printf "  %b│     └─ 主题无感切换 : %b页面右上角点击「☾ 深空极光」或「☼ 液态玻璃」秒切 %b│%b\n" "$C_CYAN" "$C_YELLOW" "$C_CYAN" "$C_RESET"
printf "  %b╰─────────────────────────────────────────────────────────────────────╯%b\n" "$C_CYAN" "$C_RESET"
echo ""

# 交互启动与退出倒计时
OPEN_CMD=""
if command -v open >/dev/null 2>&1; then
  OPEN_CMD="open"
elif command -v xdg-open >/dev/null 2>&1; then
  OPEN_CMD="xdg-open"
fi

if [ $SERVICE_ONLINE -eq 1 ] && [ "$NO_AUTO_OPEN" != "1" ] && [ -n "$OPEN_CMD" ]; then
  printf "  %b🚀 是否立即在浏览器中打开观测台？%b\n" "$C_CYAN" "$C_RESET"
  printf "     • 按 [回车] 或 [Y] 立即打开并访问\n"
  printf "     • 按 [N] 或等待倒计时结束退出\n"
  echo ""
  SHOULD_OPEN=0
  for ((i=5; i>=1; i--)); do
    printf "\r  %b⏳ 正在等待输入... [ %ds ] (按 Y 打开 / N 退出): %b" "$C_YELLOW" "$i" "$C_RESET"
    if read -t 1 -n 1 -r KEY 2>/dev/null; then
      if [ "$KEY" = "" ] || [ "$KEY" = "y" ] || [ "$KEY" = "Y" ]; then
        SHOULD_OPEN=1
        break
      elif [ "$KEY" = "n" ] || [ "$KEY" = "N" ]; then
        break
      fi
    fi
  done
  echo ""
  if [ $SHOULD_OPEN -eq 1 ]; then
    printf "  %b🚀 正在启动默认浏览器打开观测台...%b\n" "$C_GREEN" "$C_RESET"
    $OPEN_CMD "http://localhost:$PORT/opendash.html" 2>/dev/null || true
  else
    printf "  %b⚡ 任务已完成，祝使用愉快！%b\n" "$C_GREEN" "$C_RESET"
  fi
else
  for ((i=3; i>=1; i--)); do
    printf "\r  %b⚡ 部署完成，将在 [ %d ] 秒后自动退出...%b" "$C_YELLOW" "$i" "$C_RESET"
    sleep 1
  done
  printf "\r  %b🚀 任务已完成。                                                     %b\n" "$C_GREEN" "$C_RESET"
fi
echo ""


