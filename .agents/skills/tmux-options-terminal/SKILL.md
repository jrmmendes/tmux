---
name: tmux-options-terminal
description: Conventions for tmux options and terminal integration in this config — general behavior options, terminfo/truecolor, extended-keys, OSC 52 clipboard, prefix, escape-time. Use when changing tmux options, fixing color/key problems, or configuring the terminal.
compatibility: opencode
---

# Options and terminal integration

All options live in `tmux.conf`. Sections and scopes:

| Section              | Options                                                                 |
| -------------------- | ----------------------------------------------------------------------- |
| Prefix               | `prefix`, `unbind C-b`, `bind C-a send-prefix`                          |
| Terminal / keys      | `default-terminal`, `terminal-features`, `extended-keys`, `set-clipboard`, `escape-time` |
| General behaviour    | `base-index`, `pane-base-index`, `renumber-windows`, `history-limit`, `focus-events`, `mouse`, `mode-keys` |

## Scopes (get these right; a wrong scope can silently do nothing)

- **Server options** → `set -s` / `set -as`:
  `extended-keys`, `set-clipboard`, `terminal-features`.
- **Window options** → `setw -g` (or `set -w`):
  `mode-keys`, `pane-base-index`.
- **Global session options** → `set -g`:
  `prefix`, `base-index`, `mouse`, `history-limit`, `status-*`, `pane-*`.

## Terminal / truecolor / extended keys

```
set -g default-terminal "tmux-256color"
set -as terminal-features ",*:RGB"
set -as terminal-features ",*:extkeys"
set -s extended-keys on
set -s set-clipboard on
set -g escape-time 10
```

- `,*:RGB` enables truecolor for every terminal; `,*:extkeys` advertises
  extended keys. Both are **server** options (`-as`).
- `extended-keys on` is required for the nvim `<A-*>` maps to reach nvim. It is
  a **server** option — `set -s`, not `set -g`.
- `escape-time 10` keeps `<Esc>` snappy for nvim.
- `default-terminal` needs the terminfo (falls back to `screen-256color`).

## Do not expand `$VAR`

tmux does **not** expand shell variables inside `tmux.conf`. In particular do
**not** write `set -g default-shell "$SHELL"` — it fails with
`not a suitable shell: $SHELL`. The config relies on the inherited `$SHELL`
(the server environment), which is `zsh` here. If a literal shell is ever
needed, hardcode the path (e.g. `/usr/bin/zsh`) and document why.

## New windows/panes in cwd

```
bind c new-window -c "#{pane_current_path}"
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
```

`#{pane_current_path}` keeps the working directory, like the nvim `lcd` pattern.

## Verify an option's effective value and scope

```bash
tmux show-options -g            # global session
tmux show-options -s            # server (extended-keys, terminal-features)
tmux show-options -gw           # window (mode-keys)
tmux -f ~/.config/tmux/tmux.conf new-session -d -s smoke   # load check
```

If a value you set does not appear under the scope you expect, it is in the
wrong scope — fix the flag (`-g` vs `-s` vs `-w`). Then reload with `C-a r`.
