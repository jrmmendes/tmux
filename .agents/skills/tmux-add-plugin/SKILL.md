---
name: tmux-add-plugin
description: How to add, change or configure a local in-tree plugin in this tmux config — the plugins/<name>.tmux registration file, the plugins/<name>/ implementation tree, and the loader that sources plugins/*.tmux. Use when the user wants to add a plugin, change a plugin's binds/options, or wire up a new plugin.
compatibility: opencode
---

# Adding and configuring local plugins

This repo has **no plugin manager**: no TPM, no `set -g @plugin`, no fetching
remote code. Local (in-tree) plugins are supported and live under `plugins/`.

## Layout

- `plugins/<name>.tmux` — the **registration/spec** file: it declares the
  plugin's OWN binds/options (the plugin's `keys`).
- `plugins/<name>/` — the **pure plugin tree** (implementation): `entry.sh` plus
  any assets.

A plugin's keybinds live in its `plugins/<name>.tmux` file — **not** in
`tmux.conf`'s Keybindings section. `tmux.conf` stays a plain tmux config; the
plugin file carries everything the plugin adds.

## Loader

The end of `tmux.conf` sources every registration file with a native tmux glob:

```tmux
source-file ~/.config/tmux/plugins/*.tmux
```

The glob is silent when there is no match, so it is safe with zero plugins.
Because of this, **adding a plugin = adding a file** — no edit to `tmux.conf` is
needed.

## Procedure

1. Read `AGENTS.md` and a neighbouring plugin (`plugins/command-palette.tmux` +
   `plugins/command-palette/entry.sh`) to match style.
2. Decide the concern name (`[a-z][a-z0-9-]*`). One concern per plugin file.
3. If the concern already has a file, **edit that file** instead of adding a new
   one — the last `bind` for a key wins.
4. Declare the plugin's binds in `plugins/<name>.tmux`; put the implementation in
   `plugins/<name>/` (e.g. `entry.sh`, executable).
5. Validate (below) and tell the user to reload with `C-a r`.

## Rules

- **Local only.** Never add TPM, `set -g @plugin`, or a `run-shell` that fetches
  remote code. A plugin is just files in this repo.
- **Prefix `C-a`.** Plugin binds go in the prefix table, same as core binds; do
  not add `bind -n M-...` (a root-table `Alt-*` would swallow the nvim `<A-*>`
  maps).
- Keep it self-contained: the implementation tree ships with the repo, with no
  install step and no external plugin manager.
- Prefer built-in tmux commands inside the plugin; use `run-shell` only to call
  the plugin's own `entry.sh`, never to download anything.

## Validate

Load on a **private socket** and confirm the plugin's bind landed in the prefix
table (`list-keys`, not just a clean load — a bind can load and still be dead in
the wrong table/scope):

```bash
tmux -L plugin-test -f ~/.config/tmux/tmux.conf new-session -d -s smoke
tmux -L plugin-test list-keys -T prefix | grep -E '<key>'
tmux -L plugin-test kill-server
```

Then remind the user to reload with `C-a r` (the loader globs
`plugins/*.tmux` automatically).
