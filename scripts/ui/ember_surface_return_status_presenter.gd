class_name EmberSurfaceReturnStatusPresenter
extends RefCounted

## Presentation-only view of detached Ember surface/return evidence.
## It never moves actors, admits landing/reboard, selects berths, or grants rewards.

const STATES := [
	&"orbit_approach", &"descent", &"surface_approach", &"landing_approach",
	&"landed", &"on_foot", &"reboard", &"reboarded", &"takeoff", &"ascent",
	&"orbit_return", &"return_manifest", &"rejected",
]
const OPTIONAL_SURFACE_OBJECTIVE_SPECS := [
	{
		"checkpoint_id": &"ember_sample_rack_analysis_log",
		"interaction_key": &"sample_rack_interaction",
		"interaction_id": &"ember_sample_rack_analysis",
		"label": "SAMPLE RACK",
	},
	{
		"checkpoint_id": &"ember_bunker_gantry_log",
		"interaction_key": &"survey_interaction",
		"interaction_id": &"ember_bunker_gantry_survey",
		"label": "BUNKER / GANTRY LOG",
	},
]

var _source_generation := -1
var _attached := false
var _view: Dictionary = {}


func present(snapshot: Dictionary, reduced_motion: bool = false) -> Dictionary:
	var generation_variant: Variant = snapshot.get("generation", null)
	if not generation_variant is int or int(generation_variant) < 0:
		return _reject(&"invalid_generation")
	var generation := int(generation_variant)
	if _source_generation >= 0 and generation < _source_generation:
		return _reject(&"stale_generation")
	_source_generation = generation
	var host := snapshot.get("host", {}) as Dictionary
	var binding := snapshot.get("binding", {}) as Dictionary
	var receipt := snapshot.get("last_result", {}) as Dictionary
	var manifest := snapshot.get("return_manifest", {}) as Dictionary
	var state := StringName(host.get("phase_id", &""))
	if not bool(host.get("attached", binding.get("attached", false))):
		state = &"rejected"
	if receipt.has("accepted") and not bool(receipt.get("accepted", false)):
		state = &"rejected"
	elif bool(receipt.get("accepted", false)) and StringName(receipt.get("reason", &"")) == &"return_manifest_ready":
		state = &"return_manifest"
	var mapped := _map_state(state)
	if mapped.is_empty():
		return _reject(&"unsupported_phase")
	var status_semantics := _status_semantics(
		mapped.get("state", &"rejected") as StringName,
		bool(host.get("attached", binding.get("attached", false))), receipt
	)
	var visible_title := "EMBER %s %s" % [
		str(status_semantics.get("marker", "[???]")),
		str(status_semantics.get("short_label", "STATUS UNAVAILABLE")),
	]
	var route_guidance := _route_guidance(
		host, binding, mapped.get("state", &"rejected") as StringName
	)
	var optional_objectives := _optional_surface_objectives(
		host, binding, mapped.get("state", &"rejected") as StringName
	)
	var caldera_expeditions := _caldera_expeditions(
		host, binding, mapped.get("state", &"rejected") as StringName
	)
	var lines := PackedStringArray([visible_title])
	lines.append("STATUS MARKER  //  %s  //  %s" % [
		str(status_semantics.get("marker", "[???]")),
		str(status_semantics.get("label", "STATUS UNAVAILABLE")),
	])
	var distance := _finite(host, &"distance_meters")
	var speed := _finite(host, &"speed_meters_per_second")
	if bool(route_guidance.get("available", false)):
		distance = float(route_guidance.get("distance_m", distance))
		lines.append(
			"NEXT  %s  //  %.1f m" % [
				route_guidance.get("target_label", "ROUTE"), distance,
			]
		)
	if bool(optional_objectives.get("available", false)):
		lines.append("OPTIONAL SURVEY  //  %d OF %d" % [
			int(optional_objectives.get("completed_count", 0)),
			int(optional_objectives.get("objective_count", 0)),
		])
		for objective: Dictionary in optional_objectives.get("objectives", []) as Array:
			var objective_line := "OPTIONAL  %s  %s" % [
				"[X]" if bool(objective.get("completed", false)) else "[ ]",
				str(objective.get("label", "SURFACE TASK")),
			]
			var objective_distance := float(objective.get("distance_m", -1.0))
			if not bool(objective.get("completed", false)) \
					and is_finite(objective_distance) and objective_distance >= 0.0:
				objective_line += "  //  %.1f m" % objective_distance
			lines.append(objective_line)
	if bool(caldera_expeditions.get("available", false)):
		lines.append("EXPEDITIONS  //  %d OF %d LOGGED" % [
			int(caldera_expeditions.get("logged_count", 0)),
			int(caldera_expeditions.get("expedition_count", 0)),
		])
		var in_hand := caldera_expeditions.get("active", {}) as Dictionary
		if in_hand.is_empty():
			var offer := caldera_expeditions.get("nearest_offer", {}) as Dictionary
			if not offer.is_empty():
				var offer_line := "EXPEDITION  [ ]  %s" % str(
					offer.get("label", "CALDERA ERRAND")
				)
				var offer_distance := float(offer.get("distance_m", -1.0))
				if is_finite(offer_distance) and offer_distance >= 0.0:
					offer_line += "  //  %.1f m" % offer_distance
				lines.append(offer_line)
				var prompt := str(offer.get("prompt", "")).strip_edges()
				if not prompt.is_empty():
					lines.append(prompt)
		else:
			var progress_line := "EXPEDITION  [>]  %s  //  CHECKPOINT %d OF %d" % [
				str(in_hand.get("label", "CALDERA ERRAND")),
				mini(
					int(in_hand.get("checkpoints_reached", 0)) + 1,
					maxi(1, int(in_hand.get("checkpoint_count", 1))),
				),
				maxi(1, int(in_hand.get("checkpoint_count", 1))),
			]
			var leg_distance := float(in_hand.get("distance_m", -1.0))
			if is_finite(leg_distance) and leg_distance >= 0.0:
				progress_line += "  //  %.1f m" % leg_distance
			lines.append(progress_line)
			var abandon_prompt := str(in_hand.get("prompt", "")).strip_edges()
			if not abandon_prompt.is_empty():
				lines.append(abandon_prompt)
	if distance >= 0.0:
		lines.append("DISTANCE  %.1f m" % distance)
	if speed >= 0.0:
		lines.append("SPEED  %.1f m/s" % speed)
	if not receipt.is_empty() and receipt.has("reason"):
		lines.append("REASON  " + str(receipt.get("reason", &"")).replace("_", " ").to_upper())
	if not manifest.is_empty() and StringName(manifest.get("destination_id", &"")) != &"":
		lines.append("DESTINATION  " + str(manifest.get("destination_id")))
	var next_action := _next_action_cue(mapped.get("state", &"rejected") as StringName)
	if not next_action.is_empty():
		lines.append("NEXT ACTION  //  " + str(next_action.get("label", "")))
	lines.append("TRANSITION  //  STATIC" if reduced_motion else "TRANSITION  //  STANDARD")
	_attached = true
	_view = {
		"accepted": true, "attached": true, "state": mapped.get("state"),
		"visible_title": visible_title,
		"text": "\n".join(lines), "generation": generation,
		"distance_m": distance, "speed_mps": speed,
		"reduced_motion": reduced_motion, "focusable": true,
		"color_independent": true, "reduced_flash_safe": true,
		"flash_requested": false, "route_guidance": route_guidance,
		"optional_objectives": optional_objectives,
		"caldera_expeditions": caldera_expeditions,
		"status_semantics": status_semantics,
		"next_action": next_action,
		"presentation_only": true,
		"input_authority": false, "travel_authority": false,
		"boarding_authority": false, "reward_authority": false,
		"movement_authority": false, "landing_authority": false,
		"session_authority": false,
	}.duplicate(true)
	return _view.duplicate(true)


func detach() -> Dictionary:
	_attached = false
	_source_generation = -1
	_view = {"accepted": true, "attached": false, "state": &"rejected", "presentation_only": true}
	return _view.duplicate(true)


func get_snapshot() -> Dictionary:
	var result := _view.duplicate(true)
	result["attached"] = _attached
	return result


func _map_state(state: StringName) -> Dictionary:
	if state == &"surface_flight":
		state = &"surface_approach"
	if state == &"disembarking" or state == &"surface_outbound" or state == &"boarding":
		state = &"on_foot" if state != &"boarding" else &"reboard"
	if state == &"completed":
		state = &"orbit_return"
	if state not in STATES:
		return {}
	return {"state": state, "label": str(state).replace("_", " ").to_upper()}


## Fixed ASCII markers deliberately survive colour loss, motion reduction, and
## compact HUD rendering. They are presentation labels, never control states.
func _status_semantics(
		state: StringName, host_attached: bool, receipt: Dictionary
	) -> Dictionary:
	var marker := "[???]"
	var label := "STATUS UNAVAILABLE"
	var short_label := "STATUS UNAVAILABLE"
	var kind := &"unavailable"
	match state:
		&"orbit_approach":
			marker = "[O>>]"
			label = "ORBIT APPROACH // ALIGN ENTRY"
			short_label = "ORBIT: ALIGN ENTRY"
			kind = &"travel"
		&"descent":
			marker = "[>>>]"
			label = "DESCENT // ENTERING"
			short_label = "DESCENT: ENTERING"
			kind = &"travel"
		&"surface_approach":
			marker = "[>=>]"
			label = "ENTRY CORRIDOR // HOLD LINE"
			short_label = "ENTRY: CORRIDOR"
			kind = &"travel"
		&"landing_approach":
			marker = "[v=v]"
			label = "LANDING COMMIT // HOLD STEADY"
			short_label = "LANDING: COMMIT"
			kind = &"travel"
		&"landed":
			marker = "[===]"
			label = "LANDED // HOLD POSITION"
			short_label = "LANDED: HOLD"
			kind = &"ready"
		&"on_foot":
			marker = "[***]"
			label = "ON FOOT // SURFACE TASK"
			short_label = "ON FOOT: SURFACE"
			kind = &"travel"
		&"reboard":
			marker = "[<->]"
			label = "REBOARD // ENTER CRAFT"
			short_label = "REBOARD: ENTER"
			kind = &"ready"
		&"reboarded":
			marker = "[=^=]"
			label = "REBOARDED // READY FOR TAKEOFF"
			short_label = "REBOARDED: TAKEOFF READY"
			kind = &"ready"
		&"takeoff":
			marker = "[^>>]"
			label = "TAKEOFF // CLIMB"
			short_label = "TAKEOFF: CLIMB"
			kind = &"travel"
		&"ascent":
			marker = "[^^^]"
			label = "ASCENT // CLIMB TO ORBIT"
			short_label = "ASCENT: TO ORBIT"
			kind = &"travel"
		&"orbit_return":
			marker = "[|||]"
			label = "ORBIT RETURN // HANDOFF"
			short_label = "ORBIT RETURN: HANDOFF"
			kind = &"travel"
		&"return_manifest":
			marker = "[###]"
			label = "RETURN MANIFEST // READY"
			short_label = "MANIFEST: READY"
			kind = &"ready"
		&"rejected":
			if not host_attached:
				marker = "[---]"
				label = "DETACHED // WAIT FOR CURRENT SESSION"
				short_label = "DETACHED: WAIT SESSION"
				kind = &"detached"
			else:
				marker = "[XXX]"
				label = "REJECTED // STATUS UNAVAILABLE"
				short_label = "REJECTED: UNAVAILABLE"
				kind = &"rejected"
	return {
		"marker": marker,
		"label": label,
		"short_label": short_label,
		"kind": kind,
		"text_independent": true,
		"shape_independent": true,
		"color_independent": true,
		"input_authority": false,
		"travel_authority": false,
	}.duplicate(true)


func _finite(source: Dictionary, key: StringName) -> float:
	var value: Variant = source.get(key, -1.0)
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0:
		return -1.0
	return float(value)


## Reboarding leaves the craft landed and waiting for the already-authenticated
## take-off transition. This is a readable state cue only: it neither exposes
## an input binding nor requests travel from the host.
func _next_action_cue(state: StringName) -> Dictionary:
	if state == &"reboarded":
		return {
			"id": &"takeoff",
			"label": "TAKE OFF",
			"focusable": true,
			"input_authority": false,
			"travel_authority": false,
		}.duplicate(true)
	return {}


## Derives one display-only route vector from the Host's detached actor/route
## observations and the retained planetary presentation's authored landmarks.
## It never samples a node, chooses a path, or mutates either source.
func _route_guidance(
		host: Dictionary, binding: Dictionary, state: StringName
	) -> Dictionary:
	var actor_state := host.get("actor_state", {}) as Dictionary
	var surface_route := host.get("surface_route", {}) as Dictionary
	var planetary := binding.get("planetary_surface", {}) as Dictionary
	var relay_presentation := planetary.get(
		"relay_survey_presentation", {}
	) as Dictionary
	var actor_key := &"player_position" if state in [
		&"on_foot", &"reboard",
	] else &"ship_position"
	var actor: Variant = actor_state.get(actor_key)
	if actor is not Vector3 or not (actor as Vector3).is_finite():
		return _unavailable_route_guidance()
	var target: Variant
	var target_id: StringName
	var target_label: String
	var route_kind: StringName
	if state in [&"descent", &"landed"]:
		target = surface_route.get("egress_anchor")
		target_id = &"ember_landing_pad"
		target_label = "LANDING PAD"
		route_kind = &"landing"
	elif state == &"on_foot":
		var cue_mode := StringName(relay_presentation.get("cue_mode", &""))
		if cue_mode in [&"approach_relay", &"active_relay"]:
			target = relay_presentation.get("relay_anchor")
			target_id = &"ember_relay_tower"
			target_label = "RELAY"
		else:
			target = relay_presentation.get(
				"return_anchor", surface_route.get("staging_anchor")
			)
			target_id = &"ember_return_route"
			target_label = "RETURN ROUTE"
		route_kind = &"surface_route"
	elif state == &"reboard":
		target = surface_route.get("egress_anchor")
		target_id = &"ember_landing_pad"
		target_label = "LANDING PAD"
		route_kind = &"surface_route"
	else:
		return _unavailable_route_guidance()
	if target is not Vector3 or not (target as Vector3).is_finite():
		return _unavailable_route_guidance()
	var actor_position := actor as Vector3
	var target_position := target as Vector3
	var displacement := target_position - actor_position
	var map_direction := Vector2(displacement.x, displacement.z)
	return {
		"available": true,
		"target_id": target_id,
		"target_label": target_label,
		"actor_position": actor_position,
		"target_position": target_position,
		"distance_m": displacement.length(),
		"offscreen_direction": map_direction.normalized() \
			if not map_direction.is_zero_approx() else Vector2.ZERO,
		"route_kind": route_kind,
		"coordinate_source": &"authoritative_detached_actor_and_landmark_snapshots",
		"reduced_flash_safe": true,
		"navigation_authority": false,
	}.duplicate(true)


func _unavailable_route_guidance() -> Dictionary:
	return {
		"available": false,
		"reduced_flash_safe": true,
		"navigation_authority": false,
	}.duplicate(true)


## Makes both already-authored side interactions discoverable from the retained
## surface card. It reads only the authenticated detached production snapshot;
## the primary relay route and its marker remain authoritative and unchanged.
func _optional_surface_objectives(
		host: Dictionary, binding: Dictionary, state: StringName
	) -> Dictionary:
	if state != &"on_foot":
		return _unavailable_optional_objectives()
	var actor: Variant = (
		host.get("actor_state", {}) as Dictionary
	).get("player_position", Vector3.INF)
	if actor is not Vector3 or not (actor as Vector3).is_finite():
		return _unavailable_optional_objectives()
	var planetary := binding.get("planetary_surface", {}) as Dictionary
	var relay := planetary.get("relay_survey", {}) as Dictionary
	if StringName(relay.get("activity_id", &"")) != &"ember_beacon_survey":
		return _unavailable_optional_objectives()
	var checkpoints := relay.get("optional_checkpoints", {}) as Dictionary
	var objectives: Array[Dictionary] = []
	var completed_count := 0
	var nearest: Dictionary = {}
	for spec: Dictionary in OPTIONAL_SURFACE_OBJECTIVE_SPECS:
		var checkpoint_id := spec.get("checkpoint_id", &"") as StringName
		var expected_interaction_id := StringName(spec.get("interaction_id", &""))
		var checkpoint := checkpoints.get(checkpoint_id, {}) as Dictionary
		var status := StringName(checkpoint.get("status", &""))
		var completed := bool(checkpoint.get("completed", false))
		if StringName(checkpoint.get("checkpoint_id", &"")) != checkpoint_id \
				or StringName(checkpoint.get("interaction_id", &"")) \
					!= expected_interaction_id \
				or status not in [&"available", &"completed"] \
				or completed != (status == &"completed"):
			continue
		var interaction_key := spec.get("interaction_key", &"") as StringName
		var interaction := planetary.get(interaction_key, {}) as Dictionary
		if StringName(interaction.get("interaction_id", &"")) \
				!= expected_interaction_id:
			continue
		var position: Variant = interaction.get("position_body_local_m", Vector3.INF)
		var distance := -1.0
		if position is Vector3 and (position as Vector3).is_finite():
			distance = (position as Vector3).distance_to(actor as Vector3)
		if completed:
			completed_count += 1
		var objective := {
			"checkpoint_id": checkpoint_id,
			"label": str(spec.get("label", "SURFACE TASK")),
			"status": status,
			"completed": completed,
			"distance_m": distance,
			"position_body_local_m": (
				position if position is Vector3 and (position as Vector3).is_finite()
				else Vector3.INF
			),
			"presentation_only": true,
			"navigation_authority": false,
			"activity_authority": false,
			"reward_authority": false,
		}.duplicate(true)
		objectives.append(objective)
		if not completed and distance >= 0.0 \
				and (nearest.is_empty() \
					or distance < float(nearest.get("distance_m", INF))):
			nearest = objective.duplicate(true)
	return {
		"available": not objectives.is_empty(),
		"completed_count": completed_count,
		"objective_count": objectives.size(),
		"objectives": objectives,
		"nearest_incomplete": nearest,
		"coordinate_source": &"authenticated_detached_surface_interactions",
		"presentation_only": true,
		"navigation_authority": false,
		"activity_authority": false,
		"reward_authority": false,
	}.duplicate(true)


## Makes the two authored caldera errands legible from the retained surface
## card: how many are logged, which one is in hand and how far its next
## checkpoint is, or which one is being offered underfoot. Everything is read
## from the authenticated detached errand snapshot and the offer points''' own
## fresh reports; this view can neither start, advance nor pay an errand.
func _caldera_expeditions(
		host: Dictionary, binding: Dictionary, state: StringName
	) -> Dictionary:
	if state != &"on_foot":
		return _unavailable_caldera_expeditions()
	var actor: Variant = (
		host.get("actor_state", {}) as Dictionary
	).get("player_position", Vector3.INF)
	if actor is not Vector3 or not (actor as Vector3).is_finite():
		return _unavailable_caldera_expeditions()
	var planetary := binding.get("planetary_surface", {}) as Dictionary
	var expeditions := planetary.get("caldera_expeditions", {}) as Dictionary
	if StringName(expeditions.get("world_id", &"")) != &"ember_moon":
		return _unavailable_caldera_expeditions()
	var records := expeditions.get("activities", {}) as Dictionary
	if records.is_empty():
		return _unavailable_caldera_expeditions()
	var offer_reports := (
		planetary.get("caldera_expedition_interactions", {}) as Dictionary
	).get("offers", {}) as Dictionary
	var actor_position := actor as Vector3
	var active_id := StringName(expeditions.get("active_activity_id", &""))
	var logged_count := 0
	var offers: Array[Dictionary] = []
	var nearest_offer: Dictionary = {}
	var in_hand: Dictionary = {}
	for activity_id: StringName in records:
		var record := records[activity_id] as Dictionary
		var offer_state := StringName(record.get("offer_state", &""))
		if offer_state not in [&"available", &"active", &"busy", &"completed"]:
			continue
		if offer_state == &"completed":
			logged_count += 1
		var report := offer_reports.get(activity_id, {}) as Dictionary
		var label := str(record.get("display_name", "Caldera Errand")).to_upper()
		var trailhead: Variant = record.get("trailhead_body_local_m", Vector3.INF)
		var trailhead_distance := -1.0
		if trailhead is Vector3 and (trailhead as Vector3).is_finite():
			trailhead_distance = (trailhead as Vector3).distance_to(actor_position)
		var prompt := str(report.get("prompt", "")) \
			if bool(report.get("active", false)) else ""
		var entry := {
			"activity_id": activity_id,
			"label": label,
			"offer_state": offer_state,
			"distance_m": trailhead_distance,
			"in_range": bool(report.get("pressable", false)),
			"prompt": prompt,
			"position_body_local_m": (
				trailhead if trailhead is Vector3 else Vector3.INF
			),
			"presentation_only": true,
			"activity_authority": false,
			"reward_authority": false,
			"navigation_authority": false,
		}.duplicate(true)
		if offer_state == &"active" and activity_id == active_id:
			var next_checkpoint: Variant = record.get(
				"next_checkpoint_body_local_m", Vector3.INF
			)
			var leg_distance := -1.0
			if next_checkpoint is Vector3 and (next_checkpoint as Vector3).is_finite():
				leg_distance = (next_checkpoint as Vector3).distance_to(actor_position)
			in_hand = entry.duplicate(true)
			in_hand["checkpoints_reached"] = int(record.get("checkpoints_reached", 0))
			in_hand["checkpoint_count"] = int(record.get("checkpoint_count", 0))
			in_hand["distance_m"] = leg_distance
			in_hand["position_body_local_m"] = (
				next_checkpoint if next_checkpoint is Vector3 else Vector3.INF
			)
			continue
		offers.append(entry)
		if offer_state == &"available" and trailhead_distance >= 0.0 \
				and (nearest_offer.is_empty() \
					or trailhead_distance < float(nearest_offer.get("distance_m", INF))):
			nearest_offer = entry.duplicate(true)
	return {
		"available": true,
		"world_id": &"ember_moon",
		"logged_count": logged_count,
		"expedition_count": records.size(),
		"active": in_hand,
		"offers": offers,
		"nearest_offer": nearest_offer,
		"coordinate_source": &"authenticated_detached_caldera_errand_snapshot",
		"reduced_flash_safe": true,
		"presentation_only": true,
		"activity_authority": false,
		"reward_authority": false,
		"navigation_authority": false,
	}.duplicate(true)


func _unavailable_caldera_expeditions() -> Dictionary:
	return {
		"available": false,
		"logged_count": 0,
		"expedition_count": 0,
		"active": {},
		"offers": [],
		"nearest_offer": {},
		"reduced_flash_safe": true,
		"presentation_only": true,
		"activity_authority": false,
		"reward_authority": false,
		"navigation_authority": false,
	}.duplicate(true)


func _unavailable_optional_objectives() -> Dictionary:
	return {
		"available": false,
		"completed_count": 0,
		"objective_count": 0,
		"objectives": [],
		"nearest_incomplete": {},
		"presentation_only": true,
		"navigation_authority": false,
		"activity_authority": false,
		"reward_authority": false,
	}.duplicate(true)


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "presentation_only": true, "movement_authority": false, "landing_authority": false}
