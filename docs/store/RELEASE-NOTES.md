KDEScreenConf 0.5.1 adds a KDE Store-ready widget package and a friendly missing-backend screen.

Downloads:
- **KDEScreenConf-0.5.1.plasmoid**: architecture-independent Plasma 6 widget only. This is the file to upload to KDE Store.
- **KDEScreenConf-0.5.1-linux-x86_64.tar.gz**: companion Rust backend, KWin integration, widget, and user-service installer. Extract and run `./scripts/install.sh --prebuilt` as your desktop user. Built on Ubuntu 26.04; build from source on incompatible distributions or other architectures.
- `.sha256` files provide checksums.

The Store package does not install the companion. [Installation instructions](https://github.com/DBCane46/KDEScreenConf#installation).

Includes Ctrl+Meta-only drag previews/snapping, non-overlapping freeform zones, a global 2-pixel default gap, additional presets, explicit application-assignment restore, and single-screen per-virtual-desktop profiles. Normal opening/dragging does not reposition windows.

[Store listing text and submission checklist](https://github.com/DBCane46/KDEScreenConf/blob/main/docs/store/PUBLISHING.md) and synthetic UI screenshots are included in the repository. No KDE Store submission has been made.

Validation: Rust, JavaScript, Python/package, and offscreen QML tests; QML lint; isolated installation with kpackagetool6. Physical single-screen docking remains unverified. Modifier-assisted dragging requires KDE Wayland keystate v5; keyboard placement is available as fallback.
