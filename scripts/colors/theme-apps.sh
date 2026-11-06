#!/usr/bin/env bash
# Mosaic OS: with a fixed theme (Gruvbox, Horizonte...), the apps that take their
# colours from Matugen get the THEME's colours instead of the wallpaper's:
#   Neovim (colors/matugen.lua and its icon), the Mosaic Store (colors.css) and
#   the Zen browser (zen-userChrome.css / zen-userContent.css).
# How: the theme's JSON (the 49 Material colours) is turned into the layout
# Matugen dumps (colors.<name>.{dark,default,light}.color) and imported with
# `matugen json`, using a config with ONLY those templates, copied from
# ~/.config/matugen/config.toml (same files, same post hooks). The rest of
# Matugen's outputs (Hyprland, GTK, KDE...) are left alone.
# Runs after every wallpaper change (switchwall.sh) and when a theme is chosen.
# With the Mosaic theme it does nothing: Matugen's wallpaper colours stand.
set -u

# the theme: the argument (just chosen), or the saved one
THEME=${1:-$(cat "$HOME/.config/mosaic-os/theme" 2>/dev/null || echo mosaic)}
[ "$THEME" = "mosaic" ] && exit 0
SHELL_DIR=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
FILE="$SHELL_DIR/themes/$THEME.json"
[ -f "$FILE" ] || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 -I - "$FILE" "$HOME/.config/matugen/config.toml" "$tmp" <<'EOF'
import json, sys, tomllib
theme_file, matugen_config, out = sys.argv[1:4]
theme = json.load(open(theme_file))
# fixed themes are dark only: the same colour for every mode
colors = {k: {m: {"color": v} for m in ("dark", "default", "light")} for k, v in theme.items()}
json.dump({"colors": colors}, open(f"{out}/colors.json", "w"))
wanted = ("nvim", "nvimIcon", "site", "zen-userchrome", "zen-usercontent")
templates = tomllib.load(open(matugen_config, "rb")).get("templates", {})
with open(f"{out}/config.toml", "w") as f:
    f.write("[config]\n")
    for name in wanted:
        if name not in templates:
            continue
        f.write(f"\n[templates.{name}]\n")
        for key, value in templates[name].items():
            f.write(f"{key} = {json.dumps(value)}\n")
EOF

matugen json "$tmp/colors.json" -c "$tmp/config.toml" -m dark -q
