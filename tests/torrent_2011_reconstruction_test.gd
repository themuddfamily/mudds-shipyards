extends SceneTree

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")

const RECONSTRUCTION_AUDIT_METHOD := &"get_torrent_reconstruction_audit_report"
const SPEC_SPAN_LENGTH_MIN := 0.85
const SPEC_SPAN_LENGTH_MAX := 0.94
const SPEC_HEIGHT_LENGTH_MIN := 0.53
const SPEC_HEIGHT_LENGTH_MAX := 0.59
const SPEC_SIDE_EXTENSION_MIN := 0.19
const SPEC_SIDE_EXTENSION_MAX := 0.27
const SPEC_RAIL_PROTRUSION_MIN := 0.30
const SPEC_RAIL_PROTRUSION_MAX := 0.46
const REQUIRED_CONTRACT_NODES: Array[String] = [
	"visual_root",
	"pointed_nose",
	"raised_spine",
	"blocky_aft",
	"port_lower_side_plane",
	"port_upper_side_plane",
	"starboard_lower_side_plane",
	"starboard_upper_side_plane",
	"port_aft_housing",
	"starboard_aft_housing",
	"port_aft_rail",
	"starboard_aft_rail",
	"pilot_area",
	"pilot_seat",
	"forward_panel",
]

var _failures: Array[String] = []
var _test_root: Node3D
var _audit: Dictionary = {}
var _node_contract: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "Torrent2011ReconstructionTestRoot"
	root.add_child(_test_root)
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	_check(torrent != null, "Torrent scene instantiates as HeroShip")
	if torrent == null:
		_finish()
		return
	_test_root.add_child(torrent)
	await process_frame
	await physics_frame
	await physics_frame

	_test_evidence_boundary(torrent)
	_test_reconstruction_node_contract(torrent)
	_test_compact_longitudinal_silhouette(torrent)
	_test_stepped_side_planes(torrent)
	_test_aft_housings_and_rail_hierarchy(torrent)
	_test_central_pilot_area(torrent)
	_test_modern_system_labels(torrent)
	await _test_runtime_contracts(torrent)
	await _test_variant_seams()

	Input.action_release("move_forward")
	torrent.queue_free()
	await process_frame
	_test_root.queue_free()
	await process_frame
	_finish()


func _test_evidence_boundary(torrent: HeroShip) -> void:
	_check(
		torrent.has_method(RECONSTRUCTION_AUDIT_METHOD),
		"Torrent publishes the focused dated-reconstruction audit"
	)
	if torrent.has_method(RECONSTRUCTION_AUDIT_METHOD):
		var report: Variant = torrent.call(RECONSTRUCTION_AUDIT_METHOD)
		_check(report is Dictionary, "dated-reconstruction audit returns a Dictionary")
		if report is Dictionary:
			_audit = report as Dictionary

	_check(bool(_audit.get("valid", false)), "dated-reconstruction audit validates its own contract")
	_check(_audit.has("errors") and _string_array(_audit.get("errors", [])).is_empty(), "dated-reconstruction audit reports no construction errors")
	_check(int(_audit.get("schema_version", 0)) >= 3, "dated-reconstruction audit has the authored-macroform v3 schema")
	var authored_mesh := _audit.get("authored_mesh", {}) as Dictionary
	_check(bool(authored_mesh.get("valid", false)), "dated reconstruction delegates to a valid authored-macroform audit")
	_check(
		str(authored_mesh.get("asset_revision", "")) == "v2",
		"dated reconstruction identifies the bounded authored-geometry refinement revision"
	)
	_check(str(_audit.get("identity_lock", "")) == "dated_2011", "identity is source-locked specifically to the dated 2011 Torrent")
	_check(str(_audit.get("historical_revision", "")) == "2011", "audit does not silently generalise the observed craft to another revision")
	_check(str(_audit.get("reconstruction_status", "")) == "partial", "detailed reconstruction remains explicitly partial")
	_check(str(_audit.get("2009_continuity", "")) == "unproved", "continuity with the creator-listed 2009 Torrent remains unproved")
	_check(not bool(_audit.get("authenticated_geometry", true)), "partial reconstruction does not claim authenticated exact geometry")

	var source_refs := _string_array(_audit.get("source_references", PackedStringArray()))
	_check(_contains_tokens(source_refs, ["B5"]), "audit cites B5's decisive uncut name-to-model sequence")
	_check(_contains_tokens(source_refs, ["B6"]), "audit cites B6's independent dated corroboration")
	var safe_features := _string_array(_audit.get("safe_historical_features", PackedStringArray()))
	for requirement: Array in [
		["pointed", "nose"],
		["raised", "spine"],
		["blocky", "aft"],
		["stepped", "side", "plane"],
		["circular", "housing"],
		["upright", "rail"],
		["single", "pilot"],
		["red", "seat"],
		["yellow", "forward", "panel"],
	]:
		_check(
			_contains_tokens(safe_features, requirement),
			"source-safe feature inventory includes %s" % " ".join(requirement)
		)
	_check(
		not _contains_tokens(safe_features, ["crossbar"])
		and not _contains_tokens(safe_features, ["cross", "member"]),
		"source-safe inventory does not promote the optional reconstruction crossbar to a B5-observed feature"
	)

	_check(
		str(torrent.get_meta("identity_lock", "")) == "dated_2011"
		or bool(torrent.get_meta("torrent_2011_identity_locked", false)),
		"ship root mirrors the dated-2011 identity boundary"
	)
	_check(
		str(torrent.get_meta("reconstruction_status", "")) in ["partial", "source_aligned_partial"],
		"ship root mirrors partial reconstruction status"
	)
	_check(
		str(torrent.get_meta("2009_continuity", "")) == "unproved"
		or (torrent.has_meta("authenticated_2009_continuity") and not bool(torrent.get_meta("authenticated_2009_continuity"))),
		"ship root keeps 2009 continuity visibly unproved"
	)


func _test_reconstruction_node_contract(torrent: HeroShip) -> void:
	var contract_value: Variant = _audit.get("node_contract", {})
	_check(contract_value is Dictionary, "audit exposes semantic reconstruction node paths")
	if contract_value is Dictionary:
		_node_contract = contract_value as Dictionary
	for key: String in REQUIRED_CONTRACT_NODES:
		_check(_node_contract.has(key), "node contract declares %s" % key)
		var node := _contract_node(torrent, key)
		_check(node != null, "node contract path for %s resolves inside the Torrent" % key)

	var visual := _contract_node(torrent, "visual_root") as Node3D
	_check(visual != null and visual == torrent.get_variant_visual_root(), "contract visual root is the authoritative banked Torrent presentation")
	if visual != null:
		_check(str(visual.get_meta("identity_lock", "")) == "dated_2011" or bool(visual.get_meta("torrent_2011_identity_locked", false)), "visual root carries the dated-2011 source lock")
		_check(str(visual.get_meta("reconstruction_status", "")) in ["partial", "source_aligned_partial"], "visual root carries partial-reconstruction status")
		_check(
			not bool(visual.get_meta("authenticated_exact_geometry", false))
			and not bool(visual.get_meta("authenticated_historical_silhouette", false)),
			"visual root denies exact-geometry authentication"
		)


func _test_compact_longitudinal_silhouette(torrent: HeroShip) -> void:
	var visual := _contract_node(torrent, "visual_root") as Node3D
	if visual == null:
		return
	var measured := _subtree_mesh_bounds(visual, visual)
	var authored_macroform := _contract_node(torrent, "authored_macroform") as Node3D
	var authored_lod0 := (
		authored_macroform.get_node_or_null("Dated2011Form/MacroformLOD0") as Node3D
		if authored_macroform != null else null
	)
	var authored_measured := _subtree_mesh_bounds(authored_lod0, visual)
	_check(_usable_bounds(measured), "Torrent visual hierarchy has finite non-zero mesh bounds")
	_check(_usable_bounds(authored_measured), "checked-in authored macroform has finite non-zero mesh bounds")
	if not _usable_bounds(measured) or not _usable_bounds(authored_measured):
		return
	var authored_value: Variant = _audit.get("authored_bounds_m", null)
	_check(authored_value is Dictionary, "audit publishes authored metric bounds without claiming historical measurements")
	if authored_value is Dictionary:
		var authored := authored_value as Dictionary
		var authored_length := float(authored.get("length", -1.0))
		var authored_width := float(authored.get("width", -1.0))
		var authored_height := float(authored.get("total_height", -1.0))
		_check(
			_float_close(authored_length, authored_measured.size.z, 0.01)
			and _float_close(authored_width, authored_measured.size.x, 0.01)
			and _float_close(authored_height, authored_measured.size.y, 0.01),
			"authored metric bounds track the imported macroform within one percent"
		)
		var body_height := float(authored.get("body_height", -1.0))
		_check(body_height > 0.0 and body_height < authored_height, "audit separates compact body height from dominant aft-rail height")
		var authored_span_length_ratio := authored_width / authored_length if authored_length > 0.0 else -1.0
		var authored_height_length_ratio := authored_height / authored_length if authored_length > 0.0 else -1.0
		_check(
			authored_span_length_ratio >= SPEC_SPAN_LENGTH_MIN
			and authored_span_length_ratio <= SPEC_SPAN_LENGTH_MAX,
			"audited authored span-to-length ratio stays inside the canonical 0.85-0.94 band"
		)
		_check(
			authored_height_length_ratio >= SPEC_HEIGHT_LENGTH_MIN
			and authored_height_length_ratio <= SPEC_HEIGHT_LENGTH_MAX,
			"audited authored height-to-length ratio stays inside the canonical 0.53-0.59 band"
		)
	var measured_ratio := authored_measured.size.x / authored_measured.size.z
	var measured_height_ratio := authored_measured.size.y / authored_measured.size.z
	var reported_ratio := float(_audit.get("width_to_length_ratio", -1.0))
	var authored_ratio := -1.0
	if authored_value is Dictionary:
		var authored := authored_value as Dictionary
		var authored_length := float(authored.get("length", -1.0))
		if authored_length > 0.0:
			authored_ratio = float(authored.get("width", -1.0)) / authored_length
	_check(
		is_finite(reported_ratio)
		and reported_ratio >= SPEC_SPAN_LENGTH_MIN
		and reported_ratio <= SPEC_SPAN_LENGTH_MAX
		and absf(reported_ratio - authored_ratio) <= 0.001
		and absf(reported_ratio - measured_ratio) <= 0.005,
		"audit width-to-length ratio is canonical and closely derived from authored and live geometry"
	)
	_check(authored_measured.size.z > authored_measured.size.x, "authored Torrent macroform is longitudinal-dominant rather than a wide arrowhead")
	_check(
		measured_ratio >= SPEC_SPAN_LENGTH_MIN and measured_ratio <= SPEC_SPAN_LENGTH_MAX,
		"live compact wedge span-to-length ratio stays inside the canonical 0.85-0.94 band"
	)
	_check(
		measured_height_ratio >= SPEC_HEIGHT_LENGTH_MIN and measured_height_ratio <= SPEC_HEIGHT_LENGTH_MAX,
		"live flight-silhouette height-to-length ratio stays inside the canonical 0.53-0.59 band"
	)

	var nose := _contract_node(torrent, "pointed_nose") as Node3D
	var spine := _contract_node(torrent, "raised_spine") as Node3D
	var aft := _contract_node(torrent, "blocky_aft") as Node3D
	var nose_bounds := _subtree_mesh_bounds(nose, visual)
	var spine_bounds := _subtree_mesh_bounds(spine, visual)
	var aft_bounds := _subtree_mesh_bounds(aft, visual)
	_check(_usable_bounds(nose_bounds) and str(nose.get_meta("silhouette_role", "")) == "pointed_nose" if nose != null else false, "pointed nose is physical geometry with a semantic silhouette role")
	_check(_usable_bounds(spine_bounds) and str(spine.get_meta("silhouette_role", "")) == "raised_spine" if spine != null else false, "raised spine is physical geometry with a semantic silhouette role")
	_check(_usable_bounds(aft_bounds) and str(aft.get_meta("silhouette_role", "")) == "blocky_aft" if aft != null else false, "blocky aft is physical geometry with a semantic silhouette role")
	if _usable_bounds(nose_bounds) and _usable_bounds(aft_bounds):
		_check(nose_bounds.position.z <= measured.position.z + measured.size.z * 0.08, "pointed nose reaches the forward end of the craft")
		_check(_subtree_tapers_forward(nose, visual), "nose geometry narrows materially toward its forward tip")
		_check(_aabb_center(nose_bounds).z < _aabb_center(aft_bounds).z, "pointed nose remains forward of the aft body")
	if _usable_bounds(spine_bounds):
		_check(absf(_aabb_center(spine_bounds).x) <= measured.size.x * 0.08, "raised spine remains central")
		_check(spine_bounds.end.y >= measured.end.y - measured.size.y * 0.12, "raised spine participates in the dominant upper silhouette")
	if _usable_bounds(aft_bounds):
		_check(_aabb_center(aft_bounds).z > _aabb_center(measured).z, "blocky body occupies the aft half")
		_check(aft_bounds.size.x > authored_measured.size.x * 0.24 and aft_bounds.size.y > authored_measured.size.y * 0.30, "aft body is a substantial volume rather than a thin tail plate")


func _test_stepped_side_planes(torrent: HeroShip) -> void:
	var visual := _contract_node(torrent, "visual_root") as Node3D
	if visual == null:
		return
	var nodes := {
		"port_lower": _contract_node(torrent, "port_lower_side_plane") as Node3D,
		"port_upper": _contract_node(torrent, "port_upper_side_plane") as Node3D,
		"starboard_lower": _contract_node(torrent, "starboard_lower_side_plane") as Node3D,
		"starboard_upper": _contract_node(torrent, "starboard_upper_side_plane") as Node3D,
	}
	for key: String in nodes:
		var plane := nodes[key] as Node3D
		var bounds := _subtree_mesh_bounds(plane, visual)
		_check(_usable_bounds(bounds), "%s side-plane tier has physical mesh bounds" % key)
		if plane != null:
			_check(str(plane.get_meta("silhouette_role", "")) == "stepped_side_plane", "%s is semantically tagged as stepped side-plane geometry" % key)
			_check(bool(plane.get_meta("stepped_edge", false)), "%s records its observed stepped edge" % key)
			_check(str(plane.get_meta("side", "")) == ("port" if key.begins_with("port") else "starboard"), "%s records the correct paired side" % key)
			_check(str(plane.get_meta("tier", "")) == ("lower" if key.ends_with("lower") else "upper"), "%s records the correct two-tier role" % key)
		if _usable_bounds(bounds):
			_check(bounds.size.x > bounds.size.y * 2.0 and bounds.size.z > bounds.size.y * 2.0, "%s reads as a broad plane rather than a vertical fin" % key)
			_check(_aabb_center(bounds).x < 0.0 if key.begins_with("port") else _aabb_center(bounds).x > 0.0, "%s remains on its declared side" % key)

	var port_lower := _subtree_mesh_bounds(nodes.port_lower as Node3D, visual)
	var port_upper := _subtree_mesh_bounds(nodes.port_upper as Node3D, visual)
	var starboard_lower := _subtree_mesh_bounds(nodes.starboard_lower as Node3D, visual)
	var starboard_upper := _subtree_mesh_bounds(nodes.starboard_upper as Node3D, visual)
	var overall := _subtree_mesh_bounds(visual, visual)
	var aft := _subtree_mesh_bounds(_contract_node(torrent, "blocky_aft") as Node3D, visual)
	_check(_aabb_size_close(port_lower, starboard_lower, 0.28), "lower side planes remain a readable pair without claiming exact symmetry")
	_check(_aabb_size_close(port_upper, starboard_upper, 0.32), "upper side-plane tiers remain paired without claiming exact symmetry")
	if _usable_bounds(port_lower) and _usable_bounds(port_upper):
		_check(not _aabb_size_close(port_lower, port_upper, 0.08) or _aabb_center(port_lower).distance_to(_aabb_center(port_upper)) > 0.15, "port lower and upper tiers are distinct geometry rather than duplicate labels")
	if _usable_bounds(starboard_lower) and _usable_bounds(starboard_upper):
		_check(not _aabb_size_close(starboard_lower, starboard_upper, 0.08) or _aabb_center(starboard_lower).distance_to(_aabb_center(starboard_upper)) > 0.15, "starboard lower and upper tiers are distinct geometry rather than duplicate labels")
	if _usable_bounds(overall) and _usable_bounds(aft):
		for plane_data: Array in [[port_upper, "port"], [starboard_upper, "starboard"]]:
			var bounds := plane_data[0] as AABB
			var side_name := str(plane_data[1])
			if not _usable_bounds(bounds):
				continue
			var outboard_edge := -bounds.position.x if side_name == "port" else bounds.end.x
			var extension_ratio := (outboard_edge - aft.size.x * 0.5) / overall.size.x
			_check(
				extension_ratio >= SPEC_SIDE_EXTENSION_MIN
				and extension_ratio <= SPEC_SIDE_EXTENSION_MAX,
				"%s upper side-plane extension stays inside the canonical 0.19-0.27 span band" % side_name
			)


func _test_aft_housings_and_rail_hierarchy(torrent: HeroShip) -> void:
	var visual := _contract_node(torrent, "visual_root") as Node3D
	if visual == null:
		return
	var port_housing := _contract_node(torrent, "port_aft_housing") as Node3D
	var starboard_housing := _contract_node(torrent, "starboard_aft_housing") as Node3D
	var housing_bounds: Array[AABB] = [
		_subtree_mesh_bounds(port_housing, visual),
		_subtree_mesh_bounds(starboard_housing, visual),
	]
	for index in 2:
		var housing := port_housing if index == 0 else starboard_housing
		var side_name := "port" if index == 0 else "starboard"
		_check(housing != null and _subtree_has_circular_form(housing), "%s aft housing contains explicit circular/cylindrical geometry" % side_name)
		if housing != null:
			_check(str(housing.get_meta("historical_function", "")) == "unknown" or bool(housing.get_meta("historical_function_unresolved", false)), "%s circular housing keeps its historical function unknown" % side_name)
			_check(str(housing.get_meta("modern_interpretation", "")) == "engine", "%s circular housing labels engine use as a modern interpretation" % side_name)
			_check(str(housing.get_meta("interpretation_status", "")) == "modern", "%s engine interpretation cannot masquerade as recovered function" % side_name)
		if _usable_bounds(housing_bounds[index]):
			var radial_ratio := housing_bounds[index].size.x / housing_bounds[index].size.y
			_check(radial_ratio >= 0.58 and radial_ratio <= 1.72, "%s housing keeps a recognisably round transverse envelope" % side_name)
			_check(_aabb_center(housing_bounds[index]).x < 0.0 if index == 0 else _aabb_center(housing_bounds[index]).x > 0.0, "%s circular housing remains beside the aft body" % side_name)
	_check(_aabb_size_close(housing_bounds[0], housing_bounds[1], 0.28), "aft circular housings remain a readable pair")

	var port_rail := _contract_node(torrent, "port_aft_rail") as Node3D
	var starboard_rail := _contract_node(torrent, "starboard_aft_rail") as Node3D
	var crossbar := _contract_node(torrent, "aft_crossbar") as Node3D
	var port_bounds := _subtree_mesh_bounds(port_rail, visual)
	var starboard_bounds := _subtree_mesh_bounds(starboard_rail, visual)
	var authored_root := _contract_node(torrent, "authored_macroform") as Node3D
	var overall_bounds := _subtree_mesh_bounds(authored_root, visual)
	var aft_bounds := _subtree_mesh_bounds(_contract_node(torrent, "blocky_aft") as Node3D, visual)
	for rail_data: Array in [[port_rail, port_bounds, "port"], [starboard_rail, starboard_bounds, "starboard"]]:
		var rail := rail_data[0] as Node3D
		var bounds := rail_data[1] as AABB
		var side_name := str(rail_data[2])
		_check(_usable_bounds(bounds), "%s aft rail has physical bounds" % side_name)
		if rail != null:
			_check(str(rail.get_meta("silhouette_role", "")) == "upright_aft_rail", "%s aft rail publishes its source-safe silhouette role" % side_name)
		if _usable_bounds(bounds):
			_check(bounds.size.y > bounds.size.x * 1.8 and bounds.size.y > bounds.size.z * 0.72, "%s aft rail is visually upright" % side_name)
			if _usable_bounds(overall_bounds) and _usable_bounds(aft_bounds):
				var protrusion_ratio := (bounds.end.y - aft_bounds.end.y) / overall_bounds.size.y
				_check(
					protrusion_ratio >= SPEC_RAIL_PROTRUSION_MIN
					and protrusion_ratio <= SPEC_RAIL_PROTRUSION_MAX,
					"%s aft rail protrusion stays inside the canonical 0.30-0.46 height band" % side_name
				)
	if crossbar != null:
		var crossbar_bounds := _subtree_mesh_bounds(crossbar, visual)
		var crossbar_source_reference := str(crossbar.get_meta("source_reference", "")).to_upper()
		_check(
			"B5" not in crossbar_source_reference,
			"optional reconstruction crossbar is not tagged as a direct B5 observation"
		)
		_check(
			crossbar.has_meta("historically_supported")
			and not bool(crossbar.get_meta("historically_supported")),
			"optional reconstruction crossbar explicitly rejects historical support"
		)
		_check(
			not _usable_bounds(crossbar_bounds) or str(crossbar.get_meta("silhouette_role", "")) == "aft_crossbar",
			"optional physical crossbar retains a semantic reconstruction role when present"
		)
	if _usable_bounds(port_bounds) and _usable_bounds(starboard_bounds):
		var separation := absf(_aabb_center(starboard_bounds).x - _aabb_center(port_bounds).x)
		_check(_aabb_center(port_bounds).x < 0.0 and _aabb_center(starboard_bounds).x > 0.0, "dominant upright rails form a port/starboard pair")
		_check(separation > 0.1, "dominant upright rails remain visibly separated")


func _test_central_pilot_area(torrent: HeroShip) -> void:
	var visual := _contract_node(torrent, "visual_root") as Node3D
	var pilot_area := _contract_node(torrent, "pilot_area") as Node3D
	var pilot_seat := _contract_node(torrent, "pilot_seat") as Node3D
	var forward_panel := _contract_node(torrent, "forward_panel") as Node3D
	if visual == null:
		return
	_check(int(_audit.get("pilot_area_count", 0)) == 1, "audit exposes exactly one central pilot area")
	_check(pilot_area != null and int(pilot_area.get_meta("pilot_capacity", 0)) == 1, "physical pilot area is explicitly single-seat")
	_check(pilot_area != null and str(pilot_area.get_meta("historical_access", "")) == "physical_central", "pilot area records B5's physical central access evidence")
	var area_bounds := _subtree_mesh_bounds(pilot_area, visual)
	var seat_bounds := _subtree_mesh_bounds(pilot_seat, visual)
	var panel_bounds := _subtree_mesh_bounds(forward_panel, visual)
	_check(_usable_bounds(area_bounds) and absf(_aabb_center(area_bounds).x) <= _subtree_mesh_bounds(visual, visual).size.x * 0.08, "single pilot area remains central")
	_check(pilot_seat != null and pilot_seat.is_visible_in_tree(), "pilot seat is present and visible")
	_check(pilot_seat != null and _subtree_has_material_colour(pilot_seat, _is_visible_red), "pilot seat has a directly visible red material")
	_check(pilot_seat != null and bool(pilot_seat.get_meta("historically_observed_colour", false)), "red seat colour is labelled as historically observed")
	_check(forward_panel != null and forward_panel.is_visible_in_tree(), "forward panel is present and visible")
	_check(forward_panel != null and _subtree_has_material_colour(forward_panel, _is_pale_yellow_translucent), "forward panel is pale yellow and translucent in material data")
	_check(forward_panel != null and (str(forward_panel.get_meta("historical_function", "")) == "unknown" or bool(forward_panel.get_meta("historical_function_unresolved", false))), "forward panel does not overclaim a proven canopy/glazing function")
	if _usable_bounds(seat_bounds) and _usable_bounds(panel_bounds):
		_check(absf(_aabb_center(seat_bounds).x) <= 0.35 and absf(_aabb_center(panel_bounds).x) <= 0.45, "seat and forward panel share the central pilot axis")
		_check(_aabb_center(panel_bounds).z < _aabb_center(seat_bounds).z, "translucent panel remains forward of the red pilot seat")
	var seat_anchor := torrent.get_pilot_seat_anchor()
	_check(seat_anchor != null and pilot_area != null and pilot_area.is_ancestor_of(seat_anchor), "functional pilot anchor belongs to the single physical pilot area")
	if seat_anchor != null and _usable_bounds(seat_bounds):
		_check(seat_bounds.grow(0.9).has_point(visual.to_local(seat_anchor.global_position)), "functional pilot anchor remains aligned with the visible red seat")


func _test_modern_system_labels(torrent: HeroShip) -> void:
	var modern := _string_array(_audit.get("modern_interpretations", PackedStringArray()))
	for requirement: Array in [
		["engine"],
		["exhaust"],
		["weapon"],
		["landing", "gear"],
		["canopy"],
		["cockpit", "control"],
		["flight", "handling"],
	]:
		_check(_contains_tokens(modern, requirement), "modern-interpretation inventory labels %s" % " ".join(requirement))
	var visual := _contract_node(torrent, "visual_root") as Node3D
	if visual == null:
		return
	var unsupported_patterns := PackedStringArray([
		"*EnginePlume*", "*Nozzle*", "*PulseCannon*", "*GunRail*",
		"*GearAssembly*", "*RCSCluster*", "VentralDockingReceiver", "CanopyHinge",
		"InstrumentCluster", "*Display*", "*Console*", "ControlStick*",
		"Throttle*", "*RudderPedal", "*Belt*", "Harness*",
		"*CanopyLatchStriker", "CanopyHingeBar", "*CanopyHingeMount",
	])
	var unsupported_nodes: Array[Node] = []
	for pattern: String in unsupported_patterns:
		var candidates := visual.find_children(pattern, "", true, false)
		_check(not candidates.is_empty(), "implemented modern-system pattern %s resolves to physical nodes" % pattern)
		for candidate: Node in candidates:
			if not unsupported_nodes.has(candidate):
				unsupported_nodes.append(candidate)
	_check(not unsupported_nodes.is_empty(), "implemented modern systems remain discoverable for evidence auditing")
	for node: Node in unsupported_nodes:
		_check(_is_explicitly_modern(node), "%s is explicitly tagged presentation-only or modern" % node.name)


func _test_runtime_contracts(torrent: HeroShip) -> void:
	_check(torrent.collision_layer == PhysicsLayers.SHIP_BODY_LAYER, "reconstructed Torrent retains canonical ship collision layer")
	_check(torrent.collision_mask == PhysicsLayers.SHIP_BODY_MASK, "reconstructed Torrent retains canonical ship collision mask")
	var collisions: Array[CollisionShape3D] = []
	for child: Node in torrent.get_children():
		if child is CollisionShape3D:
			collisions.append(child as CollisionShape3D)
	_check(collisions.size() == 7, "reconstruction uses the exact bounded seven-shape hull, propulsion, and parked-gear collision contract")
	for collision: CollisionShape3D in collisions:
		_check(collision.shape != null and not collision.disabled and collision.position.is_finite(), "%s remains an enabled finite collision shape" % collision.name)

	var boarding_area := torrent.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	var seat_anchor := torrent.get_pilot_seat_anchor()
	var entry := torrent.get_boarding_entry_transform()
	var boarding_position := torrent.get_boarding_position()
	var exit := torrent.get_exit_transform()
	_check(boarding_area != null and boarding_area.get_ship() == torrent and boarding_area.is_available(), "physical boarding area resolves the reconstructed Torrent")
	_check(boarding_position.is_finite() and entry.origin.is_finite() and exit.origin.is_finite(), "boarding, entry, and exit markers remain finite")
	_check(boarding_area != null and boarding_position.distance_to(boarding_area.global_position - Vector3.UP * 0.5) < 0.8, "boarding marker remains aligned with the interaction volume")
	_check(seat_anchor != null and entry.origin.distance_to(seat_anchor.global_position) < 3.5, "physical boarding entry remains a short transition to the central seat")
	_check(exit.origin.distance_to(torrent.global_position) > 3.0, "exit marker clears the compact collision envelope")
	var left_muzzle := torrent.get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := torrent.get_node_or_null("RightMuzzle") as Marker3D
	_check(left_muzzle != null and right_muzzle != null and left_muzzle.position.x < 0.0 and right_muzzle.position.x > 0.0, "paired weapon markers remain coherent even though weapon geometry is modern")
	_check(left_muzzle != null and right_muzzle != null and absf(left_muzzle.position.z - right_muzzle.position.z) < 0.2, "paired weapon markers share a forward firing line")

	var chase := torrent.get_camera()
	_check(chase != null and chase.name == &"ShipCamera", "reconstructed Torrent retains its collision-safe chase camera")
	torrent.set_piloted(true)
	_check(chase != null and chase.current, "piloting activates chase view")
	torrent.set_cockpit_view(true)
	var cockpit_camera := torrent.get_camera()
	_check(cockpit_camera != null and cockpit_camera.name == &"CockpitCamera" and cockpit_camera.current, "cockpit view remains attached to the physical pilot area")
	_check(cockpit_camera != null and _contract_node(torrent, "pilot_area").is_ancestor_of(cockpit_camera) if _contract_node(torrent, "pilot_area") != null else false, "cockpit camera is owned by the central pilot hierarchy")
	torrent.set_cockpit_view(false)

	var starting_position := torrent.global_position
	var original_start_time := torrent.engine_start_time
	torrent.engine_start_time = 0.03
	torrent.request_engine_start()
	for _index in 7:
		await physics_frame
	var telemetry := torrent.get_telemetry()
	_check(str(telemetry.get("engine_state", "")) == "ONLINE", "reconstructed Torrent completes the inherited engine-start lifecycle")
	_check(str(telemetry.get("role", "")) == "Interceptor", "flight telemetry retains the creator-supported Interceptor role")
	Input.action_press("move_forward")
	for _index in 8:
		await physics_frame
	Input.action_release("move_forward")
	_check(torrent.velocity.is_finite() and torrent.velocity.length() > 0.05, "reconstructed geometry leaves inherited arcade thrust operational")
	_check(torrent.global_position.distance_to(starting_position) > 0.001, "reconstructed Torrent can depart under the real flight input path")
	torrent.request_engine_stop()
	torrent.set_piloted(false)
	torrent.engine_start_time = original_start_time
	_check(torrent.is_boardable(), "engine shutdown restores the same physical boarding contract")


func _test_variant_seams() -> void:
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_check(arrow != null, "Arrow variant still instantiates after the Torrent reconstruction")
	_check(jovian != null, "Jovian variant still instantiates after the Torrent reconstruction")
	if arrow == null or jovian == null:
		if arrow != null:
			arrow.queue_free()
		if jovian != null:
			jovian.queue_free()
		await process_frame
		return
	_test_root.add_child(arrow)
	_test_root.add_child(jovian)
	await process_frame
	await physics_frame
	_check(arrow.get_arrow_visual_root() != null and arrow.get_node_or_null("TorrentVisual") == null, "Arrow still replaces the Torrent visual hierarchy")
	_check(jovian.get_jovian_visual_root() != null and jovian.get_node_or_null("TorrentVisual") == null, "Jovian still replaces the Torrent visual hierarchy")
	_check(arrow.get_pilot_seat_anchor() != null and arrow.get_camera() != null, "Arrow retains inherited pilot and camera seams")
	_check(jovian.get_pilot_seat_anchor() != null and jovian.get_camera() != null, "Jovian retains inherited pilot and camera seams")
	_check(arrow.collision_layer == PhysicsLayers.SHIP_BODY_LAYER and jovian.collision_layer == PhysicsLayers.SHIP_BODY_LAYER, "both variants retain canonical physical ship collision")
	arrow.queue_free()
	jovian.queue_free()
	await process_frame


func _contract_node(torrent: HeroShip, key: String) -> Node:
	if not _node_contract.has(key):
		return null
	var value: Variant = _node_contract[key]
	if value is Node:
		var direct := value as Node
		return direct if direct == torrent or torrent.is_ancestor_of(direct) else null
	if value is NodePath or value is String or value is StringName:
		var path := NodePath(str(value))
		if path.is_empty():
			return null
		return torrent.get_node_or_null(path)
	return null


func _subtree_mesh_bounds(node: Node3D, reference: Node3D) -> AABB:
	if node == null or reference == null or not node.is_inside_tree() or not reference.is_inside_tree():
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	var bounds := AABB()
	var has_point := false
	var world_to_reference := reference.global_transform.affine_inverse()
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var local_bounds := mesh_instance.get_aabb()
		var local_to_reference := world_to_reference * mesh_instance.global_transform
		for corner_index in 8:
			var corner := local_bounds.position + Vector3(
				local_bounds.size.x if corner_index & 1 else 0.0,
				local_bounds.size.y if corner_index & 2 else 0.0,
				local_bounds.size.z if corner_index & 4 else 0.0
			)
			var point := local_to_reference * corner
			if not has_point:
				bounds = AABB(point, Vector3.ZERO)
				has_point = true
			else:
				bounds = bounds.expand(point)
	return bounds if has_point else AABB()


func _subtree_has_circular_form(node: Node) -> bool:
	if node == null:
		return false
	if bool(node.get_meta("circular_form", false)):
		return true
	var meshes: Array[Node] = []
	if node is MeshInstance3D:
		meshes.append(node)
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for candidate: Node in meshes:
		var mesh := (candidate as MeshInstance3D).mesh
		if mesh is CylinderMesh or mesh is TorusMesh:
			return true
		if bool(candidate.get_meta("circular_form", false)):
			return true
	return false


func _subtree_tapers_forward(node: Node3D, reference: Node3D) -> bool:
	if node == null or reference == null or not node.is_inside_tree() or not reference.is_inside_tree():
		return false
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	var points := PackedVector3Array()
	var world_to_reference := reference.global_transform.affine_inverse()
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var local_to_reference := world_to_reference * mesh_instance.global_transform
		for vertex: Vector3 in mesh_instance.mesh.get_faces():
			points.append(local_to_reference * vertex)
	if points.size() < 6:
		return false
	var minimum_z := INF
	var maximum_z := -INF
	for point: Vector3 in points:
		minimum_z = minf(minimum_z, point.z)
		maximum_z = maxf(maximum_z, point.z)
	var length := maximum_z - minimum_z
	if not is_finite(length) or length <= 0.01:
		return false
	var front_min_x := INF
	var front_max_x := -INF
	var rear_min_x := INF
	var rear_max_x := -INF
	for point: Vector3 in points:
		if point.z <= minimum_z + length * 0.28:
			front_min_x = minf(front_min_x, point.x)
			front_max_x = maxf(front_max_x, point.x)
		if point.z >= maximum_z - length * 0.28:
			rear_min_x = minf(rear_min_x, point.x)
			rear_max_x = maxf(rear_max_x, point.x)
	var front_width := front_max_x - front_min_x
	var rear_width := rear_max_x - rear_min_x
	return is_finite(front_width) and is_finite(rear_width) and rear_width > 0.05 and front_width <= rear_width * 0.72


func _subtree_has_material_colour(node: Node, predicate: Callable) -> bool:
	if node == null or not predicate.is_valid():
		return false
	var meshes: Array[Node] = []
	if node is MeshInstance3D:
		meshes.append(node)
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for candidate: Node in meshes:
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.material_override is StandardMaterial3D:
			if bool(predicate.call((mesh_instance.material_override as StandardMaterial3D).albedo_color)):
				return true
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index)
			if material is StandardMaterial3D and bool(predicate.call((material as StandardMaterial3D).albedo_color)):
				return true
	return false


func _is_visible_red(colour: Color) -> bool:
	return colour.a >= 0.75 and colour.r >= 0.48 and colour.r > colour.g * 1.35 and colour.r > colour.b * 1.25


func _is_pale_yellow_translucent(colour: Color) -> bool:
	return (
		colour.a >= 0.08 and colour.a <= 0.88
		and colour.r >= 0.65 and colour.g >= 0.56
		and colour.b >= 0.24
		and colour.r > colour.b * 1.12 and colour.g > colour.b * 1.08
	)


func _is_explicitly_modern(node: Node) -> bool:
	if node == null:
		return false
	var cursor: Node = node
	while cursor != null:
		var evidence_status := str(cursor.get_meta("evidence_status", ""))
		var design_origin := str(cursor.get_meta("design_origin", ""))
		var interpretation_status := str(cursor.get_meta("interpretation_status", ""))
		if (
			evidence_status in ["modern", "modern_interpretation", "presentation_only"]
			or design_origin in ["modern", "modern_interpretation"]
			or interpretation_status == "modern"
			or bool(cursor.get_meta("presentation_only", false))
			or bool(cursor.get_meta("articulated_visual_only", false))
			or (cursor.has_meta("historically_supported") and not bool(cursor.get_meta("historically_supported")))
		):
			return true
		cursor = cursor.get_parent()
	return false


func _string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value as PackedStringArray
	var result := PackedStringArray()
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result


func _contains_tokens(values: PackedStringArray, tokens: Array) -> bool:
	for value: String in values:
		var normalised := value.to_lower().replace("_", " ").replace("-", " ")
		var matches := true
		for token: String in tokens:
			if token.to_lower() not in normalised:
				matches = false
				break
		if matches:
			return true
	return false


func _usable_bounds(bounds: AABB) -> bool:
	return (
		bounds.position.is_finite() and bounds.size.is_finite()
		and bounds.size.x > 0.001 and bounds.size.y > 0.001 and bounds.size.z > 0.001
	)


func _aabb_center(bounds: AABB) -> Vector3:
	return bounds.position + bounds.size * 0.5


func _aabb_size_close(first: AABB, second: AABB, tolerance: float) -> bool:
	if not _usable_bounds(first) or not _usable_bounds(second):
		return false
	for axis in 3:
		var scale := maxf(first.size[axis], second.size[axis])
		if absf(first.size[axis] - second.size[axis]) > maxf(0.01, scale * tolerance):
			return false
	return true


func _float_close(first: float, second: float, relative_tolerance: float) -> bool:
	if not is_finite(first) or not is_finite(second):
		return false
	return absf(first - second) <= maxf(0.01, maxf(absf(first), absf(second)) * relative_tolerance)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TORRENT_2011_RECONSTRUCTION_TEST_OK")
		quit(0)
	else:
		print("TORRENT_2011_RECONSTRUCTION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
