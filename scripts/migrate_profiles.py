#!/usr/bin/env python3
"""Copy legacy Kadr profiles once; never replace an existing destination."""
import json
import os
from pathlib import Path


def migrate(config_root: Path) -> bool:
    old = config_root / "kadr" / "profiles.json"
    new = config_root / "kdescreenconf" / "profiles.json"
    if not old.is_file() or new.exists():
        return False
    raw = old.read_bytes()
    document = json.loads(raw)
    if document.get("version") != 1 or not isinstance(document.get("profiles"), dict):
        raise ValueError("Unrecognized Kadr configuration; original file has been retained")
    new.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation protects a destination created concurrently.
    with new.open("xb") as target:
        target.write(raw)
        target.flush()
        os.fsync(target.fileno())
    return True


if __name__ == "__main__":
    base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    if migrate(base):
        print("Copied Kadr profiles to KDEScreenConf; original profiles retained.")
