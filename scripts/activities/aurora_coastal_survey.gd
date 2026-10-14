extends RefCounted
## Aurora's optional on-foot observations. ActivityDirector owns progression;
## the existing reward authority and atomic visit store own durable writes.
const ACTIVITY_ID: StringName = &"aurora_coastal_observation"
const REWARD_ID: StringName = &"aurora_coastal_survey_data"
const RADIUS := 3.2
const ANCHORS := ["SurveyTrailSign", "SurveyLookout", "SurveyStones"]
const LABELS := ["Trail sign", "Lookout instrument", "Standing stones"]
const LOCATION := preload("res://assets/world/locations/aurora_temperate.tres")

var _flow: GameFlow
var _visit_ref: WeakRef
var _region: Node3D
var _anchors: Array[Node3D] = []
var _adapter := NearbyActivityRewardAdapter.new()
var _pending_restore: Dictionary = {}
var _shared_checkpoint_examined := false

func _init(flow: GameFlow, visit: RefCounted) -> void:
	_flow = flow
	_visit_ref = weakref(visit)
	_adapter.configure(Callable(flow, &"_commit_game_flow_activity_reward"), ACTIVITY_ID, REWARD_ID)

static func definition_for(points: PackedVector3Array) -> ActivityDefinition:
	var definition := ActivityDefinition.new()
	definition.activity_id = ACTIVITY_ID
	definition.display_name = "Aurora coastal observation"
	definition.content_note = "Read the coastal waterline and compare weathering on the standing stones."
	definition.location = LOCATION
	definition.checkpoint_positions = points
	definition.checkpoint_radius = RADIUS
	return definition

static func valid_progress(candidate: Variant) -> bool:
	if not candidate is Dictionary:
		return false
	if (candidate as Dictionary).is_empty():
		return true
	var validator := CheckpointRouteActivity.new(definition_for(PackedVector3Array([Vector3.ZERO, Vector3.ONE])))
	return bool(validator.validate_persistence_state(candidate).get("accepted", false))

func attach(surface: Node3D) -> void:
	_shared_checkpoint_examined = false
	_region = surface.get_node_or_null(^"LandingRegion") as Node3D
	_anchors.clear()
	for anchor_name in ANCHORS:
		_anchors.append(surface.find_child(anchor_name, true, false) as Node3D)
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

func _available() -> bool:
	return is_instance_valid(_region) and _region.is_inside_tree() \
		and _anchors.size() == 3 and _anchors.all(func(anchor: Node3D) -> bool: return is_instance_valid(anchor))

func _on_foot() -> bool:
	return _available() and _visit_ref.get_ref() != null and _visit_ref.get_ref().state == &"surface" and not _flow._transition_busy \
		and not _flow._piloting and not _flow.player.is_seated() and not _flow._station_seated \
		and _flow.player.is_control_enabled() and _flow.player.is_on_floor()

func _near(index: int, body: PlayerController = null) -> bool:
	var actor := body if body != null else _flow.player
	return actor.global_position.distance_to(_anchors[index].global_position) <= RADIUS

func target_index() -> int:
	var route := snapshot()
	if route.is_empty() or int(route.get("state", 0)) in [CheckpointRouteActivity.State.IDLE, CheckpointRouteActivity.State.FAILED]:
		return 0
	return mini(int(route.get("next_checkpoint_index", 0)) + 1, 2)

func objective() -> String:
	if reward_recorded():
		return "Coastal survey recorded — Aurora data saved. Board your ship whenever ready."
	if not _available():
		return "Explore Aurora's coastal trail"
	var index := target_index()
	var distance := _flow.player.global_position.distance_to(_anchors[index].global_position)
	var route := snapshot()
	if int(route.get("state", 0)) == CheckpointRouteActivity.State.COMPLETED:
		return "Observations complete — return to the standing stones to retry saving the reward"
	# An abandoned run keeps its reached index, but its observations are lost.
	if int(route.get("state", 0)) != CheckpointRouteActivity.State.ACTIVE:
		return "%s — %.0f m  |  Optional coastal survey" % [LABELS[index], distance]
	return "%s — %.0f m  |  %d/2 observations  |  Trail sign: abandon survey" % [LABELS[index], distance,
		int(route.get("next_checkpoint_index", 0))]

func prompt() -> String:
	if not _on_foot() or reward_recorded():
		return "WALK THE COASTAL TRAIL"
	var route := snapshot()
	if _near(0) and int(route.get("state", 0)) != CheckpointRouteActivity.State.COMPLETED:
		return "[ E ]  ABANDON COASTAL SURVEY" if int(route.get("state", 0)) == CheckpointRouteActivity.State.ACTIVE else "[ E ]  START COASTAL SURVEY"
	if target_index() > 0 and _near(target_index()):
		return "[ E ]  READ COASTAL WATERLINE" if target_index() == 1 else "[ E ]  RECORD STONE WEATHERING"
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
			_flow.hud.toast("Coastal survey started", "Follow the amber trail. Read the waterline through the lookout instrument.", 5.0)
			_save()
		return bool(started.get("accepted", false))
	var index := target_index()
	if index == 0 or not _near(index, actor):
		return false
	if state == CheckpointRouteActivity.State.ACTIVE:
		var result := _flow.activity_director.submit_position(ACTIVITY_ID,
			_region.to_local(actor.global_position), int(route.generation))
		if not bool(result.get("accepted", false)):
			return false
		route = snapshot()
		if int(route.state) == CheckpointRouteActivity.State.ACTIVE:
			_flow.hud.toast("Waterline observed — 1/2", "Pale tidal bands mark the sheltered coast. Compare their height with weathering on the standing stones.", 6.0)
			_save()
			return true
	if int(route.get("state", 0)) == CheckpointRouteActivity.State.COMPLETED and _actor_can_observe(actor):
		var handoff := route.duplicate(true)
		handoff["state_id"] = &"completed"
		handoff["outcome"] = &"cleared"
		var reward := _adapter.consume(handoff, int(route.generation))
		if bool(reward.get("accepted", false)) or reward_recorded():
			_flow.hud.toast("Coastal survey complete — 2/2", "Salt-worn stone faces align with the tidal bands. Aurora coastal survey data saved; board your ship whenever ready.", 7.0)
		else:
			_flow.hud.toast("Observations retained", "Reward could not be saved. Interact at the standing stones to retry.", 5.0)
		_save()
		return true
	return false

func abandon(body: PlayerController = null) -> bool:
	var actor := body if body != null else _flow.player
	if not _actor_can_observe(actor):
		return false
	var route := snapshot()
	if not _flow.activity_director.fail_activity(ACTIVITY_ID, &"player_abandoned", int(route.get("generation", -1))):
		return false
	_flow.hud.toast("Survey abandoned", "Explore freely or board your ship. The trail sign can start a fresh survey.", 4.0)
	_save()
	return true

func _save() -> void:
	var saved := _flow.save_interrupted_aurora_visit()
	if not bool(saved.get("accepted", false)):
		_flow.hud.toast("Survey progress not saved", "Your observations remain available for this visit; saving can be retried on exit.", 5.0)


## A remote observer is the retained server body, admitted by the current
## surface lease. A client never submits a position or a completion receipt.
func _actor_can_observe(body: PlayerController) -> bool:
	if body == _flow.player:
		return _on_foot()
	return _available() and _flow._shared_aurora_survey_store_is_current() \
		and _flow._network_aurora_survey_body_is_current(body) \
		and not body.is_seated() and body.is_on_floor()


func shared_state() -> Dictionary:
	return {"progress": capture(), "reward_recorded": reward_recorded()}


## Read-only client presentation against this machine's streamed anchors.
## The host's progress picture grants no activity or reward authority.
func shared_presentation(surface: Node3D, body: PlayerController, shared: Dictionary) -> Dictionary:
	if not is_instance_valid(surface) or not is_instance_valid(body) or shared.is_empty():
		return {}
	var route := shared.get("progress", {}) as Dictionary
	if not valid_progress(route):
		return {}
	var paid := bool(shared.get("reward_recorded", false))
	var state := int(route.get("state", CheckpointRouteActivity.State.IDLE))
	var index := 0 if state in [CheckpointRouteActivity.State.IDLE, CheckpointRouteActivity.State.FAILED] else mini(int(route.get("next_checkpoint_index", 0)) + 1, 2)
	var anchor := surface.find_child(ANCHORS[index], true, false) as Node3D
	var sign := surface.find_child(ANCHORS[0], true, false) as Node3D
	if not is_instance_valid(anchor) or not is_instance_valid(sign):
		return {}
	var objective_text := "Coastal survey recorded — Aurora data saved. Reboard whenever ready." if paid else "%s — %.0f m | Optional shared survey | %d/2 observations" % [LABELS[index], body.global_position.distance_to(anchor.global_position), int(route.get("next_checkpoint_index", 0))]
	var interaction := "WALK THE COASTAL TRAIL"
	if not paid:
		if body.global_position.distance_to(sign.global_position) <= RADIUS and state != CheckpointRouteActivity.State.COMPLETED:
			interaction = "[ E ] ABANDON COASTAL SURVEY" if state == CheckpointRouteActivity.State.ACTIVE else "[ E ] START COASTAL SURVEY"
		elif body.global_position.distance_to(anchor.global_position) <= RADIUS and index > 0:
			interaction = "[ E ] RETRY SAVING SURVEY" if state == CheckpointRouteActivity.State.COMPLETED else ("[ E ] READ COASTAL WATERLINE" if index == 1 else "[ E ] RECORD STONE WEATHERING")
		else:
			interaction = "WALK TO " + LABELS[index].to_upper()
		if state == CheckpointRouteActivity.State.COMPLETED:
			objective_text = "Observations complete — retry saving at the standing stones, or reboard whenever ready"
	return {"objective": objective_text, "prompt": interaction}


func resume_shared_checkpoint() -> void:
	if _shared_checkpoint_examined or not _available() \
			or not _flow._network_aurora_passenger_host_is_current(_flow.active_ship):
		return
	_shared_checkpoint_examined = true
	var restored := _flow.restore_shared_aurora_survey_checkpoint()
	if bool(restored.get("accepted", false)):
		_flow.hud.toast("Coastal observations restored", "Your saved observations are available. Continue the coastal survey or reboard whenever ready.", 5.0)
