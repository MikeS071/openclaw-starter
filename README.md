# openclaw-starter (public)

Public, minimal bootstrap for a **vanilla OpenClaw** instance.

This repo intentionally does **not** ship ArchonHQ persona/workflow templates.
Mission Control provisioning uses a separate **private** starter repo.

## VPS install (Ubuntu 22.04 / 24.04)

```bash
curl -fsSL https://raw.githubusercontent.com/MikeS071/openclaw-starter/main/vps-install.sh | sudo bash
```

What it does:
- creates an `openclaw` user (passwordless sudo)
- installs Node.js 22 + OpenClaw CLI
- runs `openclaw setup --non-interactive`
- installs a systemd user service to keep `openclaw gateway` running

## Local install (optional)

```bash
bash install.sh
```
