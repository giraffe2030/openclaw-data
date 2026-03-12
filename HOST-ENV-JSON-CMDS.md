# OpenClaw Host Download Commands

宿主机执行这些命令即可：

先执行这一行：

```bash
BASE=/root/docker-apps/openclaw
```

## 1. 创建目录

```bash
mkdir -p "$BASE/scripts"
mkdir -p "$BASE/config"
mkdir -p "$BASE/workspace/shared/skills"
mkdir -p "$BASE/workspace/shared/extensions"
mkdir -p "$BASE/workspace/instance1/config"
mkdir -p "$BASE/workspace/instance1/data"
mkdir -p "$BASE/workspace/instance2/config"
mkdir -p "$BASE/workspace/instance2/data"
```

## 2. 下载宿主机挂载文件

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/giraffe2030/openclaw-data@main/scripts/bootstrap.sh -o "$BASE/scripts/bootstrap.sh"
curl -fsSL https://cdn.jsdelivr.net/gh/giraffe2030/openclaw-data@main/config/openclaw.json -o "$BASE/config/openclaw.json"
chmod +x "$BASE/scripts/bootstrap.sh"
```

## 3. 下载 Portainer 环境变量模板

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/giraffe2030/openclaw-data@main/PORTAINER-ENV.txt -o "$BASE/PORTAINER-ENV.txt"
```

## 4. Portainer 里使用

- `docker-compose.yml`：直接使用仓库里的 [docker-compose.yml](/Users/loki/IdeaProjects/openclaw-data/docker-compose.yml)
- `Environment`：把 `/root/docker-apps/openclaw/PORTAINER-ENV.txt` 的内容填进去，再替换成你的真实值
- 更新后如果仍报插件安装错误或插件重复告警，先重新下载最新 `bootstrap.sh`，并同步更新 Stack 里的 `docker-compose.yml`，再重新部署
