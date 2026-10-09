#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

# --in-world-interruption runs one actual kill/restart; --activity=beacon or
# --activity=mining, --activity=scan, --activity=hulk or --activity=stationdefense selects unpaid recovery
# (pilot only); default remains convoy.
# --source selects the current project instead of PACKAGE_PATH; source
# and PCK identities are recorded separately and neither qualifies native input.
# --native-export runs PACKAGE_PATH's embedded Linux game directly; it cannot
# accept external source, pack or script overrides.
IN_WORLD_INTERRUPTION=0
SOURCE_MODE=0
NATIVE_EXPORT=0
PROBE_ACTIVITY="${PACKAGE_PROBE_ACTIVITY:-convoy}"
ACTIVITY_FLAG_SEEN=0
for argument in "$@"; do
  case "$argument" in
    --in-world-interruption) IN_WORLD_INTERRUPTION=1 ;;
    --source) SOURCE_MODE=1 ;;
    --native-export) NATIVE_EXPORT=1 ;;
    --activity=*)
      if (( ACTIVITY_FLAG_SEEN == 1 )); then echo "Duplicate interruption activity selector" >&2; exit 2; fi
      ACTIVITY_FLAG_SEEN=1
      PROBE_ACTIVITY="${argument#--activity=}" ;;
    *) echo "Unknown package probe option: $argument" >&2; exit 2 ;;
  esac
done
if (( SOURCE_MODE == 1 && IN_WORLD_INTERRUPTION == 0 )); then
  echo "--source requires --in-world-interruption" >&2
  exit 2
fi
if (( NATIVE_EXPORT == 1 && (IN_WORLD_INTERRUPTION == 0 || SOURCE_MODE == 1) )); then
  echo "--native-export requires --in-world-interruption and forbids --source" >&2
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
if [[ "$PROBE_ACTIVITY" != convoy && "$PROBE_ACTIVITY" != beacon && "$PROBE_ACTIVITY" != mining && "$PROBE_ACTIVITY" != stationdefense && "$PROBE_ACTIVITY" != scan && "$PROBE_ACTIVITY" != hulk ]]; then
  echo "Invalid interruption activity" >&2
  exit 2
fi
if (( IN_WORLD_INTERRUPTION == 0 )) && { (( ACTIVITY_FLAG_SEEN == 1 )) || [[ "$PROBE_ACTIVITY" != convoy ]]; }; then
  echo "Activity selection requires --in-world-interruption" >&2
  exit 2
fi
if [[ "$RECOVERY_CONTEXT" != pilot && "$RECOVERY_CONTEXT" != cabin && "$RECOVERY_CONTEXT" != rest && "$RECOVERY_CONTEXT" != crew && "$RECOVERY_CONTEXT" != engineer ]]; then
  echo "Invalid interruption recovery context" >&2
  exit 2
fi
if [[ ( "$PROBE_ACTIVITY" == beacon || "$PROBE_ACTIVITY" == mining || "$PROBE_ACTIVITY" == stationdefense || "$PROBE_ACTIVITY" == scan || "$PROBE_ACTIVITY" == hulk ) && "$RECOVERY_CONTEXT" != pilot ]]; then
  echo "$PROBE_ACTIVITY interruption currently requires pilot context" >&2
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

if (( NATIVE_EXPORT == 0 )) && ! command -v "$GODOT_BIN" >/dev/null; then
  echo "Godot binary not found: $GODOT_BIN"
  exit 2
fi

if [[ "$RECOVERY_CONTEXT" == engineer ]] && ! command -v Xvfb >/dev/null; then
  echo "Engineer interruption requires driver-owned Xvfb" >&2
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
  env -u DISPLAY -u WAYLAND_DISPLAY PYTHONDONTWRITEBYTECODE=1 python3 - "$PROJECT_ROOT" "$GODOT_BIN" "$PACKAGE_PATH" "$SOURCE_MODE" "$TIMEOUT_SECONDS" "$RUN_DIR" "$PROBE_WORK_DIR" "$RECOVERY_CONTEXT" "$NATIVE_EXPORT" "$PROBE_ACTIVITY" <<'PYPROBE' &
import hashlib, json, os, pathlib, re, secrets, select, signal, subprocess, sys, time
root, godot, package, source_mode, timeout, run_dir, profile, recovery_context, native_export, activity = sys.argv[1:]
root, run_dir, profile = map(pathlib.Path, (root, run_dir, profile))
timeout = int(timeout)
source_mode = source_mode == "1"
native_export = native_export == "1"
result_path = run_dir / "in-world-interruption.json"
driver_commit = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
result = {"status": "FAIL", "mode": "native_export" if native_export else ("source" if source_mode else "PCK"),
          "project_root": str(root), "private_profile": str(profile), "package": None if source_mode else package,
          "source_commit": None if native_export else driver_commit,
          "native_gpu": "NOT_RUN", "normal_controls": "NOT_RUN",
          "pilot_seat_world_restore": "NOT_RUN", "recovery_context": recovery_context, "activity": activity, "processes": []}
if native_export:
    result["driver_source_commit"] = driver_commit
children = []
private_display = None
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
for key in ("DISPLAY", "WAYLAND_DISPLAY", "MUDDS_PRIVATE_PROBE_INPUT"):
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
    # Input-only dummy rendering retains the private display, real input and
    # physics. The engineer fixture never inherits the caller's display.
    display_options = (["--display-driver", "x11", "--disable-render-loop", "--rendering-driver", "dummy"]
                       if recovery_context == "engineer" else ["--headless"])
    if native_export:
        command = [package, *display_options, "--audio-driver", "Dummy"]
    else:
        command = [godot, *display_options, "--audio-driver", "Dummy", "--path", str(root)]
        if not source_mode:
            command += ["--main-pack", package]
    command += ["--in-world-interruption-stage=" + stage, "--in-world-interruption-context=" + recovery_context]
    command += ["--in-world-interruption-activity=" + activity]
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
    if recovery_context == "engineer":
        # An explicit high display and -displayfd confirm this exact child's
        # ownership. Abstract local sockets work even when WSLg mounts the
        # desktop's filesystem socket directory read-only; never use that path.
        read_fd, write_fd = os.pipe()
        display_log = run_dir / "logs/private-x11.log"
        requested_display = str(100 + secrets.randbelow(10000))
        require(not os.path.lexists("/tmp/.X11-unix/X" + requested_display), "private display collides with a filesystem socket")
        display_command = ["Xvfb", ":" + requested_display, "-displayfd", str(write_fd), "-screen", "0", "1280x720x24",
                           "-nolisten", "tcp", "-nolisten", "unix", "-ac"]
        try:
            with display_log.open("w") as output:
                registering_child = True
                try:
                    private_display = subprocess.Popen(display_command, pass_fds=(write_fd,), stdout=output,
                                                       stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                                       env=environment, start_new_session=True)
                    result["private_display"] = {"pid": private_display.pid, "arguments": display_command,
                                                 "log": str(display_log)}
                finally:
                    registering_child = False
                    if pending_abort is not None:
                        abort_probe(pending_abort)
            os.close(write_fd)
            write_fd = None
            display_deadline = time.monotonic() + 15
            display_bytes = b""
            while b"\n" not in display_bytes:
                require(bool(select.select([read_fd], [], [], max(0, display_deadline - time.monotonic()))[0]),
                        "private Xvfb did not publish its display")
                chunk = os.read(read_fd, 32)
                require(bool(chunk) and len(display_bytes) + len(chunk) <= 32, "private Xvfb display acknowledgement was incomplete")
                display_bytes += chunk
            display_number = display_bytes.decode().strip()
            require(display_number == requested_display and private_display.poll() is None
                    and not os.path.lexists("/tmp/.X11-unix/X" + display_number), "private Xvfb refused display ownership")
            environment["DISPLAY"] = ":" + display_number
            environment["MUDDS_PRIVATE_PROBE_INPUT"] = "engineer-x11"
            result["private_display"]["display"] = environment["DISPLAY"]
        finally:
            os.close(read_fd)
            if write_fd is not None:
                os.close(write_fd)
    if native_export:
        # SIGKILL must own the actual game, never a Windows interop wrapper.
        require(sys.platform.startswith("linux"), "native-export interruption requires a Linux host")
        binary = pathlib.Path(package).resolve()
        with binary.open("rb") as stream:
            header = stream.read(20)
        require(header[:6] == b"\x7fELF\x02\x01" and int.from_bytes(header[18:20], "little") == 62,
                "native-export requires a Linux x86_64 ELF binary")
        require(os.access(binary, os.X_OK), "native-export binary is not executable")
        metadata_path = pathlib.Path(str(binary) + ".export-result.json")
        metadata = json.loads(metadata_path.read_text())
        require(metadata.get("schema_version") == 1 and metadata.get("platform") == "linux",
                "native-export requires the existing Linux export metadata")
        require(metadata.get("binary", {}).get("sha256") == result["package_sha256"]
                and metadata.get("binary", {}).get("bytes") == binary.stat().st_size,
                "native-export metadata does not match the executable")
        require(re.fullmatch(r"[0-9a-f]{40}", metadata.get("source_commit", "")) is not None,
                "native-export metadata has no exact compiled source identity")
        # The driver can be newer than the immutable game it qualifies.
        result["source_commit"] = metadata["source_commit"]
        result["export_metadata_sha256"] = digest(metadata_path)
        package = str(binary)
        result["package"] = package
    arm, arm_log, arm_entry = start("arm")
    deadline = time.monotonic() + timeout
    ready = None
    while time.monotonic() < deadline:
        ready = token(arm_log, "IN_WORLD_INTERRUPTION_READY")
        if ready is not None:
            break
        require(arm.poll() is None, "arm process exited before actual durable readiness")
        require(not diagnostics(arm_log), "arm engine/script diagnostics before readiness")
        time.sleep(0.1)
    require(ready is not None and arm.poll() is None, "missing live IN_WORLD_INTERRUPTION_READY")
    require(not diagnostics(arm_log), "arm engine/script diagnostics")
    require(ready.get("recovery_context") == recovery_context, "arm ignored the selected recovery context")
    require(ready.get("entry") == "startup_completed", "arm did not use Boot's own loaded Main")
    require(ready.get("activity", "convoy") == activity, "arm ignored the selected activity")
    before = document.read_bytes()
    saved = json.loads(before)
    if activity == "hulk":
        terminal = saved["payload"]["cinder_hulk_power_session"]
        require(terminal == ready["boundary"] and terminal == {"schema_version": 1,
                "activity_id": "cinder_hulk_power_restoration", "state": 2, "generation": 1, "elapsed_seconds": 3},
                "hulk readiness has no genuine supported full earned terminal")
        require(ready["receipts"] == 0
                and saved["payload"].get("game_flow_reward_store", {}).get("reward_counts", {}).get("hulk_auxiliary_power_cell", 0) == 0
                and ready["runtime_observation"]["craft_piloted"] is True
                and ready["runtime_observation"]["player_seated"] is True,
                "hulk arm has no genuine unpaid completion and real pilot ownership")
        require(saved["payload"]["runtime_settings"] == ready["foreign_settings"]
                and saved["payload"]["jovian_cargo_session"] == ready["foreign_cargo"],
                "hulk arm lost unrelated production settings/cargo")
    elif activity == "stationdefense":
        terminal = saved["payload"]["station_defense_session"]
        session = terminal["session"]
        completion = session["completion"]
        require(terminal == ready["boundary"] and terminal["schema_version"] == 1
                and terminal["payload_kind"] == "nearby_sector_activity_session"
                and terminal["slot_id"] == "station_defense_session" and session["schema_version"] == 2,
                "defense readiness differs from the actual supported saved terminal")
        require(session["history"]["activity_id"] == "shipyard_perimeter_defense"
                and session["history"]["state_id"] == "completed"
                and session["history"]["generation"] == completion["generation"] > 0
                and session["history"]["reward_handoff_generation"] == 0
                and completion["activity_id"] == "shipyard_perimeter_defense"
                and completion["reward_requested"] is True and completion["reward_granted"] is False,
                "defense readiness has no genuine completed unpaid report")
        require(ready["armed_elapsed_seconds"] == 10.5 and ready["receipts"] == 0
                and ready["runtime_observation"]["craft_piloted"] is True
                and ready["runtime_observation"]["player_seated"] is True,
                "defense arm lacks genuine authored-wave elapsed observation or real pilot ownership")
        require(saved["payload"]["runtime_settings"] == ready["foreign_settings"]
                and saved["payload"]["jovian_cargo_session"] == ready["foreign_cargo"]
                and saved["payload"]["game_flow_reward_store"]["reward_counts"] == ready["foreign_reward_counts"]
                and ready["foreign_reward_counts"].get("debris_route_navigation_data") == 1,
                "defense arm lost production settings/cargo or the genuinely earned unrelated beacon reward")
    elif activity == "mining":
        terminal = saved["payload"]["cinder_mining_capacity"]
        session = terminal["session"]
        require(terminal == ready["boundary"] and terminal["schema_version"] == 2
                and terminal["payload_kind"] == "cinder_mining_capacity_receipt"
                and terminal["slot_id"] == "cinder_mining_capacity", "mining readiness differs from actual saved session")
        require(session == {"state": 2, "generation": 1, "elapsed_seconds": 6,
                            "reward_requested": False, "capacity_paid": False}
                and terminal["capacity"] == {} and ready["receipts"] == 0,
                "mining readiness has no genuine generation-one full unpaid terminal")
        require(ready["runtime_observation"]["craft_piloted"] is True
                and ready["runtime_observation"]["player_seated"] is True, "mining arm has no real pilot")
        require(not pathlib.Path(str(document) + ".tmp").exists(), "mining blockage remains at kill boundary")
        require(saved["payload"]["runtime_settings"] == ready["foreign_settings"]
                and saved["payload"]["mining_probe_foreign_cargo"] == ready["foreign_cargo"],
                "mining arm lost unrelated settings or cargo")
    elif activity == "scan":
        terminal = saved["payload"]["cinder_structure_scan_session"]
        row = terminal["activities"][0]
        require(terminal == ready["boundary"] and terminal["schema_version"] == 1
                and len(terminal["activities"]) == 1, "scan readiness differs from actual saved session")
        require(row["activity_id"] == "cinder_derelict_structure_scan" and row["generation"] == 1
                and row["state"] == 2 and row["progress"]["elapsed_seconds"] == 4
                and row["progress"]["generation"] == row["generation"]
                and row["reward_requested"] is True and row["reward_granted"] is False
                and row["progress"]["reward_requested"] is False, "scan readiness has no genuine unpaid terminal")
        require(ready["runtime_observation"]["craft_piloted"] is True
                and ready["runtime_observation"]["player_seated"] is True, "scan arm has no real pilot")
        counts = saved["payload"].get("game_flow_reward_store", {}).get("reward_counts", {})
        require(counts.get("derelict_material_sample", 0) == ready["receipts"], "scan baseline differs from saved reward ledger")
        require(saved["payload"]["runtime_settings"] == ready["foreign_settings"]
                and saved["payload"]["jovian_cargo_session"] == ready["foreign_cargo"],
                "scan arm lost production settings or cargo")
    elif activity == "beacon":
        terminal = saved["payload"]["cinder_beacon_session"]
        row = terminal["activities"][0]
        require(terminal == ready["boundary"] and terminal["schema_version"] == 1
                and len(terminal["activities"]) == 1, "beacon readiness differs from actual saved session")
        require(row["activity_id"] == "cinder_debris_beacon_traversal" and row["generation"] > 0
                and row["state"] == 2 and row["progress"]["next_beacon_index"] == 4
                and row["progress"]["generation"] == row["generation"]
                and row["reward_requested"] is True and row["reward_granted"] is False
                and row["progress"]["reward_requested"] is False, "beacon readiness has no valid unpaid terminal")
        require(ready["runtime_observation"]["craft_piloted"] is True
                and ready["runtime_observation"]["player_seated"] is True, "beacon arm has no real pilot")
        counts = saved["payload"].get("game_flow_reward_store", {}).get("reward_counts", {})
        require(counts.get("debris_route_navigation_data", 0) == ready["receipts"], "beacon baseline differs from saved reward ledger")
    else:
        row = saved["payload"]["cinder_convoy_session"]["activities"][0]
        require(row["progress"]["convoy_session_state"] == ready["boundary"], "readiness differs from real durable document")
        if recovery_context == "engineer":
            context = saved["payload"]["solo_safe_recovery"]
            observed = ready["runtime_observation"]
            require(context == ready["safe_context"] and len(context) == 4
                    and context["mode"] == "crew" and context["craft_id"] == "jovian_provisional"
                    and ready["boundary"]["escort_ship_id"] == "jovian_provisional"
                    and row["state"] == 3 and ready["receipts"] == 1,
                    "engineer readiness has no genuine four-field crew preference and failed Jovian convoy")
            require(observed["craft_id"] == "jovian_provisional" and observed["player_seated"] is True
                    and observed["craft_piloted"] is False and observed["player_sleeping"] is False
                    and ready["engineer_observation"]["assignment"]["role"] == "engineer",
                    "engineer readiness has no actual ordinary engineer owner")
            require(saved["payload"]["runtime_settings"] == ready["foreign_settings"]
                    and saved["payload"]["jovian_cargo_session"] == ready["foreign_cargo"],
                    "engineer arm lost actual settings or cargo")
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
    require(recovered.get("activity", "convoy") == activity, "restart ignored the selected activity")
    require(resume_log.read_text(errors="replace").strip().splitlines()[-1].startswith("IN_WORLD_RECOVERY_OK: "), "recovery token is not terminal")
    require(recovered["boundary"] == ready["boundary"], "fresh process changed durable host/threat/escort/clock/progress")
    require(recovered["receipts_before"] == ready["receipts"] and recovered["receipts_after"] == ready["receipts"] + (0 if recovery_context == "engineer" else 1),
            "restart lost or duplicated the activity receipt")
    require(recovered["crash_events"] == 1, "actual interruption did not publish one crash event")
    after = document.read_bytes()
    final = json.loads(after)
    if activity == "hulk":
        paid = final["payload"]["cinder_hulk_power_session"]
        safe = recovered["safe_recovery_observation"]
        require(safe["craft_piloted"] is True and safe["player_seated"] is True
                and safe["craft_id"] == ready["runtime_observation"]["craft_id"],
                "hulk restart did not reacquire the actual saved safe-home pilot")
        require(paid == terminal == recovered["paid_boundary"]
                and final["payload"]["game_flow_reward_store"]["reward_counts"]["hulk_auxiliary_power_cell"] == 1
                and recovered["payment_commit"]["id"].startswith("game-flow-reward-"),
                "hulk retry changed the earned terminal or lost/duplicated its durable cell receipt")
        require(final["payload"]["runtime_settings"] == ready["foreign_settings"] == recovered["foreign_settings"]
                and final["payload"]["jovian_cargo_session"] == ready["foreign_cargo"] == recovered["foreign_cargo"],
                "hulk recovery changed unrelated production settings/cargo")
    elif activity == "stationdefense":
        paid = final["payload"]["station_defense_session"]
        safe = recovered["safe_recovery_observation"]
        require(safe["craft_piloted"] is True and safe["player_seated"] is True
                and safe["craft_id"] == ready["runtime_observation"]["craft_id"],
                "defense restart did not reacquire the real saved safe-home pilot")
        require(paid == recovered["paid_boundary"]
                and paid["session"]["completion"] == {**completion, "reward_granted": True}
                and paid["session"]["history"] == {**session["history"], "reward_handoff_generation": completion["generation"]}
                and recovered["payment_commit"]["id"].startswith("game-flow-reward-"),
                "defense retry changed the earned generation or lost the atomic reward acknowledgement")
        counts = final["payload"]["game_flow_reward_store"]["reward_counts"]
        require(counts.get("return_defense_report_to_shipyard") == 1
                and all(counts.get(key) == value for key, value in ready["foreign_reward_counts"].items()),
                "defense retry lost or duplicated its report or the unrelated genuine reward")
        require(final["payload"]["runtime_settings"] == ready["foreign_settings"] == recovered["foreign_settings"]
                and final["payload"]["jovian_cargo_session"] == ready["foreign_cargo"] == recovered["foreign_cargo"],
                "defense recovery changed actual unrelated settings/cargo")
        require(recovered["active_combat_restore"] == "NOT_SUPPORTED" and recovered["elapsed_timer_restore"] == "NOT_SUPPORTED",
                "defense probe must retain the delivered safe-history-only restoration limit")
    elif activity == "mining":
        paid = final["payload"]["cinder_mining_capacity"]
        safe = recovered["safe_recovery_observation"]
        require(safe["craft_piloted"] is True and safe["player_seated"] is True
                and safe["craft_id"] == ready["runtime_observation"]["craft_id"],
                "mining restart did not reacquire the actual saved pilot craft")
        require(paid == recovered["paid_boundary"] and recovered["capacity_commits"] == 1
                and paid["session"] == {**session, "reward_requested": True, "capacity_paid": True},
                "mining retry changed the genuine timer/generation or duplicated its atomic paid acknowledgement")
        require(paid["capacity"]["activity_id"] == "cinder_platform_mining_run"
                and paid["capacity"]["extraction_seconds"] == 6
                and paid["capacity"]["reward_receipt"] == {"activity_id": "cinder_platform_mining_run",
                    "reward_id": "cinder_raw_ore_sample", "granted": False, "replay_allowed": False},
                "mining restart has no actual durable non-granting capacity receipt")
        require(final["payload"]["runtime_settings"] == ready["foreign_settings"] == recovered["foreign_settings"]
                and final["payload"]["mining_probe_foreign_cargo"] == ready["foreign_cargo"] == recovered["foreign_cargo"],
                "mining recovery changed unrelated settings or cargo fields")
    elif activity == "scan":
        paid = final["payload"]["cinder_structure_scan_session"]
        safe = recovered["safe_recovery_observation"]
        require(safe["craft_piloted"] is True and safe["player_seated"] is True
                and safe["craft_id"] == ready["runtime_observation"]["craft_id"],
                "scan restart did not reacquire the actual saved safe-home pilot craft")
        paid_row = paid["activities"][0]
        require(paid == recovered["paid_boundary"]
                and paid_row == {**row, "reward_granted": True,
                                 "progress": {**row["progress"], "reward_requested": True}},
                "scan retry changed genuine generation/progress or lost its atomic payment acknowledgement")
        require(final["payload"]["game_flow_reward_store"]["reward_counts"]["derelict_material_sample"] == ready["receipts"] + 1,
                "scan retry lost or duplicated the actual saved material-sample payment")
        require(final["payload"]["runtime_settings"] == ready["foreign_settings"] == recovered["foreign_settings"]
                and final["payload"]["jovian_cargo_session"] == ready["foreign_cargo"] == recovered["foreign_cargo"],
                "scan recovery changed actual settings or cargo")
    elif activity == "beacon":
        paid = final["payload"]["cinder_beacon_session"]
        safe = recovered["safe_recovery_observation"]
        require(safe["craft_piloted"] is True and safe["player_seated"] is True
                and safe["craft_id"] == ready["runtime_observation"]["craft_id"],
                "beacon restart did not reacquire the actual saved pilot craft")
        require(paid == recovered["paid_boundary"] and paid["activities"][0]["reward_granted"] is True
                and paid["activities"][0]["progress"]["reward_requested"] is True,
                "restarted beacon has no actual durable payment acknowledgement")
        require(paid["activities"][0]["generation"] == row["generation"]
                and paid["activities"][0]["progress"]["next_beacon_index"] == row["progress"]["next_beacon_index"],
                "beacon retry changed its legitimate terminal generation or cursor")
        require(final["payload"]["game_flow_reward_store"]["reward_counts"]["debris_route_navigation_data"] == ready["receipts"] + 1,
                "beacon retry lost or duplicated the actual saved navigation-data payment")

    if recovery_context == "engineer":
        safe = recovered["safe_recovery_observation"]
        repair = recovered["repair_observation"]
        require(safe["craft_id"] == "jovian_provisional" and safe["player_seated"] is False
                and safe["craft_piloted"] is False and safe["player_sleeping"] is False
                and safe["player_on_floor"] is True and safe["player_control_enabled"] is True
                and safe["cabin_containment"] is True,
                "engineer cold Resume did not return usable awake home cabin ownership")
        require(recovered["safe_context"] == ready["safe_context"]
                and repair["kits_before"] == 6 and repair["kits_after"] == 5
                and 0 <= repair["integrity_before"] < repair["integrity_after"] <= 1,
                "engineer recovery did not commit genuine finite-kit component repair")
        require(final["payload"]["runtime_settings"] == ready["foreign_settings"] == recovered["foreign_settings"]
                and final["payload"]["jovian_cargo_session"] == ready["foreign_cargo"] == recovered["foreign_cargo"]
                and final["payload"]["game_flow_reward_store"]["reward_counts"]["return_convoy_credit_to_shipyard"] == 1,
                "engineer recovery changed settings, cargo or the actual first convoy payment")
        require(recovered["live_seat_work_restore"] == "NOT_SUPPORTED"
                and recovered["repair_inventory_restore"] == "NOT_SUPPORTED"
                and recovered["airborne_pose_restore"] == "NOT_SUPPORTED",
                "engineer probe must retain the existing safe-preference-only restoration limit")
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
    if private_display is not None:
        if private_display.poll() is None:
            private_display.terminate()
            try:
                private_display.wait(timeout=15)
            except subprocess.TimeoutExpired:
                private_display.kill()
                private_display.wait(timeout=15)
        result["private_display"]["exit_code"] = private_display.returncode
        result["private_display"]["reaped"] = True
        result["private_display"]["log_sha256"] = digest(pathlib.Path(result["private_display"]["log"]))
    if document.exists():
        (run_dir / "document-at-exit.json").write_bytes(document.read_bytes())
    result["owned_children_reaped"] = (all(process.poll() is not None for process in children)
                                       and (private_display is None or private_display.poll() is not None))
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
    if native_export and "export_metadata_sha256" in result and digest(metadata_path) != result["export_metadata_sha256"]:
        result["status"] = "FAIL"
        result["failure"] = "export metadata changed during interruption check"
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
