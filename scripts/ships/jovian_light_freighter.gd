class_name JovianLightFreighter
extends HeroShip

## Evidence-bounded Jovian-class Light Freighter candidate.
##
## Creator-authored material (A3, page archived 2009-11-12) supports the class
## name and light-freighter role. No registered source shows a craft identified
## as Jovian: B4 records the label string alone, with no ledger frame anchor and
## no tied craft, so the Jovian name-to-model mapping is `unknown`.
## Every visible dimension, colour, access route, interior, system, hardpoint,
## and handling value in this component is a revisable modern interpretation.
## The cargo deck, passenger cabin, cockpit, and exterior ramp are one physical
## ship-local hierarchy; no detached or teleported interior is involved.

const SCHEMA_VERSION := 1
const EVIDENCE_STATUS: StringName = &"provisional"
const EVIDENCE_SCOPE: StringName = &"name_and_role_only"
const NAME_TO_MODEL_STATUS: StringName = &"unknown"
const COMBAT_SOURCE_ID := 1103
const INTERIOR_SCHEMA_VERSION := 1
const INTERIOR_BOUNDS := AABB(Vector3(-5.72, 0.0, -8.0), Vector3(11.44, 4.6, 17.25))
const PARKED_RENDER_BOUNDS := AABB(Vector3(-10.6, -1.36, -14.1), Vector3(19.1, 6.31, 28.55))
const FLIGHT_COLLISION_BOUNDS := AABB(Vector3(-10.45, -1.45, -13.9), Vector3(18.55, 6.2, 26.2))
const PROVISIONAL_NOTE := (
	"Creator-supported facts (A3 page text): Jovian-class Light Freighter name "
	+ "and light-freighter role. No registered source ties any visible craft to "
	+ "the Jovian name, so the name-to-model mapping is unknown. "
	+ "The displayed geometry, dimensions, colours, cargo and "
	+ "passenger interior, ramp, cockpit access, capacity, systems, weapons, "
	+ "materials, and handling are modern provisional interpretation; no "
	+ "authenticated historical silhouette mapping is claimed."
)

# Fleet readability palette. The Jovian's name-to-model mapping is unknown and
# its palette is listed among its unknowns in docs/research/ship_evidence_matrix.json,
# so these are freely chosen modern hull tints picked to separate the freighter
# from the rest of the fleet under normal and dichromatic vision. See
# tests/fleet_role_differentiation_test.gd for the frozen separation floors.
# HULL_COOL keeps its name because `hull_cool` is the craft's stable public
# material-family key, asserted by tests/fleet_pbr_test.gd; it now carries the
# subordinate shade of the same warm clay family rather than a cool grey.
const HULL_WARM := Color("e0ab74")
const HULL_COOL := Color("bd9270")
const JOVIAN_STRUCTURE := Color("283c42")
const JOVIAN_STRUCTURE_DARK := Color("0e2026")
const FREIGHT_TEAL := Color("35bbb5")
const FREIGHT_AMBER := Color("e9a844")
const CARGO_BLUE := Color("39798d")
const CABIN_CLOTH := Color("365259")
const DECK_GREY := Color("718084")
const ENGINE_AQUA := Color("70eee7")
const JOVIAN_NAV_RED := Color("ff635d")
const JOVIAN_NAV_GREEN := Color("70e995")

var _jovian_built := false
var _jovian_visual: Node3D
var _jovian_materials: Dictionary = {}
var _walkable_interior: Node3D
var _cargo_bay: Node3D
var _passenger_cabin: Node3D
var _moving_interior_component: MovingInteriorFrame
var _occupant_volume: Area3D
var _interior_access_marker: Marker3D
var _interior_deck_marker: Marker3D
var _interior_exit_marker: Marker3D
var _cargo_hardpoints: Array[Marker3D] = []
var _passenger_seat_anchors: Array[Marker3D] = []
var _engine_plumes: Array[MeshInstance3D] = []
var _jovian_engine_lights: Array[OmniLight3D] = []
var _elapsed_jovian := 0.0


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _ready() -> void:
	super._ready()
	if not _jovian_built:
		_jovian_built = rebuild_variant_presentation(_build_jovian_variant)
	_apply_jovian_metadata()
	_sync_jovian_engine_presentation_immediately()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_elapsed_jovian += delta
	_update_jovian_presentation(delta)


func apply_damage(
		amount: float,
		world_hit_position: Vector3 = Vector3.INF,
		world_hit_normal: Vector3 = Vector3.ZERO,
		presentation_receipt_id: int = -1,
		defer_presentation: bool = false
	) -> void:
	super.apply_damage(
		amount,
		world_hit_position,
		world_hit_normal,
		presentation_receipt_id,
		defer_presentation
	)
	if is_destroyed():
		_set_interior_operational(false)


func reset_for_reuse(spawn_transform: Transform3D) -> void:
	super.reset_for_reuse(spawn_transform)
	_set_interior_operational(true)
	if _moving_interior_component != null:
		_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
		_moving_interior_component.reset_frame_tracking(true)
	_sync_jovian_engine_presentation_immediately()


## The complete visible freighter hierarchy used by the common presentation
## lifecycle. Its `WalkableInterior` child stays attached while the ship moves.
func get_jovian_visual_root() -> Node3D:
	return _jovian_visual


## Stable local combat registry identity reserved for this physical candidate.
## The shared combat authority remains the owner of actual registration.
func get_combat_source_id() -> int:
	return COMBAT_SOURCE_ID


## Stable ship-local hierarchy containing the deck, rooms, lights, fixtures,
## access aperture, and semantic markers of the connected interior.
func get_interior_root() -> Node3D:
	return _walkable_interior


## Registration frame for moving-interior occupant stabilisation. This returns
## a Node3D rather than a concrete component type so the ship contract remains
## usable before or without multiplayer motion compensation.
func get_interior_frame() -> Node3D:
	return self


## Typed coordinator for occupant registration, frame-delta compensation, and
## inertial exit velocity. It is separate from the spatial frame by design.
func get_moving_interior_component() -> MovingInteriorFrame:
	return _moving_interior_component


func get_cargo_bay_root() -> Node3D:
	return _cargo_bay


func get_passenger_cabin_root() -> Node3D:
	return _passenger_cabin


func get_interior_access_marker() -> Marker3D:
	return _interior_access_marker


func get_interior_deck_marker() -> Marker3D:
	return _interior_deck_marker


## World-space safe transform beyond the deployed ramp. This is intentionally
## distinct from HeroShip.get_exit_transform(), which serves the pilot seat.
func get_interior_exit_transform() -> Transform3D:
	if _interior_exit_marker == null:
		return Transform3D(global_basis.orthonormalized(), global_position)
	return _interior_exit_marker.global_transform


## Pressurised/walkable cabin envelope in ship-local coordinates. The deployed
## exterior ramp is deliberately outside this box.
func get_interior_bounds() -> AABB:
	return INTERIOR_BOUNDS


## Typed clearance contract for a berth or landing planner. These are bounds of
## this provisional implementation, not evidence about the historical Jovian.
func get_berth_clearance_report() -> Dictionary:
	return {
		"schema_version": 1,
		"home_berth_id": get_home_berth_id(),
		"parked_render_bounds": PARKED_RENDER_BOUNDS,
		"flight_collision_bounds": FLIGHT_COLLISION_BOUNDS,
		"ramp_side": &"port",
		"ramp_local_direction": Vector3.LEFT,
		"landing_contact_y": -1.25,
		"deployed_ramp_may_overlap_apron": true,
		"provisional": true,
	}


func get_cargo_hardpoints() -> Array[Marker3D]:
	return _cargo_hardpoints.duplicate()


func get_passenger_seat_anchors() -> Array[Marker3D]:
	return _passenger_seat_anchors.duplicate()


func get_walkable_interior_report() -> Dictionary:
	return {
		"schema_version": INTERIOR_SCHEMA_VERSION,
		"frame": self,
		"moving_interior_component": _moving_interior_component,
		"root": _walkable_interior,
		"ship_local_bounds": INTERIOR_BOUNDS,
		"access_marker": _interior_access_marker,
		"deck_marker": _interior_deck_marker,
		"exit_transform": get_interior_exit_transform(),
		"cargo_bay": _cargo_bay,
		"passenger_cabin": _passenger_cabin,
		"pilot_cockpit": get_pilot_seat_anchor().get_parent() if get_pilot_seat_anchor() != null else null,
		"connected_spaces": PackedStringArray(["exterior_ramp", "cargo_bay", "passenger_cabin", "pilot_cockpit"]),
		"cargo_hardpoint_count": _cargo_hardpoints.size(),
		"passenger_seat_count": _passenger_seat_anchors.size(),
		"detached_interior": false,
		"physical_deck_collision": true,
		"moving_occupant_compensation": _moving_interior_component != null,
		"historically_authenticated_layout": false,
		"content_note": PROVISIONAL_NOTE,
	}


func get_jovian_evidence_report() -> Dictionary:
	var definition := get_ship_definition()
	return {
		"schema_version": SCHEMA_VERSION,
		"evidence_status": EVIDENCE_STATUS,
		"evidence_scope": EVIDENCE_SCOPE,
		"name_to_model_status": NAME_TO_MODEL_STATUS,
		"authenticated_geometry": false,
		"creator_supported": PackedStringArray([
			"Jovian-class Light Freighter name (A3 page text)",
			"light-freighter role (A3 page text)",
		]),
		"modern_provisional": PackedStringArray([
			"silhouette, dimensions, proportions, and colours",
			"cargo ramp, walkable interior, room layout, fixtures, and capacity",
			"cockpit, pilot hatch, seat, access side, and cameras",
			"quad engines, defensive weapons, landing gear, and cargo hardware",
			"materials, handling, durability, audio profile, and all mechanics",
		]),
		"content_note": PROVISIONAL_NOTE,
		"ship_definition": definition.get_audit_report() if definition != null else {},
	}


func get_jovian_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var definition := get_ship_definition()
	if definition == null or not definition.is_definition_valid():
		errors.append("valid provisional ShipDefinition is missing")
	elif definition.get_evidence_status_id() != &"provisional":
		errors.append("Jovian definition must remain provisional")
	if _jovian_visual == null:
		errors.append("dedicated Jovian visual root is missing")
	if _walkable_interior == null or _cargo_bay == null or _passenger_cabin == null:
		errors.append("connected cargo and passenger interior hierarchy is incomplete")
	if _interior_access_marker == null or _interior_deck_marker == null or _interior_exit_marker == null:
		errors.append("interior route markers are incomplete")
	if _moving_interior_component == null or _moving_interior_component.get_moving_frame() != self:
		errors.append("typed moving-interior component is not configured against the ship frame")
	if _cargo_hardpoints.size() < 4:
		errors.append("cargo bay requires at least four stable cargo hardpoints")
	if _passenger_seat_anchors.size() < 4:
		errors.append("passenger cabin requires at least four seat anchors")
	if _engine_plumes.size() != 4:
		errors.append("provisional quad-engine presentation is incomplete")
	if get_node_or_null("LeftMuzzle") == null or get_node_or_null("RightMuzzle") == null:
		errors.append("defensive muzzle markers are missing")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"ship_id": get_ship_id(),
		"display_name": get_display_name(),
		"role": get_role(),
		"engine_count": _engine_plumes.size(),
		"weapon_class": &"freighter_defensive_pulse",
		"combat_source_id": COMBAT_SOURCE_ID,
		"interior": get_walkable_interior_report(),
		"evidence": get_jovian_evidence_report(),
	}


func _build_jovian_variant(_controller: HeroShip) -> bool:
	var inherited_visual := get_variant_visual_root()
	if inherited_visual == null:
		return false
	# Keep common-controller cockpit objects and their private references intact,
	# but relocate the entire cabin into the freighter's forward flight deck.
	var cockpit := inherited_visual.get_node_or_null("CockpitInterior") as Node3D
	var canopy := inherited_visual.get_node_or_null("CanopyHinge") as Node3D
	var hinge_bar := inherited_visual.get_node_or_null("CanopyHingeBar") as Node3D
	var hinge_mounts := inherited_visual.find_children("*CanopyHingeMount", "Node3D", false, false)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(self, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(self, true)
	if inherited_visual.get_parent() != null:
		inherited_visual.get_parent().remove_child(inherited_visual)
	inherited_visual.queue_free()

	_jovian_visual = Node3D.new()
	_jovian_visual.name = "JovianFreighterVisual"
	_jovian_visual.set_meta("geometry_status", EVIDENCE_STATUS)
	_jovian_visual.set_meta("authenticated_historical_silhouette", false)
	_jovian_visual.set_meta("content_note", PROVISIONAL_NOTE)
	add_child(_jovian_visual)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(_jovian_visual, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(_jovian_visual, true)

	_create_jovian_materials()
	_relocate_and_restyle_cockpit(cockpit, canopy, hinge_bar, hinge_mounts)
	_build_exterior()
	_build_connected_interior()
	_build_propulsion_and_gear()
	_replace_collision_and_markers()
	_bind_optional_interior_frame()
	if not replace_variant_visual_root(_jovian_visual):
		return false
	return true


func _create_jovian_materials() -> void:
	_jovian_materials.hull_warm = _jovian_material(HULL_WARM, 0.16, 0.3)
	_jovian_materials.hull_cool = _jovian_material(HULL_COOL, 0.22, 0.38)
	# Freighter secondary structure. Before this pass structure/dark/amber sat at
	# roughness 0.36/0.30/0.35 and cargo_blue/deck at 0.47/0.52 — the whole
	# working half of the ship inside a 0.22 band, so the painted bulkheads, the
	# oiled load rails and the yellow cargo-aperture frame all returned the same
	# highlight and separated only by hue. They are now painted plate, oiled
	# steel, matte industrial paint, a painted crate and worn deck tread.
	# Colours are unchanged.
	_jovian_materials.structure = _jovian_material(JOVIAN_STRUCTURE, 0.34, 0.66)
	_jovian_materials.dark = _jovian_material(JOVIAN_STRUCTURE_DARK, 0.72, 0.22)
	_jovian_materials.teal = _jovian_material(FREIGHT_TEAL, 0.28, 0.3, FREIGHT_TEAL, 0.75)
	_jovian_materials.amber = _jovian_material(FREIGHT_AMBER, 0.14, 0.62)
	_jovian_materials.cargo_blue = _jovian_material(CARGO_BLUE, 0.10, 0.70)
	_jovian_materials.cabin_cloth = _jovian_material(CABIN_CLOTH, 0.08, 0.78)
	_jovian_materials.deck = _jovian_material(DECK_GREY, 0.40, 0.74)
	_jovian_materials.engine = _jovian_material(ENGINE_AQUA, 0.1, 0.16, ENGINE_AQUA, 3.2)
	_jovian_materials.nav_red = _jovian_material(JOVIAN_NAV_RED, 0.08, 0.2, JOVIAN_NAV_RED, 2.4)
	_jovian_materials.nav_green = _jovian_material(JOVIAN_NAV_GREEN, 0.08, 0.2, JOVIAN_NAV_GREEN, 2.4)
	_jovian_materials.interior_light = _jovian_material(Color("d5f9ee"), 0.0, 0.24, Color("b7fff0"), 2.5)
	_jovian_materials.display = _jovian_material(Color("183b40"), 0.18, 0.22, FREIGHT_TEAL, 2.8)
	_jovian_materials.glass = _jovian_glass(Color(0.12, 0.48, 0.52, 0.2))
	# The freighter has its own larger-scale civilian service-panel finish. Reusing
	# the Arrow's small ceramic pattern made two intentionally different classes
	# read as the same procedural prop at normal viewing distance.
	var hull_albedo := load("res://assets/materials/jovian-hull-albedo-v1.png") as Texture2D
	var hull_normal := load("res://assets/materials/jovian-hull-normal-v1.png") as Texture2D
	var hull_roughness := load("res://assets/materials/jovian-hull-roughness-v1.png") as Texture2D
	for hull_material: StandardMaterial3D in [_jovian_materials.hull_warm, _jovian_materials.hull_cool]:
		if hull_albedo != null:
			hull_material.albedo_texture = hull_albedo
		if hull_normal != null:
			hull_material.normal_enabled = true
			hull_material.normal_texture = hull_normal
			hull_material.normal_scale = 0.68
		if hull_roughness != null:
			hull_material.roughness_texture = hull_roughness
			hull_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		hull_material.uv1_triplanar = true
		hull_material.uv1_triplanar_sharpness = 4.5
		hull_material.uv1_scale = Vector3.ONE * 0.24
		hull_material.clearcoat_enabled = true
		hull_material.clearcoat = 0.42
		hull_material.clearcoat_roughness = 0.25
	# The cargo-aperture uprights, header, load rails and restraints were the
	# most primitive-looking objects on the freighter: full-height flat yellow
	# bars standing against a fully panelled hull in the baseline walk-up frame.
	# The freighter's own registered normal map is reused on the working
	# structure through triplanar projection at roughly 3-6x the hull's
	# frequency, so a bulkhead, a load rail and a deck plate each carry surface
	# relief at their own scale. No albedo texture is bound anywhere here, so
	# the hull, accent and cargo tints the fleet colour floors measure are
	# exactly as authored.
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.structure, hull_normal, 0.8, 0.70)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.dark, hull_normal, 1.1, 0.55)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.amber, hull_normal, 1.0, 0.80)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.cargo_blue, hull_normal, 0.9, 0.90)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.deck, hull_normal, 1.4, 0.85)


func get_variant_materials() -> Dictionary:
	return _jovian_materials


func _relocate_and_restyle_cockpit(
		cockpit: Node3D,
		canopy: Node3D,
		hinge_bar: Node3D,
		hinge_mounts: Array[Node]
	) -> void:
	const COCKPIT_SHIFT := Vector3(0.0, -1.38, -8.15)
	if cockpit != null:
		cockpit.position += COCKPIT_SHIFT
		cockpit.set_meta("space_id", &"pilot_cockpit")
		var rear_wall := cockpit.get_node_or_null("RearPressureWall") as MeshInstance3D
		if rear_wall != null:
			# The freighter connects this former fighter rear bulkhead to a real
			# passenger passage. A new open pressure frame replaces the solid panel.
			rear_wall.visible = false
		for surface in cockpit.find_children("*Sidewall", "MeshInstance3D", true, false):
			(surface as MeshInstance3D).material_override = _jovian_materials.structure
		for surface in cockpit.find_children("*Sill", "MeshInstance3D", true, false):
			(surface as MeshInstance3D).material_override = _jovian_materials.amber
		for display in cockpit.find_children("*Display", "MeshInstance3D", true, false):
			(display as MeshInstance3D).material_override = _jovian_materials.display
	if canopy != null:
		canopy.position += COCKPIT_SHIFT
		for glass in canopy.find_children("CanopyGlass", "MeshInstance3D", true, false):
			(glass as MeshInstance3D).material_override = _jovian_materials.glass
		for frame in canopy.find_children("*Canopy*Frame", "MeshInstance3D", true, false):
			(frame as MeshInstance3D).material_override = _jovian_materials.structure
		for rail in canopy.find_children("*Canopy*Rail", "MeshInstance3D", true, false):
			(rail as MeshInstance3D).material_override = _jovian_materials.amber
	if hinge_bar != null:
		hinge_bar.position += COCKPIT_SHIFT
		(hinge_bar as MeshInstance3D).material_override = _jovian_materials.structure
	for mount in hinge_mounts:
		var mount_3d := mount as Node3D
		mount_3d.position += COCKPIT_SHIFT
		if mount_3d is MeshInstance3D:
			(mount_3d as MeshInstance3D).material_override = _jovian_materials.amber


func _build_exterior() -> void:
	# The flight deck is a smooth low nose supporting the retained physical
	# cockpit. It does not enclose the cabin with a solid collision primitive.
	_loft_hull(
		_jovian_visual,
		"ForwardFlightDeck",
		Vector3(0.0, -0.02, 0.0),
		PackedVector3Array([
			Vector3(0.18, 0.08, -14.0),
			Vector3(2.1, 0.3, -12.4),
			Vector3(3.35, 0.43, -10.25),
			Vector3(4.15, 0.54, -7.2),
			Vector3(4.5, 0.48, -4.4),
		]),
		_jovian_materials.hull_warm,
		28
	)
	# Long shoulder volumes carry load and engines outside the open central
	# interior. Their dense lofts provide a materially larger, non-box silhouette.
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var side_name := "Port" if side < 0.0 else "Starboard"
		if side < 0.0:
			# Two pressure-shell sections leave a true four-metre port aperture.
			# The visual opening matches the split collision volumes below.
			_loft_hull(
				_jovian_visual,
				"PortCargoShoulder",
				Vector3(side * 6.25, 2.05, 0.0),
				PackedVector3Array([
					Vector3(0.62, 0.52, -7.8),
					Vector3(1.62, 1.72, -5.5),
					Vector3(1.82, 2.02, 0.8),
					Vector3(1.78, 1.98, 1.12),
				]),
				_jovian_materials.hull_cool,
				24
			)
			_loft_hull(
				_jovian_visual,
				"PortAftCargoShoulder",
				Vector3(side * 6.25, 2.05, 0.0),
				PackedVector3Array([
					Vector3(1.78, 1.98, 5.28),
					Vector3(1.8, 2.0, 5.62),
					Vector3(1.75, 1.92, 8.7),
					Vector3(1.32, 1.52, 11.2),
				]),
				_jovian_materials.hull_cool,
				24
			)
		else:
			_loft_hull(
				_jovian_visual,
				"StarboardCargoShoulder",
				Vector3(side * 6.25, 2.05, 0.0),
				PackedVector3Array([
					Vector3(0.62, 0.52, -7.8),
					Vector3(1.62, 1.72, -5.5),
					Vector3(1.82, 2.02, 1.5),
					Vector3(1.75, 1.92, 8.7),
					Vector3(1.32, 1.52, 11.2),
				]),
				_jovian_materials.hull_cool,
				24
			)
		# Recessed service spine and panel strips break the broad fairing without
		# covering the cargo aperture on the port side.
		if side < 0.0:
			_curve_tube(_jovian_visual, "PortForwardShoulderRail", PackedVector3Array([
				Vector3(-7.55, 3.2, -4.8), Vector3(-7.8, 3.34, 0.95),
			]), 0.13, _jovian_materials.teal)
			_curve_tube(_jovian_visual, "PortAftShoulderRail", PackedVector3Array([
				Vector3(-7.78, 3.3, 5.48), Vector3(-7.5, 3.1, 8.7),
			]), 0.13, _jovian_materials.teal)
		else:
			_curve_tube(
				_jovian_visual,
				"StarboardShoulderRail",
				PackedVector3Array([
					Vector3(side * 7.55, 3.2, -4.8),
					Vector3(side * 7.82, 3.35, 1.0),
					Vector3(side * 7.5, 3.1, 8.7),
				]),
				0.13,
				_jovian_materials.teal
			)
		for panel_index in 4:
			if side < 0.0 and panel_index == 2:
				continue
			var panel_z := -4.1 + float(panel_index) * 3.75
			_box(
				_jovian_visual,
				side_name + "ServicePanel%02d" % panel_index,
				Vector3(side * 7.83, 2.12, panel_z),
				Vector3(0.1, 1.48, 2.45),
				_jovian_materials.structure
			)
		_sphere(
			_jovian_visual,
			side_name + "NavigationLight",
			Vector3(side * 8.02, 3.7, 8.4),
			0.16,
			_jovian_materials.nav_red if side < 0.0 else _jovian_materials.nav_green
		)

	# Arched roof and keel members visually unify the load-bearing shoulders.
	_planform_surface(
		_jovian_visual,
		"CargoRoofShell",
		PackedVector3Array([
			Vector3(-5.72, 4.55, -3.0),
			Vector3(5.72, 4.55, -3.0),
			Vector3(5.72, 4.48, 9.3),
			Vector3(-5.72, 4.48, 9.3),
		]),
		0.24,
		_jovian_materials.hull_warm
	)
	for rib_index in 5:
		var rib_z := -2.4 + float(rib_index) * 2.72
		_curve_tube(
			_jovian_visual,
			"DorsalCargoRib%02d" % rib_index,
			PackedVector3Array([
				Vector3(-5.55, 4.28, rib_z),
				Vector3(-3.7, 4.72, rib_z),
				Vector3(0.0, 4.9, rib_z),
				Vector3(3.7, 4.72, rib_z),
				Vector3(5.55, 4.28, rib_z),
			]),
			0.095,
			_jovian_materials.structure
		)
	_box(_jovian_visual, "VentralKeel", Vector3(0.0, 0.02, 3.25), Vector3(2.2, 0.42, 19.4), _jovian_materials.structure)
	for side in [-1.0, 1.0]:
		_box(_jovian_visual, "VentralLoadRail", Vector3(side * 3.9, 0.15, 2.9), Vector3(0.42, 0.48, 18.5), _jovian_materials.dark)

	# Aft machinery deck, tapered tail bridge, radiators, and restrained colour
	# blocks make the class readable as a utility vessel rather than a fighter.
	_loft_hull(
		_jovian_visual,
		"AftMachinerySpine",
		Vector3(0.0, 2.25, 0.0),
		PackedVector3Array([
			Vector3(4.5, 1.35, 8.4),
			Vector3(4.85, 1.42, 10.5),
			Vector3(3.9, 1.15, 12.25),
			Vector3(2.2, 0.72, 13.35),
		]),
		_jovian_materials.hull_cool,
		24
	)
	for side in [-1.0, 1.0]:
		_planform_surface(
			_jovian_visual,
			"PortRadiator" if side < 0.0 else "StarboardRadiator",
			PackedVector3Array([
				Vector3(side * 4.6, 3.15, 8.9),
				Vector3(side * 8.2, 2.85, 9.45),
				Vector3(side * 8.45, 2.55, 12.0),
				Vector3(side * 4.05, 2.85, 11.55),
			]),
			0.15,
			_jovian_materials.structure
		)
		for stripe_index in 3:
			_box(
				_jovian_visual,
				"PortLoadMark" if side < 0.0 else "StarboardLoadMark",
				Vector3(side * 7.88, 1.15, -1.3 + stripe_index * 1.1),
				Vector3(0.12, 0.42, 0.72),
				_jovian_materials.amber,
				Vector3(0.0, 0.0, side * deg_to_rad(18.0))
			)

	# The deployed ramp and frame are deliberately obvious from the berth. The
	# opening remains geometrically clear all the way to the cargo deck.
	# A 20-degree rise gives the wedge's walkable upper surface y=-1.25 at
	# x=-10.45 and y=+0.48 at the cargo-deck threshold x=-5.725. Unlike a
	# rotated box, its flat underside never extends below the landing plane.
	var ramp_angle := deg_to_rad(20.0)
	_ramp_wedge(
		_jovian_visual,
		"PortCargoRamp",
		-10.45,
		-5.725,
		-1.25,
		-1.25,
		0.48,
		3.2,
		1.7,
		_jovian_materials.deck
	)
	for rail_z in [1.62, 4.78]:
		_box(
			_jovian_visual,
			"CargoRampEdgeRail",
			Vector3(-7.9, -0.22, rail_z),
			Vector3(5.15, 0.24, 0.16),
			_jovian_materials.amber,
			Vector3(0.0, 0.0, ramp_angle)
		)
	for vertical_z in [1.25, 5.15]:
		_box(_jovian_visual, "CargoApertureUpright", Vector3(-5.78, 2.38, vertical_z), Vector3(0.32, 3.75, 0.3), _jovian_materials.amber)
	_box(_jovian_visual, "CargoApertureHeader", Vector3(-5.78, 4.22, 3.2), Vector3(0.34, 0.3, 4.2), _jovian_materials.amber)
	_box(_jovian_visual, "CargoRampActuator", Vector3(-6.1, 0.12, 1.3), Vector3(0.24, 0.24, 1.35), _jovian_materials.structure, Vector3(0.0, 0.0, ramp_angle))
	_box(_jovian_visual, "CargoRampActuator", Vector3(-6.1, 0.12, 5.1), Vector3(0.24, 0.24, 1.35), _jovian_materials.structure, Vector3(0.0, 0.0, ramp_angle))


func _build_connected_interior() -> void:
	_walkable_interior = Node3D.new()
	_walkable_interior.name = "WalkableInterior"
	_walkable_interior.set_meta("space_id", &"jovian_connected_interior")
	_walkable_interior.set_meta("geometry_status", EVIDENCE_STATUS)
	_walkable_interior.set_meta("detached_interior", false)
	_walkable_interior.set_meta("historically_authenticated_layout", false)
	# This must be a direct child of the physical ship, not the banked exterior
	# visual root. Its deck meshes, direct hull colliders, occupancy volume, and
	# MovingInteriorFrame therefore share one authoritative rigid transform.
	add_child(_walkable_interior)
	var cockpit := _jovian_visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit != null:
		cockpit.reparent(_walkable_interior, true)

	_build_cargo_bay()
	_build_passenger_cabin()
	_build_interior_route_and_markers()


func _build_cargo_bay() -> void:
	_cargo_bay = Node3D.new()
	_cargo_bay.name = "CargoBay"
	_cargo_bay.set_meta("space_id", &"cargo_bay")
	_cargo_bay.set_meta("capacity_status", &"provisional")
	_walkable_interior.add_child(_cargo_bay)
	_box(_cargo_bay, "CargoDeck", Vector3(0.0, 0.5, 3.15), Vector3(11.3, 0.18, 12.1), _jovian_materials.deck)
	# Slim inlaid lanes leave an unobstructed route from ramp to forward cabin.
	for lane_x in [-2.15, 0.0, 2.15]:
		_box(_cargo_bay, "CargoDeckLane", Vector3(lane_x, 0.61, 3.15), Vector3(0.11, 0.025, 11.4), _jovian_materials.teal)
	# Starboard wall is continuous. The port wall is split around the open ramp.
	_box(_cargo_bay, "StarboardInnerWall", Vector3(5.64, 2.5, 3.15), Vector3(0.18, 3.86, 12.0), _jovian_materials.structure)
	_box(_cargo_bay, "PortInnerWallForward", Vector3(-5.64, 2.5, -0.9), Vector3(0.18, 3.86, 3.65), _jovian_materials.structure)
	_box(_cargo_bay, "PortInnerWallAft", Vector3(-5.64, 2.5, 7.15), Vector3(0.18, 3.86, 4.05), _jovian_materials.structure)
	_box(_cargo_bay, "AftPressureWall", Vector3(0.0, 2.5, 9.17), Vector3(11.3, 3.86, 0.18), _jovian_materials.structure)
	# Forward bulkhead wraps a 2.8 m passage to the passenger cabin.
	for side in [-1.0, 1.0]:
		_box(_cargo_bay, "ForwardBulkheadWing", Vector3(side * 3.55, 2.5, -2.88), Vector3(4.2, 3.86, 0.18), _jovian_materials.structure)
	_box(_cargo_bay, "ForwardBulkheadHeader", Vector3(0.0, 4.12, -2.88), Vector3(2.95, 0.62, 0.18), _jovian_materials.amber)
	# Curved interior frames expose the true structural scale without closing the
	# route. All fixtures are children of the moving ship.
	for frame_index in 4:
		var frame_z := -1.7 + float(frame_index) * 3.25
		_curve_tube(
			_cargo_bay,
			"CargoFrame%02d" % frame_index,
			PackedVector3Array([
				Vector3(-5.35, 0.72, frame_z),
				Vector3(-5.35, 4.15, frame_z),
				Vector3(0.0, 4.48, frame_z),
				Vector3(5.35, 4.15, frame_z),
				Vector3(5.35, 0.72, frame_z),
			]),
			0.085,
			_jovian_materials.hull_cool
		)
	# Four stable tie-down hardpoints and six visibly secured cargo units. The
	# central lane and door-to-cabin diagonal remain at least 2 m wide.
	for row in 2:
		for side_index in 2:
			var side := -1.0 if side_index == 0 else 1.0
			var position := Vector3(side * 3.75, 0.64, 0.25 + float(row) * 5.3)
			var hardpoint := Marker3D.new()
			hardpoint.name = ("Port" if side < 0.0 else "Starboard") + "CargoHardpoint%02d" % row
			hardpoint.position = position
			hardpoint.set_meta("hardpoint_id", StringName("cargo_%s_%02d" % ["port" if side < 0.0 else "starboard", row]))
			_cargo_bay.add_child(hardpoint)
			_cargo_hardpoints.append(hardpoint)
			_box(_cargo_bay, "CargoPallet", position + Vector3(0.0, 0.12, 0.0), Vector3(2.25, 0.22, 2.5), _jovian_materials.structure)
			_box(_cargo_bay, "CargoContainer", position + Vector3(0.0, 0.9, 0.0), Vector3(1.95, 1.3, 2.15), _jovian_materials.cargo_blue)
			for band_z in [-0.64, 0.64]:
				_box(_cargo_bay, "CargoRestraint", position + Vector3(0.0, 1.62, band_z), Vector3(2.02, 0.08, 0.1), _jovian_materials.amber)
	# Rear corner lockers add believable stowage without obstructing egress.
	for side in [-1.0, 1.0]:
		_box(_cargo_bay, "ServiceLocker", Vector3(side * 4.75, 1.52, 8.25), Vector3(1.25, 1.9, 1.15), _jovian_materials.hull_cool)
		_box(_cargo_bay, "LockerDisplay", Vector3(side * 4.1, 1.62, 8.25), Vector3(0.03, 0.38, 0.52), _jovian_materials.display)
	# Warm-neutral practicals illuminate the actual interior, not a detached set.
	for light_z in [-1.25, 2.85, 6.95]:
		_box(_cargo_bay, "CargoCeilingLight", Vector3(0.0, 4.36, light_z), Vector3(2.1, 0.05, 0.18), _jovian_materials.interior_light)
		var cargo_light := OmniLight3D.new()
		cargo_light.name = "CargoPracticalLight"
		cargo_light.position = Vector3(0.0, 4.12, light_z)
		cargo_light.light_color = Color("d7fff2")
		cargo_light.light_energy = 1.1
		cargo_light.omni_range = 6.8
		cargo_light.shadow_enabled = true
		_cargo_bay.add_child(cargo_light)


func _build_passenger_cabin() -> void:
	_passenger_cabin = Node3D.new()
	_passenger_cabin.name = "PassengerCabin"
	_passenger_cabin.set_meta("space_id", &"passenger_cabin")
	_passenger_cabin.set_meta("capacity_status", &"provisional")
	_walkable_interior.add_child(_passenger_cabin)
	_box(_passenger_cabin, "PassengerDeck", Vector3(0.0, 0.5, -5.25), Vector3(6.9, 0.18, 4.65), _jovian_materials.deck)
	_box(_passenger_cabin, "PassengerRoof", Vector3(0.0, 3.82, -5.25), Vector3(6.9, 0.16, 4.65), _jovian_materials.hull_cool)
	for side in [-1.0, 1.0]:
		_box(_passenger_cabin, "CabinSidewall", Vector3(side * 3.36, 2.15, -5.25), Vector3(0.18, 3.35, 4.6), _jovian_materials.structure)
		_box(_passenger_cabin, "CabinLightStrip", Vector3(side * 3.23, 3.46, -5.25), Vector3(0.04, 0.12, 3.55), _jovian_materials.interior_light)
		# Three side-facing seats per side keep a clear central passage to the
		# inherited cockpit. Their anchors are explicit future passenger contracts.
		for seat_index in 3:
			var seat_z := -6.55 + float(seat_index) * 1.3
			var seat_root := Node3D.new()
			seat_root.name = ("Port" if side < 0.0 else "Starboard") + "PassengerSeat%02d" % seat_index
			seat_root.position = Vector3(side * 2.62, 0.0, seat_z)
			seat_root.rotation.y = -side * PI * 0.5
			_passenger_cabin.add_child(seat_root)
			_box(seat_root, "SeatBase", Vector3(0.0, 0.88, 0.0), Vector3(0.72, 0.2, 0.82), _jovian_materials.cabin_cloth)
			_box(seat_root, "SeatBack", Vector3(0.0, 1.42, 0.36), Vector3(0.72, 0.95, 0.16), _jovian_materials.cabin_cloth, Vector3(deg_to_rad(8.0), 0.0, 0.0))
			_box(seat_root, "Harness", Vector3(0.0, 1.42, 0.25), Vector3(0.13, 0.72, 0.04), _jovian_materials.amber)
			var anchor := Marker3D.new()
			anchor.name = "PassengerAnchor"
			anchor.position = Vector3(0.0, 0.24, -0.02)
			anchor.set_meta("seat_id", StringName("passenger_%s_%02d" % ["port" if side < 0.0 else "starboard", seat_index]))
			seat_root.add_child(anchor)
			_passenger_seat_anchors.append(anchor)
	# Open frames make both forward and aft connections visually explicit.
	for bulkhead_z in [-7.48, -3.0]:
		for side in [-1.0, 1.0]:
			_box(_passenger_cabin, "CabinPortalUpright", Vector3(side * 1.45, 2.1, bulkhead_z), Vector3(0.18, 3.25, 0.2), _jovian_materials.amber)
		_box(_passenger_cabin, "CabinPortalHeader", Vector3(0.0, 3.68, bulkhead_z), Vector3(3.05, 0.18, 0.2), _jovian_materials.amber)
	_box(_passenger_cabin, "CabinStatusPanel", Vector3(0.0, 2.5, -3.13), Vector3(1.05, 0.58, 0.04), _jovian_materials.display)
	var cabin_light := OmniLight3D.new()
	cabin_light.name = "PassengerPracticalLight"
	cabin_light.position = Vector3(0.0, 3.52, -5.25)
	cabin_light.light_color = Color("e8fff6")
	cabin_light.light_energy = 0.95
	cabin_light.omni_range = 5.2
	cabin_light.shadow_enabled = true
	_passenger_cabin.add_child(cabin_light)


func _build_interior_route_and_markers() -> void:
	# A short same-level bridge joins the passenger room to the flight deck.
	_box(_walkable_interior, "CockpitConnectorDeck", Vector3(0.0, 0.5, -8.0), Vector3(2.75, 0.18, 1.45), _jovian_materials.deck)
	for side in [-1.0, 1.0]:
		_box(_walkable_interior, "CockpitConnectorRail", Vector3(side * 1.42, 1.75, -8.0), Vector3(0.12, 2.4, 1.42), _jovian_materials.structure)

	_interior_access_marker = Marker3D.new()
	_interior_access_marker.name = "InteriorAccessMarker"
	_interior_access_marker.position = Vector3(-10.05, -1.08, 3.2)
	_interior_access_marker.rotation.y = PI * 0.5
	_interior_access_marker.set_meta("route_id", &"port_cargo_ramp")
	_walkable_interior.add_child(_interior_access_marker)
	_interior_deck_marker = Marker3D.new()
	_interior_deck_marker.name = "InteriorDeckMarker"
	_interior_deck_marker.position = Vector3(-5.05, 0.64, 3.2)
	_interior_deck_marker.rotation.y = PI * 0.5
	_interior_deck_marker.set_meta("space_id", &"cargo_bay")
	_walkable_interior.add_child(_interior_deck_marker)
	_interior_exit_marker = Marker3D.new()
	_interior_exit_marker.name = "InteriorExitMarker"
	_interior_exit_marker.position = Vector3(-10.7, -1.08, 3.2)
	_interior_exit_marker.rotation.y = PI * 0.5
	_walkable_interior.add_child(_interior_exit_marker)

	# Direct CharacterBody collision shapes below make the interior physically
	# walkable; this volume drives production MovingInteriorFrame occupancy while
	# keeping every occupant in the same world-space scene.
	_occupant_volume = Area3D.new()
	_occupant_volume.name = "InteriorOccupantVolume"
	_occupant_volume.collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
	_occupant_volume.collision_mask = PhysicsLayers.PLAYER_BODY_LAYER
	_occupant_volume.monitoring = true
	_occupant_volume.monitorable = false
	_occupant_volume.set_meta("ship_local_bounds", INTERIOR_BOUNDS)
	_walkable_interior.add_child(_occupant_volume)
	var volume_shape := CollisionShape3D.new()
	volume_shape.name = "InteriorBoundsShape"
	volume_shape.position = INTERIOR_BOUNDS.get_center()
	var box := BoxShape3D.new()
	box.size = INTERIOR_BOUNDS.size
	volume_shape.shape = box
	_occupant_volume.add_child(volume_shape)


func _build_propulsion_and_gear() -> void:
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var side_name := "Port" if side < 0.0 else "Starboard"
		for vertical_index in 2:
			var engine_y := 1.15 + float(vertical_index) * 2.25
			var engine_x := side * (5.05 + float(vertical_index) * 1.35)
			var prefix := side_name + ("Lower" if vertical_index == 0 else "Upper")
			_cylinder(_jovian_visual, prefix + "EngineHousing", Vector3(engine_x, engine_y, 11.65), 0.84, 3.0, _jovian_materials.structure, Vector3(90.0, 0.0, 0.0))
			_cylinder(_jovian_visual, prefix + "EngineCollar", Vector3(engine_x, engine_y, 13.05), 1.02, 0.42, _jovian_materials.hull_cool, Vector3(90.0, 0.0, 0.0))
			_cylinder(_jovian_visual, prefix + "EngineCore", Vector3(engine_x, engine_y, 13.31), 0.57, 0.2, _jovian_materials.engine, Vector3(90.0, 0.0, 0.0))
			var plume := _cylinder(_jovian_visual, prefix + "EnginePlume", Vector3(engine_x, engine_y, 13.8), 0.38, 1.1, _jovian_materials.engine, Vector3(90.0, 0.0, 0.0))
			_engine_plumes.append(plume)
			var light := OmniLight3D.new()
			light.name = prefix + "EngineLight"
			light.position = Vector3(engine_x, engine_y, 13.45)
			light.light_color = ENGINE_AQUA
			light.light_energy = 0.0
			light.omni_range = 8.0
			light.shadow_enabled = false
			_jovian_visual.add_child(light)
			_jovian_engine_lights.append(light)

	# Four wide landing bogies support the heavier visual mass and establish a
	# stable parked contact plane at y=-1.25 relative to the ship root.
	for side in [-1.0, 1.0]:
		for z_position in [-5.8, 7.3]:
			_box(_jovian_visual, "LandingBogieStrut", Vector3(side * 4.85, -0.42, z_position), Vector3(0.34, 1.5, 0.34), _jovian_materials.dark, Vector3(0.0, 0.0, side * deg_to_rad(-7.0)))
			_box(_jovian_visual, "LandingBogieFoot", Vector3(side * 5.05, -1.14, z_position), Vector3(1.65, 0.18, 2.2), _jovian_materials.structure)
			_cylinder(_jovian_visual, "LandingDamper", Vector3(side * 4.64, -0.22, z_position), 0.13, 1.25, _jovian_materials.amber)

	# Twin defensive pulse mounts communicate capability without turning the
	# freighter into a gunship. The common weapon lifecycle uses their markers.
	for side in [-1.0, 1.0]:
		var prefix := "Port" if side < 0.0 else "Starboard"
		_cylinder(_jovian_visual, prefix + "DefensiveTurretBase", Vector3(side * 5.15, 3.72, -5.55), 0.48, 0.3, _jovian_materials.structure)
		_cylinder(_jovian_visual, prefix + "DefensivePulseBarrel", Vector3(side * 5.15, 3.76, -6.25), 0.14, 1.35, _jovian_materials.dark, Vector3(90.0, 0.0, 0.0))


func _replace_collision_and_markers() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	# Physical decks form the lower hull and support walking while landed.
	_add_box_collision("CargoDeckCollision", Vector3(0.0, 0.36, 3.15), Vector3(11.45, 0.24, 12.15))
	_add_box_collision("PassengerDeckCollision", Vector3(0.0, 0.36, -5.25), Vector3(7.0, 0.24, 4.72))
	_add_box_collision("CockpitDeckCollision", Vector3(0.0, 0.36, -8.75), Vector3(3.1, 0.24, 3.25))
	_add_box_collision("VentralHullCollision", Vector3(0.0, -0.05, -10.9), Vector3(6.25, 0.65, 6.0))
	# The port shoulder is split around the 3.9 m cargo aperture. No collision
	# volume crosses the exterior-ramp-to-deck path.
	_add_box_collision("StarboardShoulderCollision", Vector3(6.65, 2.0, 1.8), Vector3(2.85, 4.15, 19.0))
	_add_box_collision("PortForwardShoulderCollision", Vector3(-6.65, 2.0, -3.5), Vector3(2.85, 4.15, 8.45))
	_add_box_collision("PortAftShoulderCollision", Vector3(-6.65, 2.0, 7.25), Vector3(2.85, 4.15, 4.15))
	_add_box_collision("CargoRoofCollision", Vector3(0.0, 4.54, 3.15), Vector3(11.6, 0.3, 12.3))
	_add_box_collision("AftHullCollision", Vector3(0.0, 2.0, 10.75), Vector3(10.2, 3.8, 3.0))
	# Interior walls and portal wings preserve a connected central route.
	_add_box_collision("StarboardInteriorWallCollision", Vector3(5.64, 2.5, 3.15), Vector3(0.22, 3.9, 12.0))
	_add_box_collision("PortInteriorWallForwardCollision", Vector3(-5.64, 2.5, -0.9), Vector3(0.22, 3.9, 3.65))
	_add_box_collision("PortInteriorWallAftCollision", Vector3(-5.64, 2.5, 7.15), Vector3(0.22, 3.9, 4.05))
	_add_box_collision("AftPressureWallCollision", Vector3(0.0, 2.5, 9.17), Vector3(11.3, 3.9, 0.22))
	for side in [-1.0, 1.0]:
		_add_box_collision("ForwardBulkheadWingCollision", Vector3(side * 3.55, 2.5, -2.88), Vector3(4.2, 3.9, 0.22))
		_add_box_collision("PassengerSidewallCollision", Vector3(side * 3.36, 2.15, -5.25), Vector3(0.22, 3.4, 4.65))
	# The ramp is a real sloped ship-owned collider, aligned with its visual.
	_add_ramp_wedge_collision(
		"PortCargoRampCollision",
		-10.45,
		-5.725,
		-1.25,
		-1.25,
		0.48,
		3.2,
		1.7
	)

	var boarding := get_node_or_null("BoardingPoint") as Marker3D
	var exit := get_node_or_null("ExitPoint") as Marker3D
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if boarding != null:
		boarding.position = Vector3(-3.4, -0.52, -8.15)
	if exit != null:
		exit.position = Vector3(-4.7, -1.05, -8.2)
		exit.rotation.y = -PI * 0.5
	if left_muzzle != null:
		left_muzzle.position = Vector3(-5.15, 3.76, -6.95)
	if right_muzzle != null:
		right_muzzle.position = Vector3(5.15, 3.76, -6.95)
	var boarding_area := get_node_or_null("ShipBoardingArea") as Area3D
	if boarding_area != null:
		boarding_area.position = Vector3(-3.4, -0.02, -8.15)
	var camera_rig := get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.position = Vector3(0.0, 4.0, 6.5)


func _add_box_collision(
		node_name: String,
		collision_position: Vector3,
		size: Vector3,
		rotation := Vector3.ZERO
	) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.position = collision_position
	collision.rotation = rotation
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)
	return collision


func _add_ramp_wedge_collision(
		node_name: String,
		outer_x: float,
		inner_x: float,
		bottom_y: float,
		outer_top_y: float,
		inner_top_y: float,
		center_z: float,
		half_width_z: float
	) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(outer_x, bottom_y, center_z - half_width_z),
		Vector3(outer_x, outer_top_y, center_z - half_width_z),
		Vector3(inner_x, bottom_y, center_z - half_width_z),
		Vector3(inner_x, inner_top_y, center_z - half_width_z),
		Vector3(outer_x, bottom_y, center_z + half_width_z),
		Vector3(outer_x, outer_top_y, center_z + half_width_z),
		Vector3(inner_x, bottom_y, center_z + half_width_z),
		Vector3(inner_x, inner_top_y, center_z + half_width_z),
	])
	collision.shape = shape
	add_child(collision)
	return collision


func _bind_optional_interior_frame() -> void:
	_moving_interior_component = get_node_or_null("MovingInteriorFrame") as MovingInteriorFrame
	if _moving_interior_component == null:
		_moving_interior_component = MovingInteriorFrame.new()
		_moving_interior_component.name = "MovingInteriorFrame"
		add_child(_moving_interior_component)
	_moving_interior_component.set_meta("frame_id", &"jovian_walkable_interior")
	# Ship scenes build their volume after the pre-authored coordinator has run
	# `_ready`; enable automatic monitoring before configure so signal wiring and
	# existing-overlap registration are both active immediately.
	_moving_interior_component.auto_register_from_volume = true
	# PlayerController consumes MovingInteriorFrame.get_frame_gravity directly,
	# so the component's default registration options avoid double correction.
	_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
	_moving_interior_component.call_deferred("_register_existing_overlaps")


func _set_interior_operational(enabled: bool) -> void:
	if _walkable_interior != null:
		_walkable_interior.visible = enabled
	if _occupant_volume != null:
		_occupant_volume.set_deferred(&"monitoring", enabled)
		for child in _occupant_volume.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred(&"disabled", not enabled)
	if not enabled and _moving_interior_component != null:
		_moving_interior_component.clear_occupants(true, &"ship_destroyed")


func _update_jovian_presentation(delta: float) -> void:
	var telemetry := get_telemetry()
	var engine_state := StringName(telemetry.get("engine_state", &"OFFLINE"))
	var engine_level := 0.0
	if engine_state == ENGINE_STARTING:
		engine_level = 0.22 + 0.08 * sin(_elapsed_jovian * 10.0)
	elif engine_state == ENGINE_ONLINE:
		engine_level = 0.46 + clampf(velocity.length() / maxf(maximum_speed, 1.0), 0.0, 1.0) * 0.54
	var damage_presentation := get_damage_presentation()
	if is_instance_valid(damage_presentation):
		engine_level *= clampf(damage_presentation.get_engine_power_multiplier(), 0.0, 1.0)
	for plume in _engine_plumes:
		plume.visible = engine_level > 0.01
		plume.scale.z = lerpf(plume.scale.z, 0.5 + engine_level * 1.25, 1.0 - exp(-6.0 * delta))
	for light in _jovian_engine_lights:
		light.light_energy = engine_level * 2.6


func _sync_jovian_engine_presentation_immediately() -> void:
	var telemetry := get_telemetry()
	var state := StringName(telemetry.get("engine_state", ENGINE_OFFLINE))
	var active := not is_destroyed() and state in [ENGINE_STARTING, ENGINE_ONLINE]
	for plume in _engine_plumes:
		if is_instance_valid(plume):
			plume.visible = active
			if not active:
				plume.scale.z = 0.5
	for light in _jovian_engine_lights:
		if is_instance_valid(light):
			light.light_energy = 0.6 if active and state == ENGINE_STARTING else (1.2 if active else 0.0)


func request_engine_start() -> void:
	super.request_engine_start()
	_sync_jovian_engine_presentation_immediately()


func request_engine_stop(play_transition_cue: bool = true) -> void:
	super.request_engine_stop(play_transition_cue)
	_sync_jovian_engine_presentation_immediately()


func _apply_jovian_metadata() -> void:
	set_meta("jovian_light_freighter_candidate", true)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("evidence_scope", EVIDENCE_SCOPE)
	set_meta("name_to_model_status", NAME_TO_MODEL_STATUS)
	set_meta("authenticated_historical_silhouette", false)
	set_meta("connected_walkable_interior", true)
	set_meta("content_note", PROVISIONAL_NOTE)
	set_meta("weapon_class", &"freighter_defensive_pulse")
	set_meta("engine_profile", &"heavy_quad_freighter")


func _jovian_material(
		color: Color,
		metallic: float,
		roughness: float,
		emission := Color.BLACK,
		energy := 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic, 0.0, 1.0)
	material.roughness = clampf(roughness, 0.04, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _jovian_glass(color: Color) -> StandardMaterial3D:
	var material := _jovian_material(color, 0.1, 0.09, Color("17464c"), 0.16)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	return material


func _loft_hull(
		parent: Node3D,
		node_name: String,
		origin: Vector3,
		sections: PackedVector3Array,
		material: Material,
		ring_count := 24
	) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for section_index in sections.size():
		var section := sections[section_index]
		for ring_index in ring_count:
			var angle := TAU * float(ring_index) / float(ring_count)
			var cosine := cos(angle)
			var sine := sin(angle)
			var rounded_x := signf(cosine) * pow(absf(cosine), 0.7)
			var rounded_y := signf(sine) * pow(absf(sine), 0.7)
			tool.set_uv(Vector2(float(ring_index) / float(ring_count), float(section_index) / float(maxi(1, sections.size() - 1))))
			tool.add_vertex(Vector3(section.x * rounded_x, section.y * rounded_y, section.z))
	for section_index in sections.size() - 1:
		for ring_index in ring_count:
			var next_ring := (ring_index + 1) % ring_count
			var current := section_index * ring_count + ring_index
			var current_next := section_index * ring_count + next_ring
			var following := (section_index + 1) * ring_count + ring_index
			var following_next := (section_index + 1) * ring_count + next_ring
			tool.add_index(current)
			tool.add_index(following)
			tool.add_index(following_next)
			tool.add_index(current)
			tool.add_index(following_next)
			tool.add_index(current_next)
	var front_center := sections.size() * ring_count
	tool.add_vertex(Vector3(0.0, 0.0, sections[0].z))
	var rear_center := front_center + 1
	tool.add_vertex(Vector3(0.0, 0.0, sections[sections.size() - 1].z))
	for ring_index in ring_count:
		var next_ring := (ring_index + 1) % ring_count
		tool.add_index(front_center)
		tool.add_index(next_ring)
		tool.add_index(ring_index)
		var rear_base := (sections.size() - 1) * ring_count
		tool.add_index(rear_center)
		tool.add_index(rear_base + ring_index)
		tool.add_index(rear_base + next_ring)
	tool.generate_normals()
	tool.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = origin
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance


func _planform_surface(
		parent: Node3D,
		node_name: String,
		outline: PackedVector3Array,
		thickness: float,
		material: Material
	) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var half_thickness := thickness * 0.5
	for point in outline:
		tool.add_vertex(point + Vector3.UP * half_thickness)
	for point in outline:
		tool.add_vertex(point - Vector3.UP * half_thickness)
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		tool.add_index(triangle[0])
		tool.add_index(triangle[1])
		tool.add_index(triangle[2])
		tool.add_index(outline.size() + triangle[0])
		tool.add_index(outline.size() + triangle[2])
		tool.add_index(outline.size() + triangle[1])
	for index in outline.size():
		var next := (index + 1) % outline.size()
		tool.add_index(index)
		tool.add_index(outline.size() + index)
		tool.add_index(outline.size() + next)
		tool.add_index(index)
		tool.add_index(outline.size() + next)
		tool.add_index(next)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance


func _curve_tube(
		parent: Node3D,
		node_name: String,
		points: PackedVector3Array,
		radius: float,
		material: Material
	) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	for index in points.size() - 1:
		var direction := points[index + 1] - points[index]
		var segment := _cylinder(root, "Segment%02d" % index, (points[index] + points[index + 1]) * 0.5, radius, direction.length(), material)
		segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
	for point in points:
		_sphere(root, "CurveJoint", point, radius, material)
	return root


func _ramp_wedge(
		parent: Node3D,
		node_name: String,
		outer_x: float,
		inner_x: float,
		bottom_y: float,
		outer_top_y: float,
		inner_top_y: float,
		center_z: float,
		half_width_z: float,
		material: Material
	) -> MeshInstance3D:
	var points := PackedVector3Array([
		Vector3(outer_x, bottom_y, center_z - half_width_z),
		Vector3(outer_x, outer_top_y, center_z - half_width_z),
		Vector3(inner_x, bottom_y, center_z - half_width_z),
		Vector3(inner_x, inner_top_y, center_z - half_width_z),
		Vector3(outer_x, bottom_y, center_z + half_width_z),
		Vector3(outer_x, outer_top_y, center_z + half_width_z),
		Vector3(inner_x, bottom_y, center_z + half_width_z),
		Vector3(inner_x, inner_top_y, center_z + half_width_z),
	])
	# Each face is wound outward. The cross-section retains a slim outer lip, so
	# the convex shape remains numerically stable while meeting the apron cleanly.
	var triangles := PackedInt32Array([
		1, 3, 7, 1, 7, 5, # walkable slope
		0, 4, 6, 0, 6, 2, # flat underside
		0, 1, 5, 0, 5, 4, # outer lip
		2, 6, 7, 2, 7, 3, # inner riser
		0, 2, 3, 0, 3, 1, # forward edge
		4, 5, 7, 4, 7, 6, # aft edge
	])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for index in triangles:
		var point := points[index]
		tool.set_uv(Vector2(
			inverse_lerp(outer_x, inner_x, point.x),
			inverse_lerp(center_z - half_width_z, center_z + half_width_z, point.z)
		))
		tool.add_vertex(point)
	tool.generate_normals()
	tool.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance
