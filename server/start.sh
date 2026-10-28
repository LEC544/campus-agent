#!/usr/bin/env bash
set -euo pipefail

# 无论从哪个目录调用，都在 server 目录启动。
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if [[ ! -f .venv/Scripts/python.exe && ! -x .venv/bin/python ]]; then
  if command -v python >/dev/null 2>&1; then
    python -m venv .venv
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m venv .venv
  else
    printf "未找到 Python，请先安装 Python 3.11 或更新版本。\n" >&2
    exit 1
  fi
fi

if [[ -f .venv/Scripts/python.exe ]]; then
  venv_python="./.venv/Scripts/python.exe"
else
  venv_python="./.venv/bin/python"
fi

"$venv_python" -m pip install --disable-pip-version-check -r requirements.txt

if [[ ! -f .env ]]; then
  cp .env.example .env
  printf "已创建 server/.env，默认使用 mock 模式。\n"
fi

printf "启动 Campus Agent Server，按 Ctrl+C 停止。\n"
exec "$venv_python" -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000 "$@"
