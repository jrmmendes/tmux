#!/usr/bin/env bash
# layout: customizar — 3 agentes opencode, um por repo de config, lado a lado.
: "${LAYOUT_LABEL:=Customizar (3 agentes)}"
# As chaves de {opencode,nvim,tmux} encerrariam o ${VAR:=...} inline; por isso
# o default (com chaves) vai numa variável citada e o := só o referencia.
_layout_desc_default='opencode em ~/.config/{opencode,nvim,tmux}, lado a lado'
: "${LAYOUT_DESC:=$_layout_desc_default}"
: "${LAYOUT_SPEC:=H(opencode:1,neovim:1,tmux:1)}"
: "${LAYOUT_CMD_opencode:=opencode}"
: "${LAYOUT_CMD_neovim:=opencode}"
: "${LAYOUT_CMD_tmux:=opencode}"
: "${LAYOUT_DIR_opencode:=$HOME/.config/opencode}"
: "${LAYOUT_DIR_neovim:=$HOME/.config/nvim}"
: "${LAYOUT_DIR_tmux:=$HOME/.config/tmux}"
source "$(dirname -- "${BASH_SOURCE[0]}")/../layout-lib.sh"
layout_main "$@"
