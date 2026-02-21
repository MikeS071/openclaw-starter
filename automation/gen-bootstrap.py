#!/usr/bin/env python3
"""
gen-bootstrap.py — generates BOOTSTRAP.md with current session state.
Runs every 5min via cron. BOOTSTRAP.md is auto-injected into new sessions.
DO NOT delete BOOTSTRAP.md at startup — the cron keeps it fresh.
After reading, kick off: python3 automation/gen-bootstrap.py &
"""

import json
import os
import subprocess
import concurrent.futures
from datetime import datetime, timezone, timedelta

WORKSPACE = os.path.expanduser("~/.openclaw/workspace")
SPRINT_JSON = os.path.join(WORKSPACE, "workflow/sprint.json")
BLOCKERS_JSON = os.path.join(WORKSPACE, "workflow/blockers.json")
BOOTSTRAP_OUT = os.path.join(WORKSPACE, "BOOTSTRAP.md")

# Melbourne DST: AEDT Oct–Apr = UTC+11, AEST Apr–Oct = UTC+10
def melb_offset() -> timedelta:
    month = datetime.now(timezone.utc).month
    return timedelta(hours=11 if month <= 4 or month >= 10 else 10)

def melb_now() -> str:
    offset = melb_offset()
    tz = timezone(offset)
    suffix = "AEDT" if offset.seconds // 3600 == 11 else "AEST"
    return datetime.now(tz).strftime(f"%a %d %b %Y, %I:%M %p {suffix}")

def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def load_sprint() -> dict:
    try:
        with open(SPRINT_JSON) as f:
            return json.load(f)
    except Exception:
        return {}


def active_epics(sprint: dict) -> list[dict]:
    """Extract active/in_progress epics and their pending stories from all sprint arrays."""
    results = []
    for key in ("epics", "pendingEpics", "activeEpics"):
        for epic in sprint.get(key, []):
            if epic.get("status") not in ("active", "in_progress"):
                continue
            items = epic.get("items", epic.get("stories", []))
            pending = [
                i for i in items
                if i.get("status") not in ("done", "delivered", "skipped")
            ]
            results.append({
                "id": epic.get("id", epic.get("epicId", "")),
                "title": epic.get("title", epic.get("name", "")),
                "status": epic.get("status", ""),
                "pending": pending,
            })
    return results


# --- Infra checks (run in parallel) ---

def check_prod() -> tuple[str, str]:
    try:
        r = subprocess.run(
            ["curl", "-sk", "-o", "/dev/null", "-w", "%{http_code}", "https://archonhq.ai"],
            capture_output=True, text=True, timeout=8
        )
        code = r.stdout.strip()
        return code, "✅" if code == "200" else "🚨"
    except Exception:
        return "?", "🚨"

def check_aipipe() -> tuple[str, str]:
    try:
        r = subprocess.run(
            ["curl", "-sk", "-o", "/dev/null", "-w", "%{http_code}", "http://127.0.0.1:8082/healthz"],
            capture_output=True, text=True, timeout=5
        )
        code = r.stdout.strip()
        return code, "✅" if code == "200" else "🚨"
    except Exception:
        return "?", "🚨"

def check_tunnel() -> tuple[int, str]:
    try:
        r = subprocess.run(
            ["pgrep", "-c", "cloudflared"],
            capture_output=True, text=True, timeout=3
        )
        count = int(r.stdout.strip()) if r.stdout.strip().isdigit() else 0
        return count, "✅" if count > 0 else "🚨"
    except Exception:
        return 0, "🚨"


def load_blockers() -> list[str]:
    """Load dynamic blockers from workflow/blockers.json if it exists, else fallback to hardcoded."""
    try:
        with open(BLOCKERS_JSON) as f:
            data = json.load(f)
            return data.get("blockers", [])
    except Exception:
        return [
            "Stripe live keys — Mike manual (Task #20)",
            "CoderAI cai-0 — needs Vercel API token + Supabase management token from Mike",
            "Google Search Console — Mike: submit https://archonhq.ai/sitemap.xml",
            "David Ondrej + @eptwts articles — X auth wall, Mike to paste",
        ]


def render_greeting(melb_ts: str, epics: list[dict], blockers: list[str],
                    prod_sym: str, aipipe_sym: str, tunnel_sym: str) -> list[str]:
    """Pre-render the exact greeting block the agent can paste verbatim."""
    lines = ["## Greeting (paste verbatim — no exec needed)", "```"]
    lines.append(f"Hey Mike 🧭 Context loaded — {melb_ts}")
    lines.append("")
    lines.append(f"**Infra:** Prod {prod_sym} | AiPipe {aipipe_sym} | CF Tunnel {tunnel_sym}")

    if epics:
        lines.append("")
        lines.append("**Active epics:**")
        recommended = None
        for epic in epics:
            pending = epic["pending"]
            next_item = next((i for i in pending if i.get("status") == "in_progress"), None)
            if not next_item:
                next_item = pending[0] if pending else None
            next_str = f"{next_item['id']} ({next_item.get('status','todo')})" if next_item else "no pending stories"
            lines.append(f"- `{epic['id']}`: {epic['title']} — next: {next_str}")
            if recommended is None and next_item:
                recommended = (epic["id"], next_item)

        lines.append("")
        if recommended:
            epic_id, item = recommended
            lines.append(f"**🔥 Recommended next:** `{item['id']}` — {item.get('title', item.get('name', ''))}")
        else:
            lines.append("**🔥 Recommended next:** No unblocked stories — check sprint.json")
    else:
        lines.append("")
        lines.append("**Active epics:** None — all epics complete or check sprint.json")
        lines.append("")
        lines.append("**🔥 Recommended next:** Review sprint.json for next priorities")

    if blockers:
        lines.append("")
        lines.append(f"**Blockers:** {len(blockers)} items")
        for b in blockers:
            lines.append(f"- {b}")

    lines.append("```")
    return lines


def main():
    now_utc = utc_now()
    now_melb = melb_now()

    sprint = load_sprint()
    epics = active_epics(sprint)
    blockers = load_blockers()

    # Run infra checks in parallel
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:
        f_prod = ex.submit(check_prod)
        f_aipipe = ex.submit(check_aipipe)
        f_tunnel = ex.submit(check_tunnel)
        prod_code, prod_sym = f_prod.result()
        aipipe_code, aipipe_sym = f_aipipe.result()
        tunnel_count, tunnel_sym = f_tunnel.result()

    lines = [
        f"# Session State — {now_utc}",
        "",
        "> Auto-generated by gen-bootstrap.py (every 5 min). Do NOT delete — cron keeps it fresh.",
        "> After reading: `python3 ~/.openclaw/workspace/automation/gen-bootstrap.py &`",
        "",
    ]

    # Pre-rendered greeting block
    lines += render_greeting(now_melb, epics, blockers, prod_sym, aipipe_sym, tunnel_sym)
    lines.append("")

    # Active epics (raw data for reference)
    if epics:
        lines.append("## Active Sprint")
        for epic in epics:
            lines.append(f"- **{epic['id']}** ({epic['status']}): {epic['title']}")
            for item in epic["pending"][:6]:
                iid = item.get("id", "")
                title = item.get("title", item.get("name", ""))
                status = item.get("status", "todo")
                lines.append(f"  - {iid} `{status}`: {title}")
        lines.append("")
    else:
        lines += ["## Active Sprint", "- No active epics", ""]

    # Blockers
    lines += ["## Known Blockers"]
    for b in blockers:
        lines.append(f"- {b}")
    lines.append("")

    # Infra snapshot
    lines += [
        "## Infra",
        f"- Prod: {prod_code} ({prod_sym})",
        f"- AiPipe: {aipipe_code} ({aipipe_sym})",
        f"- CF Tunnel: {tunnel_count} proc(s) ({tunnel_sym})",
        "- Serving: CF Tunnel → tls-proxy.js → archonhq :3002",
        "- DB: postgresql://openclaw@/mission_control (migrations 0001–0011 applied)",
        "",
    ]

    # Key decisions
    lines += [
        "## Key Decisions (permanent)",
        "- Article review gate: write → QA → Mike approves → POST /api/insights. Never auto-publish.",
        "- Language: Go for CLIs, Python for automation, TS/Next.js for web",
        "- No direct push to main. All changes: dev → pre-release-check → main.",
        "- AiPipe sub-agent routing: litellm/aipipe-auto → gpt-4o-mini (complexity routing)",
        "- code-reviewer model: sonnet (confirmed, synced in WORKFLOW_AUTO.md)",
        "",
    ]

    lines.append(f"_Generated at {now_utc}_")

    with open(BOOTSTRAP_OUT, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"[gen-bootstrap] Written BOOTSTRAP.md ({len(lines)} lines) at {now_utc} | prod:{prod_code} aipipe:{aipipe_code} tunnel:{tunnel_count}")


if __name__ == "__main__":
    main()
