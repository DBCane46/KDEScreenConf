#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="source"
cargo_flags=(--locked)
for arg in "$@"; do
    case "$arg" in
        --offline) cargo_flags+=(--offline) ;;
        --prebuilt) mode="prebuilt" ;;
        *) echo "Usage: $0 [--offline | --prebuilt]" >&2; exit 2 ;;
    esac
done
for tool in python3 systemctl qdbus6 kwriteconfig6 kscreen-doctor timeout; do
    command -v "$tool" >/dev/null || { echo "Missing dependency: $tool" >&2; exit 1; }
done
if [[ "$mode" == source ]]; then
    cargo build --release "${cargo_flags[@]}"
    binary=target/release/kdescreenconf
else
    binary=bin/kdescreenconf
    [[ -x "$binary" ]] || { echo "Prebuilt binary not found" >&2; exit 1; }
fi
python3 scripts/migrate_profiles.py
install -Dm755 "$binary" "$HOME/.local/bin/kdescreenconf.new"
mv "$HOME/.local/bin/kdescreenconf.new" "$HOME/.local/bin/kdescreenconf"
install -Dm644 design/kdescreenconf.svg "$HOME/.local/share/icons/hicolor/scalable/apps/kdescreenconf.svg"
install -Dm644 packaging/org.kde.kdescreenconf.desktop "$HOME/.local/share/applications/org.kde.kdescreenconf.desktop"
mkdir -p "$HOME/.local/share/plasma/plasmoids/org.kde.kdescreenconf" "$HOME/.local/share/kwin/scripts/kdescreenconf" "$HOME/.config/systemd/user"
cp -R widget/. "$HOME/.local/share/plasma/plasmoids/org.kde.kdescreenconf/"
cp -R kwin/. "$HOME/.local/share/kwin/scripts/kdescreenconf/"
# KWin caches QML across reloads; include all QML/JS in the entry URL's digest.
python3 - <<'PYINSTALL'
import hashlib,json,pathlib,shutil
source=pathlib.Path("kwin/contents")
dest=pathlib.Path.home()/".local/share/kwin/scripts/kdescreenconf"
digest=hashlib.sha256()
for p in sorted(source.rglob("*")):
    if p.is_file():digest.update(p.relative_to(source).as_posix().encode());digest.update(p.read_bytes())
version=digest.hexdigest()[:12]
version_dir=dest/"contents/versions"/version
shutil.copytree(source,version_dir,dirs_exist_ok=True)
meta=json.loads((dest/"metadata.json").read_text());meta["X-Plasma-MainScript"]="versions/"+version+"/ui/main.qml"
(dest/"metadata.json").write_text(json.dumps(meta,indent=2)+"\n")
PYINSTALL
cat > "$HOME/.config/systemd/user/kdescreenconf.service" <<'SERVICE'
[Unit]
Description=KDEScreenConf monitor profile service
After=graphical-session.target
PartOf=graphical-session.target
[Service]
ExecStart=%h/.local/bin/kdescreenconf daemon
Restart=on-failure
RestartSec=5
[Install]
WantedBy=graphical-session.target
SERVICE
if [[ -f "$HOME/.config/systemd/user/kadr.service" ]]; then
    systemctl --user disable --now kadr.service
    kwriteconfig6 --file kwinrc --group Plugins --key kadrEnabled false
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript kadr || true
fi
systemctl --user daemon-reload
systemctl --user enable kdescreenconf.service
systemctl --user restart kdescreenconf.service
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript kdescreenconf || true
kwriteconfig6 --file kwinrc --group Plugins --key kdescreenconfEnabled true
entry=$(python3 -c 'import json,pathlib; p=pathlib.Path.home()/".local/share/kwin/scripts/kdescreenconf"; print(p/"contents"/json.loads((p/"metadata.json").read_text())["X-Plasma-MainScript"])')
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadDeclarativeScript "$entry" kdescreenconf
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
# Replace an existing Kadr panel/desktop widget, without adding one on fresh installs.
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var cs = panels().concat(desktops());
for (var i=0; i<cs.length; i++) {
    var ws=cs[i].widgets(); var old=[]; var present=false;
    for(var j=0;j<ws.length;j++){ if(ws[j].type==="org.kde.kadr")old.push(ws[j]); if(ws[j].type==="org.kde.kdescreenconf")present=true; }
    if(old.length && !present)cs[i].addWidget("org.kde.kdescreenconf");
    for(var j=0;j<old.length;j++)old[j].remove();
}' || echo "Add KDEScreenConf from Plasma’s Add Widgets menu."
echo "KDEScreenConf installed. Add its widget to your panel or open it from the application launcher."
