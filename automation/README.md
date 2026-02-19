# Automation Scripts

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
