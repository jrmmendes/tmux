#!/usr/bin/env bash
# =============================================================================
# ~/.config/tmux/plugins/command-palette/layout-lib.sh
# Motor compartilhado dos layouts (in-tree, sem TPM). Um arquivo em
# plugins/command-palette/layouts/<slug>.sh define os dados e chama layout_main:
#
#   LAYOUT_LABEL      rótulo legível (preview + palette)
#   LAYOUT_DESC       descrição curta
#   LAYOUT_SPEC       árvore no DSL: (H|V)"(" child,... ")"[:peso] | NOME[:peso]
#                     H = lado a lado, V = empilhado; folha = rótulo do pane
#   LAYOUT_CMD_<role> comando a executar no pane (ex.: opencode, "nvim .")
#   LAYOUT_DIR_<role> diretório em que o pane deve rodar
#
# O parsing/desenho/planejamento vive em layout.awk (modos figure|plan|roles).
# figure = preview; roles = rótulos; plan = script bash que chama layout_leaf.
#
# Valores gruvbox-hard (fonte única: ~/.config/nvim/core/config/statusline.lua):
#   amarelo #fabd2f, cinza #a89984.
# =============================================================================
set -uo pipefail

_LAYOUT_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMUX_BIN="${TMUX_BIN:-tmux}"
# pares pane/role acumulados durante apply (usados no sweep final de títulos).
_LAYOUT_LEAVES=()

# O plano do awk chama `tmux` literalmente; resolvemos TMUX_BIN para um caminho
# absoluto e definimos tmux()/tm() para que tanto os helpers quanto o plano
# sigam TMUX_BIN sem recursão (mesmo se TMUX_BIN=="tmux").
_LAYOUT_TMUX_REAL="$(command -v "$TMUX_BIN" 2>/dev/null || printf '%s' "$TMUX_BIN")"
tm()   { "$_LAYOUT_TMUX_REAL" "$@" 2>/dev/null; }
tmux() { "$_LAYOUT_TMUX_REAL" "$@" 2>/dev/null; }

# --- metadados: LABEL \t DESC (lido pela palette) ----------------------------
layout_meta() { printf '%s\t%s\n' "$LAYOUT_LABEL" "$LAYOUT_DESC"; }

# --- papéis: um rótulo por linha, na ordem do spec ---------------------------
layout_roles() {
  awk -v mode=roles -v spec="$LAYOUT_SPEC" -f "$_LAYOUT_LIB_DIR/layout.awk"
}

# centraliza texto na largura cols; a cor (ANSI) fica separada do texto, então
# o padding é calculado pelo comprimento "cru" — ANSI não conta.
_center() {
  local cols="$1" text="$2" color="${3:-}"
  local pad=$(( (cols - ${#text}) / 2 ))
  (( pad < 0 )) && pad=0
  printf '%*s%s%s\033[0m\n' "$pad" "" "$color" "$text"
}

# --- preview: preenche a janela do preview do fzf ----------------------------
layout_figure() {
  local cols lines
  cols="${FZF_PREVIEW_COLUMNS:-60}"
  lines="${FZF_PREVIEW_LINES:-20}"

  # legenda: papéis que têm LAYOUT_CMD_<role>
  local -a legend=(); local r var
  while IFS= read -r r; do
    [[ -n "$r" ]] || continue
    var="LAYOUT_CMD_$r"
    [[ -n "${!var:-}" ]] && legend+=("$r → ${!var}")
  done < <(layout_roles)
  local legend_n=${#legend[@]}

  # w = clamp(cols-6, 18..72); h = clamp(lines-5-legenda, 5..18)
  local w=$(( cols - 6 )); (( w < 18 )) && w=18; (( w > 72 )) && w=72
  local h=$(( lines - 5 - legend_n )); (( h < 5 )) && h=5; (( h > 18 )) && h=18

  local yellow=$'\033[38;2;250;189;47m' dim=$'\033[38;2;168;153;132m'

  printf '\n'
  _center "$cols" "$LAYOUT_LABEL" "$yellow"
  printf '\n'
  local ln
  while IFS= read -r ln; do
    _center "$cols" "$ln" ""
  done < <(awk -v mode=figure -v spec="$LAYOUT_SPEC" -v W="$w" -v H="$h" \
                -f "$_LAYOUT_LIB_DIR/layout.awk")
  printf '\n'
  local i
  for (( i=0; i<legend_n; i++ )); do
    _center "$cols" "${legend[i]}" "$dim"
  done
}

# --- aplica o layout no alvo: a folha é o pane, o papel é o título -----------
# O plano (mode=plan) cria os panes via `tmux split-window` e chama layout_leaf.
layout_leaf() {
  local pane="$1" role="$2"

  local cmdvar="LAYOUT_CMD_$role" dirvar="LAYOUT_DIR_$role"
  local cmd="${!cmdvar:-}" dir="${!dirvar:-}"

  if [[ "$pane" == "$P_ROOT" ]]; then
    # pane raiz já existe: digita (uma só linha) em vez de respawnar. Enviar
    # cd e cmd em linhas separadas provoca duas reescritas de título do shell
    # (allow-rename), que correm com o select-pane -T abaixo; numa linha só há
    # uma atualização e o título do papel vence.
    local line=""
    if [[ -n "$dir" && "$dir" != "$CWD" ]]; then
      line="cd $(printf '%q' "$dir")"
    fi
    if [[ -n "$cmd" ]]; then
      line="${line:+$line && }$cmd"
    fi
    [[ -n "$line" ]] && tm send-keys -t "$pane" "$line" Enter
  else
    if [[ -n "$cmd" ]]; then
      tm respawn-pane -k -t "$pane" -c "${dir:-$CWD}" "$cmd"
    elif [[ -n "$dir" ]]; then
      tm respawn-pane -k -t "$pane" -c "$dir"
    fi
  fi

  # título imediato (papel visível já no border) + registra para o sweep final.
  tm select-pane -T "$role" -t "$pane"
  _LAYOUT_LEAVES+=("$pane" "$role")
}

layout_apply() {
  P_ROOT="$1"; CWD="$2"
  export P_ROOT CWD
  _LAYOUT_LEAVES=()
  # o plano usa $P_ROOT e layout_leaf; roda no shell atual (source).
  source <(awk -v mode=plan -v spec="$LAYOUT_SPEC" -f "$_LAYOUT_LIB_DIR/layout.awk")

  # Sweep final: o shell pinta o título do prompt (ocioso) ou do comando
  # (preexec) DEPOIS do select-pane imediato e venceria o papel. Espera o
  # settle e reaplica todos os títulos de uma vez (um único sleep por apply).
  if (( ${#_LAYOUT_LEAVES[@]} > 0 )); then
    sleep "${_LAYOUT_TITLE_SETTLE:-0.3}"
    local i
    for (( i=0; i<${#_LAYOUT_LEAVES[@]}; i+=2 )); do
      tm select-pane -T "${_LAYOUT_LEAVES[i+1]}" -t "${_LAYOUT_LEAVES[i]}"
    done
  fi
}

# --- dispatch ----------------------------------------------------------------
layout_main() {
  case "${1:-}" in
    meta)   layout_meta ;;
    figure) layout_figure ;;
    roles)  layout_roles ;;
    apply)  shift; layout_apply "$@" ;;
    *) printf 'uso: %s {meta|figure|roles|apply <pane> <cwd>}\n' "${BASH_SOURCE[0]}" >&2; return 2 ;;
  esac
}
