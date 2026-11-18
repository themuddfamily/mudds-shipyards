extends SceneTree

const EXPECTED_RATED_FIELDS := {
	"maximum_speed": ["m/s", "benefit", "flight"],
	"maximum_hull": ["hull point", "benefit", "systems"],
	"boost_speed": ["m/s", "benefit", "flight"],
	"thrust_acceleration": ["m/s2", "benefit", "flight"],
	"yaw_speed_degrees": ["degree/s", "benefit", "flight"],
	"roll_speed_degrees": ["degree/s", "benefit", "flight"],
	"brake_acceleration": ["m/s2", "benefit", "flight"],
	"passive_drag": ["m/s2", "cost", "flight"],
	"boost_multiplier": ["ratio", "benefit", "flight"],
	"landing_maximum_speed": ["m/s", "benefit", "systems"],
	"engine_start_time": ["s", "cost", "systems"],
	"weapon_cooldown": ["s", "cost", "systems"],
	"throttle_response": ["1/s", "benefit", "flight"],
	"flight_assist_strength": ["1/s", "undirected", "flight"],
	"visual_bank_degrees": ["degree", "undirected", "flight"],
	"maximum_mouse_turn_degrees": ["degree", "undirected", "flight"],
}
const EXPECTED_MISSING_DIMENSIONS := [
	"component_consequences_and_repair", "firepower_and_range", "cargo",
	"passenger_and_support", "collision_footprint", "boarding_time", "skill_floor",
	"complete_role_and_capability_metadata",
]

## Focused production proof for the read-only Fleet Registry terminal. The real
## PlayerController walks into the shared station candidate, uses the ordinary
## interaction dispatch, and receives detached fleet rows without changing any
## berth lease or pending-regeneration entry.

const VALID_STATES: Array[StringName] = [
	&"available", &"occupied", &"destroyed", &"regenerating",
]

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--capture-rated-registry" in OS.get_cmdline_user_args():
		await _capture_rated_registry()
		return
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	await process_frame

	var player := game.player as PlayerController
	var console := game.world.call(&"get_fleet_registry_console") as Area3D
	_check(
		player != null and console != null,
		"production Main exposes the real Player and Fleet Registry terminal"
	)
	if player == null or console == null:
		await _finish(game)
		return

	# The console's 4.8 x 2.8 x 2.0 m interaction box reaches 1.0 m towards the
	# approach and the player's interaction sphere 2.35 m, so a 2.8 m stage was
	# already inside the prompt and only "walked" when a starved process ran
	# several physics ticks per iteration. Stage outside both reaches.
	var staged_position := console.global_position + Vector3(0.0, 0.0, -4.6)
	player.teleport_to(Transform3D(Basis(Vector3.UP, PI), staged_position))
	await physics_frame
	var walk_start := player.global_position
	Input.action_press(&"move_forward")
	for _frame in 50:
		await physics_frame
		await process_frame
		if game.station_interaction_candidate == console:
			break
	Input.action_release(&"move_forward")
	await physics_frame
	await process_frame
	_check(
		player.global_position.distance_to(walk_start) > 0.35
			and game.station_interaction_candidate == console
			and str(console.call(&"get_interaction_prompt")).contains("VIEW FLEET REGISTRY")
			and not bool(game.get_boarding_confirmation_presentation_report().get(
				"attached", true
			)),
		"normal locomotion reaches the shared prompt without a stale boarding card"
	)

	var berths_before := _berth_snapshot(game.world)
	var regeneration_before := _regeneration_snapshot(game)
	game.call(&"_on_interact_requested")
	await process_frame
	var presented := console.call(&"get_presentation_snapshot") as Dictionary
	var live_snapshot := presented.get("last_snapshot", {}) as Dictionary
	var rows := live_snapshot.get("rows", []) as Array
	var text := str(presented.get("screen_text", ""))
	var rows_are_live_and_complete := rows.size() == game.ships.size() and not rows.is_empty()
	for row_raw: Variant in rows:
		var row := row_raw as Dictionary
		var state := StringName(row.get("state", &""))
		rows_are_live_and_complete = (
			rows_are_live_and_complete
			and state in VALID_STATES
			and text.contains(String(row.get("display_name", "")).to_upper().left(18))
			and text.contains(String(state).to_upper())
		)
	_check(
		int(presented.get("presentation_sequence", 0)) == 1
			and rows_are_live_and_complete
			and not _contains_object(live_snapshot),
		"one shared interaction paints every retained craft as detached available/occupied/destroyed/regenerating data"
	)
	# First new assertion observes actual E output on the old runtime too.
	# No new console API is called until all sixteen fields have been observed.
	var complete_handling := rows.size() == 15
	for row: Dictionary in rows:
		var budget: Variant = row.get("rated_budget")
		complete_handling = complete_handling and budget is Dictionary and budget.get("fields") is Dictionary and budget.fields.size() == 16
	_check(complete_handling, "ordinary E must publish all sixteen authored handling fields; the old two-field subset is missing fourteen")
	if not complete_handling:
		await _finish(game)
		return
	# Must compile against the old runtime and fail on actual first-E missing data.
	var complete_footprint := rows.size() == 15
	for row: Dictionary in rows:
		var footprint: Variant = (row.get("rated_budget", {}) as Dictionary).get("footprint")
		complete_footprint = complete_footprint and footprint is Dictionary and footprint.get("status") == "MEASURED" and footprint.get("fields") is Dictionary and footprint.fields.size() == 3
	_check(complete_footprint, "ordinary E must publish actual complete enabled-root collision footprint for all fifteen live craft")
	if not complete_footprint:
		await _finish(game)
		return
	var first_accepted_snapshot := live_snapshot.duplicate(true)
	for page in 5:
		if page > 0:
			game.call(&"_on_interact_requested")
			await process_frame
		presented = console.call(&"get_presentation_snapshot") as Dictionary
		live_snapshot = presented.last_snapshot
		text = presented.screen_text
		_check_rated_rows(game, live_snapshot, text, page)
		_check_console_bounds(console, page)
		var default_receipt := console.call(&"present_fleet_snapshot", live_snapshot) as Dictionary
		_check(default_receipt.get("accepted", false) and (console.call(&"get_presentation_snapshot") as Dictionary).screen_text == text, "default snapshot refresh preserves the current page")
	game.call(&"_on_interact_requested")
	await process_frame
	_check((console.call(&"get_presentation_snapshot") as Dictionary).screen_text.begins_with("RATED 1/5"), "sixth ordinary E wraps back to page one")
	_check(
		_berth_snapshot(game.world) == berths_before
			and _regeneration_snapshot(game) == regeneration_before,
		"reading the registry changes no berth owner, occupant, token, or regeneration entry"
	)
	var authority := presented.get("authority", {}) as Dictionary
	_check(
		authority == {
			"berth": false,
			"regeneration": false,
			"ship_lifecycle": false,
			"fleet_membership": false,
		},
		"the terminal publishes explicit zero-authority presentation ownership"
	)

	# Exercise the complete screen vocabulary with detached values only. This is
	# presentation input, not a forged ship/berth fixture, and must remain unable
	# to alter production lifecycle state.
	var vocabulary_snapshot := live_snapshot.duplicate(true)
	vocabulary_snapshot["rows"] = [
		{"ship_id": &"a", "display_name": "Available", "berth_id": &"a", "state": &"available"},
		{"ship_id": &"b", "display_name": "Occupied", "berth_id": &"b", "state": &"occupied"},
		{"ship_id": &"c", "display_name": "Destroyed", "berth_id": &"c", "state": &"destroyed"},
		{"ship_id": &"d", "display_name": "Regenerating", "berth_id": &"d", "state": &"regenerating"},
	]
	var receipt := console.call(&"present_fleet_snapshot", vocabulary_snapshot) as Dictionary
	presented = console.call(&"get_presentation_snapshot") as Dictionary
	text = str(presented.get("screen_text", ""))
	_check(
		bool(receipt.get("accepted", false))
			and text.contains("AVAILABLE")
			and text.contains("OCCUPIED")
			and text.contains("DESTROYED")
			and text.contains("REGENERATING")
			and _berth_snapshot(game.world) == berths_before
			and _regeneration_snapshot(game) == regeneration_before,
		"the detached screen renders all four promised states with no authority side effect"
	)
	var sequence_before_rejection := int(presented.get("presentation_sequence", 0))
	var authority_bearing_snapshot := vocabulary_snapshot.duplicate(true)
	authority_bearing_snapshot["live_world"] = game.world
	receipt = console.call(&"present_fleet_snapshot", authority_bearing_snapshot) as Dictionary
	presented = console.call(&"get_presentation_snapshot") as Dictionary
	_check(
		not bool(receipt.get("accepted", true))
			and StringName(receipt.get("reason", &"")) == &"registry_snapshot_not_detached"
			and int(presented.get("presentation_sequence", 0)) == sequence_before_rejection,
		"the terminal refuses Object-bearing input instead of retaining live authority"
	)
	var callable_bearing_snapshot := vocabulary_snapshot.duplicate(true)
	callable_bearing_snapshot["live_callback"] = Callable(game, &"queue_free")
	receipt = console.call(
		&"present_fleet_snapshot", callable_bearing_snapshot
	) as Dictionary
	presented = console.call(&"get_presentation_snapshot") as Dictionary
	_check(
		not bool(receipt.get("accepted", true))
			and StringName(receipt.get("reason", &"")) \
				== &"registry_snapshot_not_detached"
			and int(presented.get("presentation_sequence", 0)) \
				== sequence_before_rejection,
		"the terminal refuses Callables that retain live object/method authority"
	)

	_check_rated_refusals(console, live_snapshot)
	if _failures.is_empty():
		_write_rated_snapshot(first_accepted_snapshot)
	await _finish(game)


func _berth_snapshot(world: Node) -> Dictionary:
	var snapshot := {}
	for berth_id: StringName in world.call(&"get_berth_ids") as Array[StringName]:
		var berth := world.call(&"get_berth_node", berth_id) as ShipBerth
		var owner := berth.get_reservation_owner() if berth != null else null
		var occupant := berth.get_occupant() if berth != null else null
		snapshot[berth_id] = {
			"owner_instance_id": owner.get_instance_id() if is_instance_valid(owner) else 0,
			"occupant_instance_id": occupant.get_instance_id() if is_instance_valid(occupant) else 0,
			"reserved_ship_id": berth.get_reserved_ship_id() if berth != null else &"",
			"token": berth.get_reservation_token(owner) if is_instance_valid(owner) else &"",
		}
	return snapshot


func _regeneration_snapshot(game: GameFlow) -> Dictionary:
	var snapshot := {}
	var pending := game.get("_regeneration_pending") as Dictionary
	for instance_id_raw: Variant in pending.keys():
		var entry := pending.get(instance_id_raw, {}) as Dictionary
		var ship_ref := entry.get("ship") as WeakRef
		var pending_ship: Object = ship_ref.get_ref() if ship_ref != null else null
		snapshot[int(instance_id_raw)] = {
			"ready_at_msec": int(entry.get("ready_at_msec", 0)),
			"ship_instance_id": (
				pending_ship.get_instance_id() if is_instance_valid(pending_ship) else 0
			),
		}
	return snapshot


func _contains_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			if _contains_object(key) or _contains_object((value as Dictionary).get(key)):
				return true
	elif value is Array:
		for item: Variant in value as Array:
			if _contains_object(item):
				return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _finish(game: GameFlow) -> void:
	Input.action_release(&"move_forward")
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("FLEET_REGISTRY_CONSOLE_PRODUCTION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_rated_rows(game: GameFlow, snapshot: Dictionary, text: String, page: int) -> void:
	var rows := snapshot.get("rows", []) as Array
	_check(rows.size() == 15 and text.begins_with(("RATED %d/5" % [page + 1]) if page < 4 else "COLLISION 5/5") and text.contains("INTERACT:NEXT"), "physical page labels rated data and ordinary next interaction")
	var pages := [
		["maximum_speed", "maximum_hull", "boost_speed", "thrust_acceleration"],
		["yaw_speed_degrees", "roll_speed_degrees", "brake_acceleration", "passive_drag"],
		["boost_multiplier", "landing_maximum_speed", "engine_start_time", "weapon_cooldown"],
		["throttle_response", "flight_assist_strength", "visual_bank_degrees", "maximum_mouse_turn_degrees"],
	]
	for row_index in rows.size():
		var row: Dictionary = rows[row_index]
		var craft := game.call(&"_find_flyable_ship_by_id", StringName(row.ship_id)) as HeroShip
		_check(craft != null, "rated row identifies an actual current Main craft")
		if craft == null:
			continue
		var definition := craft.get_ship_definition()
		var budget: Dictionary = row.rated_budget
		var missing := EXPECTED_MISSING_DIMENSIONS.duplicate()
		missing.erase("collision_footprint")
		_check(budget.ship_id == row.ship_id and budget.qualification == &"NOT_QUALIFIED" and budget.missing_dimensions == missing and not _contains_object(budget), "rated row retains identity and seven still-missing actual-role dimensions")
		_check_footprint_geometry(craft, budget)
		var cells := PackedStringArray()
		for axis: String in EXPECTED_RATED_FIELDS:
			var spec: Array = EXPECTED_RATED_FIELDS[axis]
			var field: Dictionary = budget.fields[axis]
			var profile: Dictionary = definition.get_flight_profile() if spec[2] == "flight" else definition.get_systems_profile()
			var raw: float = profile[axis]
			_check(field.raw == raw and field.unit == spec[0] and field.direction == spec[1] and field.unit_scale == 1.0 and field.source == "ShipDefinition.get_%s_profile.%s" % [spec[2], axis], "terminal %s retains actual raw/source/unit/direction" % axis)
			if spec[1] == "undirected":
				_check(not field.has("normalized"), "terminal feel remains raw only")
			else:
				_check(field.normalized == (raw / (1.0 + raw) if spec[1] == "benefit" else 1.0 / (1.0 + raw)), "terminal directed index retains exact full precision")
		if page == 4:
			for axis: String in ["span", "height", "length"]:
				var field: Dictionary = budget.footprint.fields[axis]
				cells.append("%.3f/%.3f" % [field.raw, field.normalized])
		else:
			for axis: String in pages[page]:
				var field: Dictionary = budget.fields[axis]
				cells.append(str(field.raw) if field.direction == "undirected" else "%s/%.3f" % [str(field.raw), field.normalized])
		var expected := "%-18s %-12s %s" % [str(row.display_name).strip_edges().replace("_", " ").to_upper().left(18), str(row.state).to_upper(), "  ".join(cells)]
		_check(text.split("\n")[row_index + 1] == expected, "page retains each current name/state and four correctly ordered raw/index or feel cells")


func _check_console_bounds(console: Area3D, page: int) -> void:
	var label := console.get_node("FleetRegistryLiveRows") as Label3D
	var screen := console.get_node("FleetRegistryLiveScreen") as MeshInstance3D
	var bounds := screen.global_transform.affine_inverse() * label.global_transform * label.get_aabb()
	var screen_bounds := screen.get_aabb()
	print("FLEET_REGISTRY_ACTUAL_SCREEN_BOUNDS: ", {"page": page + 1, "lines": label.text.split("\n").size(), "glyph": bounds, "screen": screen_bounds, "font_size": label.font_size, "pixel_size": label.pixel_size})
	_check(label.text.split("\n").size() == 16 and label.font_size == 40 and is_equal_approx(label.pixel_size, 0.0016) and screen.mesh.size == Vector3(3.76, 1.46, 0.018) and bounds.position.x >= screen_bounds.position.x and bounds.end.x <= screen_bounds.end.x and bounds.position.y >= screen_bounds.position.y and bounds.end.y <= screen_bounds.end.y, "all fifteen names/states plus header fit the unchanged screen on page %d" % [page + 1])

func _check_rated_refusals(console: Area3D, source: Dictionary) -> void:
	var rows := source.get("rows", []) as Array
	if rows.is_empty() or not (rows[0] as Dictionary).get("rated_budget") is Dictionary:
		return
	var receipt := console.call(&"present_fleet_snapshot", source) as Dictionary
	_check(bool(receipt.get("accepted", false)), "sourced rated snapshot can be presented again")
	var retained := console.call(&"get_presentation_snapshot") as Dictionary
	var edited := source.duplicate(true)
	edited.rows[0].rated_budget.fields.maximum_speed.raw = 999.0
	_check((console.call(&"get_presentation_snapshot") as Dictionary) == retained, "detached snapshot editing cannot mutate retained terminal state")
	var cases: Array = []
	for replacement in [null, [], "budget", {}, {"ship_id": []}]:
		var candidate := source.duplicate(true)
		candidate.rows[0].rated_budget = replacement
		cases.append(candidate)
	for patch in [{"ship_id": &"foreign"}, {"ship_id": []}, {"valid": []}, {"qualification": []}, {"qualification": "QUALIFIED"}, {"missing_dimensions": []}, {"missing_dimensions": [null]}, {"fields": []}, {"live": console}]:
		var candidate := source.duplicate(true)
		candidate.rows[0].rated_budget.merge(patch, true)
		cases.append(candidate)
	for patch in [{"raw": INF}, {"raw": NAN}, {"raw": -1.0}, {"raw": []}, {"normalized": INF}, {"normalized": []}, {"normalized": 0.5}, {"unit": []}, {"unit": "km/h"}, {"unit_scale": []}, {"unit_scale": 2.0}, {"direction": []}, {"direction": "lower"}, {"source": []}, {"source": "invented"}]:
		var candidate := source.duplicate(true)
		candidate.rows[0].rated_budget.fields.maximum_speed.merge(patch, true)
		cases.append(candidate)
	for axis: String in EXPECTED_RATED_FIELDS:
		for patch: Dictionary in [{"raw": INF}, {"raw": NAN}, {"raw": -1.0}, {"unit": "wrong"}, {"direction": "wrong"}, {"source": "invented"}, {"unit_scale": 2.0}]:
			var candidate := source.duplicate(true)
			candidate.rows[0].rated_budget.fields[axis].merge(patch, true)
			cases.append(candidate)
		var missing_field := source.duplicate(true)
		missing_field.rows[0].rated_budget.fields.erase(axis)
		cases.append(missing_field)
		var wrong_index := source.duplicate(true)
		wrong_index.rows[0].rated_budget.fields[axis]["normalized"] = 0.123
		cases.append(wrong_index)
	for replacement: Variant in [null, [], {}, {"status": "MEASURED"}, "geometry"]:
		var candidate := source.duplicate(true)
		candidate.rows[0].rated_budget.footprint = replacement
		cases.append(candidate)
	for patch: Dictionary in [{"status": "UNKNOWN"}, {"status": []}, {"reason": "invented"}, {"source": "landing_clearance"}, {"source": []}, {"ship_id": "foreign"}, {"ship_id": []}, {"shape_count": 0}, {"shape_count": -1}, {"shape_count": 1.5}, {"shape_count": INF}, {"shape_count": []}, {"local_bounds": []}, {"fields": []}]:
		var candidate := source.duplicate(true)
		candidate.rows[0].rated_budget.footprint.merge(patch, true)
		cases.append(candidate)
	for bounds_key: String in ["position", "size"]:
		for replacement: Variant in [null, [], {}, {"x": INF, "y": 1.0, "z": 1.0}, {"x": [], "y": 1.0, "z": 1.0}, {"x": 1.0, "y": 1.0, "z": 1.0, "w": 1.0}]:
			var candidate := source.duplicate(true)
			candidate.rows[0].rated_budget.footprint.local_bounds[bounds_key] = replacement
			cases.append(candidate)
	for axis: String in ["span", "height", "length"]:
		for metadata: String in ["unit", "direction", "source"]:
			for malformed_value: Variant in [[], ["nested"], {}, null, 17, false]:
				var candidate := source.duplicate(true)
				candidate.rows[0].rated_budget.footprint.fields[axis][metadata] = malformed_value
				cases.append(candidate)
		for patch: Dictionary in [{"raw": 0.0}, {"raw": -1.0}, {"raw": NAN}, {"raw": INF}, {"raw": []}, {"normalized": 0.5}, {"normalized": INF}, {"normalized": []}, {"direction": "benefit"}, {"unit": "km"}, {"unit_scale": 1000.0}, {"source": "authored_size_class"}]:
			var candidate := source.duplicate(true)
			candidate.rows[0].rated_budget.footprint.fields[axis].merge(patch, true)
			cases.append(candidate)
		var missing_axis := source.duplicate(true)
		missing_axis.rows[0].rated_budget.footprint.fields.erase(axis)
		cases.append(missing_axis)
	var inconsistent_bounds := source.duplicate(true)
	inconsistent_bounds.rows[0].rated_budget.footprint.local_bounds.size.x += 1.0
	cases.append(inconsistent_bounds)
	var missing_geometry := source.duplicate(true)
	missing_geometry.rows[0].rated_budget.footprint.erase("local_bounds")
	cases.append(missing_geometry)
	var missing_flag := source.duplicate(true)
	missing_flag.rows[0].rated_budget.missing_dimensions.append("collision_footprint")
	cases.append(missing_flag)
	var mixed := source.duplicate(true)
	mixed.rows[0].erase("rated_budget")
	cases.append(mixed)
	for candidate: Dictionary in cases:
		receipt = console.call(&"present_fleet_snapshot", candidate, true) as Dictionary
		_check(not bool(receipt.get("accepted", true)) and (console.call(&"get_presentation_snapshot") as Dictionary) == retained, "malformed rated payload refuses atomically without changing text, sequence or retained data")
	# Unknown and unavailable data remain readable, with no zero-metre benefit.
	for status: String in ["UNKNOWN", "UNAVAILABLE"]:
		var unavailable := source.duplicate(true)
		unavailable.rows[0].rated_budget.footprint = {"status": status, "reason": "live_craft_not_supplied" if status == "UNKNOWN" else "no_enabled_root_shapes", "source": "actual_enabled_direct_root_collision_shapes"}
		unavailable.rows[0].rated_budget.missing_dimensions = EXPECTED_MISSING_DIMENSIONS.duplicate()
		receipt = console.call(&"present_fleet_snapshot", unavailable) as Dictionary
		_check(bool(receipt.get("accepted", false)), "explicit missing geometry remains presentable without pretending qualification")
		for step in 5:
			var presentation := console.call(&"get_presentation_snapshot") as Dictionary
			if int(presentation.get("rated_page", -1)) == 4:
				break
			console.call(&"present_fleet_snapshot", unavailable, true)
		var unavailable_text := str((console.call(&"get_presentation_snapshot") as Dictionary).screen_text)
		_check(unavailable_text.begins_with("COLLISION 5/5") and unavailable_text.split("\n")[1].contains("%s  %s  %s" % [status, status, status]), "missing footprint prints explicit unknown cells without numeric zeros")
		var malformed := unavailable.duplicate(true)
		malformed.rows[0].rated_budget.footprint["shape_count"] = 0
		var before := console.call(&"get_presentation_snapshot") as Dictionary
		receipt = console.call(&"present_fleet_snapshot", malformed, true) as Dictionary
		_check(not bool(receipt.get("accepted", true)) and (console.call(&"get_presentation_snapshot") as Dictionary) == before, "unmeasured footprint cannot acquire invented geometry or zero counts")
	var legacy := source.duplicate(true)
	var expected := PackedStringArray(["FLEET STATUS // LIVE"])
	for row: Dictionary in legacy.rows:
		row.erase("rated_budget")
		expected.append("%-18s  %s" % [str(row.display_name).strip_edges().replace("_", " ").to_upper().left(18), str(row.state).to_upper()])
	receipt = console.call(&"present_fleet_snapshot", legacy) as Dictionary
	_check(bool(receipt.get("accepted", false)) and (console.call(&"get_presentation_snapshot") as Dictionary).screen_text == "\n".join(expected), "all-budget-absent legacy snapshots retain the exact original status-only format")


func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.substr(prefix.length() + 1)
	return ""


func _write_rated_snapshot(snapshot: Dictionary) -> void:
	var path := _argument("--write-rated-snapshot")
	if path.is_empty():
		return
	_check(path.is_absolute_path(), "real rated snapshot output uses an explicit absolute path")
	if not path.is_absolute_path():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "real rated snapshot output opens")
	if file != null:
		file.store_string(JSON.stringify(snapshot, "\t"))
		file.close()


func _capture_rated_registry() -> void:
	# Production component only: Main is never instantiated in this branch.
	var path := _argument("--snapshot")
	var output := _argument("--output-dir")
	_check(path.is_absolute_path() and output.is_absolute_path(), "component capture requires explicit absolute snapshot and output paths")
	_check(DisplayServer.get_name() == "X11" and RenderingServer.get_current_rendering_method() == "forward_plus", "component capture requires isolated X11 Forward+")
	var snapshot: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path.is_absolute_path() and FileAccess.file_exists(path) else null
	_check(snapshot is Dictionary, "component capture reads the pinned real detached snapshot")
	if not _failures.is_empty():
		await _finish(null)
		return
	_check(snapshot.get("rows") is Array and snapshot.rows.size() == 15, "pinned real snapshot contains all fifteen rows")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	var component := Node3D.new()
	root.add_child(component)
	var console := preload("res://scripts/interaction/fleet_registry_console.gd").new() as Area3D
	component.add_child(console)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.3
	camera.position = Vector3(0.0, 0.38, -4.5)
	component.add_child(camera)
	camera.look_at(Vector3(0.0, 0.38, -1.1), Vector3.UP)
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101c25")
	component.add_child(environment)
	await process_frame
	var receipt := console.call(&"present_fleet_snapshot", snapshot) as Dictionary
	_check(bool(receipt.get("accepted", false)), "production component accepts the exact real captured snapshot")
	_check(DirAccess.make_dir_recursive_absolute(output) == OK, "component capture output directory is available")
	for page in 5:
		if page > 0:
			receipt = console.call(&"present_fleet_snapshot", snapshot, true) as Dictionary
			_check(bool(receipt.get("accepted", false)), "component advances the exact pinned snapshot")
		for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = viewport
			for frame in 8:
				await process_frame
				await RenderingServer.frame_post_draw
			_check_console_bounds(console, page)
			_check((console.call(&"get_presentation_snapshot") as Dictionary).screen_text.begins_with(("RATED %d/5" % [page + 1]) if page < 4 else "COLLISION 5/5"), "component captures the requested real page")
			var image := root.get_texture().get_image()
			_check(image.get_size() == viewport, "component capture has exact requested native dimensions")
			if _failures.is_empty():
				_check(image.save_png(output.path_join("fleet_footprint_page_%02d_%dx%d.png" % [page + 1, viewport.x, viewport.y])) == OK, "component capture saves the real terminal pixels")
	component.queue_free()
	await _finish(null)


## Independent support-point oracle: query each shape in six root-axis directions.
## This does not consume the production footprint Resource or landing clearance.
func _expected_root_geometry(craft: HeroShip) -> Dictionary:
	var bounds := AABB()
	var first := true
	var count := 0
	for child in craft.get_children():
		if not child is CollisionShape3D or (child as CollisionShape3D).disabled:
			continue
		var collision := child as CollisionShape3D
		var shape := collision.shape
		if shape == null:
			return {}
		count += 1
		for direction: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
			var local_direction := collision.basis.transposed() * direction
			var support := Vector3.ZERO
			if shape is BoxShape3D:
				var half := (shape as BoxShape3D).size * 0.5
				support = Vector3(half.x if local_direction.x >= 0 else -half.x, half.y if local_direction.y >= 0 else -half.y, half.z if local_direction.z >= 0 else -half.z)
			elif shape is ConvexPolygonShape3D:
				var points := (shape as ConvexPolygonShape3D).points
				if points.is_empty():
					return {}
				support = points[0]
				for point in points:
					if point.dot(local_direction) > support.dot(local_direction):
						support = point
			elif shape is CylinderShape3D:
				var cylinder := shape as CylinderShape3D
				var radial := Vector3(local_direction.x, 0, local_direction.z).normalized() * cylinder.radius
				support = radial + Vector3.UP * cylinder.height * (0.5 if local_direction.y >= 0 else -0.5)
			elif shape is SphereShape3D:
				support = local_direction.normalized() * (shape as SphereShape3D).radius
			elif shape is CapsuleShape3D:
				var capsule := shape as CapsuleShape3D
				support = local_direction.normalized() * capsule.radius + Vector3.UP * (capsule.height * 0.5 - capsule.radius) * (1.0 if local_direction.y >= 0 else -1.0)
			else:
				return {}
			var actual := collision.transform * support
			bounds = AABB(actual, Vector3.ZERO) if first else bounds.expand(actual)
			first = false
	return {"bounds": bounds, "count": count} if not first else {}


func _check_footprint_geometry(craft: HeroShip, budget: Dictionary) -> void:
	var expected := _expected_root_geometry(craft)
	var footprint: Dictionary = budget.get("footprint", {})
	_check(not expected.is_empty() and footprint.get("status") == "MEASURED", "actual enabled direct root geometry is measured for %s" % craft.get_ship_id())
	if expected.is_empty() or footprint.get("status") != "MEASURED":
		return
	var bounds: AABB = expected.bounds
	_check(footprint.ship_id == str(craft.get_ship_id()) and footprint.source == "actual_enabled_direct_root_collision_shapes" and footprint.shape_count == expected.count, "footprint identifies actual complete root union and shape count")
	var components := ["x", "y", "z"]
	var axes := ["span", "height", "length"]
	for index in 3:
		_check(is_equal_approx(float(footprint.local_bounds.position[components[index]]), bounds.position[index]) and is_equal_approx(float(footprint.local_bounds.size[components[index]]), bounds.size[index]), "complete union position and size match independent support points")
		var field: Dictionary = footprint.fields[axes[index]]
		_check(is_equal_approx(float(field.raw), bounds.size[index]) and field.unit == "m" and field.unit_scale == 1.0 and field.direction == "cost" and field.source == "actual_enabled_direct_root_collision_shapes" and field.normalized == 1.0 / (1.0 + field.raw), "physical dimension keeps exact metre cost normalization")
