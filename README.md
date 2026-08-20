# omartia-dots-remux

Drop-in replacement for omarchy-shell (quattro bar) with **Caelestia Shell** — keeps omarchy's theme switching working via a color bridge.

## What this does

- **Replaces** omarchy-shell (bar, notifications, OSD, menu) with Caelestia Shell
- **Bridges** omarchy themes → Caelestia's Material Design 3 color system
- **Keeps** all omarchy keybindings, workspace management, and theme switching

## What you get

| Feature | Source |
|---|---|
| Status bar | Caelestia Shell |
| Lock screen | Caelestia Shell (animated) |
| App launcher | Caelestia Shell (Super+Space) |
| Dashboard | Caelestia Shell (media, weather, stats) |
| OSD (volume/brightness) | Caelestia Shell |
| Theme switching | `omarchy-theme-set` (native, works as before) |
| Window management | Omarchy keybindings (unchanged) |

## Quick install

```bash
git clone https://github.com/deoxizn/omartia-dots-remux.git
cd omartia-dots-remux
./install.sh
```

The installer will:
1. Install build dependencies (cmake, ninja, qt6)
2. Build and install Caelestia Shell from source
3. Backup your existing configs
4. Copy the new configs
5. Set up the theme bridge hook
6. Sync your current theme

## After install

1. Edit `~/.config/hypr/monitors.lua` for your displays
2. Edit `~/.config/hypr/input.lua` for your keyboard
3. Log out and back in
4. Test: `SUPER+Space` (launcher), `SUPER+L` (lock), `omarchy-theme-set <theme>`

## Keybindings

| Binding | Action |
|---|---|
| `SUPER+Space` | Caelestia launcher (apps, wallpaper, schemes, system) |
| `SUPER+Alt+Space` | Session menu (logout, shutdown, reboot) |
| `SUPER+Return` | Terminal |
| `SUPER+Shift+Return` | Browser |
| `SUPER+Shift+F` | File manager |
| `SUPER+Shift+N` | Editor |
| `SUPER+K` | Keybinding list |
| `SUPER+Q` | Close window |
| `SUPER+1-0` | Switch workspace |
| `SUPER+Arrow` | Move/resize windows |
| `PRINT` | Screenshot |

## Uninstall

```bash
./uninstall.sh
```

Restores all backed-up configs and removes Caelestia Shell configs. Log out/in to restore omarchy-shell.

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
- cmake, ninja, qt6-base, qt6-declarative, qt6-svg (installer handles this)

## Credits

- [Omarchy](https://github.com/basecamp/omarchy) — window manager, theme system, keybindings
- [Caelestia Shell](https://github.com/caelestia-dots/shell) — desktop shell, lock screen, launcher
- Original [omartia-dots](https://github.com/Z-Rh0/omartia-dots) — inspiration for combining both
