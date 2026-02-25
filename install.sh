#!/usr/bin/env bash
set -euo pipefail

# Minimal local bootstrap for a vanilla OpenClaw instance.
# This does not copy any persona/workflow templates.

openclaw setup --wizard
