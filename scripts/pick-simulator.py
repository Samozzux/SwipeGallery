#!/usr/bin/env python3
"""Sceglie un simulatore iPhone con iOS 26+ disponibile sul runner.

Legge l'output JSON di `xcrun simctl list devices available --json` da stdin
e stampa l'UDID. Preferisce "iPhone 17" e, a parità, il runtime più recente.
"""

import json
import re
import sys

PREFERRED = "iPhone 17"


def main() -> int:
    devices = json.load(sys.stdin)["devices"]
    best = None
    for runtime, entries in devices.items():
        match = re.search(r"iOS-(\d+)-(\d+)", runtime)
        if not match:
            continue
        version = (int(match.group(1)), int(match.group(2)))
        if version < (26, 0):
            continue
        for device in entries:
            name = device.get("name", "")
            if not name.startswith("iPhone") or not device.get("isAvailable", True):
                continue
            score = (name == PREFERRED, version, name)
            if best is None or score > best[0]:
                best = (score, device["udid"])
    if best is None:
        print("Nessun simulatore iPhone con iOS 26 o successivo", file=sys.stderr)
        return 1
    score, udid = best
    print(f"Simulatore scelto: {score[2]} (iOS {score[1][0]}.{score[1][1]})", file=sys.stderr)
    print(udid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
