#!/bin/bash
# Generate MagikOS theme assets for SDDM and Plymouth using ImageMagick

set -e

# Colors
BG="#0d0e14"
ACCENT="#5b3f9e"
TEXT="#ffffff"
ERROR="#f44336"
ENTRY_BG="#1a1b26"
PROGRESS_BG="#282a3a"

: "${MAGIKOS_PATH:?MAGIKOS_PATH must be set}"
SDDM_DIR="$MAGIKOS_PATH/default/sddm/magikos"
PLYMOUTH_DIR="$MAGIKOS_PATH/default/plymouth"

mkdir -p "$SDDM_DIR" "$PLYMOUTH_DIR"

echo "Generating MagikOS theme assets..."

# Find a usable font
FONT=""
for f in \
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" \
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf" \
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf" \
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"; do
    if [[ -f "$f" ]]; then
        FONT="$f"
        break
    fi
done

if [[ -z "$FONT" ]]; then
    echo "Warning: No TrueType font found, using default"
    FONT_PATH=""
else
    FONT_PATH="font:${FONT}"
fi

# -------------------------------- SDDM Assets --------------------------------

echo "  Creating SDDM assets in $SDDM_DIR"

# Logo (500x120, transparent background, white text with shadow)
# First create text layer, then composite for proper centering
magick -size 500x120 xc:transparent \
    -font "$FONT" -pointsize 72 \
    -fill black -annotate +152+62 "MagikOS" \
    -fill "$TEXT" -annotate +150+60 "MagikOS" \
    "$SDDM_DIR/logo.png"

# Lock icon (34x38, purple)
magick -size 34x38 xc:transparent \
    -fill "$ACCENT" \
    -draw "roundrectangle 8,18 26,32 3,3" \
    -stroke "$ACCENT" -strokewidth 3 \
    -draw "arc 10,4 24,20 180,0" \
    "$SDDM_DIR/lock.png"

# Lock icon failed (34x38, red)
magick -size 34x38 xc:transparent \
    -fill "$ERROR" \
    -draw "roundrectangle 8,18 26,32 3,3" \
    -stroke "$ERROR" -strokewidth 3 \
    -draw "arc 10,4 24,20 180,0" \
    "$SDDM_DIR/lock-failed.png"

# Entry field (300x50, dark bg with purple border)
magick -size 300x50 xc:transparent \
    -fill none -stroke "$ACCENT" -strokewidth 2 \
    -draw "roundrectangle 0,0 299,49 8,8" \
    -fill "$ENTRY_BG" -stroke none \
    -draw "roundrectangle 2,2 297,47 6,6" \
    "$SDDM_DIR/entry.png"

# Entry field failed (300x50, dark bg with red border)
magick -size 300x50 xc:transparent \
    -fill none -stroke "$ERROR" -strokewidth 2 \
    -draw "roundrectangle 0,0 299,49 8,8" \
    -fill "$ENTRY_BG" -stroke none \
    -draw "roundrectangle 2,2 297,47 6,6" \
    "$SDDM_DIR/entry-failed.png"

# Bullet (7x7, white dot)
magick -size 7x7 xc:transparent \
    -fill "$TEXT" \
    -draw "circle 3,3 3,0" \
    "$SDDM_DIR/bullet.png"

# -------------------------------- Plymouth Assets --------------------------------

echo "  Creating Plymouth assets in $PLYMOUTH_DIR"

# Logo (500x120)
magick -size 500x120 xc:transparent \
    -font "$FONT" -pointsize 72 \
    -fill black -annotate +152+62 "MagikOS" \
    -fill "$TEXT" -annotate +150+60 "MagikOS" \
    "$PLYMOUTH_DIR/logo.png"

# Lock icon (34x38)
magick -size 34x38 xc:transparent \
    -fill "$ACCENT" \
    -draw "roundrectangle 8,18 26,32 3,3" \
    -stroke "$ACCENT" -strokewidth 3 \
    -draw "arc 10,4 24,20 180,0" \
    "$PLYMOUTH_DIR/lock.png"

# Entry field (300x50)
magick -size 300x50 xc:transparent \
    -fill none -stroke "$ACCENT" -strokewidth 2 \
    -draw "roundrectangle 0,0 299,49 8,8" \
    -fill "$ENTRY_BG" -stroke none \
    -draw "roundrectangle 2,2 297,47 6,6" \
    "$PLYMOUTH_DIR/entry.png"

# Bullet (7x7)
magick -size 7x7 xc:transparent \
    -fill "$TEXT" \
    -draw "circle 3,3 3,0" \
    "$PLYMOUTH_DIR/bullet.png"

# Progress bar fill (260x8, purple)
magick -size 260x8 xc:transparent \
    -fill "$ACCENT" \
    -draw "roundrectangle 0,0 259,7 4,4" \
    "$PLYMOUTH_DIR/progress_bar.png"

# Progress bar background (260x8, darker)
magick -size 260x8 xc:transparent \
    -fill "$PROGRESS_BG" \
    -draw "roundrectangle 0,0 259,7 4,4" \
    "$PLYMOUTH_DIR/progress_box.png"

echo "Done! All assets generated."
