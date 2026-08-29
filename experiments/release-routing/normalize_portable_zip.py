#!/usr/bin/env python3
"""Normalize JReleaser portable-ZIP projections from Foundry release semantics.

This is deliberately product-agnostic. Product facts come only from the normalized
release model. It corrects assumptions in JReleaser's generic BINARY templates that
a ZIP has one root directory and a bin/ executable layout.
"""
import json, re, sys
from pathlib import Path


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: normalize_portable_zip.py MODEL.json SCOOP.json WINGET_INSTALLER.yaml")
    model_path, scoop_path, winget_path = map(Path, sys.argv[1:])
    model = json.loads(model_path.read_text(encoding="utf-8"))
    artifact = model["artifacts"][0]
    if artifact["type"] != "portable-zip":
        raise SystemExit("normalizer only accepts portable-zip")
    entry = artifact["entryPoints"][0]
    commands = model.get("semantics", {}).get("commands", [])
    if len(commands) != 1:
        raise SystemExit("RDTE normalizer requires exactly one command mapping")
    alias = commands[0]["name"]
    if commands[0]["path"] != entry:
        raise SystemExit("command path and artifact entry point disagree")

    scoop = json.loads(scoop_path.read_text(encoding="utf-8"))
    scoop.pop("extract_dir", None)
    scoop.pop("env_add_path", None)
    scoop["bin"] = [[entry, alias]]
    scoop_path.write_text(json.dumps(scoop, indent=4) + "\n", encoding="utf-8")

    text = winget_path.read_text(encoding="utf-8")
    text, n1 = re.subn(r"(?m)^(\s*- RelativeFilePath:)\s*.*$", rf"\1 {entry}", text, count=1)
    text, n2 = re.subn(r"(?m)^(\s*PortableCommandAlias:)\s*.*$", rf"\1 {alias}", text, count=1)
    if n1 != 1 or n2 != 1:
        raise SystemExit("expected one WinGet nested installer path and alias")
    winget_path.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
