#!/usr/bin/env bash
# =============================================================================
# ~/.config/tmux/plugins/command-palette/entry.sh
# Self-contained tmux command palette (fzf) — in-tree plugin, no TPM.
#
# Registration/bind lives in plugins/command-palette.tmux (sourced by the
# loader at the end of tmux.conf); the bind is C-a f:
#   C-a f -> display-popup -E ... -e PALETTE_TARGET=#{pane_id} ... this script
#
# PALETTE_TARGET is the pane id captured at bind time. Inside a display-popup
# the "current" pane is the popup itself, so every pane-relative action must
# pass -t "$PALETTE_TARGET" explicitly; otherwise it would act on the popup.
#
# Debug / headless test: PALETTE_DUMP=1 (or --list) prints the TSV candidate
# list to stdout and exits without launching fzf.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# SCRIPT_DIR is plugins/command-palette, so the repo root is two levels up.
REPO_DIR="$(dirname -- "$(dirname -- "$SCRIPT_DIR")")"
CONF="$HOME/.config/tmux/tmux.conf"
TMUX_BIN="${TMUX_BIN:-tmux}"

DUMP=0
[[ "${PALETTE_DUMP:-0}" == "1" ]] && DUMP=1
for arg in "$@"; do [[ "$arg" == "--list" ]] && DUMP=1; done

# stderr-silent tmux helper: a palette must never spam the popup.
tm() { "$TMUX_BIN" "$@" 2>/dev/null; }

# --- Resolve the bind-time target pane and its context -----------------------
target="${PALETTE_TARGET:-}"
[[ -z "$target" ]] && target="$(tm display-message -p '#{pane_id}')"

cwd=""; sess=""; win=""; client=""
if [[ -n "$target" ]]; then
  cwd="$(tm display-message -p -t "$target" '#{pane_current_path}')"
  sess="$(tm display-message -p -t "$target" '#{session_id}')"
  win="$(tm display-message -p -t "$target" '#{window_id}')"
  client="$(tm display-message -p -t "$target" '#{client_tty}')"
fi
[[ -n "$cwd" ]] || cwd="$HOME"

# --- Candidate rows: cat \t label \t desc \t action \t payload \t b64(preview)
b64() { printf '%s' "$1" | base64 -w0 2>/dev/null || printf '%s' "$1" | base64 2>/dev/null; }

row() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$(b64 "$6")"; }

emit_candidates() {
  # --- A) Ações -------------------------------------------------------------
  row "Ações" "[Ações] Split right"      "divide à direita (horizontal)"  "split-right"    "" "tmux split-window -h  -c '$cwd' -t $target"
  row "Ações" "[Ações] Split left"       "divide à esquerda"              "split-left"     "" "tmux split-window -hb -c '$cwd' -t $target"
  row "Ações" "[Ações] Split down"       "divide abaixo (vertical)"       "split-down"     "" "tmux split-window -v  -c '$cwd' -t $target"
  row "Ações" "[Ações] Split up"         "divide acima"                   "split-up"       "" "tmux split-window -vb -c '$cwd' -t $target"
  row "Ações" "[Ações] Nova janela"      "nova janela no cwd do pane"     "new-window"     "" "tmux new-window -c '$cwd' -t $sess"
  row "Ações" "[Ações] Matar pane"       "fecha o pane alvo"              "kill-pane"      "" "tmux kill-pane -t $target"
  row "Ações" "[Ações] Zoom pane"        "alterna o zoom do pane"         "zoom-pane"      "" "tmux resize-pane -Z -t $target"
  row "Ações" "[Ações] Próxima janela"   "vai para a próxima janela"      "next-window"    "" "tmux next-window -t $sess"
  row "Ações" "[Ações] Janela anterior"  "volta uma janela"               "prev-window"    "" "tmux previous-window -t $sess"
  row "Ações" "[Ações] Próximo layout"   "cicla o layout do pane"         "next-layout"    "" "tmux next-layout -t $win"
  row "Ações" "[Ações] Copy-mode"        "entra no modo cópia (vi)"       "copy-mode"      "" "tmux copy-mode -t $target"
  row "Ações" "[Ações] Renomear janela"  "renomeia a janela (prompt)"     "rename-window"  "" "tmux rename-window -t $win -- <novo-nome>"
  row "Ações" "[Ações] Renomear sessão"  "renomeia a sessão (prompt)"     "rename-session" "" "tmux rename-session -t $sess -- <novo-nome>"
  row "Ações" "[Ações] Recarregar config" "recarrega ~/.config/tmux/tmux.conf" "reload"     "" "tmux source-file $CONF \\; display-message 'Config recarregada!'"
  row "Ações" "[Ações] Detach"           "desanexa o cliente"             "detach"         "" "tmux detach-client -s $sess"
  row "Ações" "[Ações] Matar sessão"     "encerra a sessão"               "kill-session"   "" "tmux kill-session -t $sess"

  # --- B) Keybinds — generated live from tmux (never drifts) ----------------
  local tbl line
  for tbl in prefix copy-mode-vi; do
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      row "Keybinds" "[Keybinds] $line" "table: $tbl (informativo)" "info" "$line" "$line"
    done < <(tm list-keys -T "$tbl")
  done

  # --- C) Sessões / Janelas / Panes ----------------------------------------
  local id name sid wid pid label
  while IFS='|' read -r id name; do
    [[ -n "$id" ]] || continue
    row "Sessões" "[Sessões] $name" "$id" "session" "$id" "tmux switch-client -t $id"
  done < <(tm list-sessions -F '#{session_id}|#{session_name}')

  while IFS='|' read -r sid wid label; do
    [[ -n "$wid" ]] || continue
    row "Janelas" "[Janelas] $label" "$wid" "window" "$sid|$wid" "tmux select-window -t $wid"
  done < <(tm list-windows -a -F '#{session_id}|#{window_id}|#{session_name}:#{window_index} #{window_name}')

  while IFS='|' read -r sid wid pid label; do
    [[ -n "$pid" ]] || continue
    row "Panes" "[Panes] $label" "$pid" "pane" "$sid|$wid|$pid" "tmux select-pane -t $pid"
  done < <(tm list-panes -a -F '#{session_id}|#{window_id}|#{pane_id}|#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}')

  # --- D) Presets (optional: presets/<name>.sh written by new-pane-preset) --
  local p
  if [[ -d "$REPO_DIR/presets" ]]; then
    for p in "$REPO_DIR"/presets/*.sh; do
      [[ -e "$p" ]] || continue
      row "Presets" "[Presets] $(basename "$p" .sh)" "$p" "preset" "$p" "$p"
    done
  fi
}

# --- fzf theming: gruvbox-hard (palette is the single source of truth) -------
GU="bg:#282828,bg+:#3c3836,fg:#ebdbb2,fg+:#fbf1c7,hl:#fb4934,hl+:#fe8019,info:#a89984,prompt:#b8bb26,pointer:#d3869b,marker:#83a598,spinner:#8ec07c,header:#a89984,border:#7c6f64,label:#fabd2f,query:#ebdbb2,separator:#3c3836,scrollbar:#7c6f64,preview-border:#7c6f64,preview-label:#fabd2f,preview-fg:#ebdbb2,preview-bg:#282828"

fzf_theme() {
  fzf --layout=reverse --height=100% \
      --border=rounded --border-label=" Command palette " --border-label-pos=3 \
      --prompt="▸ " --pointer="▶" --marker="▶" \
      --info=inline-right --highlight-line \
      --preview-window='right,52%,border-left,wrap' \
      --preview-label=' detalhe ' --preview-label-pos=3 \
      --color="$GU" "$@"
}

# Prompt for a new name via fzf --print-query (never tmux command-prompt,
# which fights the popup). Prefilled with the current name.
prompt_text() {
  local initial="${1:-}" label="${2:-Novo nome}" out
  out="$(fzf_theme --print-query --border=none --no-info \
          --query="$initial" \
          --header="$label   (Enter confirma · Esc cancela)" \
          --preview-window=hidden <<< "$initial" 2>/dev/null)"
  printf '%s' "${out%%$'\n'*}"
}

# --- Dump / build ------------------------------------------------------------
candidates="$(emit_candidates)"

if [[ "$DUMP" == "1" ]]; then
  printf '%s\n' "$candidates"
  exit 0
fi

# --- Stage 1: pick a section ------------------------------------------------
# Candidate field 1 is the section name. Order them the way the user wants.
ordered_sections=""
for s in "Ações" "Keybinds" "Sessões" "Janelas" "Panes" "Presets"; do
  if printf '%s\n' "$candidates" | cut -f1 | grep -qxF "$s"; then
    n="$(printf '%s\n' "$candidates" | awk -F'\t' -v s="$s" '$1==s' | wc -l)"
    ordered_sections+="$(printf '%s\t%s (%s)\n' "$s" "$s" "$n")"$'\n'
  fi
done

section="$(printf '%s' "$ordered_sections" | fzf_theme \
            --delimiter=$'\t' --with-nth=2 --accept-nth=1 \
            --header="Seções   ·   Enter: abrir   ·   Esc: cancelar" )" || true
[[ -n "$section" ]] || exit 0

# --- Stage 2: candidates filtered to that section --------------------------
filtered="$(printf '%s\n' "$candidates" | awk -F'\t' -v s="$section" '$1==s')"

out="$(set +o pipefail; printf '%s\n' "$filtered" | fzf_theme \
        --delimiter=$'\t' --with-nth=2,3 --accept-nth=4,5 \
        --header="Enter: executar   Esc: cancelar" \
        --preview='printf %s {6} | base64 -d 2>/dev/null | bat --color=always --style=numbers --language=bash --paging=never 2>/dev/null' )"
rc=$?

# Esc / Ctrl-C (fzf 130) or no selection: exit clean, no side effects.
if [[ $rc -ne 0 || -z "$out" ]]; then
  exit 0
fi

action=""; payload=""
IFS=$'\t' read -r action payload <<< "$out"

run() { "$TMUX_BIN" "$@" >/dev/null 2>&1 || true; }
cli=(); [[ -n "$client" ]] && cli=(-c "$client")

case "$action" in
  split-right)  run split-window  -h  -c "$cwd" -t "$target" ;;
  split-left)   run split-window  -hb -c "$cwd" -t "$target" ;;
  split-down)   run split-window  -v  -c "$cwd" -t "$target" ;;
  split-up)     run split-window  -vb -c "$cwd" -t "$target" ;;
  new-window)   run new-window    -c "$cwd" -t "$sess" ;;
  kill-pane)    run kill-pane     -t "$target" ;;
  zoom-pane)    run resize-pane   -Z -t "$target" ;;
  next-window)  run next-window   -t "$sess" ;;
  prev-window)  run previous-window -t "$sess" ;;
  next-layout)  run next-layout   -t "$win" ;;
  copy-mode)    run copy-mode     -t "$target" ;;
  rename-window)
    wname="$(tm display-message -p -t "$target" '#{window_name}')"
    new="$(prompt_text "$wname" 'Novo nome da janela')"
    [[ -n "$new" ]] && run rename-window -t "$win" -- "$new"
    ;;
  rename-session)
    sname="$(tm display-message -p -t "$target" '#{session_name}')"
    new="$(prompt_text "$sname" 'Novo nome da sessão')"
    [[ -n "$new" ]] && run rename-session -t "$sess" -- "$new"
    ;;
  reload)       run source-file "$CONF" \; display-message "Config recarregada!" ;;
  detach)       run detach-client -s "$sess" ;;
  kill-session) run kill-session -t "$sess" ;;
  info)
    msg="${payload//#/##}"
    run display-message -t "$target" "$msg"
    ;;
  session)      run switch-client "${cli[@]}" -t "$payload" ;;
  window)
    IFS='|' read -r ss ww <<< "$payload"
    run switch-client "${cli[@]}" -t "$ss" \; select-window -t "$ww"
    ;;
  pane)
    IFS='|' read -r ss ww pp <<< "$payload"
    run switch-client "${cli[@]}" -t "$ss" \; select-window -t "$ww" \; select-pane -t "$pp"
    ;;
  preset)
    [[ -x "$payload" ]] && "$payload" >/dev/null 2>&1 || true
    ;;
esac

exit 0
