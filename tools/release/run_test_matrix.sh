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

DIAGNOSTIC_RE='^[[:space:]]*SCRIPT[[:space:]]+ERROR|^[[:space:]]*ERROR:|\\bFATAL ERROR\\b|\\bObjectDB\\b|Resource.*still in use|\\bOrphaned\\b|\\bLeaked\\b|\\bObjectDB\\b'

usage() {
	cat <<EOF
Usage: $(basename "$0") [--godot PATH] [--timeout SECONDS] [--results-dir DIR] [--audio-driver NAME]

Run every tests/*_test.gd file under Godot --headless and write a timestamped matrix manifest.

Environment variables:
  GODOT_BIN                 Defaults to \`godot\`.
  TEST_MATRIX_TIMEOUT_SECONDS Defaults to 180.
  TEST_MATRIX_RESULTS_ROOT   Defaults to artifacts/test-matrix.
  TEST_MATRIX_TEST_FILTER    Extended-regular-expression filter applied to tests/*_test.gd paths.
  TEST_MATRIX_AUDIO_DRIVER   Audio backend passed to --audio-driver (defaults to Dummy).
  TEST_MATRIX_RUN_ID         Override the timestamp label.
  --audio-driver NAME       Override TEST_MATRIX_AUDIO_DRIVER for this invocation.
EOF
}

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

if [[ ! -x "$GODOT_BIN" ]] && ! command -v "$GODOT_BIN" >/dev/null; then
	echo "Godot binary not found: $GODOT_BIN"
	exit 2
fi

RUN_DIR="$RUN_RESULTS_ROOT/$RUN_ID"
LOG_DIR="$RUN_DIR/logs"
mkdir -p "$LOG_DIR"

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

manifest_source_before="$RUN_DIR/source-manifest-before.csv"
collect_source_manifest "$manifest_source_before"
source_manifest_before_sha="$(sha256sum "$manifest_source_before" | cut -d' ' -f1)"
source_manifest_before_count="$(($(wc -l < "$manifest_source_before") - 1))"

mapfile -d '' TEST_FILES < <(find "$PROJECT_ROOT/tests" -maxdepth 1 -type f -name '*_test.gd' -print0 | sort -z)
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
	echo "No tests/*_test.gd files found under $PROJECT_ROOT/tests"
	exit 1
fi

results_tsv="$RUN_DIR/results.tsv"
printf 'test_path\tstatus\texit_code\tsentinel\tsentinel_count\tpass_assertions\tdiagnostic_count\tduration_ms\tlog_path\tlog_sha256\treasons\n' > "$results_tsv"

overall_status="PASS"

for test_file in "${TEST_FILES[@]}"; do
	relative_test_path="${test_file#$PROJECT_ROOT/}"
	base_name="$(basename "$test_file" .gd)"
	base_upper="$(printf '%s' "$base_name" | tr '[:lower:]' '[:upper:]')"
	res_path="res://$relative_test_path"
	log_path="$LOG_DIR/${base_name}.log"
	expected_ok="${base_upper}_OK"
	expected_pass="${base_upper}_PASS"
	sentinel_found=""

	start_ms="$(date +%s%3N)"
	if [[ -z "${start_ms##*[!0-9]*}" ]]; then
		start_ms="$(( $(date +%s) * 1000 ))"
	fi

	set +e
	GODOT_ARGS=("$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script "$res_path")
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

	end_ms="$(date +%s%3N)"
	if [[ -z "${end_ms##*[!0-9]*}" ]]; then
		end_ms="$(( $(date +%s) * 1000 ))"
	fi
	duration_ms="$(( end_ms - start_ms ))"

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
	terminal_line="$(tail_nonempty_line "$log_path")"
	log_sha="$(sha256sum "$log_path" | cut -d' ' -f1)"
	terminal_sentinel=""
	if [[ "$terminal_line" =~ ^[[:space:]]*${expected_ok}([[:space:]]|:|$) ]]; then
		terminal_sentinel="$expected_ok"
	elif [[ "$terminal_line" =~ ^[[:space:]]*${expected_pass}([[:space:]]|:|$) ]]; then
		terminal_sentinel="$expected_pass"
	fi

	reasons=()
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
	if (( ${#reasons[@]} > 0 )); then
		overall_status="FAIL"
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
		"$reason_text" >> "$results_tsv"

	echo "[$(date -u +%H:%M:%S)] ${base_name}: status=${status} exit=${exit_code} sentinel=${sentinel_found:-<none>} pass=${pass_count} diag=${diag_count} duration_ms=${duration_ms}"
done

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
total_suites=${#TEST_FILES[@]}
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
EOF

echo
echo "Test matrix complete."
echo "Run manifest: ${manifest}"
echo "Results TSV: ${results_tsv}"
echo "Log directory: ${LOG_DIR}"
echo "Source manifest match: ${source_manifest_match}"
echo "Overall status: ${overall_status}"

if [[ "$overall_status" != "PASS" ]]; then
	exit 1
fi
