#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [--force-config] [--no-systemd] [--skip-pip]

Installs or updates the voice dictation daemon for the current user.

Options:
  --force-config  Overwrite ~/.config/voice-dictation.env with the example config.
  --no-systemd    Skip systemd --user reload/enable/restart steps.
  --skip-pip      Skip Python package installation after creating the virtualenv.
  -h, --help      Show this help text.
EOF
}

log() {
  printf '[install] %s\n' "$*"
}

warn() {
  printf '[install] warning: %s\n' "$*" >&2
}

die() {
  printf '[install] error: %s\n' "$*" >&2
  exit 1
}

FORCE_CONFIG=0
NO_SYSTEMD=0
SKIP_PIP=0

while (($# > 0)); do
  case "$1" in
    --force-config)
      FORCE_CONFIG=1
      ;;
    --no-systemd)
      NO_SYSTEMD=1
      ;;
    --skip-pip)
      SKIP_PIP=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown option: $1"
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

PYTHON_BIN="$(command -v python3 || true)"
[[ -n "$PYTHON_BIN" ]] || die "python3 is required"

APP_DIR="${VOICE_DICTATION_HOME:-$HOME/.local/share/voice-dictation}"
VENV_DIR="$APP_DIR/venv"
LIBEXEC_DIR="$APP_DIR/libexec"
INSTALLED_DAEMON="$LIBEXEC_DIR/voice-dictation-daemon"
LAUNCHER_PATH="$HOME/.local/bin/voice-dictation-daemon"
SYSTEMD_UNIT_PATH="$HOME/.config/systemd/user/voice-dictation.service"
CONFIG_PATH="$HOME/.config/voice-dictation.env"
STATE_DIR="$HOME/.local/state/voice-dictation"

[[ -f "$REPO_ROOT/requirements.txt" ]] || die "requirements.txt not found next to install.sh"
[[ -f "$REPO_ROOT/bin/voice-dictation-daemon" ]] || die "bin/voice-dictation-daemon not found"
[[ -f "$REPO_ROOT/systemd/user/voice-dictation.service" ]] || die "systemd unit not found"
[[ -f "$REPO_ROOT/config/voice-dictation.env.example" ]] || die "config example not found"

mkdir -p "$APP_DIR" "$LIBEXEC_DIR" "$HOME/.local/bin" "$HOME/.config/systemd/user" "$STATE_DIR"

if [[ ! -x "$VENV_DIR/bin/python3" ]]; then
  log "Creating virtual environment at $VENV_DIR"
  if ! "$PYTHON_BIN" -m venv "$VENV_DIR"; then
    die "failed to create virtual environment; on Ubuntu install python3-venv"
  fi
else
  log "Using existing virtual environment at $VENV_DIR"
fi

if ((SKIP_PIP == 0)); then
  log "Installing Python dependencies"
  "$VENV_DIR/bin/pip" install --upgrade pip
  "$VENV_DIR/bin/pip" install -r "$REPO_ROOT/requirements.txt"
else
  log "Skipping Python dependency installation"
fi

log "Installing daemon payload"
install -Dm755 "$REPO_ROOT/bin/voice-dictation-daemon" "$INSTALLED_DAEMON"

log "Installing launcher"
launcher_tmp="$(mktemp)"
trap 'rm -f "$launcher_tmp"' EXIT
cat >"$launcher_tmp" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$VENV_DIR/bin/python3" "$INSTALLED_DAEMON" "\$@"
EOF
install -Dm755 "$launcher_tmp" "$LAUNCHER_PATH"
rm -f "$launcher_tmp"
trap - EXIT

log "Installing systemd user unit"
install -Dm644 "$REPO_ROOT/systemd/user/voice-dictation.service" "$SYSTEMD_UNIT_PATH"

if ((FORCE_CONFIG == 1)); then
  log "Overwriting config at $CONFIG_PATH"
  install -Dm600 "$REPO_ROOT/config/voice-dictation.env.example" "$CONFIG_PATH"
elif [[ -e "$CONFIG_PATH" ]]; then
  log "Keeping existing config at $CONFIG_PATH"
else
  log "Creating config at $CONFIG_PATH"
  install -Dm600 "$REPO_ROOT/config/voice-dictation.env.example" "$CONFIG_PATH"
fi

if ((NO_SYSTEMD == 1)); then
  log "Skipping systemd --user reload/start"
else
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl not found; reload and start voice-dictation.service manually"
  elif ! systemctl --user daemon-reload; then
    warn "systemctl --user daemon-reload failed; reload the user service manually"
  else
    if ! systemctl --user enable --now voice-dictation.service; then
      warn "failed to enable/start voice-dictation.service; run systemctl --user enable --now voice-dictation.service"
    elif ! systemctl --user restart voice-dictation.service; then
      warn "failed to restart voice-dictation.service; run systemctl --user restart voice-dictation.service"
    fi
  fi
fi

log "Install complete"
log "Launcher: $LAUNCHER_PATH"
log "Config: $CONFIG_PATH"
