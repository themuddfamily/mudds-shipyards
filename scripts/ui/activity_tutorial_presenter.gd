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

## Activity family. The first ten stay aligned with NearbySectorActivityPresenter's
## production activity identifiers so every offered activity has one briefing;
## the rest are the shipyard deck-board sorties and the planetary surface
## activities, published from GameFlow's board-arm, errand-start and
## surface-arrival seams.
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
	&"shipyard_heavy_breach",
	&"shipyard_torpedo_run",
	&"aurora_coastal_observation",
	&"rime_ice_core_survey",
	&"ember_beacon_survey",
	&"ember_caldera_errands",
]

const ACTIVITY_COPY := {
	&"cinder_reach_emberline_convoy": {
		"title": "Escort the Emberline convoy",
		"label": "EMBERLINE CONVOY ESCORT",
		"controller": "Depart the berth in a healthy piloted craft and fly to the marked rendezvous. The activity row's Start begins the escort there; entering the marker can also begin it automatically. Stay beside the tender along its marked route and press {fire} on closing hostiles.",
		"keyboard": "Depart the berth in a healthy piloted craft and fly to the marked rendezvous. The activity row's Start begins the escort there; entering the marker can also begin it automatically. Stay beside the tender along its marked route and press {fire} on closing hostiles.",
		"accessible": "Depart the berth in a healthy piloted craft and fly to the marked rendezvous. The activity row's Start begins the escort there; entering the marker can also begin it automatically. Stay beside the tender along its marked route and use the fire control on closing hostiles.",
		"next_action": "RENDEZVOUS // ESCORT THE TENDER ALONG ITS MARKED ROUTE",
		"recovery": "SEPARATED WHILE ACTIVE // RETURN BESIDE THE TENDER BEFORE THREE SECONDS; LOST OR FAILED // CHOOSE RESET, RETURN TO THE RENDEZVOUS AND CHOOSE START FOR A FRESH ESCORT",
	},
	&"cinder_reach_checkpoint_route": {
		"title": "Run the checkpoint route",
		"label": "TIMED CHECKPOINT ROUTE",
		"controller": "The activity row's Start begins the countdown. After the start signal, use {move_forward} to pass every gate in order; {sprint_boost} helps you reach the next gate before time runs out.",
		"keyboard": "The activity row's Start begins the countdown. After the start signal, use {move_forward} to pass every gate in order; {sprint_boost} helps you reach the next gate before time runs out.",
		"accessible": "The activity row's Start begins the countdown. After the start signal, fly through every checkpoint gate in order. Boost helps you reach the next gate before time runs out.",
		"next_action": "CLEAR THE NEXT GATE // IN ORDER",
		"recovery": "GATE MISSED // RETURN TO THE NEXT UNFINISHED GATE; TIME EXPIRED // CHOOSE START FOR A NEW COUNTDOWN",
	},
	&"cinder_relay_patrol": {
		"title": "Fly the patrol route",
		"label": "PATROL ROUTE",
		"controller": "The activity row's Start begins the selected patrol. Visit its marked waypoints in order and hold continuously at each for two seconds. Use {brake} if needed to stay inside the waypoint.",
		"keyboard": "The activity row's Start begins the selected patrol. Visit its marked waypoints in order and hold continuously at each for two seconds. Use {brake} if needed to stay inside the waypoint.",
		"accessible": "The activity row's Start begins the selected patrol. Visit its marked waypoints in order and hold continuously at each for two seconds. Brake if needed to stay inside the waypoint.",
		"next_action": "NEXT MARKED WAYPOINT // HOLD CONTINUOUSLY FOR TWO SECONDS",
		"recovery": "LEAVING RESETS THE CURRENT HOLD // WHILE ACTIVE, RE-ENTER THE SAME UNFINISHED WAYPOINT WITHOUT START; FAILED OR ABORTED // CHOOSE RESET THEN START",
	},
	&"cinder_platform_mining_run": {
		"title": "Work the mining platform",
		"label": "PLATFORM MINING RUN",
		"controller": "The activity row's Start begins extraction at the Cinder extraction approach marker. Once active, use {brake} if needed and hold at the marker until progress reaches 100%.",
		"keyboard": "The activity row's Start begins extraction at the Cinder extraction approach marker. Once active, use {brake} if needed and hold at the marker until progress reaches 100%.",
		"accessible": "The activity row's Start begins extraction at the Cinder extraction approach marker. Once active, brake if needed and hold at the marker until progress reaches 100%.",
		"next_action": "HOLD AT THE EXTRACTION APPROACH MARKER // REACH 100%",
		"recovery": "LEAVING RESETS PROGRESS // RETURN TO THE APPROACH MARKER AND CHOOSE START AGAIN",
	},
	&"cinder_derelict_structure_scan": {
		"title": "Scan the derelict",
		"label": "DERELICT STRUCTURE SCAN",
		"controller": "The activity row's Start begins the scan at the derelict scan approach marker. Once active, use {brake} if needed and hold at the marker until progress reaches 100%.",
		"keyboard": "The activity row's Start begins the scan at the derelict scan approach marker. Once active, use {brake} if needed and hold at the marker until progress reaches 100%.",
		"accessible": "The activity row's Start begins the scan at the derelict scan approach marker. Once active, brake if needed and hold at the marker until progress reaches 100%.",
		"next_action": "HOLD AT THE SCAN APPROACH MARKER // REACH 100%",
		"recovery": "LEAVING PAUSES PROGRESS // RETURN TO THE APPROACH MARKER TO CONTINUE",
	},
	&"cinder_debris_beacon_traversal": {
		"title": "Run the beacon line",
		"label": "DEBRIS BEACON TRAVERSAL",
		"controller": "The activity row's Start begins the traversal at the first beacon. Fly through all four beacons in order. Use {brake} if needed to line up on the next unfinished beacon.",
		"keyboard": "The activity row's Start begins the traversal at the first beacon. Fly through all four beacons in order. Use {brake} if needed to line up on the next unfinished beacon.",
		"accessible": "The activity row's Start begins the traversal at the first beacon. Fly through all four beacons in order, braking if needed to line up on the next unfinished beacon.",
		"next_action": "NEXT UNFINISHED BEACON // FOUR BEACONS IN ORDER",
		"recovery": "LINE LOST // RETURN TO THE NEXT UNFINISHED BEACON; CLEARED BEACONS STAY CLEARED WITHOUT START; REWARD SAVE PENDING // CLEARED ROUTE RETAINED; CHOOSE START TO RETRY REWARD SAVE",
	},
	&"cinder_platform_supply_run": {
		"title": "Fly the supply run",
		"label": "PLATFORM SUPPLY RUN",
		"controller": "The activity row's Start begins the run with your Jovian docked at the Cinder berth; cargo is supplied automatically. Depart beyond the berth gate, return and dock, then leave the seat and press {interact} at the platform cargo terminal before the clock runs out.",
		"keyboard": "The activity row's Start begins the run with your Jovian docked at the Cinder berth; cargo is supplied automatically. Depart beyond the berth gate, return and dock, then leave the seat and press {interact} at the platform cargo terminal before the clock runs out.",
		"accessible": "The activity row's Start begins the run with your Jovian docked at the Cinder berth; cargo is supplied automatically. Depart beyond the berth gate, return and dock, then leave the seat and use the interact control at the platform cargo terminal before the clock runs out.",
		"next_action": "CLEAR THE BERTH GATE // RETURN, DOCK AND USE THE CARGO TERMINAL",
		"recovery": "RUN EXPIRED OR FAILED // DOCK AT THE CINDER BERTH, THEN CHOOSE RESET AND START AGAIN",
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
		"controller": "Enter the belt's ringed mouth and reach the first gate. The activity row's Start begins the run there. Use {move_forward} to pass all five gates in order.",
		"keyboard": "Enter the belt's ringed mouth and reach the first gate. The activity row's Start begins the run there. Use {move_forward} to pass all five gates in order.",
		"accessible": "Enter the belt's ringed mouth and reach the first gate. The activity row's Start begins the run there. Fly through all five marked gates in order.",
		"next_action": "NEXT UNFINISHED GATE // FIVE GATES IN ORDER",
		"recovery": "GATE MISSED // RETURN TO THE NEXT UNFINISHED GATE; RESET ABANDONS PROGRESS; FAILED OR RESET // RETURN TO THE FIRST GATE AND CHOOSE START",
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
	&"shipyard_heavy_breach": {
		"title": "Break the charged picket",
		"label": "HEAVY BREACH SORTIE",
		"controller": "On foot at the deck board, press {interact} to arm the posted Heavy Breach contract, then launch a healthy combat craft. The picket commits after berth departure; press {fire} on it before it reaches the protected station asset.",
		"keyboard": "On foot at the deck board, press {interact} to arm the posted Heavy Breach contract, then launch a healthy combat craft. The picket commits after berth departure; press {fire} on it before it reaches the protected station asset.",
		"accessible": "On foot at the deck board, use the interact control to arm the posted Heavy Breach contract, then launch a healthy combat craft. The picket commits after berth departure; use the fire control on it before it reaches the protected station asset.",
		"next_action": "ARM THE POSTED DECK CONTRACT // LAUNCH AND DESTROY THE PICKET",
		"recovery": "ARMED LAUNCH INTERRUPTED // RETRY DEPARTURE; INTERACT AT THE BOARD AGAIN TO CANCEL; SORTIE ENDED // RETURN ON FOOT AND INTERACT TO ARM THE CURRENT OFFER; HEAVY BREACH AND TORPEDO RUN ALTERNATE AFTER EACH CONCLUDED SORTIE; REWARD SAVE PENDING // INTERACT TO RETRY",
	},
	&"shipyard_torpedo_run": {
		"title": "Survive the torpedo run",
		"label": "TORPEDO RUN SORTIE",
		"controller": "On foot at the deck board, press {interact} to arm the posted Torpedo Run contract, then launch a healthy combat craft. After berth departure, destroy the torpedo boat. When a torpedo locks, break across its path with {pitch_up} and {sprint_boost}, or shoot it down with {fire}.",
		"keyboard": "On foot at the deck board, press {interact} to arm the posted Torpedo Run contract, then launch a healthy combat craft. After berth departure, destroy the torpedo boat. When a torpedo locks, break across its path with {pitch_up} and {sprint_boost}, or shoot it down with {fire}.",
		"accessible": "On foot at the deck board, use the interact control to arm the posted Torpedo Run contract, then launch a healthy combat craft. After berth departure, destroy the torpedo boat. When a torpedo locks, turn across its path and boost, or shoot it down with the fire control.",
		"next_action": "ARM THE POSTED DECK CONTRACT // DESTROY THE BOAT; DODGE OR SHOOT DOWN TORPEDOES",
		"recovery": "ARMED LAUNCH INTERRUPTED // RETRY DEPARTURE; INTERACT AT THE BOARD AGAIN TO CANCEL; SORTIE ENDED // RETURN ON FOOT AND INTERACT TO ARM THE CURRENT OFFER; HEAVY BREACH AND TORPEDO RUN ALTERNATE AFTER EACH CONCLUDED SORTIE; REWARD SAVE PENDING // INTERACT TO RETRY",
	},
	&"aurora_coastal_observation": {
		"title": "Survey the Aurora coast",
		"label": "AURORA COASTAL SURVEY",
		"controller": "On foot, press {interact} at the trail sign to start this optional survey, then at the lookout instrument and standing stones. Board your ship whenever ready.",
		"keyboard": "On foot, press {interact} at the trail sign to start this optional survey, then at the lookout instrument and standing stones. Board your ship whenever ready.",
		"accessible": "On foot, use the interact control at the trail sign to start this optional survey, then at the lookout instrument and standing stones. Board your ship whenever ready.",
		"next_action": "FOLLOW THE OBJECTIVE // INTERACT AT EACH MARK",
		"recovery": "TRAIL LOST // THE OBJECTIVE NAMES THE NEXT MARK AND ITS DISTANCE; TRAIL SIGN WHILE ACTIVE // INTERACT TO ABANDON; REWARD SAVE PENDING // OBSERVATIONS RETAINED; INTERACT AT THE STANDING STONES TO RETRY",
	},
	&"rime_ice_core_survey": {
		"title": "Drill the Rime ice core",
		"label": "RIME ICE-CORE SURVEY",
		"controller": "On foot, press {interact} at the orange beacon to start this optional survey, then at the drill rig and ridge gauge. Your SUIT HEATER drains away from warmth; your ship and the heated hut refill it. Board your ship whenever ready.",
		"keyboard": "On foot, press {interact} at the orange beacon to start this optional survey, then at the drill rig and ridge gauge. Your SUIT HEATER drains away from warmth; your ship and the heated hut refill it. Board your ship whenever ready.",
		"accessible": "On foot, use the interact control at the orange survey beacon to start this optional survey, then at the drill rig and ridge strain gauge. Your suit heater drains away from warmth; standing near your ship or in the heated hut refills it. Board your ship whenever ready.",
		"next_action": "FOLLOW THE OBJECTIVE AND DISTANCE // BEACON // DRILL RIG // STRAIN GAUGE // WATCH THE SUIT HEATER",
		"recovery": "HEATER LOW // WARM UP BY YOUR SHIP OR IN THE HEATED HUT, THEN CONTINUE; HEATER EMPTY // YOU ARE SAFE; RESTART A FRESH SURVEY AT THE BEACON; BEACON WHILE ACTIVE // INTERACT TO ABANDON; REWARD SAVE PENDING // READINGS RETAINED; INTERACT AT THE RIDGE GAUGE TO RETRY",
	},
	&"ember_beacon_survey": {
		"title": "Fly the Ember expedition",
		"label": "EMBER RELAY SURVEY",
		"controller": "Cruise to the Ember Moon and fly the caldera corridor down to the pad. On foot, press {interact} at each relay beacon.",
		"keyboard": "Cruise to the Ember Moon and fly the caldera corridor down to the pad. On foot, press {interact} at each relay beacon.",
		"accessible": "Cruise to the Ember Moon, follow the caldera approach corridor down and settle on the landing pad. On foot, use the interact control at each relay beacon.",
		"next_action": "CRUISE TO EMBER // FOLLOW THE CALDERA CORRIDOR",
		"recovery": "CORRIDOR LOST // SLOW DOWN AND LINE UP ON THE NEXT CORRIDOR MARKER",
	},
	&"ember_caldera_errands": {
		"title": "Run a caldera errand",
		"label": "EMBER CALDERA ERRAND",
		"controller": "Follow the route markers from the trailhead to the lava tube or the wrecked lander, then press {interact} at the landmark.",
		"keyboard": "Follow the route markers from the trailhead to the lava tube or the wrecked lander, then press {interact} at the landmark.",
		"accessible": "Walk the marked route from the trailhead to the landmark: the collapsed lava tube west of the pad, or the wrecked survey lander to the south-east. Use the interact control at the landmark.",
		"next_action": "FOLLOW THE ROUTE MARKERS // INTERACT AT THE LANDMARK",
		"recovery": "ROUTE LOST // RETURN TO THE TRAILHEAD TO ABANDON OR RESTART",
	},
}

## Production identifiers that share one authored briefing, so both caldera
## errands brief the pilot only once between them.
const ACTIVITY_ALIASES := {
	&"ember_lava_tube_sounding": &"ember_caldera_errands",
	&"ember_lander_wreck_survey": &"ember_caldera_errands",
}

## Glyph tokens the authored copy above can contain. The HUD resolves these
## through InputGlyphResolver; this list only tells the caller what to resolve.
const GLYPH_ACTIONS: Array[StringName] = [
	&"interact", &"fire", &"move_forward", &"sprint_boost", &"brake", &"pitch_up",
]

var _snapshot: Dictionary = {}
var _source_generation := -1
var _source_revision := -1
var _source_activity: StringName = &""
var _attached := false


static func is_known_activity(activity_id: StringName) -> bool:
	return ACTIVITY_ORDER.has(activity_id)


## The authored briefing id for a production activity id, or `&""`.
static func briefing_id_for(activity_id: StringName) -> StringName:
	if ACTIVITY_ALIASES.has(activity_id):
		return ACTIVITY_ALIASES[activity_id] as StringName
	return activity_id if ACTIVITY_ORDER.has(activity_id) else &""


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
