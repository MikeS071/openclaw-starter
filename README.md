# openclaw-starter

`openclaw-starter` is a practical starter kit for building a structured OpenClaw setup fast: persona defaults, session behavior, memory scaffolding, workflow templates, and automation helpers. Clone it, run one script, and get a clean, opinionated baseline you can adapt to your own style.

## Philosophy

This repo is built around two ideas:
- **Structured AI persona:** clear identity, autonomy boundaries, safety posture, and communication style.
- **Agentic engineering workflow:** repeatable templates and checks that reduce drift and increase reliability.

## Quick start

```bash
git clone https://github.com/MikeS071/openclaw-starter.git
cd openclaw-starter
bash install.sh
```

## What you get after install

- Persona templates (`SOUL.md`, `IDENTITY.md`) with sane defaults
- Session operating rules (`AGENTS.md`) and heartbeat checks (`HEARTBEAT.md`)
- Human profile scaffolding (`USER.md`) and long-term memory template (`MEMORY.md`)
- Workflow templates (`workflow/preflight-spec-template.md`, `workflow/agent-quality-contract.md`)
- Generic readiness script (`workflow/readiness-check.sh`)
- Automation helper for Gmail/Calendar pre-cache (`automation/precache-checks.sh`)
- Interactive installer to personalize files and optionally configure API secrets

## Structure overview

```text
.
├── install.sh
├── workspace/
│   ├── AGENTS.md
│   ├── HEARTBEAT.md
│   ├── IDENTITY.md
│   ├── MEMORY.md
│   ├── SOUL.md
│   ├── TOOLS.md
│   ├── USER.md
│   └── workflow/
│       ├── agent-quality-contract.md
│       ├── preflight-spec-template.md
│       └── readiness-check.sh
├── automation/
│   ├── precache-checks.sh
│   └── README.md
└── .gitignore
```

## Contributing

PRs are welcome. Keep changes practical, generic, and documented. If you add templates/scripts, include short usage notes in the relevant README.
