extends SceneTree

const PORT := 29140
const PEER_SCRIPT := "res://tests/network/network_authority_peer.gd"

var _pids: Array[int] = []
var _logs: Array[String] = []
var _log_root := ""
var _roles: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var directory_base := OS.get_environment("TMPDIR")
	if directory_base.is_empty():
		directory_base = OS.get_user_data_dir()
	_log_root = directory_base.path_join("mudds-network-authority-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_log_root)
	var script_path := ProjectSettings.globalize_path(PEER_SCRIPT)
	for role in ["server", "client_a", "client_b"]:
		var log_path := _log_root.path_join("%s.log" % role)
		var log_file := FileAccess.open(log_path, FileAccess.WRITE)
		if log_file != null:
			log_file.close()
		var args := PackedStringArray([
			"--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"),
			"--script", script_path, "--", "--role",
			role, "--port", str(PORT), "--log", log_path,
		])
		var pid := _spawn_peer(role, args)
		if pid <= 0:
			await _cleanup()
			push_error("failed to spawn %s" % role)
			quit(1)
			return
		_pids.append(pid)
		_roles.append(role)
		_logs.append(log_path)
		print("SPAWN %s pid=%d" % [role, pid])
	var deadline := Time.get_ticks_msec() + 24000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
		var all_exited_zero := _all_exited_zero()
		var failure := _process_failure()
		if not failure.is_empty():
			await _cleanup()
			push_error("three-process child failure: %s\n%s" % [failure, _read_logs()])
			quit(1)
			return
		if _evidence_complete() and all_exited_zero:
			# Exit receipts are written only after wait reaps the actual engines;
			# their redirected output includes all teardown diagnostics.
			_pids.clear()
			print("OK: three-process network authority harness; all three OS exits=0; diagnostics=0")
			quit(0)
			return
	await _cleanup()
	push_error("three-process harness timed out\n%s" % _read_logs())
	quit(1)


func _spawn_peer(role: String, args: PackedStringArray) -> int:
	# Every path is a positional argument, never shell source. The wrapper owns
	# an independent abort path and records the engine's real wait status.
	var command := '"$@" > "$0.output" 2>&1 & child=$!; printf "%s" "$child" > "$0.pid"; trap \'kill "$child" 2>/dev/null; wait "$child"; exit 143\' TERM INT HUP; wait "$child"; status=$?; printf "%s" "$status" > "$0.exit"; exit "$status"'
	var wrapper := PackedStringArray(["-c", command, _log_root.path_join(role), OS.get_executable_path()])
	wrapper.append_array(args)
	return OS.create_process("/bin/sh", wrapper)


func _all_exited_zero() -> bool:
	for role in _roles:
		var path := _log_root.path_join(role + ".exit")
		if not FileAccess.file_exists(path) or FileAccess.get_file_as_string(path).strip_edges() != "0":
			return false
	return _roles.size() == 3


func _process_failure() -> String:
	for role in _roles:
		var exit_path := _log_root.path_join(role + ".exit")
		if FileAccess.file_exists(exit_path):
			var status := FileAccess.get_file_as_string(exit_path).strip_edges()
			if not status.is_empty() and status != "0":
				return "%s actual OS exit=%s" % [role, status]
		var output_path := _log_root.path_join(role + ".output")
		if FileAccess.file_exists(output_path):
			var output := FileAccess.get_file_as_string(output_path)
			for diagnostic in ["ERROR:", "WARNING:", "SCRIPT ERROR:", "SCRIPT WARNING:"]:
				if output.contains(diagnostic):
					return "%s emitted %s" % [role, diagnostic]
	return ""


func _evidence_complete() -> bool:
	var server_log := _read_log("server")
	var client_a_log := _read_log("client_a")
	var client_b_log := _read_log("client_b")
	for marker in [
		"HOST_READY", "PILOT_ADMITTED", "PASSENGER_ADMITTED", "COMMAND_ACCEPTED",
		"RELATIONSHIP_PUBLISHED", "IMPAIRMENT", "IMPAIRMENT_DROP sequence=17",
		"STALE_REJECTED sequence=23", "COMMANDS_ACCEPTED_40", "COMMANDS_DROPPED_1", "QUEUE_MAX_0",
		"AUTHORITATIVE_DELIVERED", "CORRECTION_BOUNDED", "PILOT_A_RELEASED",
		"PILOT_B_CLAIMED", "PILOT_TRANSFER_ATOMIC", "STALE_A_REJECTED",
		"TRANSFER_COMMAND_ACCEPTED", "TRANSFER_AUTHORITATIVE_DELIVERED",
		"CRAFT_DESTROYED", "OLD_REPLICAS_CLEARED", "CRAFT_RESPAWNED",
		"RESPAWN_COMMAND_ACCEPTED", "RESPAWN_AUTHORITATIVE_DELIVERED",
		"LANDED_OCCUPIED", "SEATS_RELEASED", "LANDING_EXIT_CLEAN", "TRANSFER_CLEAN_DISCONNECT",
		"REAL_JOVIAN_MOVED", "REAL_PASSENGER_ATTACHED", "REAL_PASSENGER_RELEASED",
		"REAL_PLAYERS_BOARDING", "REAL_BOARDING_RELEASED",
		"REAL_PAYLOAD_RELEASED", "REAL_PAYLOAD_TERMINAL_RESOLVED", "DAMAGE_ONCE_SERVER_ONLY",
		"STATION_DEFENSE_STARTED", "STATION_ACTIVE_WAVE", "STATION_ASSET_CRITICAL",
		"STATION_DEFENSE_TERMINAL", "STATION_REPLAY_SENT", "STATION_REPLAY_REJECTED_SERVER", "STATION_INVALID_GENERATION_REJECTED",
		"CARGO_MANIFEST_READY", "CARGO_TRANSFER_COMMITTED", "CARGO_TRANSFER_COMPLETED",
		"CARGO_QUANTITY_CONSERVED_12", "CARGO_REPLAY_SENT", "CARGO_INVALID_GENERATION_REJECTED",
		"COPILOT_ADMITTED", "COPILOT_NAV_ACCEPTED", "COPILOT_NAV_REPLICATED",
		"COPILOT_STALE_SEQUENCE_REJECTED", "COPILOT_HELM_MUTATION_REJECTED",
		"COPILOT_STALE_GENERATION_REJECTED", "COPILOT_DISCONNECT_CLEAN",
		"LOADMASTER_ADMITTED", "LOADMASTER_MANIFEST_READY", "LOADMASTER_ROUTE_REPLICATED",
		"LOADMASTER_RECEIPT_REAL",
		"LOADMASTER_STALE_GENERATION_REJECTED", "LOADMASTER_REORDER_REJECTED",
		"LOADMASTER_STALE_OCCUPANT_REJECTED", "LOADMASTER_DISCONNECT_CLEAN",
		"RECONNECT_OLD_COMMAND_REJECTED", "RECONNECT_RESYNC_PUBLISHED", "RECONNECT_GENERATION_FRESH",
		"COMMAND_RPC_pilot50", "COMMAND_RPC_duplicate50", "COMMAND_RPC_late49",
		"COMMAND_RPC_other_owner", "COMMAND_RPC_false_peer", "COMMAND_RPC_CONSUMED_ONCE",
	]:
		if not server_log.contains(marker):
			return false
	if not client_a_log.contains("MID_SESSION_DISCONNECT") \
		or not client_a_log.contains("RECONNECT_JOIN_STARTED") \
		or not client_a_log.contains("RECONNECT_ADMITTED") \
		or not client_a_log.contains("RECONNECT_OLD_TERMINAL_REJECTED") \
		or not client_a_log.contains("RECONNECT_DAMAGE_RESYNC") \
		or not client_a_log.contains("RECONNECT_RELATIONSHIP_RESYNC"):
		return false
	for station_marker in [
		"STATION_STARTED_PRESENTED", "STATION_WAVE_PRESENTED", "STATION_CRITICAL_PRESENTED",
		"STATION_TERMINAL_PRESENTED", "STATION_REPLAY_REJECTED",
	]:
		if not client_a_log.contains(station_marker) or not client_b_log.contains(station_marker):
			return false
	if not client_a_log.contains("STATION_TERMINAL_RESYNC_PRESENTED"):
		return false
	if not client_b_log.contains("HANDSHAKE_MISMATCH_REJECTED"):
		return false
	if not client_b_log.contains("DIRECT_CONNECT_BAD_PORT_REJECTED"):
		return false
	for cargo_marker in [
		"CARGO_READY_PRESENTED", "CARGO_TRANSIT_PRESENTED", "CARGO_COMMIT_PRESENTED",
		"CARGO_COMPLETED_PRESENTED", "CARGO_REPLAY_REJECTED",
	]:
		if not client_a_log.contains(cargo_marker) or not client_b_log.contains(cargo_marker):
			return false
	if not client_a_log.contains("COPILOT_NAV_PRESENTED") and not client_b_log.contains("COPILOT_NAV_PRESENTED"):
		return false
	if not client_a_log.contains("LOADMASTER_READY_PRESENTED") \
		or not client_a_log.contains("LOADMASTER_ROUTE_PRESENTED"):
		return false
	if not client_a_log.contains("CARGO_TERMINAL_RESYNC_PRESENTED"):
		return false
	for client_log in [client_a_log, client_b_log]:
		if not client_log.contains("ADMITTED") or not client_log.contains("RELATIONSHIP_STABLE") \
			or not client_log.contains("PROJECTILE_PRESENTED") \
			or not client_log.contains("PROJECTILE_TERMINAL_PRESENTED") \
			or not client_log.contains("CLIENT_PAYLOAD_POOL_RELEASED") \
			or not client_log.contains("CLIENT_PAYLOAD_POOL_TERMINAL") \
			or not client_log.contains("CLIENT_TERMINAL_DUPLICATE_REJECTED") \
			or not client_log.contains("RELATIONSHIP_RELEASED") \
			or not client_log.contains("DAMAGE_DESTROYED_PRESENTED") \
			or not client_log.contains("DAMAGE_RESPAWN_PRESENTED") \
			or not client_log.contains("LANDED_PRESENTED") \
			or not client_log.contains("LANDED_OCCUPIED_PRESENTED") \
			or not client_log.contains("SEATS_RELEASED_PRESENTED") \
			or not client_log.contains("LANDING_EXIT_PRESENTED") \
			or not client_log.contains("CLIENT_CLEAN"):
			return false
	for peer_log in [server_log, client_a_log, client_b_log]:
		if not peer_log.contains("PEER_FINISHED"):
			return false
	return true


func _read_log(role: String) -> String:
	var path := _log_root.path_join("%s.log" % role)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents := file.get_as_text()
	file.close()
	return contents

func _read_logs() -> String:
	var output := ""
	for role in _roles:
		for extension in [".log", ".output", ".exit", ".pid"]:
			var path := _log_root.path_join(role + extension)
			if FileAccess.file_exists(path):
				output += path + "\n" + FileAccess.get_file_as_string(path) + "\n"
	return output


func _cleanup() -> void:
	# Kill owned engines first, leaving their wrappers alive to wait/reap them.
	for role in _roles:
		var pid_path := _log_root.path_join(role + ".pid")
		var exit_path := _log_root.path_join(role + ".exit")
		if FileAccess.file_exists(pid_path) and not FileAccess.file_exists(exit_path):
			var child_pid := int(FileAccess.get_file_as_string(pid_path))
			if child_pid > 0 and OS.is_process_running(child_pid):
				OS.kill(child_pid)
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		var wrappers_running := false
		for pid in _pids:
			wrappers_running = wrappers_running or OS.is_process_running(pid)
		if not wrappers_running:
			break
		await create_timer(0.02).timeout
	for pid in _pids:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_pids.clear()
