#!/usr/bin/env bash
# Thumbnails and the average colour of every wallpaper in a folder, for the
# Mosaic OS wallpaper picker. Only new images are processed: the rest come
# from the cache. Runs at the lowest priority, so it never gets in the way.
#   ~/.cache/mosaic-os/wallpapers/thumbs/<name>.jpg   480x300 crop
#   ~/.cache/mosaic-os/wallpapers/colors.tsv          <name><TAB>#rrggbb
# Idea from hyprdots' wallpaper-index.sh (fedyaqq34356/hyprdots, GPL-3.0).
set -u

DIR="${1:?usage: wallpaper-index.sh <folder>}"
CACHE="$HOME/.cache/mosaic-os/wallpapers"
THUMBS="$CACHE/thumbs"
INDEX="$CACHE/colors.tsv"
mkdir -p "$THUMBS"
touch "$INDEX"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

while IFS= read -r wp; do
    name=$(basename "$wp")
    thumb="$THUMBS/$name.jpg"
    if [ ! -f "$thumb" ]; then
        nice -n 19 vipsthumbnail "$wp" --size 480x300 --smartcrop centre -o "$thumb[Q=82]" 2>/dev/null \
            || nice -n 19 magick "$wp" -resize 480x300^ -gravity center -extent 480x300 -quality 82 "$thumb" 2>/dev/null
    fi
    # colour already known: keep it
    if line=$(grep -m1 -F "$(printf '%s\t' "$name")" "$INDEX" 2>/dev/null); then
        printf '%s\n' "$line" >> "$tmp"
        continue
    fi
    src="$thumb"
    [ -f "$src" ] || src="$wp"
    hex=$(nice -n 19 magick "$src" -resize '1x1!' -depth 8 -format '#%[hex:p{0,0}]' info: 2>/dev/null)
    [ -n "$hex" ] && printf '%s\t%s\n' "$name" "${hex:0:7}" >> "$tmp"
done < <(find "$DIR" -maxdepth 1 -type f \
             \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)

mv "$tmp" "$INDEX"
trap - EXIT
