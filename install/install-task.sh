#!/usr/bin/env bash

set -Eeuo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}PASS: $*${NC}"; }
fail() { echo -e "${RED}FAIL: $*${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN: $*${NC}"; }

echo -e "${BLUE}Starting go-task installation...${NC}"

if command -v task >/dev/null 2>&1; then
    pass "go-task is already installed: $(task --version)"
elif [[ "$(uname -s)" == Linux ]] && command -v apt-get >/dev/null 2>&1; then
    echo -e "${BLUE}Installing go-task for the current user...${NC}"
    command -v curl >/dev/null 2>&1 || {
        echo "curl is required to install go-task." >&2
        exit 1
    }
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b "$INSTALL_DIR"
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        warn "Add $INSTALL_DIR to PATH before running task."
    fi
elif command -v brew >/dev/null 2>&1; then
    echo -e "${GREEN}Found Homebrew. Installing go-task via brew...${NC}"
    brew install go-task
else
    echo -e "${BLUE}Homebrew not found. Using the official install script...${NC}"
    command -v curl >/dev/null 2>&1 || {
        echo "curl is required to install go-task." >&2
        exit 1
    }
    INSTALL_DIR="/usr/local/bin"
    echo "This may require your password to install to $INSTALL_DIR"
    sudo sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b "$INSTALL_DIR"
fi

TASK_BIN="$(command -v task 2>/dev/null || true)"
if [[ -z "$TASK_BIN" && -x "${INSTALL_DIR:-}/task" ]]; then
    TASK_BIN="${INSTALL_DIR}/task"
fi
[[ -n "$TASK_BIN" && -x "$TASK_BIN" ]] || fail "go-task executable was not installed"
TASK_VERSION="$($TASK_BIN --version 2>/dev/null)" || fail "go-task could not report its version"
pass "go-task executable works: $TASK_VERSION"

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$REPO_ROOT/Taskfile.yml" ]]; then
    "$TASK_BIN" --dir "$REPO_ROOT" --list >/dev/null \
        || fail "Taskfile.yml could not be parsed"
    pass "repository Taskfile parses successfully"
fi

echo -e "${GREEN}go-task installation and validation complete.${NC}"
