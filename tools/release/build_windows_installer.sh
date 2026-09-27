#!/usr/bin/env bash
# Build the per-user Windows installer for an exported checkpoint executable.
#
# usage: build_windows_installer.sh <MuddsShipyards-<commit>.exe> [output.exe]
#
# The source executable must be a file produced by export_windows_candidate.sh
# (its name carries the seven-character source revision). The full commit is
# resolved from the repository this script lives in; the product version is
# read from project.godot. Writes <output>, <output>.sha256 and
# <output>.installer-result.json (schema_version 1). Compiling never needs a
# clean worktree because it only consumes an already exported artifact.
#
# Optional Authenticode signing (see docs/WINDOWS_CODE_SIGNING.md):
#   MUDDS_INSTALLER_SIGN=pfx              sign with MUDDS_SIGNING_PFX /
#                                         MUDDS_SIGNING_PASSWORD
#   MUDDS_INSTALLER_SIGN=dev-self-signed  UNTRUSTED throwaway certificate, for
#                                         pipeline testing only
# When set, the exported EXE is signed in place before it is embedded, the
# embedded uninstaller is signed by makensis' !uninstfinalize hook, and the
# finished installer is signed and verified. Verification JSON is written to
# <output>.signing-result.json and <source>.signing-result.json.
# MUDDS_SIGNING_TIMESTAMP_URL adds an RFC 3161 timestamp to every signature.
set -euo pipefail

die() {
	printf 'build-windows-installer: ERROR: %s\n' "$*" >&2
	exit 1
}

if (( $# < 1 || $# > 2 )); then
	die "usage: $0 <MuddsShipyards-<commit>.exe> [output.exe]"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" \
	|| die "cannot resolve script directory"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" \
	|| die "script is not inside a Git worktree"
NSI="$SCRIPT_DIR/installer/mudds_shipyards.nsi"
[[ -f "$NSI" ]] || die "installer script missing at $NSI"
command -v makensis >/dev/null 2>&1 || die "makensis (NSIS 3) is not installed"

source_exe="$1"
[[ -f "$source_exe" ]] || die "source executable not found: $source_exe"
source_exe="$(cd -- "$(dirname -- "$source_exe")" && pwd -P)/$(basename -- "$source_exe")"
source_name="$(basename -- "$source_exe")"
if [[ ! "$source_name" =~ ^MuddsShipyards-([0-9a-f]{7})\.exe$ ]]; then
	die "source executable must be named MuddsShipyards-<7 hex>.exe (got $source_name)"
fi
short_commit="${BASH_REMATCH[1]}"

full_commit="${MUDDS_INSTALLER_FULL_COMMIT:-}"
if [[ -z "$full_commit" ]]; then
	full_commit="$(git -C "$REPO_ROOT" rev-parse --verify "${short_commit}^{commit}" 2>/dev/null)" \
		|| die "source revision $short_commit is not a commit in $REPO_ROOT"
fi
[[ "$full_commit" =~ ^[0-9a-f]{40}$ ]] || die "full commit must be forty hex characters"
[[ "$full_commit" == "$short_commit"* ]] || die "full commit does not start with $short_commit"

product_version="$(sed -n 's/^config\/version="\([0-9][0-9.]*\)"$/\1/p' "$REPO_ROOT/project.godot" | head -n 1)"
[[ "$product_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
	|| die "project.godot config/version is not a three-part version (got '${product_version}')"

output="${2:-$(dirname -- "$source_exe")/MuddsShipyards-${short_commit}-setup.exe}"
case "$output" in
	*/*) output_dir="$(cd -- "$(dirname -- "$output")" && pwd -P)" || die "output directory does not exist" ;;
	*) output_dir="$(pwd -P)" ;;
esac
output="$output_dir/$(basename -- "$output")"
[[ "$output" == *.exe ]] || die "output must end in .exe"
[[ "$output" != "$source_exe" ]] || die "output must differ from the source executable"

sign_mode="${MUDDS_INSTALLER_SIGN:-}"
signing_label="unsigned"
sign_flags=()
signing_defines=()
SIGN_SCRIPT="$SCRIPT_DIR/sign_windows_artifacts.sh"
case "$sign_mode" in
	"") ;;
	pfx) signing_label="authenticode-pfx" ;;
	dev-self-signed)
		signing_label="dev-self-signed-UNTRUSTED"
		sign_flags=(--dev-self-signed) ;;
	*) die "MUDDS_INSTALLER_SIGN must be empty, 'pfx' or 'dev-self-signed' (got '$sign_mode')" ;;
esac
if [[ -n "$sign_mode" ]]; then
	[[ -x "$SIGN_SCRIPT" ]] || die "signing requested but $SIGN_SCRIPT is missing"
	case "$SIGN_SCRIPT" in
		*\'*|*\"*) die "signing script path must not contain quotes" ;;
	esac
	# The exported EXE is the payload players run, so it is signed before it is
	# embedded; its verification record is written after compilation.
	"$SIGN_SCRIPT" "${sign_flags[@]}" --sign-in-place "$source_exe" \
		|| die "signing the exported executable failed"
	signing_defines=(
		"-DSIGNING_LABEL=$signing_label"
		"-DUNINSTALL_SIGN_COMMAND=\"$SIGN_SCRIPT\" ${sign_flags[*]} --sign-in-place"
	)
fi

log="$output.makensis.log"
makensis -V2 -WX \
	"-DSOURCE_EXE=$source_exe" \
	"-DSHORT_COMMIT=$short_commit" \
	"-DFULL_COMMIT=$full_commit" \
	"-DPRODUCT_VERSION=$product_version" \
	"-DOUTPUT_FILE=$output" \
	"${signing_defines[@]}" \
	"$NSI" > "$log" 2>&1 || { cat "$log" >&2; die "makensis failed (log: $log)"; }
[[ -s "$output" ]] || die "makensis produced no output at $output"

signing_result=""
source_signing_result=""
if [[ -n "$sign_mode" ]]; then
	signing_result="$output.signing-result.json"
	source_signing_result="$source_exe.signing-result.json"
	"$SIGN_SCRIPT" "${sign_flags[@]}" --result "$signing_result" "$output" \
		|| die "signing or verifying the installer failed (see $signing_result)"
	"$SIGN_SCRIPT" "${sign_flags[@]}" --verify-only --result "$source_signing_result" "$source_exe" \
		|| die "verifying the signed executable failed (see $source_signing_result)"
fi

source_sha256="$(sha256sum "$source_exe" | cut -d' ' -f1)"
installer_sha256="$(sha256sum "$output" | cut -d' ' -f1)"
installer_bytes="$(stat -c %s "$output")"
source_bytes="$(stat -c %s "$source_exe")"
makensis_version="$(makensis -VERSION 2>/dev/null | tr -d '\r\n')"
printf '%s  %s\n' "$installer_sha256" "$(basename -- "$output")" > "$output.sha256"
python3 - "$output.installer-result.json" \
	"$source_exe" "$source_sha256" "$source_bytes" "$short_commit" "$full_commit" \
	"$product_version" "$output" "$installer_sha256" "$installer_bytes" "$makensis_version" \
	"$signing_label" "$signing_result" "$source_signing_result" <<'PY'
import json, sys
(
    path, source_exe, source_sha256, source_bytes, short_commit, full_commit,
    product_version, output, installer_sha256, installer_bytes, makensis_version,
    signing_label, signing_result, source_signing_result,
) = sys.argv[1:]
record = {
    "schema_version": 1,
    "installer_kind": "nsis-per-user",
    "signing": signing_label,
    "product_version": product_version,
    "build_label": f"{product_version}+{short_commit}",
    "source_commit": full_commit,
    "source_exe": source_exe,
    "source_exe_bytes": int(source_bytes),
    "source_exe_sha256": source_sha256,
    "installer": output,
    "installer_bytes": int(installer_bytes),
    "installer_sha256": installer_sha256,
    "makensis_version": makensis_version,
    "native_verification": "NOT_RUN",
}
if signing_result:
    record["signing_result"] = signing_result
    record["source_signing_result"] = source_signing_result
    # A signature from a certificate Windows has not been shown to trust is
    # never reported as trusted signing.
    record["trusted_signing_claimed"] = False
with open(path, "w", encoding="utf-8") as handle:
    json.dump(record, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
printf 'build-windows-installer: wrote %s (%s bytes, sha256 %s)\n' "$output" "$installer_bytes" "$installer_sha256"
