---
name: tmux-e2e-test
description: End-to-end testing of this tmux config by driving a headless tmux session — creating split layouts, sending prefix keys, capturing panes, and verifying binds, status bar, titles and clipboard. Use to validate a keybind/layout/theme change for real, not just that the config loads.
compatibility: opencode
---

# E2E testing the tmux config

A smoke-load (`tmux -f ... new-session -d`) only proves the config parses. A
bind can parse and still be **dead** — wrong table, wrong scope, or overridden.
Drive a real (headless) session to verify behavior.

## Harness

```bash
s=e2e
tmux kill-session -t "$s" 2>/dev/null
tmux -f ~/.config/tmux/tmux.conf new-session -d -s "$s" -x 200 -y 50
sleep 1
# ... drive keys / capture ...
tmux capture-pane -pt "$s" -S -60
tmux kill-session -t "$s"
```

- Always load **this** config with `-f ~/.config/tmux/tmux.conf` so the run is
  isolated from the user's running server (do not `kill-server` the user's — use
  a distinct session name, or a temporary `-L socketname`).
- Prefer a private socket to be safe:
  `tmux -L e2e -f ~/.config/tmux/tmux.conf new-session -d -s "$s"` and pass
  `-L e2e` to every subsequent command.

## Sending keys

`send-keys` takes key names (`C-a`, `C-m`, `Escape`, `-`, `|`, ...) or a literal
string with `-l`. To exercise a bind, send the prefix then the key:

```bash
# C-a |  -> split right (new pane)
tmux send-keys -t "$s" C-a '|'
sleep 0.3
tmux display-message -p -t "$s" '#{window_panes}'   # expect 2

# C-a h / l  -> move focus
tmux send-keys -t "$s" C-a l
tmux display-message -p -t "$s" '#{pane_index}'     # focus moved
```

Do not put a `sleep` **between** the prefix and the key of the sequence under
test (that can hide races); send them in one `send-keys` call and sleep after.

## What to assert

| Feature            | Probe                                                              |
| ------------------ | ------------------------------------------------------------------ |
| Split `\|` / `-`   | `#{window_panes}` increases; `#{pane_id}` of new pane              |
| Navigation `hjkl`  | `#{pane_index}` / `#{pane_id}` changes                              |
| Resize `HJKL`      | `#{pane_width}` / `#{pane_height}` changes (repeatable)            |
| Zoom `z`           | `#{window_zoomed_flag}` toggles to 1                               |
| New window `c`     | `#{window_index}` increments, cwd = `#{pane_current_path}`         |
| Status bar         | `tmux capture-pane -p -S -1 \| tail -1` shows the blocks + clock    |
| Pane title         | run a command, border shows `#{pane_current_command}`              |
| Copy-mode + wl-copy| `C-a [`, select, `y`, then `wl-paste` returns the text             |

## Verifying binds without a live session

`list-keys` is the fastest check that a bind exists in the right table:

```bash
tmux -L e2e -f ~/.config/tmux/tmux.conf list-keys -T prefix | rg ' C-a | h | \| '
tmux -L e2e -f ~/.config/tmux/tmux.conf list-keys -T copy-mode-vi | rg ' y '
```

## Clipboard test (Wayland)

```bash
printf 'tmux-e2e-marker' | wl-copy      # seed / sanity-check wl-paste works
# inside session: C-a [, select the marker, y
wl-paste | rg 'tmux-e2e-marker' && echo CLIPBOARD_OK
```

If `wl-paste` is unavailable (headless, no compositor) note it and check the
bind exists instead — absence of a compositor is not a config bug.

## Gotchas

- Always clean up: `tmux kill-session -t "$s"` (and `tmux -L e2e kill-server`
  if you used a private socket).
- `capture-pane -p` prints to stdout; `-S -N` includes N lines of scrollback.
- Give the server a moment after creation before sending keys (`sleep 1`).
- The status bar is the last rendered line; capture the bottom of the pane to
  inspect it.
- `extended-keys` behavior depends on the client terminal — a headless
  `send-keys` cannot fully prove the nvim `<A-*>` path. For that, test inside a
  real TTY.

## Output

Report: the exact key sequence, the observed state (`window_panes`,
`window_zoomed_flag`, captured status line, ...), and the before/after when
validating a fix. Pair it with a clean smoke-load
(`tmux -f ~/.config/tmux/tmux.conf new-session -d -s smoke` with no output).
