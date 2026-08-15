#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="${1:-artifacts/matrix/$(date -u +%Y%m%d_%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
TIMEOUT_SECONDS="${2:-120}"
GODOT_BIN="${3:-godot}"
AUDIO_DRIVER="${MATRIX_AUDIO_DRIVER:-Dummy}"

mkdir -p "$OUT_DIR/logs"

MANIFEST_PATH="$OUT_DIR/source_manifest.txt"
SUMMARY_PATH="$OUT_DIR/matrix_summary.csv"
RESULTS_PATH="$OUT_DIR/matrix_results.json"

mapfile -t SUITES < <(find tests -maxdepth 1 -type f -name '*_test.gd' | sort)

{
  printf "test,exit_code,sentinel_count,sentinel_line,assertion_count,diagnostic_hits,log_sha256,log_bytes\n"
} > "$SUMMARY_PATH"

{
  printf '{\n'
  printf '  "run_id": "%s",\n' "$(date -u +%Y%m%d_%H%M%S)"
  printf '  "git_head": "%s",\n' "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf '  "suite_count": %d,\n' "${#SUITES[@]}"
  printf '  "timeout_seconds": %s,\n' "$TIMEOUT_SECONDS"
  printf '  "godot": "%s",\n' "$GODOT_BIN"
} > "$RESULTS_PATH"

# Capture a deterministic source manifest before execution.
git ls-files | sort > "$MANIFEST_PATH"
manifest_before_sha=$(sha256sum "$MANIFEST_PATH" | awk '{print $1}')
echo "source_manifest_before_sha256=$manifest_before_sha"

failures=0

for suite in "${SUITES[@]}"; do
  suite_name="$(basename "$suite")"
  log_path="$OUT_DIR/logs/${suite_name%.gd}.log"
  echo "RUN $suite"

  exit_code=0
  GODOT_ARGS=("$GODOT_BIN" --headless --path . --script "$suite")
  if [[ -n "$AUDIO_DRIVER" ]]; then
    GODOT_ARGS+=(--audio-driver "$AUDIO_DRIVER")
  fi
  if ! timeout "$TIMEOUT_SECONDS" "${GODOT_ARGS[@]}" >"$log_path" 2>&1; then
    exit_code=$?
  fi

  sentinel_lines=$(grep -E '^[A-Z0-9_]+_(OK|PASS)(:|$)' "$log_path" | tr -d '\r')
  sentinel_count=0
  sentinel_line=""
  if [[ -n "$sentinel_lines" ]]; then
    sentinel_count=$(printf '%s\n' "$sentinel_lines" | awk 'END{print NR}')
    sentinel_line=$(printf '%s\n' "$sentinel_lines" | tail -n 1)
  fi

  assertion_count=$(printf '%s\n' "$sentinel_lines" | tail -n 1 | grep -Eo '[0-9]+' | tail -n 1 || true)

  diagnostics=$(grep -E "SCRIPT ERROR|\\bFATAL\\b|\\bERROR\\b|FAIL:|ObjectDB|Resource .*still in use|Orphan|Leaked" "$log_path" || true)
  diagnostic_count=$(printf '%s\n' "$diagnostics" | awk 'BEGIN{n=0} /./{n++} END{print n}')
  log_sha=$(sha256sum "$log_path" | awk '{print $1}')
  log_bytes=$(stat -c '%s' "$log_path")

  sentinel_escaped=$(printf '%s' "$sentinel_line" | sed 's/"/\\"/g')
  printf '%s,%s,%s,"%s",%s,%s,%s,%s\n' \
    "$suite_name" \
    "$exit_code" \
    "$sentinel_count" \
    "$sentinel_escaped" \
    "${assertion_count:-0}" \
    "$diagnostic_count" \
    "$log_sha" \
    "$log_bytes" >> "$SUMMARY_PATH"

  if [[ "$exit_code" -ne 0 || "$sentinel_count" -ne 1 || "$diagnostic_count" -ne 0 ]]; then
    failures=$((failures+1))
    if [[ "$exit_code" -ne 0 ]]; then
      echo "FAILURE: ${suite_name} exited code ${exit_code}"
    fi
    if [[ "$sentinel_count" -ne 1 ]]; then
      echo "FAILURE: ${suite_name} terminal-sentinel count=${sentinel_count}"
    fi
    if [[ "$diagnostic_count" -ne 0 ]]; then
      echo "FAILURE: ${suite_name} found ${diagnostic_count} diagnostic matches"
    fi
  fi

done

manifest_after_sha=$(sha256sum "$MANIFEST_PATH" | awk '{print $1}')
manifest_match="false"
if [[ "$manifest_before_sha" == "$manifest_after_sha" ]]; then
  manifest_match="true"
fi

{
  printf '  "manifest_before_sha256": "%s",\n' "$manifest_before_sha"
  printf '  "manifest_after_sha256": "%s",\n' "$manifest_after_sha"
  printf '  "manifest_unchanged": %s,\n' "$manifest_match"
  printf '  "suite_failures": %s,\n' "$failures"
  printf '  "log_directory": "%s",\n' "$OUT_DIR/logs"
  printf '  "summary_csv": "%s"\n' "$SUMMARY_PATH"
  printf '}\n'
} >> "$RESULTS_PATH"

if [[ "$manifest_match" != "true" ]]; then
  echo "FAILURE: source manifest hash changed during test run"
  git status --short
  exit 1
fi

if [[ "$failures" -ne 0 ]]; then
  echo "FAILURE: matrix detected ${failures} failing suites"
  exit 1
fi

echo "MATRIX_OK suites=${#SUITES[@]} manifest=$manifest_before_sha"
