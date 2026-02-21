# Automation Scripts

## gen-bootstrap.py

Generates `BOOTSTRAP.md` at the workspace root with a compact session state snapshot:
active sprint epics, blockers extracted from today's memory log, and optional prod health check.

BOOTSTRAP.md is auto-injected into every new session (it's a recognised workspace file) and
deleted by the agent once read — so the next cron run regenerates it fresh.

### Setup

1. Edit the `CONFIG` block at the top of the script:
   - `PROD_URL` — your production URL (blank to skip health check)
   - `UTC_OFFSET_HRS` — your local timezone offset
2. Add to crontab (run every 30 minutes):
   ```bash
   */30 * * * * cd /path/to/workspace && python3 automation/gen-bootstrap.py >> /tmp/gen-bootstrap.log 2>&1
   ```
3. Enable the `daily-memory` hook for full memory auto-injection (see `hooks/daily-memory/`):
   ```bash
   openclaw hooks enable daily-memory
   openclaw gateway restart
   ```

### Usage
```bash
python3 automation/gen-bootstrap.py
```

---

## precache-checks.sh
Pre-caches Gmail inbox and Calendar output into an oc-dispatcher cache endpoint.

### Prerequisites
- `curl`
- `python3`
- `jq`
- Workspace contains `automation/google-api.py`
- Dispatcher reachable at `DISPATCHER_URL` (default: `http://127.0.0.1:7070`)

### Usage
```bash
bash automation/precache-checks.sh
```

Optional environment variables:
- `DISPATCHER_URL`
- `OPENCLAW_WORKSPACE`
