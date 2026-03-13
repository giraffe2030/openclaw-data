#!/bin/sh
set -eu

STACK_ROOT="${OPENCLAW_STACK_ROOT:-/opt/openclaw-stack}"
STATE_DIR="/home/node/.openclaw"
CONFIG_TEMPLATE="${OPENCLAW_CONFIG_TEMPLATE:-$STACK_ROOT/config/openclaw.json}"
CONFIG_OUTPUT="$STATE_DIR/openclaw.json"
IMAGE_EXT_DIR="/app/extensions"
EXT_CACHE_DIR="${OPENCLAW_EXT_CACHE_DIR:-/opt/openclaw/extensions-cache}"
SEED_VERSION="${OPENCLAW_VERSION:-unknown}"
EXT_LOCK_DIR="$EXT_CACHE_DIR/.bootstrap.lock"
CONFIG_FORCE_RENDER="${OPENCLAW_CONFIG_FORCE_RENDER:-false}"

log() {
  printf '[bootstrap] %s\n' "$1"
}

ensure_dir() {
  mkdir -p "$1"
}

is_true() {
  case "$1" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

lock_extensions() {
  while ! mkdir "$EXT_LOCK_DIR" 2>/dev/null; do
    log "wait extension lock"
    sleep 1
  done
}

unlock_extensions() {
  rmdir "$EXT_LOCK_DIR" 2>/dev/null || true
}

sync_extension() {
  dir="$1"
  src="$IMAGE_EXT_DIR/$dir"
  dst="$EXT_CACHE_DIR/$dir"
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

link_extension_deps() {
  dir="$1"
  src="$IMAGE_EXT_DIR/$dir"
  dst="$EXT_CACHE_DIR/$dir"

  rm -rf "$src/node_modules"
  ln -s "$dst/node_modules" "$src/node_modules"
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

  for registry in \
    "${NPM_CONFIG_REGISTRY:-https://registry.npmjs.org}" \
    "https://registry.npmjs.org" \
    "https://registry.npmmirror.com"
  do
    log "deps install: $dep via $registry"
    if (
      cd "$dir"
      npm install --omit=dev --ignore-scripts --no-audit --no-fund --registry="$registry" "$dep"
    ); then
      return 0
    fi
  done

  echo "[bootstrap] failed dependency install: $dep" >&2
  exit 1
}

log "prepare state directories"
ensure_dir "$STATE_DIR"
ensure_dir "$STATE_DIR/workspace"
ensure_dir "$STATE_DIR/memory/lancedb"
ensure_dir "$EXT_CACHE_DIR"

npm config set registry "${NPM_CONFIG_REGISTRY:-https://registry.npmmirror.com}" >/dev/null 2>&1 || true

trap unlock_extensions EXIT INT TERM
lock_extensions

sync_extension feishu
sync_extension memory-lancedb

install_dep "$EXT_CACHE_DIR/feishu" "@larksuiteoapi/node-sdk"
install_dep "$EXT_CACHE_DIR/memory-lancedb" "openai"

link_extension_deps feishu
link_extension_deps memory-lancedb

node <<'NODE'
require.resolve("@larksuiteoapi/node-sdk", { paths: ["/app/extensions/feishu"] });
require.resolve("openai", { paths: ["/app/extensions/memory-lancedb"] });
console.log("[bootstrap] runtime resolve check passed");
NODE

unlock_extensions
trap - EXIT INT TERM

if [ ! -f "$CONFIG_TEMPLATE" ]; then
  echo "[bootstrap] missing template: $CONFIG_TEMPLATE" >&2
  exit 1
fi

if [ -f "$CONFIG_OUTPUT" ] && ! is_true "$CONFIG_FORCE_RENDER"; then
  log "keep existing config: $CONFIG_OUTPUT"
else
  if is_true "$CONFIG_FORCE_RENDER"; then
    log "force render config"
  else
    log "seed config"
  fi
  CONFIG_TEMPLATE="$CONFIG_TEMPLATE" CONFIG_OUTPUT="$CONFIG_OUTPUT" node <<'NODE'
const fs = require("fs");

const templatePath = process.env.CONFIG_TEMPLATE;
const outputPath = process.env.CONFIG_OUTPUT;
const template = fs.readFileSync(templatePath, "utf8");
const rendered = template.replace(/\$\{([A-Z0-9_]+)(:-([^}]*))?\}/g, (_, name, _withDefault, defaultValue) => {
  const value = process.env[name];
  if (value == null || value === "") {
    return defaultValue == null ? "" : defaultValue;
  }
  return value;
});

fs.writeFileSync(outputPath, rendered, "utf8");
NODE

  chmod 600 "$CONFIG_OUTPUT" || true
fi

log "start gateway"
exec openclaw gateway --bind "${OPENCLAW_GATEWAY_BIND:-lan}" --port "${OPENCLAW_GATEWAY_PORT:-18789}"
