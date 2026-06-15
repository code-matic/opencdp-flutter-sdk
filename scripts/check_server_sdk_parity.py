#!/usr/bin/env python3
"""Cross-SDK parity check against Flutter conformance vectors."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VECTORS = ROOT / "docs" / "conformance_vectors.json"

CHECKS = [
    (
        "python",
        ROOT.parent / "opencdp-python" / "cdp_client" / "gateway_urls.py",
        'DEFAULT_PRIMARY = "',
        '"',
    ),
    (
        "go",
        ROOT.parent / "opencdp-go" / "cdp" / "gateway_urls.go",
        'defaultPrimaryBaseURL = "',
        '"',
    ),
    (
        "node",
        ROOT.parent / "opencdp-node-sdk" / "src" / "gateway_urls.ts",
        'DEFAULT_PRIMARY_BASE_URL =\n  "',
        '"',
    ),
    (
        "php",
        ROOT.parent / "opencdp-php" / "src" / "GatewayUrls.php",
        "public const DEFAULT_PRIMARY = '",
        "'",
    ),
]


def extract_quoted_value(text: str, marker: str, end_quote: str) -> str:
    start = text.index(marker) + len(marker)
    if text[start] == end_quote:
        start += 1
    end = text.index(end_quote, start)
    return text[start:end]


def main() -> int:
    vectors = json.loads(VECTORS.read_text())
    expected_primary = vectors["gateway"]["primary"]
    expected_fallbacks = vectors["gateway"]["fallbacks"]

    print("OpenCDP server SDK parity check\n")
    print(f"Contract primary:   {expected_primary}")
    print(f"Contract fallbacks: {expected_fallbacks}\n")

    failed = False
    for name, path, marker, end_quote in CHECKS:
        if not path.exists():
            print(f"[FAIL] {name}: missing {path}")
            failed = True
            continue
        text = path.read_text()
        primary = extract_quoted_value(text, marker, end_quote)
        ok = primary == expected_primary
        status = "OK" if ok else "FAIL"
        print(f"[{status}] {name}: primary = {primary}")
        if not ok:
            failed = True

    print("\nContract vectors:")
    for vector in vectors["vectors"]:
        print(f"  - {vector['id']}: {vector['method']} {vector['path']}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
