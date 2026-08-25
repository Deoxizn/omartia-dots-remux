#!/bin/bash
# stellarchy: post-update hook — keep the remux repo current after omarchy-update.
# @REPO_DIR@ is replaced with the checkout's absolute path at install time.
REPO_DIR="@REPO_DIR@"
LOG="$HOME/.local/state/stellarchy/repo-sync.log"
BRANCH="master"

mkdir -p "$(dirname "$LOG")"
exec 9>/tmp/stellarchy-repo-sync.lock || exit 0
flock -n 9 || exit 0 # a manual ./sync.sh or a concurrent hook run owns the sync

exec 3>&1 # console passthrough — the block below redirects stdout to the log
say() { echo "Stellarchy $1" >&3; }

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
