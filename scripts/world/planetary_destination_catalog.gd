class_name PlanetaryDestinationCatalog
extends RefCounted

## Player-facing directory of authored planetary destinations.
##
## The catalog retains detached identity and route descriptors only. It can
## answer whether a destination has a production route, but it cannot select a
## ship, start travel, stream a world, move an actor, or grant a reward. Those
## checks remain with GameFlow and the existing planetary journey bindings.

const SCHEMA_VERSION := 1
const CATALOG_ID: StringName = &"mudds_planetary_destinations"
const MAX_DESTINATIONS := 16
const MAX_COPY_LENGTH := 128
const MAX_DISTANCE_METERS := 1_000_000_000.0
const UNCHARTED_DISTANCE_METERS := -1.0

const ROUTE_DESCRIPTOR_KEYS := [
	"route_id",
	"route_available",
	"orbital_distance_meters",
	"travel_summary",
	"unavailable_reason",
]
const RUNTIME_STATE_KEYS := [
	"status_id",
	"status_text",
	"action_enabled",
	"engagement_requested",
]
## In-sector places a pilot can actually enter without an interplanetary
## expedition: the hulk's dock and the belt's cut bore. They are listed beside
## the worlds so the sector's contents can be found deliberately, but they are
## kept in their own roster because they are not worlds and must never be
## counted as one.
const SECTOR_SITE_DESCRIPTOR_KEYS := [
	"site_id",
	"display_name",
	"sector_id",
	"site_kind_id",
	"site_kind_text",
	"approach_id",
	"approach_distance_meters",
	"travel_summary",
	"engagement_text",
	"unreachable_text",
]
const SECTOR_SITE_KIND_IDS := [&"dock", &"bore"]
const MAX_SECTOR_SITES := 8

const RUNTIME_STATUS_IDS := [
	&"ready",
	&"queued",
	&"accelerating",
	&"cruising",
	&"braking_to_speed",
	&"braking",
	&"unavailable",
]

var _entries: Dictionary = {}
var _ordered_ids: Array[StringName] = []
var _sites: Dictionary = {}
var _ordered_site_ids: Array[StringName] = []


func register_destination(
	world: PlanetaryWorldDefinition,
	route_descriptor: Dictionary,
) -> Dictionary:
	if world == null or not world.is_definition_valid():
		return _result(false, &"invalid_world_definition")
	if _ordered_ids.size() >= MAX_DESTINATIONS:
		return _result(false, &"catalog_full")
	var destination_id := world.world_id
	if _entries.has(destination_id):
		return _result(false, &"duplicate_destination")
	var validation := _validate_route_descriptor(route_descriptor)
	if not bool(validation.get("accepted", false)):
		return validation
	var route_available := bool(route_descriptor.get("route_available", false))
	var distance_meters := float(
		route_descriptor.get("orbital_distance_meters", UNCHARTED_DISTANCE_METERS)
	)
	_entries[destination_id] = {
		"destination_id": destination_id,
		"display_name": world.display_name,
		"sector_id": world.sector_id,
		"environment_id": &"atmospheric" if world.has_atmosphere else &"airless",
		"environment_text": "ATMOSPHERIC" if world.has_atmosphere else "AIRLESS",
		"evidence_status": world.get_evidence_status_id(),
		"route_id": StringName(route_descriptor.get("route_id", &"")),
		"route_available": route_available,
		"orbital_distance_meters": distance_meters,
		"travel_summary": str(route_descriptor.get("travel_summary", "")),
		"unavailable_reason": str(route_descriptor.get("unavailable_reason", "")),
	}.duplicate(true)
	_ordered_ids.append(destination_id)
	return _result(true, &"destination_registered", {
		"destination_id": destination_id,
		"destination_count": _ordered_ids.size(),
	})


## Registers one in-sector place that is entered by flying to it. There is no
## expedition to launch, so a site carries an approach identifier rather than a
## route id, and the caller still owns whether the sector is even resident.
func register_sector_site(descriptor: Dictionary) -> Dictionary:
	var validation := _validate_sector_site_descriptor(descriptor)
	if not bool(validation.get("accepted", false)):
		return validation
	if _ordered_site_ids.size() >= MAX_SECTOR_SITES:
		return _result(false, &"sector_site_roster_full")
	var site_id := StringName(descriptor.get("site_id", &""))
	if _sites.has(site_id) or _entries.has(site_id):
		return _result(false, &"duplicate_sector_site")
	_sites[site_id] = descriptor.duplicate(true)
	_ordered_site_ids.append(site_id)
	return _result(true, &"sector_site_registered", {
		"site_id": site_id,
		"sector_site_count": _ordered_site_ids.size(),
	})


## Resolves only the authored static route mapping. The caller must still apply
## every live ship, pilot, combat, activity, streaming, and lifecycle gate.
## Sector sites resolve through the same entry point so one board selection has
## one answer, but they resolve to an approach, never to a launchable route.
func resolve_route(destination_id: StringName) -> Dictionary:
	if _sites.has(destination_id):
		var site := _sites[destination_id] as Dictionary
		return _result(true, &"sector_site_resolved", {
			"destination_id": destination_id,
			"route_id": StringName(site.get("approach_id", &"")),
			"destination_kind": &"sector_site",
			"site_kind_id": StringName(site.get("site_kind_id", &"")),
		})
	if not _entries.has(destination_id):
		return _result(false, &"unknown_destination")
	var entry := _entries[destination_id] as Dictionary
	if not bool(entry.get("route_available", false)):
		return _result(false, &"route_unavailable", {
			"destination_id": destination_id,
		})
	return _result(true, &"route_resolved", {
		"destination_id": destination_id,
		"route_id": StringName(entry.get("route_id", &"")),
	})


## Produces the complete detached view consumed by the pause Destination Board.
## Runtime state is optional and never makes an unrouted destination actionable.
func get_presentation_snapshot(
	runtime_states: Dictionary = {},
	sector_site_states: Dictionary = {},
) -> Dictionary:
	var rows: Array[Dictionary] = []
	var available_ids := PackedStringArray()
	for destination_id: StringName in _ordered_ids:
		var entry := (_entries[destination_id] as Dictionary).duplicate(true)
		var route_available := bool(entry.get("route_available", false))
		var runtime := (
			(runtime_states.get(destination_id, {}) as Dictionary).duplicate(true)
			if route_available
			else {}
		)
		var runtime_valid := _valid_runtime_state(runtime)
		var status_id: StringName = &"unavailable"
		var status_text := str(entry.get("unavailable_reason", "ROUTE UNAVAILABLE"))
		var action_enabled := false
		var engagement_requested := false
		if route_available and runtime_valid:
			status_id = StringName(runtime.get("status_id", &"unavailable"))
			status_text = str(runtime.get("status_text", "UNAVAILABLE — SYSTEM OFFLINE"))
			action_enabled = bool(runtime.get("action_enabled", false))
			engagement_requested = bool(runtime.get("engagement_requested", false))
		if route_available:
			available_ids.append(str(destination_id))
		var distance_meters := float(entry.get(
			"orbital_distance_meters", UNCHARTED_DISTANCE_METERS
		))
		rows.append({
			"destination_id": destination_id,
			"display_name": str(entry.get("display_name", "UNKNOWN DESTINATION")),
			"sector_id": StringName(entry.get("sector_id", &"")),
			"environment_id": StringName(entry.get("environment_id", &"unknown")),
			"environment_text": str(entry.get("environment_text", "UNKNOWN")),
			"evidence_status": StringName(entry.get("evidence_status", &"unknown")),
			"route_id": StringName(entry.get("route_id", &"")),
			"route_available": route_available,
			"orbital_distance_meters": distance_meters,
			"distance_text": _distance_text(distance_meters),
			"travel_summary": str(entry.get("travel_summary", "")),
			"status_id": status_id,
			"status_text": status_text,
			"action_enabled": action_enabled,
			"engagement_requested": engagement_requested,
			"action_text": (
				"CANCEL EXPEDITION"
				if engagement_requested
				else "LAUNCH EXPEDITION"
				if action_enabled
				else "ROUTE UNAVAILABLE"
			),
			"presentation_only": true,
		}.duplicate(true))
	var site_rows: Array[Dictionary] = []
	var available_site_ids := PackedStringArray()
	for site_id: StringName in _ordered_site_ids:
		var site := (_sites[site_id] as Dictionary).duplicate(true)
		# A site is only ever offered on a well-typed residency report. A
		# malformed one reads as "not out there", never as reachable.
		var reachable_value: Variant = (
			sector_site_states.get(site_id, {}) as Dictionary
		).get("reachable", false)
		var reachable := reachable_value is bool and bool(reachable_value)
		if reachable:
			available_site_ids.append(str(site_id))
		var distance_meters := float(site.get(
			"approach_distance_meters", UNCHARTED_DISTANCE_METERS
		))
		site_rows.append({
			"destination_id": site_id,
			"display_name": str(site.get("display_name", "UNKNOWN SITE")),
			"sector_id": StringName(site.get("sector_id", &"")),
			"environment_id": StringName(site.get("site_kind_id", &"dock")),
			"environment_text": str(site.get("site_kind_text", "SITE")),
			"evidence_status": &"authored_site",
			"route_id": StringName(site.get("approach_id", &"")),
			"route_available": true,
			"orbital_distance_meters": distance_meters,
			"distance_text": _site_distance_text(distance_meters),
			"travel_summary": str(site.get("travel_summary", "")),
			"status_id": &"ready" if reachable else &"unavailable",
			"status_text": (
				str(site.get("engagement_text", ""))
				if reachable
				else str(site.get("unreachable_text", ""))
			),
			"action_enabled": reachable,
			"engagement_requested": false,
			"action_text": "SHOW BRIEFING" if reachable else "OUT OF SENSOR RANGE",
			"presentation_only": true,
		}.duplicate(true))
	return {
		"schema_version": SCHEMA_VERSION,
		"catalog_id": CATALOG_ID,
		"destination_count": rows.size(),
		"available_destination_ids": available_ids,
		"destinations": rows,
		"sector_site_count": site_rows.size(),
		"available_sector_site_ids": available_site_ids,
		"sector_sites": site_rows,
		"authority": {
			"destination_selection": false,
			"movement": false,
			"streaming": false,
			"origin_shift": false,
			"landing": false,
			"activity": false,
			"reward": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func get_destination_count() -> int:
	return _ordered_ids.size()


func get_sector_site_count() -> int:
	return _ordered_site_ids.size()


func _validate_sector_site_descriptor(descriptor: Dictionary) -> Dictionary:
	if not _has_exact_string_keys(descriptor, SECTOR_SITE_DESCRIPTOR_KEYS):
		return _result(false, &"sector_site_schema_mismatch")
	if (
		descriptor.get("site_id") is not StringName
		or descriptor.get("display_name") is not String
		or descriptor.get("sector_id") is not StringName
		or descriptor.get("site_kind_id") is not StringName
		or descriptor.get("site_kind_text") is not String
		or descriptor.get("approach_id") is not StringName
		or descriptor.get("approach_distance_meters") is not float
		or descriptor.get("travel_summary") is not String
		or descriptor.get("engagement_text") is not String
		or descriptor.get("unreachable_text") is not String
	):
		return _result(false, &"sector_site_type_mismatch")
	if StringName(descriptor.get("site_id", &"")).is_empty() \
			or StringName(descriptor.get("approach_id", &"")).is_empty():
		return _result(false, &"missing_sector_site_identity")
	if StringName(descriptor.get("site_kind_id", &"")) not in SECTOR_SITE_KIND_IDS:
		return _result(false, &"invalid_sector_site_kind")
	var distance := float(descriptor.get("approach_distance_meters", -1.0))
	if not is_finite(distance) or distance <= 0.0 or distance > MAX_DISTANCE_METERS:
		return _result(false, &"invalid_sector_site_distance")
	for copy_key: String in [
		"display_name", "site_kind_text", "travel_summary",
		"engagement_text", "unreachable_text",
	]:
		if not _valid_copy(str(descriptor.get(copy_key, ""))):
			return _result(false, &"invalid_sector_site_copy")
	return _result(true, &"valid_sector_site_descriptor")


func _validate_route_descriptor(descriptor: Dictionary) -> Dictionary:
	if not _has_exact_string_keys(descriptor, ROUTE_DESCRIPTOR_KEYS):
		return _result(false, &"route_descriptor_schema_mismatch")
	if (
		descriptor.get("route_id") is not StringName
		or descriptor.get("route_available") is not bool
		or descriptor.get("orbital_distance_meters") is not float
		or descriptor.get("travel_summary") is not String
		or descriptor.get("unavailable_reason") is not String
	):
		return _result(false, &"route_descriptor_type_mismatch")
	var available := bool(descriptor.get("route_available", false))
	var route_id := StringName(descriptor.get("route_id", &""))
	var distance := float(descriptor.get(
		"orbital_distance_meters", UNCHARTED_DISTANCE_METERS
	))
	var summary := str(descriptor.get("travel_summary", ""))
	var unavailable := str(descriptor.get("unavailable_reason", ""))
	if not _valid_copy(summary):
		return _result(false, &"invalid_travel_summary")
	if available:
		if route_id.is_empty():
			return _result(false, &"missing_route_id")
		if not is_finite(distance) or distance <= 0.0 or distance > MAX_DISTANCE_METERS:
			return _result(false, &"invalid_route_distance")
		if not unavailable.is_empty():
			return _result(false, &"available_route_has_unavailable_reason")
	else:
		if not route_id.is_empty():
			return _result(false, &"unavailable_route_has_route_id")
		if distance != UNCHARTED_DISTANCE_METERS:
			return _result(false, &"unavailable_route_has_distance")
		if not _valid_copy(unavailable):
			return _result(false, &"invalid_unavailable_reason")
	return _result(true, &"valid_route_descriptor")


func _valid_runtime_state(candidate: Dictionary) -> bool:
	if not _has_exact_string_keys(candidate, RUNTIME_STATE_KEYS):
		return false
	if (
		candidate.get("status_id") is not StringName
		or candidate.get("status_text") is not String
		or candidate.get("action_enabled") is not bool
		or candidate.get("engagement_requested") is not bool
	):
		return false
	return (
		StringName(candidate.get("status_id", &"")) in RUNTIME_STATUS_IDS
		and _valid_copy(str(candidate.get("status_text", "")))
	)


## Sites sit a few hundred metres out, not a few thousand kilometres, so they
## are quoted in metres rather than being rounded away to "0 KM".
func _site_distance_text(distance_meters: float) -> String:
	return "%s M FROM MUDDS" % _grouped_integer(roundi(distance_meters))


func _distance_text(distance_meters: float) -> String:
	if distance_meters == UNCHARTED_DISTANCE_METERS:
		return "ORBITAL ROUTE UNCHARTED"
	return "%s KM FROM MUDDS" % _grouped_integer(roundi(distance_meters / 1000.0))


static func _grouped_integer(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped


static func _valid_copy(value: String) -> bool:
	return (
		not value.is_empty()
		and value == value.strip_edges()
		and value.length() <= MAX_COPY_LENGTH
		and not value.contains("\n")
		and not value.contains("\r")
	)


static func _has_exact_string_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key: Variant in candidate:
		if key is not String or not expected.has(key):
			return false
	return true


static func _result(
	accepted: bool,
	reason: StringName,
	extra: Dictionary = {},
) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
