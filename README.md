# OpenClaw Portainer Layout

这个目录是给 Portainer Web Editor 方案准备的 3 件套。

## 目录说明

- `docker-compose.yml`
  - 粘贴到 Portainer Stack 里使用。
- `scripts/bootstrap.sh`
  - 放到 Docker 宿主机的 `/opt/openclaw-stack/scripts/bootstrap.sh`。
- `config/openclaw.json5.tmpl`
  - 放到 Docker 宿主机的 `/opt/openclaw-stack/config/openclaw.json5.tmpl`。
- `.env.example`
  - 作为环境变量清单参考，按需填到 Portainer 的 Stack env 里。

## 宿主机目标路径

```text
/opt/openclaw-stack/
  scripts/
    bootstrap.sh
  config/
    openclaw.json5.tmpl
```

## 建议部署步骤

1. 在 Docker 宿主机创建目录：
   - `/opt/openclaw-stack/scripts`
   - `/opt/openclaw-stack/config`
2. 上传：
   - `scripts/bootstrap.sh` -> `/opt/openclaw-stack/scripts/bootstrap.sh`
   - `config/openclaw.json5.tmpl` -> `/opt/openclaw-stack/config/openclaw.json5.tmpl`
3. 给脚本执行权限：
   - `chmod +x /opt/openclaw-stack/scripts/bootstrap.sh`
4. 在 Portainer Stack 中粘贴 `docker-compose.yml`。
5. 在 Portainer 中补齐环境变量。
6. 更新 Stack。

## 后续扩展

- 加 `cron`：优先改 `config/openclaw.json5.tmpl`
- 加新模型：优先改 `config/openclaw.json5.tmpl`
- 加新的启动前逻辑：优先改 `scripts/bootstrap.sh`
- 如果插件依赖越来越多，再考虑把依赖移到自定义镜像的 Dockerfile 里