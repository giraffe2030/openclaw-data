# OpenClaw Host Prepare

宿主机只需要执行这一条命令：

```bash
/bin/sh -lc 'REPO_DIR=/opt/openclaw-data; if [ -d "$REPO_DIR/.git" ]; then git -C "$REPO_DIR" pull --ff-only; else git clone https://github.com/giraffe2030/openclaw-data.git "$REPO_DIR"; fi && sh "$REPO_DIR/scripts/prepare-host.sh"'
```

这条命令会：

1. 拉取或更新仓库到 `/opt/openclaw-data`
2. 创建宿主机目录 `/root/docker-apps/openclaw/...`
3. 写入宿主机挂载文件：
   `scripts/bootstrap.sh -> /root/docker-apps/openclaw/scripts/bootstrap.sh`
   `config/openclaw.json -> /root/docker-apps/openclaw/config/openclaw.json`

Portainer 里还需要做一件事：

把 [PORTAINER-ENV.txt](/Users/loki/IdeaProjects/openclaw-data/PORTAINER-ENV.txt) 或本地私有的 `PORTAINER-ENV.local.txt` 内容填到 Stack `Environment`。
