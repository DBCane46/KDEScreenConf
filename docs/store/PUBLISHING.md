# Publishing KDEScreenConf on KDE Store

## Release assets

- Upload `KDEScreenConf-0.5.1.plasmoid` under **Plasma 6 Widgets**. It is a ZIP with `metadata.json` at the root, QML, bundled icon, and MIT license; no compiled program or install script is inside it.
- Keep `KDEScreenConf-0.5.1-linux-x86_64.tar.gz` on GitHub Releases as the separate companion installer. Do not upload that archive as the Store widget download.
- SHA-256 files accompany both packages.
- `LISTING.md` contains copy-ready description, dependencies, license, and links.
- `backend-missing.png` and `layout-editor.png` are rendered UI previews with synthetic data, suitable for the listing; they contain no private desktop content. Add a screenshot of Ctrl+Meta dragging on an empty/demo desktop if desired.

## Submission

1. Sign in to https://store.kde.org with your account and create a new product/listing.
2. Choose the Plasma 6 widget category and copy the listing details from `LISTING.md`.
3. Upload the `.plasmoid` as the installable file, specifying its version and Plasma 6 compatibility. Follow the current form labels; they may change.
4. Add the screenshots and source/support links. Keep the companion requirement prominent.
5. Preview the listing, verify its installation link, then submit/publish through your account.
6. Test the Store download on a clean user account: the widget should show "Backend not installed" until the companion is installed. Then it should reconnect without needing removal/re-addition.

The Store submission itself has not been performed. A Store installation does not bootstrap the companion. KDE guidance for compiled components: https://develop.kde.org/docs/plasma/widget/c-api/

## Rebuild / validate

```sh
python3 scripts/package-widget.py
python3 -m unittest discover -s tests -p 'test_*.py'
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
./scripts/package.sh --offline  # omit --offline if dependencies are not cached
```

The `.plasmoid` is architecture-independent. The companion archive is architecture-specific. Always use matching versions, update the version fields in Cargo.toml and both metadata.json files, and regenerate Cargo.lock before publishing a new release.

The icon in the widget is bundled. The package ID remains `org.kde.kdescreenconf` for compatibility with existing installations; this is not a claim of KDE affiliation.
