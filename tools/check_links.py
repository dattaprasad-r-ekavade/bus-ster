"""Checks relative links and #anchors in the project's Markdown docs.

Run from the repo root: python tools/check_links.py
Exits non-zero when any link is broken.
"""
import glob
import os
import re
import sys

files = ["README.md", "GAME_PLAN.md"] + glob.glob("docs/**/*.md", recursive=True)


def slug(heading):
    heading = heading.strip().lower()
    heading = re.sub(r"[^\w\- ]", "", heading)
    return heading.replace(" ", "-")


def anchors(path):
    out = set()
    in_code = False
    for line in open(path, encoding="utf-8"):
        if line.startswith("```"):
            in_code = not in_code
        if not in_code and line.startswith("#"):
            out.add(slug(line.lstrip("#")))
    return out


bad = 0
count = 0
for f in files:
    text = open(f, encoding="utf-8").read()
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for m in re.finditer(r"\]\(([^)\s]+)\)", text):
        target_ref = m.group(1)
        if re.match(r"^[a-z]+:", target_ref):
            continue
        count += 1
        path, _, frag = target_ref.partition("#")
        target = os.path.normpath(os.path.join(os.path.dirname(f), path)) if path else f
        if not os.path.exists(target):
            print(f"BROKEN {f}: {target_ref}")
            bad += 1
            continue
        if frag and target.endswith(".md") and frag not in anchors(target):
            print(f"BAD ANCHOR {f}: {target_ref}")
            bad += 1

print(f"checked {count} relative links in {len(files)} files, {bad} problems")
sys.exit(1 if bad else 0)
