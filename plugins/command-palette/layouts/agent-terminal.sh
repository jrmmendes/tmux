#!/usr/bin/env bash
# layout: agente + terminal — opencode à esquerda, shell à direita.
: "${LAYOUT_LABEL:=Agente + terminal}"
: "${LAYOUT_DESC:=agente à esquerda, terminal à direita}"
: "${LAYOUT_SPEC:=H(agent:50,terminal:50)}"
: "${LAYOUT_CMD_agent:=opencode}"
source "$(dirname -- "${BASH_SOURCE[0]}")/../layout-lib.sh"
layout_main "$@"
