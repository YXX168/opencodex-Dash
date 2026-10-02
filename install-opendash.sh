#!/usr/bin/env bash
set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

SOURCE_HTML=""
if [ -f "$SCRIPT_DIR/opendash.html" ]; then
  SOURCE_HTML="$SCRIPT_DIR/opendash.html"
elif [ -f "$PWD/opendash.html" ]; then
  SOURCE_HTML="$PWD/opendash.html"
elif [ -f "$HOME/Documents/ChatGPT/管理/opencodex-Dash/opendash.html" ]; then
  SOURCE_HTML="$HOME/Documents/ChatGPT/管理/opencodex-Dash/opendash.html"
fi

if [ -z "$SOURCE_HTML" ] || [ ! -f "$SOURCE_HTML" ]; then
  echo "[错误] 未找到 opendash.html，请确保脚本与 opendash.html 在同一目录，或指定正确的项目路径。" >&2
  exit 1
fi

PORT="${PORT:-10100}"
DIST_DIR="$1"

test_gui_dist() {
  [ -n "$1" ] && [ -d "$1" ] && [ -f "$1/index.html" ]
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

FOUND=""

if [ -n "$DIST_DIR" ]; then
  if test_gui_dist "$DIST_DIR"; then
    FOUND="$DIST_DIR"
  else
    FOUND="$(resolve_pkg_dist "$DIST_DIR" || true)"
  fi
fi

if [ -z "$FOUND" ]; then
  NPM_PREFIX="$(npm prefix -g 2>/dev/null || true)"
  if [ -n "$NPM_PREFIX" ]; then
    FOUND="$(resolve_pkg_dist "$NPM_PREFIX/lib/node_modules/@bitkyc08/opencodex" || true)"
  fi
fi

if [ -z "$FOUND" ]; then
  OCX_BIN="$(which opencodex 2>/dev/null || true)"
  if [ -n "$OCX_BIN" ]; then
    OCX_REAL="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$OCX_BIN" 2>/dev/null || true)"
    if [ -n "$OCX_REAL" ]; then
      OCX_DIR="$(cd "$(dirname "$OCX_REAL")/.." && pwd)"
      FOUND="$(resolve_pkg_dist "$OCX_DIR" || true)"
    fi
  fi
fi

if [ -z "$FOUND" ]; then
  for cand in \
    "$HOME/.npm-global/lib/node_modules/@bitkyc08/opencodex" \
    "/usr/local/lib/node_modules/@bitkyc08/opencodex" \
    "/opt/homebrew/lib/node_modules/@bitkyc08/opencodex" \
    "$HOME/.opencodex"; do
    FOUND="$(resolve_pkg_dist "$cand" || true)"
    if [ -n "$FOUND" ]; then break; fi
  done
fi

if [ -z "$FOUND" ]; then
  echo "[错误] 未能定位 opencodex 静态目录，安装中止。请指定包含 index.html 的 gui/dist 路径。" >&2
  exit 1
fi

echo "正在安装 OpenCodex 一体化请求用量观测台..."
echo "目标目录: $FOUND"

TARGET_ROOT="$FOUND/opendash.html"
TARGET_SUB="$FOUND/opendash/index.html"
TARGET_LIGHT="$FOUND/opendash-light.html"
TARGET_DARK="$FOUND/opendash-dark.html"

mkdir -p "$FOUND/opendash"
cp -f "$SOURCE_HTML" "$TARGET_ROOT"
cp -f "$SOURCE_HTML" "$TARGET_SUB"
cp -f "$SOURCE_HTML" "$TARGET_LIGHT"
cp -f "$SOURCE_HTML" "$TARGET_DARK"

echo "[OK] 已成功安装一体化观测台（默认液态玻璃，支持页面内一键切换深空极光）"
echo "访问地址: http://localhost:$PORT/opendash.html"
echo "目录入口: http://localhost:$PORT/opendash/index.html"

