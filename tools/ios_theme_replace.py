import os
import re

root = "lib"
replacements = [
    (r"const Color\(0xFFE53935\)", "SoriTokens.systemRed"),
    (r"Color\(0xFFE53935\)", "SoriTokens.systemRed"),
    (r"const Color\(0xFFDC2626\)", "SoriTokens.systemRed"),
    (r"Color\(0xFFDC2626\)", "SoriTokens.systemRed"),
    (r"const Color\(0xFFEF4444\)", "SoriTokens.systemRed"),
    (r"Color\(0xFFEF4444\)", "SoriTokens.systemRed"),
    (r"const Color\(0xFFC4B5FD\)", "SoriTokens.textTertiary"),
    (r"Color\(0xFFC4B5FD\)", "SoriTokens.textTertiary"),
    (r"const Color\(0xFFF9A8D4\)", "SoriTokens.textSecondary"),
    (r"Color\(0xFFF9A8D4\)", "SoriTokens.textSecondary"),
    (r"const Color\(0xFFF472B6\)", "SoriTokens.textSecondary"),
    (r"Color\(0xFFF472B6\)", "SoriTokens.textSecondary"),
    (r"const Color\(0xFFF97316\)", "SoriTokens.textSecondary"),
    (r"Color\(0xFFF97316\)", "SoriTokens.textSecondary"),
    (r"const Color\(0xFF0EA5E9\)", "SoriTokens.primary"),
    (r"Color\(0xFF0EA5E9\)", "SoriTokens.primary"),
    (r"const Color\(0xFF047857\)", "SoriTokens.primary"),
    (r"Color\(0xFF047857\)", "SoriTokens.primary"),
    (r"const Color\(0xFF0F766E\)", "SoriTokens.primary"),
    (r"Color\(0xFF0F766E\)", "SoriTokens.primary"),
    (r"const Color\(0xFFCCFBF1\)", "SoriTokens.primarySoft"),
    (r"Color\(0xFFCCFBF1\)", "SoriTokens.primarySoft"),
    (r"const Color\(0xFF60A5FA\)", "SoriTokens.primary"),
    (r"Color\(0xFF60A5FA\)", "SoriTokens.primary"),
    (r"const Color\(0xFFB7791F\)", "SoriTokens.textSecondary"),
    (r"Color\(0xFFB7791F\)", "SoriTokens.textSecondary"),
    (r"const Color\(0xFFF5A524\)", "SoriTokens.textSecondary"),
    (r"Color\(0xFFF5A524\)", "SoriTokens.textSecondary"),
    (r"const Color\(0xFFD97706\)", "SoriTokens.textSecondary"),
    (r"Color\(0xFFD97706\)", "SoriTokens.textSecondary"),
    (r"const Color\(0xFF991B1B\)", "SoriTokens.primaryDark"),
    (r"Color\(0xFF991B1B\)", "SoriTokens.primaryDark"),
    (r"const Color\(0xFFFCA5A5\)", "SoriTokens.systemRed.withValues(alpha: 0.45)"),
    (r"Color\(0xFFFCA5A5\)", "SoriTokens.systemRed.withValues(alpha: 0.45)"),
    (r"const Color\(0xFF312E81\)", "SoriTokens.primaryLight"),
    (r"Color\(0xFF312E81\)", "SoriTokens.primaryLight"),
    (r"const Color\(0xFF78350F\)", "SoriTokens.primaryLight"),
    (r"Color\(0xFF78350F\)", "SoriTokens.primaryLight"),
    (r"const Color\(0xFFFDE68A\)", "SoriTokens.textQuaternary"),
    (r"Color\(0xFFFDE68A\)", "SoriTokens.textQuaternary"),
    (r"const Color\(0xFFFDBA74\)", "SoriTokens.textSecondary"),
    (r"Color\(0xFFFDBA74\)", "SoriTokens.textSecondary"),
    (r"const Color\(0xFFCD7F32\)", "SoriTokens.border"),
    (r"Color\(0xFFCD7F32\)", "SoriTokens.border"),
    (r"const Color\(0xFF1A1028\)", "SoriTokens.primaryDark"),
    (r"Color\(0xFF1A1028\)", "SoriTokens.primaryDark"),
]

changed_files = []
for dirpath, _, files in os.walk(root):
    for fn in files:
        if not fn.endswith(".dart"):
            continue
        path = os.path.join(dirpath, fn)
        with open(path, encoding="utf-8") as f:
            src = f.read()
        orig = src
        for pat, rep in replacements:
            src = re.sub(pat, rep, src)
        src = re.sub(
            r"(SnackBar\([\s\S]*?backgroundColor:\s*)SoriTokens\.primaryDark",
            r"\1SoriTokens.systemRed",
            src,
        )
        if src != orig:
            if "SoriTokens." in src and "sori_tokens.dart" not in src:
                rel = os.path.relpath("lib/theme/sori_tokens.dart", dirpath).replace("\\", "/")
                import_line = f"import '{rel}';\n"
                if "import 'package:flutter/material.dart';" in src:
                    src = src.replace(
                        "import 'package:flutter/material.dart';",
                        "import 'package:flutter/material.dart';\n\n" + import_line,
                        1,
                    )
            with open(path, "w", encoding="utf-8") as f:
                f.write(src)
            changed_files.append(path)

print(f"Changed {len(changed_files)} files")
for p in sorted(changed_files):
    print(" ", p)
