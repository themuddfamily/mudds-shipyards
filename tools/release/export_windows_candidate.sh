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

source_tree_is_stable() {
	local current_commit=""
	local current_dirty_state=""
	current_commit="$(git -C "$REPO_ROOT" rev-parse --verify 'HEAD^{commit}' 2>/dev/null)" \
		|| return 1
	[[ "$current_commit" == "$commit" ]] || return 1
	current_dirty_state="$(
		git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all
	)" || return 1
	[[ -z "$current_dirty_state" ]]
}

require_stable_source_tree() {
	source_tree_is_stable \
		|| die "source commit or worktree changed during export"
}

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
temporary_identity="$(identity_of "$temporary_output")" \
	|| die "cannot identify reserved temporary output"
artifact_identity=""
published=0
successful_publication=0

cleanup_release() {
	local status=$?
	local current_identity=""
	trap - EXIT
	set +e

	# The EXIT check is the last observation this process can make. It prevents
	# a successful return if the public name or any physical build-root component
	# changed after the ordinary post-publication checks below.
	if (( status == 0 && successful_publication == 1 )); then
		current_identity="$(identity_of "$output_path")"
		if ! source_tree_is_stable \
				|| ! release_root_is_stable \
				|| [[ "$current_identity" != "$artifact_identity" ]]; then
			printf '%s\n' \
				'export-windows-candidate: ERROR: source or published executable changed before exit' \
				>&2
			status=1
		fi
	fi

	# Roll back through the already-open directory descriptor. This still reaches
	# the directory this invocation validated if a racing process has displaced
	# builds/windows. Never remove a path whose inode is no longer ours.
	if (( status != 0 && published == 1 )); then
		current_identity="$(identity_of "$output_path")"
		if [[ -n "$artifact_identity" && "$current_identity" == "$artifact_identity" ]]; then
			rm -f -- "$output_path"
		fi
	fi

	current_identity="$(identity_of "$temporary_output")"
	if [[ -n "$temporary_identity" && "$current_identity" == "$temporary_identity" ]]; then
		rm -f -- "$temporary_output"
	fi
	exit "$status"
}
trap cleanup_release EXIT

require_stable_release_root

"$godot_bin" \
	--headless \
	--path "$REPO_ROOT" \
	--export-release "Windows Desktop" \
	"$temporary_output"

require_stable_source_tree
require_stable_release_root
if [[ -L "$temporary_output" || ! -f "$temporary_output" || ! -s "$temporary_output" ]]; then
	die "Godot did not create a nonempty Windows executable"
fi
temporary_identity="$(identity_of "$temporary_output")" \
	|| die "cannot identify temporary Windows executable"
exec {artifact_fd}<"$temporary_output" \
	|| die "cannot open exported Windows executable"
artifact_fd_path="/proc/$$/fd/$artifact_fd"
artifact_identity="$(identity_of "$artifact_fd_path")" \
	|| die "cannot identify opened Windows executable"
[[ "$artifact_identity" == "$temporary_identity" ]] \
	|| die "temporary Windows executable identity changed while opening"

if [[ -e "$output_path" || -L "$output_path" ]]; then
	die "refusing to overwrite existing output: $public_output_path"
fi
require_stable_release_root
ln -- "$temporary_output" "$output_path" || die "cannot publish Windows executable"
published=1
if [[ "$(identity_of "$output_path")" != "$temporary_identity" ]]; then
	die "published Windows executable identity changed"
fi
require_stable_release_root
rm -f -- "$temporary_output" || die "cannot remove temporary Windows executable"

# Closing the temporary name is not the end of publication. Revalidate the
# directory chain and final name after that unlink; the opened artifact FD keeps
# byte/identity observations tied to the exported inode even if a racing process
# replaces the public pathname.
if [[ -e "$temporary_output" || -L "$temporary_output" ]]; then
	die "temporary Windows executable remained after publication"
fi
require_stable_release_root
[[ "$(identity_of "$output_path")" == "$artifact_identity" ]] \
	|| die "published Windows executable changed after temporary cleanup"

byte_size="$(stat -Lc '%s' -- "$artifact_fd_path")"
sha256="$(sha256sum -- "$artifact_fd_path" | awk '{print $1}')"
[[ "$(identity_of "$artifact_fd_path")" == "$artifact_identity" ]] \
	|| die "opened Windows executable identity changed"
require_stable_source_tree
require_stable_release_root
[[ "$(identity_of "$output_path")" == "$artifact_identity" ]] \
	|| die "published Windows executable changed while hashing"
successful_publication=1
printf 'path=%s\n' "$public_output_path"
printf 'bytes=%s\n' "$byte_size"
printf 'sha256=%s\n' "$sha256"
