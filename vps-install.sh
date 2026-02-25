#!/bin/bash
set -euo pipefail

# openclaw-starter (public) — vanilla OpenClaw VPS bootstrap
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/MikeS071/openclaw-starter/main/vps-install.sh | sudo bash

OPENCLAW_USER="openclaw"

log() {
  echo "[openclaw-starter] $*"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must run as root. Use: curl ... | sudo bash"
    exit 1
  fi
}

check_ubuntu_version() {
  if [[ ! -f /etc/os-release ]]; then
    echo "Cannot detect OS (missing /etc/os-release)."
    exit 1
  fi

  # shellcheck source=/dev/null
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "This installer supports Ubuntu only (detected: ${ID:-unknown})."
    exit 1
  fi

  case "${VERSION_ID:-}" in
    "22.04"|"24.04") ;;
    *)
      echo "Supported Ubuntu versions: 22.04 or 24.04 (detected: ${VERSION_ID:-unknown})."
      exit 1
      ;;
  esac
}

ensure_openclaw_user() {
  if id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
    log "User '$OPENCLAW_USER' already exists."
    return
  fi

  log "Creating user '$OPENCLAW_USER'..."
  useradd -m -s /bin/bash "$OPENCLAW_USER"
  usermod -aG sudo "$OPENCLAW_USER"

  cat >/etc/sudoers.d/90-openclaw <<'EOF'
openclaw ALL=(ALL) NOPASSWD:ALL
EOF
  chmod 440 /etc/sudoers.d/90-openclaw
}

wait_for_apt() {
  log "Waiting for apt lock (cloud-init may be running)..."
  systemctl stop unattended-upgrades 2>/dev/null || true
  systemctl stop apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
  local waited=0
  while flock --nonblock /var/lib/dpkg/lock-frontend true 2>/dev/null; [ $? -ne 0 ]; do
    if [ $waited -ge 120 ]; then
      log "Timed out waiting for apt lock after 120s — proceeding anyway"
      break
    fi
    sleep 5
    waited=$((waited + 5))
  done
  while flock --nonblock /var/lib/dpkg/lock true 2>/dev/null; [ $? -ne 0 ]; do
    sleep 3
  done
}

install_base_deps() {
  log "Installing base dependencies..."
  wait_for_apt
  apt-get update
  apt-get install -y ca-certificates curl git jq gnupg pass lsb-release software-properties-common

  log "Installing Node.js 22 (NodeSource)..."
  apt-get remove -y nodejs npm 2>/dev/null || true
  apt-get autoremove -y 2>/dev/null || true
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  wait_for_apt
  apt-get install -y nodejs
}

configure_ufw() {
  log "Configuring UFW firewall..."
  apt-get install -y ufw
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp
  ufw --force enable
}

configure_fail2ban() {
  log "Configuring Fail2ban..."
  apt-get install -y fail2ban

  mkdir -p /etc/fail2ban/jail.d
  cat >/etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled = true
port = ssh
maxretry = 3
findtime = 10m
bantime = 1h
EOF

  systemctl enable fail2ban
  systemctl restart fail2ban
}

install_openclaw_cli() {
  log "Installing OpenClaw CLI as $OPENCLAW_USER..."
  sudo -H -u "$OPENCLAW_USER" bash -lc 'npm config set prefix "$HOME/.local"'
  sudo -H -u "$OPENCLAW_USER" bash -lc 'npm install -g openclaw'

  PROFILE_FILE="/home/${OPENCLAW_USER}/.profile"
  if ! grep -q 'HOME/.local/bin' "$PROFILE_FILE" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE_FILE"
  fi
}

init_openclaw() {
  log "Initializing OpenClaw (vanilla)..."
  sudo -H -u "$OPENCLAW_USER" bash -lc 'openclaw setup --non-interactive --mode local --workspace /home/openclaw/.openclaw/workspace'
}

setup_systemd_user_service() {
  local uid runtime_dir service_dir service_file
  uid="$(id -u "$OPENCLAW_USER")"
  runtime_dir="/run/user/${uid}"
  service_dir="/home/${OPENCLAW_USER}/.config/systemd/user"
  service_file="${service_dir}/openclaw.service"

  log "Configuring systemd user service for OpenClaw gateway..."
  mkdir -p "$service_dir"
  cat >"$service_file" <<'EOF'
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
ExecStart=/home/openclaw/.local/bin/openclaw gateway run
Restart=always
RestartSec=10
Environment=HOME=/home/openclaw

[Install]
WantedBy=default.target
EOF

  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/home/$OPENCLAW_USER/.config"

  loginctl enable-linger "$OPENCLAW_USER"

  mkdir -p "$runtime_dir"
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$runtime_dir"

  sudo -u "$OPENCLAW_USER" XDG_RUNTIME_DIR="$runtime_dir" systemctl --user daemon-reload || true
  sudo -u "$OPENCLAW_USER" XDG_RUNTIME_DIR="$runtime_dir" systemctl --user enable openclaw || true
  sudo -u "$OPENCLAW_USER" XDG_RUNTIME_DIR="$runtime_dir" systemctl --user restart openclaw || true
}

print_summary() {
  cat <<EOF

✅ OpenClaw vanilla bootstrap complete.

Next steps:
1) Switch to openclaw user:
   sudo -iu openclaw
2) Check service:
   systemctl --user status openclaw
3) Open dashboard:
   openclaw dashboard

EOF
}

main() {
  require_root
  check_ubuntu_version
  ensure_openclaw_user
  install_base_deps
  configure_ufw
  configure_fail2ban
  install_openclaw_cli
  init_openclaw
  setup_systemd_user_service
  print_summary
}

main "$@"
