# Changelog

## 0.0.1

First version.

- Muscle Memory key bindings for Xcode: IntelliJ IDEA's macOS keymap for navigation, editing, refactoring, build, run, debug and source control, with the Xcode defaults it displaces moved or cleared so no key does two things.
- Editor keys Xcode lacks a menu command for: Delete Line (Cmd+Backspace) and Join Lines (Ctrl+Shift+J).
- Optional editor commands, built from source: Extend/Shrink Selection (Alt+Up/Down), Next/Previous Method (Ctrl+Shift+Down/Up), Toggle Case (Shift+Cmd+U), Start New Line (Shift+Enter), Start New Line Before Current and Comment with Block Comment (Alt+Cmd+/), under Editor → Muscle Memory.
- Optional Back / Forward history in the same app: Cmd+Option+Left / Right return to every place the caret jumped to, in the same file too (Xcode's own history skips clicks and searches), with a separate history for each project. It runs in the menu bar and needs Accessibility access.
- Muscle Memory Dark and Muscle Memory Light color themes with IntelliJ IDEA's colors, in JetBrains Mono when it is installed and SF Mono otherwise.
- IntelliJ IDEA's `sout`, `soutv`, `fori`, `iter`, `ifn` and `inn` live templates as Swift code snippets.
- `install.sh` selects the key bindings and themes in Xcode; `uninstall.sh` removes them and restores the previous choices.
