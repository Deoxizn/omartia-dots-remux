#!/bin/bash
# omartia-dots-remux: keep the Stellarchy splash on every kernel.
# Fired by 95-stellarchy-plymouth-refresh.hook (PostTransaction, after
# mkinitcpio's 90-* hooks) whenever a kernel package is installed or
# upgraded. If the Stellarchy splash is adopted, rebuilds the UKIs so the
# new kernel's initramfs packs the stellarchy theme instead of falling back
# to whatever theme was active mid-transaction. Idempotent; exits instantly
# when the splash was never adopted.

conf=/etc/plymouth/plymouthd.conf
dir=/usr/share/plymouth/themes/stellarchy

grep -q '^Theme=stellarchy' "$conf" 2>/dev/null || exit 0
[[ -d $dir ]] || {
	logger -t stellarchy-plymouth "Theme=stellarchy set but $dir is missing - skipping rebuild"
	exit 0
}

# Never rebuild from a non-self-contained theme: mkinitcpio's plymouth hook
# packs only the active theme's own directory, so a cross-dir ScriptFile
# ships an initramfs with no splash script at all (black screen, and the
# LUKS passphrase prompt with it).
sf="$(sed -n 's/^ *ScriptFile *= *//p' "$dir/stellarchy.plymouth" 2>/dev/null)"
case "$sf" in
"$dir"/*) [[ -f $sf ]] || {
	logger -t stellarchy-plymouth "broken stellarchy theme: $sf missing - skipping rebuild"
	exit 1
	} ;;
*)
	logger -t stellarchy-plymouth "stellarchy theme is not self-contained - skipping rebuild"
	exit 1 ;;
esac

echo "stellarchy remux: Theme=stellarchy active - rebuilding UKIs for new kernel(s)"
logger -t stellarchy-plymouth "rebuilding UKIs after kernel change"
exec /usr/bin/limine-mkinitcpio
