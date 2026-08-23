#!/usr/bin/env python3
"""
Generate MagikOS theme assets for SDDM and Plymouth.
Requires: pip install Pillow
"""

import os
from PIL import Image, ImageDraw, ImageFont

# Colors
BG_COLOR = (13, 14, 20)          # #0d0e14 - dark blue-black
ACCENT = (91, 63, 158)           # #5b3f9e - purple
TEXT_COLOR = (255, 255, 255)     # #ffffff - white
MUTED_COLOR = (170, 178, 192)   # #AAB2C0 - grey
ERROR_COLOR = (244, 67, 54)     # #f44336 - red
ENTRY_BG = (26, 27, 38)        # #1a1b26 - surface
ENTRY_BORDER = (91, 63, 158)    # #5b3f9e - purple border
PROGRESS_BG = (40, 42, 58)     # darker background
PROGRESS_FG = (91, 63, 158)    # purple progress


def create_logo(path, size=(400, 100)):
    """Create MagikOS text logo."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Try to use a nice font, fallback to default
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 64)
    except:
        try:
            font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 64)
        except:
            font = ImageFont.load_default()

    text = "MagikOS"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    x = (size[0] - text_width) // 2
    y = (size[1] - text_height) // 2

    # Draw text with slight shadow
    draw.text((x + 2, y + 2), text, fill=(0, 0, 0, 128), font=font)
    draw.text((x, y), text, fill=TEXT_COLOR, font=font)

    img.save(path)


def create_lock_icon(path, size=(34, 38), color=ACCENT):
    """Create lock icon."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Lock body
    body_x = size[0] // 4
    body_y = size[1] // 2
    body_w = size[0] // 2
    body_h = size[1] // 3
    draw.rounded_rectangle(
        [body_x, body_y, body_x + body_w, body_y + body_h],
        radius=3,
        fill=color
    )

    # Lock shackle
    shackle_x = size[0] // 3
    shackle_y = body_y - body_h // 2
    shackle_w = size[0] // 3
    shackle_h = body_h // 2 + 2
    draw.arc(
        [shackle_x, shackle_y, shackle_x + shackle_w, shackle_y + shackle_h],
        start=180,
        end=0,
        fill=color,
        width=3
    )

    img.save(path)


def create_entry_field(path, size=(300, 50), color=ENTRY_BG, border=ENTRY_BORDER, failed=False):
    """Create password entry field."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if failed:
        border = ERROR_COLOR

    # Outer border
    draw.rounded_rectangle(
        [0, 0, size[0] - 1, size[1] - 1],
        radius=8,
        fill=None,
        outline=border,
        width=2
    )

    # Inner fill
    draw.rounded_rectangle(
        [2, 2, size[0] - 3, size[1] - 3],
        radius=6,
        fill=color
    )

    img.save(path)


def create_bullet(path, size=(7, 7)):
    """Create password bullet dot."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.ellipse([0, 0, size[0] - 1, size[1] - 1], fill=TEXT_COLOR)

    img.save(path)


def create_progress_bar(path, size=(260, 8)):
    """Create progress bar fill."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rounded_rectangle(
        [0, 0, size[0] - 1, size[1] - 1],
        radius=4,
        fill=PROGRESS_FG
    )

    img.save(path)


def create_progress_box(path, size=(260, 8)):
    """Create progress bar background."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rounded_rectangle(
        [0, 0, size[0] - 1, size[1] - 1],
        radius=4,
        fill=PROGRESS_BG
    )

    img.save(path)


def main():
    magikos_path = os.environ.get("MAGIKOS_PATH")
    if not magikos_path:
        raise SystemExit("MAGIKOS_PATH must be set")

    sddm_dir = os.path.join(magikos_path, "default", "sddm", "magikos")
    plymouth_dir = os.path.join(magikos_path, "default", "plymouth")

    os.makedirs(sddm_dir, exist_ok=True)
    os.makedirs(plymouth_dir, exist_ok=True)

    print("Generating MagikOS theme assets...")

    # SDDM assets
    print(f"  Creating SDDM assets in {sddm_dir}")
    create_logo(os.path.join(sddm_dir, "logo.png"))
    create_lock_icon(os.path.join(sddm_dir, "lock.png"))
    create_lock_icon(os.path.join(sddm_dir, "lock-failed.png"), color=ERROR_COLOR)
    create_entry_field(os.path.join(sddm_dir, "entry.png"))
    create_entry_field(os.path.join(sddm_dir, "entry-failed.png"), failed=True)
    create_bullet(os.path.join(sddm_dir, "bullet.png"))

    # Plymouth assets
    print(f"  Creating Plymouth assets in {plymouth_dir}")
    create_logo(os.path.join(plymouth_dir, "logo.png"))
    create_lock_icon(os.path.join(plymouth_dir, "lock.png"))
    create_entry_field(os.path.join(plymouth_dir, "entry.png"))
    create_bullet(os.path.join(plymouth_dir, "bullet.png"))
    create_progress_bar(os.path.join(plymouth_dir, "progress_bar.png"))
    create_progress_box(os.path.join(plymouth_dir, "progress_box.png"))

    print("Done! All assets generated.")


if __name__ == "__main__":
    main()
