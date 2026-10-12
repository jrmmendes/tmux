# plugins/command-palette.tmux — command palette (fzf popup, no plugin manager).
# display-popup does not expand formats, so run-shell expands #{pane_id} first
# and hands the literal id to the popup; inside the popup the "current" pane is
# not the bind-time pane.
bind f run-shell "tmux display-popup -E -w 92% -h 85% -B -e PALETTE_TARGET=#{pane_id} \"$HOME/.config/tmux/plugins/command-palette/entry.sh\""
