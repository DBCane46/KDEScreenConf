# KDEScreenConf

<img src="design/kdescreenconf.svg" alt="KDEScreenConf icon" width="96">

[![Checks](https://github.com/DBCane46/KDEScreenConf/actions/workflows/ci.yml/badge.svg)](https://github.com/DBCane46/KDEScreenConf/actions/workflows/ci.yml)

Plasma 6 window-zone widget with a Rust/D-Bus backend. No cloud service is involved.

## Installation

Requires KDE Plasma 6 on Linux, `kscreen-doctor`, `plasmawindowed`, Plasma5Support, GNU `timeout`, `python3`, systemd user services, `qdbus6`, and `kwriteconfig6`. Run the installer as your desktop user, without sudo.

### Build from source

Install Rust/Cargo (tested with Rust 1.93.1), then:

```sh
git clone https://github.com/DBCane46/KDEScreenConf.git
cd KDEScreenConf
./scripts/install.sh
```

For an offline rebuild with cached dependencies, use `./scripts/install.sh --offline`.

### Prebuilt Linux x86-64 release

Download and extract the archive from [Releases](https://github.com/DBCane46/KDEScreenConf/releases), then run `./scripts/install.sh --prebuilt` inside the extracted directory. The initial binary is built on Ubuntu 26.04; source installation is recommended on distributions with older system libraries.

### Upgrading from Kadr

The installer copies legacy `kadr/profiles.json` into `kdescreenconf/profiles.json` only if the destination does not exist. It preserves the original file, disables the old service/script, and replaces existing Kadr widgets. Legacy files are retained for recovery.

## Usage

 Add **KDEScreenConf** through Plasma's **Add Widgets** menu. The user service starts with the graphical session. You can also open KDEScreenConf from the application launcher.

The widget detects Mobile (laptop), Wide desk (laptop + one external), Dual desk (laptop + two external), and Workstation (three 4K + two other external screens). Other combinations receive a separate Custom setup profile. Each exact set of enabled monitor identities gets its own persistent profile, even when two sets share the same friendly name.

Choose a preset for each monitor: full, halves, thirds, wide centre, or quarters. Changes save immediately to `~/.config/kdescreenconf/profiles.json`. All new monitors initially use halves. Reconnecting a known set selects its saved layouts after three consistent observations (roughly 4–6 seconds). Layout selection persists across logins and restarts.

- Ctrl+Meta+1…9: place the active window in a numbered zone on its current monitor.
- Ctrl+Meta+0: restore its previous geometry, clamped to the current monitor.
- Enabled switch: pause/resume KDEScreenConf placement.

KWin applies normalized zones in logical coordinates within the usable screen area, respecting panels and display scaling. Each monitor has a small placement strip at the top of its usable area. Drag a window toward the strip to expand a thumbnail of that monitor’s layout, then release on a numbered thumbnail to place the window. The helper also works when full-screen drag overlays are disabled. Its visibility can be toggled in the widget.

Drag a window to show its monitor’s zones, then release over a zone to snap. Ctrl+Meta+D skips snapping for the current drag. The widget can disable drag overlays independently of keyboard placement. Escape-cancelled moves are ignored when KWin restores the starting geometry.

Choose **Edit zones…** under a monitor to add, move, resize, or delete 1–9 rectangular zones. Opening the editor identifies the physical screen for about five seconds with a green border, connector name, and resolution. Press **Identify screen** to show it again. Percentage fields provide precise coordinates. Zones must be at least 5% wide and high and stay inside the screen. Zones cannot overlap: dragging, resizing, and percentage edits reject collisions, and the backend validates every saved layout. **Add zone** splits the selected zone without overlap; touching edges are allowed. Older invalid custom layouts are retained on disk but replaced with a safe two-column layout for placement until you edit and save them. **Save layout** persists and selects the custom layout for that monitor/profile; **Cancel** discards edits. Switching to a preset retains your custom layout. Saving is rejected if the monitor combination changed while editing. Existing version-1 profiles migrate without losing preset selections.

KDEScreenConf does not replace native Meta+T tiles or restore application windows across logins. It does not change monitor resolutions, positions, or power state.

## Monitor identity

EDID bytes from `/sys/class/drm` identify hardware when available. Connector names are the fallback. Duplicate EDIDs are distinguished by connector. With missing or duplicate EDIDs, changing dock ports can therefore create a new profile. The widget recognizes the enabled outputs, so a connected but disabled laptop display is excluded.

## Commands

```
kdescreenconf status
kdescreenconf detect
kdescreenconf identify HDMI-A-1
kdescreenconf set HDMI-A-1 quarters
kdescreenconf pause
kdescreenconf resume
systemctl --user status kdescreenconf
```

## Development

```
cargo test --offline
node tests/kwin.test.cjs
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
cargo build --release --offline
/usr/lib/qt6/bin/qmllint widget/contents/ui/main.qml
```

Cargo dependencies are pinned in Cargo.lock. QML tests and lint require Qt 6 test/development tools and KDE QML modules. CI runs the Rust, geometry, and migration tests; QML and compositor integration are tested locally in Plasma.

This is an early release, tested on Plasma 6 Wayland with a five-monitor setup. Hardware-specific docking and mixed-DPI behavior should be checked on your own setup.

To disable: turn off **KDEScreenConf window zones** in System Settings → Window Management → KWin Scripts, remove the widget, and run `systemctl --user disable --now kdescreenconf.service`. Your saved profiles remain available.

## License

MIT. This is an independent project and is not an official KDE application.
