extends RefCounted
## The small per-world description a [PlanetarySurfaceVisitExpedition] is
## configured by.
##
## Aurora was the first world visited through the journey coordinator's
## surface-visit lane and Rime the second. Everything the two visits did was the
## same production path; what differed was only which world the lane admits,
## which streaming pair and save slot belong to it, where its authored pad is,
## which optional on-foot activity runs there and the words the player reads.
## Those differences live here and nowhere else, so a further atmospheric world
## is one new profile rather than another thousand-line copy of the visit.
##
## A profile is plain data. It owns no node, no signal and no authority; the
## visit reads it and the profile never changes after [method validate] passes.

## The Destination Board row and the journey lane's world id.
var destination_id: StringName = &""
var world_id: StringName = &""
## Player-facing world name ("Aurora"). Most copy is built from it.
var display_name := ""
## Lower-case stem for every typed rejection reason and receipt id ("aurora"
## yields `aurora_visit_refused` and `aurora-visit-ended-0000000001`).
var reason_prefix := ""

## GameFlow members this visit reads. Names rather than references, because a
## visit is constructed while GameFlow is still initialising its members.
var bootstrap_property: StringName = &""
var binding_property: StringName = &""
var persistence_binding_property: StringName = &""
## The other surface visit sharing the one lane, if any, and the copy shown
## while it holds that lane.
var peer_expedition_property: StringName = &""
var peer_active_copy := ""

## The authored landing-region resource and the approach-source script whose
## node arms the corridor. Both are preloaded by the world's thin wrapper.
var landing_region: PlanetaryLandingRegionDefinition
var approach_source_script: GDScript
## The optional on-foot activity. Constructed as `new(flow, visit)`; it may
## additionally declare `physics_tick(delta)` (run while on foot) and
## `detach()` (run when the surface is cleared).
var survey_script: GDScript

## The exploration berth leased on the streamed world's landing region.
var berth_node_name := ""
var berth_id: StringName = &""
var approach_source_node_name := ""
var fade_layer_name := ""

## Copy that is not simply the world's name dropped into a shared sentence.
var cruise_toast_body := "Streaming the world and arming the landing approach"
var welcome_toast_body := "E: leave the ship. Explore, then board to return."
var outbound_objective := ""
var corridor_objective := ""
var landing_objective := ""
var survey_heading := ""
var restore_toast_body := "Your ship is on the pad where you left it"
var return_toast_body := ""


## Returns the list of missing fields; an empty list means the visit may use it.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for key: String in [
		"destination_id", "world_id", "display_name", "reason_prefix",
		"bootstrap_property", "binding_property", "persistence_binding_property",
		"berth_node_name", "berth_id", "approach_source_node_name",
		"fade_layer_name", "outbound_objective", "corridor_objective",
		"landing_objective", "survey_heading", "return_toast_body",
	]:
		if str(get(key)).strip_edges().is_empty():
			errors.append(key)
	if landing_region == null:
		errors.append("landing_region")
	if approach_source_script == null:
		errors.append("approach_source_script")
	if survey_script == null:
		errors.append("survey_script")
	return errors


## `aurora` + `visit_refused` -> `&"aurora_visit_refused"`.
func reason(suffix: String) -> StringName:
	return StringName("%s_%s" % [reason_prefix, suffix])


func upper_name() -> String:
	return display_name.to_upper()


## Detached description for snapshots and tests.
func describe() -> Dictionary:
	return {
		"destination_id": destination_id,
		"world_id": world_id,
		"display_name": display_name,
		"reason_prefix": reason_prefix,
		"bootstrap_property": bootstrap_property,
		"binding_property": binding_property,
		"persistence_binding_property": persistence_binding_property,
		"peer_expedition_property": peer_expedition_property,
		"berth_id": berth_id,
		"landing_region_path": landing_region.resource_path \
			if landing_region != null else "",
		"survey_script_path": survey_script.resource_path \
			if survey_script != null else "",
	}.duplicate(true)
