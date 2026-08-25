#!/bin/bash
# stellarchy: post-update hook — keep the remux repo current after omarchy-update.
# Resolves repo location via state file, auto-migration, baked path, or XDG default.
STATE_DIR="$HOME/.local/state/stellarchy"
STATE_FILE="$STATE_DIR/repo-dir"
BAKED_DIR="@REPO_DIR@"
XDG_DEFAULT="$HOME/.local/opt/stellarchy"
LEGACY_PATH="$HOME/Work/omartia-dots-remux"
LOG="$STATE_DIR/repo-sync.log"
BRANCH="master"

mkdir -p "$STATE_DIR"

# Resolve repo directory with auto-migration from ~/Work/ if needed
resolve_repo() {
  # 1. State file (authoritative if it exists and points to a valid dir)
  if [[ -f $STATE_FILE ]]; then
    local stored
    stored=$(<"$STATE_FILE")
    if [[ -d $stored ]]; then
      echo "$stored"
      return
    fi
  fi
  # 2. XDG default (fresh installs, target location)
  if [[ -d $XDG_DEFAULT ]]; then
    echo "$XDG_DEFAULT"
    return
  fi
  # 3. Auto-migrate: old ~/Work/ repo → ~/.local/opt/stellarchy
  if [[ -d $LEGACY_PATH ]] && [[ ! -d $XDG_DEFAULT ]]; then
    mkdir -p "$(dirname "$XDG_DEFAULT")"
    if mv "$LEGACY_PATH" "$XDG_DEFAULT" 2>/dev/null; then
      echo "$XDG_DEFAULT"
      return
    fi
  fi
  # 4. Baked path from install (backward compat, last resort)
  if [[ -d $BAKED_DIR ]]; then
    echo "$BAKED_DIR"
    return
  fi
}

REPO_DIR=$(resolve_repo)
if [[ -z $REPO_DIR ]]; then
  echo "[$(date '+%F %T')] repo not found (state=$STATE_FILE baked=$BAKED_DIR xdg=$XDG_DEFAULT legacy=$LEGACY_PATH)"
  exit 0
fi

# Persist resolved path so future runs skip the fallback chain
if [[ ! -f $STATE_FILE ]] || [[ $(<"$STATE_FILE") != "$REPO_DIR" ]]; then
  echo "$REPO_DIR" > "$STATE_FILE"
fi

exec 9>/tmp/stellarchy-repo-sync.lock || exit 0
flock -n 9 || exit 0 # a manual ./sync.sh or a concurrent hook run owns the sync

exec 3>&1 # console passthrough — the block below redirects stdout to the log
# One green section header (house style of omarchy-update's other blocks), then
# status line(s) beneath it.
header_done=
say() {
  if [[ -z $header_done ]]; then
    echo -e "\e[32m\nStellarchy\e[0m" >&3
    header_done=1
  fi
  echo "$1" >&3
}

{
    cd "$REPO_DIR" 2>/dev/null || { say "repo missing at $REPO_DIR"; echo "[$(date '+%F %T')] repo missing at $REPO_DIR"; exit 0; }
    if ! git fetch --quiet origin 2>/dev/null; then
        say "sync skipped (offline)"
        echo "[$(date '+%F %T')] offline — skipped"
        exit 0
    fi

    local_rev=$(git rev-parse --short HEAD 2>/dev/null)
    remote_rev=$(git rev-parse --short "origin/$BRANCH" 2>/dev/null)
    if [[ -z $local_rev || -z $remote_rev ]]; then
        say "could not determine revisions"
        echo "[$(date '+%F %T')] could not determine revisions"
        exit 0
    fi
    if [[ $local_rev == "$remote_rev" ]]; then
        say "up to date ($local_rev)"
        echo "[$(date '+%F %T')] up to date ($local_rev)"
        exit 0
    fi

    say "syncing $local_rev -> $remote_rev..."
    echo "[$(date '+%F %T')] syncing $local_rev -> $remote_rev"
    if ! git pull --ff-only --quiet; then
        say "sync FAILED — repo diverged?"
        echo "[$(date '+%F %T')] pull failed (diverged?)"
        notify-send -u critical "Stellarchy sync failed" "Repo diverged — run sync.sh manually in $REPO_DIR"
        exit 0
    fi

    if ./sync.sh; then
        say "synced to $remote_rev"
        notify-send -u normal "Stellarchy updated" "Dots synced to latest; some changes apply on next login."
    else
        say "sync FAILED"
        notify-send -u critical "Stellarchy update failed" "Check ~/.local/state/stellarchy/repo-sync.log"
    fi
} >>"$LOG" 2>&1
exit 0
