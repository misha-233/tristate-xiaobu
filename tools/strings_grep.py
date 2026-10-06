#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""按正则从 APK 的 dex/arsc 里捞出 ASCII 字符串。"""
import re
import sys
import zipfile


def ascii_strings(data, minlen=4):
    cur = bytearray()
    out = []
    for b in data:
        if 32 <= b < 127:
            cur.append(b)
        else:
            if len(cur) >= minlen:
                out.append(cur.decode("ascii", "replace"))
            cur = bytearray()
    if len(cur) >= minlen:
        out.append(cur.decode("ascii", "replace"))
    return out


def main(apk, pattern, minlen=4):
    pat = re.compile(pattern, re.IGNORECASE)
    hits = set()
    with zipfile.ZipFile(apk) as z:
        for name in z.namelist():
            if not (name.endswith(".dex") or name == "resources.arsc"):
                continue
            for s in ascii_strings(z.read(name), minlen):
                if pat.search(s) and len(s) < 120:
                    hits.add(s)
    for s in sorted(hits):
        print(s)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 4)
