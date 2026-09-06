#!/usr/bin/env bash
# Official release downloads; keep the workflow version aligned with project.godot.
set -euo pipefail
version="${GODOT_VERSION:?GODOT_VERSION is required}"
install_dir="${RUNNER_TEMP:?RUNNER_TEMP is required}/godot-${version}"
archive="Godot_v${version}-stable_linux.x86_64.zip"
base_url="https://github.com/godotengine/godot-builds/releases/download/${version}-stable"
mkdir -p "$install_dir"
cd "$install_dir"
curl --fail --location --retry 3 --output "$archive" "$base_url/$archive"
curl --fail --location --retry 3 --output SHA512-SUMS.txt "$base_url/SHA512-SUMS.txt"
awk -v archive="$archive" '$2 == archive {print}' SHA512-SUMS.txt > selected-checksum.txt
[[ -s selected-checksum.txt ]]
sha512sum --check selected-checksum.txt
unzip -q "$archive"
chmod +x "Godot_v${version}-stable_linux.x86_64"
ln -sf "Godot_v${version}-stable_linux.x86_64" godot
printf '%s\n' "$install_dir" >> "${GITHUB_PATH:?GITHUB_PATH is required}"
./godot --headless --audio-driver Dummy --version
