#!/usr/bin/env bash
# Silent, isolated startup check for an exported Linux build.
#
#   tools/release/run_linux_startup_check.sh [--dry-run] [--keep-profile] <binary.x86_64 | package.tar.gz>
#
# Runs the exported game with --headless --audio-driver Dummy --startup-check
# under a private HOME and XDG profile (so the developer's saves, settings and
# caches are never read or written) and passes only when the process exits 0
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
set -euo pipefail

die_usage() {
	printf 'linux-startup-check: %s\n' "$*" >&2
	printf 'usage: %s [--dry-run] [--keep-profile] <binary.x86_64|package.tar.gz>\n' "$0" >&2
	exit 2
}
fail() {
	printf 'linux-startup-check: FAIL: %s\n' "$*" >&2
	exit 1
}

dry_run=0
keep_profile=0
positional=()
for argument in "$@"; do
	case "$argument" in
		--dry-run) dry_run=1 ;;
		--keep-profile) keep_profile=1 ;;
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

if (( dry_run == 1 )); then
	python3 - "$input" "$input_kind" "$result_json" "$result_log" "$timeout_seconds" \
		"${game_args[@]}" <<'PY'
import json, sys
input_path, kind, result_json, result_log, timeout = sys.argv[1:6]
print(json.dumps({
    "dry_run": True,
    "input": input_path,
    "input_kind": kind,
    "arguments": sys.argv[6:],
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
for sub in home data config cache runtime state; do
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

started_ms="$(date +%s%3N)"
set +e
( cd "$(dirname -- "$binary")" && env -i \
	PATH="/usr/local/bin:/usr/bin:/bin" \
	HOME="$profile_root/home" \
	XDG_DATA_HOME="$profile_root/data" \
	XDG_CONFIG_HOME="$profile_root/config" \
	XDG_CACHE_HOME="$profile_root/cache" \
	XDG_STATE_HOME="$profile_root/state" \
	XDG_RUNTIME_DIR="$profile_root/runtime" \
	LANG="C.UTF-8" \
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
(( ${#reasons[@]} == 0 )) || status="FAIL"

python3 - "$result_json" "$status" "$input" "$binary" "$exit_code" "$sentinel_count" \
	"$((ended_ms - started_ms))" "$result_log" "$([[ -d "$user_data_dir" ]] && echo true || echo false)" \
	"${reasons[@]}" <<'PY'
import hashlib, json, sys
(out, status, input_path, binary, exit_code, sentinel, wall_ms, log,
 user_data) = sys.argv[1:10]
reasons = sys.argv[10:]
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
    "environment": "headless, --audio-driver Dummy, private HOME/XDG",
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
