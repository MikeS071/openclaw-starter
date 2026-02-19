#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
NON_INTERACTIVE=false

for arg in "$@"; do
  case "$arg" in
    --non-interactive)
      NON_INTERACTIVE=true
      ;;
    -h|--help)
      cat <<'EOF'
Usage: bash install.sh [--non-interactive]

Options:
  --non-interactive  Skip prompts and read values from environment variables.

Environment variables used in non-interactive mode:
  OPENCLAW_WORKSPACE
  OPENCLAW_USER_NAME
  OPENCLAW_TIMEZONE
  OPENCLAW_WORK_EMAIL
  OPENCLAW_X_HANDLE
  OPENCLAW_PERSONAL_EMAIL (optional)
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

if [[ "$NON_INTERACTIVE" == false && ! -t 0 ]]; then
  NON_INTERACTIVE=true
fi

require_cmd() {
  local cmd="$1"
  local help_msg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required tool '$cmd' is missing. $help_msg"
    exit 1
  fi
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

confirm() {
  local prompt="$1"
  local response
  read -r -p "$prompt [y/N]: " response
  [[ "$response" =~ ^[Yy]$ ]]
}

ensure_gpg_key() {
  if gpg --list-keys "navi@openclaw.local" >/dev/null 2>&1; then
    return 0
  fi

  echo "No GPG key found for navi@openclaw.local. Generating one (no passphrase)..."
  local key_spec
  key_spec=$(mktemp)
  cat > "$key_spec" <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 3072
Subkey-Type: RSA
Subkey-Length: 3072
Name-Real: OpenClaw Navi
Name-Email: navi@openclaw.local
Expire-Date: 0
%commit
EOF
  gpg --batch --gen-key "$key_spec"
  rm -f "$key_spec"
}

configure_api_keys() {
  echo
  echo "API key setup"
  echo "Choose which API keys to configure (comma-separated numbers, or Enter to skip):"
  echo "  1) OpenAI"
  echo "  2) Brave Search"
  echo "  3) Google OAuth"
  echo "  4) X (Twitter)"
  read -r -p "Selection: " key_selection

  [[ -z "${key_selection// }" ]] && return 0

  ensure_gpg_key
  mkdir -p "$HOME/.password-store/apis"

  declare -A key_map=(
    [1]="OPENAI_API_KEY"
    [2]="BRAVE_SEARCH_API_KEY"
    [3]="GOOGLE_OAUTH"
    [4]="X_TWITTER_API_KEY"
  )

  IFS=',' read -ra selected <<< "$key_selection"
  for raw in "${selected[@]}"; do
    idx="$(echo "$raw" | xargs)"
    key_name="${key_map[$idx]:-}"
    if [[ -z "$key_name" ]]; then
      echo "Skipping invalid selection: $idx"
      continue
    fi

    read -r -s -p "Enter value for $key_name: " key_value
    echo
    if [[ -z "$key_value" ]]; then
      echo "Skipping $key_name (empty value)."
      continue
    fi

    printf '%s' "$key_value" | gpg --batch --yes -e -r navi@openclaw.local -o "$HOME/.password-store/apis/${key_name}.gpg"
    echo "Stored encrypted key: ~/.password-store/apis/${key_name}.gpg"
  done
}

setup_precache() {
  if [[ "$NON_INTERACTIVE" == false ]]; then
    if ! confirm "Set up Gmail/Calendar pre-cache?"; then
      return 0
    fi
  fi

  mkdir -p "$WORKSPACE_PATH/automation"
  cp "$REPO_ROOT/automation/precache-checks.sh" "$WORKSPACE_PATH/automation/precache-checks.sh"
  chmod +x "$WORKSPACE_PATH/automation/precache-checks.sh"

  echo ""
  echo "OpenClaw cron API setup is environment-specific."
  echo "If cron API is available, register this command:"
  echo "  OPENCLAW_WORKSPACE=\"$WORKSPACE_PATH\" bash \"$WORKSPACE_PATH/automation/precache-checks.sh\""
  echo ""
  echo "Example crontab entry (every 15 min):"
  echo "  */15 * * * * OPENCLAW_WORKSPACE=\"$WORKSPACE_PATH\" bash \"$WORKSPACE_PATH/automation/precache-checks.sh\""
}

require_cmd git "Install git first."
require_cmd gpg "Install GnuPG first."
require_cmd pass "Install pass first."

if [[ "$NON_INTERACTIVE" == true ]]; then
  WORKSPACE_PATH="$DEFAULT_WORKSPACE"
else
  read -r -p "OpenClaw workspace path [$DEFAULT_WORKSPACE]: " WORKSPACE_PATH
  WORKSPACE_PATH="${WORKSPACE_PATH:-$DEFAULT_WORKSPACE}"

  if ! confirm "Use workspace path: $WORKSPACE_PATH?"; then
    echo "Aborted. Re-run install.sh and enter the correct path."
    exit 1
  fi
fi

mkdir -p "$WORKSPACE_PATH"

if compgen -G "$WORKSPACE_PATH/*" >/dev/null; then
  backup_dir="$WORKSPACE_PATH.backup.$(date +%Y%m%d-%H%M%S)"
  echo "Backing up existing workspace to: $backup_dir"
  mkdir -p "$backup_dir"
  cp -a "$WORKSPACE_PATH"/. "$backup_dir"/
fi

echo "Copying template workspace files..."
cp -a "$REPO_ROOT/workspace"/. "$WORKSPACE_PATH"/

if [[ "$NON_INTERACTIVE" == true ]]; then
  NAME="${OPENCLAW_USER_NAME:-OpenClaw User}"
  PREFERRED_NAME="${OPENCLAW_USER_NAME:-OpenClaw}"
  TIMEZONE="${OPENCLAW_TIMEZONE:-UTC}"
  X_HANDLE="${OPENCLAW_X_HANDLE:-}"
  WORK_EMAIL="${OPENCLAW_WORK_EMAIL:-}"
  PERSONAL_EMAIL="${OPENCLAW_PERSONAL_EMAIL:-}"
else
  read -r -p "Your name: " NAME
  read -r -p "Preferred name: " PREFERRED_NAME
  read -r -p "Timezone (e.g. Australia/Melbourne): " TIMEZONE
  read -r -p "X/Twitter handle (without @): " X_HANDLE
  read -r -p "Work email: " WORK_EMAIL
  read -r -p "Personal email: " PERSONAL_EMAIL
fi

USER_FILE="$WORKSPACE_PATH/USER.md"
IDENTITY_FILE="$WORKSPACE_PATH/IDENTITY.md"
MEMORY_FILE="$WORKSPACE_PATH/MEMORY.md"
TOOLS_FILE="$WORKSPACE_PATH/TOOLS.md"

sed -i "s/{{NAME}}/$(escape_sed "$NAME")/g" "$USER_FILE" "$MEMORY_FILE"
sed -i "s/{{PREFERRED_NAME}}/$(escape_sed "$PREFERRED_NAME")/g" "$USER_FILE"
sed -i "s/{{TIMEZONE}}/$(escape_sed "$TIMEZONE")/g" "$USER_FILE" "$MEMORY_FILE" "$TOOLS_FILE"
sed -i "s/{{WORK_EMAIL}}/$(escape_sed "$WORK_EMAIL")/g" "$USER_FILE"
sed -i "s/{{PERSONAL_EMAIL}}/$(escape_sed "$PERSONAL_EMAIL")/g" "$USER_FILE"
sed -i "s/{{X_HANDLE}}/$(escape_sed "$X_HANDLE")/g" "$USER_FILE"
sed -i "s/{{AGENT_NAME}}/$(escape_sed "$NAME")/g" "$IDENTITY_FILE" "$MEMORY_FILE"
sed -i "s/{{DATE}}/$(date -u +%F)/g" "$MEMORY_FILE"

if [[ "$NON_INTERACTIVE" == false ]]; then
  configure_api_keys
fi
setup_precache

chmod +x "$WORKSPACE_PATH/workflow/readiness-check.sh" "$WORKSPACE_PATH/automation/precache-checks.sh" 2>/dev/null || true

echo ""
echo "Setup complete! Restart OpenClaw to activate your new persona."