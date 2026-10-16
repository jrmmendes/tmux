#!/usr/bin/env bash
# =============================================================================
# ~/.config/tmux/plugins/command-palette/save-layout.sh
# Captura a janela atual e delega ao opencode a criação de um novo layout
# em plugins/command-palette/layouts/<slug>.sh (skill tmux-add-layout).
#
# Modos:
#   capture <target-pane> <window-id> <client-tty>
#     Snapshot (geometria + tabela de panes) -> prompt PT-BR em arquivo
#     temporário -> popup do opencode já apontando para o prompt. O caminho do
#     prompt vai pelo AMBIENTE (valor de uma linha só, seguro no -e).
#   popup <prompt-file> <client-tty>
#     Abre o popup num cliente explícito. É o fallback robusto: quando o
#     display-popup aninhado (dentro do popup da palette) é engolido, o
#     capture relança este modo via `run-shell -b` após a palette fechar.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMUX_BIN="${TMUX_BIN:-tmux}"
tm() { "$TMUX_BIN" "$@" 2>/dev/null; }

# --- prompt PT-BR entregue ao opencode ---------------------------------------
build_prompt() {
  local winline="$1" panes="$2"
  # heredocs citados (<<'EOF'): mantêm $, $@ e ${VAR:=...} LITERAIS no prompt;
  # o snapshot entra pelos dois printf no meio.
  cat <<'EOF'
Você vai salvar a janela atual do tmux como um layout reutilizável da
command palette (C-a f > Layouts). Siga exatamente isto:

1. Carregue a skill `tmux-add-layout` (leia
   ~/.config/tmux/.agents/skills/tmux-add-layout/SKILL.md).
2. Crie um novo arquivo executável em
   /home/mendes/.config/tmux/plugins/command-palette/layouts/<slug>.sh, com um
   slug curto e descritivo em [a-z][a-z0-9-]*, que REPRODUZA a janela
   capturada abaixo. Não edite nada fora de layouts/; nunca toque em
   ~/.config/nvim.
3. O arquivo define, com `: "${VAR:=default}"`, LAYOUT_LABEL, LAYOUT_DESC,
   LAYOUT_SPEC e (por papel) LAYOUT_CMD_<role>/LAYOUT_DIR_<role>; depois faz
   `source "$(dirname -- "${BASH_SOURCE[0]}")/../layout-lib.sh"` e
   `layout_main "$@"` (padrão idêntico aos layouts existentes).
4. LAYOUT_SPEC no DSL: (H|V)"(" child ("," child)+ ")"[:peso] | NOME[:peso].
   H = lado a lado, V = empilhado; folha = rótulo do pane. Dimensões/ordem vêm
   da geometria capturada (larguras/alturas relativas viram pesos).
5. Os papéis (<role>) vêm dos títulos dos panes (pane_title) e, quando vazios,
   do comando em execução (pane_current_command). LAYOUT_CMD_<role> preserva o
   app rodando (ex.: opencode, "nvim .") e LAYOUT_DIR_<role> preserva o
   diretório (pane_current_path) de cada pane.
6. Valide: bash -n no arquivo, `chmod +x`, e
   `plugins/command-palette/layouts/<slug>.sh figure` (a figura deve imitar a
   geometria capturada).

Snapshot da janela (dimensão + layout do tmux):
EOF
  printf '%s\n\n' "$winline"
  cat <<'EOF'
Tabela de panes: índice<TAB>esquerda,topo larguraxaltura<TAB>path<TAB>cmd<TAB>título
EOF
  printf '%s\n' "$panes"
}

# --- popup -------------------------------------------------------------------
# -c <client> fixa o cliente quando conhecido; sem ele usa o cliente atual.
open_popup() {
  local file="$1" client="$2"; shift 2
  local cli=(); [[ -n "$client" ]] && cli=(-c "$client")
  tm display-popup -E -w 92% -h 85% -d "$HOME/.config/tmux" "${cli[@]}" \
    -e LAYOUT_PROMPT_FILE="$file" -T " opencode · salvar layout " \
    'opencode --prompt "$(cat "$LAYOUT_PROMPT_FILE")"'
}

capture() {
  local target="$1" win="$2" client="${3:-}"
  local winline panes tmp
  winline="$(tm display-message -p -t "$win" '#{window_width}x#{window_height} #{window_layout}')"
  panes="$(tm list-panes -t "$win" -F '#{pane_index}	#{pane_left},#{pane_top} #{pane_width}x#{pane_height}	#{pane_current_path}	#{pane_current_command}	#{pane_title}')"

  tmp="$(mktemp "${TMPDIR:-/tmp}/tmux-layout-prompt.XXXXXX")"
  build_prompt "$winline" "$panes" > "$tmp"

  # EVIDÊNCIA (testado em tmux 3.7c): um display-popup ABERTO DE DENTRO do popup
  # da palette (entry.sh) é engolido — retorna 0, mas o comando do popup interno
  # nunca roda. Por isso o caminho robusto é reabrir DEPOIS que a palette fecha,
  # num cliente explícito, via run-shell -b (assíncrono, sobrevive ao popup).
  tm run-shell -b "sleep 0.3; '$SCRIPT_DIR/save-layout.sh' popup '$tmp' '$client'"
}

popup() {
  local file="$1" client="${2:-}"
  open_popup "$file" "$client"
  rm -f "$file"
}

mode="${1:-}"; shift || true
case "$mode" in
  capture) capture "$@" ;;
  popup)   popup "$@" ;;
  *) printf 'uso: %s {capture <pane> <win> <client>|popup <file> <client>}\n' "$0" >&2; exit 2 ;;
esac
