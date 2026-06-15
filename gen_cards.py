"""Generate pure-white, high-contrast classic playing cards for the Lucky5 cabinet.

Overwrites the 52 face PNGs + 2 backs in godot/cabinet/skins/lucky5/cards/

keeping the existing 626x1056 dimensions and filenames (rank+suit+.png).
"""

import os
from PIL import Image, ImageDraw, ImageFont

CARDS_DIR = r"C:\Users\Gabi.WIN-CD45QMUUPFF\Documents\GitHub\Lucky5-v7\godot\cabinet\skins\lucky5\cards"

W, H = 626, 1056

RED = (208, 0, 0, 255)
BLACK = (16, 16, 16, 255)
WHITE = (255, 255, 255, 255)
BORDER = (24, 24, 24, 255)

# Font paths - try multiple locations
ARIAL_BD_PATHS = [
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\arial.ttf",
]
SYMBOL_PATHS = [
    r"C:\Windows\Fonts\seguisym.ttf",
    r"C:\Windows\Fonts\seguiemj.ttf",
]

def find_font(paths):
    for p in paths:
        if os.path.exists(p):
            return p
    return None

ARIAL_BD = find_font(ARIAL_BD_PATHS)
SYMBOL = find_font(SYMBOL_PATHS)

if not ARIAL_BD:
    raise RuntimeError("Arial Bold font not found")
if not SYMBOL:
    raise RuntimeError("Symbol font (Segoe UI Symbol) not found")

RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
SUITS = {"S": "\u2660", "H": "\u2665", "D": "\u2666", "C": "\u2663"}
SUIT_COLOR = {"S": BLACK, "C": BLACK, "H": RED, "D": RED}

def rounded_card():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    radius = 56
    margin = 10
    # outer dark border
    d.rounded_rectangle([margin, margin, W - margin, H - margin], radius=radius, fill=BORDER)
    # white face
    pad = 18
    d.rounded_rectangle([margin + pad, margin + pad, W - margin - pad, H - margin - pad],
                        radius=radius - 12, fill=WHITE)
    return img

def text_size(d, text, font):
    box = d.textbbox((0, 0), text, font=font)
    return box[2] - box[0], box[3] - box[1], box[0], box[1]

def make_corner(rank, suit_glyph, color):
    """Render the rank + suit pip corner group on a transparent tile."""
    tile = Image.new("RGBA", (200, 320), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    rank_font = ImageFont.truetype(ARIAL_BD, 150 if rank != "10" else 120)
    suit_font = ImageFont.truetype(SYMBOL, 120)
    rw, rh, rox, roy = text_size(d, rank, rank_font)
    d.text((100 - rw / 2 - rox, 10 - roy), rank, font=rank_font, fill=color)
    sw, sh, sox, soy = text_size(d, suit_glyph, suit_font)
    d.text((100 - sw / 2 - sox, 180 - soy), suit_glyph, font=suit_font, fill=color)
    return tile

def make_card(rank, suit):
    glyph = SUITS[suit]
    color = SUIT_COLOR[suit]
    img = rounded_card()
    d = ImageDraw.Draw(img)
    corner = make_corner(rank, glyph, color)
    # top-left
    img.alpha_composite(corner, (48, 44))
    # bottom-right (rotated 180)
    img.alpha_composite(corner.rotate(180), (W - 48 - corner.width, H - 44 - corner.height))
    # big central pip
    center_font = ImageFont.truetype(SYMBOL, 440)
    gw, gh, gox, goy = text_size(d, glyph, center_font)
    d.text((W / 2 - gw / 2 - gox, H / 2 - gh / 2 - goy), glyph, font=center_font, fill=color)
    return img

def make_back(primary):
    img = rounded_card()
    d = ImageDraw.Draw(img)
    radius = 44
    inner = [60, 60, W - 60, H - 60]
    d.rounded_rectangle(inner, radius=radius, fill=primary)
    # diamond lattice
    light = tuple(min(255, c + 70) for c in primary[:3]) + (255,)
    step = 72
    for gx in range(inner[0], inner[2] + step, step):
        for gy in range(inner[1], inner[3] + step, step):
            d.polygon([(gx, gy - 22), (gx + 22, gy), (gx, gy + 22), (gx - 22, gy)],
                      outline=light, width=4)
    # inner frame
    d.rounded_rectangle([84, 84, W - 84, H - 84], radius=radius - 12, outline=light, width=6)
    return img

def main():
    count = 0
    for rank in RANKS:
        for suit in SUITS:
            path = os.path.join(CARDS_DIR, f"{rank}{suit}.png")
            make_card(rank, suit).save(path)
            count += 1
    make_back((26, 60, 142, 255)).save(os.path.join(CARDS_DIR, "bside.png")) # blue back
    make_back((150, 24, 28, 255)).save(os.path.join(CARDS_DIR, "holdbside.png")) # red held back
    print(f"generated {count} faces + 2 backs in {CARDS_DIR}")

if __name__ == "__main__":
    main()