# Muscle Memory for Xcode

Keep the habits you built in IntelliJ IDEA when you work in Xcode:

- **Keymap:** IntelliJ IDEA's macOS keymap applied to Xcode's commands: Cmd+B to jump to a definition, Shift+F6 to rename, Cmd+K to commit, F8 to step over, Cmd+Backspace to delete a line, and about 50 more.
- **Themes:** Muscle Memory Dark (IntelliJ IDEA's dark syntax colors on a `#191A1C` background) and Muscle Memory Light (IntelliJ Light's colors on white), in JetBrains Mono when it is installed.
- **Live templates:** `sout`, `soutv`, `fori`, `iter`, `ifn` and `inn` expand in Swift code like they do in IntelliJ IDEA.
- **Editor commands** (optional, [build it yourself](#editor-commands-build-it-yourself)): Extend/Shrink Selection, Next/Previous Method, Toggle Case, Start New Line, Start New Line Before Current and Comment with Block Comment.
- **Back / Forward history** (optional, same app): Cmd+Option+Left / Right return to every place the caret jumped to, in the same file too, as in IntelliJ IDEA.

Xcode doesn't load plugins that change its interface. It lets you add a key binding set, color themes, code snippets and Source Editor Extensions, which edit the text of the open file; this plugin is made of those. The VS Code plugin's inheritance markers, Switcher, Push preview and async coloring can't be built for Xcode, and Go to Super can't either: an extension doesn't know the code's types.

## Install

You need Xcode on macOS. The files were made for and checked against Xcode 26.1.

1. Download `musclememory-xcode-<version>.zip` from the newest `intellij-xcode-v…` release on the [Releases page](https://github.com/PavloZoria/musclememory/releases), or [build it](#development).
2. Quit Xcode, then in Terminal:

   ```sh
   unzip musclememory-xcode-<version>.zip
   musclememory-xcode-<version>/install.sh
   ```

3. Open Xcode. It now uses the **Muscle Memory** key bindings, **Muscle Memory Light** in light mode and **Muscle Memory Dark** in dark mode.

`install.sh` copies the files into `~/Library/Developer/Xcode/UserData` and selects them. If Xcode is running, it only copies them; choose them yourself in **Xcode → Settings → Key Bindings** (the set menu above the list) and **→ Themes**.

| Option | |
|---|---|
| `--font auto` | Default. JetBrains Mono when it is installed in `~/Library/Fonts` or `/Library/Fonts`, SF Mono (which ships with Xcode) otherwise. Install JetBrains Mono with `brew install --cask font-jetbrains-mono` and run `install.sh` again. |
| `--font sf-mono` / `--font jetbrains-mono` | Use that font whatever is installed. |
| `--no-activate` | Copy the files without selecting them. |

**Function keys:** many shortcuts below use F1–F12. macOS uses those keys for brightness, volume and media, so either hold Fn or turn on **System Settings → Keyboard → Keyboard Shortcuts → Function Keys → Use F1, F2, etc. keys as standard function keys**.

### Uninstall

Quit Xcode and run `musclememory-xcode-<version>/uninstall.sh` (or `make uninstall` in this folder). It removes the files and gives Xcode back the key bindings and themes it used before.

## Editor commands (build it yourself)

Some IntelliJ IDEA editing actions have no Xcode command at all. A small Xcode extension adds them under **Editor → Muscle Memory**, and the keymap gives them IntelliJ IDEA's keys:

| IntelliJ IDEA action | Key | What it does in Xcode |
|---|---|---|
| Extend Selection | Alt+Up | Word → string contents → string → bracket contents → brackets → statement → line → block with its header → … → file |
| Shrink Selection | Alt+Down | Steps back through what Extend Selection selected |
| Next Method / Previous Method | Ctrl+Shift+Down / Up | Caret to the name of the next or previous function, initializer, computed property or type (Swift and Objective-C) |
| Toggle Case | Shift+Cmd+U | Upper case, or lower case when it already is; the word at the caret when nothing is selected |
| Comment with Block Comment | Alt+Cmd+/ | Wraps the selection (or the line) in `/* */`, or unwraps it |
| Start New Line | Shift+Enter | Empty line below the caret's line, wherever the caret is; indented one level deeper after `{`, `(` or `[` |
| Start New Line Before Current | (no key; Alt+Cmd+Enter stays Xcode's Canvas) | Empty, indented line above the caret |

The extension only sees the text of the open file, so these commands work from the text, without Xcode's knowledge of types. It doesn't send your code anywhere and doesn't run while you type.

### Back and Forward inside a file

Xcode's own Back / Forward only records some jumps: to another file, Jump to Line, Jump to Definition. A click, a search result or Cmd+Down in the same file just moves its current place, so Back skips where you were. The app that carries the extension fixes this while it runs in the menu bar (the ↩ icon):

- It follows the caret in Xcode's source editor and remembers a new place when the caret jumps to another file or 10 or more lines away. Shorter moves and typing update the current place, so walking through code with the arrow keys doesn't fill the history.
- Each project (workspace or package) has its own history of the last 50 places, so Back in one project window never takes you into another. The histories of the 10 most recently used projects are kept while the app runs.
- Cmd+Option+Left / Right go back and forward through those places, opening the file when it is another one. Elsewhere in Xcode, and while the app isn't running, the keys stay Xcode's own Back / Forward.
- It needs **Accessibility** access to see the caret and to answer the two keys: the app asks on first launch, or use **Allow Accessibility Access…** in its window (menu bar icon → Setup…). It reads only the file path and caret position from Xcode, keeps them in memory, and acts only on Cmd+Option+Left / Right; other keys pass through untouched.
- Turn on **Open at login** in its window or menu to keep the history after a restart. **Back / Forward History** in the menu turns it off.

To try it in Xcode: open a long file, click a line near the top, then a line 10 or more lines further down, then press Cmd+Option+Left. The caret returns to the first click; Xcode's own Back would skip it and go to the place before.

What it takes from Xcode:

- **Which editor has focus:** the text area Xcode labels "Source Editor". Navigators, the console, the find bar and Interface Builder are left alone, so the keys keep Xcode's meaning there.
- **The file:** the window's document, the file named in its title bar.
- **The project:** the workspace or package folder of that window. A file opened on its own, outside a project, shares one history with other such files.
- **Xcode's menus:** **Navigate → Go Back / Go Forward** still show Cmd+Option+Left / Right; the app answers the keys before Xcode sees them.

If Back acts like Xcode's own (skipping places in the same file):

- Check that the ↩ icon is in the menu bar; if not, open `~/Applications/Muscle Memory.app`.
- In **System Settings → Privacy & Security → Accessibility**, check that Muscle Memory is on. A rebuild signed with a different certificate counts as a new app; switch it off and on, or remove it with − and allow it again.
- A Back / Forward history only builds up while the app runs; places from before it started aren't there.

**There is no download for the extension.** macOS only runs a downloaded app with an extension when it is signed with a paid Developer ID and notarized by Apple, and Xcode only loads extensions signed with an Apple-issued certificate. Building it on your own Mac with your own (free) Apple Development certificate meets both.

### What you need

- Xcode 15 or later on macOS 14 or later.
- An Apple Development certificate in your keychain. A free Apple ID is enough: in Xcode, **Settings → Accounts → +** → add your Apple ID, select it, **Manage Certificates… → + → Apple Development**. Check with `security find-identity -v -p codesigning`; a line with "Apple Development" means you're set.
- This repository: `git clone https://github.com/PavloZoria/musclememory.git`

### Build and turn it on

```sh
cd musclememory/intellij/xcode
make install-extension
```

This builds `Muscle Memory.app`, signs it with your Apple Development certificate, copies it to `~/Applications`, registers its extension with macOS, turns it on and starts the app. If you have several certificates, choose one with `make install-extension SIGN_IDENTITY="Apple Development: …"` (the name as `security find-identity` shows it). Then:

1. Quit and reopen Xcode.
2. Open a source file. **Editor → Muscle Memory** lists the commands.
3. Install the keymap too (see [Install](#install)) for the keys above; without it, bind the commands yourself in Xcode → Settings → Key Bindings (search for "Muscle Memory").
4. For [Back and Forward inside a file](#back-and-forward-inside-a-file), allow Muscle Memory in **System Settings → Privacy & Security → Accessibility** when it asks.

If **Editor → Muscle Memory** doesn't appear:

- Check that the extension is on: **System Settings → General → Login Items & Extensions → Extensions → Xcode Source Editor → Muscle Memory**. Opening `~/Applications/Muscle Memory.app` shows these steps and a button that opens that page.
- Ask Xcode why: `/usr/bin/log show --last 10m --predicate 'process == "Xcode" AND eventMessage CONTAINS "Xcode Extension"'`. "does not meet code signing requirement" means the app wasn't signed with an Apple Development certificate; rerun `make install-extension`.
- Make sure no other copy of `Muscle Memory.app` (for example one built from Xcode into DerivedData) is registered: `pluginkit -m -v -i dev.musclememory.editing.extension` should list only `~/Applications/Muscle Memory.app`. Delete other copies and rerun `make install-extension`.

**Building in Xcode instead of `make`:** open `Extension/MuscleMemoryEditor.xcodeproj`. For both targets, under **Signing & Capabilities**, set **Team** to your team and **Signing Certificate** to Development. Build the MuscleMemoryEditor scheme (**Product → Build**), then **Product → Show Build Folder in Finder**, move `Products/Debug/Muscle Memory.app` to `~/Applications`, open it once, delete the build folder copy, and turn the extension on in System Settings as above.

Your certificate and team are only used on your Mac; nothing about them is written into the repository.

### Update and remove

- **Update:** `git pull`, then `make install-extension` and restart Xcode.
- **Remove:** `make uninstall-extension` quits the app, removes its login item and Accessibility entry, turns the extension off, unregisters it and deletes `~/Applications/Muscle Memory.app`. Restart Xcode.

## Shortcuts

The third column is the key Xcode uses for the same command without this keymap.

### Navigation

| IntelliJ IDEA action | Key | Xcode's own key |
|---|---|---|
| Go to Declaration (Jump to Definition) | Cmd+B | Ctrl+Cmd+J |
| Back / Forward (previous caret place, in the same file with [the app](#back-and-forward-inside-a-file)) | Cmd+Option+Left / Right | Ctrl+Cmd+Left / Right |
| Switcher: previous / next class | Ctrl+Tab / Ctrl+Shift+Tab (previous / next editor tab) | Shift+Cmd+[ / ] |
| Recent Files / Recent Locations (menu of where you were; Option+Cmd+E lists files only) | Cmd+E | Ctrl+2 / Ctrl+Option+2 |
| File Structure (the jump bar's list of the file's symbols; type to filter) | Cmd+F12 | Ctrl+6 |
| Select in Project View (Reveal in Project Navigator) | Alt+F1 | Shift+Cmd+J |
| Quick Documentation (Quick Help) | F1 | Ctrl+Shift+Cmd+/ |
| Find Usages (Find Selected Symbol in Workspace) | Alt+F7 | Ctrl+Shift+Cmd+F |
| Call Hierarchy | Ctrl+Alt+H | Ctrl+Shift+Cmd+H |
| Next / Previous Highlighted Error (issue) | F2 / Shift+F2 | Cmd+' / Shift+Cmd+' |
| Next / Previous Change | Ctrl+Alt+Shift+Down / Up | Ctrl+\ / Ctrl+Shift+\ |
| Next / Previous Occurrence in Find results | Alt+Cmd+Down / Up | Ctrl+Cmd+G / Ctrl+Shift+Cmd+G |
| Toggle Bookmark (Bookmark Line) / with Mnemonic (with dialog) | F3 / Alt+F3 | Ctrl+Cmd+' / Ctrl+Alt+Cmd+' |

Holding Option (and Shift) with Cmd+B opens the definition in another editor, as Xcode does with its own keys.

### Editing and refactoring

| IntelliJ IDEA action | Key | Xcode's own key |
|---|---|---|
| Delete Line | Cmd+Backspace | (none) |
| Join Lines | Ctrl+Shift+J | Ctrl+J, which still works |
| Move Line Up / Down | Alt+Shift+Up / Down | Alt+Cmd+[ / ] |
| Show Intention Actions (shows the issue on the line, with its Fix button) | Alt+Enter | Ctrl+Alt+Cmd+L |
| Rename | Shift+F6 | (none) |
| Extract Method / Introduce Variable | Alt+Cmd+M / Alt+Cmd+V | (none) |
| Reformat Code (Format File, uses swift-format) | Alt+Cmd+L | Ctrl+Shift+I |
| Auto-Indent Lines (Re-Indent) | Ctrl+Alt+I | Ctrl+I, which still works |
| Add Selection for Next Occurrence | Ctrl+G | Alt+Cmd+E |
| Select All Occurrences (Edit All in Scope) | Ctrl+Cmd+G | Ctrl+Cmd+E |
| Replace / Replace in Files | Cmd+R / Shift+Cmd+R | Alt+Cmd+F / Alt+Shift+Cmd+F |
| Collapse / Expand | Cmd+- / Cmd+= | Alt+Cmd+Left / Right |
| Collapse All (methods and functions) / Expand All | Shift+Cmd+- / Shift+Cmd+= | Alt+Shift+Cmd+Left / (none) |

### Build, run and debug

| IntelliJ IDEA action | Key | Xcode's own key |
|---|---|---|
| Build Project | Cmd+F9 | Cmd+B |
| Run (with the debugger, as Xcode always runs) | Ctrl+R | Cmd+R |
| Run… (edit the scheme, then run) | Ctrl+Alt+R | Alt+Cmd+R |
| Stop | Cmd+F2 | Cmd+. |
| Step Over / Step Out | F8 / Shift+F8 | F6 / F8 |
| Resume Program (Pause / Continue) | F9 | Ctrl+Cmd+Y |
| Run to Cursor (Continue to Current Line) | Alt+F9 | Ctrl+Cmd+C |
| Toggle Line Breakpoint | Cmd+F8 | Cmd+\ |
| View Breakpoints (Breakpoint navigator) | Shift+Cmd+F8 | Cmd+8 |

### Version control

| IntelliJ IDEA action | Key | Xcode's own key |
|---|---|---|
| Commit | Cmd+K | Alt+Cmd+C |
| Push | Shift+Cmd+K | (none) |
| Update Project (Pull) | Cmd+T | Alt+Cmd+X |

### Tool windows (navigators)

| IntelliJ IDEA tool window | Xcode | Key | Xcode's own key |
|---|---|---|---|
| Project | Project navigator | Cmd+1 | Cmd+1 |
| Bookmarks | Bookmarks navigator | Cmd+2 | Cmd+3 |
| Find | Find navigator | Cmd+3 | Cmd+4 |
| Run | Console (debug area) | Cmd+4 | Shift+Cmd+C |
| Debug | Debug navigator | Cmd+5 | Cmd+7 |
| Problems | Issue navigator | Cmd+6 | Cmd+5 |
| (none) | Test navigator | Cmd+7 | Cmd+6 |
| (none) | Report navigator | Cmd+8 | Cmd+9 |
| Version Control | Source Control navigator | Cmd+9 | Cmd+2 |

### Already the same in both

Cmd+Shift+O (Go to File; Xcode's Open Quickly also finds types and symbols), Cmd+Shift+A (Find Action; Xcode's Quick Actions), Cmd+L (Go to Line), Cmd+/ (Comment), Cmd+D (Duplicate), Cmd+F / Cmd+Shift+F / Cmd+G (Find, Find in Files, Find Next), Ctrl+Space (Completion), F7 (Step Into), Cmd+W (Close Tab).

## Differences from IntelliJ IDEA

- **One key per command.** Xcode can't give a command two keys, so IntelliJ IDEA's second keys are missing: Cmd+[ / Cmd+] for Back / Forward (they stay Xcode's Shift Left / Right), Cmd+Shift+[ / ] for the previous / next tab (now Ctrl+Tab / Ctrl+Shift+Tab), Cmd+Y and Alt+Space for Quick Definition, Ctrl+J for Quick Documentation, Alt+Cmd+F7 for Show Usages, Cmd+Shift+Up / Down for Move Statement.
- **Xcode has no equivalent** for these, so they keep Xcode's meaning or do nothing: Shift Shift (use Cmd+Shift+O or Cmd+Shift+A), Cmd+O Go to Class (still Xcode's Open… dialog; use Cmd+Shift+O), Alt+Cmd+B Implementations (Option+Cmd+B opens the definition in another editor), Cmd+U Super Method (still Xcode's Test), Ctrl+H Type Hierarchy, Cmd+P Parameter Info (still Print), Cmd+N Generate (still New File), Alt+Cmd+N Inline, Ctrl+Alt+O Optimize Imports, Cmd+Shift+Backspace Last Edit Location, Cmd+Shift+E Recent Locations, Alt+Cmd+T Surround With, Cmd+J Insert Live Template (snippets show up in completion instead), Ctrl+M Matching Brace, Alt+F8 Evaluate Expression, Alt+F12 Terminal, Alt+Cmd+Z Rollback, Cmd+Shift+F12 Hide All Tool Windows, Ctrl+D Debug (Ctrl+R already runs with the debugger).
- **Extend Selection, Next/Previous Method, Toggle Case and Block Comment** come from the [editor commands](#editor-commands-build-it-yourself); without them, those keys do nothing.
- **Back / Forward** without [the app](#back-and-forward-inside-a-file) use Xcode's history, which skips places reached by a click or a search in the same file. With the app, a place is a jump of 10 or more lines; IntelliJ IDEA's rule differs in detail. The app keeps one history per project rather than one per tab, forgets it when it quits, and doesn't follow edits that move lines, so a place can end up a few lines off after you add or delete lines above it. In a split editor, the history follows only the pane whose file the window title shows.
- **Start New Line Before Current** (Alt+Cmd+Enter) stays Xcode's Canvas (SwiftUI preview) toggle; the editor command has no key.
- **Ctrl+Tab** has no Switcher popup: Xcode can't show one. Ctrl+Tab / Ctrl+Shift+Tab step to the previous / next editor tab. When you open classes in the same tab (as Open Quickly does), Cmd+Option+Left goes back to the previous class instead, and Cmd+E lists where you were. Xcode keeps a separate Back/Forward history in each tab.
- **Alt+Enter** shows the issue on the current line with its Fix buttons. It doesn't list refactorings; use Editor → Refactor, Shift+F6, Alt+Cmd+M and Alt+Cmd+V, or Cmd+Shift+A.
- **Alt+F7** lists usages in the Find navigator (Cmd+3); there is no usages popup.
- **Recent Files (Cmd+E) and File Structure (Cmd+F12)** open Xcode's menus, not searchable popups: pick with the arrow keys and Return. File Structure's menu filters as you type.
- **Expand All / Collapse All** unfold everything and fold methods and functions; Xcode has no "fold everything" command.
- **Xcode keys that move or go away** because IntelliJ IDEA's keymap uses them:

  | Xcode command | Before | Now |
  |---|---|---|
  | Build | Cmd+B | Cmd+F9 |
  | Run | Cmd+R | Ctrl+R |
  | Editor → Font Size → Increase / Decrease | Cmd++ / Cmd+- | Ctrl+Cmd+= / Ctrl+Cmd+- |
  | Clean Build Folder / Immediately | Shift+Cmd+K / Alt+Shift+Cmd+K | Ctrl+Shift+Cmd+K / Ctrl+Alt+Shift+Cmd+K |
  | Clear Console | Cmd+K | Ctrl+Cmd+K |
  | Edit → Delete (delete files in a navigator) | Cmd+Backspace | none; press Backspace in the navigator |
  | Use Selection for Find | Cmd+E | none; Cmd+F with a selection does the same |
  | File → New → Tab | Cmd+T | none |
  | Jump to Selection, Reformat to Width, Analyze… (Option variant), Build For → Running, Reload Organizer, Minimize All, Move Item Here | Alt+Cmd+L, Ctrl+Alt+I, Alt+Shift+Cmd+B, Shift+Cmd+R, Ctrl+R, Alt+Cmd+M, Alt+Cmd+V | none |
  | Editor → Selection → Select Column Up / Down | Ctrl+Shift+Up / Down | none (Previous / Next Method); Option-drag still selects columns |
  | Product → Build For → Testing | Shift+Cmd+U | none (Toggle Case) |
  | Editor → Structure → Add Documentation | Alt+Cmd+/ | none (Comment with Block Comment) |
  | Window → Show Previous / Next Window Tab | Ctrl+Shift+Tab / Ctrl+Tab | none (the menu still works) |
  | PDF viewer: Next Page / Previous Page | Alt+Cmd+Down / Up | none (scroll, or use the menu) |

  Every command keeps its place in the menus. To give one a key again, find it in Xcode → Settings → Key Bindings; Xcode saves the change into the Muscle Memory set.
- **Reinstalling replaces the set.** Changes you make in Settings → Key Bindings are saved into `Muscle Memory.idekeybindings`, which `install.sh` overwrites. Duplicate the set in Settings first (the menu above the list) if you want to keep your own version.
- **macOS only.** Xcode only runs on macOS, so this is IntelliJ IDEA's macOS keymap ("macOS" in its Keymap settings).

## Colors

Xcode colors code by role (keyword, string, declaration, …), not by language, so the themes map IntelliJ IDEA's colors onto those roles:

| Role | Muscle Memory Dark | Muscle Memory Light |
|---|---|---|
| Plain text, types, calls, local variables | `#A9B7C6` | `#080808` |
| Keywords | `#CC7832` orange | `#0033B3` navy |
| Strings and characters | `#6E8C5C` green | `#067D17` green |
| Numbers | `#6897BB` blue | `#1750EB` blue |
| Function and property declarations | `#FFC66D` yellow | `#00627A` dark cyan |
| Properties and globals in use | `#9876AA` purple | `#871094` purple |
| Constants and enum cases in use | `#9876AA` purple italic | `#871094` purple italic |
| Attributes (`@MainActor`) and `#if` | `#BBB529` olive | `#9E880D` olive |
| Comments | `#808080` gray | `#8C8C8C` gray |
| Documentation comments | `#629755` green italic | `#8C8C8C` gray italic |
| `// MARK:`, `// TODO:`, `// FIXME:` | `#A8C023` italic | `#008DDE` italic |
| Links | `#589DF6` | `#2A5DB0` |

- Xcode has a single role for declared names, so property declarations are yellow like function declarations; IntelliJ IDEA colors only functions that way.
- Xcode doesn't tell themes about parameters or reassigned variables, so the VS Code plugin's rose parameters and underlined reassigned variables aren't available.
- Strings in the dark theme are a shade lighter than IntelliJ IDEA's `#6A8759`, and links use IntelliJ IDEA's dark hyperlink color, so both reach a 4.5:1 contrast on the background.
- The editor font is JetBrains Mono 13 (or SF Mono 13) with IntelliJ IDEA's 1.2 line spacing. The console uses the same font and background.

## Live templates

Type the abbreviation in Swift code and pick it from the completion list (Return accepts it). Tab moves between the placeholders.

| Abbreviation | Expands to |
|---|---|
| `sout` | `print(value)` |
| `soutv` | `print("name = \(value)")` |
| `fori` | `for i in 0..<count { … }` |
| `iter` | `for item in items { … }` |
| `ifn` | `if value == nil { … }` |
| `inn` | `if value != nil { … }` |

They appear in Xcode's Library (Shift+Cmd+L → Snippets) as "Muscle Memory: …".

## Performance

The key bindings, themes and snippets don't run anything: Xcode reads them when it starts, like the ones it ships with. The editor commands run only when you invoke one.

The Back / Forward app uses about 16 MB of memory and no CPU while you aren't working in Xcode. When the caret moves, it asks Xcode where it is at most ten times a second, however fast you type. Each lookup is a few Accessibility calls with a 0.5 s timeout; the editor's file and project are looked up once and remembered until you switch files. It never reads the file's text. It sees every key press in order to catch Cmd+Option+Left / Right, and checks only the key and modifiers before passing the others on.

## Development

The files are generated from Swift sources and checked against the installed Xcode. You need Xcode (or its command line tools) and `make`:

```sh
make test       # unit tests, including a check against the Xcode selected with xcode-select
make check      # report keymap commands this Xcode doesn't have, and keys used twice
make menus      # regenerate XcodeMenus.swift after changing Keymap.swift or switching Xcode versions
make install    # generate into build/ and run install.sh (make install ARGS="--no-activate")
make package    # lint, test, check, then dist/musclememory-xcode-<version>.zip
make uninstall
```

The version is in `VERSION`. Sources: `Keymap.swift` lists the bindings and `XcodeCommand.swift` the Xcode commands they use; `Palette.swift` and `ColorTheme.swift` define the themes, `Snippets.swift` the live templates.

The editor commands' logic and the Back / Forward history rules (`NavigationHistory.swift`) are in `Sources/MuscleMemoryEditing` (plain Swift, covered by `make test`). `Extension/` holds the app and the extension that call it from Xcode; `Extension/App/NavigationRecorder.swift` follows Xcode's caret and handles the two keys. The app isn't sandboxed, because sandboxed apps can't use the Accessibility API; the extension is, as Xcode requires. `project.yml` is the [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec, and the generated `MuscleMemoryEditor.xcodeproj` is committed so building needs only Xcode. After changing `project.yml`, run `make extension-project` (needs `brew install xcodegen`). A command's identifier and title live in `EditingCommand` and in `project.yml`; a test keeps them in step.

```sh
make extension             # build and sign build/extension/…/Muscle Memory.app (SIGN_IDENTITY=… to choose a certificate)
make install-extension     # build, copy to ~/Applications, register and turn on
make uninstall-extension
```

How Xcode applies a key binding set, which the generator follows:

- A command gets one key, but Xcode keeps a binding entry for every menu the command appears in: the main menu bar, and the Editor or Navigate menu of each kind of editor that offers it (source code, playgrounds, comparisons, the console). A menu left out keeps its old key, and Xcode may show that one instead.
- Items grouped with a command (the GPU debugger's Step to Next Draw Call with Step Over) need the same key.
- A key used by two commands whose menus are on screen together (any menu with the main menu bar, which is always there) is dropped for both. Editors that are never on screen together may share a key.

`XcodeMenus.swift` is generated by `make menus` from Xcode's own command and menu definitions (`XcodeCatalog.swift` reads them) and lists every menu item each binding must cover. `make check` fails when that table is out of date, when a command is missing, or when a key clashes under the rule above.

To support another Xcode version, select it (`xcode-select -s`), run `make menus` and `make check`, and adjust `Keymap.swift` where it reports clashes.
