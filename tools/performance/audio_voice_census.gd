extends SceneTree

## Renderer-independent audio voice/resource census for production Main.
##
## Usage:
##   godot --headless --audio-driver Dummy --path . \
##     --script res://tools/performance/audio_voice_census.gd
##
## Optional environment variables:
##   KETH_AUDIO_CENSUS_SCENARIO=station_resident|cinder_loaded
##   KETH_AUDIO_CENSUS_SETTLE=N
##   KETH_AUDIO_CENSUS_JSON=path

const MAIN_SCENE := preload("res://scenes/main.tscn")
const GEOMETRY_CENSUS := preload("res://tools/geometry_census.gd")

const SCHEMA_VERSION := 1
const DEFAULT_SETTLE_FRAMES := 8
const SCENARIO_STATION_RESIDENT: StringName = &"station_resident"
const SCENARIO_CINDER_LOADED: StringName = &"cinder_loaded"
const DEFAULT_SCENARIO: StringName = SCENARIO_STATION_RESIDENT
const SCENARIO_ENVIRONMENT_VARIABLE := "KETH_AUDIO_CENSUS_SCENARIO"
const SETTLE_ENVIRONMENT_VARIABLE := "KETH_AUDIO_CENSUS_SETTLE"
const JSON_ENVIRONMENT_VARIABLE := "KETH_AUDIO_CENSUS_JSON"
const FALLBACK_BUCKET := "(scene root)"
const SPLIT_ROOTS: Array[String] = ["ShipyardWorld"]
const AUTHORITY_EXCLUSIONS: Array[String] = [
	"native_mixer_voice_count",
	"native_mixer_memory",
	"decoded_backend_buffers",
	"audio_thread_cpu_time",
	"process_ram",
	"frame_time",
	"renderer_cost",
]


class AudioStreamResourceCensus:
	extends RefCounted

	var bound_streams: Dictionary = {}
	var retained_streams: Dictionary = {}
	var retained_origins: Dictionary = {}
	var skipped_freed_object_references := 0
	var _visited_objects: Dictionary = {}
	var _strong_resources: Array[Resource] = []


	func note_bound(stream: AudioStream) -> void:
		if stream == null:
			return
		bound_streams[stream.get_instance_id()] = stream


	func collect_retained(root_node: Node) -> void:
		_visited_objects.clear()
		retained_origins.clear()
		_visit_object(root_node, "scene")


	func retained_rows() -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		for id_variant in retained_streams:
			var stream := retained_streams[id_variant] as AudioStream
			if stream == null:
				continue
			var payload := _payload_bytes(stream)
			rows.append({
				"origin": str(retained_origins.get(id_variant, "<unresolved>")),
				"class": stream.get_class(),
				"resource_path": stream.resource_path,
				"payload_bytes": payload.size(),
				"payload_sha256": _sha256(payload),
				"format_contract": _format_contract(stream),
			})
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _stream_row_descriptor(a) < _stream_row_descriptor(b)
		)
		return rows


	func retained_payload_bytes() -> int:
		var total := 0
		for stream_variant in retained_streams.values():
			var stream := stream_variant as AudioStream
			if stream != null:
				total += _payload_bytes(stream).size()
		return total


	func retained_unknown_payload_count() -> int:
		var count := 0
		for stream_variant in retained_streams.values():
			var stream := stream_variant as AudioStream
			if stream != null and not _has_payload_property(stream):
				count += 1
		return count


	func _visit_variant(value: Variant, origin: String) -> void:
		if typeof(value) == TYPE_OBJECT and not is_instance_valid(value):
			skipped_freed_object_references += 1
			return
		if value is AudioStream:
			_note_retained(value as AudioStream, origin)
			return
		if value is Resource:
			_visit_object(value as Resource, origin)
			return
		if value is Node:
			_visit_object(value as Node, origin)
			return
		if value is Array:
			var array := value as Array
			for index in array.size():
				_visit_variant(array[index], "%s[%d]" % [origin, index])
			return
		if value is Dictionary:
			var dictionary := value as Dictionary
			var keys := dictionary.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			for key_variant in keys:
				var key_text := str(key_variant)
				_visit_variant(key_variant, "%s.key[%s]" % [origin, key_text])
				_visit_variant(dictionary[key_variant], "%s[%s]" % [origin, key_text])


	func _visit_object(object: Object, origin: String) -> void:
		if object == null:
			return
		var instance_id := object.get_instance_id()
		if _visited_objects.has(instance_id):
			return
		_visited_objects[instance_id] = true
		if object is Resource:
			_strong_resources.append(object as Resource)
		var properties := object.get_property_list()
		properties.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("name", "")) < str(b.get("name", ""))
		)
		for property_variant in properties:
			var property := property_variant as Dictionary
			var usage := int(property.get("usage", 0))
			if (usage & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE)) == 0:
				continue
			var property_name := StringName(str(property.get("name", "")))
			if property_name.is_empty():
				continue
			_visit_variant(
				object.get(property_name),
				"%s.%s" % [origin, property_name]
			)
		if object is Node:
			for child in (object as Node).get_children():
				_visit_object(
					child,
					"%s/%s" % [origin, _stable_sibling_segment(child)]
				)


	func _note_retained(stream: AudioStream, origin: String) -> void:
		var instance_id := stream.get_instance_id()
		retained_streams[instance_id] = stream
		if not retained_origins.has(instance_id) or origin < str(retained_origins[instance_id]):
			retained_origins[instance_id] = origin
		_visit_object(stream, origin)


	static func _has_payload_property(stream: AudioStream) -> bool:
		for property_variant in stream.get_property_list():
			if str((property_variant as Dictionary).get("name", "")) == "data":
				return stream.get("data") is PackedByteArray
		return false


	static func _payload_bytes(stream: AudioStream) -> PackedByteArray:
		if not _has_payload_property(stream):
			return PackedByteArray()
		return stream.get("data") as PackedByteArray


	static func _sha256(bytes: PackedByteArray) -> String:
		var context := HashingContext.new()
		if context.start(HashingContext.HASH_SHA256) != OK:
			return ""
		if context.update(bytes) != OK:
			return ""
		return context.finish().hex_encode()


	static func _format_contract(stream: AudioStream) -> Dictionary:
		if stream is AudioStreamWAV:
			var wave := stream as AudioStreamWAV
			return {
				"format": wave.format,
				"mix_rate": wave.mix_rate,
				"stereo": wave.stereo,
				"loop_mode": wave.loop_mode,
				"loop_begin": wave.loop_begin,
				"loop_end": wave.loop_end,
			}
		return {}


	static func _stream_row_descriptor(row: Dictionary) -> String:
		return "%s|%s|%s|%d|%s|%s" % [
			str(row.get("origin", "")),
			str(row.get("class", "")),
			str(row.get("resource_path", "")),
			int(row.get("payload_bytes", 0)),
			str(row.get("payload_sha256", "")),
			JSON.stringify(row.get("format_contract", {})),
		]


	static func _stable_sibling_segment(node: Node) -> String:
		var runtime_name := str(node.name)
		if not runtime_name.begins_with("@"):
			return runtime_name
		var parent := node.get_parent()
		if parent == null:
			return "%s[01]" % node.get_class()
		var ordinal := 0
		for sibling in parent.get_children():
			if sibling.get_class() == node.get_class() and str(sibling.name).begins_with("@"):
				ordinal += 1
				if sibling == node:
					break
		return "%s[%02d]" % [node.get_class(), maxi(ordinal, 1)]


var _stream_census := AudioStreamResourceCensus.new()
var _player_rows: Array[Dictionary] = []
var _component_rows: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	var scenario := StringName(
		OS.get_environment(SCENARIO_ENVIRONMENT_VARIABLE).strip_edges()
	)
	if scenario.is_empty():
		scenario = DEFAULT_SCENARIO
	if scenario not in [SCENARIO_STATION_RESIDENT, SCENARIO_CINDER_LOADED]:
		printerr("audio voice census: unsupported scenario: %s" % scenario)
		quit(1)
		return
	var settle_frames := DEFAULT_SETTLE_FRAMES
	var settle_override := OS.get_environment(SETTLE_ENVIRONMENT_VARIABLE)
	if settle_override.is_valid_int():
		settle_frames = maxi(1, settle_override.to_int())

	var game := MAIN_SCENE.instantiate() as GameFlow
	if game == null:
		printerr("audio voice census: production Main failed to instantiate")
		quit(1)
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	if scenario == SCENARIO_CINDER_LOADED:
		var prepared := await prepare_cinder_loaded_scenario(game)
		if not bool(prepared.get("accepted", false)):
			printerr("audio voice census: Cinder preparation failed: %s" % prepared)
			game.queue_free()
			await process_frame
			quit(1)
			return
	await settle_scene(self, settle_frames)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var scenario_contract := inspect_production_scenario(game, scenario)
	if not bool(scenario_contract.get("valid", false)):
		printerr("audio voice census: invalid production scenario: %s" % scenario_contract)
		game.queue_free()
		await process_frame
		quit(1)
		return
	var report := measure_frozen_scene(
		game,
		scenario,
		int(scenario_contract.get("loaded_instance_count", -1)),
		settle_frames
	)
	var errors := validate_report(report)
	if not errors.is_empty():
		printerr("audio voice census: invalid report: %s" % errors)
		game.queue_free()
		await process_frame
		quit(1)
		return
	print(JSON.stringify(report, "\t"))
	var json_path := OS.get_environment(JSON_ENVIRONMENT_VARIABLE)
	if not json_path.is_empty():
		var file := FileAccess.open(json_path, FileAccess.WRITE)
		if file == null:
			printerr("audio voice census: cannot write JSON: %s" % json_path)
			game.queue_free()
			await process_frame
			quit(1)
			return
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	game.queue_free()
	await process_frame
	quit(0)


static func settle_scene(tree: SceneTree, settle_frames: int = DEFAULT_SETTLE_FRAMES) -> void:
	for _frame in maxi(1, settle_frames):
		await tree.process_frame
	await tree.physics_frame
	await tree.process_frame


static func prepare_cinder_loaded_scenario(game: GameFlow) -> Dictionary:
	return await GEOMETRY_CENSUS.prepare_cinder_loaded_scenario(game)


static func inspect_production_scenario(scene_root: Node, scenario: StringName) -> Dictionary:
	return GEOMETRY_CENSUS.inspect_production_scenario(scene_root, scenario)


func measure_frozen_scene(
		scene_root: Node,
		scenario: StringName,
		loaded_instance_count: int,
		settle_frames: int = DEFAULT_SETTLE_FRAMES
	) -> Dictionary:
	_reset_measurement()
	_walk_players(scene_root, "")
	_stream_census.collect_retained(scene_root)
	_finalize_components()
	var totals := _build_totals(_player_rows)
	var retained_rows := _stream_census.retained_rows()
	var report := {
		"schema_version": SCHEMA_VERSION,
		"scenario": str(scenario),
		"loaded_instance_count": loaded_instance_count,
		"settle_frames": settle_frames,
		"freeze_policy": "settle_idle_frames_then_one_physics_and_one_idle_frame_then_disable_Main_process_mode",
		"measurement_scope": "scene_graph_audio_players_and_reachable_AudioStream_payloads",
		"totals": totals,
		"bus_split": _build_bus_split(_player_rows),
		"component_buckets": _component_rows.duplicate(true),
		"players": _player_rows.duplicate(true),
		"retained_streams": {
			"unique_count": retained_rows.size(),
			"payload_bytes": _stream_census.retained_payload_bytes(),
			"unknown_payload_count": _stream_census.retained_unknown_payload_count(),
			"skipped_freed_object_references": _stream_census.skipped_freed_object_references,
			"rows": retained_rows,
		},
		"authority_exclusions": AUTHORITY_EXCLUSIONS.duplicate(),
	}
	report["measurement_fingerprint"] = build_measurement_fingerprint(report)
	return report.duplicate(true)


func _reset_measurement() -> void:
	_stream_census = AudioStreamResourceCensus.new()
	_player_rows = []
	_component_rows = {}


func _walk_players(node: Node, path: String) -> void:
	var here := path
	if not here.is_empty():
		here += "/"
	here += _stable_sibling_segment(node)
	var effective := here.substr(here.find("/") + 1) if here.contains("/") else ""
	if _is_audio_player(node):
		var stream := node.get("stream") as AudioStream
		_stream_census.note_bound(stream)
		var exposed := _has_property(node, &"max_polyphony")
		var polyphony := int(node.get("max_polyphony")) if exposed else 0
		var row := {
			"path": effective,
			"bucket": _bucket_for(effective),
			"class": node.get_class(),
			"bus": str(node.get("bus")),
			"playing": bool(node.get("playing")),
			"max_polyphony_exposed": exposed,
			"max_polyphony": polyphony,
			"bound_stream_class": stream.get_class() if stream != null else "",
			"bound_stream_path": stream.resource_path if stream != null else "",
		}
		_player_rows.append(row)
		_note_component_player(row, stream)
	for child in node.get_children():
		_walk_players(child, here)


func _note_component_player(row: Dictionary, stream: AudioStream) -> void:
	var bucket := str(row.get("bucket", FALLBACK_BUCKET))
	if not _component_rows.has(bucket):
		_component_rows[bucket] = _empty_count_row()
	var component := _component_rows[bucket] as Dictionary
	_increment_count_row(component, row)
	if stream != null:
		(component["_bound_stream_ids"] as Dictionary)[stream.get_instance_id()] = stream


func _finalize_components() -> void:
	for bucket in _component_rows:
		var row := _component_rows[bucket] as Dictionary
		var stream_ids := row.get("_bound_stream_ids", {}) as Dictionary
		var bytes := 0
		for stream_variant in stream_ids.values():
			bytes += AudioStreamResourceCensus._payload_bytes(stream_variant as AudioStream).size()
		row["bound_unique_streams"] = stream_ids.size()
		row["bound_unique_stream_payload_bytes"] = bytes
		row.erase("_bound_stream_ids")
		row["bus_split"] = _sort_dictionary(row.get("bus_split", {}) as Dictionary)
	_component_rows = _sort_dictionary(_component_rows)
	_player_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("path", "")) < str(b.get("path", ""))
	)


static func _build_totals(rows: Array[Dictionary]) -> Dictionary:
	var totals := _empty_count_row()
	for row in rows:
		_increment_count_row(totals, row)
	totals.erase("bus_split")
	totals.erase("_bound_stream_ids")
	return totals


static func _build_bus_split(rows: Array[Dictionary]) -> Dictionary:
	var buses := {}
	for row in rows:
		var bus := str(row.get("bus", ""))
		if not buses.has(bus):
			buses[bus] = _empty_bus_row()
		_increment_bus_row(buses[bus] as Dictionary, row)
	return _sort_dictionary(buses)


static func _empty_count_row() -> Dictionary:
	return {
		"player_nodes": 0,
		"audio_stream_player_nodes": 0,
		"audio_stream_player_2d_nodes": 0,
		"audio_stream_player_3d_nodes": 0,
		"currently_playing_nodes": 0,
		"currently_playing_voice_lower_bound": 0,
		"currently_playing_voice_ceiling": 0,
		"max_polyphony_exposed_nodes": 0,
		"max_polyphony_unexposed_nodes": 0,
		"summed_max_polyphony_ceiling": 0,
		"bus_split": {},
		"_bound_stream_ids": {},
	}


static func _empty_bus_row() -> Dictionary:
	return {
		"player_nodes": 0,
		"currently_playing_nodes": 0,
		"currently_playing_voice_lower_bound": 0,
		"currently_playing_voice_ceiling": 0,
		"max_polyphony_exposed_nodes": 0,
		"max_polyphony_unexposed_nodes": 0,
		"summed_max_polyphony_ceiling": 0,
	}


static func _increment_count_row(target: Dictionary, player: Dictionary) -> void:
	target["player_nodes"] = int(target.get("player_nodes", 0)) + 1
	match str(player.get("class", "")):
		"AudioStreamPlayer":
			target["audio_stream_player_nodes"] = int(target.get("audio_stream_player_nodes", 0)) + 1
		"AudioStreamPlayer2D":
			target["audio_stream_player_2d_nodes"] = int(target.get("audio_stream_player_2d_nodes", 0)) + 1
		"AudioStreamPlayer3D":
			target["audio_stream_player_3d_nodes"] = int(target.get("audio_stream_player_3d_nodes", 0)) + 1
	_increment_voice_metrics(target, player)
	var bus := str(player.get("bus", ""))
	var bus_split := target.get("bus_split", {}) as Dictionary
	if not bus_split.has(bus):
		bus_split[bus] = _empty_bus_row()
	_increment_bus_row(bus_split[bus] as Dictionary, player)


static func _increment_bus_row(target: Dictionary, player: Dictionary) -> void:
	target["player_nodes"] = int(target.get("player_nodes", 0)) + 1
	_increment_voice_metrics(target, player)


static func _increment_voice_metrics(target: Dictionary, player: Dictionary) -> void:
	var exposed := bool(player.get("max_polyphony_exposed", false))
	var polyphony := maxi(1, int(player.get("max_polyphony", 0))) if exposed else 1
	if exposed:
		target["max_polyphony_exposed_nodes"] = int(target.get("max_polyphony_exposed_nodes", 0)) + 1
		target["summed_max_polyphony_ceiling"] = int(target.get("summed_max_polyphony_ceiling", 0)) + polyphony
	else:
		target["max_polyphony_unexposed_nodes"] = int(target.get("max_polyphony_unexposed_nodes", 0)) + 1
	if bool(player.get("playing", false)):
		target["currently_playing_nodes"] = int(target.get("currently_playing_nodes", 0)) + 1
		target["currently_playing_voice_lower_bound"] = int(target.get("currently_playing_voice_lower_bound", 0)) + 1
		target["currently_playing_voice_ceiling"] = int(target.get("currently_playing_voice_ceiling", 0)) + polyphony


static func _is_audio_player(node: Node) -> bool:
	return node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D


static func _has_property(object: Object, property_name: StringName) -> bool:
	for property_variant in object.get_property_list():
		if StringName(str((property_variant as Dictionary).get("name", ""))) == property_name:
			return true
	return false


static func _bucket_for(path: String) -> String:
	if path.is_empty():
		return FALLBACK_BUCKET
	var parts := path.split("/")
	if parts.size() >= 2 and SPLIT_ROOTS.has(parts[0]):
		return "%s/%s" % [parts[0], parts[1]]
	return parts[0]


static func _stable_sibling_segment(node: Node) -> String:
	var runtime_name := str(node.name)
	if not runtime_name.begins_with("@"):
		return runtime_name
	var parent := node.get_parent()
	if parent == null:
		return "%s[01]" % node.get_class()
	var ordinal := 0
	for sibling in parent.get_children():
		if sibling.get_class() == node.get_class() and str(sibling.name).begins_with("@"):
			ordinal += 1
			if sibling == node:
				break
	return "%s[%02d]" % [node.get_class(), maxi(ordinal, 1)]


static func _sort_dictionary(source: Dictionary) -> Dictionary:
	var sorted := {}
	var keys := source.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for key in keys:
		sorted[str(key)] = source[key]
	return sorted


static func build_measurement_fingerprint(report: Dictionary) -> String:
	var descriptors := PackedStringArray([
		"schema=%d|scenario=%s|loaded=%d|settle=%d" % [
			int(report.get("schema_version", -1)),
			str(report.get("scenario", "")),
			int(report.get("loaded_instance_count", -1)),
			int(report.get("settle_frames", -1)),
		],
		"scope=%s|freeze=%s" % [
			str(report.get("measurement_scope", "")),
			str(report.get("freeze_policy", "")),
		],
		"totals=%s" % JSON.stringify(_canonical_json_value(report.get("totals", {}))),
		"buses=%s" % JSON.stringify(_canonical_json_value(report.get("bus_split", {}))),
		"components=%s" % JSON.stringify(_canonical_json_value(report.get("component_buckets", {}))),
	])
	for player_variant in report.get("players", []) as Array:
		descriptors.append("player=%s" % JSON.stringify(_canonical_json_value(player_variant)))
	var streams := report.get("retained_streams", {}) as Dictionary
	# Freed-object skip telemetry is retained in the report for traversal audit,
	# but is not audio budget currency and therefore cannot perturb the audio
	# fingerprint when an unrelated visual component retains a dead Object slot.
	descriptors.append(
		"streams|unique=%d|bytes=%d|unknown=%d" % [
			int(streams.get("unique_count", -1)),
			int(streams.get("payload_bytes", -1)),
			int(streams.get("unknown_payload_count", -1)),
		]
	)
	for stream_variant in streams.get("rows", []) as Array:
		descriptors.append("stream=%s" % JSON.stringify(_canonical_json_value(stream_variant)))
	descriptors.sort()
	return "\n".join(descriptors).sha256_text()


static func validate_report(report: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not report is Dictionary:
		return PackedStringArray(["report must be a Dictionary"])
	var typed := report as Dictionary
	if not _is_json_integer(typed.get("schema_version")) \
		or int(typed.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("schema_version must be exact integer %d" % SCHEMA_VERSION)
	if typeof(typed.get("scenario")) != TYPE_STRING or StringName(typed.get("scenario", "")) not in [
		SCENARIO_STATION_RESIDENT, SCENARIO_CINDER_LOADED,
	]:
		errors.append("scenario must be a supported String")
	for integer_field in ["loaded_instance_count", "settle_frames"]:
		if not _is_json_integer(typed.get(integer_field)) \
			or int(typed.get(integer_field, -1)) < 0:
			errors.append("%s must be a non-negative integer" % integer_field)
	for dictionary_field in ["totals", "bus_split", "component_buckets", "retained_streams"]:
		if not typed.get(dictionary_field) is Dictionary:
			errors.append("%s must be a Dictionary" % dictionary_field)
	if not typed.get("players") is Array:
		errors.append("players must be an Array")
	if not typed.get("authority_exclusions") is Array:
		errors.append("authority_exclusions must be an Array")
	if errors.is_empty():
		var expected := build_measurement_fingerprint(typed)
		if typeof(typed.get("measurement_fingerprint")) != TYPE_STRING \
			or str(typed.get("measurement_fingerprint", "")) != expected:
			errors.append("measurement_fingerprint does not match deterministic report content")
	return errors


static func _is_json_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floorf(float(value))


static func _canonical_json_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and _is_json_integer(value):
		return int(value)
	if value is Array:
		var normalized := []
		for item in value as Array:
			normalized.append(_canonical_json_value(item))
		return normalized
	if value is Dictionary:
		var normalized := {}
		for key in value as Dictionary:
			normalized[key] = _canonical_json_value((value as Dictionary)[key])
		return normalized
	return value
