#!/bin/bash
# omartia-dots-remux: keep omarchy-update from resurrecting the Omarchy shell.
# Re-inserts an early-exit guard into /usr/share/omarchy/bin/omarchy-restart-shell
# whenever an omarchy package upgrade overwrites it. Idempotent.

f=/usr/share/omarchy/bin/omarchy-restart-shell
[[ -f $f ]] || exit 0
grep -q 'omartia-dots-remux' "$f" && exit 0

python3 - "$f" <<'PYEOF'
import sys

p = sys.argv[1]
s = open(p).read()
guard = (
    "#!/bin/bash\n"
    "\n"
    "# omartia-dots-remux: Caelestia handles the shell; skip Omarchy shell restart.\n"
    'if pgrep -f "qs -c caelestia" >/dev/null 2>&1; then\n'
    '  echo "Caelestia active; skipping Omarchy shell restart."\n'
    "  exit 0\n"
    "fi\n"
)
s = s.replace("#!/bin/bash\n", guard, 1)
open(p, "w").write(s)
print("guard applied to", p)
PYEOF
