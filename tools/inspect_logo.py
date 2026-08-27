import re
from pathlib import Path

s = Path("assets/images/logo_sori.svg").read_text(encoding="utf-8")
print("len", len(s))
print("image tags", len(re.findall(r"<image", s, re.I)))
print("path tags", len(re.findall(r"<path", s, re.I)))
print("use tags", len(re.findall(r"<use", s, re.I)))
print("filter", s.count("filter"))
print("base64", "base64" in s)
print("xlink:href count", s.count("xlink:href"))
colors = re.findall(r"#[0-9a-fA-F]{3,8}", s)
from collections import Counter
print("top colors", Counter(colors).most_common(15))
# check for embedded image mime
m = re.search(r"data:image/([^;]+);base64,", s)
print("embedded image", m.group(1) if m else None)
if m:
    print("base64 length around", len(re.findall(r"base64,[A-Za-z0-9+/=]+", s)[0]) if re.findall(r"base64,[A-Za-z0-9+/=]+", s) else 0)
