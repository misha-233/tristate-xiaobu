#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""从 APK 里挖 intent action 常量 / 闪记相关关键字（不依赖 androguard）。"""
import re
import sys
import zipfile

PATTERNS = [
    ("ACTION", re.compile(r'^[a-zA-Z][A-Za-z0-9_.]*\.action\.[A-Za-z0-9_.]+$')),
    ("FLASH", re.compile(r'[Ff]lash[ _]?[Nn]ote|flashnotes|FlashNotes')),
    ("AIMEM", re.compile(r'aimemory|AiMemory|AIMemory')),
    ("CN", re.compile(r'闪记|记忆|记账|小布')),
    ("BROADCAST", re.compile(r'\.(?:broadcast|RECEIVER|EXTRA_|extra\.)[A-Za-z0-9_.]*')),
]


def ascii_strings(data, minlen=6):
    out = []
    cur = bytearray()
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


def scan(path):
    print("=" * 70)
    print("APK:", path)
    print("=" * 70)
    hits = {}
    with zipfile.ZipFile(path) as z:
        names = [n for n in z.namelist() if n.endswith(".dex") or n == "resources.arsc"]
        for name in names:
            data = z.read(name)
            cands = set()
            for s in ascii_strings(data):
                for tag, pat in PATTERNS:
                    if pat.search(s):
                        cands.add((tag, s))
            # arsc 里的中文（UTF-8 / UTF-16LE）
            if name == "resources.arsc":
                for kw in ("闪记", "小布记忆", "一键闪记"):
                    if kw.encode("utf-8") in data:
                        cands.add(("CN-UTF8", kw))
                    if kw.encode("utf-16-le") in data:
                        cands.add(("CN-UTF16", kw))
            for tag, s in cands:
                hits.setdefault(tag, set()).add(s)

    for tag, _ in PATTERNS:
        vals = hits.get(tag)
        if not vals:
            continue
        print("\n--- %s (%d) ---" % (tag, len(vals)))
        for v in sorted(vals):
            print("   ", v)
    for tag in ("CN-UTF8", "CN-UTF16"):
        vals = hits.get(tag)
        if vals:
            print("\n--- %s ---" % tag)
            for v in sorted(vals):
                print("   ", v)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        scan(p)
