---
name: tmux-add-keybind
description: Conventions for adding, changing or removing a keybinding in this tmux config — the prefix table (C-a), copy-mode-vi binds, repeatable binds, split/navigation binds. Use when the user wants a new keybinding, to change or remove one, or asks where a bind should live.
compatibility: opencode
---

# Keybindings

Every bind lives in `tmux.conf`, in one of two sections:

1. **Prefix table** (default) → the "Keybindings" section. Reached with `C-a`.
2. **copy-mode-vi table** → the "Copy-mode (vi) + Wayland clipboard" section.

There is no other place: no plugins, no `run-shell` sourcing extra files.

## Rules

- **Everything goes under the prefix `C-a`.** A bind in the prefix table must
  never override an `Alt-*` key on the **root** table — the nvim config uses
  `<A-f>`, `<A-p>`, `<A-,>`, `<A-g>`, `<A-n>`, `<A-s>`, `<A-d>`, and a root
  `Alt-*` bind would swallow them. Do **not** add `bind -n M-...`.
- `C-a C-a` is reserved for `send-prefix` (literal `C-a` to the app). Do not
  rebind it.
- Keep the nvim-adjacent language: `|` splits right (`-h`, `splitright`), `-`
  splits below (`-v`, `splitbelow`), `h/j/k/l` navigate, `H/J/K/L` resize.
- Repeatable binds use `bind -r <key> ...` (e.g. resize H/J/K/L).
- Binds that push a command banner should keep the style already in the file
  (`\; display-message "..."`) — but do not spam; use sparingly.

## Adding a bind

Add one line under the matching sub-group, in this shape:

```
bind <key> <tmux-command> [args...]
```

Examples already in the file:

```
bind h select-pane -L
bind | split-window -h -c "#{pane_current_path}"
bind -r H resize-pane -L 5
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "wl-copy"
```

Notes:

- A lone `-` is a valid key argument (`bind - split-window -v ...`); tmux treats
  a single `-` as a non-option argument.
- Values needing spaces/quotes are quoted: `set -g ... "a b"`.
- `#{...}` are tmux formats (expanded at runtime), not shell variables. `$VAR`
  is **not** expanded in `tmux.conf`.
- New windows/panes should open in the current directory:
  `-c "#{pane_current_path}"`.
- Prefer built-in commands over shell (`run-shell`) — this repo keeps runtime
  overhead minimal.

## Removing a bind

- To drop a stock bind, add an `unbind <key>` in the same section (e.g. the
  config already does `unbind %` and `unbind '"'`).
- To replace a bind, just `bind` the key again later in the file; the last
  definition wins. Prefer editing the existing line instead of adding a
  duplicate.

## Validate

```bash
tmux -f ~/.config/tmux/tmux.conf new-session -d -s smoke
tmux list-keys -T prefix | grep -E '<key>'
tmux kill-session -t smoke
```

A bind that "loads" can still be dead if it landed in the wrong table/scope —
confirm it appears in the expected table (`prefix` vs `copy-mode-vi`). Remind
the user to reload with `C-a r` (or restart the server).
