# Muscle Memory for VS Code

Keep the habits you built in IntelliJ IDEA when you work in VS Code, on macOS, Windows and Linux:

- **Themes:** Muscle Memory Dark (syntax colors on a `#191A1C` background with a matching dark UI) and Muscle Memory Light (IntelliJ Light's syntax colors on a white editor with a light gray frame).
- **Keymap:** IntelliJ IDEA's keymap for each system, focused on code navigation: the `Mac OS X 10.5+` layout on macOS, the default Windows/Linux layout elsewhere.
- **Select Opened File:** a crosshair button in the Explorer title bar, also on Alt+F1.

## Install

1. Download `musclememory-<version>.vsix` from the newest `intellij-vscode-v…` release on the [Releases page](https://github.com/PavloZoria/musclememory/releases), or [build it](#development) into `dist/`.
2. Command Palette (Cmd+Shift+P / Ctrl+Shift+P) → **Extensions: Install from VSIX…** → pick the file.
3. Command Palette → **Preferences: Color Theme** → **Muscle Memory Dark** or **Muscle Memory Light**.

The keymap is active as soon as the extension is installed. VS Code picks the macOS or the Windows/Linux keys by itself. To turn a single shortcut off, open Keyboard Shortcuts (Find Action → "Keyboard Shortcuts"), find it, and remove it.

## Navigation

| Action | macOS | Windows / Linux |
|---|---|---|
| Declaration / usages | Cmd+B, Cmd+Click | Ctrl+B, Ctrl+Click |
| Implementation(s) | Cmd+Alt+B | Ctrl+Alt+B |
| Type declaration | Ctrl+Shift+B | Ctrl+Shift+B |
| Super method / super type | Cmd+U | Ctrl+U |
| Type hierarchy | Ctrl+H | Ctrl+H |
| Call hierarchy | Ctrl+Alt+H | Ctrl+Alt+H |
| Method hierarchy (implementations view) | Cmd+Shift+H | Ctrl+Shift+H |
| Find usages (panel) / Show usages (popup) | Alt+F7 / Cmd+Alt+F7 | Alt+F7 / Ctrl+Alt+F7 |
| Highlight usages in file | Cmd+Shift+F7 | Ctrl+Shift+F7 |
| Back / Forward | Cmd+[ / Cmd+] , Cmd+Alt+Left / Right | Ctrl+Alt+Left / Right |
| Last edit location | Cmd+Shift+Backspace | Ctrl+Shift+Backspace |
| Next / previous method | Ctrl+Shift+Down / Up | Alt+Down / Up |
| Next / previous error | F2 / Shift+F2 | F2 / Shift+F2 |
| Next / previous VCS change | Ctrl+Alt+Shift+Down / Up | Ctrl+Alt+Shift+Down / Up |
| Switcher (open files only, all splits) | Ctrl+Tab / Ctrl+Shift+Tab | Ctrl+Tab / Ctrl+Shift+Tab |
| Search everywhere | Shift Shift | Shift Shift |
| Go to file / class / symbol | Cmd+Shift+O / Cmd+O / Cmd+Alt+O | Ctrl+Shift+N / Ctrl+N / Ctrl+Alt+Shift+N |
| Recent files | Cmd+E | Ctrl+E |
| Find action | Cmd+Shift+A | Ctrl+Shift+A |
| File structure / Structure view | Cmd+F12 / Cmd+7 | Ctrl+F12 / Alt+7 |
| Go to line | Cmd+L | Ctrl+G |
| Navigation bar (breadcrumbs) | Cmd+Up | Alt+Home |
| Select opened file | Alt+F1 | Alt+F1 |
| Quick definition / Quick documentation | Alt+Space, Cmd+Y / F1, Ctrl+J | Ctrl+Shift+I / Ctrl+Q |
| Parameter info | Cmd+P | Ctrl+P |

## Editing, refactoring, run and VCS

| Action | macOS | Windows / Linux |
|---|---|---|
| Show intention actions | Alt+Enter | Alt+Enter |
| Refactor this / Rename | Ctrl+T / Shift+F6 | Ctrl+Alt+Shift+T / Shift+F6 |
| Generate | Cmd+N | Alt+Insert |
| Extract (method, variable, constant, field) / Inline / Move | Cmd+Alt+M, V, C, F / Cmd+Alt+N / F6 | Ctrl+Alt+M, V, C, F / Ctrl+Alt+N / F6 |
| Surround with / Insert live template | Cmd+Alt+T / Cmd+J | Ctrl+Alt+T / Ctrl+J |
| Reformat / Optimize imports | Cmd+Alt+L / Ctrl+Alt+O | Ctrl+Alt+L / Ctrl+Alt+O |
| Duplicate line / Delete line | Cmd+D / Cmd+Backspace | Ctrl+D / Ctrl+Y |
| Block comment | Cmd+Alt+/ | Ctrl+Shift+/ |
| Extend / shrink selection | Alt+Up / Alt+Down | Ctrl+W / Ctrl+Shift+W |
| Move statement / line | Cmd+Shift+Up/Down / Alt+Shift+Up/Down | Ctrl+Shift+Up/Down / Alt+Shift+Up/Down |
| Add next occurrence / all / undo last | Ctrl+G / Ctrl+Cmd+G / Ctrl+Shift+G | Alt+J / Ctrl+Alt+Shift+J / Alt+Shift+J |
| Column selection | Cmd+Shift+8 | Alt+Shift+Insert |
| Fold / unfold (all) | Cmd+- / Cmd+= (with Shift for all) | Ctrl+- / Ctrl+= (with Shift for all) |
| Start new line / above | Shift+Enter / Cmd+Alt+Enter | Shift+Enter / Ctrl+Alt+Enter |
| Join lines / Jump to matching brace | Ctrl+Shift+J / Ctrl+M | Ctrl+Shift+J / Ctrl+Shift+M |
| Replace / Replace in files | Cmd+R / Cmd+Shift+R | Ctrl+R / Ctrl+Shift+R |
| Next / previous search result | Cmd+Alt+Down / Up | Ctrl+Alt+Down / Up |
| Copy file path | Cmd+Shift+C | Ctrl+Shift+C |
| Build | Cmd+F9 | Ctrl+F9 |
| Run / Debug / choose configuration | Ctrl+R / Ctrl+D / Ctrl+Alt+R | Shift+F10 / Shift+F9 / Alt+Shift+F10 |
| Step over / into / out, Resume, Stop | F8 / F7 / Shift+F8, F9 or Cmd+Alt+R, Cmd+F2 | F8 / F7 / Shift+F8, F9, Ctrl+F2 |
| Toggle breakpoint / View breakpoints | Cmd+F8 / Cmd+Shift+F8 | Ctrl+F8 / Ctrl+Shift+F8 |
| Evaluate (selection) / Run to cursor | Alt+F8 / Alt+F9 | Alt+F8 / Alt+F9 |
| Commit / Push / Update (pull) | Cmd+K / Cmd+Shift+K / Cmd+T | Ctrl+K / Ctrl+Shift+K / Ctrl+T |
| Rollback changed lines | Cmd+Alt+Z | Ctrl+Alt+Z |
| Project / Find / Run / Debug / Problems / Git | Cmd+1 / 3 / 4 / 5 / 6 / 9, 0 | Alt+1 / 3 / 4 / 5 / 6 / 9, 0 |
| Terminal | Alt+F12 | Alt+F12 |
| Hide all tool windows / Hide active one | Cmd+Shift+F12 / Shift+Esc | Ctrl+Shift+F12 / Shift+Esc |
| Next / previous editor split | Alt+Tab / Alt+Shift+Tab | (left to the system's window switcher) |

## Differences from IntelliJ IDEA

- **Cmd+K (Ctrl+K) opens Commit**, so VS Code's two-step Cmd+K / Ctrl+K shortcuts (e.g. Cmd+K Cmd+T) stop working. Use Find Action (Cmd+Shift+A / Ctrl+Shift+A) for those commands.
- **Cmd+P (Ctrl+P) is Parameter Info**, as in IntelliJ IDEA. Quick open is Shift Shift, Cmd+Shift+O / Ctrl+Shift+N or Cmd+E / Ctrl+E.
- **Cmd+U** relies on the language server's type hierarchy (C#, Java and TypeScript support it). It matches overridden members by name, so with overloads it may offer more than one target.
- **Switcher** lists open files only, without Settings, Output or panels. Hold Ctrl and press Tab / Shift+Tab to move, release Ctrl to open, or type to filter.
- **Push (Cmd+Shift+K / Ctrl+Shift+K)** shows the outgoing commits and pushes only after you confirm, like IntelliJ IDEA's Push dialog. A branch that isn't on the remote yet is offered for publishing instead.
- **Update Project (Cmd+T / Ctrl+T)** pulls right away; there is no Update dialog to pick merge or rebase. Git's own `pull.rebase` setting decides that.
- **Not mapped (no VS Code equivalent):** Recent Locations (Cmd+Shift+E / Ctrl+Shift+E), Complete Current Statement (Cmd+Shift+Enter / Ctrl+Shift+Enter), Bookmarks (F3 / F11).
- **On Windows and Linux** the IntelliJ keys replace these VS Code defaults: Ctrl+W (close editor, use Ctrl+F4), Ctrl+Y (redo, use Ctrl+Shift+Z), Ctrl+N (new file, use Alt+Insert in the Explorer), Ctrl+P (quick open, use Shift Shift or Ctrl+E), Ctrl+J (panel), Ctrl+R (open recent), Ctrl+D (add selection, use Alt+J). Ctrl+Shift+P stays VS Code's Command Palette: Expression Type, which IntelliJ puts there, is mapped on macOS only.
- **macOS-only aliases**: Cmd+[ / Cmd+], Cmd+Y, Ctrl+J, Cmd+Shift+B, Cmd+Shift+/ and Cmd+Alt+R have no Windows/Linux counterpart in IntelliJ IDEA's keymap, so they exist on macOS only.
- **Linux desktops reserve some of these keys** before VS Code sees them. GNOME, for example, uses Ctrl+Alt+Left/Right/Up/Down (workspaces), Ctrl+Alt+T (terminal), Ctrl+Alt+L (lock screen), Alt+F1, Alt+F7 and Alt+F8. IntelliJ IDEA has the same conflicts there; free the key in the desktop's keyboard settings if you want it in VS Code.
- **Select Opened File** is also automatic: VS Code's `explorer.autoReveal` is on by default, which matches IntelliJ IDEA's "Always Select Opened File".

## Language colors

The colors below are described for Muscle Memory Dark. Muscle Memory Light keeps every role with IntelliJ Light's palette: navy keywords, green strings, dark cyan method declarations, purple fields, olive annotations, teal-green C# types, a stronger blue for async code and rose-brown C# parameters.


- **Kotlin** (needs the "Kotlin by JetBrains" extension) matches IntelliJ IDEA: yellow function declarations, plain calls, italic extension and top-level calls, purple properties, olive annotations, teal type parameters. Named arguments, `it` in bold and smart-cast backgrounds aren't available, because the language server doesn't report them.
- **C#** follows the Kotlin colors, with additions so method bodies aren't all one color:
  - Types (`Result`, `CancellationToken`) are teal; interfaces (`IOrderRepository`) are italic teal.
  - Async code is blue: `Task`, `Task<T>`, `ValueTask`, `IAsyncEnumerable`, and every call the C# server reports as returning an awaitable (it marks them `(awaitable)` in its hover), whatever the method is named.
  - Parameters are rose, so they stand apart from local variables.
  - Variables and parameters that get reassigned are underlined, like Android Studio's underline on Kotlin `var`.
  - `[Obsolete]` members are struck through.

  The C# server tags method declarations and calls the same way and doesn't put return types in its colors, so the extension adds the yellow declarations, olive attribute names (like `[HttpGet]`) and blue async calls itself. They appear a moment after a file opens. Async calls are looked up for the code on screen, so newly scrolled-to calls may take a moment to turn blue.
- **Python** uses PyCharm-like colors: `self` purple, builtins lavender, keyword arguments orange, dunder names magenta, docstrings green italic.

## Inheritance markers

C#, Kotlin and Java files get inheritance gutter arrows next to classes, interfaces and their members:

| Icon | Meaning |
|---|---|
| Green ↑ | Implements an interface (or an interface member) |
| Blue ↑ | Extends a class, or overrides a base member |
| Green ↓ | Interface or interface member that has implementations |
| Blue ↓ | Class with subclasses, or virtual/abstract member that is overridden |
| ↑↓ | Both at once |

VS Code doesn't pass left clicks on an extension's gutter icons to the extension, so the arrows come with three ways to jump:

- **Click the line above the declaration** (CodeLens, like IntelliJ IDEA's Code Vision): `↑ implements IOrderRepository`, `↓ 2 implementations`. One target opens directly; several open a peek list.
- **Right-click the arrow** (or its line number): **Go to Super Type/Method** or **Show Implementations/Inheritors**.
- **Hover the class or member name** for the same targets as links.

Cmd+U (super) and Cmd+Alt+B (implementations) work from the keyboard as before.

Markers appear a moment after a file opens. Answers about what implements what are shared by all of the above, cached, and rechecked after saves at most every 15 seconds. If something looks out of date, run **Muscle Memory: Refresh Inheritance Markers**. Kotlin and Java depend on their language server answering type-hierarchy requests.

## Settings

| Setting | Default | |
|---|---|---|
| `musclememory.inheritanceMarkers` | `true` | Gutter arrows for inheritance, with the right-click menu. |
| `musclememory.inheritanceCodeLens` | `true` | Clickable `↑ implements …` / `↓ N implementations` above declarations. |
| `musclememory.csharp.awaitableCalls` | `true` | Blue calls that return an awaitable. Turn off to skip the hover lookups this needs. |

## Performance

The C# coloring and the inheritance markers ask the language server questions VS Code's own APIs can answer (outline, hover, type hierarchy, implementations). To keep that from competing with completions and diagnostics:

- At most 4 of these requests run at once; the rest wait.
- Async calls and member implementations are only looked up for code on screen (plus 40 lines), more as you scroll.
- Answers are cached. A save only drops the answers its edits could have changed, so auto-save stays cheap.
- Work for an outdated version of a file is cancelled as soon as you type on.

Timings and errors are logged under **Output → Muscle Memory** (set the log level to Debug for timings).

## Development

The extension is written in TypeScript. With Node.js installed:

```sh
npm install          # tooling only; the extension has no runtime dependencies
npm run watch        # compile on change
npm test             # unit tests (Node's test runner)
npm run lint         # ESLint with type checking
npm run package      # lint, test, then build dist/musclememory-<version>.vsix
code --install-extension dist/musclememory-<version>.vsix
```

Source layout: `src/extension.ts` wires the features in `src/features/`; logic without VS Code dependencies (C# code scanning, async-answer cache, marker model, request limiter) lives in `src/csharp/`, `src/inheritance/` and `src/util/`, and is covered by `src/test/`.

## Optional settings for a closer match

IntelliJ IDEA's editor font is JetBrains Mono 12. It ships inside IntelliJ IDEA, but VS Code needs it installed on the system first: `brew install --cask font-jetbrains-mono` on macOS, or download it from jetbrains.com/lp/mono on Windows and Linux.

```json
"editor.fontFamily": "JetBrains Mono, Menlo, monospace",
"editor.fontSize": 12,
"editor.minimap.enabled": false,
"editor.bracketPairColorization.enabled": false
```
