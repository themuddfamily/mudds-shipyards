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
	_finish()


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
