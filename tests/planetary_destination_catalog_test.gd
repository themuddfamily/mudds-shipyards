extends SceneTree

const CatalogType := preload("res://scripts/world/planetary_destination_catalog.gd")
const EmberWorld := preload("res://assets/world/planets/ember_moon_world.tres")
const AuroraWorld := preload("res://assets/world/planets/aurora_temperate_world.tres")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	var catalog := CatalogType.new()
	var ember_registration := catalog.register_destination(EmberWorld, {
		"route_id": &"ember_surface_expedition",
		"route_available": true,
		"orbital_distance_meters": 8_000_000.0,
		"travel_summary": "LAND // RELAY SURVEY // RETURN",
		"unavailable_reason": "",
	})
	var aurora_registration := catalog.register_destination(AuroraWorld, {
		"route_id": &"",
		"route_available": false,
		"orbital_distance_meters": -1.0,
		"travel_summary": "ATMOSPHERIC FOUNDATION // ROUTE NOT COMMISSIONED",
		"unavailable_reason": "NOT YET VISITABLE",
	})
	_check(
		bool(ember_registration.get("accepted", false))
		and bool(aurora_registration.get("accepted", false))
		and catalog.get_destination_count() == 2,
		"the two authored worlds enter one bounded catalog",
	)
	_check(
		not bool(catalog.register_destination(EmberWorld, {
			"route_id": &"ember_surface_expedition",
			"route_available": true,
			"orbital_distance_meters": 8_000_000.0,
			"travel_summary": "LAND // RELAY SURVEY // RETURN",
			"unavailable_reason": "",
		}).get("accepted", true)),
		"duplicate world identities cannot create duplicate destination rows",
	)
	var snapshot := catalog.get_presentation_snapshot({
		&"ember_moon": {
			"status_id": &"ready",
			"status_text": "READY — EMBER MOON",
			"action_enabled": true,
			"engagement_requested": false,
		},
		# Even a forged runtime state cannot make an unrouted world actionable.
		&"aurora_temperate_world": {
			"status_id": &"ready",
			"status_text": "READY — AURORA",
			"action_enabled": true,
			"engagement_requested": true,
		},
	})
	var rows := snapshot.get("destinations", []) as Array
	_check(
		int(snapshot.get("destination_count", 0)) == 2
		and rows.size() == 2
		and snapshot.get("available_destination_ids") == PackedStringArray(["ember_moon"]),
		"the player snapshot distinguishes the sole production-routed destination",
	)
	var ember := rows[0] as Dictionary
	var aurora := rows[1] as Dictionary
	_check(
		ember.get("destination_id") == &"ember_moon"
		and ember.get("environment_id") == &"airless"
		and ember.get("distance_text") == "8,000 KM FROM MUDDS"
		and ember.get("travel_summary") == "LAND // RELAY SURVEY // RETURN"
		and ember.get("action_text") == "LAUNCH EXPEDITION"
		and bool(ember.get("action_enabled", false)),
		"Ember publishes its authored identity, distance, itinerary, and live action",
	)
	_check(
		aurora.get("destination_id") == &"aurora_temperate_world"
		and aurora.get("environment_id") == &"atmospheric"
		and aurora.get("distance_text") == "ORBITAL ROUTE UNCHARTED"
		and aurora.get("status_text") == "NOT YET VISITABLE"
		and aurora.get("action_text") == "ROUTE UNAVAILABLE"
		and not bool(aurora.get("action_enabled", true))
		and not bool(aurora.get("engagement_requested", true)),
		"Aurora remains visible but cannot be activated by forged presentation state",
	)
	_check(
		bool(catalog.resolve_route(&"ember_moon").get("accepted", false))
		and catalog.resolve_route(&"ember_moon").get("route_id")
			== &"ember_surface_expedition",
		"the catalog resolves Ember to the existing expedition route",
	)
	_check(
		not bool(catalog.resolve_route(&"aurora_temperate_world").get("accepted", true))
		and catalog.resolve_route(&"aurora_temperate_world").get("reason")
			== &"route_unavailable"
		and catalog.resolve_route(&"unknown_world").get("reason")
			== &"unknown_destination",
		"unrouted and unknown worlds fail closed",
	)
	var malformed := catalog.get_presentation_snapshot({
		&"ember_moon": {
			"status_id": &"ready",
			"status_text": "READY — EMBER MOON",
			"action_enabled": true,
		},
	})
	var malformed_ember := (malformed.get("destinations", []) as Array)[0] as Dictionary
	_check(
		malformed_ember.get("status_id") == &"unavailable"
		and not bool(malformed_ember.get("action_enabled", true)),
		"a malformed live state cannot enable a production route",
	)
	rows[0]["display_name"] = "MUTATED"
	var fresh_rows := (
		catalog.get_presentation_snapshot().get("destinations", []) as Array
	)
	_check(
		(fresh_rows[0] as Dictionary).get("display_name") == "Ember Moon",
		"consumer mutation cannot alter retained catalog identity",
	)
	var authority := snapshot.get("authority", {}) as Dictionary
	_check(
		authority.values().all(func(value: Variant) -> bool: return value == false),
		"the catalog owns no travel, movement, streaming, landing, or reward authority",
	)
	_test_sector_sites(catalog)
	_finish()


## The sector's own enterable places are listed beside the worlds, but they are
## never counted as worlds and are never offered while the sector is away.
func _test_sector_sites(catalog: PlanetaryDestinationCatalog) -> void:
	var hulk := catalog.register_sector_site({
		"site_id": &"cinder_hulk_dock_site",
		"display_name": "Abandoned Station Hulk",
		"sector_id": &"cinder_reach",
		"site_kind_id": &"dock",
		"site_kind_text": "PRESSURISED DOCK",
		"approach_id": &"cinder_hulk_dock_approach",
		"approach_distance_meters": 486.0,
		"travel_summary": "DOCK // WALK IN // THROW THE BREAKER",
		"engagement_text": "IN SENSOR RANGE — DOCK ON THE LIT FACE",
		"unreachable_text": "OUT OF SENSOR RANGE — FLY OUT TO CINDER REACH",
	})
	var bore := catalog.register_sector_site({
		"site_id": &"cinder_belt_bore_site",
		"display_name": "Cinder Belt Bore",
		"sector_id": &"cinder_reach",
		"site_kind_id": &"bore",
		"site_kind_text": "CUT BORE",
		"approach_id": &"cinder_belt_bore_run",
		"approach_distance_meters": 368.0,
		"travel_summary": "ENTER THE RINGED MOUTH // FIVE GATES // EXIT",
		"engagement_text": "IN SENSOR RANGE — LINE UP ON THE RINGED MOUTH",
		"unreachable_text": "OUT OF SENSOR RANGE — FLY OUT TO CINDER REACH",
	})
	_check(
		bool(hulk.get("accepted", false)) and bool(bore.get("accepted", false))
		and catalog.get_sector_site_count() == 2
		and catalog.get_destination_count() == 2,
		"both enterable places register as sites without inflating the world count",
	)
	_check(
		not bool(catalog.register_sector_site({
			"site_id": &"cinder_hulk_dock_site",
			"display_name": "Abandoned Station Hulk",
			"sector_id": &"cinder_reach",
			"site_kind_id": &"dock",
			"site_kind_text": "PRESSURISED DOCK",
			"approach_id": &"cinder_hulk_dock_approach",
			"approach_distance_meters": 486.0,
			"travel_summary": "DOCK // WALK IN // THROW THE BREAKER",
			"engagement_text": "IN SENSOR RANGE — DOCK ON THE LIT FACE",
			"unreachable_text": "OUT OF SENSOR RANGE — FLY OUT TO CINDER REACH",
		}).get("accepted", true))
		and not bool(catalog.register_sector_site({
			"site_id": &"cinder_ghost_site",
			"display_name": "Ghost Site",
			"sector_id": &"cinder_reach",
			"site_kind_id": &"wormhole",
			"site_kind_text": "UNKNOWN",
			"approach_id": &"cinder_ghost_approach",
			"approach_distance_meters": 100.0,
			"travel_summary": "NOWHERE",
			"engagement_text": "NOWHERE",
			"unreachable_text": "NOWHERE",
		}).get("accepted", true)),
		"a duplicate site, and a site of an unauthored kind, both fail closed",
	)

	# Sector away: nothing is offered, and the copy says why rather than
	# claiming a route.
	var away := catalog.get_presentation_snapshot({}, {})
	var away_sites := away.get("sector_sites", []) as Array
	_check(
		int(away.get("destination_count", -1)) == 2
		and int(away.get("sector_site_count", -1)) == 2
		and away_sites.size() == 2
		and (away.get("available_sector_site_ids", PackedStringArray())
			as PackedStringArray).is_empty(),
		"the board lists both places while the sector is streamed out",
	)
	var honest_away := true
	for row_variant: Variant in away_sites:
		var row := row_variant as Dictionary
		if bool(row.get("action_enabled", true)):
			honest_away = false
		if StringName(row.get("status_id", &"")) != &"unavailable":
			honest_away = false
		if str(row.get("action_text", "")) != "OUT OF SENSOR RANGE":
			honest_away = false
		if not str(row.get("status_text", "")).begins_with("OUT OF SENSOR RANGE"):
			honest_away = false
	_check(
		honest_away,
		"an absent sector can never present one of its places as engageable",
	)

	# Sector resident: the rows become actionable and quote a metre distance,
	# not a rounded-away kilometre one.
	var near := catalog.get_presentation_snapshot({}, {
		&"cinder_hulk_dock_site": {"reachable": true},
		&"cinder_belt_bore_site": {"reachable": true},
	})
	var near_sites := near.get("sector_sites", []) as Array
	var hulk_row := near_sites[0] as Dictionary
	var bore_row := near_sites[1] as Dictionary
	_check(
		(near.get("available_sector_site_ids", PackedStringArray())
			as PackedStringArray) == PackedStringArray([
				"cinder_hulk_dock_site", "cinder_belt_bore_site",
			])
		and bool(hulk_row.get("action_enabled", false))
		and StringName(hulk_row.get("status_id", &"")) == &"ready"
		and str(hulk_row.get("action_text", "")) == "SHOW BRIEFING"
		and str(hulk_row.get("distance_text", "")) == "486 M FROM MUDDS"
		and str(hulk_row.get("environment_text", "")) == "PRESSURISED DOCK"
		and str(bore_row.get("distance_text", "")) == "368 M FROM MUDDS"
		and str(bore_row.get("travel_summary", ""))
			== "ENTER THE RINGED MOUTH // FIVE GATES // EXIT",
		"a resident sector offers both places with their own copy and distance",
	)
	_check(
		not bool(catalog.get_presentation_snapshot({}, {
			&"cinder_hulk_dock_site": {"reachable": "yes"},
		}).get("sector_sites", [] as Array)[0].get("action_enabled", true)),
		"a malformed residency report cannot offer a place",
	)

	# Both rosters resolve through the same entry point, with different answers.
	var resolved_hulk := catalog.resolve_route(&"cinder_hulk_dock_site")
	var resolved_ember := catalog.resolve_route(&"ember_moon")
	_check(
		bool(resolved_hulk.get("accepted", false))
		and resolved_hulk.get("reason") == &"sector_site_resolved"
		and resolved_hulk.get("destination_kind") == &"sector_site"
		and resolved_hulk.get("route_id") == &"cinder_hulk_dock_approach"
		and bool(resolved_ember.get("accepted", false))
		and resolved_ember.get("reason") == &"route_resolved"
		and not resolved_ember.has("destination_kind"),
		"the board resolves each place to its approach and each world to its route",
	)
	_check(
		not bool(catalog.resolve_route(&"cinder_unknown_site").get("accepted", true)),
		"an unlisted place resolves to nothing",
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_DESTINATION_CATALOG_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("PLANETARY_DESTINATION_CATALOG_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
