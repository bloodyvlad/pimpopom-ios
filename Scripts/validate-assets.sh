#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

shasum -a 256 -c Scripts/asset-hashes.sha256

test "$(find App/Resources/Audio -type f | wc -l | tr -d ' ')" = "14"
test "$(find App/Resources/Fonts -type f | wc -l | tr -d ' ')" = "1"
test "$(find App/Resources/Pets -type f | wc -l | tr -d ' ')" = "14"
test "$(find App/Resources/Themes -type f | wc -l | tr -d ' ')" = "3"

dimensions() {
  file=$1
  expected_width=$2
  expected_height=$3
  width=$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')
  height=$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')
  test "$width" = "$expected_width"
  test "$height" = "$expected_height"
}

opaque() {
  file=$1
  has_alpha=$(sips -g hasAlpha "$file" | awk '/hasAlpha/ { print $2 }')
  test "$has_alpha" = "no"
}

app_icon=App/Assets.xcassets/AppIcon.appiconset/PimPoPom-AppIcon.png
app_icon_master=assets/branding/sources/PimPoPom-AppIcon-glow-master.png
light_app_icon=App/Assets.xcassets/AppIconLight.appiconset/PimPoPom-AppIcon-Light.png
light_app_icon_master=assets/branding/sources/PimPoPom-AppIcon-light-master.png
pixel_app_icon=App/Assets.xcassets/AppIconPixel.appiconset/PimPoPom-AppIcon-Pixel.png
pixel_app_icon_master=assets/branding/sources/PimPoPom-AppIcon-pixel-master.png
glow_preview=App/Assets.xcassets/AppIconGlowPreview.imageset/PimPoPom-AppIcon-Glow-Preview.png
light_preview=App/Assets.xcassets/AppIconLightPreview.imageset/PimPoPom-AppIcon-Light-Preview.png
pixel_preview=App/Assets.xcassets/AppIconPixelPreview.imageset/PimPoPom-AppIcon-Pixel-Preview.png
dimensions "$app_icon" 1024 1024
dimensions "$app_icon_master" 1024 1024
dimensions "$light_app_icon" 1024 1024
dimensions "$light_app_icon_master" 1024 1024
dimensions "$pixel_app_icon" 1024 1024
dimensions "$pixel_app_icon_master" 1024 1024
dimensions "$glow_preview" 180 180
dimensions "$light_preview" 180 180
dimensions "$pixel_preview" 180 180
opaque "$app_icon"
opaque "$app_icon_master"
opaque "$light_app_icon"
opaque "$light_app_icon_master"
opaque "$pixel_app_icon"
opaque "$pixel_app_icon_master"
opaque "$glow_preview"
opaque "$light_preview"
opaque "$pixel_preview"
cmp -s "$app_icon_master" "$app_icon"
cmp -s "$light_app_icon_master" "$light_app_icon"
cmp -s "$pixel_app_icon_master" "$pixel_app_icon"

for contents in \
  App/Assets.xcassets/AppIcon.appiconset/Contents.json \
  App/Assets.xcassets/AppIconLight.appiconset/Contents.json \
  App/Assets.xcassets/AppIconPixel.appiconset/Contents.json \
  App/Assets.xcassets/AppIconGlowPreview.imageset/Contents.json \
  App/Assets.xcassets/AppIconLightPreview.imageset/Contents.json \
  App/Assets.xcassets/AppIconPixelPreview.imageset/Contents.json; do
  plutil -convert xml1 -o /dev/null -- "$contents"
done

for file in App/Resources/Pets/*-sprite.png; do
  dimensions "$file" 640 64
done

for file in App/Resources/Pets/*.png; do
  case "$file" in
    *-sprite.png) ;;
    *) dimensions "$file" 64 48 ;;
  esac
done

for source in assets/pets/sources/*.png; do
    runtime="App/Resources/Pets/$(basename "$source")"
    cmp -s "$source" "$runtime"
done

for source in assets/themes/sources/*.png; do
    runtime="App/Resources/Themes/$(basename "$source")"
    cmp -s "$source" "$runtime"
    dimensions "$runtime" 1024 1024
done

cmp -s assets/fonts/sources/jersey-10-regular.ttf App/Resources/Fonts/jersey-10-regular.ttf
test "$(/usr/libexec/PlistBuddy -c 'Print :UIAppFonts:0' Config/Info.plist)" = "jersey-10-regular.ttf"

printf '%s\n' 'Asset hashes, counts, retained sources, font registration, icon catalogs, opacity, and image geometry verified.'
