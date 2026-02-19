# openclaw-starter

> One command to clone a productive AI assistant on a fresh VPS.

## Quick Start (Fresh VPS)

```bash
curl -fsSL https://raw.githubusercontent.com/MikeS071/openclaw-starter/main/vps-install.sh | sudo bash
```

Installs OpenClaw + security hardening + your AI persona + workflow templates. ~5 minutes on Ubuntu 22.04/24.04.

## What You Get

- OpenClaw installed and running as a systemd user service
- UFW firewall + Fail2ban + Tailscale VPN
- Structured AI persona (`SOUL.md`, `USER.md`, `AGENTS.md`, `IDENTITY.md`)
- Agentic engineering workflow (pre-flight specs, agent quality contract, readiness checks)
- Gmail/Calendar pre-cache automation scaffolding
- Weekly self-improvement cron-friendly templates

## Already Have OpenClaw? (Persona Only)

```bash
git clone https://github.com/MikeS071/openclaw-starter.git
cd openclaw-starter
bash install.sh
```

## Post-Install

```bash
cd ~/openclaw-starter
make status    # check service health
make logs      # view gateway logs
make backup    # backup config
make harden    # restrict SSH to Tailscale only
make persona   # re-run persona setup wizard
```

## Local Testing (Docker)

```bash
cd docker
make install
```

## Structure

```text
.
├── Makefile
├── README.md
├── install.sh
├── vps-install.sh
├── server/
│   └── Makefile
├── docker/
│   ├── Dockerfile
│   └── Makefile
├── automation/
│   ├── README.md
│   └── precache-checks.sh
└── workspace/
    ├── AGENTS.md
    ├── HEARTBEAT.md
    ├── IDENTITY.md
    ├── MEMORY.md
    ├── SOUL.md
    ├── TOOLS.md
    ├── USER.md
    └── workflow/
        ├── agent-quality-contract.md
        ├── preflight-spec-template.md
        └── readiness-check.sh
```

## Philosophy

This project is designed for practical, repeatable agent setup rather than one-off prompt hacking. You install a secure runtime, then layer in a structured persona and explicit working agreements so the assistant behaves consistently across sessions. The focus is less on "magic" and more on dependable operation under real production conditions.

The workflow is inspired by BMAD-style agentic engineering: define intent before execution, use quality contracts to constrain behavior, and run readiness checks before shipping changes. That gives you a system that is easier to audit, easier to iterate, and less likely to drift as your assistant grows in capability.
