#!/usr/bin/env bash

set -euo pipefail
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

GODOT_BIN="${GODOT_BIN:-godot}"
TIMEOUT_SECONDS="${TEST_MATRIX_TIMEOUT_SECONDS:-180}"
RUN_RESULTS_ROOT="${TEST_MATRIX_RESULTS_ROOT:-$PROJECT_ROOT/artifacts/test-matrix}"
RUN_ID="${TEST_MATRIX_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
AUDIO_DRIVER="${TEST_MATRIX_AUDIO_DRIVER:-Dummy}"
IMPORT_GATE="${TEST_MATRIX_IMPORT_GATE:-auto}"
ALLOW_CACHE_DRIFT="${TEST_MATRIX_ALLOW_CACHE_DRIFT:-0}"

# Default job count: leave two cores for the shell, the OS and whatever else the
# box is doing. Godot suites are themselves multi-threaded, so this is already a
# deliberate over-subscription of one process per remaining core.
detect_default_jobs() {
	local cores
	cores="$(nproc 2>/dev/null || echo 1)"
	if ! [[ "$cores" =~ ^[0-9]+$ ]] || (( cores < 1 )); then
		cores=1
	fi
	local jobs=$(( cores - 2 ))
	if (( jobs < 1 )); then
		jobs=1
	fi
	printf '%s' "$jobs"
}
JOBS="${TEST_MATRIX_JOBS:-$(detect_default_jobs)}"

SCOPE_SPECS=()
if [[ -n "${TEST_MATRIX_SCOPE:-}" ]]; then
	IFS=$', \n\t' read -r -a _env_scope <<<"${TEST_MATRIX_SCOPE}"
	SCOPE_SPECS+=("${_env_scope[@]}")
fi

DIAGNOSTIC_RE='^[[:space:]]*SCRIPT[[:space:]]+ERROR|^[[:space:]]*ERROR:|\\bFATAL ERROR\\b|\\bObjectDB\\b|Resource.*still in use|\\bOrphaned\\b|\\bLeaked\\b|\\bObjectDB\\b'

usage() {
	cat <<EOF
Usage: $(basename "$0") [--godot PATH] [--timeout SECONDS] [--results-dir DIR]
                        [--audio-driver NAME] [--jobs N] [--scope SPEC[,SPEC...]]
                        [--manifest-scope PATH[,PATH...]] [--import-gate MODE]

Run tests/*_test.gd files under Godot --headless, one isolated process per suite,
and write a timestamped matrix manifest. Suites run in parallel by default; the
results TSV, the console transcript and the run manifest are emitted in sorted
suite order regardless of completion order.

Options:
  --godot PATH              Godot binary (default: \`godot\`).
  --timeout SECONDS         Per-suite timeout (default: 180).
  --results-dir DIR         Results root (default: artifacts/test-matrix).
  --audio-driver NAME       Audio backend passed to --audio-driver (default: Dummy).
  --jobs N                  Concurrent suites. Default: nproc-2, floor 1.
                            Use --jobs 1 for a strictly serial debugging run.
  --scope SPEC[,SPEC...]    Select a subset of suites. Repeatable. A SPEC may be
                            a suite name (fleet_pbr_test), a file name
                            (fleet_pbr_test.gd), a path (tests/fleet_pbr_test.gd),
                            or a glob (*_pbr_test, flight_*). A SPEC that matches
                            no suite is a hard error. Default: every suite.
  --manifest-scope PATHS    Override the source-manifest scope used by the
                            source_manifest_match guard (comma/space separated,
                            relative to the project root).
  --import-gate MODE        auto (default) runs \`--headless --editor --quit\` only
                            when .godot/ has no script-class cache; always forces
                            it; never skips it. Root configuration files are
                            snapshotted and restored if the gate rewrites them.

Environment variables:
  GODOT_BIN                 Defaults to \`godot\`.
  TEST_MATRIX_TIMEOUT_SECONDS Defaults to 180.
  TEST_MATRIX_RESULTS_ROOT   Defaults to artifacts/test-matrix.
  TEST_MATRIX_TEST_FILTER    Extended-regular-expression filter applied to tests/*_test.gd paths.
  TEST_MATRIX_AUDIO_DRIVER   Audio backend passed to --audio-driver (defaults to Dummy).
  TEST_MATRIX_RUN_ID         Override the timestamp label.
  TEST_MATRIX_JOBS           Default concurrency (same meaning as --jobs).
  TEST_MATRIX_SCOPE          Default scope specs (same meaning as --scope).
  TEST_MATRIX_MANIFEST_SCOPE Default source-manifest scope (same as --manifest-scope).
  TEST_MATRIX_IMPORT_GATE    auto | always | never.
  TEST_MATRIX_ALLOW_CACHE_DRIFT
                            Set to 1 to downgrade a .godot/ cache-drift detection
                            during a parallel run from a failure to a warning.
  --audio-driver NAME       Override TEST_MATRIX_AUDIO_DRIVER for this invocation.
EOF
}

MANIFEST_SCOPE_OVERRIDE="${TEST_MATRIX_MANIFEST_SCOPE:-}"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--godot)
			GODOT_BIN="$2"
			shift 2
			;;
		--timeout)
			TIMEOUT_SECONDS="$2"
			shift 2
			;;
		--results-dir)
			RUN_RESULTS_ROOT="$2"
			shift 2
			;;
		--audio-driver)
			AUDIO_DRIVER="$2"
			shift 2
			;;
		--jobs|-j)
			JOBS="$2"
			shift 2
			;;
		--scope)
			IFS=$', \n\t' read -r -a _cli_scope <<<"$2"
			SCOPE_SPECS+=("${_cli_scope[@]}")
			shift 2
			;;
		--manifest-scope)
			MANIFEST_SCOPE_OVERRIDE="$2"
			shift 2
			;;
		--import-gate)
			IMPORT_GATE="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1"
			usage
			exit 1
			;;
	esac
done

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
	echo "Invalid timeout: $TIMEOUT_SECONDS"
	exit 2
fi

if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || (( JOBS < 1 )); then
	echo "Invalid --jobs value: $JOBS (expected a positive integer)"
	exit 2
fi

case "$IMPORT_GATE" in
	auto|always|never) ;;
	*)
		echo "Invalid --import-gate value: $IMPORT_GATE (expected auto, always or never)"
		exit 2
		;;
esac

if [[ ! -x "$GODOT_BIN" ]] && ! command -v "$GODOT_BIN" >/dev/null; then
	echo "Godot binary not found: $GODOT_BIN"
	exit 2
fi

RUN_DIR="$RUN_RESULTS_ROOT/$RUN_ID"
LOG_DIR="$RUN_DIR/logs"
mkdir -p "$LOG_DIR"

# Per-suite scratch lives outside RUN_DIR so that result-file-hashes.csv keeps
# covering exactly the published artefacts it covered before.
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-matrix-XXXXXX")"

kill_children() {
	local pid child
	for pid in $(jobs -p 2>/dev/null); do
		# The worker subshell's own child is `timeout`, which forwards SIGTERM
		# to Godot; without this sweep an interrupted run leaks a pool of
		# headless Godot processes.
		for child in $(pgrep -P "$pid" 2>/dev/null || true); do
			kill -TERM "$child" 2>/dev/null || true
		done
		kill -TERM "$pid" 2>/dev/null || true
	done
}

on_exit() {
	local code="$?"
	trap - EXIT
	[[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
	exit "$code"
}

on_signal() {
	echo
	echo "Interrupted - terminating in-flight suites."
	kill_children
	wait 2>/dev/null || true
	[[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
	exit 130
}

trap on_exit EXIT
trap on_signal INT TERM

RUN_STARTED_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
HAVE_TIMEOUT_BIN=0
if command -v timeout >/dev/null; then
	HAVE_TIMEOUT_BIN=1
fi

SCOPE_PATHS=(
	"project.godot"
	"export_presets.cfg"
	"default_bus_layout.tres"
	"scripts"
	"scenes"
	"tests"
	"assets"
	"tools"
	"art_source"
)

if [[ -n "$MANIFEST_SCOPE_OVERRIDE" ]]; then
	IFS=$', \n\t' read -r -a SCOPE_PATHS <<<"$MANIFEST_SCOPE_OVERRIDE"
	if (( ${#SCOPE_PATHS[@]} == 0 )); then
		echo "Empty --manifest-scope"
		exit 2
	fi
fi

# Root configuration files that a Godot editor/import pass has been observed to
# rewrite, silently dropping intentionally-versioned settings. They are
# snapshotted before the gate and restored byte-for-byte if the gate edits them.
PROTECTED_ROOT_FILES=(
	"project.godot"
	"export_presets.cfg"
	"default_bus_layout.tres"
)

collect_source_manifest() {
	local output_path="$1"
	local path_list_file
	path_list_file="$(mktemp)"
	: > "$output_path"

	for entry in "${SCOPE_PATHS[@]}"; do
		local root="$PROJECT_ROOT/$entry"
		if [[ -f "$root" ]]; then
			printf '%s\0' "$root" >> "$path_list_file"
		elif [[ -d "$root" ]]; then
			find "$root" -type f -print0 >> "$path_list_file"
		fi
	done

	printf 'path,size_bytes,sha256\n' > "$output_path"
	while IFS= read -r -d '' file; do
		relative="${file#$PROJECT_ROOT/}"
		size="$(stat -c '%s' "$file")"
		sha="$(sha256sum "$file" | cut -d' ' -f1)"
		printf '%s,%s,%s\n' "$relative" "$size" "$sha" >> "$output_path"
	done < <(sort -z < "$path_list_file")
	rm -f "$path_list_file"
}

# Signature of the shared Godot import cache. Suites run as separate processes
# against one .godot/ directory; a warm cache is read-only for
# `--headless --script`, so any drift across the suite phase means something
# wrote to shared state and the results cannot be trusted.
godot_cache_signature() {
	local cache_dir="$PROJECT_ROOT/.godot"
	if [[ ! -d "$cache_dir" ]]; then
		printf 'absent'
		return 0
	fi
	find "$cache_dir" -type f -print0 2>/dev/null \
		| sort -z \
		| xargs -0 -r sha256sum 2>/dev/null \
		| sha256sum \
		| cut -d' ' -f1
}

count_sentinel() {
	local token="$1"
	local log_path="$2"
	grep -aE "^[[:space:]]*${token}([[:space:]]|:|$)" "$log_path" | wc -l || true
}

count_matches() {
	local pattern="$1"
	local log_path="$2"
	grep -aEi "$pattern" "$log_path" | wc -l || true
}

tail_nonempty_line() {
	local log_path="$1"
	grep -aE '.' "$log_path" | tail -n 1 | tr -d '\r'
}

collect_file_hashes() {
	local output_path="$1"
	printf 'path,sha256\n' > "$output_path"
	while IFS= read -r -d '' file; do
		[[ "$file" == "$output_path" ]] && continue
		rel="${file#$RUN_DIR/}"
		sha="$(sha256sum "$file" | cut -d' ' -f1)"
		printf '%s,%s\n' "$rel" "$sha" >> "$output_path"
	done < <(find "$RUN_DIR" -type f -print0 | sort -z)
}

now_ms() {
	local ms
	ms="$(date +%s%3N)"
	if [[ -z "${ms##*[!0-9]*}" ]]; then
		ms="$(( $(date +%s) * 1000 ))"
	fi
	printf '%s' "$ms"
}

# ---------------------------------------------------------------------------
# Import gate
# ---------------------------------------------------------------------------
# A fresh worktree has no .godot/, and `--headless --script` cannot resolve
# class_name globals without it: every suite dies with a parse error. Warming it
# is therefore mandatory, and it must happen exactly once, before any concurrent
# suite starts, because a cold cache is the one window in which parallel Godot
# processes would all write to .godot/ at the same time.
import_gate_ran="false"
import_gate_exit=""
import_gate_duration_ms=""
import_gate_restored_files=""

run_import_gate() {
	local gate_log="$LOG_DIR/_import_gate.log"
	local snapshot_dir="$WORK_DIR/root-config-snapshot"
	mkdir -p "$snapshot_dir"

	local file
	for file in "${PROTECTED_ROOT_FILES[@]}"; do
		if [[ -f "$PROJECT_ROOT/$file" ]]; then
			cp -p "$PROJECT_ROOT/$file" "$snapshot_dir/$file"
		fi
	done

	echo "Running Godot editor/import gate (populating .godot/) ..."
	local start_ms end_ms
	start_ms="$(now_ms)"
	set +e
	if (( HAVE_TIMEOUT_BIN == 1 )); then
		timeout "$(( TIMEOUT_SECONDS * 4 ))s" "$GODOT_BIN" --headless --editor --path "$PROJECT_ROOT" --quit > "$gate_log" 2>&1
	else
		"$GODOT_BIN" --headless --editor --path "$PROJECT_ROOT" --quit > "$gate_log" 2>&1
	fi
	import_gate_exit="$?"
	set -e
	end_ms="$(now_ms)"
	import_gate_duration_ms="$(( end_ms - start_ms ))"
	import_gate_ran="true"

	local restored=()
	for file in "${PROTECTED_ROOT_FILES[@]}"; do
		[[ -f "$snapshot_dir/$file" ]] || continue
		if ! cmp -s "$snapshot_dir/$file" "$PROJECT_ROOT/$file"; then
			diff -u "$snapshot_dir/$file" "$PROJECT_ROOT/$file" \
				> "$RUN_DIR/import-gate-rewrote-${file//\//_}.diff" || true
			cp -p "$snapshot_dir/$file" "$PROJECT_ROOT/$file"
			restored+=("$file")
		fi
	done

	if (( ${#restored[@]} > 0 )); then
		import_gate_restored_files="$(printf '%s ' "${restored[@]}")"
		import_gate_restored_files="${import_gate_restored_files% }"
		echo "WARNING: the editor/import gate rewrote ${import_gate_restored_files}; restored from snapshot."
		echo "         See ${RUN_DIR}/import-gate-rewrote-*.diff for what it tried to change."
	fi

	if (( import_gate_exit != 0 )); then
		echo "Editor/import gate failed with exit ${import_gate_exit}; see ${gate_log}"
		exit 1
	fi
	echo "Editor/import gate complete in ${import_gate_duration_ms} ms."
}

import_gate_needed="false"
case "$IMPORT_GATE" in
	always)
		import_gate_needed="true"
		;;
	auto)
		if [[ ! -f "$PROJECT_ROOT/.godot/global_script_class_cache.cfg" ]]; then
			import_gate_needed="true"
		fi
		;;
	never)
		import_gate_needed="false"
		;;
esac

if [[ "$import_gate_needed" == "true" ]]; then
	run_import_gate
fi

# ---------------------------------------------------------------------------
# Suite selection
# ---------------------------------------------------------------------------
# Resolved before the source manifest is hashed so that a mistyped --scope
# fails immediately instead of after a full-tree hash.
mapfile -d '' ALL_TEST_FILES < <(find "$PROJECT_ROOT/tests" -maxdepth 1 -type f -name '*_test.gd' -print0 | sort -z)
if (( ${#ALL_TEST_FILES[@]} == 0 )); then
	echo "No tests/*_test.gd files found under $PROJECT_ROOT/tests"
	exit 1
fi

# A SPEC matches a suite if it equals the suite name, the file name, the
# project-relative path or the absolute path, or if it globs any of those.
spec_matches() {
	local spec="$1"
	local abs="$2"
	local rel="${abs#$PROJECT_ROOT/}"
	local file="${abs##*/}"
	local name="${file%.gd}"
	local candidate
	for candidate in "$name" "$file" "$rel" "$abs"; do
		if [[ "$candidate" == "$spec" ]]; then
			return 0
		fi
		# shellcheck disable=SC2053 - glob matching is the point.
		if [[ "$candidate" == $spec ]]; then
			return 0
		fi
	done
	return 1
}

TEST_FILES=()
SCOPE_LABEL="all"
if (( ${#SCOPE_SPECS[@]} > 0 )); then
	declare -A selected=()
	unmatched=()
	for spec in "${SCOPE_SPECS[@]}"; do
		[[ -z "$spec" ]] && continue
		if [[ "$spec" == "@all" ]]; then
			for abs in "${ALL_TEST_FILES[@]}"; do
				selected["$abs"]=1
			done
			continue
		fi
		matched=0
		for abs in "${ALL_TEST_FILES[@]}"; do
			if spec_matches "$spec" "$abs"; then
				selected["$abs"]=1
				matched=1
			fi
		done
		if (( matched == 0 )); then
			unmatched+=("$spec")
		fi
	done
	if (( ${#unmatched[@]} > 0 )); then
		echo "No suite matched --scope spec(s): ${unmatched[*]}"
		echo "Suites live in tests/*_test.gd; pass a suite name, a path or a glob."
		exit 2
	fi
	# Re-derive the order from the sorted master list so that scope order never
	# leaks into the results ordering.
	for abs in "${ALL_TEST_FILES[@]}"; do
		if [[ -n "${selected[$abs]:-}" ]]; then
			TEST_FILES+=("$abs")
		fi
	done
	SCOPE_LABEL="$(printf '%s ' "${SCOPE_SPECS[@]}")"
	SCOPE_LABEL="${SCOPE_LABEL% }"
else
	TEST_FILES=("${ALL_TEST_FILES[@]}")
fi

if [[ -n "${TEST_MATRIX_TEST_FILTER:-}" ]]; then
	filtered_tests=()
	for test_file in "${TEST_FILES[@]}"; do
		if [[ "$test_file" =~ $TEST_MATRIX_TEST_FILTER ]]; then
			filtered_tests+=("$test_file")
		fi
	done
	TEST_FILES=("${filtered_tests[@]}")
fi
if (( ${#TEST_FILES[@]} == 0 )); then
	echo "No tests/*_test.gd files selected under $PROJECT_ROOT/tests"
	exit 1
fi

TOTAL_SUITES="${#TEST_FILES[@]}"
if (( JOBS > TOTAL_SUITES )); then
	EFFECTIVE_JOBS="$TOTAL_SUITES"
else
	EFFECTIVE_JOBS="$JOBS"
fi

# The import gate can create .import sidecars inside the manifest scope, so the
# "before" manifest is only meaningful once the gate has finished.
manifest_source_before="$RUN_DIR/source-manifest-before.csv"
collect_source_manifest "$manifest_source_before"
source_manifest_before_sha="$(sha256sum "$manifest_source_before" | cut -d' ' -f1)"
source_manifest_before_count="$(($(wc -l < "$manifest_source_before") - 1))"

results_tsv="$RUN_DIR/results.tsv"
results_canonical_tsv="$RUN_DIR/results-canonical.tsv"

overall_status="PASS"

# ---------------------------------------------------------------------------
# Per-suite worker
# ---------------------------------------------------------------------------
# Runs in a background subshell. Everything it produces is written to
# per-index files under WORK_DIR: nothing is printed directly, so parallel
# suites can never interleave a failure block with another suite's output.
run_suite_worker() {
	local index="$1"
	local test_file="$2"

	local relative_test_path="${test_file#$PROJECT_ROOT/}"
	local base_name
	base_name="$(basename "$test_file" .gd)"
	local base_upper
	base_upper="$(printf '%s' "$base_name" | tr '[:lower:]' '[:upper:]')"
	local res_path="res://$relative_test_path"
	local log_path="$LOG_DIR/${base_name}.log"
	local expected_ok="${base_upper}_OK"
	local expected_pass="${base_upper}_PASS"
	local sentinel_found=""

	local start_ms end_ms duration_ms exit_code
	start_ms="$(now_ms)"

	set +e
	local GODOT_ARGS=("$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script "$res_path")
	if [[ -n "$AUDIO_DRIVER" ]]; then
		GODOT_ARGS+=(--audio-driver "$AUDIO_DRIVER")
	fi

	if (( HAVE_TIMEOUT_BIN == 1 )); then
		timeout "${TIMEOUT_SECONDS}s" "${GODOT_ARGS[@]}" > "$log_path" 2>&1
		exit_code="$?"
	else
		"${GODOT_ARGS[@]}" > "$log_path" 2>&1
		exit_code="$?"
	fi
	set -e

	end_ms="$(now_ms)"
	duration_ms="$(( end_ms - start_ms ))"

	local pass_count diag_count ok_count pass_token_count sentinel_count
	pass_count="$(grep -aE '^PASS:' "$log_path" | wc -l || true)"
	pass_count="${pass_count//[[:space:]]/}"
	diag_count="$(count_matches "$DIAGNOSTIC_RE" "$log_path")"
	diag_count="${diag_count//[[:space:]]/}"
	ok_count="$(count_sentinel "$expected_ok" "$log_path" | tr -d ' ')"
	pass_token_count="$(count_sentinel "$expected_pass" "$log_path" | tr -d ' ')"
	sentinel_count=$((ok_count + pass_token_count))
	if (( ok_count > 0 )); then
		sentinel_found="$expected_ok"
	elif (( pass_token_count > 0 )); then
		sentinel_found="$expected_pass"
	fi
	local terminal_line log_sha terminal_sentinel
	terminal_line="$(tail_nonempty_line "$log_path" || true)"
	log_sha="$(sha256sum "$log_path" | cut -d' ' -f1)"
	terminal_sentinel=""
	if [[ "$terminal_line" =~ ^[[:space:]]*${expected_ok}([[:space:]]|:|$) ]]; then
		terminal_sentinel="$expected_ok"
	elif [[ "$terminal_line" =~ ^[[:space:]]*${expected_pass}([[:space:]]|:|$) ]]; then
		terminal_sentinel="$expected_pass"
	fi

	local reasons=()
	if (( exit_code != 0 )); then
		reasons+=("exit=$exit_code")
	fi
	if (( sentinel_count != 1 )); then
		reasons+=("sentinel_count=$sentinel_count (expected 1 of ${expected_ok} or ${expected_pass})")
	fi
	if [[ -n "$sentinel_found" && -n "$terminal_sentinel" && "$terminal_sentinel" != "$sentinel_found" ]]; then
		reasons+=("sentinel_not_terminal=${terminal_line:-<missing>}")
	fi
	if [[ -n "$sentinel_found" && -z "$terminal_sentinel" ]]; then
		reasons+=("sentinel_missing_terminal=${terminal_line:-<empty>}")
	fi
	if [[ -z "$sentinel_found" && -z "$terminal_sentinel" ]]; then
		reasons+=("no_sentinel_found")
	fi
	if (( diag_count != 0 )); then
		reasons+=("diagnostic_count=$diag_count")
	fi

	local status reason_text
	if (( ${#reasons[@]} > 0 )); then
		status="FAIL"
		reason_text="$(printf '%s; ' "${reasons[@]}")"
		reason_text="${reason_text%; }"
	else
		status="PASS"
		reason_text=""
	fi

	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$relative_test_path" \
		"$status" \
		"$exit_code" \
		"${sentinel_found:-<none>}" \
		"$sentinel_count" \
		"$pass_count" \
		"$diag_count" \
		"$duration_ms" \
		"$log_path" \
		"$log_sha" \
		"$reason_text" > "$WORK_DIR/$index.tsv"

	# Completion-order-independent record used for run-to-run comparison: no
	# durations, no absolute paths.
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$relative_test_path" \
		"$status" \
		"$exit_code" \
		"${sentinel_found:-<none>}" \
		"$sentinel_count" \
		"$pass_count" \
		"$diag_count" \
		"$reason_text" > "$WORK_DIR/$index.canonical"

	{
		printf '[%s] %s: status=%s exit=%s sentinel=%s pass=%s diag=%s duration_ms=%s\n' \
			"$(date -u +%H:%M:%S)" \
			"$base_name" \
			"$status" \
			"$exit_code" \
			"${sentinel_found:-<none>}" \
			"$pass_count" \
			"$diag_count" \
			"$duration_ms"
		if [[ "$status" == "FAIL" ]]; then
			printf '    reasons: %s\n' "$reason_text"
			printf '    log: %s\n' "$log_path"
			local diag_lines
			diag_lines="$(grep -aEi "$DIAGNOSTIC_RE" "$log_path" | head -n 8 || true)"
			if [[ -n "$diag_lines" ]]; then
				printf '    diagnostics:\n'
				printf '      %s\n' "$diag_lines"
			fi
			printf '    terminal_line: %s\n' "${terminal_line:-<empty>}"
		fi
	} > "$WORK_DIR/$index.console"

	printf '%s' "$status" > "$WORK_DIR/$index.status"
	: > "$WORK_DIR/$index.done"
	exit 0
}

echo "Test matrix: ${TOTAL_SUITES} suite(s), jobs=${EFFECTIVE_JOBS}, timeout=${TIMEOUT_SECONDS}s, scope=${SCOPE_LABEL}"
echo "Run directory: ${RUN_DIR}"
echo

godot_cache_before_sha="$(godot_cache_signature)"
suite_phase_start_ms="$(now_ms)"

flushed=0
flush_ready() {
	while (( flushed < TOTAL_SUITES )) && [[ -f "$WORK_DIR/$flushed.done" ]]; do
		cat "$WORK_DIR/$flushed.console"
		flushed=$(( flushed + 1 ))
	done
}

next=0
running=0
while (( next < TOTAL_SUITES || running > 0 )); do
	while (( running < EFFECTIVE_JOBS && next < TOTAL_SUITES )); do
		run_suite_worker "$next" "${TEST_FILES[$next]}" &
		running=$(( running + 1 ))
		next=$(( next + 1 ))
	done
	if (( running > 0 )); then
		wait -n 2>/dev/null || true
		running=$(( running - 1 ))
	fi
	flush_ready
done
wait 2>/dev/null || true
flush_ready

suite_phase_end_ms="$(now_ms)"
suite_phase_duration_ms="$(( suite_phase_end_ms - suite_phase_start_ms ))"
godot_cache_after_sha="$(godot_cache_signature)"

# ---------------------------------------------------------------------------
# Deterministic assembly, in sorted suite order
# ---------------------------------------------------------------------------
printf 'test_path\tstatus\texit_code\tsentinel\tsentinel_count\tpass_assertions\tdiagnostic_count\tduration_ms\tlog_path\tlog_sha256\treasons\n' > "$results_tsv"
printf 'test_path\tstatus\texit_code\tsentinel\tsentinel_count\tpass_assertions\tdiagnostic_count\treasons\n' > "$results_canonical_tsv"

failed_suites=()
total_pass_assertions=0
for (( index = 0; index < TOTAL_SUITES; index++ )); do
	test_file="${TEST_FILES[$index]}"
	relative_test_path="${test_file#$PROJECT_ROOT/}"
	if [[ ! -f "$WORK_DIR/$index.tsv" ]]; then
		# A worker that dies before recording is itself a failure, and it must
		# never be able to silently shrink the results table.
		printf '%s\tFAIL\t-1\t<none>\t0\t0\t0\t0\t%s\t-\tharness_error=worker produced no result record\n' \
			"$relative_test_path" "$LOG_DIR/$(basename "$test_file" .gd).log" >> "$results_tsv"
		printf '%s\tFAIL\t-1\t<none>\t0\t0\t0\tharness_error=worker produced no result record\n' \
			"$relative_test_path" >> "$results_canonical_tsv"
		failed_suites+=("$relative_test_path (harness_error: no result record)")
		overall_status="FAIL"
		echo "[harness] ${relative_test_path}: worker produced no result record"
		continue
	fi
	cat "$WORK_DIR/$index.tsv" >> "$results_tsv"
	cat "$WORK_DIR/$index.canonical" >> "$results_canonical_tsv"
	suite_status="$(cat "$WORK_DIR/$index.status")"
	suite_passes="$(cut -f6 < "$WORK_DIR/$index.canonical")"
	if [[ "$suite_passes" =~ ^[0-9]+$ ]]; then
		total_pass_assertions=$(( total_pass_assertions + suite_passes ))
	fi
	if [[ "$suite_status" != "PASS" ]]; then
		overall_status="FAIL"
		failed_suites+=("$relative_test_path :: $(cut -f8 < "$WORK_DIR/$index.canonical")")
	fi
done

results_canonical_sha="$(sha256sum "$results_canonical_tsv" | cut -d' ' -f1)"

manifest_source_after="$RUN_DIR/source-manifest-after.csv"
collect_source_manifest "$manifest_source_after"
source_manifest_after_sha="$(sha256sum "$manifest_source_after" | cut -d' ' -f1)"
source_manifest_after_count="$(($(wc -l < "$manifest_source_after") - 1))"

source_manifest_match="false"
: > "$RUN_DIR/source-manifest-diff.txt"
if [[ "$source_manifest_before_sha" == "$source_manifest_after_sha" ]]; then
	source_manifest_match="true"
else
	overall_status="FAIL"
	diff -u "$manifest_source_before" "$manifest_source_after" > "$RUN_DIR/source-manifest-diff.txt" || true
fi

godot_cache_stable="true"
if [[ "$godot_cache_before_sha" != "$godot_cache_after_sha" ]]; then
	godot_cache_stable="false"
fi

if [[ "$godot_cache_stable" != "true" ]]; then
	echo
	echo "WARNING: the shared Godot import cache (.godot/) changed while suites were running."
	echo "         before=${godot_cache_before_sha} after=${godot_cache_after_sha}"
	if (( EFFECTIVE_JOBS > 1 )) && [[ "$ALLOW_CACHE_DRIFT" != "1" ]]; then
		echo "         Concurrent suites sharing a mutating import cache can corrupt each"
		echo "         other, so this run is reported as FAIL. Re-run with --jobs 1, or set"
		echo "         TEST_MATRIX_ALLOW_CACHE_DRIFT=1 if the drift is understood."
		overall_status="FAIL"
	fi
fi

result_hashes="$RUN_DIR/result-file-hashes.csv"
collect_file_hashes "$result_hashes"
result_hashes_sha="$(sha256sum "$result_hashes" | cut -d' ' -f1)"

manifest="$RUN_DIR/run-manifest.txt"
cat > "$manifest" <<EOF
run_id=${RUN_ID}
run_started_utc=${RUN_STARTED_UTC}
run_completed_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
godot_binary=${GODOT_BIN}
timeout_seconds=${TIMEOUT_SECONDS}
audio_driver=${AUDIO_DRIVER}
project_root=${PROJECT_ROOT}
overall_status=${overall_status}
total_suites=${TOTAL_SUITES}
source_manifest_before_sha=${source_manifest_before_sha}
source_manifest_after_sha=${source_manifest_after_sha}
source_manifest_match=${source_manifest_match}
source_manifest_before_count=${source_manifest_before_count}
source_manifest_after_count=${source_manifest_after_count}
results_tsv=${results_tsv}
result_hashes=${result_hashes}
result_hashes_sha=${result_hashes_sha}
source_manifest_before=${manifest_source_before}
source_manifest_after=${manifest_source_after}
source_manifest_diff=${RUN_DIR}/source-manifest-diff.txt
log_dir=${LOG_DIR}
jobs_requested=${JOBS}
jobs_effective=${EFFECTIVE_JOBS}
scope_specs=${SCOPE_LABEL}
manifest_scope=$(printf '%s ' "${SCOPE_PATHS[@]}" | sed 's/ $//')
suite_phase_duration_ms=${suite_phase_duration_ms}
total_pass_assertions=${total_pass_assertions}
failed_suite_count=${#failed_suites[@]}
results_canonical_tsv=${results_canonical_tsv}
results_canonical_sha=${results_canonical_sha}
import_gate_mode=${IMPORT_GATE}
import_gate_ran=${import_gate_ran}
import_gate_exit=${import_gate_exit}
import_gate_duration_ms=${import_gate_duration_ms}
import_gate_restored_files=${import_gate_restored_files}
godot_cache_before_sha=${godot_cache_before_sha}
godot_cache_after_sha=${godot_cache_after_sha}
godot_cache_stable=${godot_cache_stable}
EOF

echo
if (( ${#failed_suites[@]} > 0 )); then
	echo "Failing suites (${#failed_suites[@]}):"
	for entry in "${failed_suites[@]}"; do
		echo "  - ${entry}"
	done
	echo
fi
echo "Test matrix complete."
echo "Run manifest: ${manifest}"
echo "Results TSV: ${results_tsv}"
echo "Canonical results TSV: ${results_canonical_tsv} (sha256 ${results_canonical_sha})"
echo "Log directory: ${LOG_DIR}"
echo "Suites: ${TOTAL_SUITES} at jobs=${EFFECTIVE_JOBS} in ${suite_phase_duration_ms} ms"
echo "Pass assertions: ${total_pass_assertions}"
echo "Source manifest match: ${source_manifest_match}"
echo "Godot import cache stable: ${godot_cache_stable}"
echo "Overall status: ${overall_status}"

if [[ "$overall_status" != "PASS" ]]; then
	exit 1
fi
