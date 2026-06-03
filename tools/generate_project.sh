#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: ./tools/generate_project.sh [--open]

Generates the full Tuist Xcode workspace without a target query.
Use --open to open the workspace after generation.
USAGE
}

open_flag="--no-open"

if [ "$#" -gt 1 ]; then
  usage
  exit 2
fi

case "${1-}" in
  "")
    ;;
  "--open")
    open_flag="--open"
    ;;
  "-h"|"--help")
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

if ! command -v tuist >/dev/null 2>&1; then
  cat >&2 <<'ERROR'
tuist is not installed.

Install it with:
  brew tap tuist/tuist
  brew install --formula tuist
ERROR
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

tuist generate run "$open_flag"
