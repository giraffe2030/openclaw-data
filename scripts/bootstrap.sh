#!/bin/sh
set -eu

STACK_ROOT="${OPENCLAW_STACK_ROOT:-/opt/openclaw-stack}"
STATE_DIR="/home/node/.openclaw"
CONFIG_TEMPLATE="$STACK_ROOT/config/openclaw.json"
CONFIG_OUTPUT="$STATE_DIR/openclaw.json"
IMAGE_EXT_DIR="/app/extensions"
EXT_STATE_DIR="$STATE_DIR/extensions"
SEED_VERSION="${OPENCLAW_VERSION:-unknown}"

log() {
  printf '[bootstrap] %s\n' "$1"
}

ensure_dir() {
  mkdir -p "$1"
}

sync_extension() {
  dir="$1"
  src="$IMAGE_EXT_DIR/$dir"
  dst="$EXT_STATE_DIR/$dir"
  marker="$dst/.openclaw-seed-version"

  if [ ! -d "$src" ]; then
    echo "[bootstrap] missing image extension: $src" >&2
    exit 1
  fi

  if [ ! -d "$dst" ] || [ ! -f "$marker" ] || [ "$(cat "$marker" 2>/dev/null)" != "$SEED_VERSION" ]; then
    log "sync extension source: $dir@$SEED_VERSION"
    rm -rf "$dst.tmp"
    cp -R "$src" "$dst.tmp"
    rm -rf "$dst"
    mv "$dst.tmp" "$dst"
    printf '%s\n' "$SEED_VERSION" > "$marker"
  else
    log "extension source ok: $dir@$SEED_VERSION"
  fi
}

install_dep() {
  dir="$1"
  dep="$2"

  if [ -z "$dep" ]; then
    log "skip empty dependency"
    return 0
  fi

  if [ -f "$dir/node_modules/$dep/package.json" ]; then
    log "deps ok: $dep"
    return 0
  fi

  log "deps install: $dep"
  (
    cd "$dir"
    npm install --omit=dev --ignore-scripts --no-audit --no-fund "$dep"
  ) || (
    cd "$dir"
    npm install --omit=dev --ignore-scripts --no-audit --no-fund --registry=https://registry.npmjs.org "$dep"
  )
}

log "prepare state directories"
ensure_dir "$STATE_DIR"
ensure_dir "$STATE_DIR/workspace"
ensure_dir "$STATE_DIR/memory/lancedb"
ensure_dir "$EXT_STATE_DIR"

npm config set registry "${NPM_CONFIG_REGISTRY:-https://registry.npmmirror.com}" >/dev/null 2>&1 || true

sync_extension feishu
sync_extension memory-lancedb

install_dep "$EXT_STATE_DIR/feishu" "@larksuiteoapi/node-sdk"
install_dep "$EXT_STATE_DIR/memory-lancedb" "openai"

node <<'NODE'
require.resolve("@larksuiteoapi/node-sdk", { paths: ["/home/node/.openclaw/extensions/feishu"] });
require.resolve("openai", { paths: ["/home/node/.openclaw/extensions/memory-lancedb"] });
console.log("[bootstrap] runtime resolve check passed");
NODE

if [ ! -f "$CONFIG_TEMPLATE" ]; then
  echo "[bootstrap] missing template: $CONFIG_TEMPLATE" >&2
  exit 1
fi

log "render config"
CONFIG_TEMPLATE="$CONFIG_TEMPLATE" CONFIG_OUTPUT="$CONFIG_OUTPUT" node <<'NODE'
const fs = require("fs");

const templatePath = process.env.CONFIG_TEMPLATE;
const outputPath = process.env.CONFIG_OUTPUT;
const template = fs.readFileSync(templatePath, "utf8");
const rendered = template.replace(/\$\{([A-Z0-9_]+)\}/g, (_, name) => {
  const value = process.env[name];
  return value == null ? "" : value;
});

fs.writeFileSync(outputPath, rendered, "utf8");
NODE

chmod 600 "$CONFIG_OUTPUT" || true

log "start gateway"
exec openclaw gateway --bind "${OPENCLAW_GATEWAY_BIND:-lan}" --port "${OPENCLAW_GATEWAY_PORT:-18789}"
