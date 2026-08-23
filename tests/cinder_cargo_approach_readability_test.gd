extends SceneTree

## Focused threshold-readability contract for the embodied Cinder cabin. Static
## shape, text and one restrained light identify the real aperture without
## changing collision, authority or evidence status.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := Hauler.new() as CinderCargoHauler
	root.add_child(craft)
	await process_frame
	await physics_frame

	var boarding := craft.get_boarding_marker()
	var visual := craft.get_variant_visual_root()
	var sign := craft.get_node_or_null(^"CinderCargoVisual/CargoAccessSign") as Label3D
	var threshold_light := craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdLight") as OmniLight3D
	_check(sign != null and threshold_light != null, "the physical port aperture has retained sign and threshold light")
	_check(
		sign != null
			and sign.text.contains("CARGO ACCESS")
			and sign.text.contains("LOADMASTER")
			and sign.get_meta("presentation_only", false)
			and sign.get_meta("color_independent", false),
		"the approach sign is readable with text and shape-independent cues"
	)
	_check(
		threshold_light != null
			and threshold_light.light_energy > 0.0
			and threshold_light.omni_range >= 4.0
			and not threshold_light.shadow_enabled
			and threshold_light.get_meta("reduced_flash_safe", false)
			and not threshold_light.get_meta("animated", true),
		"the threshold uses one static shadowless reduced-flash-safe light"
	)
	for node_name in ["CargoThresholdPostPort", "CargoThresholdPostStarboard", "CargoThresholdHeader"]:
		var cue := craft.get_node_or_null(NodePath("CinderCargoVisual/" + node_name)) as MeshInstance3D
		_check(
			cue != null
				and cue.get_meta("presentation_only", false)
				and cue.get_meta("route_id", &"") == Hauler.CABIN_ROUTE_ID,
			"%s is a presentation-only physical route cue" % node_name
		)
	if boarding != null and sign != null:
		_check(
			sign.global_position.distance_to(boarding.global_position) < 2.1,
			"the sign stays at the real boarding threshold"
		)
	_check(
		visual != null
			and craft.get_in_flight_cabin_report().get("boarding_route_id", &"") == Hauler.CABIN_ROUTE_ID
			and craft.get_loadmaster_station_anchor() != null,
		"threshold cues preserve the existing cabin route and physical station"
	)
	_check(craft.get_meta("evidence_status", &"") == &"NEW", "threshold presentation preserves NEW evidence status")
	_check(craft.get_node_or_null(^"WalkableInterior/InteriorOccupantVolume") != null, "threshold presentation preserves the occupancy volume")

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_CARGO_APPROACH_READABILITY_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
