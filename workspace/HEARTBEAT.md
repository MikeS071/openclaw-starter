# HEARTBEAT.md

## Active checks

- **Gmail:** Run `python3 automation/google-api.py inbox` — alert if urgent/important unread email
- **Calendar:** Run `python3 automation/google-api.py calendar` — alert if event starting within 2 hours
- Stay quiet if nothing urgent. Max 1 proactive message per heartbeat unless critical.
