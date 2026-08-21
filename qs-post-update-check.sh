#!/bin/bash
set -u

fail=0
ok() { printf '  \033[32mOK \033[0m %s\n' "$*"; }
bad() { printf '  \033[31m!! \033[0m %s\n' "$*"; fail=1; }

echo "omartia quickshell post-update check"
echo "------------------------------------"

if out=$(quickshell --version 2>&1); then
  ok "binary runs: $out"
else
  bad "binary failed (Qt private-ABI mismatch?): $out"
fi

pkg=$(pacman -Q quickshell 2>/dev/null)
if [ -n "$pkg" ]; then ok "$pkg"; else bad "quickshell not found in pacman db"; fi

if n=$(pgrep -cf "qs -c caelestia"); then
  ok "caelestia shell running ($n proc)"
else
  bad "caelestia shell NOT running"
fi

f=/usr/share/omarchy/bin/omarchy-restart-shell
if [ -f "$f" ] && grep -q 'omartia-dots-remux' "$f"; then
  ok "restart-shell guard present"
else
  bad "restart-shell guard MISSING from $f"
fi

logs=$(journalctl --user -b --no-pager 2>/dev/null | grep -iE "symbol lookup error|undefined symbol" | grep -i quickshell)
if [ -n "$logs" ]; then
  bad "symbol errors in user journal:"
  printf '%s\n' "$logs" | tail -5 | sed 's/^/       /'
else
  ok "no quickshell symbol errors this boot"
fi

if coredumpctl list quickshell --no-pager >/dev/null 2>&1; then
  n=$(coredumpctl list quickshell --no-pager 2>/dev/null | grep -c quickshell)
  bad "$n quickshell coredump(s); latest:"
  coredumpctl list quickshell --no-pager 2>/dev/null | tail -2 | sed 's/^/       /'
else
  ok "no quickshell coredumps"
fi

echo "------------------------------------"
if [ "$fail" -eq 0 ]; then
  echo "all clear"
  exit 0
else
  echo "issues found - see above (downgrade: /var/cache/pacman/pkg/quickshell-0.3.0-3-*.pkg.tar.zst)"
  exit 1
fi
