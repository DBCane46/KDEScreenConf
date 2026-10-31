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

Choose a preset for each monitor: full, halves, thirds, wide centre, four equal quarters, or a left half with two stacked right quarters. Changes save immediately to `~/.config/kdescreenconf/profiles.json`. All new monitors initially use halves. Reconnecting a known set selects its saved layouts after three consistent observations (roughly 4–6 seconds). Layout selection persists across logins and restarts.

- Ctrl+Meta+1…9: place the active window in a numbered zone on its current monitor.
- Ctrl+Meta+0: restore its previous geometry, clamped to the current monitor.
- Enabled switch: pause/resume KDEScreenConf placement.

KWin applies normalized zones in logical coordinates within the usable screen area, respecting panels and display scaling. The placement helper appears only during Ctrl+Meta dragging; no persistent screen label is shown. Drag toward the top centre of a monitor to expand a thumbnail of its layout, then release on a numbered thumbnail to place the window. The helper also works when full-screen drag overlays are disabled. Its visibility can be toggled in the widget.

Opening windows and ordinary dragging never trigger KDEScreenConf placement or show zones. **Hold Ctrl+Meta while dragging** to show the available zones, then release the mouse over a highlighted zone to snap. Releasing the modifiers before dropping hides the zones and cancels placement. Ctrl+Meta+D cancels snapping for the current drag. Modifier detection requires KDE Wayland keystate protocol version 5; when unavailable, use Ctrl+Meta+1…9 for explicit keyboard placement. Escape-cancelled moves are ignored when KWin restores the starting geometry.

Choose **Edit zones…** under a monitor to add, move, resize, or delete 1–9 rectangular zones. Opening the editor identifies the physical screen for about five seconds with a green border, connector name, and resolution. Press **Identify screen** to show it again. Percentage fields provide precise coordinates. Zones must be at least 5% wide and high and stay inside the screen. Zones cannot overlap: dragging, resizing, and percentage edits reject collisions, and the backend validates every saved layout. **Add zone** fills the largest available empty rectangle without changing existing zones; if none meets the minimum size, shrink or delete a zone first; touching edges are allowed. Older invalid custom layouts are retained on disk but replaced with a safe two-column layout for placement until you edit and save them. **Save layout** persists and selects the custom layout for that monitor/profile; **Cancel** discards edits. Switching to a preset retains your custom layout. Saving is rejected if the monitor combination changed while editing. Existing version-1 profiles migrate without losing preset selections.

The global **Gap between zones** setting defaults to **2 logical pixels** and applies to every monitor/profile. It is the total gap between adjacent zones (not an inset on each side); display scaling converts logical pixels to physical pixels.

Snapping an application with the helper, drag overlay, or keyboard saves its monitor and zone in the current profile. Assignments are retained but never applied automatically. Press Ctrl+Meta+R to explicitly apply saved positions for the active profile. Matching uses the desktop application ID (falling back to window class), window role, and window title. This lets Tasks, Mail and Calendar from the same application keep separate positions. Titles are saved locally in your profile; changing a title can require teaching that window again. Windows with identical application, role and title share an assignment. Removed zones are skipped. Free moves are left alone until the next profile switch or login. KDEScreenConf does not launch applications itself: KDE session restoration or your autostart settings open them. Place each application once to teach its assignment.

KDEScreenConf does not replace native Meta+T tiles. Keep KDE Display Configuration/KScreen enabled: it still controls resolution, scaling, output positions and enabled displays; KDEScreenConf uses `kscreen-doctor` for detection.

## Single-screen virtual desktops

With exactly one enabled monitor, each KDE virtual desktop has independent layouts and application assignments. Switch desktops and choose a preset or edit zones in the widget; its heading shows the active desktop name. Snap applications once on each desktop to teach their placements. New desktop profiles inherit the original single-monitor layout, with empty assignments. The original profile remains intact. Profiles use stable desktop IDs, so renaming or reordering desktops preserves settings. Deleted desktops retain their saved profiles but newly created desktop IDs start fresh.

When you explicitly apply saved positions with Ctrl+Meta+R, only windows belonging to the current desktop are restored. Windows on all desktops follow the active desktop's assignment. With two or more enabled monitors, layouts and assignments remain shared across virtual desktops, as before. The global gap remains shared everywhere. Editor saves and queued assignments are rejected if their desktop profile is no longer active.

## Monitor identity

EDID bytes from `/sys/class/drm` identify hardware when available. Connector names are the fallback. Duplicate EDIDs are distinguished by connector. With missing or duplicate EDIDs, changing dock ports can therefore create a new profile. The widget recognizes the enabled outputs, so a connected but disabled laptop display is excluded.

## Commands

```
kdescreenconf status
kdescreenconf detect
kdescreenconf gap 2
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
node tests/assignments.test.cjs
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
cargo build --release --offline
/usr/lib/qt6/bin/qmllint widget/contents/ui/main.qml
```

Cargo dependencies are pinned in Cargo.lock. QML tests and lint require Qt 6 test/development tools and KDE QML modules. CI runs the Rust, geometry, and migration tests; QML and compositor integration are tested locally in Plasma.

This is an early release, tested on Plasma 6 Wayland with a five-monitor setup. Hardware-specific docking and mixed-DPI behavior should be checked on your own setup.

To disable: turn off **KDEScreenConf window zones** in System Settings → Window Management → KWin Scripts, remove the widget, and run `systemctl --user disable --now kdescreenconf.service`. Your saved profiles remain available.

## License

MIT. This is an independent project and is not an official KDE application.
