#!/usr/bin/env bash
# layout: editor + terminal — nvim . à esquerda, shell à direita.
: "${LAYOUT_LABEL:=Editor + terminal}"
: "${LAYOUT_DESC:=editor à esquerda, terminal à direita}"
: "${LAYOUT_SPEC:=H(editor:50,terminal:50)}"
: "${LAYOUT_CMD_editor:=nvim .}"
source "$(dirname -- "${BASH_SOURCE[0]}")/../layout-lib.sh"
layout_main "$@"
