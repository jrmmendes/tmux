import { tool } from "@opencode-ai/plugin"
import { execFileSync } from "node:child_process"
import { chmodSync, existsSync, mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"

const defaultSpec = "H(agent:50,terminal:50)"

// The DSL parser is the single source of truth: layout.awk exits 2 (with a
// message on stderr) for an invalid spec, so scaffolding can never write a
// layout that would silently do nothing.
const assertValidSpec = (worktree: string, spec: string) => {
  try {
    execFileSync(
      "awk",
      [
        "-v",
        "mode=roles",
        "-v",
        `spec=${spec}`,
        "-f",
        join(worktree, "plugins", "command-palette", "layout.awk"),
      ],
      { stdio: ["ignore", "ignore", "pipe"] },
    )
  } catch (error) {
    const stderr = (error as { stderr?: Buffer }).stderr?.toString().trim()
    throw new Error(`invalid spec ${JSON.stringify(spec)}${stderr ? ` — ${stderr}` : ""}`)
  }
}

// First role label inside the spec, skipping the H/V combinators.
const firstRole = (spec: string) => {
  const names = spec.match(/[A-Za-z_][A-Za-z0-9_-]*/g) ?? []
  return names.find((n) => n !== "H" && n !== "V") ?? "agent"
}

// A sensible starter command for well-known roles; otherwise the role itself.
const roleCommand = (role: string) => {
  switch (role.toLowerCase()) {
    case "agent":
    case "opencode":
      return "opencode"
    case "editor":
    case "neovim":
    case "nvim":
    case "vim":
      return "nvim"
    case "terminal":
    case "shell":
      return ""
    default:
      return role
  }
}

// Escape a value for a bash double-quoted string.
const q = (s: string) =>
  s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/`/g, "\\`").replace(/\$/g, "\\$")

const script = (name: string, label: string, desc: string, spec: string) => {
  const role = firstRole(spec).replace(/-/g, "_")
  const cmd = roleCommand(firstRole(spec))
  return `#!/usr/bin/env bash
# ~/.config/tmux/plugins/command-palette/layouts/${name}.sh
# Flow layout for the command palette "Layouts" section.
# One file = one layout: the palette globs layouts/*.sh, so adding this file
# is enough — no edit to entry.sh.
#
# spec DSL: H(...) panes side by side, V(...) stacked, NAME = role label,
#           :weight = relative size. Example: H(agent:50,terminal:50)
set -euo pipefail

: "\${LAYOUT_LABEL:=${q(label)}}"
: "\${LAYOUT_DESC:=${q(desc)}}"
: "\${LAYOUT_SPEC:=${q(spec)}}"

# Command launched in each role's pane (optional: unset = the default shell).
: "\${LAYOUT_CMD_${role}:=${q(cmd)}}"

source "$(dirname -- "\${BASH_SOURCE[0]}")/../layout-lib.sh"
layout_main "$@"
`
}

export default tool({
  description:
    'Scaffold a command-palette flow layout: plugins/command-palette/layouts/<name>.sh (one file = one "Layouts" entry).',
  args: {
    name: tool.schema
      .string()
      .regex(/^[a-z][a-z0-9-]*$/)
      .describe("Layout name; must match [a-z][a-z0-9-]* (used as the file slug)"),
    label: tool.schema
      .string()
      .optional()
      .describe("Palette label. Defaults to the name, title-cased with dashes -> spaces."),
    desc: tool.schema
      .string()
      .optional()
      .describe("Palette description. Defaults to the label plus the spec."),
    spec: tool.schema
      .string()
      .optional()
      .describe("DSL spec, e.g. H(agent:50,terminal:50). Defaults to H(agent:50,terminal:50)."),
    force: tool.schema.boolean().optional().describe("Overwrite an existing file"),
  },
  async execute(args, context) {
    const name = args.name
    const spec = args.spec ?? defaultSpec
    const label =
      args.label ??
      name
        .split("-")
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
        .join(" ")
    const desc = args.desc ?? `Layout "${label}" (${spec})`
    const file = join(context.worktree, "plugins", "command-palette", "layouts", `${name}.sh`)

    assertValidSpec(context.worktree, spec)

    if (!args.force && existsSync(file)) {
      throw new Error(
        `plugins/command-palette/layouts/${name}.sh already exists (use force: true to overwrite)`,
      )
    }

    mkdirSync(dirname(file), { recursive: true })
    writeFileSync(file, script(name, label, desc, spec))
    chmodSync(file, 0o755)

    return [
      `created plugins/command-palette/layouts/${name}.sh`,
      "",
      "no reload needed: the palette globs layouts/*.sh on every run — pick it under C-a f → Layouts",
    ].join("\n")
  },
})
