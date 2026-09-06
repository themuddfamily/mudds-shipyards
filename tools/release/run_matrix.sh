#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="${1:-artifacts/matrix/$(date -u +%Y%m%d_%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
TIMEOUT_SECONDS="${2:-120}"
GODOT_BIN="${3:-godot}"
AUDIO_DRIVER="${MATRIX_AUDIO_DRIVER:-Dummy}"
if [[ "$AUDIO_DRIVER" != Dummy ]]; then
  echo "Automated test audio requires --audio-driver Dummy"; exit 2
fi

mkdir -p "$OUT_DIR/logs"

MANIFEST_PATH="$OUT_DIR/source_manifest.txt"
MANIFEST_AFTER_PATH="$OUT_DIR/source_manifest_after.txt"
SUMMARY_PATH="$OUT_DIR/matrix_summary.csv"
RESULTS_PATH="$OUT_DIR/matrix_results.json"

# Legacy CSV consumers keep their format; discovery and completion rules are shared
# with the primary runner. Select graphical explicitly via MATRIX_MODE.
MODE="${MATRIX_MODE:-headless}"
CATALOG="$ROOT_DIR/tools/release/test_suite_catalog.py"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
python3 "$CATALOG" --root "$ROOT_DIR" --mode "$MODE" > "$WORK_DIR/suites.tsv"
mapfile -t SUITES < <(cut -f1 "$WORK_DIR/suites.tsv")
declare -A SUITE_MODES=()
while IFS=$'\t' read -r suite kind; do SUITE_MODES["$suite"]="$kind"; done < "$WORK_DIR/suites.tsv"
if [[ "$MODE" != headless && -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  echo "Graphical suites require DISPLAY or WAYLAND_DISPLAY"; exit 2
fi
if (( ${#SUITES[@]} == 0 )); then echo "No suites selected"; exit 2; fi

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

# Capture identity, the current index inventory, and actual working-tree bytes.
# Refresh all three after execution; a saved filename list cannot detect edits.
capture_source_manifest() {
  printf 'HEAD %s\n' "$(git rev-parse HEAD)"
  git ls-files --stage
  while IFS= read -r -d '' source_path; do
    printf 'WORKTREE %q ' "$source_path"
    if [[ -L "$source_path" ]]; then
      printf 'symlink '
      readlink -z -- "$source_path" | sha256sum
    elif [[ -f "$source_path" ]]; then
      printf 'file '
      sha256sum < "$source_path"
    elif [[ -d "$source_path" ]]; then
      printf 'directory\n'
    else
      printf 'missing\n'
    fi
  done < <(git ls-files -z | sort -zu)
}

capture_source_manifest > "$MANIFEST_PATH"
manifest_before_sha=$(sha256sum "$MANIFEST_PATH" | awk '{print $1}')
echo "source_manifest_before_sha256=$manifest_before_sha"

failures=0

for suite in "${SUITES[@]}"; do
  suite_name="${suite#tests/}"
  log_path="$OUT_DIR/logs/${suite_name%.gd}.log"
  mkdir -p "$(dirname "$log_path")"
  suite_user_data_dir="$WORK_DIR/user-data/${suite_name%.gd}"
  mkdir -p "$suite_user_data_dir"
  source_copy="$WORK_DIR/source/$suite"
  mkdir -p "$(dirname "$source_copy")"
  cp "$suite" "$source_copy"
  echo "RUN $suite"

  exit_code=0
  GODOT_ARGS=("$GODOT_BIN" --path . --script "$suite")
  if [[ "${SUITE_MODES[$suite]}" == headless ]]; then GODOT_ARGS+=(--headless); fi
  if [[ -n "$AUDIO_DRIVER" ]]; then
    GODOT_ARGS+=(--audio-driver "$AUDIO_DRIVER")
  fi
  if env XDG_DATA_HOME="$suite_user_data_dir" timeout "$TIMEOUT_SECONDS" "${GODOT_ARGS[@]}" >"$log_path" 2>&1; then
    exit_code=0
  else
    exit_code=$?
  fi

  IFS=$'\t' read -r sentinel_line sentinel_count terminal_sentinel assertion_count < <(
    python3 "$CATALOG" --assess "$source_copy" "$log_path"
  )
  if [[ "$terminal_sentinel" != "$sentinel_line" ]]; then sentinel_count=0; fi

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

capture_source_manifest > "$MANIFEST_AFTER_PATH"
manifest_after_sha=$(sha256sum "$MANIFEST_AFTER_PATH" | awk '{print $1}')
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
