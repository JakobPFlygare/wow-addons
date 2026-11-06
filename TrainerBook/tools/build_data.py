#!/usr/bin/env python3
"""Build TrainerBook's bundled data from wowforevertalents.com.

That site reads its spell and recipe lists from the Forever client (build noted in
each page), so it is the closest public source to the game itself. It does not carry
trainer costs; the addon records those in game when a trainer window is open.

Usage (stdlib only):  python3 tools/build_data.py [--refresh]
Pages are cached in tools/.cache so re-runs don't hit the site again.
"""
import html
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

BASE = "https://wowforevertalents.com"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
UA = "TrainerBook-addon-data-builder (personal use)"

CLASSES = ["warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid"]
PROFESSIONS = [
    "alchemy", "blacksmithing", "enchanting", "engineering", "herbalism", "leatherworking",
    "mining", "skinning", "tailoring", "cooking", "fishing", "first-aid",
]


def fetch(path: str, refresh: bool) -> str:
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / (path.strip("/").replace("/", "_") + ".html")
    if f.exists() and not refresh:
        return f.read_text(encoding="utf-8")
    req = urllib.request.Request(BASE + path, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        text = r.read().decode("utf-8")
    f.write_text(text, encoding="utf-8")
    time.sleep(0.5)  # be polite
    return text


def build_info(page: str) -> str:
    m = re.search(r"build (\d+\.\d+\.\d+\.\d+)", page)
    return m.group(1) if m else "?"


def icon_name(src: str) -> str:
    return src.rsplit("/", 1)[-1].removesuffix(".jpg")


def clean(s: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", s))).strip()


# ---------------------------------------------------------------- classes
def parse_class(page: str) -> list[dict]:
    spells = []
    # each school is a <section class="book-panel" ... data-tab="arms"> with <h2 class="page-title">Arms</h2>
    for sec in re.finditer(r'<section class="book-panel[^"]*"[^>]*>(.*?)</section>', page, re.S):
        body = sec.group(1)
        school = clean(re.search(r'<h2 class="page-title"[^>]*>(.*?)</h2>', body, re.S).group(1))
        for cell in re.finditer(r'<li class="cell[^"]*"(.*?)</li>', body, re.S):
            c = cell.group(1)
            status = re.search(r'data-status="([^"]*)"', c).group(1)
            if status == "removed":
                continue
            tip = json.loads(html.unescape(re.search(r'data-tip="([^"]*)"', c).group(1)))
            img = re.search(r'<img src="([^"]+)"', c)
            ranks = [
                {"r": k.get("r", ""), "l": k["l"], "m": k.get("m", ""), "q": k.get("q", ""), "d": k.get("d", "")}
                for k in tip["k"]
            ]
            spells.append({
                "n": tip["n"],
                "school": school,
                "icon": icon_name(img.group(1)) if img else "inv_misc_questionmark",
                "status": tip.get("s", status),
                "passive": bool(tip.get("p")),
                "talent": (tip.get("t") or [None])[0],
                "note": tip.get("no") or None,
                "ranks": ranks,
            })
    return spells


# ---------------------------------------------------------- professions
def parse_profession(page: str) -> dict:
    name = clean(re.search(r'<h2>(.*?)</h2>', page[page.find("data-window"):], re.S).group(1))
    emblem = re.search(r'class="pw-emblem"[^>]*><img src="([^"]+)"', page)
    recipes = []
    for grp in re.finditer(r'<section class="pw-group[^"]*"[^>]*>(.*?)</section>', page, re.S):
        body = grp.group(1)
        cat = clean(re.search(r'<span class="pw-group-name">(.*?)</span>', body, re.S).group(1))
        for row in re.finditer(r'<li class="pw-row"([^>]*)>(.*?)</li>', body, re.S):
            attrs, inner = row.group(1), row.group(2)
            a = dict(re.findall(r'data-([a-z]+)(?:="([^"]*)")?', attrs))
            if a.get("status") == "removed":
                continue
            link = re.search(r'href="https://www\.wowhead\.com/[a-z]+/(item|spell)=(\d+)"', inner)
            img = re.search(r'<img src="([^"]+)"', inner)
            nm = re.search(r'<span class="pw-row-name">(.*?)(?:<i |</span>)', inner, re.S)

            def num(k):
                v = a.get(k)
                return int(v) if v not in (None, "") else None

            recipes.append({
                "id": int(a["r"]),
                "n": clean(nm.group(1)),
                "icon": icon_name(img.group(1)) if img else "inv_misc_questionmark",
                "item": int(link.group(2)) if link and link.group(1) == "item" else None,
                "cat": cat,
                "src": a.get("src", ""),
                "learn": num("learn"),
                "y": num("yellow"), "g": num("green"), "gr": num("grey"),
                "favor": num("favor"),
                "status": a.get("status", ""),
                "text": a.get("text", ""),
            })
    return {"name": name, "icon": icon_name(emblem.group(1)) if emblem else None, "recipes": recipes}


# ------------------------------------------------------------- Lua out
def lua(v, indent=0) -> str:
    pad = "  " * indent
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{" + ", ".join(lua(x) for x in v) + "}"
        return "{\n" + "".join(f"{pad}  {lua(x, indent + 1)},\n" for x in v) + pad + "}"
    if isinstance(v, dict):
        items = [(k, x) for k, x in v.items() if x is not None]
        flat = all(not isinstance(x, (dict, list)) for _, x in items)
        key = lambda k: k if re.fullmatch(r"[A-Za-z_]\w*", k) else f"[{lua(k)}]"
        if flat:
            return "{ " + ", ".join(f"{key(k)} = {lua(x)}" for k, x in items) + " }"
        return "{\n" + "".join(f"{pad}  {key(k)} = {lua(x, indent + 1)},\n" for k, x in items) + pad + "}"
    raise TypeError(type(v))


def write(path: Path, var: str, data, build: str):
    head = (
        "-- Generated by tools/build_data.py from wowforevertalents.com"
        f" (Forever client build {build}). Do not edit by hand.\n"
        "local _, ns = ...\n"
    )
    path.write_text(head + f"ns.{var} = " + lua(data) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    refresh = "--refresh" in sys.argv
    builds = set()

    classes = {}
    for c in CLASSES:
        page = fetch(f"/abilities/{c}/", refresh)
        builds.add(build_info(page))
        classes[c.upper()] = parse_class(page)
        print(f"{c:10s} {len(classes[c.upper()]):3d} spells, {sum(len(s['ranks']) for s in classes[c.upper()]):3d} ranks")

    profs = {}
    for p in PROFESSIONS:
        page = fetch(f"/professions/{p}/", refresh)
        builds.add(build_info(page))
        d = parse_profession(page)
        profs[d["name"]] = d
        print(f"{d['name']:15s} {len(d['recipes']):4d} recipes")

    build = ", ".join(sorted(builds - {"?"})) or "?"
    write(ROOT / "Data" / "Classes.lua", "ClassData", classes, build)
    write(ROOT / "Data" / "Professions.lua", "ProfessionData", profs, build)


if __name__ == "__main__":
    main()
