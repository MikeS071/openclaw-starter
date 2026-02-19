.PHONY: status logs restart backup update harden persona

status:
	@echo "=== OpenClaw Gateway ===" && systemctl --user status openclaw || echo "Service not found"
	@echo "=== Gateway Health ===" && curl -sf http://127.0.0.1:18789/health 2>/dev/null || echo "Gateway not responding"

logs:
	journalctl --user -u openclaw -n 50 --no-pager

restart:
	systemctl --user restart openclaw

backup:
	tar -czf ~/openclaw-backup-$(shell date +%Y%m%d).tar.gz ~/.openclaw/ --exclude='~/.openclaw/cache'
	@echo "Backup saved to ~/openclaw-backup-$(shell date +%Y%m%d).tar.gz"

update:
	npm update -g openclaw && systemctl --user restart openclaw

harden:
	@echo "Restricting SSH to Tailscale interface only..."
	sudo ufw delete allow 22/tcp 2>/dev/null || true
	sudo ufw allow in on tailscale0 to any port 22
	sudo ufw reload
	@echo "SSH now Tailscale-only. Ensure tailscale is up before disconnecting."

persona:
	cd /home/openclaw/openclaw-starter && bash install.sh
