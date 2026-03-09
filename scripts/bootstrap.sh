#!/bin/sh
set -eu

STACK_ROOT="${OPENCLAW_STACK_ROOT:-/opt/openclaw-stack}"
STATE_DIR="/home/node/.openclaw"
CONFIG_TEMPLATE="$STACK_ROOT/config/openclaw.json5.tmpl"
CONFIG_OUTPUT="$STATE_DIR/openclaw.json"

log() {
  printf '[bootstrap] %s\n' "$1"
}

ensure_dir() {
  mkdir -p "$1"
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
ensure_dir "$STATE_DIR/extensions"

rm -rf "$STATE_DIR/extensions/feishu" "$STATE_DIR/extensions/memory-lancedb" || true

npm config set registry "${NPM_CONFIG_REGISTRY:-https://registry.npmmirror.com}" >/dev/null 2>&1 || true

install_dep /app/extensions/feishu "@larksuiteoapi/node-sdk"
install_dep /app/extensions/memory-lancedb "openai"

node <<'NODE'
require.resolve("@larksuiteoapi/node-sdk", { paths: ["/app/extensions/feishu"] });
require.resolve("openai", { paths: ["/app/extensions/memory-lancedb"] });
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