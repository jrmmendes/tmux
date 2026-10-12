# AGENTS.md — tmux config (Mendes' cockpit)

Always-active guidance for coding agents (OpenCode) working in this repository.
Read this before touching any file. Detailed, task-specific procedures live in
the skills under `.agents/skills/` and are loaded on demand.

## What this repo is

A **self-contained** tmux configuration — **no TPM, no remote plugins**; local
in-tree plugins live under `plugins/` (see Architecture → Local plugins). It
turns tmux into a cockpit: several AI agents, TUIs and nvim side by side in
panes. It deliberately mirrors the **Neovim v3 config** (`~/.config/nvim`):
gruvbox dark `contrast="hard"`, the same palette and the same key language.
This repo never edits the nvim config; the two are siblings, not dependencies.

The whole configuration lives in a single file: `tmux.conf`. tmux >= 3.2 reads
`~/.config/tmux/tmux.conf` by default (XDG).

## Architecture

`tmux.conf` is organized top-to-bottom in labeled sections. Keep changes inside
the matching section and keep the section order:

1. **Prefix** — `C-a` (after `unbind C-b`), plus `bind C-a send-prefix` so the
   app can receive a literal `C-a` via `C-a C-a`.
2. **Terminal / keys** — `default-terminal`, truecolor/extkeys
   `terminal-features`, `extended-keys`, `set-clipboard`, `escape-time`.
3. **General behaviour** — `base-index 1`, `pane-base-index 1`,
   `renumber-windows`, `history-limit`, `focus-events`, `mouse`, `mode-keys vi`,
   new windows/panes in `#{pane_current_path}`.
4. **Keybindings** — everything under `C-a`; never `Alt-*` on the root table.
5. **Copy-mode (vi) + Wayland clipboard** — `v`/`C-v`/`y` and
   `MouseDragEnd1Pane` piping to `wl-copy`.
6. **Status bar** — gruvbox-hard, flat blocks, no powerline arrows.
7. **Pane borders and titles** — `pane-border-status top`, green active border,
   auto-rename.
8. **Local plugins** — `plugins/<name>.tmux` (registration: declares the
   plugin's OWN binds/options) plus `plugins/<name>/` (pure tree, e.g.
   `entry.sh`), loaded by `source-file ~/.config/tmux/plugins/*.tmux` at the end
   of `tmux.conf`. **Adding a plugin = adding a file.** Plugin-provided keybinds
   live in the plugin's `.tmux` file, not in tmux.conf's Keybindings section.

There is no plugin manager, no `set -g @plugin`, and no `run-shell` fetching
remote code. Local in-tree plugins under `plugins/` ARE allowed (see
Architecture → Local plugins): adding a behavior is either a tmux option/bind in
the matching section, or a new file under `plugins/`.

## Conventions

- **Palette is the single source of truth.** gruvbox-hard values (mirrored from
  `~/.config/nvim/core/config/statusline.lua`): bg `#282828`, bg1 `#3c3836`,
  fg `#ebdbb2`, fg0 `#fbf1c7`, gray `#a89984`, gray_dim `#7c6f64`, red
  `#fb4934`, green `#b8bb26`, yellow `#fabd2f`, orange `#fe8019`, blue
  `#83a598`, purple `#d3869b`, aqua `#8ec07c`. Reuse these hex values; never
  invent a nearby shade.
- **Prefix is `C-a`.** Every binding goes in the prefix table unless there is a
  strong reason (and that reason is documented). `C-a C-a` is reserved for
  `send-prefix`.
- **No `Alt-*` on the root table.** The nvim config uses `<A-f>`, `<A-p>`,
  `<A-,>`, `<A-g>`, `<A-n>`, `<A-s>`, `<A-d>`; a root-table `Alt-*` bind would
  swallow them. `extended-keys on` is set precisely so those reach nvim.
- Keep the nvim-adjacent language: `|` splits right (`splitright`), `-` splits
  below (`splitbelow`), `h/j/k/l` and `H/J/K/L` are vim motions.
- One concern per section; add a comment only when it explains a non-obvious
  choice (e.g. why `default-shell` is not set literally).
- tmux **does not expand `$VAR`** inside `tmux.conf`. Do not write
  `set -g default-shell "$SHELL"` (it fails with "not a suitable shell").
- Server-scoped options use `-s` (`extended-keys`, `set-clipboard`,
  `terminal-features`); window options use `-w`/`setw`; the rest are global
  session options (`-g`).

## Guardrails

- **Never add TPM or fetch remote plugin code.** Local in-tree plugins under
  `plugins/` ARE allowed (see Architecture → Local plugins); a feature is either
  a tmux option/bind in the matching section, or a new file under `plugins/`.
- **Never touch `~/.config/nvim`.** This repo is 100% tmux.
- Do not bind `Alt-*` on the root table, and do not change the prefix away from
  `C-a`, without an explicit user decision recorded here.
- Do not replace the gruvbox-hard palette with ad-hoc colors.
- Before declaring a task done, validate that the config loads without errors:
  ```bash
  tmux -f ~/.config/tmux/tmux.conf new-session -d -s smoke
  tmux show-options -g >/dev/null && tmux list-keys >/dev/null
  tmux kill-session -t smoke
  ```
  A bind can "load" and still be dead (wrong table, wrong scope) — verify it
  with `tmux list-keys -T prefix` (or the relevant table), not just the load.
- If a skill's instructions ever disagree with the config, **the config is the
  truth** — read `tmux.conf` before acting.

## Routing map — pick the matching skill

| Task                                                     | Skill                     |
| -------------------------------------------------------- | ------------------------- |
| Add/change/remove a keybinding (prefix or copy-mode)     | `tmux-add-keybind`        |
| Status bar, colors, palette, pane borders/titles         | `tmux-theme`              |
| Options, terminfo/truecolor, extended-keys, clipboard    | `tmux-options-terminal`   |
| Debug/reproduce a load error or a key that does not work | `tmux-debug`              |
| E2E-test binds/layout/copy in a headless tmux session    | `tmux-e2e-test`           |
| Answer questions about the current config (read-only)    | `tmux-config-info`        |
| Add/change/configure a local plugin or its binds         | `tmux-add-plugin`        |
| Create/scaffold a local plugin                           | `tmux-create-plugin`     |

## Delegation protocol

`Build:Tmux` is a thin orchestrator. Do not burn its context doing the work
inline:

1. Classify the request against the routing map.
2. Load/select the matching skill (or instruct the subagent to load it).
3. Delegate execution to a **generic subagent** via the `task` tool, passing:
   the chosen skill name, the exact files to read, and a precise brief.
4. Validate the subagent's result (the diff, and the smoke-load command above).
5. Report back to the user, including the files changed and how it was verified.

Delegating is the default. Only handle a request inline when it is a trivial
read-only answer, and prefer `tmux-config-info` even then.
