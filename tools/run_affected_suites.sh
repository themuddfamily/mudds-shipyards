#!/usr/bin/env bash
# Runs a named subset of tests/*_test.gd with the same acceptance rules the
# release matrix applies: exit 0, exactly one terminal <SUITE>_OK/_PASS sentinel,
# and zero diagnostic lines. Used while the full matrix is being run once per
# phase instead of once per change.
#
# This is deliberately a thin wrapper. The acceptance rules live in exactly one
# place - tools/release/run_test_matrix.sh - so that the focused runner and the
# release gate cannot drift apart. (They already had: this script used to accept
# a suite that printed two sentinels, which the matrix rejects.)
#
# Usage:
#   tools/run_affected_suites.sh fleet_pbr_test tow_tractor_test
#   tools/run_affected_suites.sh 'flight_*'          # globs work
#   tools/run_affected_suites.sh --jobs 1 hud_test   # matrix flags pass through
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MATRIX="$SCRIPT_DIR/release/run_test_matrix.sh"

if [[ $# -eq 0 ]]; then
	echo "Usage: $(basename "$0") [matrix flags] <suite-name|glob|path> ..."
	echo "Runs the named suites under the release matrix's own acceptance rules."
	exit 2
fi

SCOPE_ARGS=()
PASSTHROUGH=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--godot|--timeout|--results-dir|--audio-driver|--jobs|-j|--import-gate|--manifest-scope)
			PASSTHROUGH+=("$1" "$2")
			shift 2
			;;
		--scope)
			SCOPE_ARGS+=(--scope "$2")
			shift 2
			;;
		-h|--help)
			exec "$MATRIX" --help
			;;
		-*)
			PASSTHROUGH+=("$1")
			shift
			;;
		*)
			SCOPE_ARGS+=(--scope "$1")
			shift
			;;
	esac
done

if (( ${#SCOPE_ARGS[@]} == 0 )); then
	echo "No suites named. Pass at least one suite name, glob or path."
	exit 2
fi

# Focused runs are throwaway evidence: keep them out of the release matrix tree
# and give them the longer per-suite budget this script has always used.
export TEST_MATRIX_RESULTS_ROOT="${TEST_MATRIX_RESULTS_ROOT:-$SCRIPT_DIR/../artifacts/affected-suites}"
export TEST_MATRIX_TIMEOUT_SECONDS="${TEST_MATRIX_TIMEOUT_SECONDS:-240}"

exec "$MATRIX" "${PASSTHROUGH[@]}" "${SCOPE_ARGS[@]}"
