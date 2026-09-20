class_name ActivityTutorialPresenter
extends RefCounted

## Snapshot-only first-time briefing for nearby-sector activities.
##
## One short prompt per activity kind, formatted the same way the first-sortie
## tutorial is: authored copy, caller-resolved glyphs, a textual next action and
## recovery line, and a controller-focusable action row. This object owns no
## activity, gameplay, input, timer or save authority. "Seen once" progress is
## caller-owned exactly as first-sortie step progress is; GameFlow decides
## whether a briefing is published at all.

const COMPONENT_ID: StringName = &"activity-tutorial-presenter"

## Frozen activity family. Kept aligned with NearbySectorActivityPresenter's
## production activity identifiers so every offered activity has one briefing.
const ACTIVITY_ORDER := [
	&"cinder_reach_emberline_convoy",
	&"cinder_reach_checkpoint_route",
	&"cinder_relay_patrol",
	&"cinder_platform_mining_run",
	&"cinder_derelict_structure_scan",
	&"cinder_debris_beacon_traversal",
	&"cinder_platform_supply_run",
	&"station_defense",
	&"cinder_hulk_power_restoration",
	&"cinder_asteroid_field_threading_run",
]

const ACTIVITY_COPY := {
	&"cinder_reach_emberline_convoy": {
		"title": "Escort the Emberline convoy",
		"label": "EMBERLINE CONVOY ESCORT",
		"controller": "Hold station on the convoy's wing, then press {fire} on anything that closes.",
		"keyboard": "Hold station on the convoy's wing, then press {fire} on anything that closes.",
		"accessible": "Hold station beside the convoy and use the fire control on any hostile that closes on it.",
		"next_action": "HOLD CONVOY STATION // ENGAGE CLOSING THREATS",
		"recovery": "CONVOY SEPARATED // THROTTLE BACK ONTO THE HAULERS",
	},
	&"cinder_reach_checkpoint_route": {
		"title": "Run the checkpoint route",
		"label": "TIMED CHECKPOINT ROUTE",
		"controller": "Hold {move_forward} and take every gate in order. {sprint_boost} buys back lost seconds.",
		"keyboard": "Hold {move_forward} and take every gate in order. {sprint_boost} buys back lost seconds.",
		"accessible": "Hold forward throttle and pass every checkpoint gate in order. Boost buys back lost seconds.",
		"next_action": "CLEAR THE NEXT GATE // IN ORDER",
		"recovery": "GATE MISSED // SWING BACK TO THE LAST MARKER",
	},
	&"cinder_relay_patrol": {
		"title": "Fly the relay patrol",
		"label": "RELAY PATROL",
		"controller": "Visit each relay in turn. Ease off with {brake} to hold the sweep over one.",
		"keyboard": "Visit each relay in turn. Ease off with {brake} to hold the sweep over one.",
		"accessible": "Visit each relay waypoint in turn, braking to hold the sweep over one.",
		"next_action": "NEXT RELAY // HOLD THE SWEEP",
		"recovery": "PATROL LAPSED // RETURN TO THE LAST RELAY",
	},
	&"cinder_platform_mining_run": {
		"title": "Work the mining platform",
		"label": "PLATFORM MINING RUN",
		"controller": "Settle onto the platform pad, then press {interact} to load ore.",
		"keyboard": "Settle onto the platform pad, then press {interact} to load ore.",
		"accessible": "Settle onto the mining platform pad, then use the interact control to load ore.",
		"next_action": "SETTLE ON THE PAD // INTERACT TO LOAD",
		"recovery": "PAD LOST // LINE UP ON THE PLATFORM AGAIN",
	},
	&"cinder_derelict_structure_scan": {
		"title": "Scan the derelict",
		"label": "DERELICT STRUCTURE SCAN",
		"controller": "Hold close on the derelict, then press {interact} at each marked scan point.",
		"keyboard": "Hold close on the derelict, then press {interact} at each marked scan point.",
		"accessible": "Hold position close to the derelict, then use the interact control at each marked scan point.",
		"next_action": "CLOSE ON THE MARK // INTERACT TO SCAN",
		"recovery": "SCAN BROKEN // CLOSE BACK IN ON THE MARK",
	},
	&"cinder_debris_beacon_traversal": {
		"title": "Run the beacon line",
		"label": "DEBRIS BEACON TRAVERSAL",
		"controller": "Thread the lit beacons in sequence. Use {brake} early; the debris does not move.",
		"keyboard": "Thread the lit beacons in sequence. Use {brake} early; the debris does not move.",
		"accessible": "Fly through the lit beacons in sequence, braking early because the debris does not move.",
		"next_action": "NEXT LIT BEACON // THREAD THE DEBRIS",
		"recovery": "LINE LOST // BACK TO THE LAST LIT BEACON",
	},
	&"cinder_platform_supply_run": {
		"title": "Fly the supply run",
		"label": "PLATFORM SUPPLY RUN",
		"controller": "Press {interact} to take on cargo, then deliver it before the clock runs out.",
		"keyboard": "Press {interact} to take on cargo, then deliver it before the clock runs out.",
		"accessible": "Use the interact control to take on cargo, then deliver it before the clock runs out.",
		"next_action": "LOAD CARGO // DELIVER BEFORE THE CLOCK",
		"recovery": "RUN STALLED // RETURN TO THE SUPPLY PLATFORM",
	},
	&"cinder_hulk_power_restoration": {
		"title": "Dock at the abandoned hulk",
		"label": "ABANDONED STATION HULK",
		"controller": "Dock on the hulk's lit face, leave the seat, then press {interact} on the breaker inside.",
		"keyboard": "Dock on the hulk's lit face, leave the seat, then press {interact} on the breaker inside.",
		"accessible": "Dock on the lit face of the hulk, leave the pilot seat, walk in and use the interact control on the breaker.",
		"next_action": "DOCK ON THE LIT FACE // WALK IN TO THE BREAKER",
		"recovery": "DRIFTED OFF // LINE BACK UP ON THE HULK DOCK",
	},
	&"cinder_asteroid_field_threading_run": {
		"title": "Thread the belt bore",
		"label": "ASTEROID BELT THREADING RUN",
		"controller": "The belt has one cut bore. Enter at the ringed mouth and hold {move_forward} through all five gates.",
		"keyboard": "The belt has one cut bore. Enter at the ringed mouth and hold {move_forward} through all five gates.",
		"accessible": "The belt has one cut bore. Enter at the ringed mouth and fly forward through all five marked gates in order.",
		"next_action": "ENTER AT THE RINGED MOUTH // FIVE GATES IN ORDER",
		"recovery": "BORE LOST // SWING BACK OUT TO THE RINGED MOUTH",
	},
	&"station_defense": {
		"title": "Hold the station perimeter",
		"label": "STATION DEFENCE",
		"controller": "Stay inside the perimeter ring and press {fire} on each wave as it breaks in.",
		"keyboard": "Stay inside the perimeter ring and press {fire} on each wave as it breaks in.",
		"accessible": "Stay inside the station perimeter ring and use the fire control on each incoming wave.",
		"next_action": "HOLD THE PERIMETER // ENGAGE THE WAVE",
		"recovery": "PERIMETER BREACHED // FALL BACK TO THE STATION RING",
	},
}

## Glyph tokens the authored copy above can contain. The HUD resolves these
## through InputGlyphResolver; this list only tells the caller what to resolve.
const GLYPH_ACTIONS: Array[StringName] = [
	&"interact", &"fire", &"move_forward", &"sprint_boost", &"brake",
]

var _snapshot: Dictionary = {}
var _source_generation := -1
var _source_revision := -1
var _source_activity: StringName = &""
var _attached := false


static func is_known_activity(activity_id: StringName) -> bool:
	return ACTIVITY_ORDER.has(activity_id)


func present_snapshot(source: Dictionary) -> Dictionary:
	if not bool(source.get("show_tutorials", true)):
		_clear_state()
		return _reject(&"tutorials_disabled")
	for lifecycle_key: StringName in [&"actor_attached", &"session_active"]:
		if source.has(lifecycle_key) and not source.get(lifecycle_key) is bool:
			return _reject(&"invalid_lifecycle")
	if source.has("actor_attached") and not bool(source.actor_attached):
		_clear_state()
		return _reject(&"actor_unavailable")
	if source.has("session_active") and not bool(source.session_active):
		_clear_state()
		return _reject(&"session_unavailable")
	var generation_value: Variant = source.get("generation", null)
	if not generation_value is int or int(generation_value) < 0:
		return _reject(&"invalid_generation")
	var generation := int(generation_value)
	var activity_id := StringName(str(source.get("activity_id", &"")))
	if not ACTIVITY_ORDER.has(activity_id):
		return _reject(&"unknown_activity")
	var activity_index := ACTIVITY_ORDER.find(activity_id)
	var revision_value: Variant = source.get("revision", 0)
	if not revision_value is int or int(revision_value) < 0:
		return _reject(&"invalid_revision")
	var revision := int(revision_value)
	if _attached and generation < _source_generation:
		return _reject(&"stale_generation")
	if _attached and generation == _source_generation and revision < _source_revision:
		return _reject(&"stale_revision")
	if _attached and generation == _source_generation \
			and revision == _source_revision and activity_id != _source_activity:
		return _reject(&"conflicting_revision")
	var copy := (ACTIVITY_COPY[activity_id] as Dictionary).duplicate(true)
	var family := StringName(str(source.get("input_family", &"controller")))
	var accessible := bool(source.get("accessible", false))
	var prompt := str(
		copy.accessible if accessible
		else (copy.keyboard if family == &"keyboard" else copy.controller)
	)
	var glyphs := source.get("glyphs", {}) as Dictionary
	for raw_key: Variant in glyphs:
		prompt = prompt.replace("{%s}" % str(raw_key), str(glyphs[raw_key]))
	var next_action := str(copy.next_action)
	var recovery := str(copy.recovery)
	var status_text := "\nACTIVITY // %s\nNEXT ACTION // %s\nRECOVERY // %s" % [
		str(copy.label), next_action, recovery,
	]
	prompt += status_text
	var accessible_prompt := str(copy.accessible) + status_text
	_source_generation = generation
	_source_revision = revision
	_source_activity = activity_id
	_attached = true
	_snapshot = {
		"component_id": COMPONENT_ID,
		"accepted": true,
		"attached": true,
		"activity_id": activity_id,
		"activity_index": activity_index,
		"generation": generation,
		"revision": revision,
		"title": copy.title,
		"prompt": prompt,
		"accessible_prompt": accessible_prompt,
		"activity_label": copy.label,
		"next_action": next_action,
		"recovery": recovery,
		"input_family": family,
		"actions": [
			{"id": &"next", "label": "Got it", "focusable": true},
			{"id": &"repeat", "label": "Repeat briefing", "focusable": true},
			{"id": &"dismiss", "label": "Dismiss briefing", "focusable": true},
		],
		"completion_intent": {
			"kind": &"activity_tutorial",
			"activity_id": activity_id,
			"generation": generation,
			"revision": revision,
			"persist": true,
		},
		"color_independent": true,
		"presentation_only": true,
		"tutorial_progress_authority": false,
		"activity_authority": false,
		"gameplay_authority": false,
		"input_authority": false,
		"timer_authority": false,
		"process_authority": false,
	}.duplicate(true)
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	var result := _snapshot.duplicate(true)
	if not result.is_empty():
		result["attached"] = _attached
	return result


## Caller-owned activity/session lifecycle invokes this when the retained
## briefing loses its source. Clearing the fence makes this object reusable.
func detach(reason: StringName = &"detached") -> Dictionary:
	_clear_state()
	return {
		"accepted": true,
		"attached": false,
		"reason": reason,
		"component_id": COMPONENT_ID,
		"presentation_only": true,
		"tutorial_progress_authority": false,
	}.duplicate(true)


func request(action: StringName) -> Dictionary:
	if not _attached or _snapshot.is_empty() or not [&"next", &"repeat", &"dismiss"].has(action):
		return {"accepted": false, "reason": &"action_unavailable", "presentation_only": true}
	return {
		"accepted": true,
		"action": action,
		"generation": _source_generation,
		"revision": _source_revision,
		"completion_intent": _snapshot.completion_intent.duplicate(true),
		"presentation_only": true,
		"tutorial_progress_authority": false,
		"activity_authority": false,
		"gameplay_authority": false,
		"input_authority": false,
		"timer_authority": false,
		"process_authority": false,
	}


func _clear_state() -> void:
	_snapshot.clear()
	_source_generation = -1
	_source_revision = -1
	_source_activity = &""
	_attached = false


func _reject(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"component_id": COMPONENT_ID,
		"presentation_only": true,
		"tutorial_progress_authority": false,
		"activity_authority": false,
		"gameplay_authority": false,
		"input_authority": false,
		"timer_authority": false,
		"process_authority": false,
	}
