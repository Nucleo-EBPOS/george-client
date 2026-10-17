#!/usr/bin/env bash
# GEORGE: gera todos os ícones do app a partir da marca oficial (brand/george-icon.png).
# Uso: scripts/george-gen-icons.sh /caminho/brand   (requer ImageMagick `convert`)
set -euo pipefail
BRAND="${1:-/srv/george/brand}"
ICON="$BRAND/george-icon.png"
LOGO="$BRAND/george-logo.png"
LOGO_W="$BRAND/george-logo-white.png"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
sq() { convert "$ICON" -background none -gravity center -resize "${1}x${1}" -extent "${1}x${1}" "$2"; }

# res/ (Linux deb/AppImage, Cargo bundle, tray)
sq 1024 res/icon.png
sq 1024 res/mac-icon.png
sq 32 res/32x32.png; sq 64 res/64x64.png; sq 128 res/128x128.png; sq 256 res/128x128@2x.png
convert "$ICON" -background none -gravity center -define icon:auto-resize=256,128,64,48,32,16 res/icon.ico
convert "$ICON" -background none -gravity center -define icon:auto-resize=32,16 res/tray-icon.ico
# tray template (macOS): silhueta monocromática
convert "$ICON" -background none -gravity center -resize 60x60 -extent 60x60 -alpha extract -negate -alpha copy -fill black -colorize 100 res/mac-tray-dark-x2.png
convert "$ICON" -background none -gravity center -resize 48x48 -extent 48x48 -alpha extract -negate -alpha copy -fill white -colorize 100 res/mac-tray-light-x2.png
# SVGs usados pelo Linux: wrapper SVG com o PNG embutido
b64=$(base64 -w0 res/icon.png)
for f in res/scalable.svg res/logo.svg flutter/assets/icon.svg; do
  printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1024" height="1024" viewBox="0 0 1024 1024"><image width="1024" height="1024" xlink:href="data:image/png;base64,%s"/></svg>\n' "$b64" > "$f"
done

# Flutter assets
sq 512 flutter/assets/icon.png
cp "$LOGO" flutter/assets/logo.png
cp "$LOGO" flutter/assets/logo_light.png
cp "$LOGO_W" flutter/assets/logo_dark.png
sq 512 flutter/assets/george/george-icon.png
cp "$LOGO" flutter/assets/george/george-logo.png
cp "$LOGO_W" flutter/assets/george/george-logo-white.png

# Windows
convert "$ICON" -background none -gravity center -define icon:auto-resize=256,128,64,48,32,16 flutter/windows/runner/resources/app_icon.ico
# macOS (.icns)
python3 "$ROOT/scripts/george-make-icns.py" "$ICON" flutter/macos/Runner/AppIcon.icns
# Android
declare -A D=([mdpi]=1 [hdpi]=1.5 [xhdpi]=2 [xxhdpi]=3 [xxxhdpi]=4)
for d in "${!D[@]}"; do
  dir=flutter/android/app/src/main/res/mipmap-$d; mkdir -p "$dir"
  l=$(python3 -c "print(int(48*${D[$d]}))"); fg=$(python3 -c "print(int(108*${D[$d]}))"); st=$(python3 -c "print(int(24*${D[$d]}))")
  sq "$l" "$dir/ic_launcher.png"
  convert "$ICON" -background none -gravity center -resize "$((l*9/10))x$((l*9/10))" -extent "${l}x${l}" \( +clone -alpha extract -draw "circle $((l/2)),$((l/2)) $((l/2)),0" -negate \) -alpha off -compose copy_opacity -composite "$dir/ic_launcher_round.png" 2>/dev/null || sq "$l" "$dir/ic_launcher_round.png"
  convert "$ICON" -background none -gravity center -resize "$((fg*2/3))x$((fg*2/3))" -extent "${fg}x${fg}" "$dir/ic_launcher_foreground.png"
  convert "$ICON" -background none -gravity center -resize "${st}x${st}" -extent "${st}x${st}" -alpha extract -negate -alpha copy -fill white -colorize 100 "$dir/ic_stat_logo.png"
done
# Web (landing)
mkdir -p web-landing/icons
sq 192 web-landing/icons/icon-192.png; sq 512 web-landing/icons/icon-512.png; sq 64 web-landing/favicon.png
cp "$LOGO" web-landing/george-logo.png; cp "$LOGO_W" web-landing/george-logo-white.png
echo "icons gerados"
