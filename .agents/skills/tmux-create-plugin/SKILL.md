---
name: tmux-create-plugin
description: How to create local in-tree plugins in this tmux config — the plugins/<name>.tmux registration + plugins/<name>/ tree layout, the loader that sources plugins/*.tmux, a minimal entry.sh template, and the native OpenCode tool that scaffolds them. Use when the user wants to build their own plugin or scaffold a new local plugin.
compatibility: opencode
---

# Creating local plugins

This repo can host in-tree plugins that need no plugin manager and can later be
extracted into standalone repositories. **Local only**: never TPM, never fetch
remote code.

## Layout

- `plugins/<name>.tmux` — the **registration/spec** file. Declares the plugin's
  own binds/options (the plugin's `keys`) and is sourced by the loader.
- `plugins/<name>/` — the **pure plugin tree** (implementation): `entry.sh` plus
  assets. Keep it self-contained; no install step.

The loader at the end of `tmux.conf` globs the registration files:

```tmux
source-file ~/.config/tmux/plugins/*.tmux
```

`source-file` is silent on no match, so the glob is safe at any plugin count.
Adding a plugin = adding a file; `tmux.conf` is not edited.

## Scaffolding

A native OpenCode custom tool lives at `.opencode/tools/new-tmux-plugin.ts`
(tool name `new-tmux-plugin`) and scaffolds both files:

- Call it with `name` (required), optionally `key` (defaults to the first letter
  of `name`) and `force = true`.
- `<name>` must match `[a-z][a-z0-9-]*`.
- Refuses to overwrite an existing `plugins/<name>.tmux` or
  `plugins/<name>/entry.sh` unless `force = true`.
- Generates the registration (with a
  `bind <key> run-shell "~/.config/tmux/plugins/<name>/entry.sh"` line) and the
  minimal `entry.sh` below (chmod `0o755`).

It imports `@opencode-ai/plugin`, declared in `.opencode/package.json`; OpenCode
runs `bun install` at startup, so the dependency resolves from
`.opencode/node_modules`. Never place a plain CLI script here — OpenCode imports
every `*.ts` in `.opencode/tools/` on startup.

If the tool is unavailable to the current agent, create the two files by hand
following the layout above.

## Minimal template

```bash
#!/usr/bin/env bash
# ~/.config/tmux/plugins/<name>/entry.sh
set -euo pipefail

: "${TMUX:?run this plugin from inside tmux}"

# TODO: implement the plugin.
tmux display-message "<name>: not implemented yet"
```

Make it executable (`chmod +x`). Keep the plugin self-contained: it ships with
the repo, with no install step and no external plugin manager.

## Procedure

1. Read `AGENTS.md` and an existing plugin (`plugins/command-palette.tmux` +
   `plugins/command-palette/entry.sh`).
2. Scaffold with the `new-tmux-plugin` tool, or create the two files by hand
   following the layout above.
3. Implement the plugin under `plugins/<name>/`; declare its binds in
   `plugins/<name>.tmux`.
4. Validate: private-socket load and confirm the bind in `list-keys -T prefix`
   (see `tmux-add-plugin`).
5. Tell the user to reload with `C-a r` — the loader picks up the new file, no
   `tmux.conf` edit needed.

## Guardrail

**Local only.** Never add TPM, `set -g @plugin`, or any `run-shell` that fetches
remote code; the only `run-shell` a plugin should use is to invoke its own
`entry.sh`.
