#!/usr/bin/env python3
"""Sync PrepPlanner/Localizable.xcstrings with the strings the compiler extracted in the last build.

Usage:
    python3 scripts/sync_strings.py [path/to/Objects-normal/arm64]

Keeps existing translations, adds new keys, removes keys that are no longer used,
and lists keys that still need an Uzbek translation.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "PrepPlanner", "Localizable.xcstrings")
DEFAULT_OBJ = os.path.expanduser(
    "~/Library/Developer/Xcode/DerivedData/PrepPlanner-cli/Obj/PrepPlanner.build/"
    "Debug/PrepPlanner.build/Objects-normal/arm64"
)


def specifiers(s):
    return sorted(re.sub(r"%\d+\$", "%", m) for m in re.findall(r"%(?:\d+\$)?(?:lld|@|%|lf)", s))


def main():
    obj = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OBJ
    extracted = {}
    for path in glob.glob(os.path.join(obj, "*.stringsdata")):
        for entries in json.load(open(path)).get("tables", {}).values():
            for e in entries:
                extracted.setdefault(e["key"], e.get("comment", ""))
    if not extracted:
        sys.exit(f"No .stringsdata files found in {obj}. Build the app first.")

    catalog = json.load(open(CATALOG))
    old = catalog.get("strings", {})
    strings, missing, mismatched = {}, [], []
    for key in sorted(extracted):
        entry = old.get(key, {})
        if extracted[key]:
            entry["comment"] = extracted[key]
        uz = entry.get("localizations", {}).get("uz", {}).get("stringUnit", {}).get("value")
        if uz is None and entry.get("shouldTranslate") is not False:
            missing.append(key)
        elif uz is not None and specifiers(uz) != specifiers(key):
            mismatched.append(key)
        strings[key] = entry
    removed = sorted(set(old) - set(extracted))
    catalog["strings"] = strings
    with open(CATALOG, "w") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")

    print(f"{len(strings)} keys, {len(missing)} missing Uzbek, {len(removed)} removed")
    for key in missing:
        print("  missing:", key)
    for key in mismatched:
        print("  format mismatch:", key)


if __name__ == "__main__":
    main()
