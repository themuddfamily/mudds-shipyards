extends SceneTree
## test-matrix-timeout-seconds: 300
## The Aurora coastal survey and Rime ice-core survey against a real composed
## `Main`: their GameFlow, ActivityDirector, player, HUD and reward authority.
##
## Each survey is attached to a small stand-in surface (a floor, a rotated and
## offset `LandingRegion` and the three named anchors), driven through its own
## `interact()` by an on-foot player, and checked for:
## - a rejected reward store keeps the completed readings and the second E at
##   the final anchor records the reward exactly once;
## - an abandoned survey's objective no longer claims its lost progress;
## - a survey left running when a visit ends does not resume on the next
##   visit's arrival. The expedition keeps one survey for the whole session and
##   attaches it afresh to each visit's surface.

const MAIN := preload("res://scenes/main.tscn")
const AURORA_SURVEY := preload("res://scripts/activities/aurora_coastal_survey.gd")
const RIME_SURVEY := preload("res://scripts/activities/rime_ice_core_survey.gd")
const SUCCESS_MARKER := "PLANETARY_SURVEY_LIFECYCLE_TEST_OK"
const FAILURE_MARKER := "PLANETARY_SURVEY_LIFECYCLE_TEST_FAILED"
const ANCHOR_POINTS := [Vector3(0, 0, 0), Vector3(12, 0, 0), Vector3(24, 0, 0)]

var _failures: Array[String] = []
var _assertions := 0


class StubVisit:
	extends RefCounted
	var state: StringName = &"surface"

	func get_craft() -> HeroShip:
		return null


## Forwards to the real reward store and refuses commits while `reject` is set.
class RejectingStore:
	extends RefCounted
	var inner: RefCounted
	var reject := false
	var rejected := 0

	func get_snapshot() -> Variant:
		return inner.call(&"get_snapshot")

	func get_generation() -> int:
		return int(inner.call(&"get_generation"))

	func commit(payload: Dictionary, generation: int, transaction_id: String) -> Dictionary:
		if reject:
			rejected += 1
			return {"accepted": false, "reason": &"injected_write_failure"}
		return inner.call(&"commit", payload, generation, transaction_id) as Dictionary


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _i in 4:
		await process_frame
		await physics_frame
	var authority: RefCounted = game.get("_game_flow_reward_authority")
	_check(authority != null, "production Main composes the reward authority")
	if authority == null:
		await _finish(game)
		return
	var store := RejectingStore.new()
	store.inner = authority.get("_store")
	authority.set("_store", store)
	await _survey_case(game, store, AURORA_SURVEY, "Aurora", Vector3(4000, 600, 4000))
	await _survey_case(game, store, RIME_SURVEY, "Rime", Vector3(-4000, 600, 4000))
	await _finish(game)


func _survey_case(game: GameFlow, store: RejectingStore, script: GDScript, label: String,
		origin: Vector3) -> void:
	var visit := StubVisit.new()
	var survey: RefCounted = script.new(game, visit)
	var surface := _make_surface(origin)
	survey.attach(surface)

	# Abandoning after one reading loses that reading.
	await _stand_at(game, surface, 0)
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.ACTIVE,
		"%s: E at the start anchor starts the survey" % label)
	if script == RIME_SURVEY:
		survey.physics_tick(15.0)
		_check(is_equal_approx(float(survey.get_heat_snapshot().heat_s), RIME_SURVEY.HEAT_CAPACITY_S - 15.0),
			"Rime: the active on-foot survey spends heat")
		_heat_progress_case(survey)
	await _stand_at(game, surface, 1)
	_check(survey.interact() and int(survey.snapshot().next_checkpoint_index) == 1,
		"%s: E at the first anchor records reading 1/2" % label)
	await _stand_at(game, surface, 0)
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.FAILED,
		"%s: E at the start anchor abandons the running survey" % label)
	if script == RIME_SURVEY:
		_check(is_equal_approx(float(survey.get_heat_snapshot().heat_s), RIME_SURVEY.HEAT_CAPACITY_S),
			"Rime: abandoning resets the heater for a fresh survey")
	var abandoned_objective := String(survey.objective())
	_check(not abandoned_objective.contains("1/2"),
		"%s: an abandoned survey's objective does not claim lost progress (%s)" % [label, abandoned_objective])

	# A survey left running when the visit ends.
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.ACTIVE,
		"%s: the start anchor starts a fresh survey" % label)
	await _stand_at(game, surface, 1)
	_check(survey.interact() and int(survey.snapshot().next_checkpoint_index) == 1,
		"%s: the fresh survey records reading 1/2 before the visit ends" % label)
	if script == RIME_SURVEY:
		survey.physics_tick(25.0)
	visit.state = &"boarding"
	if survey.has_method(&"detach"):
		survey.call(&"detach")
	surface.queue_free()
	await process_frame
	await physics_frame
	var next_surface := _make_surface(origin + Vector3(37, -3, -52))
	visit.state = &"surface"
	survey.attach(next_surface)
	if script == RIME_SURVEY:
		_check(is_equal_approx(float(survey.get_heat_snapshot().heat_s), RIME_SURVEY.HEAT_CAPACITY_S),
			"Rime: a fresh visit resets heat instead of carrying the previous visit's expenditure")
	var carried := String(survey.objective())
	_check(_state(survey) != CheckpointRouteActivity.State.ACTIVE and not carried.contains("1/2"),
		"%s: a survey left running on the previous visit does not resume on arrival (%s)" % [label, carried])

	# Complete with a rejecting store, then retry.
	await _stand_at(game, next_surface, 0)
	if _state(survey) == CheckpointRouteActivity.State.ACTIVE:
		survey.interact()
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.ACTIVE,
		"%s: the next visit starts its own survey" % label)
	await _stand_at(game, next_surface, 1)
	survey.interact()
	await _stand_at(game, next_surface, 2)
	store.reject = true
	var rejected_before := store.rejected
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.COMPLETED
			and not survey.reward_recorded() and store.rejected > rejected_before,
		"%s: a rejected reward write keeps the completed readings unrecorded" % label)
	_check(String(survey.prompt()).begins_with("[ E ]"),
		"%s: the final anchor still offers E to retry the reward" % label)
	store.reject = false
	_check(survey.interact() and survey.reward_recorded() and _reward_count(game, survey) == 1,
		"%s: the retry records the reward once" % label)
	_check(not survey.interact() and _reward_count(game, survey) == 1,
		"%s: another E cannot record the reward twice" % label)
	next_surface.queue_free()
	await process_frame


func _heat_progress_case(survey: RefCounted) -> void:
	var progress := survey.capture() as Dictionary
	_check(RIME_SURVEY.valid_progress(progress)
			and is_equal_approx(float(progress.get("heat_s", -1.0)), float(survey.get_heat_snapshot().heat_s)),
		"Rime: captured progress includes the spent heater")
	var legacy := progress.duplicate(true)
	legacy.erase("heat_s")
	_check(RIME_SURVEY.valid_progress(legacy), "Rime: earlier saves without heat remain loadable")
	for invalid_heat: Variant in [-1.0, RIME_SURVEY.HEAT_CAPACITY_S + 1.0, INF, NAN, "50", true]:
		var malformed := progress.duplicate(true)
		malformed["heat_s"] = invalid_heat
		_check(not RIME_SURVEY.valid_progress(malformed),
			"Rime: invalid saved heat is rejected (%s)" % str(invalid_heat))
	for saved_heat: Variant in [50, 46.5500000000002, 50.0 / 3.0]:
		var heat_progress := progress.duplicate(true)
		heat_progress["heat_s"] = saved_heat
		var binding := RimeExpeditionPersistenceBinding.new()
		var normalized := binding.normalize_visit({
			"visit_state": "surface", "craft_home_berth_id": "test_berth",
			"on_foot": true, "survey": heat_progress,
		})
		var visit := normalized.get("visit", {}) as Dictionary
		# Match UserDataStore's default precision, rather than the receipt's.
		var round_trip := JSON.parse_string(JSON.stringify(visit)) as Dictionary
		_check(bool(normalized.get("accepted", false))
				and (visit.get("survey", {}) as Dictionary).get("heat_s") is float
				and RimeExpeditionPersistenceBinding._digest(visit) == RimeExpeditionPersistenceBinding._digest(round_trip),
			"Rime: saved heat keeps a stable store-precision JSON receipt (%s)" % saved_heat)



func _make_surface(origin: Vector3) -> Node3D:
	var surface := Node3D.new()
	surface.name = "StandInSurface"
	root.add_child(surface)
	surface.global_position = origin
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	surface.add_child(floor_body)
	floor_body.position = Vector3(0, -0.5, 0)
	var region := Node3D.new()
	region.name = "LandingRegion"
	surface.add_child(region)
	region.position = Vector3(-6, 0, 5)
	region.rotation.y = 0.7
	var names: Array = AURORA_SURVEY.ANCHORS + RIME_SURVEY.ANCHORS
	for index in names.size():
		var anchor := Marker3D.new()
		anchor.name = names[index]
		region.add_child(anchor)
		anchor.position = ANCHOR_POINTS[index % 3]
	return surface


func _stand_at(game: GameFlow, surface: Node3D, index: int) -> void:
	var region := surface.get_node("LandingRegion") as Node3D
	var target := region.to_global(ANCHOR_POINTS[index]) + Vector3(0.6, 0.1, 0)
	game.player.teleport_to(Transform3D(Basis.IDENTITY, target))
	for _i in 90:
		await physics_frame
		await process_frame
		if _i >= 6 and game.player.is_on_floor():
			break


func _state(survey: RefCounted) -> int:
	return int(survey.snapshot().get("state", -1))


func _reward_count(game: GameFlow, survey: RefCounted) -> int:
	var authority: RefCounted = game.get("_game_flow_reward_authority")
	var record := authority.call(&"get_snapshot").get("record", {}) as Dictionary
	return int((record.get("reward_counts", {}) as Dictionary).get(String(survey.REWARD_ID), 0))


func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)


func _finish(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	print("%s: %d assertions" % [
		SUCCESS_MARKER if _failures.is_empty() else FAILURE_MARKER, _assertions,
	])
	quit(0 if _failures.is_empty() else 1)
