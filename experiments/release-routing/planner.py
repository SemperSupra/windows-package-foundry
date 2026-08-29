#!/usr/bin/env python3
import json, sys
from pathlib import Path

ROUTES = {
    "portable-zip": {
        "projectionBackend": "jreleaser",
        "reasonCodes": ["artifact.portable-zip", "projection.generic-backend-selected"],
    },
    "vsix": {
        "projectionBackend": None,
        "reasonCodes": ["artifact.vsix", "projection.generic-backend-not-required", "venue.native-packaging-authoritative"],
    },
}

VENUES = {
    "scoop-local": ("jreleaser+scoop-template", "scoop-json"),
    "winget-local": ("jreleaser+winget-template", "winget"),
    "chocolatey-local": ("jreleaser+chocolatey-template", "choco"),
    "vscode": ("venue-native", "vsix-manifest"),
}

def plan(model):
    artifact_type = model["artifacts"][0]["type"]
    if artifact_type not in ROUTES:
        raise SystemExit(f"unsupported artifact type: {artifact_type}")
    route = ROUTES[artifact_type]
    venues = {}
    for target in model.get("targets", []):
        venue = target["venue"]
        if venue not in VENUES:
            raise SystemExit(f"unsupported venue: {venue}")
        adapter, validator = VENUES[venue]
        if artifact_type == "vsix" and venue != "vscode":
            raise SystemExit("vsix may only route to the venue-native vscode adapter in this RDTE")
        if artifact_type == "portable-zip" and venue == "vscode":
            raise SystemExit("portable-zip may not route to vscode")
        venues[venue] = {"adapter": adapter, "nativeValidator": validator}
    return {
        "schemaVersion": 1,
        "status": "rdte",
        "authority": "non-authoritative",
        "publicationAuthorized": False,
        "product": model["release"]["product"],
        "version": model["release"]["version"],
        "artifactClass": artifact_type,
        "projectionBackend": route["projectionBackend"],
        "venues": venues,
        "reasonCodes": route["reasonCodes"],
    }

def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: planner.py MODEL.json PLAN.json")
    model = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    result = plan(model)
    Path(sys.argv[2]).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
