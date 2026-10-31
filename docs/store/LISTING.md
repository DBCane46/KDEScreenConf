# KDE Store listing text

Name: KDEScreenConf
Category: Plasma 6 Widgets
Version: 0.5.1
License: MIT
Source / homepage: https://github.com/DBCane46/KDEScreenConf
Support / issues: https://github.com/DBCane46/KDEScreenConf/issues

## Short description

Window zones and persistent monitor layouts for Plasma 6. Hold Ctrl+Meta while dragging to place windows. Requires the separately installed KDEScreenConf companion.

## Description

KDEScreenConf provides a visual zone editor and remembers layouts for different monitor combinations. With one active monitor, each virtual desktop has independent layouts and application assignments.

- Normal window opening and dragging remain untouched.
- Hold Ctrl+Meta during a drag to preview zones; release the mouse to snap.
- Presets include two columns, three columns, four equal quarters, and a left half with two stacked right quarters.
- Create custom rectangular zones without overlap; new zones use free space.
- A global gap defaults to 2 logical pixels.
- Ctrl+Meta+1…9 places a window; Ctrl+Meta+0 restores its previous geometry.
- Ctrl+Meta+R explicitly applies saved application assignments. Nothing is restored automatically.
- No persistent screen labels. Screen identification is available while editing.

IMPORTANT: The Store download contains only the widget. You must separately install the Rust backend, KWin script, and user service. The widget displays an installation link when these are missing. It never downloads or runs an installer automatically.

Installation: https://github.com/DBCane46/KDEScreenConf#installation
Companion releases: https://github.com/DBCane46/KDEScreenConf/releases

Requirements: KDE Plasma 6 on Linux; Plasma5Support QML module; kscreen-doctor; qdbus6; kwriteconfig6; systemd user services; Python 3 and GNU timeout for the companion installer. Ctrl+Meta drag activation requires KDE Wayland keystate protocol version 5. If unavailable, explicit Ctrl+Meta+1…9 placement remains available. X11 drag activation is not supported.

The prebuilt companion is Linux x86-64, built on Ubuntu 26.04; older distributions or other architectures should build from source with Rust/Cargo. See README for dependencies and limitations. Single-screen virtual desktop behavior is covered by automated tests; a physical docking test is still outstanding.

Profiles remain local. Saved application matching includes window titles; it may need reteaching when titles change. KDEScreenConf does not launch applications or replace KDE Display Configuration/KScreen. Independent community project, not an official KDE application.
