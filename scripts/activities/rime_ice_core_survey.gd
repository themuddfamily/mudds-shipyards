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
const FAILURE_PARTICIPANT_RETIRED: StringName = &"survey_participant_retired"
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
var _participant_ref: WeakRef = weakref(null)
var _participant_context: Dictionary = {}


var _pending_shared_restoration := false


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
	var route_progress := (candidate as Dictionary).duplicate(true)
	# Older visits contain only route progress; new visits also retain heat.
	# Keep the activity authority's six-field contract unchanged.
	if route_progress.has("heat_s"):
		var heat: Variant = route_progress.get("heat_s")
		if not (heat is float or heat is int) or not is_finite(float(heat)) \
				or float(heat) < 0.0 or float(heat) > HEAT_CAPACITY_S:
			return false
		route_progress.erase("heat_s")
	var validator := CheckpointRouteActivity.new(
		definition_for(PackedVector3Array([Vector3.ZERO, Vector3.ONE]))
	)
	return bool(validator.validate_persistence_state(route_progress).get("accepted", false))


## A newly recovered visit has progress, not a previous crew capability.
## Cold resumes only when a current peer actually records its next observation.
func prepare_shared_restoration() -> void:
	var visit: RefCounted = _visit_ref.get_ref()
	_pending_shared_restoration = visit != null and _shared_visit() \
		and visit.restored_surface_host_is_current() and _running() and not reward_recorded() \
		and _participant_context.is_empty()


func attach(surface: Node3D) -> void:
	_pending_shared_restoration = false
	_clear_participant()
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
		var route_progress := _pending_restore.duplicate(true)
		route_progress.erase("heat_s")
		var restored := _flow.activity_director.restore_activity_persistence_state(ACTIVITY_ID, route_progress)
		if bool(restored.get("accepted", false)) and _running():
			_heat_s = float(_pending_restore.get("heat_s", HEAT_CAPACITY_S))
		_pending_restore.clear()
	else:
		_clear_previous_visit_run()


## Drops every reference to a surface that is going away. Progress already in
## the director and the store is untouched.
func detach() -> void:
	_retire_participant()
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
		"heat_s": _heat_s,
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
	var shared := _shared_visit()
	var running := _running()
	if shared and running and _pending_shared_restoration:
		return
	var can_tick := _participant_is_current() if shared else _on_foot()
	if shared and running and not can_tick:
		_retire_participant()
		return
	if delta <= 0.0 or not running or not can_tick:
		if not running:
			_heat_s = HEAT_CAPACITY_S
			_heat_warning_shown = false
			_clear_participant()
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
	var actor := _participant_ref.get_ref() as PlayerController if _shared_visit() else _flow.player
	if not is_instance_valid(actor):
		return false
	var position := actor.global_position
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


func _near(index: int, body: PlayerController = null) -> bool:
	var actor := body if body != null else _flow.player
	return actor.global_position.distance_to(_anchors[index].global_position) <= RADIUS


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


func interact(body: PlayerController = null) -> bool:
	var actor := body if body != null else _flow.player
	if not _actor_can_observe(actor) or reward_recorded():
		return false
	var route := snapshot()
	var state := int(route.get("state", CheckpointRouteActivity.State.IDLE))
	if _near(0, actor) and state != CheckpointRouteActivity.State.COMPLETED:
		if state == CheckpointRouteActivity.State.ACTIVE:
			return abandon(actor)
		var started := _flow.activity_director.start_activity(ACTIVITY_ID)
		if bool(started.get("accepted", false)):
			_pending_shared_restoration = false
			if _shared_visit():
				_participant_ref = weakref(actor)
				_participant_context = _flow._network_rime_survey_participant_context(actor)
			_heat_s = HEAT_CAPACITY_S
			_heat_warning_shown = false
			_flow.hud.toast("Ice-core survey started",
				"Follow the orange beacons to the drill rig. Your suit heater drains away from warmth.", 5.0)
			_save()
		return bool(started.get("accepted", false))
	var index := target_index()
	if index == 0 or not _near(index, actor):
		return false
	if state == CheckpointRouteActivity.State.ACTIVE:
		if _pending_shared_restoration:
			var context := _flow._network_rime_survey_participant_context(actor)
			if context.is_empty() or not _flow._network_rime_survey_participant_is_current(actor, context):
				return false
			_participant_ref = weakref(actor)
			_participant_context = context
			_pending_shared_restoration = false
		var result := _flow.activity_director.submit_position(ACTIVITY_ID,
			_region.to_local(actor.global_position), int(route.generation))
		if not bool(result.get("accepted", false)):
			return false
		route = snapshot()
		if int(route.state) == CheckpointRouteActivity.State.ACTIVE:
			_flow.hud.toast("Ice core extracted — 1/2",
				"Blue compression bands run through the core. Log the pressure ridge's strain gauge past the serac field.", 6.0)
			_save()
			return true
	if int(route.get("state", 0)) == CheckpointRouteActivity.State.COMPLETED and _actor_can_observe(actor):
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


func abandon(body: PlayerController = null) -> bool:
	var actor := body if body != null else _flow.player
	if not _actor_can_observe(actor):
		return false
	var route := snapshot()
	if not _flow.activity_director.fail_activity(
			ACTIVITY_ID, FAILURE_ABANDONED, int(route.get("generation", -1))):
		return false
	_heat_s = HEAT_CAPACITY_S
	_flow.hud.toast("Survey abandoned", "Explore freely or board your ship. The beacon can start a fresh survey.", 4.0)
	_save()
	return true


func _shared_visit() -> bool:
	var visit: RefCounted = _visit_ref.get_ref()
	return visit != null and visit.get("_shared_arrival") == true


func _actor_can_observe(body: PlayerController) -> bool:
	if not _shared_visit():
		return body == _flow.player and _on_foot()
	return _available() and _flow._shared_aurora_survey_store_is_current() \
		and _flow._network_rime_survey_body_is_current(body) \
		and not body.is_seated() and body.is_on_floor() \
		and (not _running() or _pending_shared_restoration \
			or (_participant_is_current() and _participant_ref.get_ref() == body))


## The running participant remains current through ordinary jumping. Floor
## contact is an interaction requirement, not an identity or cold-clock fence.
func _participant_is_current() -> bool:
	var actor := _participant_ref.get_ref() as PlayerController
	return not _participant_context.is_empty() and is_instance_valid(actor) \
		and _flow._network_rime_survey_participant_is_current(actor, _participant_context)


func _clear_participant() -> void:
	_pending_shared_restoration = false
	if _participant_context.is_empty() and _participant_ref.get_ref() == null:
		return
	_participant_ref = weakref(null)
	_participant_context.clear()


func _retire_participant() -> void:
	_pending_shared_restoration = false
	if not _participant_context.is_empty() and _running():
		var route := snapshot()
		_flow.activity_director.fail_activity(ACTIVITY_ID, FAILURE_PARTICIPANT_RETIRED,
			int(route.get("generation", -1)))
	_clear_participant()
	_heat_s = HEAT_CAPACITY_S
	_heat_warning_shown = false


func shared_state() -> Dictionary:
	return {"progress": capture(), "reward_recorded": reward_recorded(),
		"survey_available": _flow._shared_aurora_survey_store_is_current(),
		"participant_entity_id": String(_participant_context.get("entity_id", &"")),
		"heat": get_heat_snapshot()}


## Passive host progress against this peer's own streamed anchors. The picture
## grants no observation, position, heat or reward authority to a client.
func shared_presentation(surface: Node3D, body: PlayerController, shared: Dictionary,
		entity_id: StringName) -> Dictionary:
	if not is_instance_valid(surface) or not is_instance_valid(body) or shared.is_empty():
		return {}
	if not bool(shared.get("survey_available", false)):
		return {"objective": "Survey save recovery required — reboard whenever ready.",
			"prompt": "SURVEY SAVE RECOVERY REQUIRED"}
	var route := shared.get("progress", {}) as Dictionary
	if not valid_progress(route):
		return {}
	var paid := bool(shared.get("reward_recorded", false))
	var state := int(route.get("state", CheckpointRouteActivity.State.IDLE))
	var index := 0 if state in [CheckpointRouteActivity.State.IDLE, CheckpointRouteActivity.State.FAILED] \
		else mini(int(route.get("next_checkpoint_index", 0)) + 1, 2)
	var anchor := surface.find_child(ANCHORS[index], true, false) as Node3D
	var beacon := surface.find_child(ANCHORS[0], true, false) as Node3D
	if not is_instance_valid(anchor) or not is_instance_valid(beacon):
		return {}
	var objective_text := "Ice-core record logged — Rime survey saved. Reboard whenever ready." if paid \
		else "%s — %.0f m | Optional shared survey | %d/2 readings" % [LABELS[index],
			body.global_position.distance_to(anchor.global_position), int(route.get("next_checkpoint_index", 0))]
	var interaction := "FOLLOW THE ORANGE SURVEY BEACONS"
	if not paid:
		if state == CheckpointRouteActivity.State.ACTIVE:
			var heat := shared.get("heat", {}) as Dictionary
			objective_text += " | SUIT HEATER %d%%" % roundi(clampf(float(heat.get("fraction", 0.0)), 0.0, 1.0) * 100.0)
			if StringName(shared.get("participant_entity_id", &"")) != entity_id:
				return {"objective": objective_text, "prompt": "SURVEY IN PROGRESS — FOLLOW YOUR CREW OR REBOARD"}
		if body.global_position.distance_to(beacon.global_position) <= RADIUS and state != CheckpointRouteActivity.State.COMPLETED:
			interaction = "[ E ] ABANDON ICE-CORE SURVEY" if state == CheckpointRouteActivity.State.ACTIVE else "[ E ] START ICE-CORE SURVEY"
		elif body.global_position.distance_to(anchor.global_position) <= RADIUS and index > 0:
			interaction = "[ E ] RETRY SAVING RECORD" if state == CheckpointRouteActivity.State.COMPLETED \
				else ("[ E ] EXTRACT ICE CORE" if index == 1 else "[ E ] LOG RIDGE STRAIN")
		else:
			interaction = "WALK TO " + LABELS[index].to_upper()
		if state == CheckpointRouteActivity.State.COMPLETED:
			objective_text = "Readings complete — retry saving at the ridge gauge, or reboard whenever ready."
		elif state == CheckpointRouteActivity.State.FAILED:
			objective_text = "Survey ended — warm up, then restart at the orange beacon or reboard whenever ready."
	return {"objective": objective_text, "prompt": interaction}


func _save() -> void:
	var saved := _flow.save_interrupted_rime_visit()
	if not bool(saved.get("accepted", false)):
		_flow.hud.toast("Survey progress not saved",
			"Your readings remain available for this visit; saving can be retried on exit.", 5.0)
