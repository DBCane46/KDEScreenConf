#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cargo build --release --locked "$@"
version=$(python3 -c 'import tomllib; print(tomllib.load(open("Cargo.toml","rb"))["package"]["version"])')
arch=$(uname -m)
name="KDEScreenConf-${version}-linux-${arch}"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/$name/bin" dist
cp -R Cargo.toml Cargo.lock README.md LICENSE docs design src widget kwin scripts packaging tests "$stage/$name/"
find "$stage" -type d -name __pycache__ -prune -exec rm -rf {} +
install -m755 target/release/kdescreenconf "$stage/$name/bin/kdescreenconf"
tar -C "$stage" -czf "dist/$name.tar.gz" "$name"
(cd dist && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256")
echo "dist/$name.tar.gz"
