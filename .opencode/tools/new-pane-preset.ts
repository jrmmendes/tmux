import { tool } from "@opencode-ai/plugin"
import { chmodSync, existsSync, mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"

const script = (name: string, key: string) => `#!/usr/bin/env bash
# ~/.config/tmux/presets/${name}.sh
# Pane-layout preset for the tmux cockpit. Run from a bind:
#   ${key} -> run-shell "~/.config/tmux/presets/${name}.sh"
#
# "\$TMUX" is set inside tmux; the presets build a layout in the current window.
set -euo pipefail

: "\${TMUX:?run this preset from inside tmux}"

# Example layout: editor on the left, two stacked agents on the right.
# Adjust the commands to the agent/TUI you actually run.
tmux split-window -h -c "#{pane_current_path}" 'nvim .'
tmux split-window -v -c "#{pane_current_path}" 'opencode'
tmux select-layout main-vertical
tmux select-pane -t 1
`

export default tool({
  description:
    'Scaffold a tmux pane-layout preset: presets/<name>.sh plus the exact bind line to add to tmux.conf.',
  args: {
    name: tool.schema
      .string()
      .regex(/^[a-z][a-z0-9-]*$/)
      .describe("Preset name; must match [a-z][a-z0-9-]*"),
    key: tool.schema
      .string()
      .optional()
      .describe(
        'Prefix-table key for the bind line (e.g. "a" or "1"). Defaults to the first letter of name.',
      ),
    force: tool.schema.boolean().optional().describe("Overwrite an existing file"),
  },
  async execute(args, context) {
    const name = args.name
    const key = args.key ?? name[0]
    const file = join(context.worktree, "presets", `${name}.sh`)

    if (!args.force && existsSync(file)) {
      throw new Error(`presets/${name}.sh already exists (use force: true to overwrite)`)
    }

    mkdirSync(dirname(file), { recursive: true })
    writeFileSync(file, script(name, key))
    chmodSync(file, 0o755)

    return [
      `created presets/${name}.sh`,
      "",
      "add this line to the Keybindings section of tmux.conf:",
      `  bind ${key} run-shell "~/.config/tmux/presets/${name}.sh"`,
      "",
      "then reload with C-a r (or: tmux source-file ~/.config/tmux/tmux.conf)",
    ].join("\n")
  },
})
