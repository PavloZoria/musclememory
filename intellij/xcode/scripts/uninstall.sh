#!/bin/bash
# Removes what install.sh added and gives Xcode back the key bindings and themes it used before.
set -euo pipefail

userdata="$HOME/Library/Developer/Xcode/UserData"
state="$HOME/Library/Application Support/MuscleMemory/xcode"
domain="com.apple.dt.Xcode"

if pgrep -xq Xcode; then
    echo "Quit Xcode first: it rewrites its settings when it quits." >&2
    exit 1
fi

if [[ ! -d "$state" ]]; then
    echo "Muscle Memory isn't installed (nothing in $state)."
    exit 0
fi

# Put back the previous choice for each setting that still points at a Muscle Memory file.
for key in IDEKeyBindingCurrentPreferenceSet XCFontAndColorCurrentTheme XCFontAndColorCurrentDarkTheme; do
    current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
    [[ "$current" == "Muscle Memory "* || "$current" == "Muscle Memory.idekeybindings" ]] || continue
    previous=""
    if [[ -f "$state/previous.txt" ]]; then
        previous="$(sed -n "s/^$key=//p" "$state/previous.txt")"
    fi
    if [[ -n "$previous" && "$previous" != "Muscle Memory"* ]]; then
        defaults write "$domain" "$key" -string "$previous"
    else
        defaults delete "$domain" "$key" 2>/dev/null || true
    fi
done

removed=0
if [[ -f "$state/installed.txt" ]]; then
    while IFS= read -r file; do
        # Only ever delete inside Xcode's UserData folder.
        [[ "$file" == "$userdata/"* && -f "$file" ]] || continue
        rm -f "$file"
        removed=$((removed + 1))
    done < "$state/installed.txt"
fi
rm -rf "$state"
rmdir "$HOME/Library/Application Support/MuscleMemory" 2>/dev/null || true

echo "Removed $removed Muscle Memory files and restored Xcode's previous key bindings and themes."
