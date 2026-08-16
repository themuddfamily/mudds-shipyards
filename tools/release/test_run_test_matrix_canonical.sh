#!/usr/bin/env bash
# Focused MATRIX-001 contract check. It uses a fake Godot executable so it can
# prove the evidence invariant without opening Godot or running the full matrix.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MATRIX="$SCRIPT_DIR/run_test_matrix.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matrix-canonical-check-XXXXXX")"

cleanup() {
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT

FAKE_GODOT="$WORK_DIR/fake-godot"
cat > "$FAKE_GODOT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

script_path=""
previous=""
for argument in "$@"; do
	if [[ "$previous" == "--script" ]]; then
		script_path="$argument"
		break
	fi
	previous="$argument"
done

if [[ -n "$script_path" ]]; then
	base_name="${script_path##*/}"
	base_name="${base_name%.gd}"
	base_upper="$(printf '%s' "$base_name" | tr '[:lower:]' '[:upper:]')"
	if [[ -n "${MATRIX_FAKE_USER_DATA_RECORD:-}" ]]; then
		printf '%s\t%s\n' "$script_path" "${XDG_DATA_HOME:?}" \
			>> "$MATRIX_FAKE_USER_DATA_RECORD"
	fi
	for (( assertion = 1; assertion <= ${MATRIX_FAKE_ASSERTIONS:-1}; assertion++ )); do
		printf 'PASS: measured_distance=%s assertion=%s\n' "${MATRIX_FAKE_MEASUREMENT:?}" "$assertion"
	done
	if [[ "${MATRIX_FAKE_DIAGNOSTIC:-0}" == "1" ]]; then
		printf 'ERROR: synthetic diagnostic %s\n' "${MATRIX_FAKE_MEASUREMENT:?}"
	fi
	printf '%s_OK\n' "$base_upper"
fi
EOF
chmod +x "$FAKE_GODOT"

FAKE_BIN="$WORK_DIR/fake-bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/date" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *" +%s%3N "* ]]; then
	index=0
	if [[ -f "${MATRIX_FAKE_DATE_STATE:?}" ]]; then
		index="$(<"$MATRIX_FAKE_DATE_STATE")"
	fi
	printf '%s' "$(( index + 1 ))" > "$MATRIX_FAKE_DATE_STATE"
	case "$index" in
		0) printf '1000\n' ;; # suite phase start
		1) printf '2000\n' ;; # suite start
		2) printf '1900\n' ;; # suite end: wall clock moved backwards
		*) printf '3000\n' ;; # suite phase end and any later reads
	esac
	else
		exec /usr/bin/date "$@"
fi
EOF
chmod +x "$FAKE_BIN/date"

FIRST="$WORK_DIR/results/first"
SECOND="$WORK_DIR/results/second"
ASSERTION_CHANGED="$WORK_DIR/results/assertion-changed"

# Run IDs are supplied through the environment to leave the command-line
# interface unchanged and exercise the same artifact layout as a real run.
TEST_MATRIX_RUN_ID=first MATRIX_FAKE_MEASUREMENT=1.234567 \
	"$MATRIX" --godot "$FAKE_GODOT" --import-gate never --jobs 1 \
	--results-dir "$WORK_DIR/results" --scope smoke_test \
	--manifest-scope tests/smoke_test.gd >/dev/null
TEST_MATRIX_RUN_ID=second MATRIX_FAKE_MEASUREMENT=9.876543 \
	"$MATRIX" --godot "$FAKE_GODOT" --import-gate never --jobs 1 \
	--results-dir "$WORK_DIR/results" --scope smoke_test \
	--manifest-scope tests/smoke_test.gd >/dev/null
TEST_MATRIX_RUN_ID=assertion-changed MATRIX_FAKE_MEASUREMENT=9.876543 MATRIX_FAKE_ASSERTIONS=2 \
	"$MATRIX" --godot "$FAKE_GODOT" --import-gate never --jobs 1 \
	--results-dir "$WORK_DIR/results" --scope smoke_test \
	--manifest-scope tests/smoke_test.gd >/dev/null

cmp "$FIRST/results-canonical.tsv" "$SECOND/results-canonical.tsv"
! cmp -s "$FIRST/logs/smoke_test.log" "$SECOND/logs/smoke_test.log"
grep -Fx $'tests/smoke_test.gd\tPASS\t0\tSMOKE_TEST_OK\t1\t1\t0\t' "$FIRST/results-canonical.tsv" >/dev/null
! cmp -s "$SECOND/results-canonical.tsv" "$ASSERTION_CHANGED/results-canonical.tsv"
grep -Fx $'tests/smoke_test.gd\tPASS\t0\tSMOKE_TEST_OK\t1\t2\t0\t' "$ASSERTION_CHANGED/results-canonical.tsv" >/dev/null

# A raw diagnostic remains a hard failure even though its numeric text is not
# part of canonical evidence.
if TEST_MATRIX_RUN_ID=diagnostic MATRIX_FAKE_MEASUREMENT=42 MATRIX_FAKE_DIAGNOSTIC=1 \
	"$MATRIX" --godot "$FAKE_GODOT" --import-gate never --jobs 1 \
	--results-dir "$WORK_DIR/results" --scope smoke_test \
	--manifest-scope tests/smoke_test.gd >/dev/null 2>&1; then
	echo "expected synthetic diagnostic to fail the matrix" >&2
	exit 1
fi
grep -Fx $'tests/smoke_test.gd\tFAIL\t0\tSMOKE_TEST_OK\t1\t1\t1\tdiagnostic_detected' \
	"$WORK_DIR/results/diagnostic/results-canonical.tsv" >/dev/null

# Duration measurement is observational: a backwards wall-clock correction is
# clamped to zero rather than contaminating results.tsv with a negative value.
TEST_MATRIX_RUN_ID=clock-backward MATRIX_FAKE_MEASUREMENT=7 MATRIX_FAKE_DATE_STATE="$WORK_DIR/date-state" \
	PATH="$FAKE_BIN:$PATH" "$MATRIX" --godot "$FAKE_GODOT" --import-gate never --jobs 1 \
	--results-dir "$WORK_DIR/results" --scope smoke_test \
	--manifest-scope tests/smoke_test.gd >/dev/null
awk -F '\t' 'NR == 2 { exit $8 != 0 }' "$WORK_DIR/results/clock-backward/results.tsv"

# Production startup writes real atomic settings/recovery state. The matrix must
# give every suite a distinct temporary XDG data root so parallel workers cannot
# touch the developer's `user://` files or each other's lifecycle markers.
USER_DATA_RECORD="$WORK_DIR/user-data-record.tsv"
TEST_MATRIX_RUN_ID=user-data-isolation MATRIX_FAKE_MEASUREMENT=8 \
	MATRIX_FAKE_USER_DATA_RECORD="$USER_DATA_RECORD" \
	"$MATRIX" --godot "$FAKE_GODOT" --import-gate never --jobs 1 \
	--results-dir "$WORK_DIR/results" --scope smoke_test,ship_command_test \
	--manifest-scope tests/smoke_test.gd,tests/ship_command_test.gd >/dev/null
[[ "$(wc -l < "$USER_DATA_RECORD")" -eq 2 ]]
[[ "$(cut -f2 "$USER_DATA_RECORD" | sort -u | wc -l)" -eq 2 ]]
grep -E $'^res://tests/smoke_test.gd\t.*/user-data/smoke_test$' \
	"$USER_DATA_RECORD" >/dev/null
grep -E $'^res://tests/ship_command_test.gd\t.*/user-data/ship_command_test$' \
	"$USER_DATA_RECORD" >/dev/null
grep -Fx 'suite_user_data_isolated=true' \
	"$WORK_DIR/results/user-data-isolation/run-manifest.txt" >/dev/null

echo "matrix canonical evidence check: PASS"
