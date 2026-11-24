#!/bin/sh
# Start script for RustiCal on Railway.
# 1. Binds to $PORT and sizes the thread pool to the service's CPU limit.
# 2. Creates (or updates) the admin user from ADMIN_USERNAME / ADMIN_PASSWORD
#    BEFORE the web server starts, so there is never an open, unclaimed instance.
# 3. Runs `rustical serve` and exits non-zero on any unexpected stop, so
#    Railway's ON_FAILURE restart policy brings it back.
set -eu

log() { echo "[start] $*"; }
fail() { echo "[start] ERROR: $*" >&2; exit 1; }

PORT="${PORT:-4000}"
DATA_DIR=/var/lib/rustical
export RUSTICAL_DATA_STORE__SQLITE__DB_URL="${RUSTICAL_DATA_STORE__SQLITE__DB_URL:-$DATA_DIR/db.sqlite3}"
export RUSTICAL_HTTP__BIND="${RUSTICAL_HTTP__BIND:-[::]:$PORT}"

mkdir -p "$DATA_DIR" || fail "cannot create $DATA_DIR"
[ -w "$DATA_DIR" ] || fail "$DATA_DIR is not writable (is the volume mounted?)"

# Railway shows the host's CPUs inside a 1 vCPU service: size tokio from cgroup cpu.max.
if [ -z "${TOKIO_WORKER_THREADS:-}" ]; then
  cpus=2
  if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max || true
    if [ "${quota:-max}" != "max" ] && [ "${period:-0}" -gt 0 ] 2>/dev/null; then
      cpus=$(( (quota + period - 1) / period ))
    fi
  fi
  [ "$cpus" -lt 2 ] && cpus=2
  [ "$cpus" -gt 4 ] && cpus=4
  export TOKIO_WORKER_THREADS="$cpus"
fi
log "listening on $RUSTICAL_HTTP__BIND, TOKIO_WORKER_THREADS=$TOKIO_WORKER_THREADS"

# ---- admin bootstrap (before the port opens) -------------------------------
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
case "$ADMIN_USERNAME" in
  *:*|*'$'*|*' '*|'') fail "ADMIN_USERNAME must not be empty or contain ':', '\$' or spaces" ;;
esac
[ -n "$ADMIN_PASSWORD" ] || fail "ADMIN_PASSWORD is empty: set it (the template generates one)"
[ "${#ADMIN_PASSWORD}" -ge 12 ] || fail "ADMIN_PASSWORD must be at least 12 characters"

if rustical principals list 2>/dev/null | grep -q "^$ADMIN_USERNAME (displayname="; then
  printf '%s\n' "$ADMIN_PASSWORD" | rustical principals edit "$ADMIN_USERNAME" --password >/dev/null \
    || fail "could not set the password of $ADMIN_USERNAME"
  log "admin user '$ADMIN_USERNAME' exists; password synced from ADMIN_PASSWORD"
else
  printf '%s\n' "$ADMIN_PASSWORD" | rustical principals create "$ADMIN_USERNAME" --name "$ADMIN_USERNAME" --password >/dev/null \
    || fail "could not create the admin user $ADMIN_USERNAME"
  rustical principals list 2>/dev/null | grep -q "^$ADMIN_USERNAME (displayname=" \
    || fail "admin user $ADMIN_USERNAME was not created"
  log "created admin user '$ADMIN_USERNAME'"
fi

# ---- serve ---------------------------------------------------------------
stopping=0
child=0
on_term() {
  stopping=1
  [ "$child" -gt 0 ] && kill -TERM "$child" 2>/dev/null || true
}
trap on_term TERM INT

rustical serve &
child=$!
status=0
while :; do
  wait "$child" && status=0 || status=$?
  # wait returns >128 when a trapped signal interrupts it; keep waiting while the child lives
  if kill -0 "$child" 2>/dev/null; then continue; fi
  break
done

if [ "$stopping" -eq 1 ]; then
  log "stopped on request (exit $status)"
  exit 0
fi
[ "$status" -eq 0 ] && status=1
log "rustical exited unexpectedly; exiting $status so Railway restarts it"
exit "$status"
