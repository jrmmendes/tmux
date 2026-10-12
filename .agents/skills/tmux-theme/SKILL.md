---
name: tmux-theme
description: Conventions for the tmux look in this config — status bar, gruvbox-hard palette, colors, window-status formats, pane borders and titles. Use when changing status bar segments, colors, the clock, pane border colors or the pane title format.
compatibility: opencode
---

# Theme (status bar, borders, palette)

Two sections of `tmux.conf`: **"Status bar"** and **"Pane borders and titles"**.

## Palette — the single source of truth (gruvbox-hard)

Mirrored from `~/.config/nvim/core/config/statusline.lua`. **Never invent a
nearby shade** — reuse these exact hex values:

| Name     | Hex       | Used for                                  |
| -------- | --------- | ----------------------------------------- |
| bg       | `#282828` | base background                           |
| bg1      | `#3c3836` | status bar background, inactive windows   |
| fg       | `#ebdbb2` | default foreground                        |
| fg0      | `#fbf1c7` | brightest foreground                      |
| gray     | `#a89984` | dim text, clock, inactive labels          |
| gray_dim | `#7c6f64` | inactive pane border                      |
| red      | `#fb4934` | —                                         |
| green    | `#b8bb26` | active pane border, session block         |
| yellow   | `#fabd2f` | active window block                       |
| orange   | `#fe8019` | —                                         |
| blue     | `#83a598` | —                                         |
| purple   | `#d3869b` | —                                         |
| aqua     | `#8ec07c` | —                                         |

## Status bar

Mirrors the nvim statusline with **flat blocks** (no powerline arrows). The
current shape:

```
set -g status-style "bg=#3c3836,fg=#ebdbb2"
set -g status-left  "#[bg=#b8bb26,fg=#282828,bold] #S #[bg=#3c3836,fg=#a89984] "
set -g status-right "#[fg=#a89984] %H:%M "
set -g window-status-format         "#[bg=#3c3836,fg=#a89984] #I:#W "
set -g window-status-current-format "#[bg=#fabd2f,fg=#282828,bold] #I:#W "
```

Rules:

- One block = `#[bg=...,fg=...]`. Reset with `#[default]` or re-state both
  attributes. Keep blocks flat: `ARROW`/`DOT` separators are empty here.
- Clock is `%H:%M` in gray; keep `status-interval 1`.
- `status-left-length` / `status-right-length` bound the segments — raise them
  if you add text, or it will be truncated.
- `window-status-separator ""` keeps blocks adjacent.

## Pane borders and titles

```
set -g pane-border-status top
set -g pane-border-format "#{?pane_active,#[fg=#b8bb26,bold],#[fg=#7c6f64]} #{?#{==:#{pane_title},},#{pane_current_command},#{pane_title}} #[default]"
set -g pane-border-style "fg=#7c6f64"
set -g pane-active-border-style "fg=#b8bb26"
set -g automatic-rename on
set -g allow-rename on
```

- Active border is green (`#b8bb26`), inactive is `#7c6f64`.
- The title format falls back to `#{pane_current_command}` when `pane_title` is
  empty.
- `automatic-rename`/`allow-rename` make the window title follow the focused
  process (`nvim`, `opencode`, `lazydocker`, ...).

## Validate

```bash
tmux -f ~/.config/tmux/tmux.conf new-session -d -s smoke -x 120 -y 30
tmux display-message -p -t smoke '#{T:status-left}'
tmux capture-pane -pt smoke -S -1 | tail -1   # status line render
tmux kill-session -t smoke
```

For a real visual check drive a live session and capture the bottom line (see
the `tmux-e2e-test` skill).
