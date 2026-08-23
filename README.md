<div align="center">

<img src="stellarchy-nobg.png" alt="Stellarchy" width="180">

```
███████╗████████╗███████╗██╗     ██╗      █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗
██╔════╝╚══██╔══╝██╔════╝██║     ██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝
███████╗   ██║   █████╗  ██║     ██║     ███████║██████╔╝██║     ███████║ ╚████╔╝
╚════██║   ██║   ██╔══╝  ██║     ██║     ██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝
███████║   ██║   ███████╗███████╗███████╗██║  ██║██║  ██║╚██████╗██║  ██║   ██║
╚══════╝   ╚═╝   ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝
```

### ✦ Stellarchy ✦

Omarchy × Caelestia · `omartia-dots-remux`

</div>

Replaces omarchy-shell (quattro bar, menus, lock) with **Caelestia Shell** — keeps omarchy's theme switching working via a color bridge. Read [READ THIS FIRST](#read-this-first) before installing: this is a shell replacement, not a theme.

<p align="center">
  <img src="desktop.png" alt="Desktop" width="1280">
</p>
<p align="center">
  <img src="lockscreen2.png" alt="Lock screen" width="1280">
</p>

[Preview video](previewvideo.mp4)

## READ THIS FIRST

**This is not a theme or a plugin — it is a shell replacement.** It removes
`omarchy-shell` from your system and rebuilds everything that depended on it.
That means some things you may use daily in stock Omarchy **stop existing**
until something replaces them: several default keybindings routed into
`omarchy-shell` become silent no-ops, the omarchy-shell menus disappear, and
the lock/idle path changes. This repo rebinds or replaces every dead path it
can (see the matrix below), but you should expect Omarchy to *not* behave
stock out of the box. Read this file before installing; if you want stock
behavior with a different bar, this remux is not that.

### No plugin support — that's quattro-specific

New users often don't realize that in stock Omarchy, **"the Shell" is a single
program** (`omarchy-shell`) that draws and controls *everything* visual: the
bar, menus, launcher, lock screen, notifications and OSD. Plugin support was
introduced in quattro and lives inside that program only — bar widgets,
panels, overlays, menus and services from `~/.config/omarchy/plugins/` are
loaded dynamically into `omarchy-shell` at runtime. They are not an Omarchy or
Hyprland feature.

Because this remux removes `omarchy-shell`, quattro plugins have nothing to
load into and will silently disappear after installing. Caelestia Shell has
its own fixed module set and **no plugin loader**, so there is currently no
equivalent way to extend it. If you depend on an omarchy-shell plugin, stay on
stock Omarchy or look for a Caelestia-native alternative.

### What happens to stock Omarchy parts

| Stock Omarchy | In omartia | Replacement / notes |
|---|---|---|
| omarchy-shell (bar, notifications, OSD) | **Removed** | Caelestia Shell provides all three |
| omarchy-shell lock screen | **Removed** | Caelestia session lock via `caelestia-system-lock` (also turns displays off ~20s after locking) |
| omarchy-shell menus (root/power/keybinds/themes/packages/update/config/defaults) | **Removed** | Fuzzel suite `omartia-*`, themed from the live Caelestia scheme |
| `omarchy-menu toggle apps/root` | **Rebound** | SUPER+Space → Caelestia launcher, SUPER+Alt+Space → Omartia root menu |
| Media keys (`XF86Audio*`) | **Were dead**, now rebound | `omartia-media` — controls whichever MPRIS player is currently playing (Spotify, browser, mpv, anything); no hardcoded app |
| Clipboard panel (`SUPER+CTRL+V`) | **Was dead**, now rebound | `caelestia clipboard` |
| Emoji picker (`SUPER+CTRL+E`) | **Was dead**, now rebound | `caelestia emoji` |
| Dismiss notifications (`SUPER+,`) | **Partially replaced** | Clears all notifications via Caelestia IPC; per-notification dismiss has no equivalent |
| Invoke last / notification history | **Gone** | No Caelestia IPC equivalent exists |
| Audio/BT/network/calendar panels (`SUPER+CTRL+A/B/W/ALT+D`) | **Unbound** | Retired — the Caelestia dashboard (`SUPER+Alt+D`) covers audio/BT/network/calendar |
| Power panel (`SUPER+CTRL+P`) | **Rebound** | Opens the Caelestia session menu |
| Bar panel chords (`SUPER+CTRL+F1-F9`) | **Unbound** | Caelestia's bar has no panel-at-index IPC |
| Idle lock / suspend wiring | **Replaced** | Managed `hypridle.conf`: locks through `caelestia-system-lock`, DPMS-off after lock, suspend-then-hibernate at 10 min |
| Theme switching (`omarchy-theme-set`) | **Works as before** | A hook bridges each theme's colors.toml into Caelestia's M3 scheme live |
| Window management, workspaces, app binds | **Work as before** | Untouched Omarchy defaults |

Anything not listed here that shells out to `omarchy-shell` elsewhere in your
own scripts will also be dead — grep for it.

## Quick install

```bash
git clone https://github.com/deoxizn/omartia-dots-remux.git
cd omartia-dots-remux
./install.sh
```

Use `./install.sh -y` to skip confirmation prompts.

**Optional flags:**
```bash
./install.sh --cachyos-kernel   # opt into the CachyOS BORE kernel (see below)
./install.sh --dry-run          # preview everything without touching anything
```

**Already running the remux?** Don't reinstall — just upgrade:
```bash
./upgrade.sh
```
This pulls the latest repo, refreshes the menu scripts / theme bridge hook /
update guard in place, 3-way-merges lua config changes into your live files
(personal edits preserved; conflicts leave your file untouched with a
`.conflict` copy for manual resolution), keeps keybinds identical to the repo
via a managed block at the end of `bindings.lua` (legacy auto-injected blocks
are stripped automatically — duplicates made toggle binds fire twice and look
dead), and enforces the SDDM-safe `omarchy-system-logout`.
`monitors.lua` / `input.lua` are never touched (device-specific); everything
else is reported as drift. Add `--dry-run` to preview, or `--adopt-lua` to
adopt repo versions of lua files that have no merge history (yours is backed
up first).

**Upgrade flags for opt-in extras:**
```bash
./upgrade.sh --bore       # switch to the CachyOS BORE kernel (chaotic-aur, prebuilt)
./upgrade.sh --plymouth   # adopt the Stellarchy boot splash (rebuilds initramfs)
```

## Stellarchy branding

The remux ships its own identity on top of Omarchy. What lands where:

| Touchpoint | New installs | Existing installs (`./upgrade.sh`) |
|---|---|---|
| Idle screensaver art | Installed | Installed if missing or still stock Omarchy art; **your own customization is never overwritten** |
| About logo (`about.txt`) | Installed | Same stock-detection rule |
| fastfetch OS line | If you have no own config, one is seeded from `/etc/fastfetch` with a `Stellarchy` OS line; custom configs are untouched | Same |
| Boot splash | `stellarchy` plymouth theme set as default (sparkle logo, Tokyo Night palette) | Opt-in via `./upgrade.sh --plymouth`; afterwards kept refreshed automatically |
| Script headers / menu About entry | Included | Synced with the menu suite |

Revert the splash anytime: `sudo plymouth-set-default-theme omarchy && sudo limine-mkinitcpio`.

The `stellarchy` theme dir vendors Omarchy's `omarchy.script` instead of referencing it across theme dirs: mkinitcpio's plymouth hook only packs the active theme's own directory into the initramfs, so a cross-dir `ScriptFile=` ships an initramfs with no splash script at all — plymouth renders nothing, and both the splash *and the LUKS passphrase prompt* are invisible (a black screen that looks like a dead boot). Install/upgrade refresh the vendored script from upstream on every run and refuse to switch themes or rebuild the initramfs if the theme isn't self-contained.

### CachyOS BORE kernel (opt-in)

BORE tunes CPU scheduling for desktop/game interactivity — a good fit for
gaming rigs, pointless for rarely-used machines. It comes prebuilt from
[chaotic-aur](https://aur.chaotic.cx), so no compiling.

- **New installs:** answer the prompt, or pass `--cachyos-kernel`
- **Existing installs:** `./upgrade.sh --bore`

What it does: adds chaotic-aur to pacman (backing up `pacman.conf` first),
installs `linux-cachyos-bore` + headers (DKMS modules like NVIDIA rebuild
automatically), and aims the `default_entry:` header in `/boot/limine.conf`
at the BORE entry — its index is computed from the live config each run, so
it survives kernel add/remove and snapshot churn (the header itself survives
`limine-update`; only Omarchy's manual refresh script resets it). The stock
Arch kernel is never removed — if anything ever misbehaves, pick it in the
Limine menu and revert with one `default_entry:` edit + `sudo limine-update`.

**Scope:** chaotic-aur is a plain signed binary repo, not a build system
change — nothing installs itself, nothing compiles differently, and your
yay/paru workflow is untouched. Only explicitly-requested packages come from
it (afterwards the kernel updates through normal `omarchy-update`). Your AUR
helper will simply *also* offer prebuilt chaotic builds where they exist,
asking which to use per install. The whole CachyOS kernel family
(`linux-cachyos`, `-lts`, RT variants...) is available the same way once the
repo exists. Full opt-out: remove the `[chaotic-aur]` block from
`/etc/pacman.conf`.

The installer will:
1. Install build dependencies (cmake, ninja, qt6, etc.)
2. Build and install Caelestia Shell from source
3. Backup your existing configs
4. Copy the new configs (skips hypr files that already exist). `looknfeel.lua` ships a managed scale-aware corner-rounding block; on first install you're asked for an explicit Hyprland monitor scale + GTK scale (defaults detected from your panel) instead of Hyprland's DPI-guessed `"auto"`, which tends to oversize UI on laptop screens — `-y` takes the detected defaults
5. Patch `hyprland.lua` to disable omarchy's default autostart (via Lua `package.loaded`, injected after Omarchy's bootstrap — survives pacman updates and config reloads)
6. Patch `autostart.lua` to launch Caelestia Shell and take over the non-shell parts of Omarchy's autostart (monitor watch, automount, post-boot hooks)
7. Set up the systemd service (auto-restart on crash)
8. Set up the theme bridge hook
9. Install `caelestia-system-lock` and the managed `hypridle.conf` so idle lock matches the manual lock path (existing hypridle.conf is never overwritten; upgrades land as `.new`)
10. Apply Caelestia shell patches from [`patches/`](patches/) — currently a self-heal for Quickshell's Hyprland event tracking, which can go stale across suspend/DPMS/multi-monitor transitions and force-close drawers (launcher/dashboard) the moment they open. Patches are applied idempotently after clone/update and survive upstream pulls
11. Install the omarchy-update guard — `omarchy-update` ends with `omarchy-restart-shell`, which hard-relaunches omarchy-shell over Caelestia. The guard makes it exit early while Caelestia is running, and a libalpm hook re-applies it after every omarchy package upgrade
12. Install the omartia fuzzel menu suite and `omartia-media` to `~/.local/bin/` (root menu includes an **About** entry)
13. Seed `~/.config/fastfetch/config.jsonc` from the system default with a `Stellarchy` OS line — only if you have no own fastfetch config; custom configs are untouched
14. Deploy Stellarchy screensaver + About art (`~/.config/omarchy/branding/`) — replaces files still identical to Omarchy's stock art, never genuine customization
15. Set up the `stellarchy` plymouth splash (sparkle logo, vendored Omarchy boot script) and rebuild the initramfs so it's live on next boot
16. Optionally install the CachyOS BORE kernel via chaotic-aur and make it the default Limine entry (interactive prompt, or `--cachyos-kernel`; skipped under `-y` unless the flag is passed) — see [CachyOS BORE kernel](#cachyos-bore-kernel-opt-in)
17. Sync your current theme
18. Run the session-start preflight (see [Install safety net](#install-safety-net-preflight))
19. Auto-logout after 5 seconds — **only if every preflight check passed** (press Ctrl+C to cancel). Uses `omarchy-system-logout` (`uwsm stop`), so the session ends cleanly and you land back at the login screen

## Install safety net (preflight)

Before the installer offers to log you out, it verifies the exact chain your
**next login** depends on:

- `hyprland.lua` autostart stub is correctly placed (after Omarchy's bootstrap, before its defaults load)
- Omarchy still loads `hypr.autostart` and still ships the APIs the launch handler uses (`o.launch`, `hyprland.start`) — catches upstream layout drift on fresh installs
- `autostart.lua` registers the Caelestia launch handler and parses as valid Lua
- `caelestia-shell.service` exists, is enabled, points at a real binary, and passes `systemd-analyze --user verify`

**All checks pass** → normal logout prompt, Caelestia takes over.

**Any check fails** → automatic rollback instead of a dead session:

1. `hyprland.lua`, `autostart.lua`, `bindings.lua` restored from the backup taken at install start (injected blocks stripped surgically if no backup exists)
2. `caelestia-shell.service` disabled so stock omarchy-shell owns startup again

Your PC stays fully usable as stock Omarchy — logging out or rebooting is safe.
The terminal prints exactly which checks failed; everything, including what was
rolled back, lands in `~/omartia-preflight.log`. Send that file for help or hand
it to your AI agent, then fix and re-run `./install.sh` — or `./uninstall.sh`
to remove everything.

**Caelestia didn't start after install** (e.g. an install from before this
existed)? Press `Ctrl+Alt+F4` for a TTY, log in, then:

```bash
cat ~/omartia-preflight.log                     # see what's wrong
systemctl --user start caelestia-shell.service  # bring the shell back now
```

## After install

1. Edit `~/.config/hypr/monitors.lua` for your displays
2. Edit `~/.config/hypr/input.lua` for your keyboard
3. Log out and back in
4. Test: `SUPER+Space` (launcher), `SUPER+Ctrl+L` (lock), `omarchy-theme-set <theme>`

**Reinstalling?** Existing hypr configs (`hyprland.lua`, `autostart.lua`, `looknfeel.lua`, `monitors.lua`, `input.lua`, `bindings.lua`) are never overwritten — edit them directly or restore from backup at `~/.config/omartia-dots-remux-backup/`.

## Keybindings

| Binding | Action |
|---|---|
| `SUPER+Space` | Caelestia launcher (apps, wallpaper, schemes, system) |
| `SUPER+Alt+Space` | Omartia root menu |
| `SUPER+N` | Caelestia sidebar / notifications shade |
| `SUPER+Alt+D` | Caelestia dashboard (media, weather, stats, network, BT) |
| `SUPER+Escape` | Power menu (confirm guard on reboot/shutdown) |
| `SUPER+Ctrl+L` | Lock via Caelestia (`caelestia-system-lock`) |
| `Media keys` | Play/pause, next, previous — any MPRIS player via `omartia-media` |
| `SUPER+Ctrl+V` / `SUPER+Ctrl+E` | Clipboard history / emoji picker |
| `SUPER+,` | Clear notifications |
| `SUPER+Ctrl+P` | Session menu |
| `SUPER+Return` | Terminal |
| `SUPER+Shift+Return` | Browser |
| `SUPER+Shift+F` | File manager |
| `SUPER+Shift+N` | Editor |
| `SUPER+K` | Keybinding list (fuzzel) |
| `SUPER+Q` | Close window |
| `SUPER+1-0` | Switch workspace |
| `SUPER+Arrow` | Move/resize windows |
| `PRINT` | Screenshot |

Everything else inherits from stock Omarchy — run `omartia-keybinds` for the
full searchable list. Stock's panel chords (`SUPER+Ctrl+A/B/W/Alt+D`) are
unbound; the dashboard on `SUPER+Alt+D` covers what they did.

## Menu suite

The omarchy-shell menus are recreated as standalone fuzzel scripts in
[`scripts/`](scripts/) (installed to `~/.local/bin/`). All of them are themed
from the live Caelestia scheme via the shared `omartia-fuzzel` wrapper, so
they restyle automatically on every theme switch. Esc navigates back one menu
level.

| Script | Purpose |
|---|---|
| `omartia-menu` | Root menu: Keybindings, Themes, Packages, Update, Config, Defaults, Restart, Session |
| `omartia-power` | Lock, logout, suspend, hibernate, reboot, shutdown (destructive actions require Confirm) |
| `omartia-keybinds` | Searchable keybinding list that dispatches binds (`--menu` for Esc-back) |
| `omartia-themes` / `omartia-themes-list` | Theme switcher with preview thumbnails + git theme install |
| `omartia-pkgs` | Package TUI launcher: install, remove, AUR |
| `omartia-update` | System/theme/firmware updates + package channel switcher |
| `omartia-config` | Edit `~/.config/hypr/*.{lua,conf}` in your default editor |
| `omartia-defaults` | Default browser/editor/terminal/agent pickers (includes installed beta/nightly browsers) |
| `omartia-restart` | Reload Hyprland, restart terminal/Caelestia shell, refresh theme |
| `omartia-media` | Universal MPRIS media control — targets whichever player is currently playing |
| `caelestia-system-lock` | Lock via Caelestia + kb-layout reset + 1Password lock + delayed display-off (used by keybind, power menu and hypridle) |
| `omartia-fuzzel` | Shared fuzzel wrapper — reads colors from `~/.local/state/caelestia/scheme.json` |

## Known limitations

Honest list of what does **not** work like stock Omarchy:

- **Per-notification actions are reduced**: no dismiss-single, no invoke-last,
  no notification history keybindings. Caelestia exposes only clear-all/DND.
- **No bar panel chords**: stock's `SUPER+CTRL+F1-F9` panel toggles have no
  Caelestia equivalent and are unbound.
- **Caelestia is a different shell**: bar layout, popouts, launcher UX,
  dashboard content and lock screen all behave like Caelestia, not quattro.
  Per-monitor config exists natively (`~/.config/caelestia/monitors/<SCREEN>/shell.json`).
- **Quickshell bugs ship with the shell**: the shell tracks Hyprland state via
  events that can be missed across suspend/multi-monitor transitions; this
  repo patches around the known drawer-killing staleness in
  [`patches/`](patches/). If Caelestia misbehaves after an upstream update,
  check whether a patch stopped applying (`install.sh` warns when so).
- **Quattro plugins don't work**: plugin support (bar widgets, panels,
  overlays, menus, services) shipped with quattro's `omarchy-shell` and is
  specific to that shell — Omarchy/Hyprland themselves don't provide it. With
  `omarchy-shell` removed there is nothing to load
  `~/.config/omarchy/plugins/` into; Caelestia has no plugin system.
- **`omarchy-shell` IPC callers die**: any personal script calling
  `omarchy-shell <...>` needs porting to `qs -c caelestia ipc call ...`,
  `playerctl`, or the omartia suite.

## Uninstall

```bash
./uninstall.sh
```

Restores all backed-up configs, stops and removes the Caelestia Shell systemd service, and removes Caelestia Shell configs (including the update guard — which also self-neutralizes once Caelestia is no longer running). Log out/in to restore omarchy-shell.

## How the theme bridge works

```
omarchy-theme-set <name>
  → generates ~/.local/state/omarchy/current/theme/colors.toml
  → hook fires: caelestia-sync.sh
  → reads colors.toml, maps to M3 tokens
  → writes ~/.local/state/caelestia/scheme.json
  → Caelestia Shell auto-reloads (FileView watcher)
```

Any omarchy theme works automatically. No per-theme configuration needed.

## Requirements

- Arch Linux (or Arch-based distro)
- Omarchy 4.0 (quattro) installed
- Quickshell (`qs` or `quickshell` in PATH)
- cmake, ninja, base-devel (installer handles these and other deps)
- AUR helper (yay or paru) for libcava, caelestia-cli

## Credits

- [Omarchy](https://github.com/basecamp/omarchy) — window manager, theme system, keybindings
- [Caelestia Shell](https://github.com/caelestia-dots/shell) — desktop shell, lock screen, launcher
- Original [omartia-dots](https://github.com/Z-Rh0/omartia-dots) — inspiration for combining both
