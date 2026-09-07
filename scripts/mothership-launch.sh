#!/usr/bin/env bash
# ai-dev-team launch script — desktop launcher & service manager.
# The ai-dev-team root is auto-detected as the parent of this scripts/ folder,
# so it works wherever you clone it. Override with MOTHERSHIP_ROOT if needed.
# Extensible: register a service by adding one line to the SERVICES array.
# Usage:
#   mothership-launch.sh            # interactive menu (desktop icon uses this)
#   mothership-launch.sh status     # one-line status of all services
#   mothership-launch.sh start <name>|stop <name>|restart <name>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Default root = parent of this scripts/ folder (i.e. the ai-dev-team checkout).
export MOTHERSHIP_ROOT="${MOTHERSHIP_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="${MOTHERSHIP_ENV:-$MOTHERSHIP_ROOT/.env}"
export MOTHERSHIP_LOG_DIR="${MOTHERSHIP_LOG_DIR:-$MOTHERSHIP_ROOT/logs}"
export MOTHERSHIP_PID_DIR="${MOTHERSHIP_PID_DIR:-$MOTHERSHIP_ROOT/run}"
mkdir -p "$MOTHERSHIP_LOG_DIR" "$MOTHERSHIP_PID_DIR"

# Load env so desktop-launched services inherit your keys (desktop icons normally don't).
[ -f "$ENV_FILE" ] && { set -a; . "$ENV_FILE"; set +a; }

# --- Service registry -------------------------------------------------------
# Format: NAME | KIND | ARG | PATTERN
#   KIND = systemd  -> managed via `systemctl --user`; ARG = unit name
#          pidfile -> managed here; ARG = start command, PATTERN = pgrep regex to find it
# Add a service = add a line below.
SERVICES=(
  "vllm-bridge|systemd|cline-vllm-bridge|cline_vllm_proxy.py"
  # "example|pidfile|python3 $SCRIPT_DIR/example.py|example.py"
)

# --- colors -----------------------------------------------------------------
if [ -t 1 ]; then
  C0=$'\033[0m'; Cg=$'\033[32m'; Cy=$'\033[33m'; Cr=$'\033[31m'; Cb=$'\033[36m'
else
  C0=""; Cg=""; Cy=""; Cr=""; Cb=""
fi

# --- helpers ----------------------------------------------------------------
field() { printf '%s\n' "${SERVICES[$1]}" | cut -d'|' -f"$2"; }
find_idx() { # $1 = name -> echo index or -1
  local i
  for i in $(seq 0 $((${#SERVICES[@]} - 1))); do
    [ "$(field "$i" 1)" = "$1" ] && { echo "$i"; return 0; }
  done
  echo "-1"
}
st_systemd() { systemctl --user is-active "$1" 2>/dev/null || echo inactive; }
st_pidfile() { pgrep -f "$1" >/dev/null 2>&1 && echo active || echo inactive; }

svc_status() {
  local i name kind arg pat st col
  echo "${Cb}== ai-dev-team services ==${C0}"
  for i in $(seq 0 $((${#SERVICES[@]} - 1))); do
    name="$(field "$i" 1)"; kind="$(field "$i" 2)"; arg="$(field "$i" 3)"; pat="$(field "$i" 4)"
    if [ "$kind" = systemd ]; then st="$(st_systemd "$arg")"; else st="$(st_pidfile "$pat")"; fi
    case "$st" in active) col="$Cg";; inactive|failed) col="$Cr";; *) col="$Cy";; esac
    printf "  %-18s %-10s %s(%s)%s\n" "$name" "$st" "$col" "$kind" "$C0"
  done
}

do_start() {
  local i="$1" name kind arg pat
  name="$(field "$i" 1)"; kind="$(field "$i" 2)"; arg="$(field "$i" 3)"; pat="$(field "$i" 4)"
  if [ "$kind" = systemd ]; then
    systemctl --user start "$arg" && echo "${Cg}started $name (systemd: $arg)${C0}" \
      || echo "${Cr}failed to start $name${C0}"
  else
    pgrep -f "$pat" >/dev/null 2>&1 && { echo "${Cy}$name already running${C0}"; return; }
    # shellcheck disable=SC2086
    ( cd "$SCRIPT_DIR" && nohup $arg >"$MOTHERSHIP_LOG_DIR/$name.log" 2>&1 & echo $! >"$MOTHERSHIP_PID_DIR/$name.pid" )
    sleep 1
    pgrep -f "$pat" >/dev/null 2>&1 && echo "${Cg}started $name${C0}" \
      || echo "${Cr}failed to start $name — see $MOTHERSHIP_LOG_DIR/$name.log${C0}"
  fi
}

do_stop() {
  local i="$1" name kind arg pat
  name="$(field "$i" 1)"; kind="$(field "$i" 2)"; arg="$(field "$i" 3)"; pat="$(field "$i" 4)"
  if [ "$kind" = systemd ]; then
    systemctl --user stop "$arg" && echo "${Cg}stopped $name${C0}"
  else
    [ -f "$MOTHERSHIP_PID_DIR/$name.pid" ] && kill "$(cat "$MOTHERSHIP_PID_DIR/$name.pid")" 2>/dev/null
    rm -f "$MOTHERSHIP_PID_DIR/$name.pid"
    pkill -f "$pat" 2>/dev/null
    echo "${Cg}stopped $name${C0}"
  fi
}

# --- menu -------------------------------------------------------------------
menu() {
  while true; do
    echo; svc_status; echo
    echo "  a) start all   z) stop all   s) systemctl status (bridge)   q) quit"
    local n=0 i
    for i in $(seq 0 $((${#SERVICES[@]} - 1))); do
      n=$((n + 1)); printf "  %s) toggle %s\n" "$n" "$(field "$i" 1)"
    done
    printf '\n> '; read -r choice
    case "$choice" in
      a) for i in $(seq 0 $((${#SERVICES[@]} - 1))); do do_start "$i"; done ;;
      z) for i in $(seq 0 $((${#SERVICES[@]} - 1))); do do_stop "$i"; done ;;
      q) exit 0 ;;
      s) systemctl --user status cline-vllm-bridge --no-pager 2>&1 | head -20 ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#SERVICES[@]} )); then
          i=$((choice - 1))
          local kind arg pat running
          kind="$(field "$i" 2)"; arg="$(field "$i" 3)"; pat="$(field "$i" 4)"
          if [ "$kind" = systemd ]; then running="$(st_systemd "$arg")"; else running="$(st_pidfile "$pat")"; fi
          [ "$running" = active ] && do_stop "$i" || do_start "$i"
        else echo "${Cr}invalid choice${C0}"; fi
        ;;
    esac
  done
}

# --- CLI -------------------------------------------------------------------
case "${1:-}" in
  start)   i="$(find_idx "${2:-}")"; (( i >= 0 )) && do_start "$i" || { echo "usage: $0 start <name>"; exit 1; } ;;
  stop)    i="$(find_idx "${2:-}")"; (( i >= 0 )) && do_stop "$i" || { echo "usage: $0 stop <name>"; exit 1; } ;;
  restart) i="$(find_idx "${2:-}")"; (( i >= 0 )) && { do_stop "$i"; do_start "$i"; } || { echo "usage: $0 restart <name>"; exit 1; } ;;
  status)  svc_status ;;
  "") menu ;;
  *) echo "usage: $0 [start|stop|restart|status [name]]"; exit 1 ;;
esac