class_name TravellingBoltProjectile
extends Node3D

## Bounded, count-capped travel and presentation pool for slow visible bolts.
##
## What this component owns:
##   * one preallocated, fixed-size pool of bolt visuals (mesh + light per slot)
##   * each live bolt's world-space position and elapsed flight
##   * a cheap, non-committing detection sweep that tells the authority *where*
##     the bolt got to on the frame it stops
##
## What this component deliberately does not own, and cannot:
##   * damage, range, speed, lifetime, radius or faction. Every one of those is
##     read back from the authority-issued flight ticket, never from the caller.
##   * the hit decision. The detection sweep only nominates a terminal segment;
##     `LiveCombatAuthority.resolve_projectile_arrival()` re-sweeps that segment
##     on the one `CombatResolver` and is the sole owner of the damage commit,
##     the faction policy, the replay sequence and the destroyed-epoch quarantine.
##
## Steady-state allocation: none. Slots, meshes, materials and lights are built
## once; launching, advancing and retiring a bolt mutates retained state only.
## Bolt materials are immutable and shared process-wide, like the pulse pool's.
##
## Evidence status: modern_interpretation. No original Keth Shipyards craft,
## weapon, tactic, or class name is authenticated or claimed by this component.

signal bolt_launched(record: Dictionary)
signal bolt_resolved(record: Dictionary, result: Dictionary)
signal bolt_abandoned(record: Dictionary, reason: StringName)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"travelling-bolt-projectile"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"

const PhysicsLayerContract := preload("res://scripts/core/physics_layers.gd")

const DEFAULT_POOL_CAPACITY := 2
const MAX_POOL_CAPACITY := 6
const MESHES_PER_SLOT := 2
const LIGHTS_PER_SLOT := 1

## Bolt silhouette. The core is the bright head; the trail is a stretched
## emissive sleeve dragged behind it along the flight axis.
const CORE_LENGTH_SCALE := 2.2
const TRAIL_LENGTH_METERS := 9.0
const REDUCED_FLASH_TRAIL_LENGTH_METERS := 3.6
const TRAIL_WIDTH_SCALE := 0.42
const LIGHT_RANGE_SCALE := 7.5
const LIGHT_ENERGY := 3.4
const CORE_EMISSION_ENERGY := 5.6
const REDUCED_FLASH_CORE_EMISSION_ENERGY := 1.6
const TRAIL_EMISSION_ENERGY := 2.6
const REDUCED_FLASH_TRAIL_EMISSION_ENERGY := 0.9
const TRAIL_TRANSPARENCY := 0.34
const REDUCED_FLASH_TRAIL_TRANSPARENCY := 0.66

## Matches `StandoffPicketOpponent.LANCE_MAGENTA` / `LANCE_VIOLET` and the pulse
## pool's magenta style so the bolt reads as the same weapon family in flight,
## on arrival and in the muzzle flash.
const BOLT_CORE_COLOR := Color("ff54d7")
const BOLT_TRAIL_COLOR := Color("8a5bff")

const CONTENT_NOTE := (
	"The bolt silhouette, trail length, palette, light falloff and pooling policy "
	+ "are an original modern presentation treatment. They do not claim to "
	+ "reproduce an authenticated historical Keth Shipyards weapon effect."
)

## Immutable and identical for every instance, exactly like the pulse pool's
## catalog. Only Resource identities are shared; every node, slot dictionary and
## lifecycle flag below stays owned by this instance.
static var _process_material_catalog: Dictionary = {}
static var _process_material_catalog_build_count := 0

@export_range(1, MAX_POOL_CAPACITY, 1) var pool_capacity := DEFAULT_POOL_CAPACITY
@export var presentation_enabled := true

var _built := false
var _reduced_flash := false
var _presentation_enabled := true
var _slots: Array[Dictionary] = []
var _core_mesh: Mesh
var _trail_mesh: Mesh
var _launched_count := 0
var _resolved_count := 0
var _abandoned_count := 0
var _rejected_count := 0

## Preallocated so the per-step detection sweep never allocates.
var _detection_query := PhysicsRayQueryParameters3D.new()
var _detection_exclusions: Array[RID] = []

var _authority: LiveCombatAuthority


func _ready() -> void:
	_build_pool()
	_presentation_enabled = presentation_enabled
	_apply_slot_visibility()
	# An empty pool costs nothing per frame: physics processing is switched on by
	# the first launch and off again by the last arrival.
	set_physics_process(false)


func _exit_tree() -> void:
	abandon_all(&"tree_exit")


func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for slot_index in _slots.size():
		_advance_slot(slot_index, delta)


# --------------------------------------------------------------- binding ----

## Binds the one server-owned combat authority. No second resolver, damage store
## or sequence ledger is created here or anywhere else in this component.
func bind_authority(authority: LiveCombatAuthority) -> void:
	_authority = authority


func get_bound_authority() -> LiveCombatAuthority:
	return _authority if is_instance_valid(_authority) else null


# ------------------------------------------------------------- lifecycle ----

## Asks the authority to open a flight, then, only if the authority accepted,
## occupies one pool slot with the ticket's own envelope.
func launch(
		source_entity: Node3D,
		weapon_id: StringName,
		origin: Vector3,
		direction: Vector3,
		presentation_receipt_id: int = -1
	) -> Dictionary:
	if not _built:
		_build_pool()
	var authority := get_bound_authority()
	if authority == null:
		_rejected_count += 1
		return {"accepted": false, "status": &"authority_unavailable", "flight_id": 0}.duplicate(true)
	var slot_index := _find_free_slot()
	if slot_index < 0:
		_rejected_count += 1
		return {"accepted": false, "status": &"pool_saturated", "flight_id": 0}.duplicate(true)
	var ticket := authority.launch_projectile(source_entity, weapon_id, origin, direction)
	if not bool(ticket.get("accepted", false)):
		_rejected_count += 1
		return ticket
	var slot: Dictionary = _slots[slot_index]
	slot["active"] = true
	slot["flight_id"] = int(ticket.get("flight_id", 0))
	slot["source"] = weakref(source_entity)
	slot["weapon_id"] = weapon_id
	slot["origin"] = origin
	slot["direction"] = (ticket.get("launch_direction", direction) as Vector3)
	slot["position"] = origin
	slot["previous_position"] = origin
	slot["speed"] = float(ticket.get("speed", 0.0))
	slot["lifetime"] = float(ticket.get("lifetime", 0.0))
	slot["radius"] = float(ticket.get("radius", 0.0))
	slot["range"] = float(ticket.get("range", 0.0))
	slot["elapsed"] = 0.0
	slot["travelled"] = 0.0
	slot["receipt_id"] = presentation_receipt_id
	var exclusions := slot.get("exclusions") as Array[RID]
	exclusions.clear()
	_append_collision_rids(source_entity, exclusions)
	_launched_count += 1
	set_physics_process(true)
	_refresh_slot_visual(slot_index)
	var record := _slot_record(slot)
	bolt_launched.emit(record)
	return {
		"accepted": true,
		"status": &"launched",
		"flight_id": int(slot.flight_id),
		"slot_index": slot_index,
		"record": record,
	}.duplicate(true)


## Retires every live bolt without inventing a resolver event.
func abandon_all(reason: StringName = &"abandoned") -> int:
	var abandoned := 0
	for slot_index in _slots.size():
		if _abandon_slot(slot_index, reason):
			abandoned += 1
	return abandoned


## Retires only the bolts fired by one source. Used when a single craft leaves
## play while the rest of the encounter continues.
func abandon_source_bolts(source_entity: Node, reason: StringName = &"source_retired") -> int:
	var abandoned := 0
	for slot_index in _slots.size():
		var slot: Dictionary = _slots[slot_index]
		if not bool(slot.get("active", false)):
			continue
		var source_reference: WeakRef = slot.get("source") as WeakRef
		if source_reference == null or source_reference.get_ref() != source_entity:
			continue
		if _abandon_slot(slot_index, reason):
			abandoned += 1
	return abandoned


# ---------------------------------------------------------- presentation ----

func set_presentation_enabled(enabled: bool) -> void:
	_presentation_enabled = enabled
	_apply_slot_visibility()


func is_presentation_enabled() -> bool:
	return _presentation_enabled


## Accessibility seam, shaped exactly like `BomberPayloadPresentation`'s. Reduced
## flash keeps the bolt fully readable — the player must still see it coming —
## while dropping the emissive punch, the dynamic light and most of the trail
## length, which are the parts that flicker past the camera.
func set_reduced_flash_enabled(enabled: bool) -> Dictionary:
	_reduced_flash = enabled
	for slot_index in _slots.size():
		_refresh_slot_visual(slot_index)
	return get_presentation_profile_snapshot()


func is_reduced_flash_enabled() -> bool:
	return _reduced_flash


func get_presentation_profile_snapshot() -> Dictionary:
	return {
		"reduced_flash": _reduced_flash,
		"reduced_flash_policy": &"readable_bolt_no_dynamic_light_short_trail",
		"presentation_enabled": _presentation_enabled,
		"trail_length_meters": (
			REDUCED_FLASH_TRAIL_LENGTH_METERS if _reduced_flash else TRAIL_LENGTH_METERS
		),
		"core_emission_energy": (
			REDUCED_FLASH_CORE_EMISSION_ENERGY if _reduced_flash else CORE_EMISSION_ENERGY
		),
		"trail_emission_energy": (
			REDUCED_FLASH_TRAIL_EMISSION_ENERGY if _reduced_flash else TRAIL_EMISSION_ENERGY
		),
		"dynamic_light_enabled": not _reduced_flash,
	}.duplicate(true)


# ------------------------------------------------------------- accessors ----

func get_component_id() -> StringName:
	return COMPONENT_ID


func get_pool_capacity() -> int:
	return _slots.size()


func get_active_bolt_count() -> int:
	var active := 0
	for slot: Dictionary in _slots:
		if bool(slot.get("active", false)):
			active += 1
	return active


func get_active_bolt_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for slot: Dictionary in _slots:
		if bool(slot.get("active", false)):
			records.append(_slot_record(slot))
	return records


func get_statistics() -> Dictionary:
	return {
		"launched": _launched_count,
		"resolved": _resolved_count,
		"abandoned": _abandoned_count,
		"rejected": _rejected_count,
		"active": get_active_bolt_count(),
		"capacity": _slots.size(),
	}.duplicate(true)


func get_evidence_metadata() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"claims_historical_class_name": false,
		"content_note": CONTENT_NOTE,
	}.duplicate(true)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _built:
		errors.append("bolt pool has not been built")
	if _slots.size() < 1 or _slots.size() > MAX_POOL_CAPACITY:
		errors.append("bolt pool capacity is outside the fixed bound")
	for slot: Dictionary in _slots:
		if not bool(slot.get("active", false)):
			continue
		if int(slot.get("flight_id", 0)) <= 0:
			errors.append("an active bolt has no authority flight ticket")
		if float(slot.get("speed", 0.0)) <= 0.0 or float(slot.get("lifetime", 0.0)) <= 0.0:
			errors.append("an active bolt has no authored travel envelope")
	if _process_material_catalog_build_count > 1:
		errors.append("immutable bolt materials must be built exactly once per process")
	for slot: Dictionary in _slots:
		var holder := slot.get("holder") as Node3D
		if not is_instance_valid(holder):
			errors.append("a bolt slot lost its retained presentation node")
			continue
		if holder.get_child_count() != MESHES_PER_SLOT + LIGHTS_PER_SLOT:
			errors.append("a bolt slot does not hold its fixed mesh and light budget")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"statistics": get_statistics(),
		"presentation": get_presentation_profile_snapshot(),
		"evidence": get_evidence_metadata(),
		"authority": {
			"damage": false,
			"raycast_commit": false,
			"faction_policy": false,
			"replay_sequence": false,
			"travel": true,
			"presentation": true,
		},
	}.duplicate(true)


# -------------------------------------------------------------- internals ----

func _advance_slot(slot_index: int, delta: float) -> void:
	var slot: Dictionary = _slots[slot_index]
	if not bool(slot.get("active", false)):
		return
	var authority := get_bound_authority()
	var flight_id := int(slot.flight_id)
	if authority == null:
		_abandon_slot(slot_index, &"authority_unavailable")
		return
	# The destroyed-source epoch quarantine is asked every step, not only on
	# arrival: a picket that dies mid-flight and is regenerated before the bolt
	# lands must never have that bolt resolved against its new healthy epoch.
	var liveness := authority.observe_projectile(flight_id)
	if liveness != &"live":
		_terminate_slot(slot_index, slot.position as Vector3, &"quarantined")
		return

	var speed := float(slot.speed)
	var remaining_lifetime := maxf(0.0, float(slot.lifetime) - float(slot.elapsed))
	var remaining_range := maxf(0.0, float(slot.range) - float(slot.travelled))
	var step := minf(delta, remaining_lifetime)
	var advance_distance := minf(speed * step, remaining_range)
	var previous_position := slot.position as Vector3
	# Positions are derived analytically from the scalar distance travelled
	# rather than accumulated per step, so a bolt that reaches its authored range
	# is exactly that far from its muzzle and never drifts past the envelope the
	# authority will measure it against.
	var travelled := float(slot.travelled) + advance_distance
	var next_position := (slot.origin as Vector3) + (slot.direction as Vector3) * travelled
	slot["previous_position"] = previous_position
	slot["position"] = next_position
	slot["elapsed"] = float(slot.elapsed) + step
	slot["travelled"] = travelled
	_refresh_slot_visual(slot_index)

	# Detection only. The segment nominated here is re-swept authoritatively by
	# the resolver, which owns occlusion, faction policy and the damage commit.
	var contact := _detect_contact(slot, previous_position, next_position)
	if contact.is_finite():
		_terminate_slot(slot_index, contact, &"impact")
		return
	if float(slot.elapsed) >= float(slot.lifetime) - 0.000001:
		_terminate_slot(slot_index, next_position, &"lifetime")
		return
	if float(slot.travelled) >= float(slot.range) - 0.000001:
		_terminate_slot(slot_index, next_position, &"range")


func _detect_contact(
		slot: Dictionary,
		previous_position: Vector3,
		next_position: Vector3
	) -> Vector3:
	if not is_inside_tree() or get_world_3d() == null:
		return Vector3.INF
	var travel := next_position - previous_position
	if not travel.is_finite() or travel.length_squared() <= 0.000001:
		return Vector3.INF
	# The leading edge of the bolt, not its centre, is what makes contact.
	var probe_end := next_position + travel.normalized() * float(slot.radius)
	_detection_query.from = previous_position
	_detection_query.to = probe_end
	_detection_query.collision_mask = PhysicsLayerContract.HITSCAN_QUERY_MASK
	# Captured once at launch: the firing hull cannot shoot itself, and rebuilding
	# the exclusion list every physics step would allocate in steady state.
	_detection_query.exclude = slot.get("exclusions", _detection_exclusions)
	_detection_query.collide_with_areas = true
	_detection_query.collide_with_bodies = true
	_detection_query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(_detection_query)
	if hit.is_empty():
		return Vector3.INF
	var position: Variant = hit.get("position", Vector3.INF)
	if position is Vector3 and (position as Vector3).is_finite():
		return position as Vector3
	return Vector3.INF


## The only place a bolt ends. Every terminal path — contact, lifetime, range —
## goes through the one authority call, so a bolt that reaches its flight
## ceiling without touching anything is still an authoritative resolved miss.
func _terminate_slot(slot_index: int, terminal_position: Vector3, reason: StringName) -> void:
	var slot: Dictionary = _slots[slot_index]
	var record := _slot_record(slot)
	record["terminal_reason"] = reason
	record["terminal_position"] = terminal_position
	var authority := get_bound_authority()
	var flight_id := int(slot.flight_id)
	var segment_start := slot.previous_position as Vector3
	if segment_start.distance_to(terminal_position) <= 0.000001:
		# A degenerate final step still needs a real displacement to sweep.
		segment_start = terminal_position - (slot.direction as Vector3) * maxf(
			float(slot.radius), 0.05
		)
	var source_reference: WeakRef = slot.get("source") as WeakRef
	var source_entity := source_reference.get_ref() as Node3D if source_reference != null else null
	_release_slot(slot_index)
	if authority == null:
		_abandoned_count += 1
		bolt_abandoned.emit(record, &"authority_unavailable")
		return
	var result := authority.resolve_projectile_arrival(
		source_entity,
		flight_id,
		segment_start,
		terminal_position,
		int(record.get("receipt_id", -1))
	)
	_resolved_count += 1
	bolt_resolved.emit(record, result)


func _abandon_slot(slot_index: int, reason: StringName) -> bool:
	var slot: Dictionary = _slots[slot_index]
	if not bool(slot.get("active", false)):
		return false
	var record := _slot_record(slot)
	var authority := get_bound_authority()
	var flight_id := int(slot.flight_id)
	_release_slot(slot_index)
	if authority != null:
		authority.abandon_projectile(flight_id)
	_abandoned_count += 1
	bolt_abandoned.emit(record, reason)
	return true


func _release_slot(slot_index: int) -> void:
	var slot: Dictionary = _slots[slot_index]
	slot["active"] = false
	slot["flight_id"] = 0
	slot["source"] = null
	slot["receipt_id"] = -1
	_hide_slot(slot)
	if _find_free_slot() >= 0 and get_active_bolt_count() == 0:
		set_physics_process(false)


func _slot_record(slot: Dictionary) -> Dictionary:
	return {
		"flight_id": int(slot.get("flight_id", 0)),
		"weapon_id": slot.get("weapon_id", &""),
		"origin": slot.get("origin", Vector3.INF),
		"direction": slot.get("direction", Vector3.ZERO),
		"position": slot.get("position", Vector3.INF),
		"speed": float(slot.get("speed", 0.0)),
		"lifetime": float(slot.get("lifetime", 0.0)),
		"radius": float(slot.get("radius", 0.0)),
		"range": float(slot.get("range", 0.0)),
		"elapsed": float(slot.get("elapsed", 0.0)),
		"travelled": float(slot.get("travelled", 0.0)),
		"receipt_id": int(slot.get("receipt_id", -1)),
	}.duplicate(true)


func _find_free_slot() -> int:
	for slot_index in _slots.size():
		if not bool((_slots[slot_index] as Dictionary).get("active", false)):
			return slot_index
	return -1


func _build_pool() -> void:
	if _built:
		return
	var catalog := _material_catalog()
	_core_mesh = catalog.core_mesh as Mesh
	_trail_mesh = catalog.trail_mesh as Mesh
	var capacity := clampi(pool_capacity, 1, MAX_POOL_CAPACITY)
	for slot_index in capacity:
		var holder := Node3D.new()
		holder.name = "Bolt%d" % slot_index
		# World-space travel: the pool may hang off a moving craft, but a bolt in
		# flight belongs to the world, not to the ship that fired it.
		holder.top_level = true
		holder.visible = false
		add_child(holder)
		var trail := MeshInstance3D.new()
		trail.name = "Trail"
		trail.mesh = _trail_mesh
		trail.material_override = catalog.trail_material as Material
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(trail)
		var core := MeshInstance3D.new()
		core.name = "Core"
		core.mesh = _core_mesh
		core.material_override = catalog.core_material as Material
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(core)
		var light := OmniLight3D.new()
		light.name = "Glow"
		light.light_color = BOLT_CORE_COLOR
		light.light_energy = LIGHT_ENERGY
		light.omni_range = 1.0
		light.shadow_enabled = false
		holder.add_child(light)
		_slots.append({
			"active": false,
			"flight_id": 0,
			"source": null,
			"weapon_id": &"",
			"origin": Vector3.INF,
			"direction": Vector3.FORWARD,
			"position": Vector3.INF,
			"previous_position": Vector3.INF,
			"speed": 0.0,
			"lifetime": 0.0,
			"radius": 0.0,
			"range": 0.0,
			"elapsed": 0.0,
			"travelled": 0.0,
			"receipt_id": -1,
			"exclusions": [] as Array[RID],
			"holder": holder,
			"core": core,
			"trail": trail,
			"light": light,
		})
	_built = true


func _material_catalog() -> Dictionary:
	if not _process_material_catalog.is_empty():
		return _process_material_catalog
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = BOLT_CORE_COLOR
	core_material.emission_enabled = true
	core_material.emission = BOLT_CORE_COLOR
	core_material.emission_energy_multiplier = CORE_EMISSION_ENERGY
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	core_material.disable_receive_shadows = true
	var reduced_core_material := StandardMaterial3D.new()
	reduced_core_material.albedo_color = BOLT_CORE_COLOR
	reduced_core_material.emission_enabled = true
	reduced_core_material.emission = BOLT_CORE_COLOR
	reduced_core_material.emission_energy_multiplier = REDUCED_FLASH_CORE_EMISSION_ENERGY
	reduced_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reduced_core_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	reduced_core_material.disable_receive_shadows = true
	var trail_material := StandardMaterial3D.new()
	trail_material.albedo_color = BOLT_TRAIL_COLOR
	trail_material.emission_enabled = true
	trail_material.emission = BOLT_TRAIL_COLOR
	trail_material.emission_energy_multiplier = TRAIL_EMISSION_ENERGY
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	trail_material.disable_receive_shadows = true
	var reduced_trail_material := StandardMaterial3D.new()
	reduced_trail_material.albedo_color = BOLT_TRAIL_COLOR
	reduced_trail_material.emission_enabled = true
	reduced_trail_material.emission = BOLT_TRAIL_COLOR
	reduced_trail_material.emission_energy_multiplier = REDUCED_FLASH_TRAIL_EMISSION_ENERGY
	reduced_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reduced_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reduced_trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	reduced_trail_material.disable_receive_shadows = true
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.5
	core_mesh.height = 1.0
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	var trail_mesh := CylinderMesh.new()
	trail_mesh.top_radius = 0.5
	trail_mesh.bottom_radius = 0.06
	trail_mesh.height = 1.0
	trail_mesh.radial_segments = 6
	trail_mesh.rings = 0
	_process_material_catalog = {
		"core_material": core_material,
		"trail_material": trail_material,
		"reduced_core_material": reduced_core_material,
		"reduced_trail_material": reduced_trail_material,
		"core_mesh": core_mesh,
		"trail_mesh": trail_mesh,
	}
	_process_material_catalog_build_count += 1
	return _process_material_catalog


func _refresh_slot_visual(slot_index: int) -> void:
	var slot: Dictionary = _slots[slot_index]
	var holder := slot.holder as Node3D
	if not is_instance_valid(holder):
		return
	if not bool(slot.get("active", false)) or not _presentation_enabled:
		holder.visible = false
		return
	var position := slot.position as Vector3
	if not position.is_finite():
		holder.visible = false
		return
	var radius := maxf(float(slot.radius), 0.05)
	var direction := slot.direction as Vector3
	holder.visible = true
	holder.global_position = position
	holder.global_basis = _basis_for_forward(direction)
	var catalog := _material_catalog()
	var core := slot.core as MeshInstance3D
	if is_instance_valid(core):
		core.scale = Vector3(radius * 2.0, radius * 2.0, radius * 2.0 * CORE_LENGTH_SCALE)
		core.position = Vector3.ZERO
		core.material_override = (
			catalog.reduced_core_material if _reduced_flash else catalog.core_material
		) as Material
	var trail_length := (
		REDUCED_FLASH_TRAIL_LENGTH_METERS if _reduced_flash else TRAIL_LENGTH_METERS
	)
	var trail := slot.trail as MeshInstance3D
	if is_instance_valid(trail):
		# The cylinder's own axis is +Y; the holder's forward is -Z.
		trail.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
		trail.scale = Vector3(radius * 2.0 * TRAIL_WIDTH_SCALE, trail_length, radius * 2.0 * TRAIL_WIDTH_SCALE)
		trail.position = Vector3(0.0, 0.0, trail_length * 0.5)
		trail.transparency = (
			REDUCED_FLASH_TRAIL_TRANSPARENCY if _reduced_flash else TRAIL_TRANSPARENCY
		)
		trail.material_override = (
			catalog.reduced_trail_material if _reduced_flash else catalog.trail_material
		) as Material
	var light := slot.light as OmniLight3D
	if is_instance_valid(light):
		# Reduced flash keeps the bolt readable but removes the moving dynamic
		# light, which is the part that strobes the whole cockpit as it passes.
		light.visible = not _reduced_flash
		light.omni_range = radius * LIGHT_RANGE_SCALE
		light.light_energy = LIGHT_ENERGY


func _apply_slot_visibility() -> void:
	for slot_index in _slots.size():
		_refresh_slot_visual(slot_index)


func _hide_slot(slot: Dictionary) -> void:
	var holder := slot.holder as Node3D
	if is_instance_valid(holder):
		holder.visible = false


func _basis_for_forward(forward: Vector3) -> Basis:
	var direction := forward
	if not direction.is_finite() or direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var up := Vector3.UP
	if absf(direction.dot(up)) > 0.999:
		up = Vector3.RIGHT
	return Basis.looking_at(direction, up)


func _append_collision_rids(node: Node, output: Array[RID]) -> void:
	if not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		var rid := (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not output.has(rid):
			output.append(rid)
	for child in node.get_children():
		_append_collision_rids(child, output)
