#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'export-windows-candidate: ERROR: %s\n' "$*" >&2
	exit 1
}

if (( $# > 1 )); then
	die "usage: $0 [output.exe]"
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

dirty_state="$(
	git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all
)" || die "cannot inspect worktree state"
if [[ -n "$dirty_state" ]]; then
	die "worktree must be clean (tracked and untracked files are present)"
fi

commit="$(git -C "$REPO_ROOT" rev-parse --verify 'HEAD^{commit}' 2>/dev/null)" \
	|| die "HEAD does not resolve to an exact commit"
if [[ ! "$commit" =~ ^[0-9a-f]{40,64}$ ]]; then
	die "HEAD resolved to an invalid commit ID"
fi
short_commit="${commit:0:7}"
if [[ ! "$short_commit" =~ ^[0-9a-f]{7}$ ]]; then
	die "Git did not return an exact seven-character source revision"
fi

output_basename="${1:-MuddsShipyards-${short_commit}.exe}"
if [[ "$output_basename" == */* || "$output_basename" == "." || "$output_basename" == ".." ]]; then
	die "output must be a basename directly inside builds/windows"
fi
if [[ "$output_basename" != *.exe || "$output_basename" == ".exe" ]]; then
	die "output must use the .exe suffix"
fi

godot_bin="${GODOT_BIN:-godot}"
if ! command -v "$godot_bin" >/dev/null 2>&1; then
	die "configured Godot binary is unavailable: $godot_bin"
fi
for required_tool in awk ln mkdir mktemp realpath rm sha256sum stat; do
	command -v "$required_tool" >/dev/null 2>&1 \
		|| die "required tool is unavailable: $required_tool"
done

identity_of() {
	stat -Lc '%d:%i' -- "$1" 2>/dev/null
}

ensure_directory_component() {
	local parent_fd_path="$1"
	local component_name="$2"
	local expected_path="$3"
	local component_path="$parent_fd_path/$component_name"
	[[ ! -L "$component_path" ]] || die "build roots must not be symlinks"
	if [[ ! -e "$component_path" ]]; then
		mkdir -- "$component_path" || die "cannot create build directory: $expected_path"
	fi
	[[ ! -L "$component_path" ]] || die "build roots must not be symlinks"
	[[ -d "$component_path" ]] || die "build roots must be directories"
	local resolved_path
	resolved_path="$(realpath -e -- "$component_path")" \
		|| die "cannot resolve build directory: $expected_path"
	[[ "$resolved_path" == "$expected_path" ]] \
		|| die "build directory escaped the physical repository: $expected_path"
}

# Linux/WSL directory descriptors keep every create, export and publish operation
# attached to the directory inode that passed the physical-path checks. Replacing
# a later pathname with a symlink cannot redirect any of those operations.
exec {repo_fd}<"$REPO_ROOT" || die "cannot open repository directory"
repo_fd_path="/proc/$$/fd/$repo_fd"
repo_identity="$(identity_of "$repo_fd_path")" || die "cannot identify repository directory"
[[ "$repo_identity" == "$(identity_of "$REPO_ROOT")" ]] \
	|| die "repository directory identity changed"

builds_root="$REPO_ROOT/builds"
ensure_directory_component "$repo_fd_path" "builds" "$builds_root"
exec {builds_fd}<"$repo_fd_path/builds" || die "cannot open builds directory"
builds_fd_path="/proc/$$/fd/$builds_fd"
builds_identity="$(identity_of "$builds_fd_path")" || die "cannot identify builds directory"

build_root="$builds_root/windows"
ensure_directory_component "$builds_fd_path" "windows" "$build_root"
exec {build_fd}<"$builds_fd_path/windows" || die "cannot open Windows build directory"
build_fd_path="/proc/$$/fd/$build_fd"
build_identity="$(identity_of "$build_fd_path")" || die "cannot identify Windows build directory"

release_root_is_stable() {
	[[ ! -L "$builds_root" && ! -L "$build_root" ]] \
		&& [[ -d "$builds_root" && -d "$build_root" ]] \
		&& [[ "$(identity_of "$REPO_ROOT")" == "$repo_identity" ]] \
		&& [[ "$(identity_of "$builds_root")" == "$builds_identity" ]] \
		&& [[ "$(identity_of "$build_root")" == "$build_identity" ]] \
		&& [[ "$(realpath -e -- "$builds_fd_path" 2>/dev/null)" == "$builds_root" ]] \
		&& [[ "$(realpath -e -- "$build_fd_path" 2>/dev/null)" == "$build_root" ]]
}

require_stable_release_root() {
	release_root_is_stable || die "physical Windows build root changed during export"
}

require_stable_release_root
output_path="$build_fd_path/$output_basename"
public_output_path="$build_root/$output_basename"
if [[ -e "$output_path" || -L "$output_path" ]]; then
	die "refusing to overwrite existing output: $public_output_path"
fi

temporary_output="$(mktemp "$build_fd_path/.MuddsShipyards-${short_commit}.XXXXXX.exe")" \
	|| die "cannot reserve temporary output"
cleanup_temporary() { rm -f -- "$temporary_output"; }
trap cleanup_temporary EXIT

require_stable_release_root

"$godot_bin" \
	--headless \
	--path "$REPO_ROOT" \
	--export-release "Windows Desktop" \
	"$temporary_output"

require_stable_release_root
if [[ -L "$temporary_output" || ! -f "$temporary_output" || ! -s "$temporary_output" ]]; then
	die "Godot did not create a nonempty Windows executable"
fi
temporary_identity="$(identity_of "$temporary_output")" \
	|| die "cannot identify temporary Windows executable"

if [[ -e "$output_path" || -L "$output_path" ]]; then
	die "refusing to overwrite existing output: $public_output_path"
fi
require_stable_release_root
ln -- "$temporary_output" "$output_path" || die "cannot publish Windows executable"
if [[ "$(identity_of "$output_path")" != "$temporary_identity" ]]; then
	die "published Windows executable identity changed"
fi
if ! release_root_is_stable; then
	# Remove only the link this invocation created, and only while it still names
	# the reserved temporary inode. Never remove a racing or pre-existing file.
	if [[ "$(identity_of "$output_path")" == "$temporary_identity" ]]; then
		rm -f -- "$output_path"
	fi
	die "physical Windows build root changed during publication"
fi
rm -f -- "$temporary_output" || die "cannot remove temporary Windows executable"
trap - EXIT

byte_size="$(stat -c '%s' -- "$output_path")"
sha256="$(sha256sum -- "$output_path" | awk '{print $1}')"
require_stable_release_root
printf 'path=%s\n' "$public_output_path"
printf 'bytes=%s\n' "$byte_size"
printf 'sha256=%s\n' "$sha256"
