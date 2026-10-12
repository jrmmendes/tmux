---
name: tmux-debug
description: How to investigate and reproduce a broken tmux config — load errors, a key that does not work, wrong scope/table, clipboard, colors, or a change that used to work. Use when the user reports an error, a dead bind, or unexpected tmux behavior.
compatibility: opencode
---

# Debugging the tmux config

Goal: a **minimal reproduction**, the offending line, then fix. Read
`tmux.conf` (and `AGENTS.md`) first — the config is the truth.

## Order of investigation

1. **Read the error.** Capture the exact message. A config error prints on load
   (e.g. `unknown option`, `not a suitable shell`, `bad key`). The offending
   line number is usually shown.
2. **Smoke-load on a clean server** (isolates config from a running server):
   ```bash
   tmux kill-server 2>/dev/null
   tmux -f ~/.config/tmux/tmux.conf new-session -d -s smoke 2>&1
   ```
   Any message here is a config bug. Then `tmux kill-session -t smoke`.
3. **Reload in a live server and watch for errors:**
   ```bash
   tmux source-file ~/.config/tmux/tmux.conf
   tmux show-messages | tail -20   # recent server messages/errors
   ```
4. **Dead key?** A bind can load and still do nothing if it landed in the wrong
   **table** or **scope**:
   ```bash
   tmux list-keys -T prefix        # is my bind here?
   tmux list-keys -T copy-mode-vi  # copy-mode binds live here
   tmux list-keys -T root          # root table (should have no Alt-* here)
   ```
   - `bind` defaults to the `prefix` table; copy-mode binds need
     `bind -T copy-mode-vi ...`.
   - A later `bind` for the same key overrides an earlier one — check for
     duplicates.
5. **Option not taking effect?** Check the scope:
   `show-options -g` (session) vs `-s` (server) vs `-gw` (window). A wrong flag
   (`-g` on a server option) is the classic silent failure.
6. **Bisect.** `git log --oneline -10`, `git diff`. Comment out the suspect
   line to confirm, then fix.

## Common failure modes in this repo

- **`default-shell "$SHELL"`** → `not a suitable shell: $SHELL`. tmux does not
  expand shell variables. Rely on the inherited `$SHELL` instead.
- **`extended-keys` / `terminal-features` / `set-clipboard` set with `-g`** → no
  effect (they are server options; use `-s` / `-as`).
- **Alt-keys swallowed:** a `bind -n M-...` (root table) breaks the nvim
  `<A-*>` maps. Remove it.
- **Clipboard:** requires `wl-copy` (Wayland). If `y` copies nothing, check
  `command -v wl-copy`; OSC 52 fallback needs terminal support.
- **Colors off:** terminal must advertise truecolor; check
  `tmux show-options -s | grep terminal-features` and `TERM`.
- **`tmux-256color` missing:** `infocmp tmux-256color` — if absent, fall back
  to `screen-256color` in `default-terminal`.

## Useful commands

```bash
tmux info | head                    # server/terminfo summary
tmux show-options -s | grep -i key  # server option values
tmux display-message -p '#{client_termname} #{pane_current_command}'
tmux list-keys | rg '<key>'         # find a key across all tables
```

## Output

Report the root cause, the `tmux.conf:LINE`, and the fix. Confirm with the
smoke-load command (no output = clean) and by re-listing the bind/option in the
expected table/scope. If the cause is outside this repo (missing `wl-copy`,
terminfo, terminal without truecolor), say so explicitly.
