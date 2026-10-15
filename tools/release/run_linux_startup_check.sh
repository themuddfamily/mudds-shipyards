#!/usr/bin/env bash
# Silent, isolated startup check for an exported Linux build.
#
#   tools/release/run_linux_startup_check.sh [--rendered] [--dry-run] [--keep-profile] <binary.x86_64 | package.tar.gz>
#
# Runs the exported game with --headless --audio-driver Dummy --startup-check
# with inherited HOME and a private XDG/TMPDIR profile (so the developer's
# saves, settings and caches are never read or written) and passes only when the process exits 0
# AND the log contains STARTUP_MENU_READY_OK. The game prints that sentinel only
# after the real title menu is presented and interactive (startup_loader.gd);
# a fixed --quit-after frame count would not establish menu readiness, and
# export templates may ignore external --script overrides.
#
# Given a .tar.gz, the archive is unpacked into the private profile first and
# its single *.x86_64 binary is checked, which also exercises the packaging.
#
# Writes <binary-or-tarball>.startup-check.json (schema_version 1) and the full
# log beside it as <...>.startup-check.log. Exit 0 = pass, 1 = fail, 2 = usage.
#
# Environment:
#   STARTUP_CHECK_TIMEOUT_SECONDS  wall-clock abort (default 300)
#   STARTUP_CHECK_RESULT_DIR       where the JSON/log go (default: beside input)
# Rendered mode additionally requires an authenticated, caller-owned isolated
# X server: DISPLAY=127.0.0.1:N, private XAUTHORITY, and one absolute
# VK_DRIVER_FILES path pinned by STARTUP_CHECK_VK_DRIVER_SHA256. The caller owns
# Xvfb startup, independent abort and session cleanup; this script creates none.
set -euo pipefail

die_usage() {
	printf 'linux-startup-check: %s\n' "$*" >&2
	printf 'usage: %s [--rendered] [--dry-run] [--keep-profile] <binary.x86_64|package.tar.gz>\n' "$0" >&2
	exit 2
}
fail() {
	printf 'linux-startup-check: FAIL: %s\n' "$*" >&2
	exit 1
}

dry_run=0
keep_profile=0
rendered=0
positional=()
for argument in "$@"; do
	case "$argument" in
		--dry-run) dry_run=1 ;;
		--keep-profile) keep_profile=1 ;;
		--rendered) rendered=1 ;;
		-h|--help) die_usage "help" ;;
		--*) die_usage "unknown option: $argument" ;;
		*) positional+=("$argument") ;;
	esac
done
(( ${#positional[@]} == 1 )) || die_usage "exactly one binary or tarball is required"
input="${positional[0]}"
[[ -f "$input" && ! -L "$input" ]] || die_usage "input is not a regular file: $input"
input="$(realpath -e -- "$input")"
case "$input" in
	*.x86_64) input_kind="binary" ;;
	*.tar.gz) input_kind="tarball" ;;
	*) die_usage "input must be a .x86_64 binary or a .tar.gz package" ;;
esac

timeout_seconds="${STARTUP_CHECK_TIMEOUT_SECONDS:-300}"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] \
	|| die_usage "STARTUP_CHECK_TIMEOUT_SECONDS must be a positive integer"
result_dir="${STARTUP_CHECK_RESULT_DIR:-$(dirname -- "$input")}"
result_base="$result_dir/$(basename -- "$input").startup-check"
result_json="$result_base.json"
result_log="$result_base.log"
game_args=(--headless --audio-driver Dummy --startup-check)
launch_mode="headless"
render_env=()
render_display=""
driver_file=""
driver_sha=""
if (( rendered == 1 )); then
	launch_mode="rendered"
	render_display="${DISPLAY:-}"
	authority="${XAUTHORITY:-}"
	driver_file="${VK_DRIVER_FILES:-}"
	driver_sha="${STARTUP_CHECK_VK_DRIVER_SHA256:-}"
	# Validate before creating a profile or output. A TCP-only display avoids
	# accidentally selecting an inherited desktop's local Unix socket.
	python3 - "$render_display" "$authority" "$driver_file" "$driver_sha" <<'PY' || fail "invalid rendered isolation inputs"
import hashlib, os, pathlib, re, socket, stat, struct, sys
display, auth, driver, expected = sys.argv[1:]
match = re.fullmatch(r"127\.0\.0\.1:([1-9][0-9]{0,4})(?:\.0)?", display)
if not match or int(match[1]) > 59535:
    sys.exit("Rendered DISPLAY must name an explicit isolated loopback TCP display")
authority = pathlib.Path(auth)
if not authority.is_absolute() or authority.is_symlink() or not authority.is_file():
    sys.exit("Rendered XAUTHORITY must be an absolute regular private file")
info = authority.stat()
if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600:
    sys.exit("Rendered XAUTHORITY must be owned by this user with mode 0600")
if stat.S_IMODE(authority.parent.stat().st_mode) != 0o700:
    sys.exit("Rendered XAUTHORITY parent must have mode 0700")
# Xauthority records: family, then length-prefixed address/display/name/cookie.
# xauth may encode loopback TCP as FamilyLocal with this machine's hostname.
# Accept only that exact local identity or the explicit Internet loopback address.
data, offset, authenticated = authority.read_bytes(), 0, False
try:
    while offset < len(data):
        family = struct.unpack_from(">H", data, offset)[0]
        offset += 2
        fields = []
        for _ in range(4):
            length = struct.unpack_from(">H", data, offset)[0]
            offset += 2
            if offset + length > len(data):
                raise ValueError("truncated authority")
            fields.append(data[offset:offset + length])
            offset += length
        local_address = (family == 0 and fields[0] == b"\x7f\x00\x00\x01") or (
            family == 256 and fields[0] == socket.gethostname().encode()
        )
        authenticated |= (local_address and fields[1:3] == [
            str(int(match[1])).encode(), b"MIT-MAGIC-COOKIE-1"
        ] and len(fields[3]) == 16)
except (ValueError, struct.error):
    sys.exit("Malformed rendered XAUTHORITY")
if not authenticated:
    sys.exit("Rendered XAUTHORITY has no cookie for the requested TCP display")
path = pathlib.Path(driver)
if not path.is_absolute() or path.is_symlink() or not path.is_file():
    sys.exit("VK_DRIVER_FILES must name one absolute regular file")
if not re.fullmatch(r"[0-9a-f]{64}", expected):
    sys.exit("STARTUP_CHECK_VK_DRIVER_SHA256 must pin the driver file")
with path.open("rb") as stream:
    actual = hashlib.file_digest(stream, "sha256").hexdigest()
if actual != expected:
    sys.exit("Rendered Vulkan driver-file SHA-256 mismatch")
PY
	game_args=(--startup-check --audio-driver Dummy --display-driver x11 --rendering-method forward_plus --rendering-driver vulkan)
	render_env=("DISPLAY=$render_display" "XAUTHORITY=$authority" "VK_DRIVER_FILES=$driver_file")
fi

if (( dry_run == 1 )); then
	python3 - "$input" "$input_kind" "$result_json" "$result_log" "$timeout_seconds" \
		"$launch_mode" "$render_display" "$driver_file" "$driver_sha" "${game_args[@]}" <<'PY'
import json, sys
input_path, kind, result_json, result_log, timeout, mode, display, driver, pin = sys.argv[1:10]
print(json.dumps({
    "dry_run": True,
    "input": input_path,
    "input_kind": kind,
    "arguments": sys.argv[10:],
    "launch_mode": mode,
    "display": display or None,
    "vulkan_driver_file": driver or None,
    "vulkan_driver_sha256": pin or None,
    "required_exit_code": 0,
    "required_sentinel": "STARTUP_MENU_READY_OK",
    "timeout_seconds": int(timeout),
    "result": result_json,
    "log": result_log,
}, indent=2, sort_keys=True))
PY
	exit 0
fi

for required_tool in mktemp python3 sha256sum tar timeout; do
	command -v "$required_tool" >/dev/null 2>&1 || fail "required tool is unavailable: $required_tool"
done
mkdir -p -- "$result_dir"
for existing in "$result_json" "$result_log"; do
	[[ ! -e "$existing" && ! -L "$existing" ]] \
		|| fail "refusing to overwrite an earlier result: $existing"
done

profile_root="$(mktemp -d "${TMPDIR:-/tmp}/mudds-linux-startup-check.XXXXXX")"
cleanup() {
	local status=$?
	trap - EXIT
	if (( keep_profile == 1 )); then
		printf 'profile kept at %s\n' "$profile_root" >&2
	else
		rm -rf -- "$profile_root"
	fi
	exit "$status"
}
trap cleanup EXIT
for sub in data config cache runtime state data-dirs config-dirs tmp; do
	mkdir -p -- "$profile_root/$sub"
	chmod 700 -- "$profile_root/$sub"
done

binary="$input"
if [[ "$input_kind" == "tarball" ]]; then
	mkdir -p -- "$profile_root/package"
	tar --no-same-owner -xzf "$input" -C "$profile_root/package" \
		|| fail "cannot unpack $input"
	mapfile -t candidates < <(find "$profile_root/package" -type f -name '*.x86_64' | sort)
	(( ${#candidates[@]} == 1 )) \
		|| fail "package must contain exactly one *.x86_64 binary (found ${#candidates[@]})"
	binary="${candidates[0]}"
	package_dir="$(dirname -- "$binary")"
	for member in mudds-shipyards.desktop mudds-shipyards.png install-desktop-entry.sh; do
		[[ -f "$package_dir/$member" ]] || fail "package is missing $member"
	done
	[[ -x "$binary" ]] || fail "packaged binary is not executable"
fi
[[ -x "$binary" ]] || fail "binary is not executable: $binary"

inherited_home=()
if [[ ${HOME+x} ]]; then
	inherited_home=("HOME=$HOME")
fi

started_ms="$(date +%s%3N)"
set +e
( cd "$(dirname -- "$binary")" && env -i \
	PATH="/usr/local/bin:/usr/bin:/bin" \
	"${inherited_home[@]}" \
	XDG_DATA_HOME="$profile_root/data" \
	XDG_CONFIG_HOME="$profile_root/config" \
	XDG_CACHE_HOME="$profile_root/cache" \
	XDG_STATE_HOME="$profile_root/state" \
	XDG_RUNTIME_DIR="$profile_root/runtime" \
	XDG_DATA_DIRS="$profile_root/data-dirs" \
	XDG_CONFIG_DIRS="$profile_root/config-dirs" \
	TMPDIR="$profile_root/tmp" \
	LANG="C.UTF-8" \
	"${render_env[@]}" \
	timeout --signal=TERM --kill-after=15s "${timeout_seconds}s" \
	"$binary" "${game_args[@]}" ) >"$result_log" 2>&1 </dev/null
exit_code=$?
set -e
ended_ms="$(date +%s%3N)"

sentinel_count="$(grep -ac '^STARTUP_MENU_READY_OK' "$result_log" || true)"
failed_count="$(grep -ac '^STARTUP_MENU_READY_FAILED' "$result_log" || true)"
user_data_dir="$profile_root/data/godot/app_userdata/Mudds Shipyards"
status="PASS"
reasons=()
(( exit_code == 0 )) || reasons+=("exit=$exit_code")
(( sentinel_count >= 1 )) || reasons+=("missing STARTUP_MENU_READY_OK")
(( failed_count == 0 )) || reasons+=("STARTUP_MENU_READY_FAILED printed")
if (( rendered == 1 )); then
	(( sentinel_count == 1 )) || reasons+=("rendered startup requires exactly one STARTUP_MENU_READY_OK")
	if grep -aqE 'SCRIPT ERROR:|^ERROR:|ObjectDB instances leaked|resources still in use' "$result_log"; then
		reasons+=("rendered startup emitted error or resource-leak diagnostics")
	fi
	actual_driver_sha="$(sha256sum -- "$driver_file" 2>/dev/null | cut -d ' ' -f 1 || true)"
	[[ "$actual_driver_sha" == "$driver_sha" ]] || reasons+=("rendered Vulkan driver file changed")
fi
(( ${#reasons[@]} == 0 )) || status="FAIL"

python3 - "$result_json" "$status" "$input" "$binary" "$exit_code" "$sentinel_count" \
	"$((ended_ms - started_ms))" "$result_log" "$([[ -d "$user_data_dir" ]] && echo true || echo false)" \
	"$launch_mode" "$render_display" "$driver_file" "$driver_sha" "${reasons[@]}" <<'PY'
import hashlib, json, sys
(out, status, input_path, binary, exit_code, sentinel, wall_ms, log,
 user_data, mode, display, driver, pin) = sys.argv[1:14]
reasons = sys.argv[14:]
digest = hashlib.sha256(open(binary, "rb").read()).hexdigest()
record = {
    "schema_version": 1,
    "check": "linux_startup_menu_ready",
    "status": status,
    "input": input_path,
    "binary_sha256": digest,
    "exit_code": int(exit_code),
    "sentinel_count": int(sentinel),
    "wall_ms": int(wall_ms),
    "log": log,
    "private_user_data_created": user_data == "true",
    "reasons": reasons,
    "environment": f"{mode}, --audio-driver Dummy, inherited HOME, private XDG/TMPDIR",
    "launch_mode": mode,
    "display": display or None,
    "vulkan_driver_file": driver or None,
    "vulkan_driver_sha256": pin or None,
    "native_gpu": "NOT_RUN",
}
with open(out, "w", encoding="utf-8") as handle:
    json.dump(record, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

printf 'status=%s exit=%s sentinel=%s wall_ms=%s\n' \
	"$status" "$exit_code" "$sentinel_count" "$((ended_ms - started_ms))"
printf 'result=%s\n' "$result_json"
[[ "$status" == "PASS" ]] || fail "$(IFS='; '; echo "${reasons[*]}")"
