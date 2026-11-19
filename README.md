# Muscle Memory

IDE themes, styling and hotkeys that let you keep the habits of one IDE while you work in another.

Switching editors is mostly a fight with your fingers: Cmd+B no longer jumps to the declaration, Ctrl+Tab shows the wrong list, and the code looks unfamiliar. Muscle Memory brings the shortcuts, the colors and a few of the navigation tools you rely on to the editor you have open, so you can start working instead of relearning.

## How the repository is organized

Two levels: **the IDE whose habits you keep**, then **the editor the plugin runs in**.

```
musclememory/
├── intellij/          habits from IntelliJ IDEA…
│   ├── vscode/        …in VS Code (a VS Code extension)
│   └── xcode/         …in Xcode (key bindings, themes and snippets)
└── vscode/            habits from VS Code… (planned)
    └── intellij/      …in IntelliJ IDEA (an IntelliJ plugin)
```

So `intellij/vscode/` makes VS Code feel like IntelliJ IDEA, and `vscode/intellij/` would make IntelliJ IDEA feel like VS Code. Each plugin folder is a self-contained project with its own README, build and version, written in whatever its host editor needs (TypeScript for VS Code, Swift for Xcode, Kotlin for IntelliJ, and so on).

## Plugins

| Habits from | Used in | Folder | Status | What you get |
|---|---|---|---|---|
| IntelliJ IDEA | VS Code | [`intellij/vscode/`](intellij/vscode/) | 0.0.1 | Dark and light themes, C#/Kotlin/Python styling, keymap for macOS, Windows and Linux, inheritance markers, Switcher, Push preview |
| IntelliJ IDEA | Xcode | [`intellij/xcode/`](intellij/xcode/) | Unreleased | macOS keymap, dark and light themes, `sout`/`fori`-style live templates, optional editor commands (Extend Selection, Next Method, Toggle Case) and in-file Back / Forward |
| VS Code | IntelliJ IDEA | `vscode/intellij/` | Planned | |

## IntelliJ IDEA habits in VS Code

### Highlights

- **Two themes**: Muscle Memory Dark and Muscle Memory Light, the second built on IntelliJ Light's colors. Both add styling where VS Code's defaults are flat:
  - **C#**: distinct colors for types, method declarations, attributes, parameters and async code (every call that returns an awaitable), italic interfaces, underlined reassigned variables, struck-through `[Obsolete]` members.
  - **Kotlin**: IntelliJ's colors for function declarations, properties, annotations and extension calls.
  - **Python**: PyCharm-style `self`, builtins, keyword arguments and docstrings.
- **Keymap** for every system: IntelliJ IDEA's macOS layout on a Mac and its Windows/Linux layout elsewhere. VS Code picks the right one by itself. A few examples:

  | Action | macOS | Windows / Linux |
  |---|---|---|
  | Declaration / usages | Cmd+B | Ctrl+B |
  | Implementations | Cmd+Alt+B | Ctrl+Alt+B |
  | Super method | Cmd+U | Ctrl+U |
  | Search everywhere | Shift Shift | Shift Shift |
  | Recent files | Cmd+E | Ctrl+E |
  | Extend selection | Alt+Up | Ctrl+W |
  | Rename | Shift+F6 | Shift+F6 |
  | Show intention actions | Alt+Enter | Alt+Enter |
  | Commit / Push / Update | Cmd+K / Cmd+Shift+K / Cmd+T | Ctrl+K / Ctrl+Shift+K / Ctrl+T |
  | Run / Debug | Ctrl+R / Ctrl+D | Shift+F10 / Shift+F9 |

  The [full shortcut list](intellij/vscode/README.md#navigation) is in the extension's README.
- **Inheritance markers** for C#, Kotlin and Java: gutter arrows show what a class or member implements or overrides (↑) and what implements or overrides it (↓). Jump through the CodeLens above the declaration, the right-click menu on the arrow, or the hover links.
- **Switcher** (Ctrl+Tab): open files only, across all splits, without Settings, Output or panels. Hold Ctrl, press Tab to move, release to open.
- **Push preview** (Cmd+Shift+K / Ctrl+Shift+K): lists the outgoing commits and pushes only after you confirm.
- **Go to Super**, **Next/Previous Method** and **Select Opened File** commands.

### Install

1. Download `musclememory-<version>.vsix` from the newest `intellij-vscode-v…` release on the [Releases page](https://github.com/PavloZoria/musclememory/releases), or [build it](#build-from-source).
2. In VS Code: open the Command Palette (Cmd+Shift+P / Ctrl+Shift+P) → **Extensions: Install from VSIX…** → pick the file.
   From a terminal instead: `code --install-extension musclememory-<version>.vsix`
3. Command Palette → **Preferences: Color Theme** → **Muscle Memory Dark** or **Muscle Memory Light**.

The keymap is active as soon as the extension is installed, and it replaces several VS Code defaults: Cmd+K / Ctrl+K opens Commit (so two-step Cmd+K / Ctrl+K shortcuts stop working), Cmd+P / Ctrl+P is Parameter Info, and on Windows and Linux Ctrl+W extends the selection instead of closing the editor. To drop a single shortcut, open Keyboard Shortcuts, find it and remove it. [Differences from IntelliJ IDEA](intellij/vscode/README.md#differences-from-intellij-idea) has the full list, including the keys Linux desktops reserve.

### Requirements

| For | You need |
|---|---|
| Everything | VS Code 1.90 or later, on macOS, Windows or Linux |
| C# styling and inheritance markers | The C# extension, with its language server running |
| Kotlin styling and markers | The "Kotlin by JetBrains" extension |
| Java markers | A Java language server that answers type-hierarchy requests |

### Settings

| Setting | Default | |
|---|---|---|
| `musclememory.inheritanceMarkers` | `true` | Gutter arrows for inheritance, with the right-click menu |
| `musclememory.inheritanceCodeLens` | `true` | Clickable `↑ implements …` / `↓ N implementations` above declarations |
| `musclememory.csharp.awaitableCalls` | `true` | Async-colored calls that return an awaitable; turn off to skip the hover lookups this needs |

### Performance

The styling and markers ask the language server for outlines, hovers and type hierarchies. To keep that out of the way of completions and diagnostics, at most 4 of these requests run at once, only code on screen is looked up, answers are cached per file version, and work for an outdated version is cancelled as you type. Timings and errors are logged under **Output → Muscle Memory**.

## IntelliJ IDEA habits in Xcode

Xcode doesn't load plugins that change its interface, so the Xcode plugin is made of what Xcode lets you add: a key binding set, color themes, code snippets and an optional Source Editor Extension.

- **Keymap**: IntelliJ IDEA's macOS keys on Xcode's commands, such as Cmd+B (Jump to Definition), Cmd+Option+Left / Right (Back / Forward), Ctrl+Tab (previous tab), Cmd+E (Recent Files), Shift+F6 (Rename), Alt+Cmd+L (Format File), Cmd+Backspace (Delete Line), Cmd+K / Shift+Cmd+K / Cmd+T (Commit / Push / Pull), Ctrl+R (Run), F8 / F7 / Shift+F8 (Step Over / Into / Out). The Xcode keys this displaces, such as Cmd+B for Build, move or are cleared so no key does two things.
- **Themes**: Muscle Memory Dark and Muscle Memory Light with IntelliJ IDEA's colors, in JetBrains Mono when it is installed.
- **Live templates**: `sout`, `soutv`, `fori`, `iter`, `ifn` and `inn` for Swift.
- **Editor commands** (optional, built from source with a free Apple ID): Extend/Shrink Selection, Next/Previous Method, Toggle Case, Start New Line and Block Comment, under Editor → Muscle Memory with IntelliJ IDEA's keys. The same app keeps an IntelliJ-style Back / Forward history, so Cmd+Option+Left returns to earlier places in the same file too.

Install: download `musclememory-xcode-<version>.zip` from the newest `intellij-xcode-v…` release, quit Xcode, unzip it and run `install.sh`. The [Xcode plugin's README](intellij/xcode/README.md) has every shortcut, what Xcode can't do, and how to uninstall.

## Build from source

**VS Code extension**, with Node.js:

```sh
cd intellij/vscode
npm install          # tooling only; the extension has no runtime dependencies
npm test             # unit tests (Node's test runner)
npm run package      # lint, test, then build dist/musclememory-<version>.vsix
```

`npm run watch` recompiles on change. Source layout and the full feature docs are in [`intellij/vscode/README.md`](intellij/vscode/README.md).

**Xcode plugin**, with Xcode:

```sh
cd intellij/xcode
make test            # unit tests, including a check against the installed Xcode
make package         # lint, test, check, then dist/musclememory-xcode-<version>.zip
make install         # or install straight from the source folder
```

## Adding a plugin

1. Put it at `<ide-whose-habits-you-keep>/<editor-it-runs-in>/`, for example `vscode/intellij/` or `intellij/zed/`.
2. Make the folder self-contained: its own README (install, features, differences from the original IDE), build files and version.
3. Use the Muscle Memory names so the plugins read as one family: theme names `Muscle Memory Dark` / `Muscle Memory Light`, setting and command prefix `musclememory`.
4. Add a row to the [Plugins](#plugins) table, and to the `README.md` of the first-level folder.
5. Publish each build as a GitHub release tagged `<ide>-<editor>-v<version>` (for example `intellij-vscode-v0.0.1`), with the installable package attached. In Claude Code, `/release <ide>/<editor>` does this; add the new editor to its host table first (`.claude/skills/release/SKILL.md`).

Conventions for plugins (naming, keymaps, themes, docs, credentials) are in [CLAUDE.md](CLAUDE.md).

## License

No license has been chosen yet, so all rights are reserved. You're welcome to install and use the plugins; ask before redistributing or reusing the code.
