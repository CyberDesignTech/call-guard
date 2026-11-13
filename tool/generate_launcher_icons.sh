#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

render_icon() {
  local canvas="$1" center="$2" scale="$3" output="$4" final_size="$5"
  local stroke_width
  stroke_width="$(awk -v scale="$scale" 'BEGIN { printf "%.3f", 2.4 * scale }')"

  magick -size "${canvas}x${canvas}" xc:none \
    -fill 'gradient:#72A7FF-#19B6A3' \
    -draw "translate ${center},${center} scale ${scale},${scale} translate -50,-50 path 'M50,6 C61,13 75,16 87,18 L87,47 C87,68 71,85 50,95 C29,85 13,68 13,47 L13,18 C25,16 39,13 50,6 Z'" \
    -stroke 'rgba(255,255,255,0.34)' -strokewidth "$stroke_width" -fill none \
    -draw "translate ${center},${center} scale ${scale},${scale} translate -50,-50 path 'M50,15 C58,19 67,21 76,23'" \
    -fill white -stroke none \
    -draw "translate ${center},${center} scale ${scale},${scale} translate -50,-50 translate 50,50 scale 1.2,1.2 translate -50,-50 path 'M34,30 C31,29 28,31 27,34 L26,39 C29,53 43,67 57,72 C60,73 64,71 66,68 L69,63 C70,61 69,59 67,58 L60,54 C58,53 56,54 54,56 L51,59 C45,56 40,51 37,45 L41,41 C43,39 43,37 42,35 L37,31 C36,30 35,29 34,30 Z'" \
    -resize "${final_size}x${final_size}" -strip "PNG32:${root}/${output}"
}

render_icon 512 256 5.12 android/app/src/main/res/mipmap-mdpi/ic_launcher.png 48
render_icon 512 256 5.12 android/app/src/main/res/mipmap-hdpi/ic_launcher.png 72
render_icon 512 256 5.12 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png 96
render_icon 512 256 5.12 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png 144
render_icon 512 256 5.12 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png 192

# Adaptive foreground occupies the central Android safe zone on a 108dp canvas.
render_icon 432 216 2.968 android/app/src/main/res/drawable-nodpi/ic_launcher_foreground_bitmap.png 432
