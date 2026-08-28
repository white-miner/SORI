#!/usr/bin/env python3
"""Generate PWA icons from assets/images/logo_sori_app.svg (white 1:1 PNG)."""

from __future__ import annotations

import re
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
SVG_PATH = ROOT / "assets" / "images" / "logo_sori_app.svg"
WEB = ROOT / "web"
ICONS = WEB / "icons"

ICON_VERSION = "2"


def svg_markup(size: int, padding_ratio: float) -> str:
    raw = SVG_PATH.read_text(encoding="utf-8")
    inner = re.sub(r"<\?xml[^>]*\?>", "", raw, count=1).strip()
    inner = re.sub(r"^<svg\b", "<svg", inner, count=1)
    pad_pct = round(padding_ratio * 100, 2)
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <style>
    html, body {{
      margin: 0;
      width: {size}px;
      height: {size}px;
      background: #FFFFFF;
      overflow: hidden;
    }}
    #wrap {{
      width: {size}px;
      height: {size}px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #FFFFFF;
    }}
    svg {{
      width: {100 - pad_pct * 2}%;
      height: {100 - pad_pct * 2}%;
      display: block;
    }}
  </style>
</head>
<body>
  <div id="wrap">{inner}</div>
</body>
</html>"""


def render_icon(page, size: int, padding_ratio: float, out_path: Path) -> None:
    page.set_viewport_size({"width": size, "height": size})
    page.set_content(svg_markup(size, padding_ratio), wait_until="networkidle")
    page.locator("#wrap").screenshot(path=str(out_path), type="png")
    print(f"wrote {out_path} ({size}x{size})")


def main() -> None:
    if not SVG_PATH.is_file():
        raise SystemExit(f"Missing SVG: {SVG_PATH}")

    ICONS.mkdir(parents=True, exist_ok=True)

    targets = [
        (192, 0.08, ICONS / "Icon-192.png"),
        (512, 0.08, ICONS / "Icon-512.png"),
        (180, 0.08, ICONS / "apple-touch-icon.png"),
        (48, 0.06, WEB / "favicon.png"),
        (192, 0.18, ICONS / "Icon-maskable-192.png"),
        (512, 0.18, ICONS / "Icon-maskable-512.png"),
    ]

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(device_scale_factor=1)
        for size, padding, path in targets:
            render_icon(page, size, padding, path)
        browser.close()

    print(f"icon cache version: {ICON_VERSION}")


if __name__ == "__main__":
    main()
