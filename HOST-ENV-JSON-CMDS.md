# OpenClaw Portainer 宿主机写文件命令

`docker-compose.yml` 走 Portainer Stack 部署时，只需要准备宿主机挂载文件。

环境变量不要再写 `.env.base` / `envFile/*.env`，统一填到 Portainer 的 Stack `Environment`。

当前方案已经更新为：

- 插件目录持久化到宿主机 `/root/docker-apps/openclaw/workspace/shared/extensions`
- 容器启动时会按 `OPENCLAW_VERSION` 自动同步镜像内插件源码到宿主机
- 插件依赖安装在宿主机扩展目录里，不跟随容器层丢失
- `docker-compose.yml` 不再使用 `env_file`

变量清单见：

`PORTAINER-ENV.txt`

如果本地已经有真实密钥，使用：

`PORTAINER-ENV.local.txt`

其中 `PORTAINER-ENV.local.txt` 已加入 `.gitignore`，不会提交到 GitHub。

部署顺序：

1. 先执行下面命令，把宿主机文件写好
2. 再把 `PORTAINER-ENV.local.txt` 或 `PORTAINER-ENV.txt` 内容填到 Portainer Stack `Environment`
3. 最后用当前的 `docker-compose.yml` 重新部署 Stack

## 1. 准备目录

```bash
set -euo pipefail

mkdir -p /root/docker-apps/openclaw/scripts
mkdir -p /root/docker-apps/openclaw/config
mkdir -p /root/docker-apps/openclaw/workspace/shared/skills
mkdir -p /root/docker-apps/openclaw/workspace/shared/extensions
mkdir -p /root/docker-apps/openclaw/workspace/instance1/config
mkdir -p /root/docker-apps/openclaw/workspace/instance1/data
mkdir -p /root/docker-apps/openclaw/workspace/instance2/config
mkdir -p /root/docker-apps/openclaw/workspace/instance2/data
```

## 2. 写 `bootstrap.sh`

```bash
cat > /root/docker-apps/openclaw/scripts/bootstrap.sh <<'EOF'
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
EOF

chmod +x /root/docker-apps/openclaw/scripts/bootstrap.sh
```

## 3. 写 `openclaw.json` 第 1 段

```bash
cat > /root/docker-apps/openclaw/config/openclaw.json <<'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.3.8"
  },
  "gateway": {
    "mode": "local",
    "bind": "${OPENCLAW_GATEWAY_BIND:-lan}",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}"
    },
    "controlUi": {
      "enabled": true,
      "allowedOrigins": [
        "https://openclaw.claweasy.net",
        "https://openclaw-new.claweasy.net",
        "http://192.168.100.135:18789",
        "http://192.168.100.135:18790"
      ]
    }
  },
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace",
      "model": {
        "primary": "aliyun/MiniMax-M2.5"
      },
      "models": {
        "tencent/glm-5": { "alias": "GLM-5" },
        "tencent/kimi-k2.5": { "alias": "Kimi-K2.5" },
        "tencent/minimax-m2.5": { "alias": "MiniMax-M2.5" },
        "aliyun/qwen3.5-plus": { "alias": "Qwen 3.5 Plus" },
        "aliyun/kimi-k2.5": { "alias": "Kimi-K2.5" },
        "aliyun/MiniMax-M2.5": { "alias": "MiniMax-M2.5" }
      },
      "memorySearch": {
        "enabled": ${MEMORY_SEARCH_ENABLED:-false}
      },
      "memoryEmbeddingDimensions": ${MEMORY_EMBEDDING_DIMENSIONS:-1024}
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "aliyun": {
        "api": "openai-completions",
        "baseUrl": "${ALIYUN_BASE_URL}",
        "apiKey": "${ALIYUN_API_KEY}",
        "models": [
          { "id": "qwen3.5-plus", "name": "Qwen 3.5 Plus", "input": ["text"], "reasoning": true },
          { "id": "kimi-k2.5", "name": "Kimi-K2.5", "input": ["text"], "reasoning": false },
          { "id": "MiniMax-M2.5", "name": "MiniMax-M2.5", "input": ["text"], "reasoning": false }
        ]
      },
      "tencent": {
        "api": "openai-completions",
        "baseUrl": "${TENCENT_BASE_URL}",
        "apiKey": "${TENCENT_API_KEY}",
        "models": [
EOF
```

## 4. 写 `openclaw.json` 第 2 段

```bash
cat >> /root/docker-apps/openclaw/config/openclaw.json <<'EOF'
          {
            "id": "minimax-m2.5",
            "name": "MiniMax-M2.5",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 196608,
            "maxTokens": 32768
          },
          {
            "id": "kimi-k2.5",
            "name": "Kimi-K2.5",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 262144,
            "maxTokens": 32768
          },
          {
            "id": "glm-5",
            "name": "GLM-5",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 202752,
            "maxTokens": 16384
          }
        ]
      }
    }
  },
  "env": {
    "GITHUB_TOKEN": "${GITHUB_TOKEN}",
    "CLAWHUB_TOKEN": "${CLAWHUB_TOKEN}"
  },
  "plugins": {
    "enabled": true,
    "allow": ["feishu", "memory-lancedb"],
    "slots": { "memory": "memory-lancedb" },
    "entries": {
      "feishu": { "enabled": true },
      "memory-lancedb": {
        "enabled": true,
        "config": {
          "autoCapture": true,
          "autoRecall": true,
          "dbPath": "~/.openclaw/memory/lancedb",
          "embedding": {
EOF
```

## 5. 写 `openclaw.json` 第 3 段

```bash
cat >> /root/docker-apps/openclaw/config/openclaw.json <<'EOF'
            "apiKey": "${MEMORY_EMBEDDING_API_KEY}",
            "model": "${MEMORY_EMBEDDING_MODEL:-text-embedding-v4}",
            "baseUrl": "${MEMORY_EMBEDDING_BASE_URL}",
            "dimensions": ${MEMORY_EMBEDDING_DIMENSIONS:-1024}
          }
        }
      }
    }
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "connectionMode": "websocket",
      "domain": "${FEISHU_DOMAIN:-feishu}",
      "dmPolicy": "pairing",
      "groupPolicy": "open",
      "streaming": true,
      "blockStreaming": true,
      "accounts": {
        "default": {
          "appId": "${FEISHU_APP_ID}",
          "appSecret": "${FEISHU_APP_SECRET}",
          "botName": "${FEISHU_BOT_NAME:-OpenClaw}"
        }
      }
    }
  }
}
EOF
```

## 6. Portainer `Environment` 变量清单

见 `PORTAINER-ENV.txt`
