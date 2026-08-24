# Hidden Commands

Stellarchy keeps the menu lean — these are stock Omarchy actions that still work
on this system but don't appear anywhere in the fuzzel suite. Run them in any
terminal, or bind your favorites in `~/.config/hypr/bindings.lua`.

> Commands that stock Omarchy wraps in a floating presentation window are listed
> bare here — same effect, minus the wrapper. A few quattro-shell-only rows
> (bar toggles, plugins, emoji panel, battery percentage, About screen) are left
> out entirely since they drive parts of Omarchy this remux replaces.

## Learn

| | |
|---|---|
| Omarchy manual | `omarchy-launch-webapp 'https://omarchy.org/manual/'` |
| Hyprland wiki | `omarchy-launch-webapp 'https://wiki.hypr.land/'` |
| Arch wiki | `omarchy-launch-webapp 'https://wiki.archlinux.org/title/Main_page'` |
| LazyVim keymaps | `omarchy-launch-webapp 'https://www.lazyvim.org/keymaps'` |
| Bash cheatsheet | `omarchy-launch-webapp 'https://devhints.io/bash'` |
| Community Discord | `omarchy-launch-discord-community` |

## Capture

| | |
|---|---|
| Screenshot | `omarchy-capture-screenshot` |
| Screenrecord (no audio) | `omarchy-capture-screenrecording` |
| Screenrecord (desktop audio) | `omarchy-capture-screenrecording --with-desktop-audio` |
| Screenrecord (desktop + mic) | `omarchy-capture-screenrecording --with-desktop-audio --with-microphone-audio` |
| Screenrecord (+ webcam) | `omarchy-capture-screenrecording-with-webcam` |
| Stop recording | `omarchy-capture-screenrecording --stop-recording` |
| OCR text from region | `omarchy-capture-text` |
| Decode QR from region | `omarchy-capture-qr` |
| Color picker | `pkill hyprpicker \|\| hyprpicker -a` |
| Transcode media | `omarchy-transcode` |

## Reminders

| | |
|---|---|
| Set a reminder | `omarchy-reminder -i` |
| Quick reminder | `omarchy-reminder 30 "Check the oven"` |
| Clear all | `omarchy-reminder clear` |

(`omarchy-reminder show` needs the quattro shell panel, so it's a no-op here.)

## Share

| | |
|---|---|
| Share clipboard | `omarchy-menu-share clipboard` |
| Share a file | `omarchy-menu-share file` |
| Share a folder | `omarchy-menu-share folder` |
| Receive (LocalSend) | `uwsm-app -- localsend` |

## Toggles

| | |
|---|---|
| Stay awake (idle/lock) | `omarchy-toggle-idle` |
| Nightlight | `omarchy-toggle-nightlight` |
| Notification silencing | `omarchy-toggle-notification-silencing` |
| Crash capture | `omarchy-toggle-crash-capture` |
| Screensaver | `omarchy-toggle-screensaver` |
| Workspace layout | `omarchy-hyprland-workspace-layout-toggle` |
| Window gaps | `omarchy-hyprland-window-gaps-toggle` |
| 1-window ratio | `omarchy-hyprland-window-single-square-aspect-toggle` |

Dell XPS haptic touchpad levels: `dell-xps-touchpad-haptics set low|mid|high`.

## Style

| | |
|---|---|
| Set background | `omarchy-theme-bg-set "<background>"` |
| Reset boot splash | `omarchy-plymouth-reset` |
| Boot splash from theme | `omarchy-plymouth-set-by-theme "<theme>"` |
| Font: Cascadia Mono | `omarchy-install-font 'Cascadia Mono' ttf-cascadia-mono-nerd 'CaskaydiaMono Nerd Font'` |
| Font: Meslo LG Mono | `omarchy-install-font 'Meslo LG Mono' ttf-meslo-nerd 'MesloLGL Nerd Font'` |
| Font: Fira Code | `omarchy-install-font 'Fira Code' ttf-firacode-nerd 'FiraCode Nerd Font'` |
| Font: Victor Code | `omarchy-install-font 'Victor Code' ttf-victor-mono-nerd 'VictorMono Nerd Font'` |
| Font: Bitstream Vera | `omarchy-install-font 'Bitstream Vera Code' ttf-bitstream-vera-mono-nerd 'BitstromWera Nerd Font'` |
| Font: Iosevka | `omarchy-install-font Iosevka ttf-iosevka-nerd 'Iosevka Nerd Font Mono'` |

## Setup

| | |
|---|---|
| Edit XCompose | `omarchy-launch-config-editor ~/.XCompose && omarchy-restart-xcompose` |
| Direct boot (skip GRUB/Limine menu) | `omarchy-setup-direct-boot` |
| Factory reset (btrfs only) | `omarchy-system-factory-reset` |

Factory reset rolls the system back to stock snapshots — **it will undo the
remux**. Know what you're doing.

## Install

Gaming:

| | |
|---|---|
| Steam | `omarchy-install-gaming-steam` |
| RetroArch | `omarchy-install-gaming-retroarch` |
| RetroArch game launcher | `omarchy-games-retro-install` |
| Minecraft | `omarchy-install-and-launch Minecraft minecraft-launcher minecraft-launcher` |
| NVIDIA GeForce NOW | `omarchy-install-gaming-geforce-now` |
| Xbox Cloud Gaming | `omarchy-install-gaming-xbox-cloud` |
| Xbox controllers | `omarchy-install-gaming-xbox-controllers` |
| Battle.net | `omarchy-install-gaming-battlenet` |
| Lutris | `omarchy-install-gaming-lutris` |
| Heroic (Epic Games) | `omarchy-install-gaming-heroic` |

Browsers: `omarchy-install-browser chrome|edge|brave|brave-origin|firefox|zen`

Services:

| | |
|---|---|
| 1Password | `omarchy-install-service-1password` |
| Bitwarden | `omarchy-install-and-launch Bitwarden 'bitwarden bitwarden-cli' bitwarden` |
| Dropbox | `omarchy-install-service-dropbox` |
| Spotify | `omarchy-install-service-spotify` |
| Signal | `omarchy-install-service-signal` |
| Tailscale | `omarchy-install-service-tailscale` |
| NordVPN | `omarchy-install-service-nordvpn` |
| ONCE | `omarchy-install-service-once` |
| Chromium Google account | `omarchy-install-chromium-google-account` |

Editors:

| | |
|---|---|
| VSCode | `omarchy-install-editor-vscode` |
| Zed | `omarchy-install-editor-zed` |
| Helix | `omarchy-install-editor-helix` |
| Emacs | `omarchy-install-editor-emacs` |
| Cursor | `omarchy-install-and-launch Cursor cursor-bin cursor` |
| Sublime Text | `omarchy-install-and-launch 'Sublime Text' sublime-text-4 sublime_text` |
| Vim | `omarchy-install-app Vim vim` |

Terminals: `omarchy-install-terminal alacritty|foot|ghostty|kitty`

AI:

| | |
|---|---|
| ChatGPT Desktop | `omarchy-install-ai-chatgpt` |
| Dictation (Voxtype) | `omarchy-voxtype-install` |
| Grok Bot | `omarchy-install-and-launch 'Grok Bot' grok-bot grok-bot` |
| LM Studio | `omarchy-install-app 'LM Studio' lmstudio-bin` |
| Ollama | `omarchy-install-app Ollama ollama` (`ollama-cuda` / `ollama-rocm` per GPU) |
| T3 Code | `omarchy-install-and-launch 'T3 Code' t3code-bin t3code` |

Development environments: `omarchy-install-dev-env <env>` for
`ruby`, `go`, `php`, `laravel`, `symfony`, `python`, `elixir`, `phoenix`,
`zig`, `rust`, `java`, `dotnet`, `ocaml`, `clojure`, `scala`, `node`, `bun`,
`deno` — plus `omarchy-install-docker-dbs` for containerized databases.

Extras: `omarchy-tui-install` (TUI apps), `omarchy-windows-vm install`
(Windows VM), `omarchy-install-preinstalls` (bring back removed defaults).

## Remove

Everything above has a mirror where it makes sense:
`omarchy-remove-browser <browser>`, `omarchy-remove-gaming-<name>`,
`omarchy-remove-service-dropbox|tailscale`, `omarchy-remove-ai-<name>`,
`omarchy-remove-dev-env <env>`, `omarchy-voxtype-remove`,
`omarchy-tui-remove`, `omarchy-windows-vm remove`,
`omarchy-remove-preinstalls`.

Security removals (their setup half *is* in the menu):
`omarchy-remove-security-fingerprint`, `omarchy-remove-security-fido2`,
`omarchy-remove-security-sshd`.

## Update

| | |
|---|---|
| Drive encryption password | `omarchy-drive-password` |
| User password | `passwd` |
| Sync system clock | `omarchy-update-time` |
| Reset Hyprland config | `omarchy-refresh-hyprland` |
| Reset hyprsunset config | `omarchy-refresh-hyprsunset` |
| Reset Plymouth config | `omarchy-refresh-plymouth` |
| Reset tmux config | `omarchy-refresh-tmux` |

`omarchy-refresh-hyprland` restores **stock** Omarchy Hyprland configs — it will
overwrite the remux's lua files. Only use it if you know what you're doing.
