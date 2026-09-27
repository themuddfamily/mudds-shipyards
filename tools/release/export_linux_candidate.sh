#!/usr/bin/env bash
# Export a Linux x86_64 release candidate from an exact, clean source commit.
#
#   tools/release/export_linux_candidate.sh [--dry-run] [MuddsShipyards-<short>.x86_64]
#
# Produces, directly inside builds/linux/:
#   MuddsShipyards-<short>.x86_64                    self-contained binary (embedded PCK)
#   MuddsShipyards-<short>-linux-x86_64.tar.gz       binary + .desktop launcher + icon
#   MuddsShipyards-<short>.x86_64.export-result.json schema_version 1 provenance
#
# Discipline mirrors export_windows_candidate.sh: the worktree must be clean and
# stay on the same commit for the whole export, nothing existing is overwritten,
# artifacts are staged under temporary names and published only after checks.
# Godot runs headless with --audio-driver Dummy under a private XDG profile, so
# the developer's editor settings, caches and saves are never read or written;
# only the export templates are linked in (read-only use).
#
# Environment:
#   GODOT_BIN                     Godot 4.7.1 binary (default: godot)
#   GODOT_EXPORT_TEMPLATES_DIR    directory holding 4.7.1.stable/ (default:
#                                 ${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates)
#   EXPORT_TIMEOUT_SECONDS        wall-clock abort for the Godot export (default 900)
#
# --dry-run validates arguments and prints the planned outputs as JSON without
# requiring a clean tree, running Godot or writing anything.
set -euo pipefail

die() {
	printf 'export-linux-candidate: ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	printf 'usage: %s [--dry-run] [MuddsShipyards-<name>.x86_64]\n' "$0" >&2
	exit 2
}

PRESET_NAME="Linux"
GODOT_TEMPLATE_VERSION="4.7.1.stable"
dry_run=0
positional=()
for argument in "$@"; do
	case "$argument" in
		--dry-run) dry_run=1 ;;
		-h|--help) usage ;;
		--*) printf 'export-linux-candidate: ERROR: unknown option: %s\n' "$argument" >&2; usage ;;
		*) positional+=("$argument") ;;
	esac
done
if (( ${#positional[@]} > 1 )); then
	usage
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" \
	|| die "cannot resolve script directory"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" \
	|| die "script is not inside a Git worktree"
REPO_ROOT="$(cd -- "$REPO_ROOT" && pwd -P)" \
	|| die "cannot resolve repository root"
if [[ "$SCRIPT_DIR" != "$REPO_ROOT/tools/release" ]]; then
	die "script must remain at tools/release inside the worktree"
fi

commit="$(git -C "$REPO_ROOT" rev-parse --verify 'HEAD^{commit}' 2>/dev/null)" \
	|| die "HEAD does not resolve to an exact commit"
if [[ ! "$commit" =~ ^[0-9a-f]{40,64}$ ]]; then
	die "HEAD resolved to an invalid commit ID"
fi
short_commit="${commit:0:7}"

output_basename="${positional[0]:-MuddsShipyards-${short_commit}.x86_64}"
if [[ "$output_basename" == */* || "$output_basename" == "." || "$output_basename" == ".." ]]; then
	die "output must be a basename directly inside builds/linux"
fi
if [[ "$output_basename" != *.x86_64 || "$output_basename" == ".x86_64" ]]; then
	die "output must use the .x86_64 suffix"
fi
if [[ ! "$output_basename" =~ ^[A-Za-z0-9._-]+$ ]]; then
	die "output basename may only contain letters, digits, dot, dash and underscore"
fi
stem="${output_basename%.x86_64}"
package_dir_name="$stem"
tarball_basename="${stem}-linux-x86_64.tar.gz"
result_basename="${output_basename}.export-result.json"
desktop_basename="mudds-shipyards.desktop"
icon_basename="mudds-shipyards.png"
installer_basename="install-desktop-entry.sh"
build_root="$REPO_ROOT/builds/linux"

templates_dir="${GODOT_EXPORT_TEMPLATES_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates}"
godot_bin="${GODOT_BIN:-godot}"
timeout_seconds="${EXPORT_TIMEOUT_SECONDS:-900}"
if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
	die "EXPORT_TIMEOUT_SECONDS must be a positive integer"
fi

dirty_state="$(
	git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all
)" || die "cannot inspect worktree state"

if (( dry_run == 1 )); then
	python3 - "$commit" "$short_commit" "$build_root" "$output_basename" \
		"$tarball_basename" "$result_basename" "$package_dir_name" \
		"$templates_dir/$GODOT_TEMPLATE_VERSION" "$PRESET_NAME" \
		"$([[ -z "$dirty_state" ]] && echo true || echo false)" <<'PY'
import json, sys
(commit, short, root, binary, tarball, result, package_dir,
 templates, preset, clean) = sys.argv[1:]
print(json.dumps({
    "dry_run": True,
    "source_commit": commit,
    "short_commit": short,
    "preset": preset,
    "binary": f"{root}/{binary}",
    "tarball": f"{root}/{tarball}",
    "result": f"{root}/{result}",
    "tarball_root": package_dir,
    "export_templates": templates,
    "worktree_clean": clean == "true",
}, indent=2, sort_keys=True))
PY
	exit 0
fi

if [[ -n "$dirty_state" ]]; then
	die "worktree must be clean (tracked and untracked files are present)"
fi
if ! command -v "$godot_bin" >/dev/null 2>&1; then
	die "configured Godot binary is unavailable: $godot_bin"
fi
for required_tool in awk cp gzip head ln od mkdir mktemp python3 realpath rm sha256sum stat tar timeout; do
	command -v "$required_tool" >/dev/null 2>&1 \
		|| die "required tool is unavailable: $required_tool"
done
for template in linux_release.x86_64 linux_debug.x86_64; do
	[[ -f "$templates_dir/$GODOT_TEMPLATE_VERSION/$template" ]] \
		|| die "missing export template: $templates_dir/$GODOT_TEMPLATE_VERSION/$template"
done
icon_source="$REPO_ROOT/assets/keth-icon.png"
[[ -f "$icon_source" ]] || die "missing application icon: $icon_source"

require_stable_source_tree() {
	local current_commit current_dirty
	current_commit="$(git -C "$REPO_ROOT" rev-parse --verify 'HEAD^{commit}' 2>/dev/null)" \
		|| die "source commit changed during export"
	[[ "$current_commit" == "$commit" ]] || die "source commit changed during export"
	current_dirty="$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all)" \
		|| die "cannot inspect worktree state"
	[[ -z "$current_dirty" ]] \
		|| die "worktree changed during export (commit any generated .uid sidecars first)"
}

for component in "$REPO_ROOT/builds" "$build_root"; do
	[[ ! -L "$component" ]] || die "build roots must not be symlinks: $component"
	if [[ ! -e "$component" ]]; then
		mkdir -- "$component" || die "cannot create build directory: $component"
	fi
	[[ -d "$component" && ! -L "$component" ]] || die "build roots must be directories: $component"
	[[ "$(realpath -e -- "$component")" == "$component" ]] \
		|| die "build directory escaped the physical repository: $component"
done

binary_path="$build_root/$output_basename"
tarball_path="$build_root/$tarball_basename"
result_path="$build_root/$result_basename"
for existing in "$binary_path" "$tarball_path" "$result_path"; do
	if [[ -e "$existing" || -L "$existing" ]]; then
		die "refusing to overwrite existing output: $existing"
	fi
done

work_dir="$(mktemp -d "$build_root/.export-linux-${short_commit}.XXXXXX")" \
	|| die "cannot reserve a staging directory"
published=()
successful=0
cleanup() {
	local status=$?
	trap - EXIT
	set +e
	if (( status != 0 || successful != 1 )); then
		for path in "${published[@]}"; do
			rm -f -- "$path"
		done
	fi
	rm -rf -- "$work_dir"
	exit "$status"
}
trap cleanup EXIT

# Private profile: Godot reads editor settings and templates through XDG paths.
profile="$work_dir/profile"
for sub in data config cache runtime; do
	mkdir -p -- "$profile/$sub"
	chmod 700 -- "$profile/$sub"
done
mkdir -p -- "$profile/data/godot"
ln -s -- "$(realpath -e -- "$templates_dir")" "$profile/data/godot/export_templates" \
	|| die "cannot link export templates into the private profile"

staged_binary="$work_dir/$output_basename"
export_log="$work_dir/export.log"
set +e
env -u DISPLAY -u WAYLAND_DISPLAY \
	GODOT_SILENCE_ROOT_WARNING=1 \
	XDG_DATA_HOME="$profile/data" \
	XDG_CONFIG_HOME="$profile/config" \
	XDG_CACHE_HOME="$profile/cache" \
	XDG_RUNTIME_DIR="$profile/runtime" \
	timeout --signal=TERM --kill-after=15s "${timeout_seconds}s" \
	"$godot_bin" \
		--headless \
		--audio-driver Dummy \
		--path "$REPO_ROOT" \
		--export-release "$PRESET_NAME" \
		"$staged_binary" >"$export_log" 2>&1
export_status=$?
set -e
cat -- "$export_log"
(( export_status == 0 )) || die "Godot export failed with exit code $export_status"

require_stable_source_tree
if [[ -L "$staged_binary" || ! -f "$staged_binary" || ! -s "$staged_binary" ]]; then
	die "Godot did not create a nonempty Linux executable"
fi
# An ELF magic check catches a template mix-up (for example a Windows PE).
if [[ "$(head -c 4 -- "$staged_binary" | od -An -tx1 | tr -d ' \n')" != "7f454c46" ]]; then
	die "exported file is not an ELF executable"
fi
chmod 755 -- "$staged_binary"

# Launcher bundle. %k is the desktop file's own path, so the shipped entry
# starts the binary beside it wherever the archive is unpacked; the installer
# script rewrites Exec to an absolute path for the applications menu.
package_root="$work_dir/package/$package_dir_name"
mkdir -p -- "$package_root"
cp -- "$staged_binary" "$package_root/$output_basename"
cp -- "$icon_source" "$package_root/$icon_basename"
chmod 644 -- "$package_root/$icon_basename"
cat >"$package_root/$desktop_basename" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.5
Name=Mudds Shipyards
Comment=Modern standalone Keth Shipyards fan remake prototype
Exec=sh -c 'cd "\$(dirname "\$1")" && exec "./$output_basename"' mudds-shipyards %k
Icon=$icon_basename
Terminal=false
Categories=Game;Simulation;
X-MuddsShipyards-SourceCommit=$commit
DESKTOP
chmod 755 -- "$package_root/$desktop_basename"
cat >"$package_root/$installer_basename" <<INSTALLER
#!/bin/sh
# Adds (or with --uninstall removes) a per-user applications-menu entry for the
# Mudds Shipyards binary beside this script. Never touches saves or settings
# (those live under \${XDG_DATA_HOME:-\$HOME/.local/share}/godot/app_userdata).
set -eu
here=\$(cd "\$(dirname "\$0")" && pwd -P)
data_home=\${XDG_DATA_HOME:-\$HOME/.local/share}
entry="\$data_home/applications/mudds-shipyards.desktop"
if [ "\${1:-}" = "--uninstall" ]; then
	rm -f -- "\$entry"
	echo "Removed \$entry"
	exit 0
fi
# Exec/Path values and the sed replacements below are only safe for plain
# path characters; ask the player to unpack elsewhere otherwise.
case "\$here" in
	*[!A-Za-z0-9/._+,@\ -]*)
		echo "install-desktop-entry: move this folder to a path without special characters: \$here" >&2
		exit 1 ;;
esac
mkdir -p -- "\$(dirname "\$entry")"
# The icon is referenced by absolute path, so nothing outside this folder but
# the menu entry itself is written.
sed -e "s|^Exec=.*|Exec=\\"\$here/$output_basename\\"|" \\
	-e "s|^Icon=.*|Icon=\$here/$icon_basename|" \\
	-e "/^Terminal=/a Path=\$here" \\
	"\$here/$desktop_basename" >"\$entry"
chmod 644 -- "\$entry"
echo "Installed \$entry"
INSTALLER
chmod 755 -- "$package_root/$installer_basename"

commit_epoch="$(git -C "$REPO_ROOT" show -s --format=%ct "$commit")"
staged_tarball="$work_dir/$tarball_basename"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$commit_epoch" \
	-C "$work_dir/package" -cf - "$package_dir_name" | gzip -n -9 >"$staged_tarball" \
	|| die "cannot create the Linux tarball"
[[ -s "$staged_tarball" ]] || die "Linux tarball is empty"

require_stable_source_tree
for pair in "$staged_binary:$binary_path" "$staged_tarball:$tarball_path"; do
	source_file="${pair%%:*}"
	target_file="${pair#*:}"
	if [[ -e "$target_file" || -L "$target_file" ]]; then
		die "refusing to overwrite existing output: $target_file"
	fi
	ln -- "$source_file" "$target_file" || die "cannot publish $target_file"
	published+=("$target_file")
done

godot_version="$(
	env -u DISPLAY -u WAYLAND_DISPLAY \
		XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" \
		XDG_CACHE_HOME="$profile/cache" XDG_RUNTIME_DIR="$profile/runtime" \
		"$godot_bin" --headless --audio-driver Dummy --version 2>/dev/null | tail -n 1 || true
)"
staged_result="$work_dir/$result_basename"
python3 - "$staged_result" "$commit" "$PRESET_NAME" "$godot_version" \
	"$binary_path" "$tarball_path" "$package_dir_name" <<'PY'
import hashlib, json, os, sys
out, commit, preset, godot_version, binary, tarball, package_dir = sys.argv[1:]

def describe(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return {"path": path, "bytes": os.path.getsize(path), "sha256": digest.hexdigest()}

record = {
    "schema_version": 1,
    "platform": "linux",
    "architecture": "x86_64",
    "preset": preset,
    "source_commit": commit,
    "godot_version": godot_version,
    "binary": describe(binary),
    "tarball": describe(tarball),
    "tarball_root": package_dir,
    "signing": "unsigned",
    "startup_check": "NOT_RUN",
}
with open(out, "w", encoding="utf-8") as handle:
    json.dump(record, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
if [[ -e "$result_path" || -L "$result_path" ]]; then
	die "refusing to overwrite existing output: $result_path"
fi
ln -- "$staged_result" "$result_path" || die "cannot publish $result_path"
published+=("$result_path")

require_stable_source_tree
successful=1
printf 'path=%s\n' "$binary_path"
printf 'bytes=%s\n' "$(stat -Lc '%s' -- "$binary_path")"
printf 'sha256=%s\n' "$(sha256sum -- "$binary_path" | awk '{print $1}')"
printf 'tarball=%s\n' "$tarball_path"
printf 'result=%s\n' "$result_path"
