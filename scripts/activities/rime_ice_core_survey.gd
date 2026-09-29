extends RefCounted
## Rime's optional on-foot ice-core survey, with a cold-exposure hazard.
##
## Start at the survey beacon, extract a core at the drill rig, then log the
## pressure ridge's strain gauge. ActivityDirector owns progression; the
## existing reward authority records the discovery exactly once, and the atomic
## visit store carries progress across a whole-`Main` re-entry.
##
## What makes it Rime's is the cold: while the survey is running, an explorer
## away from warmth drains a suit heater. Standing by the craft or in the drill
## rig's heated hut refills it. If it runs out the survey fails - a recoverable
## failure: nobody is hurt or moved, the craft, the berth lease and the way home
## are untouched, and the beacon starts a fresh survey once warmed up.
const ACTIVITY_ID: StringName = &"rime_ice_core_survey"
const REWARD_ID: StringName = &"rime_ice_core_record"
const FAILURE_HEAT_DEPLETED: StringName = &"suit_heat_depleted"
const FAILURE_ABANDONED: StringName = &"player_abandoned"
const RADIUS := 3.2
const ANCHORS := ["SurveyBeacon", "SurveyDrillRig", "SurveyStrainGauge"]
const LABELS := ["Survey beacon", "Drill rig", "Ridge strain gauge"]
const LOCATION := preload("res://assets/world/locations/rime_glacial.tres")
## Suit heater budget in seconds of exposure, and its refill rate by a heat
## source. The full loop is about 30 s of walking; the budget allows lingering.
const HEAT_CAPACITY_S := 120.0
const HEAT_REFILL_PER_S := 10.0
const HEAT_WARNING_FRACTION := 0.3
const CRAFT_WARMTH_RADIUS_M := 16.0

var _flow: GameFlow
var _visit_ref: WeakRef
var _surface_ref: WeakRef
var _region: Node3D
var _anchors: Array[Node3D] = []
var _adapter := NearbyActivityRewardAdapter.new()
var _pending_restore: Dictionary = {}
var _heat_s := HEAT_CAPACITY_S
var _heat_warning_shown := false
var _heat_failures := 0


func _init(flow: GameFlow, visit: RefCounted) -> void:
	_flow = flow
	_visit_ref = weakref(visit)
	_surface_ref = weakref(null)
	_adapter.configure(Callable(flow, &"_commit_game_flow_activity_reward"), ACTIVITY_ID, REWARD_ID)


static func definition_for(points: PackedVector3Array) -> ActivityDefinition:
	var definition := ActivityDefinition.new()
	definition.activity_id = ACTIVITY_ID
	definition.display_name = "Rime ice-core survey"
	definition.content_note = "Extract an ice core at the drill rig, then log the pressure ridge's strain gauge before the suit heater runs out."
	definition.location = LOCATION
	definition.checkpoint_positions = points
	definition.checkpoint_radius = RADIUS
	return definition


static func valid_progress(candidate: Variant) -> bool:
	if not candidate is Dictionary:
		return false
	if (candidate as Dictionary).is_empty():
		return true
	var validator := CheckpointRouteActivity.new(
		definition_for(PackedVector3Array([Vector3.ZERO, Vector3.ONE]))
	)
	return bool(validator.validate_persistence_state(candidate).get("accepted", false))


func attach(surface: Node3D) -> void:
	_surface_ref = weakref(surface)
	_region = surface.get_node_or_null(^"LandingRegion") as Node3D
	_anchors.clear()
	for anchor_name in ANCHORS:
		_anchors.append(surface.find_child(anchor_name, true, false) as Node3D)
	_heat_s = HEAT_CAPACITY_S
	_heat_warning_shown = false
	if not _available():
		return
	if _flow.activity_director.get_definition(ACTIVITY_ID) == null:
		_flow.activity_director.register_definition(definition_for(PackedVector3Array([
			_region.to_local(_anchors[1].global_position),
			_region.to_local(_anchors[2].global_position),
		])))
	if not _pending_restore.is_empty():
		_flow.activity_director.restore_activity_persistence_state(ACTIVITY_ID, _pending_restore)
		_pending_restore.clear()
	else:
		_clear_previous_visit_run()


## Drops every reference to a surface that is going away. Progress already in
## the director and the store is untouched.
func detach() -> void:
	_surface_ref = weakref(null)
	_region = null
	_anchors.clear()
	_heat_s = HEAT_CAPACITY_S
	_heat_warning_shown = false


## The director outlives a visit, but survey progress belongs to the visit that
## made it: its save is retired when the visit ends. A fresh arrival must not
## inherit a run (or a failure) left over from an earlier visit this session.
## A completed run whose reward is still unsaved is kept so it can be retried.
func _clear_previous_visit_run() -> void:
	var route := snapshot()
	if int(route.get("state", CheckpointRouteActivity.State.IDLE)) in [
			CheckpointRouteActivity.State.ACTIVE, CheckpointRouteActivity.State.FAILED]:
		_flow.activity_director.reset_activity(ACTIVITY_ID, int(route.get("generation", -1)))


func restore(progress: Dictionary) -> void:
	if valid_progress(progress):
		_pending_restore = progress.duplicate(true)


func capture() -> Dictionary:
	var route := snapshot()
	if route.is_empty():
		return _pending_restore.duplicate(true)
	return {
		"schema_version": 1, "activity_id": String(ACTIVITY_ID),
		"state": int(route.state), "generation": int(route.generation),
		"next_checkpoint_index": int(route.next_checkpoint_index),
		"failure_reason": String(route.failure_reason),
	}


func snapshot() -> Dictionary:
	return _flow.activity_director.get_activity_snapshot(ACTIVITY_ID)


func reward_recorded() -> bool:
	var authority: RefCounted = _flow.get("_game_flow_reward_authority")
	if authority == null:
		return false
	var record := authority.call(&"get_snapshot").get("record", {}) as Dictionary
	return int((record.get("reward_counts", {}) as Dictionary).get(String(REWARD_ID), 0)) > 0


func heat_fraction() -> float:
	return clampf(_heat_s / HEAT_CAPACITY_S, 0.0, 1.0)


func get_heat_snapshot() -> Dictionary:
	return {
		"heat_s": _heat_s,
		"capacity_s": HEAT_CAPACITY_S,
		"fraction": heat_fraction(),
		"warm": _is_warm(),
		"failures": _heat_failures,
	}


## One physics tick of the cold. It only runs while the survey is active and
## the explorer is on foot; it never moves or damages anyone.
func physics_tick(delta: float) -> void:
	if delta <= 0.0 or not _running() or not _on_foot():
		if not _running():
			_heat_s = HEAT_CAPACITY_S
			_heat_warning_shown = false
		return
	if _is_warm():
		_heat_s = minf(HEAT_CAPACITY_S, _heat_s + HEAT_REFILL_PER_S * delta)
		if heat_fraction() > HEAT_WARNING_FRACTION:
			_heat_warning_shown = false
		return
	_heat_s = maxf(0.0, _heat_s - delta)
	if not _heat_warning_shown and heat_fraction() <= HEAT_WARNING_FRACTION:
		_heat_warning_shown = true
		_flow.hud.toast("Suit heater low", "Warm up at the drill rig's heated hut or beside your ship.", 4.0)
	if _heat_s <= 0.0:
		_fail_from_cold()


func _fail_from_cold() -> void:
	var route := snapshot()
	if not _flow.activity_director.fail_activity(
			ACTIVITY_ID, FAILURE_HEAT_DEPLETED, int(route.get("generation", -1))):
		return
	_heat_failures += 1
	_heat_s = HEAT_CAPACITY_S
	_heat_warning_shown = false
	_flow.hud.toast("Suit heater exhausted — survey lost",
		"You are safe. Warm up, then start a fresh survey at the orange beacon.", 5.0)
	_save()


func _running() -> bool:
	return int(snapshot().get("state", CheckpointRouteActivity.State.IDLE)) \
		== CheckpointRouteActivity.State.ACTIVE


func _is_warm() -> bool:
	if not is_instance_valid(_flow.player):
		return false
	var position := _flow.player.global_position
	var surface := _surface_ref.get_ref() as RimeGlacialAuthoredScene
	if is_instance_valid(surface) and surface.is_inside_tree():
		var shelter := surface.get_heat_shelter_global_position()
		if shelter.is_finite() and position.distance_to(shelter) \
				<= RimeGlacialAuthoredScene.HEAT_SHELTER_RADIUS_M:
			return true
	var visit: RefCounted = _visit_ref.get_ref()
	var craft := visit.call(&"get_craft") as HeroShip if visit != null else null
	return is_instance_valid(craft) and craft.is_inside_tree() \
		and position.distance_to(craft.global_position) <= CRAFT_WARMTH_RADIUS_M


func _available() -> bool:
	return is_instance_valid(_region) and _region.is_inside_tree() \
		and _anchors.size() == 3 \
		and _anchors.all(func(anchor: Node3D) -> bool: return is_instance_valid(anchor))


func _on_foot() -> bool:
	return _available() and _visit_ref.get_ref() != null \
		and _visit_ref.get_ref().state == &"surface" and not _flow._transition_busy \
		and not _flow._piloting and not _flow.player.is_seated() and not _flow._station_seated \
		and _flow.player.is_control_enabled() and _flow.player.is_on_floor()


func _near(index: int) -> bool:
	return _flow.player.global_position.distance_to(_anchors[index].global_position) <= RADIUS


func target_index() -> int:
	var route := snapshot()
	if route.is_empty() or int(route.get("state", 0)) in [
			CheckpointRouteActivity.State.IDLE, CheckpointRouteActivity.State.FAILED]:
		return 0
	return mini(int(route.get("next_checkpoint_index", 0)) + 1, 2)


func objective() -> String:
	if reward_recorded():
		return "Ice-core record logged — Rime survey saved. Board your ship whenever ready."
	if not _available():
		return "Explore Rime's icefall shelf"
	var index := target_index()
	var distance := _flow.player.global_position.distance_to(_anchors[index].global_position)
	var route := snapshot()
	var state := int(route.get("state", 0))
	if state == CheckpointRouteActivity.State.COMPLETED:
		return "Survey readings complete — return to the ridge gauge to retry saving the record"
	if state == CheckpointRouteActivity.State.FAILED \
			and StringName(route.get("failure_reason", &"")) == FAILURE_HEAT_DEPLETED:
		return "Suit heater ran out — warm up, then restart at the orange survey beacon (%.0f m)" % distance
	if state == CheckpointRouteActivity.State.ACTIVE:
		return "%s — %.0f m  |  %d/2 readings  |  SUIT HEATER %d%%  |  Beacon: abandon" % [
			LABELS[index], distance, int(route.get("next_checkpoint_index", 0)),
			roundi(heat_fraction() * 100.0)]
	return "%s — %.0f m  |  Optional ice-core survey" % [LABELS[index], distance]


func prompt() -> String:
	if not _on_foot() or reward_recorded():
		return "FOLLOW THE ORANGE SURVEY BEACONS"
	var route := snapshot()
	var state := int(route.get("state", 0))
	if _near(0) and state != CheckpointRouteActivity.State.COMPLETED:
		return "[ E ]  ABANDON ICE-CORE SURVEY" if state == CheckpointRouteActivity.State.ACTIVE \
			else "[ E ]  START ICE-CORE SURVEY"
	if target_index() > 0 and _near(target_index()):
		return "[ E ]  EXTRACT ICE CORE" if target_index() == 1 else "[ E ]  LOG RIDGE STRAIN"
	return "WALK TO " + LABELS[target_index()].to_upper()


func interact() -> bool:
	if not _on_foot() or reward_recorded():
		return false
	var route := snapshot()
	var state := int(route.get("state", CheckpointRouteActivity.State.IDLE))
	if _near(0) and state != CheckpointRouteActivity.State.COMPLETED:
		if state == CheckpointRouteActivity.State.ACTIVE:
			return abandon()
		var started := _flow.activity_director.start_activity(ACTIVITY_ID)
		if bool(started.get("accepted", false)):
			_heat_s = HEAT_CAPACITY_S
			_heat_warning_shown = false
			_flow.hud.toast("Ice-core survey started",
				"Follow the orange beacons to the drill rig. Your suit heater drains away from warmth.", 5.0)
			_save()
		return bool(started.get("accepted", false))
	var index := target_index()
	if index == 0 or not _near(index):
		return false
	if state == CheckpointRouteActivity.State.ACTIVE:
		var result := _flow.activity_director.submit_position(ACTIVITY_ID,
			_region.to_local(_flow.player.global_position), int(route.generation))
		if not bool(result.get("accepted", false)):
			return false
		route = snapshot()
		if int(route.state) == CheckpointRouteActivity.State.ACTIVE:
			_flow.hud.toast("Ice core extracted — 1/2",
				"Blue compression bands run through the core. Log the pressure ridge's strain gauge past the serac field.", 6.0)
			_save()
			return true
	if int(route.get("state", 0)) == CheckpointRouteActivity.State.COMPLETED:
		var handoff := route.duplicate(true)
		handoff["state_id"] = &"completed"
		handoff["outcome"] = &"cleared"
		var reward := _adapter.consume(handoff, int(route.generation))
		if bool(reward.get("accepted", false)) or reward_recorded():
			_flow.hud.toast("Ice-core survey complete — 2/2",
				"The ridge strain matches the core's compression bands. Rime ice-core record saved; board your ship whenever ready.", 7.0)
		else:
			_flow.hud.toast("Readings retained", "Record could not be saved. Interact at the ridge gauge to retry.", 5.0)
		_save()
		return true
	return false


func abandon() -> bool:
	if not _on_foot():
		return false
	var route := snapshot()
	if not _flow.activity_director.fail_activity(
			ACTIVITY_ID, FAILURE_ABANDONED, int(route.get("generation", -1))):
		return false
	_heat_s = HEAT_CAPACITY_S
	_flow.hud.toast("Survey abandoned", "Explore freely or board your ship. The beacon can start a fresh survey.", 4.0)
	_save()
	return true


func _save() -> void:
	var saved := _flow.save_interrupted_rime_visit()
	if not bool(saved.get("accepted", false)):
		_flow.hud.toast("Survey progress not saved",
			"Your readings remain available for this visit; saving can be retried on exit.", 5.0)
