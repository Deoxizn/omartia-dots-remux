# Changelog

History of changes to the Stellarchy dots and system tooling — installer/upgrader,
Hyprland configs, menu suite, theme bridge, guards and branding. Newest first.
README rewording, screenshots and demo-video commits are skipped here; browse the
[full commit history](https://github.com/deoxizn/omartia-dots-remux/commits) for those.

Each entry links to its commit; times are commit times.

<!-- Generated from git history. For new entries: add a dated section at the top,
     one bullet per change: - HH:MM — Description ([`short-hash`](commit-url)). -->

## 2026-08-24

- 07:27 — Install/upgrade: diff-check the main hypr lua files (hyprland/autostart/looknfeel/bindings) — files carrying none of the remux's content are backed up (`*.pre-install.bak` / `*.pre-upgrade.bak`) and replaced with the repo versions, fixing fresh installs silently missing the documented keybinds and autostart
- 07:27 — Add CHANGELOG.md (dots/system changes by date, linked from README)

## 2026-08-23

- 20:42 — +x on stellarchy-install/remove ([`79f76cb`](https://github.com/deoxizn/omartia-dots-remux/commit/79f76cb))
- 20:41 — Menu suite v2 + README overhaul ([`b830367`](https://github.com/deoxizn/omartia-dots-remux/commit/b830367))
- 01:15 — Splash guard hook + path-based Limine default_entry; splash guard, branding and site link in README ([`d986ee7`](https://github.com/deoxizn/omartia-dots-remux/commit/d986ee7))

## 2026-08-22

- 22:49 — Power menu: add screensaver, float pkg/theme TUIs via TUI.float ([`941539f`](https://github.com/deoxizn/omartia-dots-remux/commit/941539f))
- 21:43 — Branding: drop unused stellarchy-star.svg ([`8e0a507`](https://github.com/deoxizn/omartia-dots-remux/commit/8e0a507))
- 21:42 — Menu: drop About entry ([`0b67553`](https://github.com/deoxizn/omartia-dots-remux/commit/0b67553))
- 21:28 — Add repo-managed stellarchy SDDM greeter theme ([`2c06c7f`](https://github.com/deoxizn/omartia-dots-remux/commit/2c06c7f))
- 21:20 — Seed LOGO in identity overlay so lockscreen shows Stellarchy mark ([`fbd95dd`](https://github.com/deoxizn/omartia-dots-remux/commit/fbd95dd))
- 21:05 — Upgrade: re-apply caelestia shell patches on every run ([`c2145d9`](https://github.com/deoxizn/omartia-dots-remux/commit/c2145d9))
- 20:21 — Kernel flags: generalize --bore into `--kernel default|bore|eevdf|lts|rt-bore` ([`dfc153f`](https://github.com/deoxizn/omartia-dots-remux/commit/dfc153f))
- 19:52 — Rebrand: omartia-* -> stellarchy-* suite, os-release identity overlay, optimized logo ([`8b0297b`](https://github.com/deoxizn/omartia-dots-remux/commit/8b0297b))
- 19:09 — Plymouth: refresh vendored stellarchy-logo.png with current transparent art ([`fa620e5`](https://github.com/deoxizn/omartia-dots-remux/commit/fa620e5))
- 18:59 — Fastfetch: seed stellarchy.png (transparent) instead of nobg ([`9a2f562`](https://github.com/deoxizn/omartia-dots-remux/commit/9a2f562))
- 18:54 — Fastfetch: brand seeded installs with stellarchy-nobg sixel logo; hero image in README ([`c3cde31`](https://github.com/deoxizn/omartia-dots-remux/commit/c3cde31))
- 18:17 — Plymouth: vendor omarchy.script into stellarchy theme dir (fixes black-screen boot) ([`304a7f3`](https://github.com/deoxizn/omartia-dots-remux/commit/304a7f3))
- 15:55 — Aim default_entry header at BORE via live index computation (DEFAULT_ENTRY was a fiction; entry-tool conf is generated) ([`5099330`](https://github.com/deoxizn/omartia-dots-remux/commit/5099330))
- 15:48 — Use limine-mkinitcpio instead of mkinitcpio -P (Limine systems have no mkinitcpio presets) ([`b068cd4`](https://github.com/deoxizn/omartia-dots-remux/commit/b068cd4))
- 15:44 — Chaotic-aur bootstrap URLs moved to cdn-mirror.chaotic.cx (old cdn host 404s) ([`edeab11`](https://github.com/deoxizn/omartia-dots-remux/commit/edeab11))
- 15:36 — Docs+flags: --bore and --plymouth upgrade flags with help text, README branding/kernel section; drop upgrade-time prompts ([`6bc535e`](https://github.com/deoxizn/omartia-dots-remux/commit/6bc535e))
- 15:29 — Branding: stellarchy plymouth splash in install+upgrade with refresh and adoption flow ([`fca9763`](https://github.com/deoxizn/omartia-dots-remux/commit/fca9763))
- 15:26 — Install: opt-in cachyos bore kernel via chaotic-aur with name-based limine default entry; upgrade: kernel status check ([`65d08f4`](https://github.com/deoxizn/omartia-dots-remux/commit/65d08f4))
- 15:12 — Branding: ship screensaver/about art via install+upgrade with stock detection ([`674c056`](https://github.com/deoxizn/omartia-dots-remux/commit/674c056))
- 15:08 — Branding: stellarchy screensaver, readme banner, script headers, about menu entry ([`028ba0f`](https://github.com/deoxizn/omartia-dots-remux/commit/028ba0f))
- 15:08 — Install/upgrade: monitor+gtk scale prompts, rounding migration, fastfetch brand seed ([`aeff40a`](https://github.com/deoxizn/omartia-dots-remux/commit/aeff40a))
- 15:08 — Hypr: managed scale-aware rounding block in looknfeel template ([`7f35d58`](https://github.com/deoxizn/omartia-dots-remux/commit/7f35d58))
- 11:19 — Dedupe README, document quattro-specific plugin support; binds: unbind redundant dashboard aliases ([`eac0f48`](https://github.com/deoxizn/omartia-dots-remux/commit/eac0f48))
- 10:48 — Ship caelestia-system-lock + managed hypridle.conf ([`66eac06`](https://github.com/deoxizn/omartia-dots-remux/commit/66eac06))
- 10:43 — Binds: replace dead omarchy-shell media/panel keys; add universal omartia-media + shell self-heal patch pipeline ([`e5b4576`](https://github.com/deoxizn/omartia-dots-remux/commit/e5b4576))

## 2026-08-21

- 17:17 — Super+ctrl+l runs caelestia-system-lock so monitors sleep after lock ([`65d4324`](https://github.com/deoxizn/omartia-dots-remux/commit/65d4324))
- 15:06 — Drop resolved black-screen references, keep recovery commands ([`e4b2850`](https://github.com/deoxizn/omartia-dots-remux/commit/e4b2850))
- 14:40 — Install.sh auto-logout via omarchy-system-logout, not dispatch exit/terminate-user ([`fff2255`](https://github.com/deoxizn/omartia-dots-remux/commit/fff2255))
- 14:25 — Upgrade.sh strips legacy auto-injected binding blocks (double-toggle fix) ([`e6624d7`](https://github.com/deoxizn/omartia-dots-remux/commit/e6624d7))
- 14:04 — Correct logout label in upgrade.sh dry-run output ([`330649d`](https://github.com/deoxizn/omartia-dots-remux/commit/330649d))
- 14:04 — Logout via omarchy-system-logout (uwsm stop); upgrade.sh enforces it on existing installs ([`dda5af7`](https://github.com/deoxizn/omartia-dots-remux/commit/dda5af7))
- 13:58 — Self-contained omartia-logout (detached uwsm stop) for SDDM-safe exit ([`a69d3bb`](https://github.com/deoxizn/omartia-dots-remux/commit/a69d3bb))
- 13:57 — Logout via omarchy-system-logout (uwsm stop) so sddm-helper exits cleanly ([`dbb53ef`](https://github.com/deoxizn/omartia-dots-remux/commit/dbb53ef))
- 13:47 — Refresh pacman dbs and offer omarchy-update before installing deps ([`af61968`](https://github.com/deoxizn/omartia-dots-remux/commit/af61968))
- 13:37 — Upgrade.sh merges lua config changes and syncs keybinds via managed block ([`61c3d55`](https://github.com/deoxizn/omartia-dots-remux/commit/61c3d55))
- 07:33 — Log out via hyprctl dispatch exit, not loginctl terminate-user ([`ac0d6ed`](https://github.com/deoxizn/omartia-dots-remux/commit/ac0d6ed))
- 07:22 — Swap quickshell-git to stable in one atomic transaction ([`68168ed`](https://github.com/deoxizn/omartia-dots-remux/commit/68168ed))
- 06:33 — Session-start preflight with auto-rollback ([`fd9c79b`](https://github.com/deoxizn/omartia-dots-remux/commit/fd9c79b))

## 2026-08-20

- 23:13 — Add upgrade.sh: idempotent sync for existing installs (scripts, theme hook, update guard, missing menu keybinds, config drift report) ([`ee3ef1f`](https://github.com/deoxizn/omartia-dots-remux/commit/ee3ef1f))
- 23:07 — Omartia menu suite: full fuzzel menu set (root, power, keybinds, themes+previews, packages, update+channel, config, defaults, restart) themed from live caelestia scheme; installer ships all scripts + updated bindings; uninstall removes them ([`8a6f8fe`](https://github.com/deoxizn/omartia-dots-remux/commit/8a6f8fe))
- 21:32 — Actually ship the 25deg tertiary rotation in the bridge hook ([`9416970`](https://github.com/deoxizn/omartia-dots-remux/commit/9416970))
- 21:32 — Tertiary hue rotation 60->25deg; enable sidebar showOnHover by default ([`2176ba1`](https://github.com/deoxizn/omartia-dots-remux/commit/2176ba1))
- 21:06 — Theme bridge never hot-reloaded (missing flavour key aborted Colours.load) ([`7d9943e`](https://github.com/deoxizn/omartia-dots-remux/commit/7d9943e))
- 20:34 — Guard omarchy-restart-shell so omarchy-update can't resurrect omarchy-shell ([`2c47691`](https://github.com/deoxizn/omartia-dots-remux/commit/2c47691))
- 16:31 — Inject autostart stub after bootstrap.lua so it survives module reloads ([`015ad95`](https://github.com/deoxizn/omartia-dots-remux/commit/015ad95))
- 16:31 — Per-monitor Caelestia overlays; hide xgps/xgpsspeed from launcher ([`3ee6b8f`](https://github.com/deoxizn/omartia-dots-remux/commit/3ee6b8f))
- 14:48 — Remove stray autostart.lua from repo root ([`dee438c`](https://github.com/deoxizn/omartia-dots-remux/commit/dee438c))
- 14:48 — Chain autostart, disable omarchy bar, package.loaded override, dry-run ([`456dd05`](https://github.com/deoxizn/omartia-dots-remux/commit/456dd05))
- 12:56 — Change dashboard keybind from SUPER+D to SUPER+ALT+D ([`d2f7267`](https://github.com/deoxizn/omartia-dots-remux/commit/d2f7267))
- 12:43 — Add sidebar and dashboard keybinds to auto-injected bindings ([`ebdd33d`](https://github.com/deoxizn/omartia-dots-remux/commit/ebdd33d))
- 12:32 — Remove showOnHover from shipped sidebar config ([`80e7a50`](https://github.com/deoxizn/omartia-dots-remux/commit/80e7a50))
- 12:31 — Enable sidebar showOnHover and add missing keybindings ([`f445d18`](https://github.com/deoxizn/omartia-dots-remux/commit/f445d18))
- 12:26 — Add btop and fcitx5 entries to hiddenApps ([`9b8e794`](https://github.com/deoxizn/omartia-dots-remux/commit/9b8e794))
- 12:23 — Use proper desktop file IDs for hiddenApps and fix launcher binding ([`098bac5`](https://github.com/deoxizn/omartia-dots-remux/commit/098bac5))
- 12:16 — Add ttf-material-symbols-variable as dependency ([`e9fc7ff`](https://github.com/deoxizn/omartia-dots-remux/commit/e9fc7ff))
- 12:16 — Pass hl.dsp.global dispatcher directly instead of wrapping in function ([`bddc92a`](https://github.com/deoxizn/omartia-dots-remux/commit/bddc92a))
- 11:49 — Auto-detect monitor resolution for monitors.lua ([`6470901`](https://github.com/deoxizn/omartia-dots-remux/commit/6470901))
- 11:35 — Add systemd env import before starting caelestia-shell service ([`8fb7218`](https://github.com/deoxizn/omartia-dots-remux/commit/8fb7218))
- 11:31 — Offer auto-logout after install to start Caelestia Shell ([`8fee785`](https://github.com/deoxizn/omartia-dots-remux/commit/8fee785))
- 11:13 — Patch configs instead of replacing, stop killing omarchy-shell ([`dba9c97`](https://github.com/deoxizn/omartia-dots-remux/commit/dba9c97))
- 09:58 — Handle omarchy-dev dependency when switching from quickshell-git to stable ([`c0573eb`](https://github.com/deoxizn/omartia-dots-remux/commit/c0573eb))
- 09:39 — Add quickshell-git detection, version check, and cmake diagnostics ([`5708e0a`](https://github.com/deoxizn/omartia-dots-remux/commit/5708e0a))
- 04:07 — Remove static systemd service file (generated dynamically during install) ([`a399ba7`](https://github.com/deoxizn/omartia-dots-remux/commit/a399ba7))
- 04:06 — Fix install/uninstall robustness and update README ([`751791a`](https://github.com/deoxizn/omartia-dots-remux/commit/751791a))
- 03:53 — Add hiddenApps to Caelestia launcher config ([`feef7ca`](https://github.com/deoxizn/omartia-dots-remux/commit/feef7ca))
- 03:23 — Hide omarchy preinstall apps from Caelestia launcher when preinstalls-removed state exists ([`c86beee`](https://github.com/deoxizn/omartia-dots-remux/commit/c86beee))
- 02:44 — Add caelestia-cli runtime deps (grim, slurp, wl-clipboard, etc) ([`0dc81d5`](https://github.com/deoxizn/omartia-dots-remux/commit/0dc81d5))
- 02:29 — Keep sidebar showOnHover as default off ([`4a7154a`](https://github.com/deoxizn/omartia-dots-remux/commit/4a7154a))
- 02:27 — Enable sidebar showOnHover ([`bf2aae1`](https://github.com/deoxizn/omartia-dots-remux/commit/bf2aae1))
- 02:17 — Remove invalid config keys, fix autostart, add caelestia-cli dep ([`91053a3`](https://github.com/deoxizn/omartia-dots-remux/commit/91053a3))

## 2026-08-19

- 23:03 — Don't overwrite existing bindings.lua on install ([`87208c1`](https://github.com/deoxizn/omartia-dots-remux/commit/87208c1))
- 22:59 — Restore all custom app bindings from user's original config ([`9631049`](https://github.com/deoxizn/omartia-dots-remux/commit/9631049))
- 22:58 — Fix bindings: use hl.dsp.global() for Caelestia shortcuts ([`d8eae60`](https://github.com/deoxizn/omartia-dots-remux/commit/d8eae60))
- 22:51 — Fix cava dep: use libcava AUR package (provides .pc file) ([`6c526a0`](https://github.com/deoxizn/omartia-dots-remux/commit/6c526a0))
- 22:48 — Add ALL Caelestia Shell build deps at once ([`e625f2e`](https://github.com/deoxizn/omartia-dots-remux/commit/e625f2e))
- 22:44 — Add aubio, libqalculate, libpipewire to dependencies ([`0b915ca`](https://github.com/deoxizn/omartia-dots-remux/commit/0b915ca))
- 22:39 — Add qt6-shadertools to dependencies (fixes cmake build) ([`906fa6b`](https://github.com/deoxizn/omartia-dots-remux/commit/906fa6b))
- 22:32 — Initial release: Caelestia Shell + Omarchy theme bridge ([`d77f650`](https://github.com/deoxizn/omartia-dots-remux/commit/d77f650))
