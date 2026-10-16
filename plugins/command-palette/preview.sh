#!/usr/bin/env bash
# =============================================================================
# ~/.config/tmux/plugins/command-palette/preview.sh
# Preview renderer for the command palette (C-a f). fzf runs this with the
# selected row's field 6 as a single argument:
#   "lay:file:<path>" -> runs that layout's `figure` (layout-lib.sh), which
#                        draws the diagram to fit the preview window.
#   ""                -> nothing (section rows).
#   anything else     -> a tmux command, syntax-highlighted with bat.
# =============================================================================
set -uo pipefail

case "${1:-}" in
  lay:file:*) exec "${1#lay:file:}" figure ;;
  '')         exit 0 ;;
  *)          printf '%s\n' "$1" | bat --color=always --style=numbers --language=bash --paging=never 2>/dev/null || printf '%s\n' "$1" ;;
esac
