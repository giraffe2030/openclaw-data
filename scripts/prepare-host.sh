#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

HOST_ROOT="/root/docker-apps/openclaw"

mkdir -p "$HOST_ROOT/scripts"
mkdir -p "$HOST_ROOT/config"
mkdir -p "$HOST_ROOT/workspace/shared/skills"
mkdir -p "$HOST_ROOT/workspace/shared/extensions"
mkdir -p "$HOST_ROOT/workspace/instance1/config"
mkdir -p "$HOST_ROOT/workspace/instance1/data"
mkdir -p "$HOST_ROOT/workspace/instance2/config"
mkdir -p "$HOST_ROOT/workspace/instance2/data"

cp "$REPO_ROOT/scripts/bootstrap.sh" "$HOST_ROOT/scripts/bootstrap.sh"
cp "$REPO_ROOT/config/openclaw.json" "$HOST_ROOT/config/openclaw.json"
chmod +x "$HOST_ROOT/scripts/bootstrap.sh"

printf 'Prepared host files under %s\n' "$HOST_ROOT"
printf 'Next: fill Portainer Stack Environment from PORTAINER-ENV.txt or PORTAINER-ENV.local.txt\n'
