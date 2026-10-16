---
name: tmux-add-layout
description: How to add a new layout to the command palette's "Layouts" section — the one-file-per-layout contract under plugins/command-palette/layouts/, the H/V role spec DSL, how layout-lib.sh figures/plans/applies it, and the native OpenCode tool that scaffolds it. Use when the user wants to add, change or scaffold a command-palette flow layout.
compatibility: opencode
---

# Adding command-palette flow layouts

The command palette (`plugins/command-palette/`) renders its flows from one
**file per layout** under `plugins/command-palette/layouts/`. A layout is a plain
executable shell script; the palette **globs** that directory, so **adding a file
is enough** — `entry.sh` is never edited for a new layout.

> This skill covers the `Layouts` section only. Core tmux binds live in
> `tmux.conf` (`tmux-add-keybind`); the palette plugin itself is described by
> `tmux-add-plugin`.

## Where layouts live

- `plugins/command-palette/layouts/<slug>.sh` — one file = one layout,
  executable (`[a-z][a-z0-9-]*`).
- `plugins/command-palette/layout-lib.sh` — the shared engine every layout
  sources. It is **not** a layout; do not edit it from here.

Dropping in `layouts/quad.sh` makes `Layouts > quad` appear in the palette. No
edit to `entry.sh`, no `tmux.conf` change.

## The file contract

Every layout file:

1. sets `LAYOUT_LABEL` (palette title), `LAYOUT_DESC` (palette description) and
   `LAYOUT_SPEC` (the spec — see the DSL below);
2. optionally sets one `LAYOUT_CMD_<role>` per role (the command to launch) and
   one `LAYOUT_DIR_<role>` per role (that pane's cwd);
3. `source`s the shared engine `../layout-lib.sh`;
4. ends by calling `layout_main "$@"`.

Use the `: "${VAR:=default}"` form so the environment can override each value —
that is how headless tests inject a spec or a command without editing the file.
An unset `LAYOUT_CMD_<role>` means the pane just gets the default shell;
`LAYOUT_DIR_<role>` defaults to the target pane's cwd.

```bash
#!/usr/bin/env bash
# ~/.config/tmux/plugins/command-palette/layouts/quad.sh
# Flow layout for the command palette "Layouts" section.
# One file = one layout: the palette globs layouts/*.sh, so adding this file
# is enough — no edit to entry.sh.
set -euo pipefail

: "${LAYOUT_LABEL:=Quad}"
: "${LAYOUT_DESC:=agente + terminal}"
: "${LAYOUT_SPEC:=H(agent:50,terminal:50)}"

# Command launched in each role's pane (optional: unset = the default shell).
: "${LAYOUT_CMD_agent:=opencode}"

source "$(dirname -- "${BASH_SOURCE[0]}")/../layout-lib.sh"
layout_main "$@"
```

## The spec DSL

```
spec  := (H | V) "(" child ("," child)+ ")" [":" weight] | NAME [":" weight]
child := spec
```

- `H(...)` lays its children **side by side** (horizontal split).
- `V(...)` **stacks** its children (vertical split).
- `NAME` is a **role label**: it names the pane (pane title) and is the key for
  `LAYOUT_CMD_<role>` / `LAYOUT_DIR_<role>`.
- `:weight` is a **relative size** (integers), not a percentage: a child with
  `:50` among siblings totalling 100 gets half. `1/1/1` and `50/50/50` describe
  the same even split.

Worked examples:

| Spec                                      | Result                                                   |
| ----------------------------------------- | -------------------------------------------------------- |
| `H(agent:50,V(editor:50,terminal:50):50)` | agent left; editor over terminal on the right            |
| `H(agent:50,terminal:50)`                 | agent and terminal side by side, equal halves            |
| `H(opencode:1,neovim:1,tmux:1)`           | three columns of equal relative width                    |

## How rendering works

`layout_main` dispatches on its first argument (the palette calls `meta`,
`figure` and `apply`; `roles` is a debugging aid):

- `layout_main meta` — prints `LABEL<TAB>DESC`; this is what the palette reads to
  list the layout.
- `layout_main figure` — draws the **box-art diagram** sized to
  `$FZF_PREVIEW_COLUMNS` × `$FZF_PREVIEW_LINES` (the palette's fzf preview pane),
  so it redraws to fit when the preview is resized.
- `layout_main apply <target-pane> <cwd>` — **builds the layout** and, by design,
  **replaces the target window**:

  1. validates `LAYOUT_SPEC` first — an invalid spec prints
     `Layout inválido: …` and exits non-zero, leaving the window untouched;
  2. un-zooms the window and closes **every pane except the target one**, so the
     result is exactly the layout (a layout is not grafted onto existing panes);
  3. sets `allow-set-title off` on the window so the role titles stick;
  4. runs the `split-window -p` **plan** that `layout.awk` emits (`mode=plan`)
     and `respawn-pane -k`s **every** pane — the target pane included — with
     `LAYOUT_CMD_<role>` in `LAYOUT_DIR_<role>` (default: the target pane's cwd).

  The target pane becomes the **first** leaf of the spec. Nothing is ever typed
  into a pane (`send-keys` would inject the command into a running TUI).
- `layout_main roles` — prints one role label per line (handy for debugging).

Three behaviours to keep in mind:

- **A role command that exits closes its pane.** `respawn-pane` makes the
  command the pane's process, so a long-lived tool (`opencode`, `nvim`, a shell)
  is right; a command that exits immediately leaves no pane behind. A
  command-less role respawns a fresh shell in its dir.
- **`apply` is destructive by design.** Pre-existing panes of the window are
  closed and the target pane is respawned: scrollback and unsaved state in those
  panes are lost. Only apply a layout to a window you are willing to rebuild.
- **Role titles are deterministic in the target window.** `allow-set-title off`
  keeps the role label on the border even when zsh/nvim/opencode emit a terminal
  title (a `0.3 s` sweep re-applies them as a fallback). The option needs
  **tmux ≥ 3.3** (on 3.2 it is a silent no-op and only the sweep mitigates); it
  is per-window and persists — `set-option -w allow-set-title on` restores the
  application title behaviour there.

The `split-window -p` plan is an **internal** step of `apply`, not a
`layout_main` subcommand: `layout.awk` parses, renders and plans;
`layout-lib.sh` dispatches and applies.

## Scaffolding

A native OpenCode custom tool lives at `.opencode/tools/new-tmux-layout.ts`
(tool name `new-tmux-layout`) and writes the file:

- Args: `name` (required, `[a-z][a-z0-9-]*`), and optional `label`, `desc`,
  `spec` (default `H(agent:50,terminal:50)`) and `force`.
- Refuses to overwrite an existing layouts file unless `force: true`.
- Derives a default `label` from the name (title-cased, dashes → spaces) and a
  default `desc`, then emits the contract above (chmod `0o755`).

If the tool is unavailable to the current agent, create the file by hand from the
template above.

## Procedure

1. Read `AGENTS.md` and an existing layout
   (`plugins/command-palette/layouts/*.sh`) to match style.
2. Scaffold with `new-tmux-layout` (or hand-write the file from the template).
3. Edit `LAYOUT_LABEL` / `LAYOUT_DESC` / `LAYOUT_SPEC` and the
   `LAYOUT_CMD_<role>` lines to match the roles in your spec.
4. Validate (below). No reload is needed: the palette globs `layouts/*.sh` on
   every run, so the new entry is already in `C-a f`.

## Validate

```bash
# 1. Metadata parses (prints "LABEL<TAB>DESC").
plugins/command-palette/layouts/<name>.sh meta

# 2. The box-art figure renders at a fixed preview size.
FZF_PREVIEW_COLUMNS=80 FZF_PREVIEW_LINES=24 \
  plugins/command-palette/layouts/<name>.sh figure

# 3. The palette lists it under Layouts.
PALETTE_DUMP=1 bash plugins/command-palette/entry.sh | grep Layouts

# 4. Apply it for real, on a private socket, then inspect the panes.
#    (Add extra panes first: apply must close them and leave exactly the spec.)
tmux -L layout-test -f ~/.config/tmux/tmux.conf new-session -d -s s -x 120 -y 40
tmux -L layout-test split-window -t s -h        # pre-existing pane, must disappear
plugins/command-palette/layouts/<name>.sh apply \
  "$(tmux -L layout-test list-panes -t s -F '#{pane_id}' | head -1)" /tmp
sleep 0.5
tmux -L layout-test list-panes -t s -F '#{pane_index} #{pane_title} #{pane_current_command}'
tmux -L layout-test kill-server
```

Pane count must equal the number of leaves in `LAYOUT_SPEC`, geometry/peso must
match the figure, and every `title` must be its role.

```bash
# 5. An invalid spec must fail loudly and leave the window intact.
LAYOUT_SPEC='H(agent:50,terminal' plugins/command-palette/layouts/<name>.sh \
  apply "$(tmux -L layout-test list-panes -t s -F '#{pane_id}')" /tmp
# → stderr: layout.awk: especificação inválida: [H(agent:50,terminal] ; rc=1
```

Use a **private socket** (`-L layout-test`) for the apply test so the running
server is untouched; always `kill-server` when done.

## Saving the current window as a layout

The palette action `Ações > Salvar layout atual` runs
`plugins/command-palette/save-layout.sh capture`: it snapshots the current
window's geometry and pane table into a temp prompt file and opens a
`display-popup` running `opencode --prompt …` (with a `run-shell -b` relaunch as
a fallback when a nested popup is swallowed). Nothing is auto-persisted: the
agent then uses **this skill** to turn the captured snapshot into
`plugins/command-palette/layouts/<slug>.sh` — scaffold the file, encode the
geometry as `LAYOUT_SPEC`, set the role commands/dirs, validate.

## Guardrail

**Local only.** A layout is just a file in this repo — never add TPM, `set -g
@plugin`, or any `run-shell` that fetches remote code. Never touch
`~/.config/nvim`; this repo is 100% tmux.
