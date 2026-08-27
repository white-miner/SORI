"""Extract embedded PNG from logo_sori.svg for reliable Flutter rendering."""
import base64
import re
from pathlib import Path

svg = Path("assets/images/logo_sori.svg").read_text(encoding="utf-8")
m = re.search(r"data:image/png;base64,([A-Za-z0-9+/=]+)", svg)
if not m:
    raise SystemExit("No embedded PNG found in logo_sori.svg")
raw = base64.b64decode(m.group(1))
out = Path("assets/images/logo_sori.png")
out.write_bytes(raw)
print(f"Wrote {out} ({len(raw)} bytes)")
