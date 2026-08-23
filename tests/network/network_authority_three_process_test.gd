extends SceneTree

const PORT := 29140
const PEER_SCRIPT := "res://tests/network/network_authority_peer.gd"
const LOG_ROOT := "/tmp/mudds_network_authority_wave9"

var _pids: Array[int] = []
var _logs: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	DirAccess.make_dir_absolute(LOG_ROOT)
	var executable := OS.get_executable_path()
	var script_path := ProjectSettings.globalize_path(PEER_SCRIPT)
	for role in ["server", "client_a", "client_b"]:
		var log_path := "%s/%s.log" % [LOG_ROOT, role]
		var log_file := FileAccess.open(log_path, FileAccess.WRITE)
		if log_file != null:
			log_file.close()
		var args := PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", script_path, "--", "--role",
			"server" if role == "server" else "client", "--port", str(PORT), "--log", log_path,
		])
		var pid := OS.create_process(executable, args)
		if pid <= 0:
			_cleanup()
			push_error("failed to spawn %s" % role)
			quit(1)
			return
		_pids.append(pid)
		_logs.append(log_path)
		print("SPAWN %s pid=%d" % [role, pid])
	var deadline := Time.get_ticks_msec() + 18000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
		if _evidence_complete():
			_cleanup()
			print("OK: three-process network authority harness")
			quit(0)
			return
	_cleanup()
	push_error("three-process harness timed out\n%s" % _read_logs())
	quit(1)


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
		"TRANSFER_CLEAN_DISCONNECT",
	]:
		if not server_log.contains(marker):
			return false
	for client_log in [client_a_log, client_b_log]:
		if not client_log.contains("ADMITTED") or not client_log.contains("RELATIONSHIP_STABLE") \
			or not client_log.contains("RELATIONSHIP_RELEASED") \
			or not client_log.contains("DAMAGE_DESTROYED_PRESENTED") \
			or not client_log.contains("DAMAGE_RESPAWN_PRESENTED") \
			or not client_log.contains("CLIENT_CLEAN"):
			return false
	return true


func _read_log(role: String) -> String:
	var path := "%s/%s.log" % [LOG_ROOT, role]
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
	for path in _logs:
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				output += file.get_as_text() + "\n"
				file.close()
	return output


func _cleanup() -> void:
	for pid in _pids:
		if pid > 0:
			OS.kill(pid)
	_pids.clear()
