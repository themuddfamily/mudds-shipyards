#!/usr/bin/env bash
# Runs a named subset of tests/*_test.gd with the same acceptance rules the
# release matrix applies: exit 0, a terminal <SUITE>_OK/_PASS sentinel, and zero
# diagnostic lines. Used while the full matrix is being run once per phase
# instead of once per change.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
DIAG_RE='^[[:space:]]*SCRIPT[[:space:]]+ERROR|^[[:space:]]*ERROR:|FATAL ERROR|ObjectDB|Resource.*still in use|Orphaned|Leaked'
overall=0
for name in "$@"; do
	log="$(mktemp)"
	timeout 240 "$GODOT_BIN" --headless --path "$ROOT" --script "res://tests/${name}.gd" --audio-driver Dummy > "$log" 2>&1
	code=$?
	upper="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
	terminal="$(grep -v '^[[:space:]]*$' "$log" | tail -1)"
	diag="$(grep -cE "$DIAG_RE" "$log")"
	passes="$(grep -cE '^PASS:' "$log")"
	status="PASS"
	if [[ $code -ne 0 ]] || [[ $diag -ne 0 ]]; then
		status="FAIL"
	fi
	if [[ "$terminal" != "${upper}_OK"* && "$terminal" != "${upper}_PASS"* ]]; then
		status="FAIL"
	fi
	printf '%-52s %s exit=%d assertions=%-5s diagnostics=%s terminal=%s\n' \
		"$name" "$status" "$code" "$passes" "$diag" "$terminal"
	if [[ "$status" == "FAIL" ]]; then
		overall=1
		grep -E "$DIAG_RE" "$log" | head -6
	fi
	rm -f "$log"
done
exit $overall
