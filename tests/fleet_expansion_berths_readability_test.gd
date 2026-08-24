extends SceneTree

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const EXPECTED_LEGEND := "FLEET EXPANSION // BERTH ASSIGNMENTS\n< WEST   DOCK 04  CARGO HAULER\n> EAST   DOCK 05  BOMBER\n^ NORTH  DOCK 06  INTERCEPTOR"
const EXPECTED_ANCHORS := {
	&"dock_04_cargo": Vector3(-34.0, 4.0, -18.0),
	&"dock_05_bomber": Vector3(34.0, 4.0, -18.0),
	&"dock_06_interceptor": Vector3(0.0, 4.0, 34.0),
}

var _failures: PackedStringArray = []


func _initialize() -> void:
	var berths := Berths.new()
	root.add_child(berths)
	await process_frame

	var legend := berths.get_node_or_null(
		^"AccessCirculation/AftJunctionRouteLegend"
	) as Label3D
	_check(
		legend != null
		and legend.text == EXPECTED_LEGEND
		and legend.font_size == 28
		and legend.outline_size == 7
		and legend.billboard == BaseMaterial3D.BILLBOARD_ENABLED
		and bool(legend.get_meta(&"presentation_only", false)),
		"the Aft junction presents explicit Dock 04/05/06 assignments and cardinal routes"
	)

	var cargo_state := berths.get_pad_presentation_state(&"dock_04_cargo")
	_check(
		String(cargo_state.get("sign_text", ""))
		== "DOCK 04  CARGO HAULER  //  APPROACH CLEAR",
		"Dock 04 names its assigned Cargo Hauler class at the pad"
	)

	var anchors_unchanged := true
	for pad_id in EXPECTED_ANCHORS:
		var contract := berths.get_landing_contract(pad_id)
		anchors_unchanged = anchors_unchanged \
			and bool(contract.get("accepted", false)) \
			and (contract.get("landing_anchor", Vector3.INF) as Vector3).is_equal_approx(
				EXPECTED_ANCHORS[pad_id]
			) \
			and not bool(contract.get("ship_authority", true)) \
			and not bool(contract.get("berth_lease_authority", true))
	_check(
		anchors_unchanged
		and bool(berths.get_audit_report().get("valid", false))
		and berths.find_children("*", "StaticBody3D", true, false).size() == 10
		and berths.find_children("*", "CollisionShape3D", true, false).size() == 13,
		"readability polish preserves landing anchors, authority, and walkable collision"
	)

	berths.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_berths_readability_test (3 assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
