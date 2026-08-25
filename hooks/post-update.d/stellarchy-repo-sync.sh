#!/bin/bash
# stellarchy: post-update hook — keep the remux repo current after omarchy-update.
# @REPO_DIR@ is replaced with the checkout's absolute path at install time.
REPO_DIR="@REPO_DIR@"
LOG="$HOME/.local/state/stellarchy/repo-sync.log"
BRANCH="master"

mkdir -p "$(dirname "$LOG")"
exec 9>/tmp/stellarchy-repo-sync.lock || exit 0
flock -n 9 || exit 0 # a manual ./sync.sh or a concurrent hook run owns the sync

{
    cd "$REPO_DIR" 2>/dev/null || exit 0
    git fetch --quiet origin 2>/dev/null || exit 0 # offline; retry next update

    local_rev=$(git rev-parse --short HEAD 2>/dev/null)
    remote_rev=$(git rev-parse --short "origin/$BRANCH" 2>/dev/null)
    [[ -n $local_rev && $local_rev != "$remote_rev" ]] || exit 0

    echo "[$(date '+%F %T')] syncing $local_rev -> $remote_rev"
    if ! git pull --ff-only --quiet; then
        echo "[$(date '+%F %T')] pull failed (diverged?)"
        notify-send -u critical "Stellarchy sync failed" "Repo diverged — run sync.sh manually in $REPO_DIR"
        exit 0
    fi

    if ./sync.sh; then
        notify-send -u normal "Stellarchy updated" "Dots synced to latest; some changes apply on next login."
    else
        notify-send -u critical "Stellarchy update failed" "Check ~/.local/state/stellarchy/repo-sync.log"
    fi
} >>"$LOG" 2>&1
exit 0
