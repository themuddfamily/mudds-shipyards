#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

# --in-world-interruption runs one actual kill/restart of the existing convoy
# fixture. --source selects the current project instead of PACKAGE_PATH; source
# and PCK identities are recorded separately and neither qualifies native input.
IN_WORLD_INTERRUPTION=0
SOURCE_MODE=0
for argument in "$@"; do
  case "$argument" in
    --in-world-interruption) IN_WORLD_INTERRUPTION=1 ;;
    --source) SOURCE_MODE=1 ;;
    *) echo "Unknown package probe option: $argument" >&2; exit 2 ;;
  esac
done
if (( SOURCE_MODE == 1 && IN_WORLD_INTERRUPTION == 0 )); then
  echo "--source requires --in-world-interruption" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PACKAGE_PATH="${PACKAGE_PATH:-$PROJECT_ROOT/builds/windows/MuddsShipyards.exe}"
GODOT_BIN="${GODOT_BIN:-godot}"
TIMEOUT_SECONDS="${PACKAGE_PROBE_TIMEOUT_SECONDS:-300}"
RESULTS_ROOT="${PACKAGE_PROBE_RESULTS_ROOT:-$PROJECT_ROOT/artifacts/package-probes}"
RUN_ID="${PACKAGE_PROBE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
AUDIO_DRIVER="${PACKAGE_PROBE_AUDIO_DRIVER:-Dummy}"
RECOVERY_CONTEXT="${PACKAGE_PROBE_RECOVERY_CONTEXT:-pilot}"
if [[ "$RECOVERY_CONTEXT" != pilot && "$RECOVERY_CONTEXT" != cabin && "$RECOVERY_CONTEXT" != rest && "$RECOVERY_CONTEXT" != crew ]]; then
  echo "Invalid interruption recovery context" >&2
  exit 2
fi

if [[ "$AUDIO_DRIVER" != Dummy ]]; then
  echo "Automated package probe audio requires --audio-driver Dummy"
  exit 2
fi

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "Invalid timeout: $TIMEOUT_SECONDS"
  exit 2
fi

if (( SOURCE_MODE == 0 )) && ! [[ -f "$PACKAGE_PATH" ]]; then
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

# Keep every probe independent of caller saves and earlier interrupted probes.
# Scratch remains outside the published results, matching the source matrix.
PROBE_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/package-probes-XXXXXX")"
trap 'rm -rf -- "$PROBE_WORK_DIR"' EXIT

if (( IN_WORLD_INTERRUPTION == 1 )); then
  interruption_driver_pid=""
  interruption_cancel_status=0
  forward_interruption_cancel() {
    # Once cancellation begins, no repeated signal may interrupt the final wait.
    trap '' INT TERM HUP
    interruption_cancel_status="$1"
    if [[ -n "$interruption_driver_pid" ]]; then
      kill -TERM "$interruption_driver_pid" 2>/dev/null || true
    fi
  }
  cleanup_interruption() {
    local status=$?
    trap - EXIT INT TERM HUP
    if [[ -n "$interruption_driver_pid" ]]; then
      kill -TERM "$interruption_driver_pid" 2>/dev/null || true
      wait "$interruption_driver_pid" 2>/dev/null || true
    fi
    rm -rf -- "$PROBE_WORK_DIR"
    exit "$status"
  }
  trap cleanup_interruption EXIT
  trap 'forward_interruption_cancel 130' INT
  trap 'forward_interruption_cancel 143' TERM
  trap 'forward_interruption_cancel 129' HUP
  env -u DISPLAY -u WAYLAND_DISPLAY PYTHONDONTWRITEBYTECODE=1 python3 - "$PROJECT_ROOT" "$GODOT_BIN" "$PACKAGE_PATH" "$SOURCE_MODE" "$TIMEOUT_SECONDS" "$RUN_DIR" "$PROBE_WORK_DIR" "$RECOVERY_CONTEXT" <<'PYPROBE' &
import hashlib, json, os, pathlib, re, signal, subprocess, sys, time
root, godot, package, source_mode, timeout, run_dir, profile, recovery_context = sys.argv[1:]
root, run_dir, profile = map(pathlib.Path, (root, run_dir, profile))
timeout = int(timeout)
source_mode = source_mode == "1"
result_path = run_dir / "in-world-interruption.json"
result = {"status": "FAIL", "mode": "source" if source_mode else "PCK",
          "project_root": str(root), "private_profile": str(profile), "package": None if source_mode else package,
          "source_commit": subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(),
          "native_gpu": "NOT_RUN", "normal_controls": "NOT_RUN",
          "pilot_seat_world_restore": "NOT_RUN", "recovery_context": recovery_context, "processes": []}
children = []
registering_child = False
pending_abort = None
require_new_result = not result_path.exists()
if not require_new_result:
    raise RuntimeError("refusing to overwrite an earlier interruption result")
def abort_probe(signum, _frame=None):
    global pending_abort
    # A signal during Popen must not strand the newly created OS process before
    # its exact handle and result entry have been registered for final cleanup.
    if registering_child:
        pending_abort = pending_abort or signum
        return
    # Repeated cancellation cannot interrupt the narrowly owned final cleanup.
    for handled in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(handled, signal.SIG_IGN)
    result["cancelled_by"] = signal.Signals(signum).name
    raise RuntimeError("interruption probe cancelled by " + signal.Signals(signum).name)
for handled in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
    signal.signal(handled, abort_probe)
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def manifest(name, scope):
    path = run_dir / name
    subprocess.run([sys.executable, str(root / "tools/release/source_manifest.py"),
                    "--root", str(root), "--output", str(path), *scope], check=True)
    return digest(path)
def require(condition, message):
    if not condition:
        raise RuntimeError(message)
def token(log, name):
    lines = [line[len(name) + 2:] for line in log.read_text(errors="replace").splitlines(keepends=True)
             if line.endswith("\n") and line.startswith(name + ": ")]
    require(len(lines) <= 1, "duplicate " + name)
    return json.loads(lines[0]) if lines else None
def diagnostics(log):
    expression = r"^\s*(?:SCRIPT\s+ERROR|ERROR:|FAIL:)|\b(?:FATAL ERROR|ObjectDB|Orphaned|Leaked)\b|Resource.*still in use"
    return [line for line in log.read_text(errors="replace").splitlines()
            if re.search(expression, line, re.I)]
scope = ["project.godot", "export_presets.cfg", "default_bus_layout.tres", "scripts", "scenes", "tests", "assets", "tools", "art_source"]
source_before = manifest("source-before.csv", scope)
cache_before = manifest("cache-before.csv", [".godot"])
if not source_mode:
    result["package_sha256"] = digest(pathlib.Path(package))
environment = os.environ.copy()
for key in ("DISPLAY", "WAYLAND_DISPLAY"):
    environment.pop(key, None)
for key, directory in {"HOME": "home", "XDG_DATA_HOME": "data", "XDG_CONFIG_HOME": "config",
                       "XDG_CACHE_HOME": "cache", "XDG_STATE_HOME": "state", "XDG_RUNTIME_DIR": "runtime"}.items():
    path = profile / directory
    path.mkdir(mode=0o700)
    environment[key] = str(path)
document = profile / "data/godot/app_userdata/Mudds Shipyards/mudds_user_data.json"
def start(stage):
    global registering_child
    log = run_dir / "logs" / (stage + ".log")
    command = [godot, "--headless", "--audio-driver", "Dummy", "--path", str(root)]
    if not source_mode:
        command += ["--main-pack", package]
    command += ["--in-world-interruption-stage=" + stage, "--in-world-interruption-context=" + recovery_context]
    with log.open("w") as output:
        registering_child = True
        try:
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                                       stdin=subprocess.DEVNULL, env=environment, start_new_session=True)
            children.append(process)
            entry = {"stage": stage, "pid": process.pid, "arguments": command, "log": str(log)}
            result["processes"].append(entry)
        finally:
            registering_child = False
            if pending_abort is not None:
                abort_probe(pending_abort)
    return process, log, entry
try:
    arm, arm_log, arm_entry = start("arm")
    deadline = time.monotonic() + timeout
    ready = None
    while time.monotonic() < deadline:
        ready = token(arm_log, "IN_WORLD_INTERRUPTION_READY")
        if ready is not None:
            break
        require(arm.poll() is None, "arm process exited before actual durable readiness")
        time.sleep(0.1)
    require(ready is not None and arm.poll() is None, "missing live IN_WORLD_INTERRUPTION_READY")
    require(not diagnostics(arm_log), "arm engine/script diagnostics")
    require(ready.get("recovery_context") == recovery_context, "arm ignored the selected recovery context")
    require(ready.get("entry") == "startup_completed", "arm did not use Boot's own loaded Main")
    before = document.read_bytes()
    saved = json.loads(before)
    row = saved["payload"]["cinder_convoy_session"]["activities"][0]
    require(row["progress"]["convoy_session_state"] == ready["boundary"], "readiness differs from real durable document")
    require(saved["payload"]["crash_recovery"]["state"] == "running", "no durable running marker before kill")
    (run_dir / "interrupted-document.json").write_bytes(before)
    # Kill this exact Popen handle only. No PID search, external desktop or
    # orderly game teardown can substitute for this actual OS interruption.
    arm.kill()
    arm_entry["exit_code"] = arm.wait(timeout=15)
    arm_entry["signal"] = "SIGKILL"
    require(arm_entry["exit_code"] == -9, "owned kill did not reap as SIGKILL (-9)")
    require(document.read_bytes() == before, "kill ran an orderly repair/save")
    result["ready"] = ready
    resume, resume_log, resume_entry = start("resume")
    resume_entry["exit_code"] = resume.wait(timeout=timeout)
    recovered = token(resume_log, "IN_WORLD_RECOVERY_OK")
    require(resume_entry["exit_code"] == 0 and recovered is not None, "restart did not exit 0 with IN_WORLD_RECOVERY_OK")
    require(not diagnostics(resume_log), "restart engine/script diagnostics")
    require(recovered.get("recovery_context") == recovery_context, "restart ignored the selected recovery context")
    require(recovered.get("entry") == "startup_completed", "restart did not use Boot's own loaded Main")
    require(resume_log.read_text(errors="replace").strip().splitlines()[-1].startswith("IN_WORLD_RECOVERY_OK: "), "recovery token is not terminal")
    require(recovered["boundary"] == ready["boundary"], "fresh process changed durable host/threat/escort/clock/progress")
    require(recovered["receipts_before"] == ready["receipts"] and recovered["receipts_after"] == ready["receipts"] + 1,
            "restart lost or duplicated convoy credit")
    require(recovered["crash_events"] == 1, "actual interruption did not publish one crash event")
    after = document.read_bytes()
    final = json.loads(after)
    (run_dir / "recovered-document.json").write_bytes(after)
    result["recovered"] = recovered
    require(final["payload"]["crash_recovery"]["state"] == "clean" and final["payload"]["safe_start_recovery"]["state"] == "clean_shutdown",
            "recovered orderly process did not close both marker owners")
    result["status"] = "PASS"
except Exception as error:
    result["failure"] = str(error)
finally:
    for process in children:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=15)
            result["processes"][children.index(process)]["cleanup_killed"] = True
        result["processes"][children.index(process)]["exit_code"] = process.returncode
    if document.exists():
        (run_dir / "document-at-exit.json").write_bytes(document.read_bytes())
    result["owned_children_reaped"] = all(process.poll() is not None for process in children)
    for entry in result["processes"]:
        entry["log_sha256"] = digest(pathlib.Path(entry["log"]))
    result["source_before_sha256"] = source_before
    result["source_after_sha256"] = manifest("source-after.csv", scope)
    result["cache_before_sha256"] = cache_before
    result["cache_after_sha256"] = manifest("cache-after.csv", [".godot"])
    if result["source_before_sha256"] != result["source_after_sha256"] or result["cache_before_sha256"] != result["cache_after_sha256"]:
        result["status"] = "FAIL"
        result["failure"] = "source/import cache changed during interruption check"
    if not source_mode and digest(pathlib.Path(package)) != result["package_sha256"]:
        result["status"] = "FAIL"
        result["failure"] = "package changed during interruption check"
    result_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print("IN_WORLD_INTERRUPTION_CHECK_" + result["status"] + ": " + str(result_path))
sys.exit(0 if result["status"] == "PASS" else 1)
PYPROBE
  interruption_driver_pid=$!
  if (( interruption_cancel_status != 0 )); then
    forward_interruption_cancel "$interruption_cancel_status"
  fi
  set +e
  wait "$interruption_driver_pid"
  interruption_status=$?
  if (( interruption_cancel_status != 0 )); then
    # A trapped signal interrupts bash's first wait. Wait again for Python's
    # child cleanup before removing its private profile or returning to callers.
    wait "$interruption_driver_pid" 2>/dev/null
    interruption_status="$interruption_cancel_status"
  fi
  set -e
  interruption_driver_pid=""
  trap - INT TERM HUP
  exit "$interruption_status"
fi

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

  probe_scratch="$PROBE_WORK_DIR/$base_name"
  mkdir -p "$probe_scratch/data" "$probe_scratch/config" "$probe_scratch/cache"
  start_ms="$(date +%s%3N)"
  set +e
  env XDG_DATA_HOME="$probe_scratch/data" \
    XDG_CONFIG_HOME="$probe_scratch/config" XDG_CACHE_HOME="$probe_scratch/cache" \
    timeout "${TIMEOUT_SECONDS}s" "$GODOT_BIN" --headless --main-pack "$PACKAGE_PATH" --path "$PROJECT_ROOT" --audio-driver "$AUDIO_DRIVER" --script "res://$relative_test_path" > "$log_path" 2>&1
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
