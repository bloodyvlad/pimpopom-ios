#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

shasum -a 256 -c Scripts/asset-hashes.sha256

test "$(find App/Resources/Audio -type f | wc -l | tr -d ' ')" = "14"
test "$(find App/Resources/Pets -type f | wc -l | tr -d ' ')" = "12"
test ! -e App/Resources/Pets/pancake-sprite.png

dimensions() {
  file=$1
  expected_width=$2
  expected_height=$3
  width=$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')
  height=$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')
  test "$width" = "$expected_width"
  test "$height" = "$expected_height"
}

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

printf '%s\n' 'Asset hashes, counts, retained sources, and pet geometry verified.'
