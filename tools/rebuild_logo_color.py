"""Compose purple symbol + black SORI wordmark into clean logo assets."""
import base64
import io
import re
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

raw = subprocess.check_output(["git", "show", "HEAD:assets/images/logo_sori.svg"])
matches = list(
    re.finditer(br"data:image/([a-zA-Z0-9+]+);base64,([A-Za-z0-9+/=]+)", raw)
)
# Color embed is index 1 (RGB purple)
sym = Image.open(io.BytesIO(base64.b64decode(matches[1].group(2)))).convert("RGBA")

# Black bg -> transparent; keep purple
pixels = sym.load()
w, h = sym.size
for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        # near-black background
        if r < 28 and g < 28 and b < 28:
            pixels[x, y] = (0, 0, 0, 0)

# Trim transparent
bbox = sym.getbbox()
sym = sym.crop(bbox)
print("symbol trimmed", sym.size)

# Wordmark canvas — wide landscape like original viewBox 600x225
out_h = 220
# Symbol height ~ 78% of canvas
sym_h = int(out_h * 0.78)
sym_w = int(sym.width * (sym_h / sym.height))
sym = sym.resize((sym_w, sym_h), Image.Resampling.LANCZOS)

# Estimate text width; use a bold sans if available
font = None
for candidate in [
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\arial.ttf",
    r"C:\Windows\Fonts\seguisb.ttf",
]:
    p = Path(candidate)
    if p.exists():
        font = ImageFont.truetype(str(p), size=96)
        break
if font is None:
    font = ImageFont.load_default()

# Measure text
tmp = Image.new("RGBA", (10, 10))
d = ImageDraw.Draw(tmp)
tb = d.textbbox((0, 0), "SORI", font=font)
tw, th = tb[2] - tb[0], tb[3] - tb[1]

gap = 28
pad_x = 16
pad_y = 18
out_w = pad_x + sym_w + gap + tw + pad_x
out_h = max(out_h, sym_h + pad_y * 2, th + pad_y * 2)

canvas = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
sym_y = (out_h - sym_h) // 2
canvas.paste(sym, (pad_x, sym_y), sym)

draw = ImageDraw.Draw(canvas)
text_x = pad_x + sym_w + gap
text_y = (out_h - th) // 2 - tb[1]
draw.text((text_x, text_y), "SORI", font=font, fill=(17, 17, 17, 255))

png_path = Path("assets/images/logo_sori.png")
buf = io.BytesIO()
canvas.save(buf, format="PNG", optimize=True)
png_bytes = buf.getvalue()
png_path.write_bytes(png_bytes)
print("png", png_path, canvas.size, len(png_bytes))

b64 = base64.b64encode(png_bytes).decode("ascii")
cw, ch = canvas.size
svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="{cw}" height="{ch}" viewBox="0 0 {cw} {ch}"
     preserveAspectRatio="xMidYMid meet" role="img" aria-label="SORI">
  <title>SORI</title>
  <image width="{cw}" height="{ch}" x="0" y="0"
         href="data:image/png;base64,{b64}"
         xlink:href="data:image/png;base64,{b64}"/>
</svg>
"""
svg_path = Path("assets/images/logo_sori.svg")
svg_path.write_text(svg, encoding="utf-8", newline="\n")
print("svg", svg_path, svg_path.stat().st_size)

# Also restore HEAD svg backup? keep composed clean version.
