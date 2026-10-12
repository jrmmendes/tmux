---
name: tmux-config-info
description: Answers read-only questions about the current state of this tmux config — where an option/keybind lives, the palette, the status bar, pane borders, terminal settings. Use when the user asks what a key does, where something is configured, or how a part of the config works. Never modifies files.
compatibility: opencode
---

# Answering questions about the tmux config (read-only)

**This skill never edits files.** It only reads and explains. If the user asks
for a change, route to the appropriate skill (`tmux-add-keybind`, `tmux-theme`,
`tmux-options-terminal`, `tmux-debug`).

## Where to look

| Question                                   | Read                                              |
| ------------------------------------------ | ------------------------------------------------- |
| Overall structure / sections               | `AGENTS.md`, `README.md`, `tmux.conf`             |
| Prefix, `send-prefix`, general options      | `tmux.conf` — "Prefix" / "General behaviour"      |
| Keybindings (prefix table)                 | `tmux.conf` — "Keybindings"; `tmux list-keys -T prefix` |
| Copy-mode + clipboard                      | `tmux.conf` — "Copy-mode"; `tmux list-keys -T copy-mode-vi` |
| Status bar / colors                        | `tmux.conf` — "Status bar"                         |
| Pane borders / titles / auto-rename        | `tmux.conf` — "Pane borders and titles"            |
| Terminal / truecolor / extended-keys       | `tmux.conf` — "Terminal / keys"                    |

Everything lives in the single file `tmux.conf`; there are no other config
files and no plugins.

## How to answer well

- **Read `tmux.conf`** before asserting; do not guess from memory.
- For keybinds: report the prefix (`C-a`) and the exact tmux command. Cross-check
  with the live bind: `tmux list-keys -T prefix` (a bind can be defined but dead
  if it landed in the wrong table/scope).
- For options: quote the value and its scope (`-g`, `-s`, `-w`).
- For "is X configured?": grep the file and answer yes/no with `file:line`.
- Prefer concise summaries and `tmux.conf:LINE` references.

## Useful read-only commands

```bash
tmux show-options -g            # global session options
tmux show-options -s            # server options (extended-keys, terminal-features)
tmux show-options -gw           # window options (mode-keys)
tmux list-keys -T prefix        # prefix table binds
tmux list-keys -T copy-mode-vi  # copy-mode binds
rg -n "pattern" tmux.conf       # find an option/bind in the config
```

Do not run commands that modify state; `show-options`/`list-keys`/`rg` are fine.
