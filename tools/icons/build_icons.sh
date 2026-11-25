#!/bin/bash
# Renders the Stadia app icons from the SVGs next to this script:
#
#   icon.svg     -> iOS AppIcon set (opaque, full bleed: iOS masks it),
#                   web maskable icons, and rounded legacy Android and web
#                   icons
#   adaptive.svg -> Android adaptive icon layers (API 26+): background,
#                   foreground and monochrome (themed icons, Android 13+)
#   favicon.svg  -> web favicon (a bolder glyph for 16-32 px)
#
# Inkscape rasterises each source once at full size; ImageMagick
# downsamples (Lanczos) to every size the platforms need.
# Needs: inkscape (1.x) and magick (ImageMagick 7).
# Usage: bash tools/icons/build_icons.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# master <svg> <px> <out.png> [layer id]
# A layer id exports that layer alone, on the whole page.
master() {
  local svg=$1 px=$2 out=$3 id=${4:-}
  local args=(--export-type=png --export-filename="$out" -w "$px" -h "$px")
  [ -n "$id" ] && args+=(--export-id="$id" --export-id-only --export-area-page)
  inkscape "$svg" "${args[@]}" >/dev/null 2>&1
}

# Reproducible PNGs: no metadata, no timestamps.
PNG_OPTS=(-strip -define png:exclude-chunks=date,time)

# opaque <master> <px> <out>: RGB, no alpha channel (App Store rule).
opaque() {
  magick "$1" -filter Lanczos -resize "$2x$2" -background '#1E0021' \
    -alpha remove -alpha off "${PNG_OPTS[@]}" "PNG24:$3"
}

# alpha <master> <px> <out>: keeps transparency.
alpha() {
  magick "$1" -filter Lanczos -resize "$2x$2" "${PNG_OPTS[@]}" "PNG32:$3"
}

# --- masters -------------------------------------------------------------------
echo "rendering masters (inkscape)"
master "$here/icon.svg" 1024 "$tmp/icon.png"
# Rounded square cut from the full-bleed icon (radius 224 of 1024).
magick "$tmp/icon.png" \
  \( -size 1024x1024 xc:none -fill white \
     -draw "roundrectangle 0,0,1023,1023,224,224" \) \
  -compose DstIn -composite "$tmp/rounded.png"
for l in background foreground monochrome; do
  master "$here/adaptive.svg" 432 "$tmp/$l.png" "$l" # 108 dp @ xxxhdpi
done
master "$here/favicon.svg" 512 "$tmp/favicon.png"

# --- iOS: every image in the asset catalog, at its pixel size --------------
ios="$root/ios/Runner/Assets.xcassets/AppIcon.appiconset"
for f in "$ios"/Icon-App-*.png; do
  name=${f##*/}                     # Icon-App-83.5x83.5@2x.png
  spec=${name#Icon-App-}
  pt=${spec%%x*}                    # 83.5
  scale=${spec##*@}
  scale=${scale%x.png}              # 2
  px=$(awk "BEGIN { printf \"%d\", $pt * $scale + 0.5 }")
  opaque "$tmp/icon.png" "$px" "$f"
  echo "ios      $name ${px}px"
done

# --- Android: legacy icons (API < 26) and adaptive layers ------------------
res="$root/android/app/src/main/res"
for d in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  dpi=${d%%:*}
  s=${d##*:}
  legacy=$(awk "BEGIN { printf \"%d\", 48 * $s }")
  layer=$(awk "BEGIN { printf \"%d\", 108 * $s }")
  dir="$res/mipmap-$dpi"
  mkdir -p "$dir"
  alpha "$tmp/rounded.png" "$legacy" "$dir/ic_launcher.png"
  for l in background foreground monochrome; do
    alpha "$tmp/$l.png" "$layer" "$dir/ic_launcher_$l.png"
  done
  echo "android  mipmap-$dpi ${legacy}px, layers ${layer}px"
done

# --- Web ---------------------------------------------------------------------
web="$root/web"
alpha "$tmp/rounded.png" 512 "$web/icons/Icon-512.png"
alpha "$tmp/rounded.png" 192 "$web/icons/Icon-192.png"
opaque "$tmp/icon.png" 512 "$web/icons/Icon-maskable-512.png"
opaque "$tmp/icon.png" 192 "$web/icons/Icon-maskable-192.png"
alpha "$tmp/favicon.png" 32 "$web/favicon.png"
cp "$here/favicon.svg" "$web/favicon.svg"
echo "web      icons, favicon"
