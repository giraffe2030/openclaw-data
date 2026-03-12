# OpenClaw Host Download Commands

宿主机执行这些命令即可：

## 1. 创建目录

```bash
mkdir -p /root/docker-apps/openclaw/scripts
mkdir -p /root/docker-apps/openclaw/config
mkdir -p /root/docker-apps/openclaw/workspace/shared/skills
mkdir -p /root/docker-apps/openclaw/workspace/shared/extensions
mkdir -p /root/docker-apps/openclaw/workspace/instance1/config
mkdir -p /root/docker-apps/openclaw/workspace/instance1/data
mkdir -p /root/docker-apps/openclaw/workspace/instance2/config
mkdir -p /root/docker-apps/openclaw/workspace/instance2/data
```

## 2. 下载宿主机挂载文件

```bash
curl -fsSL https://raw.githubusercontent.com/giraffe2030/openclaw-data/main/scripts/bootstrap.sh -o /root/docker-apps/openclaw/scripts/bootstrap.sh
curl -fsSL https://raw.githubusercontent.com/giraffe2030/openclaw-data/main/config/openclaw.json -o /root/docker-apps/openclaw/config/openclaw.json
chmod +x /root/docker-apps/openclaw/scripts/bootstrap.sh
```

## 3. 下载 Portainer 环境变量模板

```bash
curl -fsSL https://raw.githubusercontent.com/giraffe2030/openclaw-data/main/PORTAINER-ENV.txt -o /root/docker-apps/openclaw/PORTAINER-ENV.txt
```

## 4. Portainer 里使用

- `docker-compose.yml`：直接使用仓库里的 [docker-compose.yml](/Users/loki/IdeaProjects/openclaw-data/docker-compose.yml)
- `Environment`：把 `/root/docker-apps/openclaw/PORTAINER-ENV.txt` 的内容填进去，再替换成你的真实值
