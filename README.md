```
████████╗███╗   ███╗██╗   ██╗██╗  ██╗
╚══██╔══╝████╗ ████║██║   ██║╚██╗██╔╝
   ██║   ██╔████╔██║██║   ██║ ╚███╔╝
   ██║   ██║╚██╔╝██║██║   ██║ ██╔██╗
   ██║   ██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗
   ╚═╝   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝
Mendes' self-contained tmux cockpit
```

A self-contained tmux config (no TPM; in-tree local plugins under `plugins/`)
built as a **cockpit** for AI agents, TUIs and nvim side by side in panes. It
matches the look and key language of the
[Neovim v3 config](https://github.com/jrmmendes/nvim-v2): gruvbox dark
`contrast="hard"`.

tmux >= 3.2 reads `~/.config/tmux/tmux.conf` by default (XDG), so no wrapper or
`TMUX_CONF` is needed.

## Structure

- `tmux.conf` — the whole configuration: prefix, terminal/truecolor, options,
  keybindings, copy-mode clipboard, status bar and pane borders.
- `plugins/` — local in-tree plugins: `plugins/<name>.tmux` (registration, which
  declares the plugin's own binds) plus `plugins/<name>/` (implementation tree,
  e.g. `entry.sh`), loaded by the `source-file plugins/*.tmux` glob at the end of
  `tmux.conf`.
- `AGENTS.md` — always-active rules for OpenCode agents: architecture,
  conventions, guardrails and a task → skill routing map.
- `.agents/skills/tmux-*/SKILL.md` — on-demand procedures loaded by agents.
- `.opencode/agents/build-tmux.md` — the `Build:Tmux` primary agent (orchestrator).
- `.opencode/tools/new-pane-preset.ts` — native OpenCode tool that scaffolds a
  pane-layout preset + its keybind.
- `.opencode/tools/new-tmux-plugin.ts` — native OpenCode tool that scaffolds a
  local plugin (`plugins/<name>.tmux` + `plugins/<name>/entry.sh`).
- `.opencode/tools/new-tmux-layout.ts` — native OpenCode tool that scaffolds a
  command-palette flow layout
  (`plugins/command-palette/layouts/<name>.sh`).

## Keybindings (prefix `C-a`)

`C-a C-a` sends a literal `C-a` to the application (needed by nvim's native
increment). No `Alt-*` is bound on the root table, so the nvim `<A-*>` maps
(`<A-f>`, `<A-p>`, `<A-,>`, `<A-g>`, `<A-n>`, `<A-s>`, `<A-d>`) keep working.

| Key               | Action                                   |
| ----------------- | ---------------------------------------- |
| `C-a C-a`         | literal `C-a` to the app                 |
| `C-a h/j/k/l`     | navigate panes (vim motions)             |
| `C-a \|`          | split right (`-h`, matches `splitright`) |
| `C-a -`           | split below (`-v`, matches `splitbelow`) |
| `C-a H/J/K/L`     | resize pane (repeatable, 5 cells)        |
| `C-a z`           | zoom pane                                |
| `C-a x`           | kill pane                                |
| `C-a Space`       | next layout                              |
| `C-a c`           | new window in cwd                        |
| `C-a n` / `C-a p` | next / previous window                   |
| `C-a ,` / `C-a $` | rename window / session                  |
| `C-a d`           | detach                                   |
| `C-a [`           | copy-mode (vi)                           |
| `C-a r`           | reload config                            |
| `C-a f`           | command palette (fzf popup plugin)       |

Copy-mode (vi): `v` select, `C-v` rectangle, `y` copy to the Wayland clipboard
(`wl-copy`); mouse drag-and-release also copies. `set-clipboard on` (OSC 52) is
kept as a fallback for terminals that support it.

## Status bar

Mirrors the nvim statusline in gruvbox-hard with **flat blocks** (no powerline
arrows): session in a green (`#b8bb26`) block on the left, the active window in
a yellow (`#fabd2f`) block, inactive windows in grey (`#a89984`), and the clock
on the right.

## Pane borders

`pane-border-status top` with the pane title (falling back to the current
command) on the border; the active pane border is green (`#b8bb26`). Windows
auto-rename to the focused process (`nvim`, `opencode`, `lazydocker`, ...).

## Install

```bash
git clone git@github.com:jrmmendes/tmux.git ~/.config/tmux
```

No build or install step: the config is just `tmux.conf` plus the in-tree
`plugins/`, and tmux >= 3.2 reads `~/.config/tmux/tmux.conf` by default (XDG) —
nothing to fetch or compile (unlike opencode's `bun install`).

If tmux is already running, reload with `C-a r` (or `tmux source-file
~/.config/tmux/tmux.conf`). Runtime deps (`fzf`, `bat`, `wl-clipboard`, Nerd
Font, `tmux-256color`, `zsh`) are listed under [Requirements](#requirements).

## Requirements

- tmux >= 3.2 (developed against 3.7c)
- `tmux-256color` terminfo (falls back to `screen-256color`)
- A terminal with truecolor + extended keys (Kitty, Konsole, ...)
- Wayland + [wl-clipboard](https://github.com/bugaevc/wl-clipboard) (`wl-copy`)
- A Nerd Font
- `zsh` (tmux inherits `$SHELL` from the server environment)

## Reload

`C-a r`, or from a shell: `tmux source-file ~/.config/tmux/tmux.conf`.

## AI agents

This repo is set up for [OpenCode](https://opencode.ai) agents:

- [`AGENTS.md`](AGENTS.md) — architecture, conventions, guardrails and the
  task → skill routing map.
- `.opencode/agents/build-tmux.md` — the `Build:Tmux` primary agent: classify,
  route, delegate, validate, report.
- `.agents/skills/tmux-*/SKILL.md` — procedures for read-only questions, adding
  keybinds, theming, options/terminal, debugging, E2E testing, adding or creating
  local plugins (`tmux-add-plugin`, `tmux-create-plugin`) and adding a
  command-palette flow layout (`tmux-add-layout`).
- `.opencode/tools/new-pane-preset.ts` — scaffolds a pane-layout preset and its
  keybind entry.
- `.opencode/tools/new-tmux-plugin.ts` — scaffolds a local plugin
  (`plugins/<name>.tmux` registration + `plugins/<name>/entry.sh`).
- `.opencode/tools/new-tmux-layout.ts` — scaffolds a command-palette flow layout
  (`plugins/command-palette/layouts/<name>.sh`).

## Persistence

Not implemented on purpose (yet): no `resurrect`/`continuum` — those are
external/TPM-style plugins, which this repo does not use. The command palette
instead carries **flow layouts** as in-tree files
(`plugins/command-palette/layouts/*.sh`, one per layout), and
`Ações > Salvar layout atual` captures the current window and hands the snapshot
to `opencode` in a floating popup so a new layout file can be written from it.
