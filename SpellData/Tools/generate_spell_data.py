#!/usr/bin/env python3
"""
Generates SpellData/Data/<Flavor>.lua of the DivineWindow addon: every buff/debuff (aura) spell of a game
version, grouped as player class spells or NPC/boss spells.

Source: Blizzard's client database tables, as exported by https://wago.tools (CSV per build).

Usage:
    python3 generate_spell_data.py                 # all flavors, latest build of each
    python3 generate_spell_data.py Retail MOP      # only these flavors
    python3 generate_spell_data.py --list          # show which build each flavor would use
    python3 generate_spell_data.py Retail --build 12.2.0.71234   # pin an exact build

For a new game version: adjust FLAVORS below (product + version prefix), run the script, and
make sure the matching DivineWindow TOC file lists SpellData/Data/<Flavor>.lua.
Downloads are cached in Tools/.cache (delete it to force a fresh download).
"""

import argparse
import csv
import json
import os
import re
import sys
import urllib.request
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON_DIR = os.path.dirname(HERE)
CACHE_DIR = os.path.join(HERE, ".cache")
DATA_DIR = os.path.join(ADDON_DIR, "Data")

BUILDS_URL = "https://wago.tools/api/builds"
CSV_URL = "https://wago.tools/db2/{table}/csv?build={build}"

# Flavor name (= Data/<name>.lua) -> wago.tools product and version prefix to pick the latest build of.
FLAVORS = {
    "Retail": ("wow", "12."),
    "Forever": ("wowf", "1."),
    "MOP": ("wow_classic", "5.5."),
    "CATA": ("wow_classic", "4.4."),
    "WOTLK": ("wow_classic", "3.4."),
    "TBC": ("wow_anniversary", "2.5."),
    "Classic": ("wow_classic_era", "1.15."),
}

# Retail and WoW Forever share the main DivineWindow.toc, so both data files are listed there; each
# file returns straight away on the other game (TOC interface version 1xxxx = Forever), so only the
# matching spell list stays in memory.
SKIP_IF = {
    "Retail": "select(4, GetBuildInfo()) < 100000",   # running WoW Forever
    "Forever": "select(4, GetBuildInfo()) >= 100000", # running retail
}

# Flavors where spells still have ranks ("Rank 7"); later expansions removed them.
RANKED_FLAVORS = {"Classic", "TBC", "WOTLK"}

# ChrClasses IDs, the same on every flavor. ClassMask bit = 1 << (id - 1).
CLASSES = {
    1: "WARRIOR", 2: "PALADIN", 3: "HUNTER", 4: "ROGUE", 5: "PRIEST", 6: "DEATHKNIGHT",
    7: "SHAMAN", 8: "MAGE", 9: "WARLOCK", 10: "MONK", 11: "DRUID", 12: "DEMONHUNTER", 13: "EVOKER",
}

# SpellClassOptions.SpellClassSet ("spell family") -> class ID, used when no skill line gives the class.
SPELL_FAMILY_TO_CLASS = {
    3: 8, 4: 1, 5: 9, 6: 5, 7: 11, 8: 4, 9: 3, 10: 2, 11: 7, 15: 6, 53: 10, 107: 12, 224: 13,
}

# SpellEffect.Effect values that apply an aura (APPLY_AURA, area auras, aura on pet, ...).
AURA_EFFECTS = {6, 35, 65, 119, 128, 129, 143, 174, 202}

SKILL_CATEGORY_CLASS = 7  # SkillLine.CategoryID for class skill lines

ATTR0_PASSIVE = 0x40
ATTR0_HIDDEN = 0x80  # no buff icon / not shown in the combat log

JUNK_NAME = re.compile(
    r"(\bOLD\b|zzOLD|\bDND\b|\bDNT\b|\[DNT\]|\bUNUSED\b|\bTEST\b|\bQA\b|\bdeprecated\b|\bDEBUG\b"
    r"|^Dummy|^Placeholder|^\w+ Aura$|^Unknown|^\d+$)",
    re.IGNORECASE,
)
RANK = re.compile(r"(\d+)")


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def fetch(url, path):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    log("  downloading", url)
    request = urllib.request.Request(url, headers={"User-Agent": "DivineWindow-SpellData-Generator"})
    with urllib.request.urlopen(request, timeout=600) as response, open(path + ".part", "wb") as out:
        while True:
            chunk = response.read(1 << 20)
            if not chunk:
                break
            out.write(chunk)
    os.replace(path + ".part", path)
    return path


def latest_builds():
    path = os.path.join(CACHE_DIR, "builds.json")
    if os.path.exists(path):
        os.remove(path)  # always refresh the build list
    with open(fetch(BUILDS_URL, path), encoding="utf-8") as f:
        builds = json.load(f)

    result = {}
    for flavor, (product, prefix) in FLAVORS.items():
        versions = [b["version"] for b in builds.get(product, []) if b["version"].startswith(prefix)]
        if versions:
            result[flavor] = max(versions, key=lambda v: tuple(int(p) for p in v.split(".")))
    return result


def rows(table, build):
    path = fetch(CSV_URL.format(table=table, build=build), os.path.join(CACHE_DIR, build, table + ".csv"))
    with open(path, encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)


def to_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def build_flavor(flavor, build):
    log(f"{flavor}: build {build}")

    aura_spells = set()
    for row in rows("SpellEffect", build):
        if to_int(row.get("DifficultyID")) == 0 and to_int(row["Effect"]) in AURA_EFFECTS \
                and to_int(row["EffectAura"]) > 0:
            aura_spells.add(to_int(row["SpellID"]))

    hidden = set()
    icons = {}
    for row in rows("SpellMisc", build):
        if to_int(row.get("DifficultyID")) == 0:
            if to_int(row["Attributes_0"]) & (ATTR0_PASSIVE | ATTR0_HIDDEN):
                hidden.add(to_int(row["SpellID"]))
            icons.setdefault(to_int(row["SpellID"]), to_int(row.get("SpellIconFileDataID")))

    class_skill_lines = {to_int(r["ID"]) for r in rows("SkillLine", build)
                         if to_int(r["CategoryID"]) == SKILL_CATEGORY_CLASS}
    skill_line_classes = defaultdict(int)
    for row in rows("SkillRaceClassInfo", build):
        skill = to_int(row["SkillID"])
        if skill in class_skill_lines:
            skill_line_classes[skill] |= to_int(row["ClassMask"])

    spell_class = {}
    for row in rows("SkillLineAbility", build):
        skill = to_int(row["SkillLine"])
        if skill not in class_skill_lines:
            continue
        mask = to_int(row["ClassMask"]) or skill_line_classes.get(skill, 0)
        class_ids = [cid for cid in CLASSES if mask & (1 << (cid - 1))]
        if len(class_ids) == 1:  # skip abilities shared by many classes (racials, generic lines)
            spell_class[to_int(row["Spell"])] = class_ids[0]

    for row in rows("SpellClassOptions", build):
        spell_id = to_int(row["SpellID"])
        class_id = SPELL_FAMILY_TO_CLASS.get(to_int(row["SpellClassSet"]))
        if class_id and spell_id not in spell_class:
            spell_class[spell_id] = class_id

    rank_text = {to_int(r["ID"]): (r["NameSubtext_lang"] or "").strip() for r in rows("Spell", build)}

    # Ranks share a name; tracking matches by name, so keep one entry per (name, class) with the highest rank.
    entries = {}
    for row in rows("SpellName", build):
        spell_id = to_int(row["ID"])
        name = (row["Name_lang"] or "").strip()
        if spell_id not in aura_spells or spell_id in hidden or not name or JUNK_NAME.search(name):
            continue
        if "\t" in name or "\n" in name:
            continue

        class_id = spell_class.get(spell_id, 0)
        rank = rank_text.get(spell_id, "") if flavor in RANKED_FLAVORS else ""
        rank_number = to_int(RANK.search(rank).group(1)) if rank.lower().startswith("rank") and RANK.search(rank) else 0
        key = (name, class_id)
        current = entries.get(key)
        if current is None or (rank_number, spell_id) > (current[2], current[0]):
            entries[key] = (spell_id, rank if rank_number else "", rank_number, icons.get(spell_id, 0))

    # A name that is a class aura is tracked the same way when an NPC casts it; list it only once.
    class_names = {name for (name, class_id) in entries if class_id}
    return {key: value for key, value in entries.items() if key[1] or key[0] not in class_names}


def lua_long_string(text):
    level = 0
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + text + "]" + eq + "]"


def write_lua(flavor, build, entries):
    # One list sorted by name, so search results come out in alphabetical order without sorting in game.
    ordered = sorted(entries.items(), key=lambda item: (item[0][0].lower(), item[0][0], item[0][1]))
    block = "\n".join(f"{name}\t{spell_id}\t{CLASSES.get(class_id, '')}\t{rank}\t{icon or ''}"
                      for (name, class_id), (spell_id, rank, _, icon) in ordered)

    lines = [
        "-- Generated by Tools/generate_spell_data.py - do not edit by hand.",
        f"-- Source: wago.tools DB2 export, build {build}.",
        "-- spells: one aura per line, sorted by name:",
        "-- name <TAB> spellId <TAB> class token (empty = NPC) <TAB> rank <TAB> icon file ID",
        *([f"if ({SKIP_IF[flavor]}) then return end -- other game, see SKIP_IF in the generator"]
          if flavor in SKIP_IF else []),
        "DivineWindow_SpellData = {",
        f'    build = "{build}",',
        f"    spells = {lua_long_string(block)},",
        "}",
        "",
    ]

    os.makedirs(DATA_DIR, exist_ok=True)
    path = os.path.join(DATA_DIR, flavor + ".lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    class_count = sum(1 for (_, class_id) in entries if class_id)
    log(f"  wrote {os.path.relpath(path, ADDON_DIR)}: {class_count} class auras, "
        f"{len(entries) - class_count} other auras, {os.path.getsize(path) / 1024 / 1024:.1f} MB")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("flavors", nargs="*", help="flavors to generate (default: all): " + ", ".join(FLAVORS))
    parser.add_argument("--build", help="exact build to use (only with a single flavor)")
    parser.add_argument("--list", action="store_true", help="only show the builds that would be used")
    args = parser.parse_args()

    flavors = args.flavors or list(FLAVORS)
    unknown = [f for f in flavors if f not in FLAVORS]
    if unknown:
        parser.error("unknown flavor(s): " + ", ".join(unknown))
    if args.build and len(flavors) != 1:
        parser.error("--build needs exactly one flavor")

    builds = {flavors[0]: args.build} if args.build else latest_builds()
    for flavor in flavors:
        if flavor not in builds:
            log(f"{flavor}: no build found for {FLAVORS[flavor]}")
            continue
        if args.list:
            print(f"{flavor}: {builds[flavor]}")
            continue
        write_lua(flavor, builds[flavor], build_flavor(flavor, builds[flavor]))


if __name__ == "__main__":
    main()
