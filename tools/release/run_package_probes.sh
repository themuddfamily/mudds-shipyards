#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PACKAGE_PATH="${PACKAGE_PATH:-$PROJECT_ROOT/builds/windows/MuddsShipyards.exe}"
GODOT_BIN="${GODOT_BIN:-godot}"
TIMEOUT_SECONDS="${PACKAGE_PROBE_TIMEOUT_SECONDS:-300}"
RESULTS_ROOT="${PACKAGE_PROBE_RESULTS_ROOT:-$PROJECT_ROOT/artifacts/package-probes}"
RUN_ID="${PACKAGE_PROBE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
AUDIO_DRIVER="${PACKAGE_PROBE_AUDIO_DRIVER:-Dummy}"

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "Invalid timeout: $TIMEOUT_SECONDS"
  exit 2
fi

if ! [[ -f "$PACKAGE_PATH" ]]; then
  echo "Package not found: $PACKAGE_PATH"
  exit 2
fi

if ! command -v "$GODOT_BIN" >/dev/null; then
  echo "Godot binary not found: $GODOT_BIN"
  exit 2
fi

if ! command -v timeout >/dev/null; then
  echo "timeout command not found"
  exit 2
fi

count_matches() {
  local pattern="$1"
  local log_path="$2"
  grep -aEi "$pattern" "$log_path" | wc -l || true
}

count_sentinel() {
  local token="$1"
  local log_path="$2"
  grep -aE "^[[:space:]]*${token}([[:space:]]|:|$)" "$log_path" | wc -l || true
}

RUN_DIR="$RESULTS_ROOT/$RUN_ID"
LOG_DIR="$RUN_DIR/logs"
mkdir -p "$LOG_DIR"

# Probe list can be overridden with a regex against file names (e.g. "*triplanar*").
DEFAULT_PROBES=(
  station_surface_playability_test.gd
  station_interaction_flow_test.gd
  station_triplanar_material_test.gd
  central_berth_hero_test.gd
)

PROBES=()
if [[ -n "${PACKAGE_PROBE_FILTER:-}" ]]; then
  for probe in "${DEFAULT_PROBES[@]}"; do
    if [[ "$probe" =~ $PACKAGE_PROBE_FILTER ]]; then
      PROBES+=("$probe")
    fi
  done
else
  PROBES=("${DEFAULT_PROBES[@]}")
fi

if (( ${#PROBES[@]} == 0 )); then
  echo "No probes selected"
  exit 1
fi

RESULT_TSV="$RUN_DIR/results.tsv"
printf 'test_path\tstatus\texit_code\tsentinel\tsentinel_count\tpass_assertions\tdiagnostic_count\tduration_ms\tlog_path\tlog_sha256\treasons\n' > "$RESULT_TSV"

overall_status="PASS"
run_started_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DIAGNOSTIC_RE='^[[:space:]]*SCRIPT[[:space:]]+ERROR|^[[:space:]]*ERROR:|\bFATAL ERROR\b|\bObjectDB\b|Resource.*still in use|\bOrphaned\b|\bLeaked\b|\bObjectDB\b'

for test_file in "${PROBES[@]}"; do
  relative_test_path="tests/$test_file"
  base_name="${test_file%.gd}"
  base_upper="$(printf '%s' "$base_name" | tr '[:lower:]' '[:upper:]')"
  expected_ok="${base_upper}_OK"
  expected_pass="${base_upper}_PASS"
  log_path="$LOG_DIR/${base_name}.log"

  start_ms="$(date +%s%3N)"
  set +e
  if [[ -n "$AUDIO_DRIVER" ]]; then
    timeout "${TIMEOUT_SECONDS}s" "$GODOT_BIN" --headless --main-pack "$PACKAGE_PATH" --path "$PROJECT_ROOT" --audio-driver "$AUDIO_DRIVER" --script "res://$relative_test_path" > "$log_path" 2>&1
  else
    timeout "${TIMEOUT_SECONDS}s" "$GODOT_BIN" --headless --main-pack "$PACKAGE_PATH" --path "$PROJECT_ROOT" --script "res://$relative_test_path" > "$log_path" 2>&1
  fi
  exit_code=$?
  set -e

  end_ms="$(date +%s%3N)"
  duration_ms=$((end_ms - start_ms))
  pass_count="$(count_matches '^PASS:' "$log_path")"
  diag_count="$(count_matches "$DIAGNOSTIC_RE" "$log_path")"

  ok_count="$(count_sentinel "$expected_ok" "$log_path")"
  pass_token_count="$(count_sentinel "$expected_pass" "$log_path")"
  sentinel_count=$((ok_count + pass_token_count))

  terminal_line="$(grep -aE '.' "$log_path" | tail -n 1 | tr -d '\r')"
  sentinel_found=""
  if (( ok_count > 0 )); then
    sentinel_found="$expected_ok"
  elif (( pass_token_count > 0 )); then
    sentinel_found="$expected_pass"
  fi

  reasons=()
  if (( exit_code != 0 )); then
    reasons+=("exit=$exit_code")
  fi
  if (( sentinel_count != 1 )); then
    reasons+=("sentinel_count=$sentinel_count (expected 1 of ${expected_ok} or ${expected_pass})")
  fi
  if [[ -n "$sentinel_found" && -n "$terminal_line" && ! "$terminal_line" =~ ^[[:space:]]*${sentinel_found}([[:space:]]|:|$) ]]; then
    reasons+=("sentinel_not_terminal=${terminal_line:-<missing>}")
  fi
  if [[ -n "${DIAGNOSTIC_RE}" && "$diag_count" -ne 0 ]]; then
    reasons+=("diagnostic_count=$diag_count")
  fi

  status="PASS"
  reason_text=""
  if (( ${#reasons[@]} > 0 )); then
    status="FAIL"
    overall_status="FAIL"
    reason_text="$(printf '%s; ' "${reasons[@]}")"
    reason_text="${reason_text%; }"
  fi

  log_sha="$(sha256sum "$log_path" | cut -d' ' -f1)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$relative_test_path" "$status" "$exit_code" "${sentinel_found:-<none>}" "$sentinel_count" "$pass_count" "$diag_count" "$duration_ms" "$log_path" "$log_sha" "$reason_text" >> "$RESULT_TSV"

  printf '[%s] %s: status=%s exit=%s sentinel=%s pass=%s diag=%s duration_ms=%s\n' \
    "$(date -u +%H:%M:%S)" "$base_name" "$status" "$exit_code" "${sentinel_found:-<none>}" "$pass_count" "$diag_count" "$duration_ms"

done

run_completed_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
manifest="$RUN_DIR/run-manifest.txt"
{
  printf 'run_id=%s\n' "$RUN_ID"
  printf 'run_started_utc=%s\n' "$run_started_utc"
  printf 'run_completed_utc=%s\n' "$run_completed_utc"
  printf 'package_path=%s\n' "$PACKAGE_PATH"
  printf 'godot_binary=%s\n' "$GODOT_BIN"
  printf 'timeout_seconds=%s\n' "$TIMEOUT_SECONDS"
  printf 'overall_status=%s\n' "$overall_status"
  printf 'total_probes=%s\n' "${#PROBES[@]}"
  printf 'results_tsv=%s\n' "$RESULT_TSV"
  printf 'log_dir=%s\n' "$LOG_DIR"
} > "$manifest"

echo

echo "Package probe complete."
echo "Run manifest: ${manifest}"
echo "Results TSV: ${RESULT_TSV}"
echo "Log directory: ${LOG_DIR}"
echo "Overall status: ${overall_status}"

if [[ "$overall_status" != "PASS" ]]; then
  exit 1
fi
