class_name EmberCalderaExpeditionActivity
extends RefCounted

## The two authored caldera expedition errands that stand beside the Ember
## relay survey: sounding the collapsed lava tube west of the pad, and logging
## the wrecked survey lander to the south-east.
##
## This is a facade over the retained planetary activity/reward plumbing. Each
## errand is an ordinary `checkpoint_route` `ActivityDefinition` run by the
## existing `ActivityDirector` through its own
## `PlanetarySurfaceActivityRewardAdapter`/`PlanetaryActivityRewardRuntime`
## pair, and its reward resolves through the one existing
## `GameFlowRewardAuthority` store. The facade creates no activity state,
## reward store, clock, inventory, save or network authority of its own; it
## only names the authored content and remembers which errand is in hand.

const ActivityDefinitionScript := preload("res://scripts/activities/activity_definition.gd")
const LocationDefinitionScript := preload("res://scripts/world/definitions/world_location_definition.gd")

const SCHEMA_VERSION := 1
const WORLD_ID: StringName = &"ember_moon"
const REGION_ID: StringName = &"ember_caldera"
const BODY_RADIUS_M := 120_000.0
const CHECKPOINT_RADIUS_M := 8.0

const LAVA_TUBE_ACTIVITY_ID: StringName = &"ember_lava_tube_sounding"
const LAVA_TUBE_REWARD_ID: StringName = &"ember_lava_tube_sounding_data"
const LAVA_TUBE_LANDMARK_ID: StringName = &"ember_collapsed_lava_tube"
const LAVA_TUBE_ROUTE_ID: StringName = &"ember_caldera_lava_tube_route"

const LANDER_WRECK_ACTIVITY_ID: StringName = &"ember_lander_wreck_survey"
const LANDER_WRECK_REWARD_ID: StringName = &"ember_lander_wreck_salvage_log"
const LANDER_WRECK_LANDMARK_ID: StringName = &"ember_wrecked_survey_lander"
const LANDER_WRECK_ROUTE_ID: StringName = &"ember_caldera_lander_wreck_route"

const ACTIVITY_IDS := [LAVA_TUBE_ACTIVITY_ID, LANDER_WRECK_ACTIVITY_ID]

## Region-local checkpoints. Each errand takes the pilot through one authored
## route turn and then onto the landmark's own approach marker, so the walk is
## the objective: there is no way to satisfy either one from the pad.
const LAVA_TUBE_CHECKPOINTS_REGION_LOCAL_M := [
	Vector3(-32.0, 0.0, -38.0),
	Vector3(-74.0, 0.0, 16.0),
]
const LANDER_WRECK_CHECKPOINTS_REGION_LOCAL_M := [
	Vector3(56.0, 0.0, 18.0),
	Vector3(52.0, 0.0, 46.0),
]

## Where the errand is offered. Each trailhead stands a few metres off the
## existing pad-to-staging walk, at the head of that errand's own authored
## route, so a pilot who leaves the craft and walks east meets both of them
## before anything else. They are sites, not geometry: the interaction binding
## owns whatever marks them.
const LAVA_TUBE_TRAILHEAD_REGION_LOCAL_M := Vector3(18.0, 0.0, -3.0)
const LANDER_WRECK_TRAILHEAD_REGION_LOCAL_M := Vector3(40.0, 0.0, -4.0)

const ACTIVITY_SPECS := {
	LAVA_TUBE_ACTIVITY_ID: {
		"display_name": "Lava Tube Sounding",
		"location_id": &"ember_lava_tube_sounding_location",
		"location_name": "Collapsed Lava Tube",
		"landmark_id": LAVA_TUBE_LANDMARK_ID,
		"route_id": LAVA_TUBE_ROUTE_ID,
		"reward_id": LAVA_TUBE_REWARD_ID,
		"objective_id": &"sound_collapsed_lava_tube",
		"checkpoints": LAVA_TUBE_CHECKPOINTS_REGION_LOCAL_M,
		"trailhead": LAVA_TUBE_TRAILHEAD_REGION_LOCAL_M,
		"content_note": "Sound the collapsed Ember lava-tube mouth from the caldera floor.",
	},
	LANDER_WRECK_ACTIVITY_ID: {
		"display_name": "Lander Wreck Survey",
		"location_id": &"ember_lander_wreck_survey_location",
		"location_name": "Wrecked Survey Lander",
		"landmark_id": LANDER_WRECK_LANDMARK_ID,
		"route_id": LANDER_WRECK_ROUTE_ID,
		"reward_id": LANDER_WRECK_REWARD_ID,
		"objective_id": &"survey_wrecked_lander",
		"checkpoints": LANDER_WRECK_CHECKPOINTS_REGION_LOCAL_M,
		"trailhead": LANDER_WRECK_TRAILHEAD_REGION_LOCAL_M,
		"content_note": "Log the wrecked Ember survey lander east of the staging gate.",
	},
}

var _active_activity_id: StringName = &""
var _completed: Dictionary = {}
## Last authoritative route position reported by the adapter for each errand,
## kept only so a reader can say "checkpoint 1 of 2" without asking the route
## owner to expose a second progress seam. It is copied from the results the
## activity plumbing already returns and is never a source of truth.
var _route_progress: Dictionary = {}


static func is_expedition_activity(activity_id: StringName) -> bool:
	return ACTIVITY_SPECS.has(activity_id)


## Region-local content coordinates are published as body-local points because
## the authored landing region sits on the +Y radius of the body scene root.
static func to_body_local(region_local: Vector3) -> Vector3:
	return region_local + Vector3(0.0, BODY_RADIUS_M, 0.0)


static func get_trailhead_region_local(activity_id: StringName) -> Vector3:
	if not ACTIVITY_SPECS.has(activity_id):
		return Vector3.INF
	return (ACTIVITY_SPECS[activity_id] as Dictionary).trailhead as Vector3


static func get_trailhead_body_local(activity_id: StringName) -> Vector3:
	if not ACTIVITY_SPECS.has(activity_id):
		return Vector3.INF
	return to_body_local(
		(ACTIVITY_SPECS[activity_id] as Dictionary).trailhead as Vector3
	)


static func get_display_name(activity_id: StringName) -> String:
	if not ACTIVITY_SPECS.has(activity_id):
		return ""
	return str((ACTIVITY_SPECS[activity_id] as Dictionary).display_name)


static func get_checkpoints_body_local(activity_id: StringName) -> PackedVector3Array:
	var points := PackedVector3Array()
	if not ACTIVITY_SPECS.has(activity_id):
		return points
	for point: Vector3 in (ACTIVITY_SPECS[activity_id] as Dictionary).checkpoints as Array:
		points.append(to_body_local(point))
	return points


## Builds the two authored `checkpoint_route` definitions for the existing
## `ActivityDirector`. It registers nothing by itself.
static func build_definitions() -> Array[ActivityDefinition]:
	var definitions: Array[ActivityDefinition] = []
	for activity_id: StringName in ACTIVITY_IDS:
		var spec := ACTIVITY_SPECS[activity_id] as Dictionary
		var location := LocationDefinitionScript.new()
		location.location_id = spec.location_id
		location.display_name = spec.location_name
		location.sector_id = &"ember_moon_surface"
		location.anchor_source_id = spec.landmark_id
		location.anchor_position = to_body_local(
			(spec.checkpoints as Array)[(spec.checkpoints as Array).size() - 1] as Vector3
		)
		location.content_note = "Authored Ember caldera expedition anchor."
		var definition := ActivityDefinitionScript.new()
		definition.activity_id = activity_id
		definition.display_name = spec.display_name
		definition.content_note = spec.content_note
		definition.location = location
		definition.checkpoint_positions = get_checkpoints_body_local(activity_id)
		definition.checkpoint_radius = CHECKPOINT_RADIUS_M
		definitions.append(definition)
	return definitions


## Starts one errand on its own adapter. Only one errand is carried at a time,
## so an abandoned or finished one must be closed before the next is taken.
func begin(activity_id: StringName, adapter: Object) -> Dictionary:
	if not ACTIVITY_SPECS.has(activity_id):
		return {"accepted": false, "reason": &"unknown_caldera_expedition"}
	if bool(_completed.get(activity_id, false)):
		return {"accepted": false, "reason": &"caldera_expedition_already_completed"}
	if adapter == null or not adapter.has_method(&"begin_activity"):
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	if _active_activity_id != &"" and _active_activity_id != activity_id:
		return {"accepted": false, "reason": &"caldera_expedition_already_active"}
	var state := StringName(_adapter_state(adapter))
	var started: Dictionary = {}
	if state == &"failed" and adapter.has_method(&"retry_activity"):
		started = adapter.call(&"retry_activity", activity_id)
	else:
		started = adapter.call(&"begin_activity", activity_id)
	if bool(started.get("accepted", false)):
		_active_activity_id = activity_id
		_capture_route_progress(activity_id, started)
	return started


func submit_position(activity_id: StringName, adapter: Object, position: Vector3) -> Dictionary:
	if not ACTIVITY_SPECS.has(activity_id) or adapter == null \
			or not adapter.has_method(&"submit_activity_position_for_production"):
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	if not position.is_finite():
		return {"accepted": false, "reason": &"invalid_caldera_expedition_position"}
	var submitted: Dictionary = adapter.call(
		&"submit_activity_position_for_production", position
	)
	_capture_route_progress(activity_id, submitted)
	return submitted


func commit_reward(activity_id: StringName, adapter: Object) -> Dictionary:
	if not ACTIVITY_SPECS.has(activity_id) or adapter == null \
			or not adapter.has_method(&"commit_activity_reward"):
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	if bool(_completed.get(activity_id, false)):
		return {"accepted": false, "reason": &"caldera_expedition_already_completed"}
	var committed: Dictionary = adapter.call(&"commit_activity_reward")
	if bool(committed.get("accepted", false)):
		_completed[activity_id] = true
		_route_progress.erase(activity_id)
		if _active_activity_id == activity_id:
			_active_activity_id = &""
	return committed


## Gives up the errand in hand. The pilot keeps their craft, their route and
## their way home; only the unfinished objective is dropped.
func abandon(activity_id: StringName, adapter: Object, reason: StringName = &"player_abandoned") -> Dictionary:
	if not ACTIVITY_SPECS.has(activity_id) or adapter == null \
			or not adapter.has_method(&"abort_activity"):
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	var aborted: Dictionary = adapter.call(&"abort_activity", reason)
	if bool(aborted.get("accepted", false)):
		_route_progress.erase(activity_id)
		if _active_activity_id == activity_id:
			_active_activity_id = &""
	return aborted


func get_active_activity_id() -> StringName:
	return _active_activity_id


## What an offer point at this errand's trailhead may say. The four states are
## exhaustive and derive only from facade state, so a reader can never present
## a start that the errand seam would refuse.
func get_offer_state(activity_id: StringName) -> StringName:
	if not ACTIVITY_SPECS.has(activity_id):
		return &"unknown"
	if bool(_completed.get(activity_id, false)):
		return &"completed"
	if _active_activity_id == activity_id:
		return &"active"
	if _active_activity_id != &"":
		return &"busy"
	return &"available"


func is_completed(activity_id: StringName) -> bool:
	return bool(_completed.get(activity_id, false))


func get_snapshot(adapters: Dictionary = {}) -> Dictionary:
	var records := {}
	for activity_id: StringName in ACTIVITY_IDS:
		var spec := ACTIVITY_SPECS[activity_id] as Dictionary
		var adapter: Variant = adapters.get(activity_id)
		var checkpoints := get_checkpoints_body_local(activity_id)
		var progress := _route_progress.get(activity_id, {}) as Dictionary
		var reached := clampi(
			int(progress.get("next_checkpoint_index", 0)), 0, checkpoints.size()
		)
		records[activity_id] = {
			"activity_id": activity_id,
			"display_name": spec.display_name,
			"landmark_id": spec.landmark_id,
			"route_id": spec.route_id,
			"reward_id": spec.reward_id,
			"objective_id": spec.objective_id,
			"checkpoints_body_local_m": checkpoints,
			"trailhead_body_local_m": get_trailhead_body_local(activity_id),
			"offer_state": get_offer_state(activity_id),
			"checkpoints_reached": reached,
			"checkpoint_count": checkpoints.size(),
			"next_checkpoint_body_local_m": (
				checkpoints[reached] if reached < checkpoints.size() else Vector3.INF
			),
			"state": _adapter_state(adapter),
			"reward_committed": bool(_completed.get(activity_id, false)),
			"activity_reward": (
				adapter.call(&"get_activity_reward_snapshot")
				if adapter != null and (adapter as Object).has_method(
					&"get_activity_reward_snapshot"
				)
				else {}
			),
		}
	return {
		"schema_version": SCHEMA_VERSION,
		"world_id": WORLD_ID,
		"region_id": REGION_ID,
		"active_activity_id": _active_activity_id,
		"activities": records,
		"authority": {
			"activity": false,
			"reward": false,
			"reward_store": false,
			"movement": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func get_persistence_snapshot() -> Dictionary:
	var completed := PackedStringArray()
	for activity_id: StringName in ACTIVITY_IDS:
		if bool(_completed.get(activity_id, false)):
			completed.append(String(activity_id))
	return {
		"schema_version": SCHEMA_VERSION,
		"world_id": WORLD_ID,
		"active_activity_id": String(_active_activity_id),
		"completed_activity_ids": completed,
	}.duplicate(true)


func validate_persistence_snapshot(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false, "reason": &"invalid_caldera_expedition_record"}
	var record := candidate as Dictionary
	if int(record.get("schema_version", -1)) != SCHEMA_VERSION \
			or StringName(record.get("world_id", &"")) != WORLD_ID \
			or not record.get("completed_activity_ids") is PackedStringArray:
		return {"accepted": false, "reason": &"invalid_caldera_expedition_record"}
	var active := StringName(record.get("active_activity_id", &""))
	if active != &"" and not ACTIVITY_SPECS.has(active):
		return {"accepted": false, "reason": &"invalid_caldera_expedition_record"}
	for value in record.get("completed_activity_ids") as PackedStringArray:
		if not ACTIVITY_SPECS.has(StringName(value)):
			return {"accepted": false, "reason": &"invalid_caldera_expedition_record"}
	return {"accepted": true, "reason": &"caldera_expedition_record_valid"}


## Restores only which errands are already paid for. A restored record can
## never recreate a pending reward, so re-entry cannot pay twice.
func restore_persistence_snapshot(candidate: Variant) -> Dictionary:
	var validation := validate_persistence_snapshot(candidate)
	if not bool(validation.get("accepted", false)):
		return validation
	var record := candidate as Dictionary
	_completed.clear()
	_route_progress.clear()
	for value in record.get("completed_activity_ids") as PackedStringArray:
		_completed[StringName(value)] = true
	var active := StringName(record.get("active_activity_id", &""))
	_active_activity_id = &"" if bool(_completed.get(active, false)) else active
	return {"accepted": true, "reason": &"caldera_expedition_record_restored"}


## Copies the route counters the checkpoint activity already publishes on every
## start/position result. An unrecognised or rejected result leaves the last
## known counters alone rather than inventing progress.
func _capture_route_progress(activity_id: StringName, result: Variant) -> void:
	if not result is Dictionary or not bool((result as Dictionary).get("accepted", false)):
		return
	var record := result as Dictionary
	if not record.get("next_checkpoint_index") is int \
			or not record.get("checkpoint_count") is int:
		return
	var count := int(record.checkpoint_count)
	if count <= 0:
		return
	_route_progress[activity_id] = {
		"next_checkpoint_index": clampi(int(record.next_checkpoint_index), 0, count),
		"checkpoint_count": count,
	}


func _adapter_state(adapter: Variant) -> StringName:
	if adapter == null or not adapter is Object \
			or not (adapter as Object).has_method(&"get_state_id"):
		return &"unavailable"
	return StringName((adapter as Object).call(&"get_state_id"))
