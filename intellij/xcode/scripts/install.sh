#!/bin/bash
# Installs Muscle Memory's key bindings, color themes and code snippets into Xcode,
# and selects them unless --no-activate is given.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
userdata="$HOME/Library/Developer/Xcode/UserData"
state="$HOME/Library/Application Support/MuscleMemory/xcode"
domain="com.apple.dt.Xcode"
keybindings="Muscle Memory.idekeybindings"
light_theme="Muscle Memory Light.xccolortheme"
dark_theme="Muscle Memory Dark.xccolortheme"

font="auto"
activate=1

usage() {
    cat <<EOF
Usage: ./install.sh [--font auto|sf-mono|jetbrains-mono] [--no-activate]

  --font         Editor font for the themes. "auto" (default) uses JetBrains Mono when it is
                 installed and SF Mono, which ships with Xcode, otherwise.
  --no-activate  Only copy the files; choose them yourself in Xcode → Settings.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --font) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; font="$2"; shift 2 ;;
        --font=*) font="${1#--font=}"; shift ;;
        --no-activate) activate=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Xcode runs on macOS only." >&2
    exit 1
fi

has_jetbrains_mono() {
    local dir
    for dir in "$HOME/Library/Fonts" "/Library/Fonts"; do
        compgen -G "$dir/JetBrainsMono*" >/dev/null && return 0
    done
    return 1
}

case "$font" in
    auto) if has_jetbrains_mono; then font_dir="JetBrains Mono"; else font_dir="SF Mono"; fi ;;
    sf-mono) font_dir="SF Mono" ;;
    jetbrains-mono)
        font_dir="JetBrains Mono"
        has_jetbrains_mono || echo "Note: JetBrains Mono isn't in ~/Library/Fonts or /Library/Fonts; Xcode falls back to another font until it is installed."
        ;;
    *) usage >&2; exit 2 ;;
esac

mkdir -p "$userdata/KeyBindings" "$userdata/FontAndColorThemes" "$userdata/CodeSnippets" "$state"

installed=()
copy() {
    cp "$1" "$2/"
    installed+=("$2/$(basename "$1")")
}
copy "$here/KeyBindings/$keybindings" "$userdata/KeyBindings"
for theme in "$here/FontAndColorThemes/$font_dir/"*.xccolortheme; do
    copy "$theme" "$userdata/FontAndColorThemes"
done
for snippet in "$here/CodeSnippets/"*.codesnippet; do
    copy "$snippet" "$userdata/CodeSnippets"
done
printf '%s\n' "${installed[@]}" > "$state/installed.txt"

echo "Installed the Muscle Memory key bindings, the Dark and Light themes ($font_dir) and ${#installed[@]} files in total into $userdata."

if [[ $activate -eq 0 ]]; then
    echo "Choose them in Xcode → Settings → Key Bindings and → Themes."
    exit 0
fi

if pgrep -xq Xcode; then
    echo "Xcode is running, so its settings were left alone. Quit Xcode and run this again to switch to Muscle Memory,"
    echo "or choose it yourself in Xcode → Settings → Key Bindings and → Themes."
    exit 0
fi

# Remember the previous choices once, so uninstall.sh can put them back.
if [[ ! -f "$state/previous.txt" ]]; then
    for key in IDEKeyBindingCurrentPreferenceSet XCFontAndColorCurrentTheme XCFontAndColorCurrentDarkTheme; do
        printf '%s=%s\n' "$key" "$(defaults read "$domain" "$key" 2>/dev/null || true)"
    done > "$state/previous.txt"
fi

defaults write "$domain" IDEKeyBindingCurrentPreferenceSet -string "$keybindings"
defaults write "$domain" XCFontAndColorCurrentTheme -string "$light_theme"
defaults write "$domain" XCFontAndColorCurrentDarkTheme -string "$dark_theme"
echo "Xcode will use the Muscle Memory key bindings, Muscle Memory Light in light mode and Muscle Memory Dark in dark mode."
