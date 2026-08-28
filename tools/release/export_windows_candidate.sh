#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'export-windows-candidate: ERROR: %s\n' "$*" >&2
	exit 1
}

if (( $# > 1 )); then
	die "usage: $0 [builds/windows/output.exe]"
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

build_root="$(realpath -m -- "$REPO_ROOT/builds/windows")"
requested_output="${1:-builds/windows/MuddsShipyards-${short_commit}.exe}"
if [[ "$requested_output" == /* ]]; then
	output_candidate="$requested_output"
else
	output_candidate="$REPO_ROOT/$requested_output"
fi
output_path="$(realpath -m -- "$output_candidate")"
case "$output_path" in
	"$build_root"/*) ;;
	*) die "output must remain beneath $build_root" ;;
esac
if [[ "$output_path" != *.exe ]]; then
	die "output must use the .exe suffix"
fi
if [[ -e "$output_path" || -L "$output_path" ]]; then
	die "refusing to overwrite existing output: $output_path"
fi

godot_bin="${GODOT_BIN:-godot}"
if ! command -v "$godot_bin" >/dev/null 2>&1; then
	die "configured Godot binary is unavailable: $godot_bin"
fi
for required_tool in mkdir realpath sha256sum stat; do
	command -v "$required_tool" >/dev/null 2>&1 \
		|| die "required tool is unavailable: $required_tool"
done

output_directory="$(dirname -- "$output_path")"
mkdir -p -- "$output_directory"

"$godot_bin" \
	--headless \
	--path "$REPO_ROOT" \
	--export-release "Windows Desktop" \
	"$output_path"

if [[ ! -s "$output_path" ]]; then
	die "Godot did not create a nonempty Windows executable: $output_path"
fi

byte_size="$(stat -c '%s' -- "$output_path")"
sha256="$(sha256sum -- "$output_path" | awk '{print $1}')"
printf 'path=%s\n' "$output_path"
printf 'bytes=%s\n' "$byte_size"
printf 'sha256=%s\n' "$sha256"
