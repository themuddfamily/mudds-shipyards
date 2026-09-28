class_name StationWayfindingSignage
extends Node3D

## Phase 10 §3 art-direction pass: one coherent station wayfinding layer.
##
## Every sign is placed from the live `StationRouteRegistry` report the world
## publishes, never from hand-authored coordinates, so a retuned route marker or a
## moved hub endpoint carries its signs with it:
##
## * one **station directory** in front of the player spawn names every
##   registered module (and the Aft VIP landmark) with an arrow toward that
##   module's hub endpoint;
## * one **threshold panel** per registry edge stands between the hub anchor and
##   the module's connection-slot marker, facing the player arriving from the hub,
##   naming the module and its nearest landmarks, and pointing back to the hub on
##   its reverse face;
## * one **junction panel** at each listed internal route marker, facing the
##   travel direction from the module's entry, lists the module landmarks still
##   ahead of the player.
##
## Visual language (one sign family): a dark high-contrast plate, pale
## engineering lettering from the project's own font-free alphabet, a per-family
## silhouette icon (ring, disc, square, triangle, diamond, chevron, plus, hexagon,
## pentagon) and an arrow. The accent colour repeats the icon but is never the
## only cue: every destination carries shape + text + arrow.
##
## Cost: every row is two textured quads (arrow + label), every panel adds one
## backing quad and one post quad. Everything is one `ArrayMesh`, one
## `MeshInstance3D`, one material sampling one pre-generated atlas
## (`assets/signage/station_wayfinding_atlas.svg`, produced deterministically by
## `tools/signage/generate_station_wayfinding_atlas.py` from `SIGN_LABELS`).
## No `TextMesh`, no `Label3D`, no lights, no collision, no processing and no
## animation, so reduced-flash settings have nothing to suppress.
##
## Placement never lands inside station collision: each candidate panel and post
## volume (plus a walk clearance, and a wider swing allowance around doors and
## moving bodies) is tested against every solid collision shape in the world as
## oriented boxes; a candidate also needs a real floor under its post. Sites with
## no clear candidate are skipped and reported in `get_wayfinding_report()`.
##
## Everything here is `modern_interpretation`: a readability layer for the
## remake, not a recovered original sign scheme.

const ATLAS_TEXTURE_PATH := "res://assets/signage/station_wayfinding_atlas.svg"

## Atlas geometry. Must match `tools/signage/generate_station_wayfinding_atlas.py`.
const ATLAS_SIZE := Vector2(1024.0, 1024.0)
const ATLAS_COLUMNS := 2
const ATLAS_CELL := Vector2(512.0, 64.0)
const ARROW_CELL_INDEX := 30
const BLANK_CELL_INDEX := 31

## Label table: `[key, text, icon shape, accent]`. The row index is the atlas
## cell index. The generator parses exactly these lines, so this is the single
## source of truth for what the atlas says.
const SIGN_LABELS: Array = [
	[&"station_hub", "STATION HUB", &"ring", "#f2f5f3"],
	[&"aft_operations", "AFT OPERATIONS", &"triangle", "#e69f00"],
	[&"fleet_docks", "FLEET DOCKS", &"disc", "#56b4e9"],
	[&"habitat", "HABITAT", &"square", "#009e73"],
	[&"freight_berth", "FREIGHT BERTH", &"chevron", "#f0e442"],
	[&"fabrication", "FABRICATION", &"plus", "#d55e00"],
	[&"observation_spur", "OBSERVATION SPUR", &"hexagon", "#56b4e9"],
	[&"salvage_terrace", "SALVAGE TERRACE", &"pentagon", "#cc79a7"],
	[&"vip_reception", "VIP RECEPTION", &"diamond", "#d55e00"],
	[&"activity_board", "ACTIVITY BOARD", &"triangle", "#e69f00"],
	[&"destination_board", "DESTINATION BOARD", &"triangle", "#e69f00"],
	[&"upper_deck", "UPPER DECK", &"triangle", "#e69f00"],
	[&"dock_01", "DOCK 01 ZENITH", &"disc", "#56b4e9"],
	[&"dock_02", "DOCK 02 HALYARD", &"disc", "#56b4e9"],
	[&"dock_03", "DOCK 03 BULWARK", &"disc", "#56b4e9"],
	[&"dock_04", "DOCK 04 CARGO", &"disc", "#56b4e9"],
	[&"dock_05", "DOCK 05 BOMBER", &"disc", "#56b4e9"],
	[&"dock_06", "DOCK 06 INTERCEPTOR", &"disc", "#56b4e9"],
	[&"observation_deck", "OBSERVATION DECK", &"square", "#009e73"],
	[&"garden_cupola", "GARDEN CUPOLA", &"square", "#009e73"],
	[&"cargo_rack", "CARGO RACK", &"chevron", "#f0e442"],
	[&"freight_service", "FREIGHT SERVICE", &"chevron", "#f0e442"],
	[&"freight_boarding", "FREIGHT BOARDING", &"chevron", "#f0e442"],
	[&"observation_pad", "OBSERVATION PAD", &"hexagon", "#56b4e9"],
	[&"logistics_pad", "LOGISTICS PAD", &"hexagon", "#56b4e9"],
	[&"upper_terrace", "UPPER TERRACE", &"pentagon", "#cc79a7"],
	[&"inspection_pad", "INSPECTION PAD", &"pentagon", "#cc79a7"],
	[&"lower_pad", "LOWER PAD", &"pentagon", "#cc79a7"],
	[&"central_berth", "CENTRAL BERTH", &"disc", "#56b4e9"],
]

## Registry module id -> title label.
const MODULE_TITLES := {
	&"aft-junction-stack": &"aft_operations",
	&"fleet-dock-comb": &"fleet_docks",
	&"habitat-spine": &"habitat",
	&"jovian-freight-berth": &"freight_berth",
	&"fabrication_annex": &"fabrication",
	&"observation-logistics-spur": &"observation_spur",
	&"salvage-terrace": &"salvage_terrace",
}

## Registry module id -> `[label, route marker id]` landmarks inside it.
## A missing marker is skipped and reported, never guessed.
const MODULE_LANDMARKS := {
	&"aft-junction-stack": [
		[&"activity_board", &"operations-room"],
		[&"destination_board", &"operations-room"],
		[&"vip_reception", &"vip-landmark"],
		[&"upper_deck", &"stair-top"],
	],
	&"fleet-dock-comb": [
		[&"dock_01", &"dock-01-threshold"],
		[&"dock_02", &"dock-02-threshold"],
		[&"dock_03", &"dock-03-threshold"],
	],
	&"habitat-spine": [
		[&"observation_deck", &"observation"],
		# Despite its historic marker name, this now enters the built, unlocked room.
		[&"garden_cupola", &"deferred-branch"],
	],
	&"jovian-freight-berth": [
		[&"freight_boarding", &"boarding-staging"],
		[&"cargo_rack", &"cargo-rack"],
		[&"freight_service", &"service-room"],
	],
	# The south service gate is an unfinished endpoint, not a destination.
	&"fabrication_annex": [],
	&"observation-logistics-spur": [
		[&"observation_pad", &"observation-pad"],
		[&"logistics_pad", &"logistics-pad"],
	],
	&"salvage-terrace": [
		[&"lower_pad", &"lower-pad"],
		[&"upper_terrace", &"upper-pad"],
		[&"inspection_pad", &"inspection-pad"],
	],
}

## World berths (owned by `ShipyardWorld`, not modules) listed as destinations.
## Each attaches to the registered module owning the route marker nearest the
## berth, so the berth is signed from wherever that module is signed.
const BERTH_LANDMARKS := {
	&"dock_04_cargo": &"dock_04",
	&"dock_05_bomber": &"dock_05",
	&"dock_06_interceptor": &"dock_06",
}

## Internal route markers that get a junction panel.
const JUNCTION_ROUTES := {
	&"aft-junction-stack": [&"lower-junction", &"stair-top"],
	&"fleet-dock-comb": [&"trunk-forward", &"trunk-mid", &"vertical-base"],
	&"habitat-spine": [&"common-entry"],
	&"jovian-freight-berth": [&"apron-threshold"],
	&"fabrication_annex": [&"annex_central"],
	&"observation-logistics-spur": [&"cross-landing"],
	&"salvage-terrace": [&"entry", &"main-ramp-base"],
}

## A hub endpoint whose anchor lies this close to another module's route marker
## is reached *through* that module (Observation and Salvage through the
## Fabrication annex), so its title becomes a destination of that module.
const THROUGH_MODULE_RADIUS := 3.0

const MAX_SIGNS := 60
const MAX_TRIANGLES := 400
const DIRECTORY_MAX_ROWS := 9
const THRESHOLD_MAX_ROWS := 4
const JUNCTION_MAX_ROWS := 3
const BACK_MAX_ROWS := 1

## Sign family dimensions (metres).
const ROW_HEIGHT := 0.2
const ROW_GAP := 0.03
const ARROW_WIDTH := 0.2
const LABEL_WIDTH := 1.6
const PLATE_MARGIN := 0.04
## Panel centre above its floor: just over a standing eye line (about 1.65 m).
const PANEL_CENTRE := 1.75
const POST_WIDTH := 0.1
const FACE_OFFSET := 0.01
const ARROW_OFFSET := 0.014

## Placement clearances (metres).
const WALK_CLEARANCE := 0.25
const DOOR_SWING_CLEARANCE := 0.9
const FLOOR_SEARCH_BELOW := 0.9
const FLOOR_SEARCH_ABOVE := 0.45
const POST_FOOT_LIFT := 0.08
const MINIMUM_SIGN_SPACING := 3.0
const MINIMUM_LANDMARK_DISTANCE := 2.5
const LEVEL_STEP := 2.5
## Destinations farther round than this from the reading direction are behind.
const REAR_BEARING := PI * 0.625

const THRESHOLD_LATERALS: Array[float] = [1.6, -1.6, 2.2, -2.2, 1.15, -1.15, 2.8, -2.8]
const THRESHOLD_ALONGS: Array[float] = [0.0, 1.2, -1.2, 2.4, -2.4]
const DIRECTORY_LATERALS: Array[float] = [1.6, -1.6, 2.6, -2.6, 0.9, -0.9]
const DIRECTORY_ALONGS: Array[float] = [4.0, 5.0, 3.0, 6.0]

const EVIDENCE_STATUS := &"modern_interpretation"

var _built := false
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _signs: Array = []
var _conflicts: Array = []
var _skipped: Array = []
var _triangle_count := 0
var _solids: Array = []
var _concave_shapes_checked := 0
var _berth_poses := {}
var _build_duration_usec := 0
var _label_index := {}
var _world_to_local := Transform3D.IDENTITY
var _build_count := 0


func _init() -> void:
	name = "StationWayfinding"
	for index in SIGN_LABELS.size():
		_label_index[(SIGN_LABELS[index] as Array)[0]] = index


## Builds the whole layer once. `world` must be a built `ShipyardWorld` (or any
## node that answers `get_station_route_registry_report()`), already inside the
## tree so global transforms resolve.
func build(world: Node3D) -> Dictionary:
	if _built:
		return get_wayfinding_report()
	var build_started := Time.get_ticks_usec()
	_built = true
	_build_count += 1
	if world == null or not is_instance_valid(world) or not world.has_method(&"get_station_route_registry_report"):
		_skipped.append({"site": "all", "reason": "no station route registry"})
		return get_wayfinding_report()
	_berth_poses = _read_berth_poses(world)
	var report := world.call(&"get_station_route_registry_report") as Dictionary
	var modules := _collect_modules(world)
	_collect_solids(world)

	var hub_origin := _hub_origin(world)
	var destinations := _module_destinations(world, report, modules)
	var sites := _plan_sites(world, report, modules, destinations, hub_origin)

	# Geometry is authored in world space and stored relative to this node.
	_world_to_local = global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for site: Dictionary in sites:
		_place_site(tool, site)
	_solids.clear()
	if _triangle_count > 0:
		var mesh := tool.commit()
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "WayfindingSignBatch"
		_mesh_instance.mesh = mesh
		_mesh_instance.material_override = _get_material()
		_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_mesh_instance.layers = 1
		_mesh_instance.set_meta(&"presentation_only", true)
		_mesh_instance.set_meta(&"non_authoritative_visual", true)
		_mesh_instance.set_meta(&"evidence_status", EVIDENCE_STATUS)
		add_child(_mesh_instance)
	_build_duration_usec = Time.get_ticks_usec() - build_started
	return get_wayfinding_report()


## Discards every panel and derives the layer again from the current registry,
## berths and collision. Explicit geometry edits may request this; normal berth
## refreshes go through `refresh_berths` and only rebuild when rows change.
func rebuild(world: Node3D) -> Dictionary:
	if is_instance_valid(_mesh_instance):
		remove_child(_mesh_instance)
		_mesh_instance.free()
	_mesh_instance = null
	_signs.clear()
	_conflicts.clear()
	_skipped.clear()
	_triangle_count = 0
	_built = false
	return build(world)


## Fleet composition can notify more than once. Comparing three berth poses is
## cheap and avoids another world collision walk after dressing consolidation.
func refresh_berths(world: Node3D) -> Dictionary:
	if not _built:
		return build(world)
	if _read_berth_poses(world) == _berth_poses:
		return get_wayfinding_report()
	return rebuild(world)


func _read_berth_poses(world: Node) -> Dictionary:
	var poses := {}
	if world == null or not world.has_method(&"has_berth") or not world.has_method(&"get_berth_transform"):
		return poses
	for berth_id: StringName in BERTH_LANDMARKS:
		if bool(world.call(&"has_berth", berth_id)):
			poses[berth_id] = (world.call(&"get_berth_transform", berth_id) as Transform3D).origin
	return poses


func is_built() -> bool:
	return _built


func get_label_text(key: StringName) -> String:
	if not _label_index.has(key):
		return ""
	return String((SIGN_LABELS[int(_label_index[key])] as Array)[1])


## Deep-detached placement report: every sign with its registry source, facing,
## rows and arrows, plus every conflict and skipped site.
func get_wayfinding_report() -> Dictionary:
	return {
		"evidence_status": EVIDENCE_STATUS,
		"built": _built,
		"build_count": _build_count,
		"sign_count": _signs.size(),
		"triangle_count": _triangle_count,
		"renderer_count": 1 if is_instance_valid(_mesh_instance) else 0,
		"material_count": 1 if is_instance_valid(_mesh_instance) else 0,
		"max_signs": MAX_SIGNS,
		"max_triangles": MAX_TRIANGLES,
		"signs": _signs.duplicate(true),
		"conflicts": _conflicts.duplicate(true),
		"skipped": _skipped.duplicate(true),
		"concave_shapes_ignored": 0,
		"concave_shapes_checked": _concave_shapes_checked,
		"build_duration_usec": _build_duration_usec,
	}


func get_sign_batch() -> MeshInstance3D:
	return _mesh_instance if is_instance_valid(_mesh_instance) else null


# --- Registry reading -------------------------------------------------------

func _collect_modules(world: Node) -> Dictionary:
	var modules := {}
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		if node != world and node.is_in_group(&"station_modules") and node.has_method(&"get_module_id"):
			modules[StringName(node.call(&"get_module_id"))] = node
			continue
		for child in node.get_children():
			stack.append(child)
	return modules


func _marker_position(modules: Dictionary, module_id: StringName, route_id: StringName) -> Variant:
	var module := modules.get(module_id) as Node
	if module == null or not is_instance_valid(module):
		return null
	if not module.has_method(&"has_route_marker") or not bool(module.call(&"has_route_marker", route_id)):
		return null
	var marker := module.call(&"get_route_marker", route_id) as Node3D
	if marker == null or not is_instance_valid(marker):
		return null
	return marker.global_position


func _hub_origin(world: Node) -> Vector3:
	var spawn := world.get(&"player_spawn") as Node3D
	if spawn != null and is_instance_valid(spawn):
		return spawn.global_position
	return (world as Node3D).global_position


## The directory is read facing into the station: toward the centroid of every
## module's hub endpoint, so most arrows point ahead or to the sides.
func _directory_forward(destinations: Dictionary, hub_origin: Vector3, fallback: Vector3) -> Vector3:
	if destinations.is_empty():
		return fallback
	var centroid := Vector3.ZERO
	for module_id: StringName in destinations.keys():
		centroid += (destinations[module_id] as Dictionary).anchor as Vector3
	centroid /= float(destinations.size())
	return _flat(centroid - hub_origin, fallback)


func _hub_forward(world: Node) -> Vector3:
	var spawn := world.get(&"player_spawn") as Node3D
	if spawn != null and is_instance_valid(spawn):
		return _flat(-spawn.global_transform.basis.z, Vector3.FORWARD)
	return Vector3.FORWARD


## Registry module id -> {title, entry, anchor, landmarks: [{label, position, source}]}.
func _module_destinations(world: Node, report: Dictionary, modules: Dictionary) -> Dictionary:
	var result := {}
	var registry_modules := report.get("modules", {}) as Dictionary
	var hub_endpoints := report.get("hub_endpoints", {}) as Dictionary
	var module_ids := registry_modules.keys()
	module_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for module_id: StringName in module_ids:
		if not MODULE_TITLES.has(module_id):
			_skipped.append({"site": String(module_id), "reason": "registry module has no sign title"})
			continue
		var entry := registry_modules[module_id] as Dictionary
		var slots := entry.get("connection_slots", {}) as Dictionary
		if slots.size() != 1:
			_skipped.append({"site": String(module_id), "reason": "module does not declare exactly one connection slot"})
			continue
		var slot_id := StringName(slots.keys()[0])
		var slot_route := StringName((slots[slot_id] as Dictionary).get("route_id", &""))
		var entry_position: Variant = _marker_position(modules, module_id, slot_route)
		var endpoint := hub_endpoints.get(slot_id, {}) as Dictionary
		if entry_position == null or endpoint.is_empty() or String(endpoint.get("anchor_path", "")).is_empty():
			_skipped.append({"site": String(module_id), "reason": "connection slot does not resolve to a marker and a hub anchor"})
			continue
		var landmarks: Array = []
		for pair: Array in (MODULE_LANDMARKS.get(module_id, []) as Array):
			var position: Variant = _marker_position(modules, module_id, pair[1] as StringName)
			if position == null:
				_skipped.append({"site": "%s:%s" % [module_id, pair[1]], "reason": "landmark route marker missing"})
				continue
			landmarks.append({"label": pair[0], "position": position, "source": "%s:%s" % [module_id, pair[1]]})
		result[module_id] = {
			"module_id": module_id,
			"title": MODULE_TITLES[module_id],
			"slot_id": slot_id,
			"slot_route": slot_route,
			"entry": entry_position,
			"anchor": ((endpoint.get("anchor_transform", Transform3D.IDENTITY)) as Transform3D).origin,
			"landmarks": landmarks,
		}
	_attach_board_consoles(world, result)
	_attach_through_modules(modules, report, result)
	_attach_berths(world, modules, report, result)
	return result


## The two board consoles are real interaction nodes inside the Aft Operations
## room; when the world exposes them, arrows aim at the console itself.
func _attach_board_consoles(world: Node, destinations: Dictionary) -> void:
	var aft := destinations.get(&"aft-junction-stack", {}) as Dictionary
	if aft.is_empty():
		return
	var consoles := {
		&"activity_board": &"get_activity_board_console",
		&"destination_board": &"get_planetary_destination_console",
	}
	for landmark: Dictionary in (aft.get("landmarks", []) as Array):
		var method := consoles.get(landmark.get("label"), &"") as StringName
		if method.is_empty() or not world.has_method(method):
			continue
		var console := world.call(method) as Node3D
		if console != null and is_instance_valid(console):
			landmark["position"] = console.global_position


func _attach_through_modules(modules: Dictionary, report: Dictionary, destinations: Dictionary) -> void:
	var registry_modules := report.get("modules", {}) as Dictionary
	for target_id: StringName in destinations.keys():
		var target := destinations[target_id] as Dictionary
		var anchor := target.get("anchor", Vector3.ZERO) as Vector3
		for host_id: StringName in destinations.keys():
			if host_id == target_id:
				continue
			var host_entry := registry_modules.get(host_id, {}) as Dictionary
			for route_id in (host_entry.get("route_ids", PackedStringArray()) as PackedStringArray):
				var position: Variant = _marker_position(modules, host_id, StringName(route_id))
				if position != null and (position as Vector3).distance_to(anchor) <= THROUGH_MODULE_RADIUS:
					((destinations[host_id] as Dictionary)["landmarks"] as Array).append({
						"label": target.get("title"),
						"position": target.get("entry"),
						"source": "%s:%s via %s:%s" % [target_id, target.get("slot_route"), host_id, route_id],
					})
					target["through"] = host_id
					break
			if target.has("through"):
				break


func _attach_berths(_world: Node, modules: Dictionary, report: Dictionary, destinations: Dictionary) -> void:
	# Deferred berths join only when the world has indexed their real poses.
	var registry_modules := report.get("modules", {}) as Dictionary
	var berth_ids := BERTH_LANDMARKS.keys()
	berth_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for berth_id: StringName in berth_ids:
		if not _berth_poses.has(berth_id):
			_skipped.append({"site": String(berth_id), "reason": "berth missing"})
			continue
		var berth_origin := _berth_poses[berth_id] as Vector3
		var best_module := &""
		var best_route := ""
		var best_distance := INF
		for module_id: StringName in destinations.keys():
			var entry := registry_modules.get(module_id, {}) as Dictionary
			for route_id in (entry.get("route_ids", PackedStringArray()) as PackedStringArray):
				var position: Variant = _marker_position(modules, module_id, StringName(route_id))
				if position == null:
					continue
				var distance := (position as Vector3).distance_to(berth_origin)
				if distance < best_distance:
					best_distance = distance
					best_module = module_id
					best_route = route_id
		if best_module.is_empty():
			continue
		((destinations[best_module] as Dictionary)["landmarks"] as Array).append({
			"label": BERTH_LANDMARKS[berth_id],
			"berth": true,
			"position": berth_origin,
			"source": "berth:%s nearest %s:%s" % [berth_id, best_module, best_route],
		})


# --- Site planning ----------------------------------------------------------

func _plan_sites(world: Node, report: Dictionary, modules: Dictionary, destinations: Dictionary, hub_origin: Vector3) -> Array:
	var sites: Array = []
	var module_ids := destinations.keys()
	module_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))

	# 1. Station directory in front of the spawn.
	var directory_rows: Array = []
	for module_id: StringName in module_ids:
		var destination := destinations[module_id] as Dictionary
		directory_rows.append({
			"label": destination.title,
			"position": destination.anchor,
			"source": "%s:%s" % [StationRouteRegistry.HUB_ENDPOINT_ID, destination.slot_id],
		})
		if module_id == &"aft-junction-stack":
			for landmark: Dictionary in (destination.landmarks as Array):
				if landmark.label == &"vip_reception":
					directory_rows.append(landmark)
	sites.append({
		"id": &"station_directory",
		"kind": &"directory",
		"source": "%s:player_spawn" % StationRouteRegistry.HUB_ENDPOINT_ID,
		"origin": hub_origin,
		"floor_reference": hub_origin.y,
		"forward": _directory_forward(destinations, hub_origin, _hub_forward(world)),
		"laterals": DIRECTORY_LATERALS,
		"alongs": DIRECTORY_ALONGS,
		"front": directory_rows,
		"front_max": DIRECTORY_MAX_ROWS,
		"sort_front_by_bearing": true,
		"back": [],
	})

	# 2. One threshold panel per registry edge.
	for module_id: StringName in module_ids:
		var destination := destinations[module_id] as Dictionary
		var anchor := destination.anchor as Vector3
		var entry := destination.entry as Vector3
		var forward := _flat(entry - anchor, Vector3.ZERO)
		if forward == Vector3.ZERO:
			forward = _flat(entry - hub_origin, Vector3.FORWARD)
		var midpoint := (anchor + entry) * 0.5
		var front: Array = [{
			"label": destination.title,
			"position": entry,
			"source": "%s:%s" % [module_id, destination.slot_route],
		}]
		front.append_array(destination.landmarks as Array)
		sites.append({
			"id": StringName("threshold:%s" % module_id),
			"kind": &"threshold",
			"source": "edge:%s" % destination.slot_id,
			"origin": Vector3(midpoint.x, entry.y, midpoint.z),
			"floor_reference": entry.y,
			"forward": forward,
			"laterals": THRESHOLD_LATERALS,
			"alongs": THRESHOLD_ALONGS,
			"front": front,
			"front_max": THRESHOLD_MAX_ROWS,
			"front_keep_first": true,
			"drop_rear": true,
			"back": [{"label": &"station_hub", "position": anchor, "source": "%s:%s" % [StationRouteRegistry.HUB_ENDPOINT_ID, destination.slot_id]}],
		})

	# 3. Junction panels at listed internal route markers.
	for module_id: StringName in module_ids:
		var destination := destinations[module_id] as Dictionary
		var entry := destination.entry as Vector3
		for route_id: StringName in (JUNCTION_ROUTES.get(module_id, []) as Array):
			var position: Variant = _marker_position(modules, module_id, route_id)
			if position == null:
				_skipped.append({"site": "%s:%s" % [module_id, route_id], "reason": "junction route marker missing"})
				continue
			var forward := _flat((position as Vector3) - entry, Vector3.ZERO)
			if forward == Vector3.ZERO:
				_skipped.append({"site": "%s:%s" % [module_id, route_id], "reason": "junction coincides with module entry"})
				continue
			sites.append({
				"id": StringName("junction:%s:%s" % [module_id, route_id]),
				"kind": &"junction",
				"source": "%s:%s" % [module_id, route_id],
				"origin": position,
				"floor_reference": (position as Vector3).y,
				"forward": forward,
				"laterals": THRESHOLD_LATERALS,
				"alongs": THRESHOLD_ALONGS,
				"front": (destination.landmarks as Array).duplicate(),
				"front_max": JUNCTION_MAX_ROWS,
				"drop_behind": true,
				"progress_origin": entry,
				"back": [{"label": &"station_hub", "position": entry, "source": "%s:%s" % [module_id, destination.slot_route]}],
			})
	return sites


# --- Placement --------------------------------------------------------------

func _place_site(tool: SurfaceTool, site: Dictionary) -> void:
	var site_id := String(site.id)
	if _signs.size() >= MAX_SIGNS:
		_skipped.append({"site": site_id, "reason": "sign budget exhausted"})
		return
	var forward := site.forward as Vector3
	var normal := -forward
	var right := forward.cross(Vector3.UP).normalized()
	var origin := site.origin as Vector3
	# Arrows are read from the route position the reader stands on, not from the
	# sign's offset mount, so a title row at a threshold reads "ahead".
	var front := _select_rows(site, site.front as Array, origin, forward, int(site.front_max), bool(site.get("front_keep_first", false)), bool(site.get("sort_front_by_bearing", false)))
	var back := _select_rows({}, site.back as Array, origin, -forward, BACK_MAX_ROWS, true, false)
	if front.is_empty():
		_skipped.append({"site": site_id, "reason": "no destination ahead"})
		return
	# Budget: trim trailing front rows rather than overrun.
	while not front.is_empty() and _triangle_count + _panel_triangles(front.size(), back.size()) > MAX_TRIANGLES:
		front.pop_back()
	if front.is_empty():
		_skipped.append({"site": site_id, "reason": "triangle budget exhausted"})
		return
	var row_count := maxi(front.size(), back.size())
	var panel_height := row_count * ROW_HEIGHT + (row_count - 1) * ROW_GAP + PLATE_MARGIN * 2.0
	# Centred just above eye height, so every panel spans the reader's eye line.
	var panel_top := PANEL_CENTRE + panel_height * 0.5
	var last_conflict := {}
	for along: float in (site.alongs as Array):
		for lateral: float in (site.laterals as Array):
			var foot := origin + right * lateral + forward * along
			var floor_y: Variant = _find_floor(foot, float(site.floor_reference))
			if floor_y == null:
				last_conflict = {"site": site_id, "candidate": foot, "reason": "no floor under post"}
				continue
			foot.y = float(floor_y)
			if _too_close_to_existing(foot):
				last_conflict = {"site": site_id, "candidate": foot, "reason": "too close to another sign"}
				continue
			var obstruction := _obstruction(foot, right, normal, panel_top, panel_height)
			if not obstruction.is_empty():
				last_conflict = {"site": site_id, "candidate": foot, "reason": "collision", "blocker": obstruction}
				continue
			_emit_panel(tool, foot, right, normal, panel_top, panel_height, front, back)
			_triangle_count += _panel_triangles(front.size(), back.size())
			_signs.append({
				"id": site.id,
				"kind": site.kind,
				"source": site.source,
				"route_origin": origin,
				"position": foot,
				"normal": normal,
				"approach_direction": forward,
				"panel_bottom": foot.y + panel_top - panel_height,
				"panel_top": foot.y + panel_top,
				"half_width": (ARROW_WIDTH + LABEL_WIDTH) * 0.5 + PLATE_MARGIN,
				"front": _row_report(front),
				"back": _row_report(back),
			})
			return
	_conflicts.append(last_conflict)
	_skipped.append({"site": site_id, "reason": "no clear placement"})


func _panel_triangles(front_rows: int, back_rows: int) -> int:
	# Backing plate + post + (arrow + label) per row.
	return 2 + 2 + (front_rows + back_rows) * 4


func _too_close_to_existing(foot: Vector3) -> bool:
	for sign: Dictionary in _signs:
		if (sign.position as Vector3).distance_to(foot) < MINIMUM_SIGN_SPACING:
			return true
	return false


## `site.drop_behind` removes destinations the reader has already passed: those
## behind them, those within reach, and those no farther from the module entry
## (`site.progress_origin`) than the reader already is.
func _select_rows(site: Dictionary, candidates: Array, foot: Vector3, forward: Vector3, limit: int, keep_first: bool, sort_by_bearing: bool) -> Array:
	var drop_behind := bool(site.get("drop_behind", false))
	var drop_rear := drop_behind or bool(site.get("drop_rear", false))
	var progress_origin: Variant = site.get("progress_origin", null)
	var rows: Array = []
	var seen := {}
	for candidate: Dictionary in candidates:
		var label := StringName(candidate.label)
		if seen.has(label) or not _label_index.has(label):
			continue
		# The threshold reserves its three landmark rows for real deferred berths.
		# They may lie behind the entry; keep their truthful return arrow instead
		# of silently losing Dock 04/05/06 to distance sorting or rear filtering.
		var priority := bool(candidate.get("berth", false)) and StringName(site.get("kind", &"")) == &"threshold"
		var target := candidate.position as Vector3
		var flat_distance := Vector2(target.x - foot.x, target.z - foot.z).length()
		var angle := _bearing(foot, target, forward)
		if drop_rear and not priority and absf(angle) > REAR_BEARING:
			continue
		if drop_behind and flat_distance < MINIMUM_LANDMARK_DISTANCE:
			continue
		# Once the reader has climbed above the module entry, the lower level is
		# behind them (for example the operations room seen from the stair top).
		if drop_behind and progress_origin is Vector3 \
				and foot.y > (progress_origin as Vector3).y + LEVEL_STEP and target.y < foot.y - LEVEL_STEP:
			continue
		if drop_behind and progress_origin is Vector3 \
				and target.distance_to(progress_origin as Vector3) <= foot.distance_to(progress_origin as Vector3):
			continue
		seen[label] = true
		rows.append({
			"label": label,
			"target": target,
			"source": candidate.get("source", ""),
			"angle": _quantize(angle),
			"distance": flat_distance,
			"priority": priority,
		})
	var head: Array = []
	if keep_first and not rows.is_empty():
		head.append(rows.pop_front())
	if sort_by_bearing:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if not is_equal_approx(float(a.angle), float(b.angle)):
				return float(a.angle) < float(b.angle)
			return String(a.label) < String(b.label))
	else:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if bool(a.priority) != bool(b.priority):
				return bool(a.priority)
			return float(a.distance) < float(b.distance))
	head.append_array(rows)
	return head.slice(0, limit)


## Signed horizontal bearing of `target` from `from`, relative to `forward`;
## positive is to the viewer's right.
func _bearing(from: Vector3, target: Vector3, forward: Vector3) -> float:
	var to := _flat(target - from, Vector3.ZERO)
	if to == Vector3.ZERO:
		return 0.0
	var right := forward.cross(Vector3.UP).normalized()
	return atan2(to.dot(right), to.dot(forward))


func _quantize(angle: float) -> float:
	var step := PI * 0.25
	var snapped_angle := roundf(angle / step) * step
	if snapped_angle <= -PI + 0.001:
		snapped_angle = PI
	return snapped_angle


func _row_report(rows: Array) -> Array:
	var result: Array = []
	for row: Dictionary in rows:
		result.append({
			"label": row.label,
			"text": get_label_text(row.label),
			"arrow_degrees": roundi(rad_to_deg(float(row.angle))),
			"target": row.target,
			"source": row.source,
		})
	return result


# --- Collision and floor ----------------------------------------------------

func _collect_solids(world: Node) -> void:
	_solids.clear()
	_concave_shapes_checked = 0
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		if node == self:
			continue
		for child in node.get_children():
			stack.append(child)
		if not (node is CollisionShape3D):
			continue
		var shape_node := node as CollisionShape3D
		if shape_node.disabled or shape_node.shape == null:
			continue
		var body := shape_node.get_parent()
		if not (body is CollisionObject3D) or body is Area3D:
			continue
		var bounds := _shape_local_bounds(shape_node.shape)
		if bounds.size.length_squared() <= 0.0:
			continue
		var xform := shape_node.global_transform * Transform3D(Basis.IDENTITY, bounds.get_center())
		var half := bounds.size * 0.5
		var concave := shape_node.shape is ConcavePolygonShape3D
		var triangles := PackedVector3Array()
		if concave:
			_concave_shapes_checked += 1
			# Keep triangles in world space for exact narrow-phase overlap and floors.
			triangles = shape_node.global_transform * (shape_node.shape as ConcavePolygonShape3D).get_faces()
		_solids.append({
			"xform": xform,
			"half": half,
			"aabb": xform * AABB(-half, half * 2.0),
			"concave": concave,
			"floor_box": shape_node.shape is BoxShape3D,
			"triangles": triangles,
			"swing": _is_moving_or_door(shape_node),
			"path": str(shape_node.get_path()),
		})


func _shape_local_bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return AABB(-size * 0.5, size)
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return AABB(Vector3(-capsule.radius, -capsule.height * 0.5, -capsule.radius), Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0))
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return AABB(Vector3(-cylinder.radius, -cylinder.height * 0.5, -cylinder.radius), Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0))
	if shape is ConvexPolygonShape3D:
		return _points_bounds((shape as ConvexPolygonShape3D).points)
	if shape is ConcavePolygonShape3D:
		return _points_bounds((shape as ConcavePolygonShape3D).get_faces())
	return AABB()


func _points_bounds(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _is_moving_or_door(shape_node: Node) -> bool:
	var node := shape_node
	while node != null:
		if node is AnimatableBody3D or node is RigidBody3D or node is CharacterBody3D:
			return true
		if String(node.name).containsn("door"):
			return true
		node = node.get_parent()
	return false


## Highest solid top under `foot` within the floor search window, or null.
func _find_floor(foot: Vector3, reference_y: float) -> Variant:
	var best: Variant = null
	for solid: Dictionary in _solids:
		# Static signs need static support, never a parked craft or moving door.
		if bool(solid.swing):
			continue
		var aabb := solid.aabb as AABB
		if foot.x < aabb.position.x + 0.05 or foot.x > aabb.end.x - 0.05:
			continue
		if foot.z < aabb.position.z + 0.05 or foot.z > aabb.end.z - 0.05:
			continue
		var top := aabb.end.y
		if bool(solid.concave):
			var triangles := solid.triangles as PackedVector3Array
			var from := Vector3(foot.x, reference_y + FLOOR_SEARCH_ABOVE, foot.z)
			var to := Vector3(foot.x, reference_y - FLOOR_SEARCH_BELOW, foot.z)
			for index in range(0, triangles.size(), 3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, triangles[index], triangles[index + 1], triangles[index + 2])
				if hit is Vector3 and (best == null or (hit as Vector3).y > float(best)):
					best = (hit as Vector3).y
			continue
		# Primitive bounds are conservative blockers, but only actual box faces
		# qualify as support. Intersect the oriented box so ramps never use the
		# elevated corner of their world AABB as a fictitious horizontal floor.
		if not bool(solid.floor_box):
			continue
		var surface_y: Variant = _box_surface_y(solid, foot)
		if surface_y == null:
			continue
		top = float(surface_y)
		if top < reference_y - FLOOR_SEARCH_BELOW or top > reference_y + FLOOR_SEARCH_ABOVE:
			continue
		if best == null or top > float(best):
			best = top
	return best


## Vertical segment / oriented box slab intersection, returning its upper face.
func _box_surface_y(solid: Dictionary, foot: Vector3) -> Variant:
	var bounds := solid.aabb as AABB
	var xform := solid.xform as Transform3D
	var inverse := xform.affine_inverse()
	var half := solid.half as Vector3
	var from := inverse * Vector3(foot.x, bounds.end.y + 1.0, foot.z)
	var to := inverse * Vector3(foot.x, bounds.position.y - 1.0, foot.z)
	var direction := to - from
	var enter := 0.0
	var leave := 1.0
	for axis in 3:
		if absf(direction[axis]) < 0.000001:
			if absf(from[axis]) > half[axis]:
				return null
			continue
		var first := (-half[axis] - from[axis]) / direction[axis]
		var second := (half[axis] - from[axis]) / direction[axis]
		enter = maxf(enter, minf(first, second))
		leave = minf(leave, maxf(first, second))
		if enter > leave:
			return null
	return (xform * (from + direction * enter)).y


## Returns the path of the first solid the panel or post volume would enter
## (with walk clearance, and door-swing clearance around doors), or "".
func _obstruction(foot: Vector3, right: Vector3, normal: Vector3, panel_top: float, panel_height: float) -> String:
	var basis := Basis(right, Vector3.UP, normal)
	var panel_half := Vector3((ARROW_WIDTH + LABEL_WIDTH) * 0.5 + PLATE_MARGIN, panel_height * 0.5, ARROW_OFFSET + 0.01)
	var panel_centre := foot + Vector3.UP * (panel_top - panel_height * 0.5)
	var post_bottom := POST_FOOT_LIFT
	var post_top := panel_top - panel_height
	var post_half := Vector3(POST_WIDTH * 0.5, maxf((post_top - post_bottom) * 0.5, 0.01), 0.02)
	var post_centre := foot + Vector3.UP * ((post_top + post_bottom) * 0.5)
	var volumes := [
		[Transform3D(basis, panel_centre), panel_half],
		[Transform3D(basis, post_centre), post_half],
	]
	for solid: Dictionary in _solids:
		var clearance := DOOR_SWING_CLEARANCE if bool(solid.swing) else WALK_CLEARANCE
		for volume: Array in volumes:
			var sign_half := (volume[1] as Vector3) + Vector3(clearance, 0.0, clearance)
			var sign_xform := volume[0] as Transform3D
			var sign_aabb := sign_xform * AABB(-sign_half, sign_half * 2.0)
			if not sign_aabb.intersects(solid.aabb as AABB):
				continue
			if bool(solid.concave):
				if _triangles_overlap_box(solid.triangles as PackedVector3Array, sign_xform, sign_half):
					return String(solid.path)
			elif _obb_overlap(sign_xform, sign_half, solid.xform as Transform3D, solid.half as Vector3):
				return String(solid.path)
	return ""


## Triangle/box SAT: box face normals, triangle normal and nine edge crosses.
## Unlike a trimesh's bounding box, this preserves empty doorways and courtyards.
static func _triangles_overlap_box(triangles: PackedVector3Array, box: Transform3D, half: Vector3) -> bool:
	var inverse := box.affine_inverse()
	var box_axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for index in range(0, triangles.size(), 3):
		var a := inverse * triangles[index]
		var b := inverse * triangles[index + 1]
		var c := inverse * triangles[index + 2]
		var edges: Array[Vector3] = [b - a, c - b, a - c]
		var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK, edges[0].cross(edges[1])]
		for edge in edges:
			for box_axis in box_axes:
				axes.append(edge.cross(box_axis))
		var separated := false
		for axis in axes:
			if axis.length_squared() < 0.00000001:
				continue
			var unit := axis.normalized()
			var radius := half.dot(unit.abs())
			var low := minf(a.dot(unit), minf(b.dot(unit), c.dot(unit)))
			var high := maxf(a.dot(unit), maxf(b.dot(unit), c.dot(unit)))
			if low > radius or high < -radius:
				separated = true
				break
		if not separated:
			return true
	return false


static func _obb_axes(xform: Transform3D, half: Vector3) -> Array:
	var axes: Array[Vector3] = []
	var extents: Array[float] = []
	for index in 3:
		var column := xform.basis[index]
		var length := column.length()
		axes.append(column / length if length > 0.000001 else Vector3.ZERO)
		extents.append(half[index] * length)
	return [axes, extents]


## Separating-axis test between two oriented boxes.
static func _obb_overlap(a_xform: Transform3D, a_half: Vector3, b_xform: Transform3D, b_half: Vector3) -> bool:
	var a := _obb_axes(a_xform, a_half)
	var b := _obb_axes(b_xform, b_half)
	var a_axes := a[0] as Array[Vector3]
	var b_axes := b[0] as Array[Vector3]
	var a_ext := a[1] as Array[float]
	var b_ext := b[1] as Array[float]
	var offset := b_xform.origin - a_xform.origin
	var candidates: Array[Vector3] = []
	candidates.append_array(a_axes)
	candidates.append_array(b_axes)
	for first in a_axes:
		for second in b_axes:
			candidates.append(first.cross(second))
	for axis in candidates:
		if axis.length_squared() < 0.000001:
			continue
		var unit := axis.normalized()
		var ra := 0.0
		var rb := 0.0
		for index in 3:
			ra += absf(a_ext[index] * a_axes[index].dot(unit))
			rb += absf(b_ext[index] * b_axes[index].dot(unit))
		# Touching faces are not an overlap.
		if absf(offset.dot(unit)) >= ra + rb - 0.001:
			return false
	return true


# --- Geometry ---------------------------------------------------------------

func _emit_panel(tool: SurfaceTool, foot: Vector3, right: Vector3, normal: Vector3, panel_top: float, panel_height: float, front: Array, back: Array) -> void:
	var top := foot + Vector3.UP * panel_top
	var half_width := (ARROW_WIDTH + LABEL_WIDTH) * 0.5 + PLATE_MARGIN
	var blank := _cell_uv(BLANK_CELL_INDEX, true)
	# Shared backing plate (visible from both sides; hides mirrored lettering).
	_quad(tool, top - right * half_width, right * (half_width * 2.0), Vector3.DOWN * panel_height, normal, blank)
	# Post from the floor to the panel bottom.
	var post_height := panel_top - panel_height
	if post_height > 0.02:
		_quad(tool, foot + Vector3.UP * post_height - right * (POST_WIDTH * 0.5) - normal * 0.001, right * POST_WIDTH, Vector3.DOWN * post_height, normal, blank)
	_emit_face(tool, top, right, normal, front)
	# The reverse face reads with its own right-hand axis.
	_emit_face(tool, top, -right, -normal, back)


func _emit_face(tool: SurfaceTool, top: Vector3, right: Vector3, normal: Vector3, rows: Array) -> void:
	var row_width := ARROW_WIDTH + LABEL_WIDTH
	for index in rows.size():
		var row := rows[index] as Dictionary
		var angle := float(row.angle)
		var row_top := top + Vector3.DOWN * (PLATE_MARGIN + index * (ROW_HEIGHT + ROW_GAP))
		var left_edge := row_top - right * (row_width * 0.5)
		# Arrow on the side it points to; ahead/behind keep the left position.
		var arrow_on_right := sin(angle) > 0.1
		var arrow_left := left_edge + right * (LABEL_WIDTH if arrow_on_right else 0.0)
		var label_left := left_edge + right * (0.0 if arrow_on_right else ARROW_WIDTH)
		_quad(tool, label_left + normal * FACE_OFFSET, right * LABEL_WIDTH, Vector3.DOWN * ROW_HEIGHT, normal, _cell_uv(int(_label_index[row.label]), false))
		var centre := arrow_left + right * (ARROW_WIDTH * 0.5) + Vector3.DOWN * (ROW_HEIGHT * 0.5) + normal * ARROW_OFFSET
		# Rotate the up-pointing arrow clockwise (as the reader sees it) by angle.
		var up_axis := Vector3.UP.rotated(normal, -angle)
		var right_axis := right.rotated(normal, -angle)
		var half := ARROW_WIDTH * 0.5
		_quad(tool, centre - right_axis * half + up_axis * half, right_axis * ARROW_WIDTH, -up_axis * ARROW_WIDTH, normal, _cell_uv(ARROW_CELL_INDEX, false, true))


## Quad from its top-left corner, an across vector and a down vector.
func _quad(tool: SurfaceTool, top_left: Vector3, across: Vector3, down: Vector3, normal: Vector3, uv: Rect2) -> void:
	var corners := [top_left, top_left + across, top_left + across + down, top_left + down]
	var uvs := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	var local_normal := (_world_to_local.basis * normal).normalized()
	for index in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(local_normal)
		tool.set_uv(uvs[index] as Vector2)
		tool.add_vertex(_world_to_local * (corners[index] as Vector3))


func _cell_uv(index: int, centre_only: bool, square: bool = false) -> Rect2:
	var column := index % ATLAS_COLUMNS
	var row := index / ATLAS_COLUMNS
	var origin := Vector2(column * ATLAS_CELL.x, row * ATLAS_CELL.y)
	var size := ATLAS_CELL
	if square:
		size = Vector2(ATLAS_CELL.y, ATLAS_CELL.y)
	if centre_only:
		origin += size * 0.25
		size *= 0.5
	var inset := Vector2(1.0, 1.0)
	return Rect2((origin + inset) / ATLAS_SIZE, (size - inset * 2.0) / ATLAS_SIZE)


func _get_material() -> StandardMaterial3D:
	if _material != null:
		return _material
	_material = StandardMaterial3D.new()
	_material.resource_name = "StationWayfindingSignMaterial"
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Slightly below white so pale lettering never trips glow on its own.
	_material.albedo_color = Color(0.86, 0.86, 0.86)
	var texture := load(ATLAS_TEXTURE_PATH) as Texture2D
	if texture != null:
		_material.albedo_texture = texture
	return _material


func _flat(vector: Vector3, fallback: Vector3) -> Vector3:
	var flat := Vector3(vector.x, 0.0, vector.z)
	if flat.length_squared() < 0.0001:
		return fallback
	return flat.normalized()
