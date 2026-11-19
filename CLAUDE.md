# CLAUDE.md

Guidance for Claude Code (and other AI assistants) working in this repository.

## What this repository is

**Muscle Memory**: plugins that keep the habits of one IDE (keymap, colors, navigation tools) inside another editor. Each plugin is an independent project; the repository only groups them and shares conventions.

## Layout

Two levels: **the IDE whose habits are kept**, then **the editor the plugin runs in**.

```
<ide>/                  e.g. intellij/ (habits from IntelliJ IDEA)
├── README.md           lists this IDE's plugins
└── <editor>/           e.g. vscode/ (a VS Code extension) — one self-contained plugin
    ├── README.md       install, features, shortcut tables, differences, settings, development
    ├── CHANGELOG.md    one "## x.y.z" section per release, newest first
    └── …               the editor's own manifest, sources, tests and build files
```

- `intellij/vscode/` makes VS Code feel like IntelliJ IDEA; `vscode/intellij/` would make IntelliJ IDEA feel like VS Code.
- A plugin never imports from another plugin. Shared ideas are copied and adapted to each editor's API.
- Build, test and dependency commands run **inside the plugin folder**, never at the root. Each plugin's README has a Development section with its commands.

| Plugin | Language / build | Test and package |
|---|---|---|
| `intellij/vscode/` | TypeScript, npm, `@vscode/vsce` | `npm test`; `npm run package` (lint, tests, `.vsix` into `dist/`) |

Add a row when a plugin is added.

## Naming and branding

- Product names and identifiers are neutral: **Muscle Memory**. Themes are `Muscle Memory Dark` / `Muscle Memory Light`; commands, settings and context keys use the `musclememory.` prefix; output channels and command categories are `Muscle Memory`.
- Never use a vendor's product name, logo or trademark in a plugin's name, ID, display name, theme name or icon. Folder names (`intellij/`, `vscode/`) and descriptive references in docs and comments ("like IntelliJ IDEA's Switcher", "Differences from IntelliJ IDEA") are fine.

## Conventions every plugin follows

### Keymaps

- Cover macOS, Windows and Linux. Follow the original IDE's own keymap for each system rather than translating Cmd to Ctrl.
- A shortcut that exists on one system only is restricted to it (in VS Code: `"when": "isMac && …"`). A macOS key (Cmd) must never be active on Windows or Linux.
- When changing keybindings, verify that the bindings for the other systems are unchanged, and update the plugin README's shortcut tables (one column per system) and its "Differences" section, including editor defaults the keymap replaces and keys the OS or desktop reserves.

### Themes

- Ship themes in pairs, dark and light, that give every syntax role a color in both. A color added to one theme gets its counterpart in the other.
- Colors drawn from code (decorations, gutter icons) need a dark and a light value too, and are only applied while one of the plugin's own themes is active.
- Keep syntax colors readable on the editor background (aim for a 4.5:1 contrast ratio; comments and annotations may be fainter when the original IDE's palette is).

### Language-server work

Features that query the editor's language servers must not slow down typing: limit concurrent requests, look up only what is on screen, cache answers per document version, and cancel outdated work.

### Documentation

- Plugin README: what it does, install, shortcut tables per OS, differences from the original IDE, settings, performance notes, development commands.
- Root `README.md` "Plugins" table and `<ide>/README.md` list every plugin with its latest released version. Update both when adding or releasing a plugin.
- Write for people using the plugin: what they can do and what changes for them, not file or function names.

## Releases

- Each plugin is released on its own as a GitHub release tagged `<ide>-<editor>-v<version>` (e.g. `intellij-vscode-v0.0.1`), with its installable package attached. Versions follow semver and live in the plugin's manifest.
- Use the **`/release` skill** (`.claude/skills/release/`) to release: it checks the tree, bumps the version, drafts the changelog, builds through the **`plugin-builder` agent** (`.claude/agents/`), and asks before pushing or publishing. Adding a plugin for a new editor means adding a row to the skill's host table and a build recipe to the agent first.
- Never force-push `main` or move a release tag once published.

## Credentials and privacy

- This repository is public. Never commit or print credentials: tokens, keys, passwords, `.env` files, `secrets*.json`, `.npmrc` with tokens, signing keys. Rely on the developer's existing `gh` / git login.
- Do not add personal data (e-mail addresses, home-directory paths, account names) to files. Code examples in docs use neutral names.
- Build output (`node_modules/`, `out/`, `dist/`, `build/`) is ignored per plugin and never committed.

## Before finishing a change

- Run the plugin's lint and tests; build the package if the manifest, themes or keymap changed.
- Update the plugin's README and, for user-visible changes, add a line to the top section of its `CHANGELOG.md` (create an unreleased section if needed).
- Keep each commit to one plugin where possible, with a message that says what changes for users.
