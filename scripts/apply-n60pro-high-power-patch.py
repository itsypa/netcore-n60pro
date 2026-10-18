#!/usr/bin/env python3
"""Remove the stock mt76 wireless packages from the N60 Pro image recipe.

The high-power profile uses MediaTek mt_wifi.  The upstream N60 Pro recipe
still lists kmod-mt7915e and its MT7986 firmware packages, which can bind the
same radio before the vendor driver.  Keep the device recipe's non-wireless
packages and remove only those three wireless package tokens in the build
workspace.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REMOVED_TOKENS = (
    "kmod-mt7915e",
    "kmod-mt7986-firmware",
    "mt7986-wo-firmware",
)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <filogic.mk>", file=sys.stderr)
        return 64

    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")
    start = text.find("define Device/netcore_n60-pro")
    if start < 0:
        print("N60 Pro device definition not found", file=sys.stderr)
        return 65

    end = text.find("\nendef", start)
    if end < 0:
        print("N60 Pro device definition is not terminated", file=sys.stderr)
        return 65

    block = text[start:end]
    if not re.search(r"(?m)^\s*DEVICE_PACKAGES\s*:=", block):
        print("N60 Pro DEVICE_PACKAGES line not found", file=sys.stderr)
        return 65

    changed = False
    for token in REMOVED_TOKENS:
        pattern = rf"(?<!\S){re.escape(token)}(?!\S)\s*"
        block, count = re.subn(pattern, "", block)
        changed = changed or count > 0

    remaining = [token for token in REMOVED_TOKENS if token in block]
    if remaining:
        print(
            "Could not remove N60 Pro wireless packages: " + ", ".join(remaining),
            file=sys.stderr,
        )
        return 65

    path.write_text(text[:start] + block + text[end:], encoding="utf-8")
    print(
        "N60 Pro high-power package patch: "
        + ("removed mt76 wireless packages" if changed else "already vendor-only")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
