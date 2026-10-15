class_name CinderConvoyThreat
extends Node3D

## One physical attacker and tender hurtbox for the production Emberline sortie.
## The shared resolver owns every hit; this node owns only placement and timing.
## The raider fires slow red travelling bolts through the authority's projectile
## flight ledger, so the player sees each shot cross to the tender and can put
## their hull in the way or kill the raider before the bolt lands.

signal tender_destroyed(generation: int)
signal tender_damaged(generation: int, current: float, maximum: float)
signal attacker_damaged(generation: int, current: float)

const PhysicsLayers := preload("res://scripts/core/physics_layers.gd")
const ATTACKER_SOURCE_ID := 2141
const ATTACKER_FACTION: StringName = &"range_defence"
const TENDER_FACTION: StringName = &"shipyard_flight_test"
const WEAPON_ID: StringName = &"emberline_raider_pulse"
## Authored travel envelope: 48 m/s for 0.875 s is exactly the 42 m range, so a
## bolt takes roughly half a second to cross the ~20 m to the tender.
const BOLT_SPEED := 48.0
const BOLT_LIFETIME := 0.875
const BOLT_RADIUS := 0.55
const WEAPON_PROFILE := {WEAPON_ID: {
	"range": 42.0,
	"damage": 30.0,
	"origin_tolerance": 3.0,
	"projectile_speed": BOLT_SPEED,
	"projectile_lifetime": BOLT_LIFETIME,
	"projectile_radius": BOLT_RADIUS,
}}
## Upper bound on the lead estimate so a route snap never throws a bolt wide.
const MAX_LEAD_SPEED := 60.0
const ATTACK_INTERVAL := 1.5
const FIRST_ATTACK_DELAY := 3.0
const ATTACKER_OFFSET := Vector3(17.0, 8.0, -3.0)
const PERSISTENCE_SCHEMA_VERSION := 1
const MAX_PERSISTED_COUNTER := 9_007_199_254_740_991

# Immutable visual resources are shared by the host and remote visual clones.
static var _raider_meshes: Dictionary = {}
static var _raider_material: StandardMaterial3D

var _host: CinderConvoyEscortHost
var _authority: LiveCombatAuthority
var _attacker: Area3D
var _attacker_health: Damageable
var _tender: Area3D
var _tender_health: Damageable
var _generation := 0
var _active := false
var _attack_clock := 0.0
var _shots_fired := 0
var _registration_count := 0
var _restoring := false
var _bolts: RaiderBoltPool
var _last_tender_position := Vector3.INF
var _tender_velocity := Vector3.ZERO


## The shared travelling-bolt pool, re-tinted Emberline red and stepped on the
## convoy's own clock instead of free-running physics, so bolt travel pauses and
## resumes exactly with the escort that owns it.
class RaiderBoltPool extends TravellingBoltProjectile:
	const RAIDER_CORE_COLOR := Color("ff3b2a")
	const RAIDER_TRAIL_COLOR := Color("b3160c")
	static var _raider_catalog: Dictionary = {}

	func _physics_process(_delta: float) -> void:
		pass

	func step(delta: float) -> void:
		if not is_finite(delta) or delta <= 0.0:
			return
		for slot_index in _slots.size():
			_advance_slot(slot_index, delta)

	func _build_pool() -> void:
		if _built:
			return
		super._build_pool()
		for slot: Dictionary in _slots:
			var light := slot.get("light") as OmniLight3D
			if is_instance_valid(light):
				light.light_color = RAIDER_CORE_COLOR

	func _material_catalog() -> Dictionary:
		if not _raider_catalog.is_empty():
			return _raider_catalog
		var shared := super._material_catalog()
		var tinted := shared.duplicate()
		for key: String in ["core_material", "reduced_core_material"]:
			var core := (shared[key] as StandardMaterial3D).duplicate() as StandardMaterial3D
			core.albedo_color = RAIDER_CORE_COLOR
			core.emission = RAIDER_CORE_COLOR
			tinted[key] = core
		for key: String in ["trail_material", "reduced_trail_material"]:
			var trail := (shared[key] as StandardMaterial3D).duplicate() as StandardMaterial3D
			trail.albedo_color = RAIDER_TRAIL_COLOR
			trail.emission = RAIDER_TRAIL_COLOR
			tinted[key] = trail
		_raider_catalog = tinted
		return _raider_catalog


func configure(host: CinderConvoyEscortHost, authority: LiveCombatAuthority) -> void:
	_host = host
	_authority = authority
	if _attacker == null:
		_attacker = _make_target("EmberlineRaider", Vector3(4.0, 2.5, 5.0), Color("dd5c4d"), ATTACKER_FACTION)
		_attacker_health = _attacker.get_node(^"Damageable") as Damageable
		_attacker_health.maximum_health = 35.0
		_attacker_health.damage_applied.connect(_on_attacker_damaged)
		_attacker_health.destroyed.connect(_on_attacker_destroyed)
		_tender = _make_target("EmberlineTenderHurtbox", Vector3(4.8, 2.0, 9.8), Color.TRANSPARENT, TENDER_FACTION, false)
		_tender_health = _tender.get_node(^"Damageable") as Damageable
		_tender_health.maximum_health = 75.0
		_tender_health.damage_applied.connect(_on_tender_damaged)
		_tender_health.destroyed.connect(_on_tender_destroyed)
	if _bolts == null:
		_bolts = RaiderBoltPool.new() as RaiderBoltPool
		_bolts.name = "EmberlineRaiderBolts"
		_bolts.pool_capacity = 3
		add_child(_bolts)
	_bolts.bind_authority(_authority)
	_retire()


func start(generation: int) -> bool:
	if _active or generation < 1 or not is_instance_valid(_host) or not is_instance_valid(_authority):
		return false
	_generation = generation
	_attack_clock = -FIRST_ATTACK_DELAY
	_shots_fired = 0
	_bolts.abandon_all(&"convoy_restart")
	_bolts.bind_authority(_authority)
	_last_tender_position = Vector3.INF
	_tender_velocity = Vector3.ZERO
	_attacker_health.reset_health()
	_tender_health.reset_health()
	_sync_positions()
	_attacker.visible = true
	_tender.visible = true
	_attacker.collision_layer = PhysicsLayers.TARGET
	_tender.collision_layer = PhysicsLayers.TARGET
	if not _authority.register_source(_attacker, ATTACKER_SOURCE_ID, ATTACKER_FACTION, WEAPON_PROFILE):
		_retire()
		return false
	_registration_count += 1
	_active = true
	return true


func advance(delta: float, generation: int) -> void:
	if not _active or generation != _generation or not is_finite(delta) or delta <= 0.0:
		return
	# Bolts fly first, against the hurtbox the physics server published at the
	# last transform flush. Moving the tender before sweeping would test a bolt
	# against a pose the query space cannot see until the next flush.
	_bolts.step(delta)
	_sync_positions()
	_sample_tender_velocity(delta)
	if _attacker_health.is_destroyed() or _tender_health.is_destroyed():
		return
	_attack_clock += delta
	if _attack_clock >= 0.0:
		# One shot per caller tick prevents a large catch-up delta from
		# manufacturing repeated launches before the player gets a new sample.
		_attack_clock -= ATTACK_INTERVAL
		var muzzle := _attacker.global_position
		# Damage is committed only by the authority, when the bolt's terminal
		# segment reaches something on a later tick.
		var launch := _bolts.launch(_attacker, WEAPON_ID, muzzle, _lead_direction(muzzle, delta))
		if bool(launch.get("accepted", false)):
			_shots_fired += 1


func retire(generation: int) -> void:
	if generation == _generation:
		_retire()


func rebind() -> void:
	if _active and not _attacker_health.is_destroyed() and is_instance_valid(_authority) \
			and _authority.get_source_id(_attacker) != ATTACKER_SOURCE_ID:
		_authority.register_source(_attacker, ATTACKER_SOURCE_ID, ATTACKER_FACTION, WEAPON_PROFILE)
		_sync_positions()
	if is_instance_valid(_bolts):
		_bolts.bind_authority(_authority)
	_last_tender_position = Vector3.INF


func get_snapshot() -> Dictionary:
	return {
		"generation": _generation,
		"active": _active,
		"attacker_position": (
			_attacker.global_position if is_instance_valid(_attacker) and _attacker.is_inside_tree()
			else _attacker.position if is_instance_valid(_attacker) else Vector3.ZERO
		),
		"attacker_alive": _active and is_instance_valid(_attacker_health) and not _attacker_health.is_destroyed(),
		"attacker_health": _attacker_health.get_health() if is_instance_valid(_attacker_health) else 0.0,
		"tender_health": _tender_health.get_health() if is_instance_valid(_tender_health) else 0.0,
		"tender_maximum_health": _tender_health.get_maximum_health() if is_instance_valid(_tender_health) else 0.0,
		"shots_fired": _shots_fired,
		"registration_count": _registration_count,
		"bolts_in_flight": _bolts.get_active_bolt_count() if is_instance_valid(_bolts) else 0,
		"bolt_statistics": _bolts.get_statistics() if is_instance_valid(_bolts) else {},
	}.duplicate(true)


func get_attacker() -> Area3D:
	return _attacker


func get_bolt_pool() -> TravellingBoltProjectile:
	return _bolts


func capture_persistence_state() -> Dictionary:
	return {
		"schema_version": PERSISTENCE_SCHEMA_VERSION,
		"generation": _generation,
		"attacker_health": _attacker_health.get_health(),
		"tender_health": _tender_health.get_health(),
		"attack_clock": _attack_clock,
		"shots_fired": _shots_fired,
		"attacker_neutralized": _attacker_health.is_destroyed(),
	}.duplicate(true)


static func pristine_persistence_state(generation: int) -> Dictionary:
	return {
		"schema_version": PERSISTENCE_SCHEMA_VERSION,
		"generation": generation,
		"attacker_health": 35.0,
		"tender_health": 75.0,
		"attack_clock": -FIRST_ATTACK_DELAY,
		"shots_fired": 0,
		"attacker_neutralized": false,
	}


static func validate_persistence_state(candidate: Variant, expected_generation: int) -> bool:
	return _validate_persistence_fields(candidate, expected_generation, false)


## A lost terminal owner can retain the tender's actual destroyed health.
## This does not admit that record to live combat restoration.
static func validate_lost_terminal_persistence_state(candidate: Variant, expected_generation: int) -> bool:
	return _validate_persistence_fields(candidate, expected_generation, true)


static func _validate_persistence_fields(candidate: Variant, expected_generation: int, allow_destroyed_tender: bool) -> bool:
	if not candidate is Dictionary:
		return false
	var saved := candidate as Dictionary
	if saved.size() != 7 or not _integral(saved.get("schema_version")) \
			or int(saved.schema_version) != PERSISTENCE_SCHEMA_VERSION \
			or not _integral(saved.get("generation")) \
			or int(saved.generation) != expected_generation \
			or not _number(saved.get("attacker_health")) \
			or not _number(saved.get("tender_health")) \
			or not _number(saved.get("attack_clock")) \
			or not _integral(saved.get("shots_fired")) \
			or saved.get("attacker_neutralized") is not bool:
		return false
	var attacker_health := float(saved.attacker_health)
	var tender_health := float(saved.tender_health)
	return attacker_health >= 0.0 and attacker_health <= 35.0 \
		and (tender_health > 0.0 or (allow_destroyed_tender and tender_health == 0.0)) and tender_health <= 75.0 \
		and float(saved.attack_clock) >= -FIRST_ATTACK_DELAY \
		and float(saved.attack_clock) <= 90.0 \
		and int(saved.shots_fired) >= 0 and int(saved.shots_fired) <= MAX_PERSISTED_COUNTER \
		and bool(saved.attacker_neutralized) == is_zero_approx(attacker_health)


func restore_persistence_state(candidate: Variant, expected_generation: int) -> bool:
	if not _active or expected_generation != _generation \
			or not validate_persistence_state(candidate, expected_generation):
		return false
	var saved := candidate as Dictionary
	_restoring = true
	_attacker_health.reset_health()
	_tender_health.reset_health()
	if float(saved.attacker_health) < 35.0:
		_attacker_health.apply_damage(35.0 - float(saved.attacker_health))
	if float(saved.tender_health) < 75.0:
		_tender_health.apply_damage(75.0 - float(saved.tender_health))
	_attack_clock = float(saved.attack_clock)
	_shots_fired = int(saved.shots_fired)
	# In-flight bolts are presentation of an uncommitted shot and never persist.
	_bolts.abandon_all(&"session_restore")
	_last_tender_position = Vector3.INF
	_tender_velocity = Vector3.ZERO
	_restoring = false
	return true


func _make_target(target_name: String, size: Vector3, tint: Color, faction: StringName, rendered: bool = true) -> Area3D:
	var target := Area3D.new()
	target.name = target_name
	target.collision_layer = 0
	target.collision_mask = 0
	add_child(target)
	var shape := CollisionShape3D.new()
	shape.name = "Hurtbox"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	target.add_child(shape)
	var health := Damageable.new()
	health.name = "Damageable"
	health.faction_id = faction
	target.add_child(health)
	if rendered:
		var visual := MeshInstance3D.new()
		visual.name = "RaiderHull"
		visual.mesh = _build_raider_visual(tint)
		visual.material_override = _raider_material
		target.add_child(visual)
	return target


## One opaque surface: the silhouette and painted role cues survive the existing
## remote presenter's mesh sharing and detached material_override health tint.
## No lights, flashing emission, moving pieces or additional hit geometry.
static func _build_raider_visual(tint: Color) -> ArrayMesh:
	if _raider_meshes.has(tint):
		return _raider_meshes[tint] as ArrayMesh
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var armor := Color("655b53")
	var dark := Color("20262b")
	# A narrow bow, broad armored shoulders and clipped stern, facing local -Z.
	_raider_loft(tool, Vector3.ZERO, [Vector3(0.18, 0.16, -2.5),
		Vector3(0.75, 0.48, -1.35), Vector3(0.78, 0.45, 1.25),
		Vector3(0.48, 0.28, 1.9)], armor, dark)
	for side: float in [-1.0, 1.0]:
		# Engines and swept wings stay inside the unchanged 4 x 2.5 x 5 hurtbox.
		_raider_loft(tool, Vector3(side * 1.6, -0.15, 0.0),
			[Vector3(0.34, 0.34, -0.5), Vector3(0.34, 0.34, 2.4)], armor, tint)
		var wing := PackedVector3Array([Vector3(side * 0.5, 0.0, -0.8),
			Vector3(side * 1.85, 0.0, 1.0), Vector3(side * 0.5, 0.0, 1.4)])
		_raider_plate(tool, wing, Vector3(0.0, 0.08, 0.0), armor)
		# Painted forward chevrons read by shape as well as hostile red hue.
		var a := Vector3(side * 0.87, 0.085, 0.15)
		var b := Vector3(side * 1.48, 0.085, 0.88)
		var c := Vector3(side * 1.13, 0.085, 0.70)
		var d := Vector3(side * 0.86, 0.085, 0.62)
		_raider_triangle(tool, a, b, c, Vector3.UP, tint)
		_raider_triangle(tool, a, c, d, Vector3.UP, tint)
	# Raised smoked canopy and tall aft fin make fore/aft and side views distinct.
	_raider_loft(tool, Vector3(0.0, 0.45, 0.0),
		[Vector3(0.25, 0.20, -1.3), Vector3(0.32, 0.20, -0.4)], dark, dark)
	_raider_plate(tool, PackedVector3Array([Vector3(0.0, 0.3, 0.5),
		Vector3(0.0, 1.2, 1.7), Vector3(0.0, 0.3, 2.1)]),
		Vector3(0.065, 0.0, 0.0), tint)
	var mesh := tool.commit()
	_raider_meshes[tint] = mesh
	if _raider_material == null:
		_raider_material = StandardMaterial3D.new()
		_raider_material.vertex_color_use_as_albedo = true
		_raider_material.albedo_color = Color.WHITE
		_raider_material.roughness = 0.72
		# Painted armor is dielectric; its cues do not depend on void reflections.
		_raider_material.metallic = 0.0
	return mesh


## Convex chamfered rings; flat face normals retain the authored armor facets.
static func _raider_loft(tool: SurfaceTool, center: Vector3, sections: Array,
		color: Color, stern_color: Color) -> void:
	var rings: Array[PackedVector3Array] = []
	for section: Vector3 in sections:
		var ring := PackedVector3Array()
		for corner: Vector2 in [Vector2(-0.6, -1.0), Vector2(0.6, -1.0),
			Vector2(1.0, -0.6), Vector2(1.0, 0.6), Vector2(0.6, 1.0),
			Vector2(-0.6, 1.0), Vector2(-1.0, 0.6), Vector2(-1.0, -0.6)]:
			ring.append(center + Vector3(corner.x * section.x, corner.y * section.y, section.z))
		rings.append(ring)
	var middle: Vector3 = center + Vector3(0.0, 0.0, (sections[0].z + sections[-1].z) * 0.5)
	for index in rings.size() - 1:
		for side in 8:
			var a := rings[index][side]
			var b := rings[index][(side + 1) % 8]
			var c := rings[index + 1][(side + 1) % 8]
			var d := rings[index + 1][side]
			var outward := (a + b + c + d) * 0.25 - middle
			_raider_triangle(tool, a, b, c, outward, color)
			_raider_triangle(tool, a, c, d, outward, color)
	for end in [0, rings.size() - 1]:
		var cap := center + Vector3(0.0, 0.0, sections[end].z)
		var outward := Vector3.FORWARD if end == 0 else Vector3.BACK
		for side in 8:
			_raider_triangle(tool, cap, rings[end][side], rings[end][(side + 1) % 8],
				outward, color if end == 0 else stern_color)


static func _raider_plate(tool: SurfaceTool, points: PackedVector3Array,
		half_thickness: Vector3, color: Color) -> void:
	var center := (points[0] + points[1] + points[2]) / 3.0
	for sign_value: float in [-1.0, 1.0]:
		_raider_triangle(tool, points[0] + half_thickness * sign_value,
			points[1] + half_thickness * sign_value, points[2] + half_thickness * sign_value,
			half_thickness * sign_value, color)
	for index in 3:
		var next := (index + 1) % 3
		var a := points[index] - half_thickness
		var b := points[next] - half_thickness
		var c := points[next] + half_thickness
		var d := points[index] + half_thickness
		var outward := (points[index] + points[next]) * 0.5 - center
		_raider_triangle(tool, a, b, c, outward, color)
		_raider_triangle(tool, a, c, d, outward, color)


static func _raider_triangle(tool: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, outward: Vector3, color: Color) -> void:
	# Godot's front faces wind clockwise; retain matching outward flat normals.
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var swap := b
		b = c
		c = swap
	var normal := (c - a).cross(b - a).normalized()
	for point: Vector3 in [a, b, c]:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.add_vertex(point)


func _sync_positions() -> void:
	if not is_instance_valid(_host):
		return
	var tender_position := _host.get_snapshot().get("entity_position", Vector3.ZERO) as Vector3
	_tender.global_position = tender_position
	_attacker.global_position = tender_position + ATTACKER_OFFSET


func _sample_tender_velocity(delta: float) -> void:
	var tender_position := _tender.global_position
	if _last_tender_position.is_finite():
		_tender_velocity = ((tender_position - _last_tender_position) / delta).limit_length(MAX_LEAD_SPEED)
	_last_tender_position = tender_position


## Leads the moving tender so a bolt released now meets it rather than the
## place it used to be. A few fixed-point steps converge because the bolt is
## always much faster than the convoy. The bolt meets the hurtbox pose from one
## tick earlier (see `advance`), so that tick is taken off the lead time.
func _lead_direction(muzzle: Vector3, delta: float) -> Vector3:
	var relative := _tender.global_position - muzzle
	var aim := relative
	for _iteration in 3:
		aim = relative + _tender_velocity * maxf(aim.length() / BOLT_SPEED - delta, 0.0)
	return aim if aim.length_squared() > 0.000001 else relative


func _retire() -> void:
	_active = false
	if is_instance_valid(_bolts):
		_bolts.abandon_all(&"convoy_retired")
	if is_instance_valid(_authority) and is_instance_valid(_attacker):
		_authority.retire_source_registration(_attacker, ATTACKER_SOURCE_ID)
	if is_instance_valid(_attacker):
		_attacker.collision_layer = 0
		_attacker.visible = false
	if is_instance_valid(_tender):
		_tender.collision_layer = 0
		_tender.visible = false


func _on_attacker_destroyed(_position: Vector3, _normal: Vector3, _context: Dictionary) -> void:
	if is_instance_valid(_attacker):
		_attacker.collision_layer = 0
		_attacker.visible = false
	# Killing the raider cancels its bolts still in the air.
	if is_instance_valid(_bolts):
		_bolts.abandon_source_bolts(_attacker, &"raider_destroyed")
	if is_instance_valid(_authority):
		_authority.retire_source_registration(_attacker, ATTACKER_SOURCE_ID)


func _on_attacker_damaged(
		_amount: float,
		current: float,
		_maximum: float,
		_position: Vector3,
		_normal: Vector3,
		_context: Dictionary
	) -> void:
	if _active and not _restoring:
		attacker_damaged.emit(_generation, current)


func _on_tender_destroyed(_position: Vector3, _normal: Vector3, _context: Dictionary) -> void:
	if _active:
		tender_destroyed.emit(_generation)


func _on_tender_damaged(
		_amount: float,
		current: float,
		maximum: float,
		_position: Vector3,
		_normal: Vector3,
		_context: Dictionary
	) -> void:
	if _active and not _restoring:
		tender_damaged.emit(_generation, current, maximum)


static func _integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
