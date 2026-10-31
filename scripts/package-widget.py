#!/usr/bin/env python3
"""Build the architecture-independent KDE Store widget (no executable backend)."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED, ZipInfo

ROOT = Path(__file__).resolve().parent.parent

def package():
    widget = ROOT / "widget"
    version = json.loads((widget / "metadata.json").read_text())["KPlugin"]["Version"]
    output = ROOT / "dist" / f"KDEScreenConf-{version}.plasmoid"
    output.parent.mkdir(exist_ok=True)
    files = {p.relative_to(widget).as_posix(): p for p in widget.rglob("*") if p.is_file() and (p.suffix in {".qml", ".js", ".svg", ".json"})}
    files["LICENSE"] = ROOT / "LICENSE"
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        for name, path in sorted(files.items()):
            info = ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())
    output.with_suffix(output.suffix + ".sha256").write_text(f"{hashlib.sha256(output.read_bytes()).hexdigest()}  {output.name}\n")
    print(output)
    return output

if __name__ == "__main__":
    package()
