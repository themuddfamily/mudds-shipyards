#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

# --in-world-interruption runs one actual kill/restart; --activity=beacon or
# --activity=mining, --activity=scan, --activity=hulk, --activity=stationdefense or
# --activity=breach selects unpaid recovery. Breach adds a further cold paid replay;
# its staged setup/direct target damage does not qualify ordinary combat.
# or --activity=ember selects a genuine interrupted planetary survey
# (pilot only); default remains convoy. PACKAGE_PROBE_RECOVERY_CONTEXT=on_foot
# selects the supported exterior Bulwark/home-berth convoy case. Context docking
# selects one real Bulwark assist cut, then cold home-pilot recovery and explicit
# reset/distinct escort continuation; it does not restore an approach pose. Ember excludes canonical outbound and
# standing-pose restore; each necessary visit discloses initial flight placement.
# --activity=ember-abandon cuts after a genuine first-relay save is explicitly
# declined while awaiting reboarding; cold recovery starts a new survey at zero.
# It does not qualify the abandon return home or completed earned-debt recovery.
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
if [[ "$PROBE_ACTIVITY" != convoy && "$PROBE_ACTIVITY" != beacon && "$PROBE_ACTIVITY" != mining && "$PROBE_ACTIVITY" != stationdefense && "$PROBE_ACTIVITY" != scan && "$PROBE_ACTIVITY" != hulk && "$PROBE_ACTIVITY" != ember && "$PROBE_ACTIVITY" != ember-abandon && "$PROBE_ACTIVITY" != breach ]]; then
  echo "Invalid interruption activity" >&2
  exit 2
fi
if (( IN_WORLD_INTERRUPTION == 0 )) && { (( ACTIVITY_FLAG_SEEN == 1 )) || [[ "$PROBE_ACTIVITY" != convoy ]]; }; then
  echo "Activity selection requires --in-world-interruption" >&2
  exit 2
fi
if [[ "$RECOVERY_CONTEXT" != pilot && "$RECOVERY_CONTEXT" != cabin && "$RECOVERY_CONTEXT" != rest && "$RECOVERY_CONTEXT" != crew && "$RECOVERY_CONTEXT" != engineer && "$RECOVERY_CONTEXT" != on_foot && "$RECOVERY_CONTEXT" != docking ]]; then
  echo "Invalid interruption recovery context" >&2
  exit 2
fi
if [[ "$RECOVERY_CONTEXT" == docking ]] && (( IN_WORLD_INTERRUPTION == 0 )); then
  echo "Docking context requires --in-world-interruption" >&2
  exit 2
fi
if [[ ( "$PROBE_ACTIVITY" == beacon || "$PROBE_ACTIVITY" == mining || "$PROBE_ACTIVITY" == stationdefense || "$PROBE_ACTIVITY" == scan || "$PROBE_ACTIVITY" == hulk || "$PROBE_ACTIVITY" == ember || "$PROBE_ACTIVITY" == ember-abandon || "$PROBE_ACTIVITY" == breach ) && "$RECOVERY_CONTEXT" != pilot ]]; then
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
def ember_document(observation, field):
    text = observation.get(field)
    require(isinstance(text, str) and bool(text), "missing actual Ember document text: " + field)
    document = json.loads(text)
    require(isinstance(document, dict) and isinstance(document.get("payload"), dict)
            and isinstance(document["payload"].get("ember_relay_survey_completion"), dict),
            "invalid actual Ember document text: " + field)
    return document
def ember_abandon_document(observation, field, expected_fresh_record=None):
    text = observation.get(field)
    require(isinstance(text, str) and bool(text), "missing actual Ember abandon document text: " + field)
    document = json.loads(text)
    require(isinstance(document, dict) and isinstance(document.get("payload"), dict)
            and (("ember_relay_survey_completion" not in document["payload"])
                 if expected_fresh_record is None else
                 document["payload"].get("ember_relay_survey_completion") == expected_fresh_record)
            and isinstance(document["payload"].get("ember_relay_survey_completion_declined"), dict),
            "invalid actual Ember abandon document text: " + field)
    return document
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
for key, directory in {"XDG_DATA_HOME": "data", "XDG_CONFIG_HOME": "config",
                       "XDG_CACHE_HOME": "cache", "XDG_STATE_HOME": "state", "XDG_RUNTIME_DIR": "runtime",
                       "XDG_DATA_DIRS": "data-dirs", "XDG_CONFIG_DIRS": "config-dirs", "TMPDIR": "tmp"}.items():
    path = profile / directory
    path.mkdir(mode=0o700)
    environment[key] = str(path)
document = profile / "data/godot/app_userdata/Mudds Shipyards/mudds_user_data.json"
def start(stage, leg=None):
    global registering_child
    log = run_dir / "logs" / ((leg or stage) + ".log")
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
            entry = {"stage": leg or stage, "cli_stage": stage, "pid": process.pid, "arguments": command, "log": str(log)}
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
    if activity in ("ember", "ember-abandon"):
        if activity == "ember":
            ready_document = ember_document(ready, "boundary_document_json")
            require(ready_document == saved, "Ember readiness document differs from the independently read save")
            journey_document = saved
        else:
            ready_document = ember_document(ready, "saved_document_json")
            # The synchronous decline CAS rotates the exact saved primary to
            # .bak. Read that real file, rather than trusting a logged object.
            backup_bytes = pathlib.Path(str(document) + ".bak").read_bytes()
            (run_dir / "pre-abandon-document.json").write_bytes(backup_bytes)
            result["pre_abandon_document_sha256"] = hashlib.sha256(backup_bytes).hexdigest()
            require(backup_bytes == ready["saved_document_json"].encode("utf-8"),
                    "actual pre-decline backup differs from captured saved primary bytes")
            journey_document = json.loads(backup_bytes)
            require(journey_document == ready_document, "actual pre-decline backup differs from saved wire document")
            declined_document = ember_abandon_document(ready, "declined_document_json")
            require(before == ready["declined_document_json"].encode("utf-8") and declined_document == saved,
                    "actual declined primary differs from captured declined wire bytes")
            require(saved["generation"] == journey_document["generation"] + 1
                    and saved["commit"]["parent_generation"] == journey_document["generation"]
                    and saved["commit"]["parent_id"] == journey_document["commit"]["id"]
                    and saved["commit"]["id"].startswith("ember-abandon-checkpoint-"),
                    "decline is not the single direct CAS successor of the actual saved primary")
            expected_payload = dict(journey_document["payload"])
            expected_payload.pop("ember_relay_survey_completion")
            # The probe binds this pre-abandon runtime envelope to the actual
            # saved wire text. UserDataStore installs parsed wire numbers, so
            # the next commit can spell a coordinate differently; its existing
            # outer and nested receipt identities are checked below.
            expected_payload["ember_relay_survey_completion_declined"] = ready["boundary"]
            require(saved["payload"] == expected_payload
                    and ready["abandon_result"].get("accepted") is True
                    and ready["abandon_result"].get("reason") == "ember_surface_abandon_pending_return"
                    and ready["abandon_state"].get("requested") is True,
                    "public abandon did not atomically archive only the original saved checkpoint while pending return")
            require(saved["payload"]["runtime_settings"] == ready["foreign_settings"]
                    and bool(ready["foreign_settings"])
                    and saved["payload"]["jovian_cargo_session"] == ready["foreign_cargo"]
                    and bool(ready["foreign_cargo"]),
                    "Ember abandon lost actual unrelated settings or cargo")
            require(ready["abandon_return_home"] == ready["completed_earned_debt"] == "NOT_RUN",
                    "pending abandon cut must retain its unperformed return-home and earned-debt gates")
            result["declined_document_sha256"] = hashlib.sha256(before).hexdigest()
        ready_boundary = ready["boundary"] if activity == "ember-abandon" else ready_document["payload"]["ember_relay_survey_completion"]
        terminal = journey_document["payload"]["ember_relay_survey_completion"]
        journey = terminal["completion"]
        route = journey["route_identity"]
        require(terminal == ready_document["payload"]["ember_relay_survey_completion"] and terminal["schema_version"] == 1
                and terminal["payload_kind"] == "ember_relay_survey_active_journey"
                and terminal["slot_id"] == "ember_relay_survey_completion",
                "Ember readiness differs from its actual supported active-journey save")
        if activity == "ember-abandon":
            require(terminal["receipt_sha256"] == ready_boundary["receipt_sha256"]
                    and terminal["completion"]["receipt_sha256"] == ready_boundary["completion"]["receipt_sha256"]
                    and terminal["completion"]["route_identity"] == ready_boundary["completion"]["route_identity"],
                    "Ember abandon changed the original outer/nested receipt or route identity")
        require(journey["marker"] == "interrupted_planetary_journey"
                and journey["journey_phase_id"] == "on_foot"
                and journey["world_id"] == "ember_moon"
                and journey["surface_attachment"] == {"active": False, "state": "detached"}
                and journey["movement_replay_allowed"] is False
                and journey["reward_replay_allowed"] is False
                and route == ready["route"] and route["activity_id"] == "ember_beacon_survey"
                and route["next_checkpoint_index"] == 1 and route["checkpoint_count"] == 2
                and route["next_objective_id"] == "ember_return_beacon" and route["complete"] is False
                and route["activity_generation"] > 0,
                "Ember arm has no genuine incomplete relay checkpoint")
        observed = ready["runtime_observation"]
        require(observed["player_on_floor"] is True and observed["player_control_enabled"] is True
                and observed["player_seated"] is False and observed["craft_piloted"] is False
                and saved["payload"]["solo_safe_recovery"] == (ready["safe_context"] if activity == "ember" else {"mode": "unavailable"}) == {"mode": "unavailable"}
                and ready["receipts"] == 0
                and saved["payload"].get("game_flow_reward_store", {}).get("reward_counts", {}).get("ember_beacon_data", 0) == 0,
                "Ember arm lost its genuine standing actor or invented a pilot preference/payment")
        require(ready["initial_flight_placements"] == ["orbital_anchor_hold", "initial_corridor_entry"]
                and ready["canonical_outbound"] == "NOT_RUN" and ready["standing_pose_restore"] == "NOT_SUPPORTED",
                "Ember acceptance must disclose its actual initial placement and recovery scope")
    elif activity == "hulk":
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
    elif activity == "breach":
        terminal = saved["payload"]["heavy_breach_session"]
        session = terminal["session"]
        completion = session["completion"]
        require(terminal == ready["boundary"] and terminal["schema_version"] == 1
                and terminal["payload_kind"] == "nearby_sector_activity_session"
                and terminal["slot_id"] == "heavy_breach_session"
                and session["component_id"] == "heavy-breach-activity-board"
                and session["generation_floor"] == completion["generation"] > 0
                and session["offered_index"] == 1,
                "Heavy Breach readiness differs from its actual supported rotated terminal")
        require(completion["activity_id"] == "shipyard_heavy_breach"
                and completion["scenario"] == "heavy_breach"
                and completion["state_id"] == "concluded" and completion["outcome"] == "cleared"
                and isinstance(completion["protected_objective"], str) and completion["protected_objective"]
                and completion["reward_granted"] is False and ready["receipts"] == 0,
                "Heavy Breach readiness has no genuine earned unpaid Heavy Breach debt")
        ledger = saved["payload"].get("game_flow_reward_store", {})
        require(ledger.get("total_receipts", 0) == 0
                and ledger.get("reward_counts", {}).get("return_heavy_breach_credit", 0) == 0
                and ready["foreign_reward_record"]["total_receipts"] == 0
                and ready["runtime_observation"]["craft_piloted"] is True
                and ready["runtime_observation"]["player_seated"] is True,
                "Heavy Breach arm has no actual unpaid boundary and real pilot ownership")
        require(saved["payload"]["runtime_settings"] == ready["foreign_settings"]
                and saved["payload"]["jovian_cargo_session"] == ready["foreign_cargo"],
                "Heavy Breach arm lost actual unrelated settings/activity payload")
        require(ready["fixture_method"] == "staged_on_foot_board_and_Arrow_entry_shortened_boarding_real_departure_then_direct_damage_on_real_charged_picket",
                "Heavy Breach arm concealed its staged setup, shortened boarding or direct target damage")
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
        if recovery_context == "docking":
            context = saved["payload"]["solo_safe_recovery"]
            observed = ready["docking_observation"]
            landing = observed["landing"]
            require(context == ready["safe_context"] == {
                        "location": "mudds_home_berth", "mode": "pilot",
                        "craft_id": "bulwark_heavy_gunship", "berth_id": "bulwark_fleet_dock_berth"}
                    and ready["boundary"]["escort_ship_id"] == context["craft_id"]
                    and row["state"] == 3 and ready["receipts"] == 1,
                    "docking readiness has no actual four-field pilot preference and failed second convoy")
            require(saved["payload"]["cinder_convoy_session"] == ready["convoy_record"]
                    and saved["payload"]["game_flow_reward_store"] == ready["reward_store"]
                    and saved["payload"]["game_flow_reward_store"]["reward_counts"]["return_convoy_credit_to_shipyard"] == 1
                    and observed["owed_rewards"] == [],
                    "docking arm omitted exact activity/debt/reward boundary or actual first payment")
            require(observed["craft_id"] == context["craft_id"] and observed["craft_piloted"] is True
                    and observed["piloting"] is True and observed["player_at_pilot_seat"] is True
                    and observed["player_seated"] is True and observed["player_sleeping"] is False
                    and observed["hatch_reserved_by_player"] is True and observed["landed"] is False
                    and observed["berth_unoccupied"] is True and observed["berth_reserved_by_craft"] is True
                    and observed["berth_lease_current"] is True and bool(observed["berth_reservation_token"])
                    and observed["landing_request_active"] is True
                    and observed["active_landing_berth_id"] == observed["home_berth_id"] == context["berth_id"],
                    "docking arm lacks actual pilot/hatch and current unoccupied target berth claim")
            require(landing["active"] is True and landing["contract_accepted"] is True
                    and landing["reservation_identity_snapshotted"] is True and landing["reservation_token_bound"] is True
                    and landing["berth_id"] == context["berth_id"]
                    and landing["berth_instance_id"] == observed["home_berth_instance_id"]
                    and landing["acceptance"]["reservation_owner_instance_id"] == observed["craft_instance_id"],
                    "docking arm lacks the exact accepted live landing contract")
            require(landing["reserved_ship_id"] == context["craft_id"]
                    and landing["elapsed"] > observed["requested_elapsed"] >= 0
                    and landing["phase"] not in ("none", "docked") and landing["last_abort_reason"] == ""
                    and observed["advanced_distance_m"] > 0 and observed["distance_to_dock_m"] > 0.1
                    and observed["completed_signals"] == observed["aborted_signals"] == 0,
                    "docking cut did not advance actual assist physics or already completed/aborted")
            require(ready["initialization"] == "existing_convoy_motion_fixture_then_home_approach_3m_above_registered_berth_real_landing_request_two_assist_physics_ticks"
                    and ready["approach_pose_restore"] == "NOT_SUPPORTED",
                    "docking readiness omitted escort/approach fixture disclosure and safe preference limit")
        if recovery_context == "on_foot":
            context = saved["payload"]["solo_safe_recovery"]
            observed = ready["exterior_observation"]
            require(context == ready["safe_context"] == {
                        "location": "mudds_home_berth", "mode": "on_foot",
                        "craft_id": "bulwark_heavy_gunship", "berth_id": "bulwark_fleet_dock_berth"}
                    and ready["boundary"]["escort_ship_id"] == context["craft_id"]
                    and row["state"] == 3 and ready["receipts"] == 1,
                    "on-foot readiness has no genuine four-field Bulwark preference and failed second convoy")
            require(observed["craft_id"] == context["craft_id"] and observed["piloting"] is False
                    and observed["player_seated"] is False and observed["player_sleeping"] is False
                    and observed["player_on_floor"] is True and observed["player_control_enabled"] is True
                    and observed["preferred_craft_piloted"] is False and observed["cabin_containment"] is False
                    and observed["hatch_reserved"] is False and observed["moving_interior_occupant"] is False
                    and observed["solo_crew_seated"] is False and observed["solo_crew_assignment_empty"] is True
                    and observed["preferred_craft_at_home"] is True and observed["home_berth_occupied_by_craft"] is True
                    and observed["distance_to_authored_exit_m"] < 1.5,
                    "on-foot arm has no actual supported awake claim-free player beside its occupied home berth")
            require(saved["payload"]["game_flow_reward_store"]["reward_counts"]["return_convoy_credit_to_shipyard"] == 1,
                    "on-foot arm lost or duplicated the actual first convoy payment")
            require(ready["initialization"] == "existing_convoy_motion_fixture_then_home_approach_3m_above_registered_berth_real_landing_and_exterior_exit",
                    "on-foot arm omitted its scenario flight and home approach initialization disclosure")
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
    if activity == "ember-abandon":
        require(pathlib.Path(str(document) + ".bak").read_bytes() == backup_bytes,
                "kill changed the independently observed pre-decline backup")
    result["ready"] = ready
    resume, resume_log, resume_entry = start("resume")
    if activity == "ember-abandon":
        require(arm.pid != resume.pid, "Ember abandon requires distinct owned OS processes")
    resume_entry["exit_code"] = resume.wait(timeout=timeout)
    recovered = token(resume_log, "IN_WORLD_RECOVERY_OK")
    require(resume_entry["exit_code"] == 0 and recovered is not None, "restart did not exit 0 with IN_WORLD_RECOVERY_OK")
    require(not diagnostics(resume_log), "restart engine/script diagnostics")
    require(recovered.get("recovery_context") == recovery_context, "restart ignored the selected recovery context")
    require(recovered.get("entry") == "startup_completed", "restart did not use Boot's own loaded Main")
    require(recovered.get("activity", "convoy") == activity, "restart ignored the selected activity")
    require(resume_log.read_text(errors="replace").strip().splitlines()[-1].startswith("IN_WORLD_RECOVERY_OK: "), "recovery token is not terminal")
    if activity == "ember-abandon":
        require(recovered["boundary"] == ready["boundary"] == ready_boundary,
                "fresh process changed the original declined Ember checkpoint")
    elif activity == "ember":
        ember_document(recovered, "boundary_document_json")
        # The probe binds each wire document to its runtime boundary. Compare
        # those boundaries exactly: Godot can re-encode a parsed JSON number
        # differently on a later commit without changing the runtime value.
        require(recovered["boundary"] == ready["boundary"], "fresh process changed durable Ember journey progress")
    else:
        require(recovered["boundary"] == ready["boundary"], "fresh process changed durable host/threat/escort/clock/progress")
    require(recovered["receipts_before"] == ready["receipts"] and recovered["receipts_after"] == ready["receipts"] + (0 if recovery_context == "engineer" or activity == "ember-abandon" else 1),
            "restart lost or duplicated the activity receipt")
    require(recovered["crash_events"] == 1, "actual interruption did not publish one crash event")
    after = document.read_bytes()
    final = json.loads(after)
    if activity == "ember-abandon":
        prequit_document = ember_abandon_document(recovered, "final_document_json",
                                                  recovered["prospective_fresh_record"])
        fresh_record = recovered["prospective_fresh_record"]
        require(recovered["prospective_fresh_record_valid"] is True
                and fresh_record["schema_version"] == 1
                and fresh_record["payload_kind"] == "ember_relay_survey_active_journey"
                and fresh_record["slot_id"] == "ember_relay_survey_completion"
                and fresh_record["completion"]["route_identity"] == recovered["fresh_route"]
                and fresh_record["completion"]["journey_phase_id"] == "on_foot"
                and fresh_record["completion"]["movement_replay_allowed"] is False
                and fresh_record["completion"]["reward_replay_allowed"] is False,
                "prospective new checkpoint does not describe the actually validated fresh standing survey")
        # Cold recovery must have no active slot. A subsequent ordinary quit
        # may save ONLY this new visit's exact independently captured receipt;
        # it can never resurrect the declined first-relay checkpoint.
        expected_final_payload = dict(prequit_document["payload"])
        if "ember_relay_survey_completion" in final["payload"]:
            require(final["payload"]["ember_relay_survey_completion"] == fresh_record,
                    "ordinary quit wrote an active checkpoint other than the exact valid new current-zero receipt")
            expected_final_payload["ember_relay_survey_completion"] = fresh_record
        require(final["payload"] == expected_final_payload,
                "ordinary quit changed payload beyond the permitted fresh current-zero checkpoint")
        require(final["payload"].get("game_flow_reward_store", {})
                == prequit_document["payload"].get("game_flow_reward_store", {})
                == saved["payload"].get("game_flow_reward_store", {}),
                "Ember abandon cold recovery changed the exact reward ledger")
        require(final["payload"]["ember_relay_survey_completion_declined"] == ready_boundary
                and final["payload"].get("game_flow_reward_store", {}).get("reward_counts", {}).get("ember_beacon_data", 0) == 0
                and recovered["receipts_before"] == recovered["receipts_after"] == 0,
                "fresh boot restored the old active checkpoint, changed its archive or automatically paid it")
        for field in ("boot_persistence", "fresh_persistence"):
            persistence = recovered[field]
            require(persistence.get("adopted") is False
                    and not persistence.get("route_identity")
                    and not persistence.get("restore_status", {}).get("checkpoint_resume", {}).get("accepted", False),
                    "Ember abandon " + field + " adopted the declined location/session/checkpoint")
        fresh_route = recovered["fresh_route"]
        require(fresh_route["activity_id"] == "ember_beacon_survey"
                and fresh_route["next_checkpoint_index"] == 0 and fresh_route["checkpoint_count"] == 2
                and fresh_route["next_objective_id"] == "ember_relay_tower"
                and fresh_route["activity_generation"] > 0 and fresh_route["complete"] is False
                and fresh_route != route,
                "legitimate new Ember arrival did not start from its first observation")
        safe = recovered["safe_recovery_observation"]
        yard = safe["cold_yard_before_boarding"]
        require(yard["player_seated"] is False and yard["player_control_enabled"] is True
                and yard["craft_piloted"] is False and safe["player_seated"] is True
                and safe["craft_piloted"] is True
                and safe["craft_id"] == ready["runtime_observation"]["craft_id"],
                "Ember abandon cold recovery did not acquire a genuine new home pilot boarding")
        require(final["payload"]["runtime_settings"] == ready["foreign_settings"] == recovered["foreign_settings"]
                and final["payload"]["jovian_cargo_session"] == ready["foreign_cargo"] == recovered["foreign_cargo"],
                "Ember abandon recovery changed actual unrelated settings or cargo")
        require(recovered["initial_flight_placements"] == ready["initial_flight_placements"]
                and recovered["canonical_outbound"] == "NOT_RUN"
                and recovered["standing_pose_restore"] == "NOT_SUPPORTED"
                and recovered["abandon_return_home"] == recovered["completed_earned_debt"] == "NOT_RUN"
                and recovered["continuation_method"] == "explicit_abandon_pending_cut_then_cold_yard_and_legitimate_new_survey",
                "Ember abandon restart concealed its pending-cut, staging or fresh-visit limits")
        result["final_document_sha256"] = hashlib.sha256(after).hexdigest()
        result["prequit_document_sha256"] = hashlib.sha256(recovered["final_document_json"].encode("utf-8")).hexdigest()
        result["fresh_checkpoint_saved_on_quit"] = "ember_relay_survey_completion" in final["payload"]
    elif activity == "ember":
        paid_document = ember_document(recovered, "paid_document_json")
        require(paid_document == final, "Ember payment document differs from the independently read save")
        paid = final["payload"]["ember_relay_survey_completion"]
        safe = recovered["safe_recovery_observation"]
        yard = safe["cold_yard_before_boarding"]
        require(yard["player_seated"] is False and yard["player_control_enabled"] is True
                and yard["craft_piloted"] is False and safe["player_seated"] is True
                and safe["craft_piloted"] is True
                and safe["craft_id"] == ready["runtime_observation"]["craft_id"],
                "Ember cold yard Resume did not acquire a genuine new pilot boarding")
        require(recovered["resumed_route"] == route
                and recovered["host_attachment_generation"] > journey["attachment_generation"]
                and paid == paid_document["payload"]["ember_relay_survey_completion"]
                and paid["payload_kind"] == "ember_relay_survey_completion"
                and paid["completion"]["activity_generation"] == route["activity_generation"]
                and paid["completion"]["mandatory_route"]["next_checkpoint_index"] == 2
                and paid["completion"]["mandatory_route"]["complete"] is True
                and paid["completion"]["reward_replay_allowed"] is False
                and final["payload"]["game_flow_reward_store"]["reward_counts"]["ember_beacon_data"] == 1,
                "Ember resumption reset the original survey, lost its successor epoch, or duplicated the real earned receipt")
        require(recovered["initial_flight_placements"] == ready["initial_flight_placements"]
                and recovered["canonical_outbound"] == "NOT_RUN"
                and recovered["standing_pose_restore"] == "NOT_SUPPORTED"
                and recovered["continuation_method"] == "ordinary_cold_yard_then_real_boarding_disclosed_initial_flight_placements_and_original_survey_resume",
                "Ember restart concealed its production yard/new-trip recovery limit")
    elif activity == "hulk":
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
    elif activity == "breach":
        paid = final["payload"]["heavy_breach_session"]
        safe = recovered["safe_recovery_observation"]
        require(safe["craft_piloted"] is True and safe["player_seated"] is True
                and safe["craft_id"] == ready["runtime_observation"]["craft_id"],
                "Heavy Breach Resume did not acquire the actual saved safe-home Arrow pilot")
        require(paid == recovered["paid_boundary"]
                and paid == {**terminal, "session": {**session,
                    "completion": {**completion, "reward_granted": True}}}
                and recovered["payment_commit"]["id"].startswith("game-flow-reward-")
                and recovered["paid_replay"] is False,
                "Heavy Breach production retry changed earned debt or lost its atomic paid acknowledgement")
        ledger = final["payload"]["game_flow_reward_store"]
        receipt = ledger["last_receipt"]
        require(ledger == recovered["reward_record"] and ledger["total_receipts"] == 1
                and ledger["receipt_serial"] == 1
                and ledger["reward_counts"] == {"return_heavy_breach_credit": 1}
                and receipt["activity_id"] == "shipyard_heavy_breach"
                and receipt["reward_id"] == "return_heavy_breach_credit"
                and receipt["activity_generation"] == completion["generation"]
                and receipt["granted"] is True and receipt["replay_allowed"] is False,
                "Heavy Breach recovery did not save exactly one actual Heavy Breach receipt")
        capture = recovered["payment_capture"]
        payment_document = json.loads(capture["document_json"])
        require(payment_document["commit"] == capture["commit"] == recovered["payment_commit"]
                and payment_document["commit"]["id"].startswith("game-flow-reward-")
                and payment_document["generation"] == capture["store_generation"]
                and payment_document["payload"]["heavy_breach_session"] == paid
                and payment_document["payload"]["game_flow_reward_store"] == ledger
                and payment_document["payload"]["runtime_settings"] == ready["foreign_settings"]
                and payment_document["payload"]["jovian_cargo_session"] == ready["foreign_cargo"],
                "Heavy Breach physical retry did not capture the same persisted atomic receipt and terminal acknowledgement before later saves")
        require(final["payload"]["runtime_settings"] == ready["foreign_settings"] == recovered["foreign_settings"]
                and final["payload"]["jovian_cargo_session"] == ready["foreign_cargo"] == recovered["foreign_cargo"],
                "Heavy Breach recovery changed actual unrelated settings/activity payload")
        require(recovered["active_combat_restore"] == "NOT_SUPPORTED"
                and recovered["ordinary_combat_acceptance"] == "NOT_RUN"
                and recovered["fixture_method"] == ready["fixture_method"]
                and recovered["continuation_method"] == "ordinary_cold_Resume_safe_home_Arrow_pilot_production_exit_staged_physical_board_interaction",
                "Heavy Breach recovery concealed its fixture or terminal-only scope")
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

    if recovery_context == "docking":
        safe = recovered["safe_recovery_observation"]
        control = recovered["control_observation"]
        context = ready["safe_context"]
        require(recovered["convoy_record"] == ready["convoy_record"]
                and recovered["reward_store"] == ready["reward_store"]
                and recovered["safe_context"] == context and safe["owed_rewards"] == [],
                "cold docking Resume changed exact failed activity, debt, reward or four-field preference")
        require(safe["craft_id"] == context["craft_id"] and safe["home_berth_id"] == context["berth_id"]
                and safe["craft_piloted"] is True and safe["piloting"] is True
                and safe["player_seated"] is True and safe["player_at_pilot_seat"] is True
                and safe["player_sleeping"] is False and safe["cabin_containment"] is False
                and safe["craft_at_home"] is True and safe["berth_occupied_by_craft"] is True
                and safe["berth_reserved_by_craft"] is True and safe["berth_lease_current"] is True
                and safe["hatch_reserved_by_player"] is True and bool(safe["berth_reservation_token"])
                and safe["berth_reservation_token"] != ready["docking_observation"]["berth_reservation_token"]
                and safe["landing"]["active"] is False and safe["landing_request_active"] is False
                and safe["active_landing_berth_id"] == "",
                "cold docking Resume did not acquire fresh home pilot/seat/berth/hatch without old assist authority")
        require(control["engine_online"] is True and control["throttle"] > 0 and control["landing_active"] is False
                and recovered["initialization"] == ready["initialization"]
                and recovered["approach_pose_restore"] == "NOT_SUPPORTED"
                and recovered["continuation_method"] == "ordinary_cold_home_pilot_resume_throttle_explicit_reset_then_distinct_convoy_motion_fixture",
                "docking recovery omitted normal usable throttle, explicit reset/distinct fixture or placement disclosure")
        paid_row = final["payload"]["cinder_convoy_session"]["activities"][0]
        require(paid_row["reward_granted"] is True
                and paid_row["generation"] == recovered["continuation_generation"] > row["generation"]
                and final["payload"]["game_flow_reward_store"]["reward_counts"]["return_convoy_credit_to_shipyard"] == 2,
                "docking continuation lost or duplicated the actual distinct convoy payment")
    if recovery_context == "on_foot":
        safe = recovered["safe_recovery_observation"]
        require(recovered["safe_context"] == ready["safe_context"]
                and safe["preferred_craft_id"] == "bulwark_heavy_gunship"
                and safe["preferred_berth_id"] == "bulwark_fleet_dock_berth"
                and safe["craft_id"] == "torrent_provisional" and safe["craft_piloted"] is False
                and safe["piloting"] is False and safe["player_seated"] is False
                and safe["player_sleeping"] is False and safe["player_on_floor"] is True
                and safe["player_control_enabled"] is True and safe["preferred_craft_piloted"] is False
                and safe["cabin_containment"] is False and safe["hatch_reserved"] is False
                and safe["moving_interior_occupant"] is False and safe["solo_crew_seated"] is False
                and safe["solo_crew_assignment_empty"] is True
                and safe["preferred_craft_at_home"] is True and safe["home_berth_occupied_by_craft"] is True
                and safe["distance_to_authored_exit_m"] < 1.5,
                "on-foot cold Resume did not return the claim-free supported player beside saved Bulwark without changing active craft")
        require(safe["walking"]["supported"] is True and safe["walking"]["distance_m"] > 0.1
                and safe["walking"]["method"] == "ordinary_camera_relative_inboard_walking_input"
                and recovered["continuation_method"] == "ordinary_cold_exterior_home_walk_and_interact_boarding_then_distinct_convoy_motion_fixture"
                and recovered["initialization"] == ready["initialization"],
                "on-foot recovery omitted usable ordinary walking, real Interact boarding or fixture disclosure")
        require(final["payload"]["cinder_convoy_session"]["activities"][0]["reward_granted"] is True
                and final["payload"]["game_flow_reward_store"]["reward_counts"]["return_convoy_credit_to_shipyard"] == 2,
                "on-foot continuation lost or duplicated the actual distinct convoy payment")
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
    if activity == "breach":
        # The existing resume stage recognizes an already paid terminal. Its
        # further OS process must load the same private profile independently;
        # only recovery markers may change, never the paid debt or reward ledger.
        replay, replay_log, replay_entry = start("resume", "paid-replay")
        require(len({entry["pid"] for entry in result["processes"]}) == 3,
                "Heavy Breach arm, recovery and paid replay require distinct owned OS processes")
        replay_entry["exit_code"] = replay.wait(timeout=timeout)
        replayed = token(replay_log, "IN_WORLD_RECOVERY_OK")
        require(replay_entry["exit_code"] == 0 and replayed is not None
                and not diagnostics(replay_log), "further cold paid replay failed or emitted diagnostics")
        require(replay_log.read_text(errors="replace").strip().splitlines()[-1].startswith("IN_WORLD_RECOVERY_OK: "),
                "paid replay token is not terminal")
        require(replayed.get("entry") == "startup_completed" and replayed.get("activity") == "breach"
                and replayed.get("recovery_context") == recovery_context and replayed.get("paid_replay") is True
                and replayed["boundary"] == paid == replayed["paid_boundary"]
                and replayed["receipts_before"] == replayed["receipts_after"] == 1
                and replayed["crash_events"] == 0 and replayed["reward_record"] == ledger,
                "further cold process did not retain the exact paid Heavy Breach terminal and single receipt")
        replay_bytes = document.read_bytes()
        replay_document = json.loads(replay_bytes)
        require(replay_document["payload"]["heavy_breach_session"] == paid
                and replay_document["payload"]["game_flow_reward_store"] == ledger
                and replay_document["payload"]["runtime_settings"] == ready["foreign_settings"] == replayed["foreign_settings"]
                and replay_document["payload"]["jovian_cargo_session"] == ready["foreign_cargo"] == replayed["foreign_cargo"],
                "independently read paid replay document changed the paid debt, ledger or unrelated payload")
        require(replay_document["payload"]["crash_recovery"]["state"] == "clean"
                and replay_document["payload"]["safe_start_recovery"]["state"] == "clean_shutdown",
                "paid replay did not close both actual recovery marker owners")
        (run_dir / "paid-replay-document.json").write_bytes(replay_bytes)
        result["paid_replay"] = replayed
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
