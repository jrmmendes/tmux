#!/usr/bin/env bash
# layout: agente + editor + terminal — opencode à esquerda; nvim . e shell à direita.
: "${LAYOUT_LABEL:=Agente + editor + terminal}"
: "${LAYOUT_DESC:=agente à esquerda; editor e shell à direita}"
: "${LAYOUT_SPEC:=H(agent:50,V(editor:50,terminal:50):50)}"
: "${LAYOUT_CMD_agent:=opencode}"
: "${LAYOUT_CMD_editor:=nvim .}"
source "$(dirname -- "${BASH_SOURCE[0]}")/../layout-lib.sh"
layout_main "$@"
