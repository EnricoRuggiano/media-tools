#!/usr/bin/env python3

import sys
import re
import base64

for line in sys.stdin:

    m = re.search(r'tables:\s*([0-9A-Fa-f]+)', line)
    if not m:
        continue

    hexstr = m.group(1)

    # Find start of ASCII "AQ"
    start = hexstr.find("4151")
    if start < 0:
        continue

    payload = hexstr[start:]

    b64 = ""

    for i in range(0, len(payload), 2):
        h = payload[i:i+2]

        if len(h) != 2:
            break

        c = chr(int(h, 16))

        if c in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=":
            b64 += c
        else:
            break

    try:
        decoded = base64.b64decode(b64)

        fc = decoded.find(b"\xfc")

        if fc >= 0:
            print(decoded[fc:].hex())
        else:
            print(decoded.hex())

    except Exception as e:
        print(f"B64 ERROR: {e}", file=sys.stderr)
