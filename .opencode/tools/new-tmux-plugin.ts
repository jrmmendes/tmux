import { tool } from "@opencode-ai/plugin"
import { chmodSync, existsSync, mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"

const registration = (name: string, key: string) => `# plugins/${name}.tmux — registration for the local "${name}" plugin.
# The loader at the end of tmux.conf sources plugins/*.tmux, so this file
# declares the plugin's OWN binds; adding a plugin = adding a file.
bind ${key} run-shell "~/.config/tmux/plugins/${name}/entry.sh"
`

const entryScript = (name: string) => `#!/usr/bin/env bash
# ~/.config/tmux/plugins/${name}/entry.sh
# Implementation for the local "${name}" plugin. Run from its registration:
#   plugins/${name}.tmux -> bind <key> run-shell "~/.config/tmux/plugins/${name}/entry.sh"
#
# "\$TMUX" is set inside tmux; do the plugin's work here. Keep it self-contained:
# local only, no TPM, never fetch remote code.
set -euo pipefail

: "\${TMUX:?run this plugin from inside tmux}"

# TODO: implement the "${name}" plugin.
tmux display-message "${name}: not implemented yet"
`

export default tool({
  description:
    'Scaffold a local tmux plugin: plugins/<name>.tmux (registration + bind) plus plugins/<name>/entry.sh, and the exact bind line.',
  args: {
    name: tool.schema
      .string()
      .regex(/^[a-z][a-z0-9-]*$/)
      .describe("Plugin name; must match [a-z][a-z0-9-]*"),
    key: tool.schema
      .string()
      .optional()
      .describe(
        'Prefix-table key for the bind (e.g. "f" or "1"). Defaults to the first letter of name.',
      ),
    force: tool.schema.boolean().optional().describe("Overwrite existing files"),
  },
  async execute(args, context) {
    const name = args.name
    const key = args.key ?? name[0]
    const spec = join(context.worktree, "plugins", `${name}.tmux`)
    const entry = join(context.worktree, "plugins", name, "entry.sh")

    if (!args.force && (existsSync(spec) || existsSync(entry))) {
      throw new Error(
        `plugins/${name}.tmux or plugins/${name}/entry.sh already exists (use force: true to overwrite)`,
      )
    }

    mkdirSync(dirname(entry), { recursive: true })
    writeFileSync(spec, registration(name, key))
    writeFileSync(entry, entryScript(name))
    chmodSync(entry, 0o755)

    return [
      `created plugins/${name}.tmux`,
      `created plugins/${name}/entry.sh`,
      "",
      `bind: C-a ${key}`,
      "",
      "reload with C-a r (the loader globs plugins/*.tmux automatically — no tmux.conf edit needed)",
    ].join("\n")
  },
})
