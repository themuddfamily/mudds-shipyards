class_name CourierRunnerOpponent
extends ResolverBackedOpponent

const MaterialCatalog := preload("res://scripts/ships/courier_runner_visual_resource_catalog.gd")

## Contract courier — an opponent whose objective is to *leave*.
##
## Every other craft in this encounter wants to be near the player. This one
## does not fight, does not orbit, does not station-keep and never turns to face
## you. It flies a boundary run, jinks when something gets close, shoots
## backwards at whatever is chasing it, and screams for help the moment it is
## touched. Whether it "wins" is a distance, not a hull.
##
## What that changes about the fight. Aim stops being the problem and closure
## becomes the problem: it has the highest straight-line speed of any opponent
## and the worst turn rate of any opponent, so it cannot be out-run down its own
## heading but it can be cut off across the chord of a jink. Its rear turret is
## weak and only covers the cone directly behind it, which makes the safe attack
## line an oblique one — the exact line that is hardest to hold while closing.
## And hurting it is not free: the first hit triggers the distress broadcast, and
## its escort wing arrives behind the *pursuer*, so the player who commits to a
## straight stern chase is the player who gets shot in the back.
##
## Termination. The runner does not need to be destroyed for the encounter to
## end. `EncounterScenarioDirector` owns that: reaching the boundary is a
## complete, terminal outcome with no leftover state, exactly like being
## destroyed is. Ignoring the courier entirely is therefore a valid way to end
## the scenario, not a way to hang it.
##
## Evidence status: modern_interpretation. No original Keth Shipyards craft,
## weapon, tactic, cargo, contract, or class name is authenticated or claimed
## here.

signal distress_broadcast_started
signal escape_run_set(origin: Vector3, heading: Vector3, distance: float)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"courier-runner-opponent"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DISPLAY_NAME := "Mudds contract courier"

const DEFAULT_SOURCE_ID := 2105
const COURIER_WEAPON_ID: StringName = &"courier_tail_deterrent"
## Ordinary opponent gun, so it takes the pooled amber; magenta stays reserved
## for the picket's heavy charged lance.
const COURIER_PULSE_STYLE: StringName = &"amber"
const COURIER_PULSE_PROFILE: StringName = PulseWeaponPresentation.PROFILE_TAIL_TURRET
const COURIER_AUDIO_PROFILE: StringName = CombatAudioPresentation.WEAPON_PROFILE_TAIL_TURRET

## A pale sand hull with a warm cargo stripe. Deliberately the brightest and
## most civilian-looking opponent in the roster: at the distance you first see
## it, "that is not a fighter" is the read that has to land.
const HULL_SAND := Color("d9c49a")
const HULL_CLAY := Color("8a6f4c")
const HULL_SHADOW := Color("3a3227")
const CARGO_RUST := Color("d9662f")
const DISTRESS_RED := Color("ff4a4a")
const COURIER_ENGINE := Color("8fd0ff")
const TAIL_TURRET_CHARGE_SCALE := Vector3(1.65, 0.62, 0.62)
const MATERIAL_CATALOG_ENTRY_COUNT := 19
const CARGO_PYLON_SIZE := Vector3(0.9, 0.22, 2.2)
const POD_BAND_SIZE := Vector3(1.35, 1.35, 0.22)
const POD_LAMP_RADIUS := 0.13
## One steady, world-space arrow above the runner makes its fixed boundary route
## legible from the player's intercept distance. It is intentionally much wider
## than a hull marker: the cue describes where the courier is escaping, not a
## subsystem to shoot.
const ROUTE_INTENT_CUE_HEIGHT := 7.5
const ROUTE_INTENT_SHAFT_SIZE := Vector3(0.72, 0.34, 6.4)
const ROUTE_INTENT_HEAD_SIZE := Vector3(0.72, 0.34, 4.6)
const ROUTE_INTENT_HEAD_OFFSET := Vector3(1.35, 0.0, -4.05)
const ROUTE_INTENT_HEAD_YAW := deg_to_rad(42.0)

## The inherited eleven recipes plus the courier's eight palette recipes are
## immutable after build. Each runner keeps its own dictionary and all dynamic
## presentation state, while the standalone process catalog owns only Material
## identities and avoids coupling lifetime to this scripted inheritance chain.

@export_category("Escape run")
## Distance from the launch point at which the run is complete. The director
## owns the outcome; this copy exists so the craft can present its own progress.
@export var escape_distance := 1400.0
## Inside this range the runner starts jinking instead of flying straight.
@export_range(10.0, 400.0, 1.0) var evade_trigger_range := 120.0
@export_range(0.0, 2.0, 0.01) var evade_strength := 0.62
## Cosine gate on the tail turret's rear cone, measured from the runner's own
## aft vector. Outside it the turret cannot arm at all.
@export_range(0.0, 0.999, 0.001) var tail_arc_cosine := 0.72

var _escape_origin := Vector3.ZERO
var _escape_heading := Vector3.FORWARD
var _escape_run_set := false
var _distress_broadcast := false
var _tail_muzzle: Marker3D
var _distress_beacon: MeshInstance3D
var _distress_light: OmniLight3D
var _route_intent_cue: Node3D
var _route_intent_generation := -1
var _cargo_lamps: Array[MeshInstance3D] = []
var _shots_arc_denied := 0
var _built_material_contracts: Dictionary = {}
var _built_visual_material_bindings: Dictionary = {}


# ------------------------------------------------------------- lifecycle ----

func _ready() -> void:
	super()
	set_meta("component_id", COMPONENT_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("historically_supported", false)
	set_meta("modern_interpretation", &"courier_runner_opponent")
	if source_id <= 0:
		source_id = DEFAULT_SOURCE_ID
	_apply_distress_presentation()
	_apply_route_intent_presentation()
	# Base _ready adds retained weapon/sensor damage feedback after hull build.
	# Freeze the complete first attachment, never recapture drift on re-entry.
	if _built_material_contracts.is_empty():
		_capture_material_contracts()


func _exit_tree() -> void:
	# A streamed detach invalidates the scenario generation that supplied this
	# route. Re-entry must receive a fresh authoritative route before advertising
	# an escape direction again.
	_clear_route_intent_presentation()
	super()


func activate(spawn_transform: Transform3D) -> Dictionary:
	var activation := super(spawn_transform) as Dictionary
	if not bool(activation.get("accepted", false)):
		return activation
	_shots_arc_denied = 0
	_distress_broadcast = false
	# The heading defaults to the spawn facing, so a craft activated by a fixture
	# that never calls `set_escape_run()` still runs a coherent, bounded course
	# instead of drifting.
	_escape_origin = spawn_transform.origin
	_escape_heading = (-spawn_transform.basis.z).normalized()
	_escape_run_set = false
	_route_intent_generation = -1
	_apply_distress_presentation()
	_apply_route_intent_presentation()
	return activation


func deactivate() -> void:
	super()
	_distress_broadcast = false
	_clear_route_intent_presentation()
	_apply_distress_presentation()


func _destroy_interceptor(death_position: Vector3) -> void:
	_distress_broadcast = false
	_clear_route_intent_presentation()
	_apply_distress_presentation()
	super(death_position)


# -------------------------------------------------------- public contract ----

func get_display_name() -> String:
	return DISPLAY_NAME


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_weapon_id() -> StringName:
	return COURIER_WEAPON_ID


func get_pulse_style_id() -> StringName:
	return COURIER_PULSE_STYLE


func get_pulse_profile_id() -> StringName:
	return COURIER_PULSE_PROFILE


func get_combat_audio_profile_id() -> StringName:
	return COURIER_AUDIO_PROFILE


## Fixes the boundary run. Called by the scenario that dispatched the courier so
## the craft and the director measure the same run from the same origin.
func set_escape_run(origin: Vector3, heading: Vector3, distance: float) -> bool:
	if not _can_mutate_live_courier():
		return false
	if not origin.is_finite() or not heading.is_finite():
		return false
	if heading.length_squared() <= 0.000001:
		return false
	if not is_finite(distance) or distance <= 0.0:
		return false
	_escape_origin = origin
	_escape_heading = heading.normalized()
	escape_distance = distance
	_escape_run_set = true
	_route_intent_generation = _activation_generation
	_apply_route_intent_presentation()
	escape_run_set.emit(_escape_origin, _escape_heading, escape_distance)
	return true


func set_target(target: Node3D) -> void:
	super(target)
	# Explicit threat loss clears the route read in the same call. An unexpected
	# target teardown is caught by the inherited presentation pass next frame.
	_apply_route_intent_presentation()


func get_escape_heading() -> Vector3:
	return _escape_heading


func get_escape_origin() -> Vector3:
	return _escape_origin


## 0 at the launch point, 1 at the boundary.
func get_escape_progress() -> float:
	if escape_distance <= 0.0 or not is_inside_tree():
		return 0.0
	return clampf(global_position.distance_to(_escape_origin) / escape_distance, 0.0, 1.0)


## Raised once, by the scenario, when the runner is first hurt. The craft owns
## only the presentation of it; the escort dispatch belongs to the director.
func begin_distress_broadcast() -> bool:
	if not _can_mutate_live_courier():
		return false
	if _distress_broadcast or not _active:
		return false
	_distress_broadcast = true
	_apply_distress_presentation()
	distress_broadcast_started.emit()
	return true


func is_distress_broadcast() -> bool:
	return _distress_broadcast


func _can_mutate_live_courier() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func get_arc_denied_count() -> int:
	return _shots_arc_denied


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"authenticated_original_geometry": false,
		"authenticated_original_weapon": false,
		"authenticated_original_tactic": false,
		"claims_historical_class_name": false,
		"modern_interpretations": PackedStringArray([
			"sand courier silhouette with slung cargo pods and a tail turret",
			"boundary escape run, jink response, and distress broadcast",
			"rear-cone-only deterrent turret",
			"every balance, cadence, range, and damage value",
		]),
		"explicit_unknowns": PackedStringArray([
			"any historical opposing craft, weapon, cargo, contract, tactic, or class name",
		]),
		"content_note": (
			"The courier silhouette, palette, escape run, distress behaviour, "
			+ "tail turret, and every balance value are an original modern "
			+ "interpretation. They do not reproduce or claim any authenticated "
			+ "historical Keth Shipyards craft, weapon, cargo, contract, tactic, "
			+ "or class name."
		),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"display_name": DISPLAY_NAME,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence": get_evidence_metadata(),
		"weapon_profiles": get_weapon_profiles(),
		"tactics": get_tactics_profile(),
		"authority": {
			"source_id": source_id,
			"faction_id": faction_id,
			"registered": is_combat_source_registered(),
			"weapon_id": COURIER_WEAPON_ID,
			"pulse_style_id": COURIER_PULSE_STYLE,
			"pulse_profile_id": COURIER_PULSE_PROFILE,
			"combat_audio_profile_id": COURIER_AUDIO_PROFILE,
		},
		"escape": {
			"run_set": _escape_run_set,
			"origin": _escape_origin,
			"heading": _escape_heading,
			"distance": escape_distance,
			"progress": get_escape_progress(),
		},
		"lifecycle": {
			"inside_tree": is_inside_tree(),
			"active": is_active(),
			"distress_broadcast": _distress_broadcast,
			"shots_fired": get_shots_fired(),
			"shots_withheld": get_shots_withheld(),
			"arc_denied": _shots_arc_denied,
			"pending_shot_receipts": get_pending_shot_receipt_count(),
		},
		"visual_resources": get_visual_resource_audit(),
	}.duplicate(true)


## Detached identity, visible-parameter, allocation, and submission evidence for
## the CourierRunner-local immutable catalog. No Resource handle is exposed.
func get_visual_resource_audit() -> Dictionary:
	var identity_by_key := {}
	var visible_parameters_by_key := {}
	var catalog_shared := true
	var catalog_keys := PackedStringArray()
	for key in _materials:
		var material := _materials.get(key) as StandardMaterial3D
		var shared_material := MaterialCatalog.get_material(key)
		catalog_keys.append(str(key))
		identity_by_key[key] = material.get_instance_id() if material != null else 0
		var visible_contract := _material_contract(material)
		visible_contract.erase("instance_id")
		visible_parameters_by_key[key] = visible_contract
		catalog_shared = (
			catalog_shared
			and material != null
			and shared_material != null
			and material == shared_material
		)
	catalog_keys.sort()
	var counts := _count_visual_resources()
	var visual_material_bindings := _visual_material_binding_contract()
	return {
		"valid": (
			_material_catalog_is_live()
			and int(counts.material_bindings) == int(counts.geometry_submissions)
			and visual_material_bindings == _built_visual_material_bindings
		),
		"scope": &"courier_runner_process_wide_immutable_material_catalog",
		"mapping_state_scope": &"courier_runner_instance",
		"catalog_shared": catalog_shared,
		"catalog_build_count": MaterialCatalog.get_build_count(),
		"catalog_keys": catalog_keys,
		"catalog_entry_count": identity_by_key.size(),
		"legacy_material_resources_per_instance": MATERIAL_CATALOG_ENTRY_COUNT,
		"shared_material_resources_per_process": MATERIAL_CATALOG_ENTRY_COUNT,
		"identity_by_key": identity_by_key,
		"visible_parameters_by_key": visible_parameters_by_key,
		"visual_material_bindings": visual_material_bindings,
		"counts": counts,
	}.duplicate(true)


func get_validation_errors() -> PackedStringArray:
	var errors := get_resolver_backed_errors()
	if not is_finite(escape_distance) or escape_distance <= 0.0:
		errors.append("the escape distance must be finite and positive")
	if not _escape_heading.is_finite() or _escape_heading.length_squared() <= 0.000001:
		errors.append("the escape heading must be a finite non-zero direction")
	if not _escape_origin.is_finite():
		errors.append("the escape origin must be finite")
	if _distress_broadcast and not _active:
		errors.append("a dormant courier must not hold a live distress broadcast")
	if tail_arc_cosine <= 0.0:
		errors.append("the tail arc must be a rear cone, not a hemisphere or wider")
	if _built and not _material_catalog_is_live():
		errors.append("the CourierRunner immutable material catalog changed")
	return errors


# ---------------------------------------------------------------- tactics ----

## The runner owns its movement loop rather than inheriting one, for two
## reasons that are both behavioural rather than cosmetic.
##
## **Speed banding is inverted.** `RangeOpponent` reaches for `chase_speed` when
## the target is *far* and settles to `cruise_speed` when it is near — correct
## for something that wants to close, exactly backwards for something that wants
## to leave. Here `cruise_speed` is the unpressured transit burn and
## `chase_speed` is what it lights off once a pursuer is inside
## `evade_trigger_range`: pressure makes a runner faster.
##
## The gap between those two numbers is the whole scenario. The transit burn is
## authored *below* every fighter's cruise so the opening approach is winnable,
## and the pressed burn *above* every fighter's cruise so the last hundred
## metres are not: closing the gap costs the pursuer his boost, and the runner
## was never meant to be caught by throttle in the first place. It is meant to
## be shot, from range, before it gets its distance — which is why it carries a
## rear turret and no forward gun at all.
##
## **Losing the target does not stop it.** The inherited loop decelerates to a
## halt when its target goes away, which for this craft would mean a player who
## disengages leaves a courier hanging motionless at the halfway mark forever.
## The runner keeps running on its last heading instead, so "ignore it" ends the
## scenario — as `ESCAPED` — rather than stalling it.
func _physics_process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		_telegraph_remaining = 0.0
		var coast := _escape_heading
		if coast.length_squared() <= 0.001:
			coast = -global_basis.z
		coast = _avoid_world_geometry(coast.normalized())
		_last_motion_direction = coast
		velocity = velocity.move_toward(coast * cruise_speed, acceleration * delta)
		_update_attitude(Vector3.ZERO, delta)
		move_and_slide()
		_resolve_slide_collisions()
		return

	var target_position := _get_target_aim_position()
	var offset := target_position - global_position
	var distance := offset.length()
	var target_direction := -global_basis.z
	if distance > 0.001:
		target_direction = offset / distance
	var desired_direction := _choose_motion_direction(target_direction, distance)
	desired_direction = _avoid_world_geometry(desired_direction)
	_last_motion_direction = desired_direction
	var desired_speed := chase_speed if distance < evade_trigger_range else cruise_speed
	velocity = velocity.move_toward(desired_direction * desired_speed, acceleration * delta)
	_update_attitude(target_direction, delta)
	move_and_slide()
	_resolve_slide_collisions()
	_update_weapon(target_position, target_direction, distance, delta)


## The runner's motion ignores where the player is except to jink away from him.
## It is the only opponent in the roster whose desired direction is not derived
## from the target at all.
func _choose_motion_direction(target_direction: Vector3, distance: float) -> Vector3:
	var desired := _escape_heading
	if desired.length_squared() <= 0.001:
		desired = -global_basis.z
	if distance < evade_trigger_range:
		# A pursuer is inside deterrent range. Break across his approach rather
		# than away from it — running straight from a faster craft is how a
		# runner dies, and the lateral component is what forces the player to
		# keep re-solving the intercept.
		var lateral := Vector3.UP.cross(target_direction)
		if lateral.length_squared() <= 0.001:
			lateral = Vector3.RIGHT
		lateral = lateral.normalized() * _orbit_sign
		var jink := sin(_elapsed * 1.7) * evade_strength
		desired = (
			desired
			+ lateral * jink
			+ Vector3.UP * sin(_elapsed * 1.1 + 0.9) * evade_strength * 0.5
		)
	if desired.length_squared() <= 0.001:
		return -global_basis.z
	return desired.normalized()


## A runner points where it is going, not at what is chasing it. The inherited
## attitude pass aims the hull at the target, which would make the tail turret's
## rear cone meaningless and would read as a craft flying sideways.
func _update_attitude(_target_direction: Vector3, delta: float) -> void:
	var heading := _last_motion_direction
	if heading.length_squared() <= 0.001:
		heading = _escape_heading
	if heading.length_squared() <= 0.001:
		heading = -global_basis.z
	heading = heading.normalized()
	var look_up := Vector3.UP
	if absf(heading.dot(look_up)) > 0.965:
		look_up = Vector3.FORWARD
	var desired_basis := Basis.looking_at(heading, look_up).orthonormalized()
	var lateral_speed := global_basis.x.dot(velocity)
	var bank_target := clampf(lateral_speed / maxf(cruise_speed, 1.0), -0.3, 0.3)
	_bank_angle = lerpf(_bank_angle, bank_target, 1.0 - exp(-5.0 * delta))
	desired_basis = (desired_basis * Basis(Vector3.BACK, _bank_angle)).orthonormalized()
	var blend := 1.0 - exp(-deg_to_rad(turn_speed_degrees) * delta)
	global_basis = Basis(Quaternion(global_basis.orthonormalized()).slerp(
		Quaternion(desired_basis),
		blend
	)).orthonormalized()


## The tail turret. It fires along the runner's own aft vector, and it can only
## arm while the pursuer is inside that cone: there is no forward or beam shot,
## and no charge is ever committed outside the arc.
func _update_weapon(
		target_position: Vector3,
		target_direction: Vector3,
		distance: float,
		delta: float
	) -> void:
	var arc_open := _is_tail_arc_open(target_direction)
	if _telegraph_remaining > 0.0:
		if (
			not arc_open
			or distance > engagement_range
			or not _has_line_of_sight(target_position)
		):
			_telegraph_remaining = 0.0
			_cooldown_remaining = maxf(_cooldown_remaining, 0.4)
			if not arc_open:
				_shots_arc_denied += 1
			return
		_telegraph_remaining = maxf(0.0, _telegraph_remaining - delta)
		if _telegraph_remaining <= 0.0:
			_fire_at_target(_get_target_aim_position())
		return
	if not arc_open or _cooldown_remaining > 0.0 or distance > engagement_range:
		return
	if not _has_line_of_sight(target_position):
		return
	_telegraph_remaining = telegraph_time


func _is_tail_arc_open(target_direction: Vector3) -> bool:
	if not _active or not is_instance_valid(_target):
		return false
	if target_direction.length_squared() <= 0.000001:
		return false
	return global_basis.z.dot(target_direction.normalized()) >= tail_arc_cosine


func _get_firing_muzzle() -> Node3D:
	return _tail_muzzle if is_instance_valid(_tail_muzzle) else super()


func _is_fire_authorized() -> bool:
	if not super():
		return false
	var offset := _get_target_aim_position() - global_position
	if offset.length_squared() <= 0.000001:
		return false
	return _is_tail_arc_open(offset.normalized())


# ----------------------------------------------------------- presentation ----

## A step function of the broadcast latch. Not a sampled oscillator phase: the
## beacon is either lit or dark, so a capture of one frame of a distressed
## courier is identical to a capture of any other frame of the same state.
func _apply_distress_presentation() -> void:
	if not _built:
		return
	var lit := _active and _distress_broadcast
	if is_instance_valid(_distress_beacon):
		_distress_beacon.visible = lit
	if is_instance_valid(_distress_light):
		_distress_light.light_energy = 4.2 if lit else 0.0
	for lamp in _cargo_lamps:
		if is_instance_valid(lamp):
			lamp.visible = _active


## Pure presentation of the already-fixed destination and live pursuer. The
## arrow is top-level, so hull jinks and banking never bend the advertised route
## away from the scenario's authoritative world-space escape heading.
func _apply_route_intent_presentation() -> void:
	if not is_instance_valid(_route_intent_cue):
		return
	var route_is_current := (
		_active
		and _escape_run_set
		and _route_intent_generation == _activation_generation
		and _has_current_target()
		and not is_equal_approx(get_escape_progress(), 1.0)
		and is_inside_tree()
		and not is_queued_for_deletion()
	)
	_route_intent_cue.visible = route_is_current
	if not route_is_current:
		# Loss, terminal distance, detach, and queued teardown invalidate this
		# generation's cue rather than merely hiding it. Restoring a target or
		# moving the retained fixture cannot resurrect a stale route read.
		if _route_intent_generation == _activation_generation:
			_route_intent_generation = -1
		return
	var route_up := Vector3.UP
	if absf(_escape_heading.dot(route_up)) > 0.965:
		route_up = Vector3.FORWARD
	_route_intent_cue.global_transform = Transform3D(
		Basis.looking_at(_escape_heading, route_up).orthonormalized(),
		global_position + Vector3.UP * ROUTE_INTENT_CUE_HEIGHT
	)


func _clear_route_intent_presentation() -> void:
	_route_intent_generation = -1
	if is_instance_valid(_route_intent_cue):
		_route_intent_cue.visible = false


func _update_presentation(delta: float) -> void:
	super(delta)
	if _active and _telegraph_remaining > 0.0 and not _warning_lenses.is_empty():
		# One retained sphere broadens across the runner's tail. The static
		# aperture reads as a slow deterrent shot without adding flash motion.
		_warning_lenses[0].scale *= TAIL_TURRET_CHARGE_SCALE
	_apply_distress_presentation()
	_apply_route_intent_presentation()


# ---------------------------------------------------------------- geometry ----

## Builds the courier hull. Every primitive, material and particle helper, and
## the whole inherited damage/destruction/debris presentation, are reused from
## `RangeOpponent`; only the silhouette, palette and mounts differ.
func _build_interceptor() -> void:
	if _built:
		return
	_built = true
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	# The runner never holds a station. The inherited orbit fields are pinned to
	# the deterrent envelope so the shared movement loop bands speed against a
	# distance that means something on this craft.
	preferred_range = clampf(evade_trigger_range * 0.6, 10.0, 200.0)
	retreat_range = clampf(evade_trigger_range * 0.35, 5.0, 100.0)
	_adopt_shared_material_catalog()
	_visual_root = Node3D.new()
	_visual_root.name = "ContractCourierVisual"
	add_child(_visual_root)

	# A single retained arrow, rendered from three boxes and two immutable mesh
	# recipes. It has no light, collision, timer, input, or process ownership.
	# Its top-level transform is refreshed by the existing presentation owner.
	_route_intent_cue = Node3D.new()
	_route_intent_cue.name = "EscapeRouteIntentCue"
	add_child(_route_intent_cue)
	_route_intent_cue.set_as_top_level(true)
	var route_shaft_mesh := _make_box_mesh(
		ROUTE_INTENT_SHAFT_SIZE, _materials.courier_engine
	)
	var route_head_mesh := _make_box_mesh(
		ROUTE_INTENT_HEAD_SIZE, _materials.courier_engine
	)
	var route_shaft := _box_from_mesh(
		_route_intent_cue, "Shaft", Vector3(0.0, 0.0, -0.25), route_shaft_mesh
	)
	var route_port_head := _box_from_mesh(
		_route_intent_cue,
		"PortArrowHead",
		Vector3(-ROUTE_INTENT_HEAD_OFFSET.x, 0.0, ROUTE_INTENT_HEAD_OFFSET.z),
		route_head_mesh,
		Vector3(0.0, -ROUTE_INTENT_HEAD_YAW, 0.0)
	)
	var route_starboard_head := _box_from_mesh(
		_route_intent_cue,
		"StarboardArrowHead",
		ROUTE_INTENT_HEAD_OFFSET,
		route_head_mesh,
		Vector3(0.0, ROUTE_INTENT_HEAD_YAW, 0.0)
	)
	for route_piece in [route_shaft, route_port_head, route_starboard_head]:
		(route_piece as MeshInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	_route_intent_cue.visible = false

	# A blunt utility hull with slung cargo pods and oversized engines. It has to
	# read as freight that has been made to go fast, not as a warship.
	# Freight pressure vessel: full sidewalls remain available for the load
	# hatches, with a formed bow and tapered aft machinery shoulder.
	# A quarter-elliptical bow continues the mounting flats into a drawn
	# pressure dome. These longitudinal stations shape both the plan and keel,
	# rather than only softening the edges of the old broad frontal slab.
	var bow_sections: Array = []
	for station in 21:
		var angle := lerpf(0.025, PI * 0.5, float(station) / 20.0)
		var longitudinal := (cos(0.025) - cos(angle)) / cos(0.025)
		bow_sections.append(Vector4(
			-1.3 + 2.7 * longitudinal,
			1.1 * sin(angle), 0.85 * sin(angle), -0.04 * (1.0 - sin(angle))
		))
	_pressure_body(_visual_root, "BluntNose", Vector3(0, 0, -3.4), bow_sections, _materials.courier_hull)
	_pressure_body(_visual_root, "HullBody", Vector3(0, 0, 0.2), [
		Vector4(-2.2, 1.1, 0.85, 0), Vector4(1.9, 1.1, 0.85, 0),
		Vector4(2.9, 1.03, 0.78, -0.01), Vector4(3.7, 0.82, 0.58, -0.04),
	], _materials.courier_hull)
	_box_from_mesh(_visual_root, "SpineTrunk", Vector3.ZERO,
		_courier_roof_mesh(-1.55, 3.02, 0.0, _materials.courier_shadow))
	_pressure_body(_visual_root, "CargoStripe", Vector3(0, 0.85, -0.4), [
		Vector4(-3.4, 0.24, 0.022, -0.21), Vector4(-2.9, 0.48, 0.025, -0.09),
		Vector4(-2.4, 0.67, 0.028, -0.035),
		Vector4(-1.6, 0.7, 0.03, 0.02), Vector4(2.4, 0.7, 0.03, 0.02),
		Vector4(3.4, 0.42, 0.022, -0.08),
	], _materials.courier_rust)
	_box(_visual_root, "VentralKeel", Vector3(0.0, -0.94, 0.6), Vector3(1.5, 0.34, 6.0), _materials.courier_shadow)

	# Rolled freight vessels and their conforming straps each share a bilateral
	# immutable mesh recipe. Runtime lamps and collision retain their own nodes.
	var cargo_shell_mesh := MaterialCatalog.make_cargo_shell(_materials.courier_clay)
	var pod_band_mesh := MaterialCatalog.make_cargo_strap(_materials.courier_rust)
	# The marker lamps are likewise a bilateral immutable visual family. Their
	# MeshInstance3D nodes remain independent because lifecycle presentation
	# toggles visibility per lamp, but their identical sphere geometry is shared.
	var pod_lamp_mesh := SphereMesh.new()
	pod_lamp_mesh.radius = POD_LAMP_RADIUS
	pod_lamp_mesh.height = POD_LAMP_RADIUS * 2.0
	pod_lamp_mesh.radial_segments = 24
	pod_lamp_mesh.rings = 12
	pod_lamp_mesh.material = _materials.courier_lamp
	# These bilateral freight supports are immutable childless silhouette stock.
	# Keep both renderer paths and exact transforms, while retaining one courier-
	# local BoxMesh recipe instead of allocating the same geometry twice.
	var cargo_pylon_mesh := _make_box_mesh(
		CARGO_PYLON_SIZE, _materials.courier_shadow
	)
	var engine_pod_mesh := _courier_engine_mesh(false)
	var engine_collar_mesh := _courier_engine_mesh(true)
	for side in [-1.0, 1.0]:
		# Slung cargo pods on external pylons: the silhouette detail that says
		# this craft is carrying something and would rather not stop.
		_box_from_mesh(
			_visual_root,
			"CargoPylon",
			Vector3(side * 1.5, -0.2, 0.6),
			cargo_pylon_mesh
		)
		_box_from_mesh(_visual_root, "CargoPod", Vector3(side * 2.5, -0.34, 0.6), cargo_shell_mesh)
		_box_from_mesh(
			_visual_root,
			"PodBand",
			Vector3(side * 2.5, -0.34, -0.8),
			pod_band_mesh
		)
		var lamp := _sphere(
			_visual_root,
			"PodLamp",
			Vector3(side * 2.5, 0.22, -1.9),
			POD_LAMP_RADIUS,
			_materials.courier_lamp,
			pod_lamp_mesh
		)
		_cargo_lamps.append(lamp)

		_box_from_mesh(_visual_root, "EnginePod", Vector3(side * 1.15, 0.05, 3.9), engine_pod_mesh)
		# Retain the renderer slot as a passive external retaining collar.
		_box_from_mesh(_visual_root, "EngineCore", Vector3(side * 1.15, 0.05, 3.9), engine_collar_mesh)
		var plume := _exhaust_plume(_visual_root, "EnginePlume", Vector3(side * 1.15, 0.05, 5.4), 0.3, 1.1, _materials.courier_engine, Vector3(90.0, 0.0, 0.0))
		_engine_glows.append(plume)
		var engine_light := OmniLight3D.new()
		engine_light.name = "EngineLight"
		engine_light.position = Vector3(side * 1.15, 0.05, 5.0)
		engine_light.light_color = COURIER_ENGINE
		engine_light.light_energy = 0.0
		engine_light.omni_range = 6.4
		engine_light.shadow_enabled = false
		_visual_root.add_child(engine_light)
		_engine_lights.append(engine_light)

	# Tail turret, mounted aft and pointing back down the hull's own +Z.
	_cylinder(_visual_root, "TailTurretRing", Vector3(0.0, 0.34, 3.5), 0.42, 0.5, _materials.courier_shadow, Vector3(90.0, 0.0, 0.0))
	_cylinder(_visual_root, "TailBarrel", Vector3(0.0, 0.34, 4.3), 0.14, 1.5, _materials.courier_clay, Vector3(90.0, 0.0, 0.0))
	var turret_lens := _sphere(_visual_root, "TailTurretLens", Vector3(0.0, 0.34, 5.05), 0.14, _materials.courier_muzzle)
	_warning_lenses.append(turret_lens)

	# Distress beacon. Lit only while the broadcast latch is set.
	_distress_beacon = _sphere(_visual_root, "DistressBeacon", Vector3(0.0, 1.32, 0.4), 0.24, _materials.courier_distress)
	_distress_beacon.visible = false
	_distress_light = OmniLight3D.new()
	_distress_light.name = "DistressLight"
	_distress_light.position = Vector3(0.0, 1.6, 0.4)
	_distress_light.light_color = DISTRESS_RED
	_distress_light.light_energy = 0.0
	_distress_light.omni_range = 12.0
	_distress_light.shadow_enabled = false
	_visual_root.add_child(_distress_light)

	_tail_muzzle = Marker3D.new()
	_tail_muzzle.name = "TailMuzzle"
	_tail_muzzle.position = Vector3(0.0, 0.34, 5.2)
	add_child(_tail_muzzle)
	# The courier has no forward gun at all. Both inherited muzzle fields point
	# at the tail so no inherited path can fire out of the nose.
	_muzzle_port = _tail_muzzle
	_muzzle_starboard = _tail_muzzle

	_warning_light = OmniLight3D.new()
	_warning_light.name = "TailTurretChargeLight"
	_warning_light.position = Vector3(0.0, 0.34, 4.9)
	_warning_light.light_color = CARGO_RUST
	_warning_light.light_energy = 0.0
	_warning_light.omni_range = 6.0
	_warning_light.shadow_enabled = false
	add_child(_warning_light)

	_build_courier_fittings()
	# Freight registry occupies the uninterrupted pressure-hull sides above the pods.
	for side in [-1.0, 1.0]:
		ShipSurfaceDetail.mark_surface(_visual_root, "CourierRegistry", "courier",
			Vector3(side * 1.10, 0.30, 0.65), Vector2(2.2, 1.1), Vector3(side, 0, 0), Vector3.UP)
		ShipSurfaceDetail.mark_surface(_visual_root, "CrewRescue", "rescue",
			Vector3(side * 1.10, 0.30, -1.7), Vector2(0.9, 0.45), Vector3(side, 0, 0), Vector3.UP)
	_build_collision()
	_build_damage_effects()


func _build_collision() -> void:
	var hull := CollisionShape3D.new()
	hull.name = "HullCollision"
	hull.position = Vector3(0.0, 0.0, 0.2)
	var hull_shape := BoxShape3D.new()
	hull_shape.size = Vector3(2.3, 2.0, 9.6)
	hull.shape = hull_shape
	add_child(hull)
	for side in [-1.0, 1.0]:
		var pod := CollisionShape3D.new()
		pod.name = "PortPodCollision" if side < 0.0 else "StarboardPodCollision"
		pod.position = Vector3(side * 2.5, -0.34, 0.6)
		var pod_shape := BoxShape3D.new()
		pod_shape.size = Vector3(1.3, 1.3, 4.6)
		pod.shape = pod_shape
		add_child(pod)


func _build_damage_effects() -> void:
	_damage_sparks = _make_spark_particles(16, 0.66, 4.2)
	_damage_sparks.name = "DamageSparks"
	_damage_sparks.position = Vector3(0.9, 0.1, 1.2)
	_damage_sparks.one_shot = false
	_damage_sparks.emitting = false
	_damage_sparks.visible = false
	add_child(_damage_sparks)
	_damage_smoke = _make_smoke_particles(false)
	_damage_smoke.name = "EngineSmoke"
	_damage_smoke.position = Vector3(-1.15, 0.15, 4.4)
	_damage_smoke.emitting = false
	_damage_smoke.visible = false
	add_child(_damage_smoke)


func _adopt_shared_material_catalog() -> void:
	var catalog := MaterialCatalog.get_catalog()
	if catalog.size() == MATERIAL_CATALOG_ENTRY_COUNT:
		_materials = catalog
		return
	_create_materials()
	_create_courier_materials()
	_materials = MaterialCatalog.publish_catalog(_materials)


func _create_courier_materials() -> void:
	_materials.courier_hull = _material(HULL_SAND, 0.1, 0.61)
	_materials.courier_clay = _material(HULL_CLAY, 0.1, 0.61)
	_materials.courier_clay.vertex_color_use_as_albedo = true
	_materials.courier_shadow = _material(HULL_SHADOW, 0.52, 0.38)
	_materials.courier_rust = _material(CARGO_RUST, 0.1, 0.62)
	_materials.courier_lamp = _material(CARGO_RUST, 0.1, 0.2, CARGO_RUST, 2.2)
	_materials.courier_muzzle = _material(CARGO_RUST, 0.12, 0.22, CARGO_RUST, 2.6)
	_materials.courier_distress = _material(DISTRESS_RED, 0.08, 0.2, DISTRESS_RED, 5.0)
	_materials.courier_engine = _material(COURIER_ENGINE, 0.08, 0.2, COURIER_ENGINE, 2.8)


func _capture_material_contracts() -> void:
	_built_material_contracts.clear()
	for key in _materials:
		_built_material_contracts[key] = _material_contract(
			_materials.get(key) as StandardMaterial3D
		)
	_built_visual_material_bindings = _visual_material_binding_contract()


func _material_catalog_is_live() -> bool:
	if (
		MaterialCatalog.get_build_count() != 1
		or _materials.size() != MATERIAL_CATALOG_ENTRY_COUNT
		or MaterialCatalog.get_entry_count() != MATERIAL_CATALOG_ENTRY_COUNT
		or _built_material_contracts.size() != MATERIAL_CATALOG_ENTRY_COUNT
		or _visual_material_binding_contract() != _built_visual_material_bindings
	):
		return false
	for key in _materials:
		var material := _materials.get(key) as StandardMaterial3D
		if (
			material == null
			or material != MaterialCatalog.get_material(key)
			or _material_contract(material) != _built_material_contracts.get(key, {})
		):
			return false
	return true


func _material_contract(material: StandardMaterial3D) -> Dictionary:
	if material == null:
		return {}
	return {
		"instance_id": material.get_instance_id(),
		"albedo_color": material.albedo_color,
		"metallic": material.metallic,
		"roughness": material.roughness,
		"transparency": material.transparency,
		"cull_mode": material.cull_mode,
		"shading_mode": material.shading_mode,
		"billboard_mode": material.billboard_mode,
		"emission_enabled": material.emission_enabled,
		"emission": material.emission,
		"emission_energy_multiplier": material.emission_energy_multiplier,
	}


func _count_visual_resources() -> Dictionary:
	var counts := {
		"node_count": 1,
		"mesh_instance_nodes": 0,
		"particle_nodes": 0,
		"geometry_submissions": 0,
		"material_bindings": 0,
		"light_nodes": 0,
		"collision_shape_nodes": 0,
	}
	for candidate in find_children("*", "", true, false):
		counts.node_count = int(counts.node_count) + 1
		if candidate is MeshInstance3D:
			var mesh_instance := candidate as MeshInstance3D
			counts.mesh_instance_nodes = int(counts.mesh_instance_nodes) + 1
			if mesh_instance.mesh != null:
				counts.geometry_submissions = (
					int(counts.geometry_submissions) + mesh_instance.mesh.get_surface_count()
				)
				counts.material_bindings = (
					int(counts.material_bindings)
					+ _count_bound_mesh_materials(mesh_instance.mesh)
				)
		elif candidate is CPUParticles3D:
			var particles := candidate as CPUParticles3D
			counts.particle_nodes = int(counts.particle_nodes) + 1
			if particles.mesh != null:
				counts.geometry_submissions = (
					int(counts.geometry_submissions) + particles.mesh.get_surface_count()
				)
				counts.material_bindings = (
					int(counts.material_bindings)
					+ _count_bound_mesh_materials(particles.mesh)
				)
		if candidate is Light3D:
			counts.light_nodes = int(counts.light_nodes) + 1
		if candidate is CollisionShape3D:
			counts.collision_shape_nodes = int(counts.collision_shape_nodes) + 1
	return counts


func _count_bound_mesh_materials(mesh: Mesh) -> int:
	var bound := 0
	for surface_index in mesh.get_surface_count():
		if mesh.surface_get_material(surface_index) != null:
			bound += 1
	return bound


func _visual_material_binding_contract() -> Dictionary:
	var bindings := {}
	for candidate in find_children("*", "", true, false):
		var mesh: Mesh
		if candidate is MeshInstance3D:
			mesh = (candidate as MeshInstance3D).mesh
		elif candidate is CPUParticles3D:
			mesh = (candidate as CPUParticles3D).mesh
		if mesh == null:
			continue
		var relative_path := str(get_path_to(candidate))
		for surface_index in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface_index)
			bindings["%s#%d" % [relative_path, surface_index]] = (
				material.get_instance_id() if material != null else 0
			)
	return bindings


func _build_courier_fittings() -> void:
	var parts: Array = []
	# Formed nacelle roots blend the aft pressure bulkhead into engine housings.
	for side in [-1.0, 1.0]:
		parts.append([Vector3(side * 0.92, 0.05, 3.1), Vector3.ZERO, 0, Vector3.ZERO, [
			Vector4(-1.25, 0.24, 0.48, 0), Vector4(-0.5, 0.59, 0.61, 0),
			Vector4(0.55, 0.67, 0.64, 0), Vector4(1.1, 0.5, 0.52, 0),
		]])
	for side in [-1.0,1.0]:
		parts.append([Vector3(side*1.1,0.22,0.45),Vector3(0.06,0.74,5.14),2])
		for panel in 4:
			parts.append([Vector3(side*1.14,0.25,-1.4+panel*1.21),Vector3(0.08,0.62,1.08),0])
		# Cargo cradles have an exposed clamp at each end and longitudinal rails.
		for end in [-1.0,1.0]:
			parts.append([Vector3(side*2.5,0.23,0.6+end*1.75),Vector3(1.15,0.17,0.24),1])
			parts.append([Vector3(side*2.5,-0.96,0.6+end*1.75),Vector3(1.13,0.14,0.25),2])
			parts.append([Vector3(side*3.09,-0.34,0.6+end*1.75),Vector3(0.14,1.1,0.23),2])
		parts.append([Vector3(side*2.5,0.32,0.6),Vector3(0.38,0.07,3.7),0])
		parts.append([Vector3(side*3.12,-0.25,0.6),Vector3(0.08,0.34,3.13),0])
		parts.append([Vector3(side*1.15,0.68,3.86),Vector3(0.68,0.12,1.28),0])
		for slot in 4:
			parts.append([Vector3(side*1.15,0.75,3.41+slot*0.26),Vector3(0.5,0.025,0.1),2])
		# The dorsal service saddle contacts the shell above its clear throat.
	# Flush locks and hinges belong to the three broad dorsal access covers.
	for bay in 3:
		var z := -0.70 + bay * 1.40
		parts.append([Vector3(0,_courier_roof_height(0.0,z+0.32)+0.118,z+0.32),Vector3(0.3,0.035,0.12),2])
		for side in [-1.0,1.0]:
			parts.append([Vector3(side*0.62,_courier_roof_height(side*0.62,z-0.35)+0.082,z-0.35),Vector3(0.13,0.055,0.26),1])
	for side in [-1.0,1.0]:
		# End bulkheads protect the load valves instead of ending in plain discs.
		parts.append([Vector3(side*2.5,-0.37,-1.77),Vector3(0.61,0.64,0.11),2])
		parts.append([Vector3(side*2.5,-0.37,-1.85),Vector3(0.37,0.4,0.075),0])
		for station in 3:
			var z := -0.63+station*1.2
			parts.append([Vector3(side*3.12,-0.28,z),Vector3(0.09,0.62,0.83),1])
			parts.append([Vector3(side*3.18,-0.28,z),Vector3(0.035,0.34,0.58),2])
		parts.append([Vector3(side*0.66,0.36,-3.72),Vector3(0.24,0.11,0.58),2,Vector3(0,side*-0.24,0)])
	parts.append([Vector3(0,-0.07,3.93),Vector3(1.32,1.05,0.09),2])
	parts.append([Vector3(0,-0.07,3.99),Vector3(0.91,0.78,0.07),0])
	for rib in 4:
		parts.append([Vector3(0,-0.32+rib*0.17,4.04),Vector3(0.65,0.07,0.05),2])
	_fit_armour(parts,[_materials.courier_hull,_materials.courier_clay,_materials.courier_shadow])
	_build_courier_upperworks()


## The flight cab has a sloped windscreen, side glazing, a weather roof and a
## pressure collar. Roof covers share the hull's shoulders instead of floating
## above the stripe on individual slabs. All opaque pieces join the existing
## material batches; only the glazing keeps its own renderer.
func _build_courier_upperworks() -> void:
	var opaque: Array = [[], [], []]
	# Drawn pressure collar rolls into the bow, then broadens beneath the cab
	# cheeks. The crown overlaps the glazing sill instead of leaving a shelf.
	opaque[0].append(_courier_cab_shell_mesh(false, _materials.courier_hull))
	_box_from_mesh(_visual_root, "Canopy", Vector3.ZERO, _courier_upper_mesh([
		Vector4(-3.40,0.36,0.32,0.965), Vector4(-2.95,0.63,0.49,1.42),
		Vector4(-2.02,0.67,0.51,1.44), Vector4(-1.76,0.63,0.50,1.15),
	], 0.94, _materials.glass))
	# One formed weather crown continues around the rear pressure bulkhead and
	# eases down into the hull service roof, with no separate rectangular cap.
	opaque[0].append(_courier_cab_shell_mesh(true, _materials.courier_hull))
	# A centre mullion and two raked corner posts trace the windscreen edges.
	for side in [-1.0, 0.0, 1.0]:
		var start := Vector3(side*0.34,0.955,-3.40)
		var finish := Vector3(side*0.50,1.45,-2.97)
		var beam := _armour_mesh(Vector3(0.055,0.052,start.distance_to(finish)), _materials.courier_clay)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(_materials.courier_clay)
		surface.append_from(beam,0,Transform3D(Basis.looking_at(finish-start), (start+finish)*0.5))
		opaque[1].append(surface.commit())
	# Three thin removable skins follow the pressure roof into its shoulders.
	# Their narrow transverse gaps reveal the continuous recessed service seal.
	for bay in 3:
		var z := -1.51 + bay*1.51
		opaque[0].append(_courier_roof_mesh(z, z+1.465, 0.024, _materials.courier_hull))
	var fittings := _visual_root.get_node(^"FittedArmourAndServices") as MeshInstance3D
	var combined := ArrayMesh.new()
	for material_index in 3:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(fittings.mesh.surface_get_material(material_index))
		surface.append_from(fittings.mesh,material_index,Transform3D.IDENTITY)
		for piece: ArrayMesh in opaque[material_index]:
			surface.append_from(piece,0,Transform3D.IDENTITY)
		surface.commit(combined)
	fittings.mesh = combined


## Closed formed cab shell. Each section gives z, half-width, shoulder height
## and crown rise. The sampled arch changes the silhouette in both directions;
## normals follow its actual transverse and longitudinal tangents. The lower
## return is thin over the glazing, deepening into the aft pressure bulkhead.
func _courier_cab_shell_mesh(weather_roof: bool, material: Material) -> ArrayMesh:
	var sections: Array[Vector4]
	var bottoms: PackedFloat32Array
	if weather_roof:
		sections = [
			Vector4(-3.00,0.50,1.44,0.035), Vector4(-2.87,0.54,1.445,0.105),
			Vector4(-2.64,0.57,1.45,0.155), Vector4(-2.35,0.59,1.455,0.16),
			Vector4(-2.02,0.57,1.46,0.105), Vector4(-1.89,0.62,1.32,0.115),
			Vector4(-1.76,0.69,1.17,0.11), Vector4(-1.62,0.76,0.99,0.10),
			Vector4(-1.49,0.82,0.88,0.078),
		]
		bottoms = PackedFloat32Array([1.405,1.41,1.415,1.42,1.425,1.285,0.85,0.83,0.81])
	else:
		sections = [
			Vector4(-3.78,0.29,0.62,0.14), Vector4(-3.60,0.43,0.735,0.17),
			Vector4(-3.40,0.57,0.805,0.175), Vector4(-3.13,0.77,0.875,0.15),
			Vector4(-2.70,0.82,0.885,0.13), Vector4(-2.10,0.84,0.88,0.13),
			Vector4(-1.83,0.82,0.88,0.12), Vector4(-1.49,0.82,0.86,0.09),
		]
		bottoms = PackedFloat32Array([0.53,0.60,0.66,0.72,0.74,0.74,0.74,0.74])
	const ARCH_STEPS := 16
	var rings: Array[PackedVector3Array] = []
	for station in sections.size():
		var section := sections[station]
		var ring := PackedVector3Array()
		for step in ARCH_STEPS+1:
			var angle := -PI*0.5+PI*float(step)/float(ARCH_STEPS)
			ring.append(Vector3(section.y*sin(angle),section.z+section.w*cos(angle),section.x))
		ring.append(Vector3(section.y,bottoms[station],section.x))
		ring.append(Vector3(-section.y,bottoms[station],section.x))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for station in rings.size()-1:
		for edge in rings[station].size():
			var next := (edge+1)%rings[station].size()
			if edge >= ARCH_STEPS:
				_emit_armour_triangle(surface,rings[station][edge],rings[station+1][edge],rings[station+1][next])
				_emit_armour_triangle(surface,rings[station][edge],rings[station+1][next],rings[station][next])
				continue
			for address: Vector2i in [Vector2i(station,edge),Vector2i(station+1,next),Vector2i(station+1,edge),
				Vector2i(station,edge),Vector2i(station,next),Vector2i(station+1,next)]:
				var point := rings[address.x][address.y]
				var around := rings[address.x][mini(ARCH_STEPS,address.y+1)]-rings[address.x][maxi(0,address.y-1)]
				var along := rings[mini(rings.size()-1,address.x+1)][address.y]-rings[maxi(0,address.x-1)][address.y]
				surface.set_normal(along.cross(around).normalized())
				surface.set_uv(Vector2(float(address.y)/float(ARCH_STEPS),point.z))
				surface.add_vertex(point)
	# Convex section ends close against bow and service roof respectively.
	for end in [0,rings.size()-1]:
		var ring := rings[end]
		for edge in range(1,ring.size()-1):
			if end == 0:
				_emit_armour_triangle(surface,ring[0],ring[edge],ring[edge+1])
			else:
				_emit_armour_triangle(surface,ring[0],ring[edge+1],ring[edge])
	surface.generate_tangents()
	return surface.commit()


## Exact roof profile of HullBody, including its aft taper and eight-segment
## quarter shoulders. Covers stop partway round that shoulder, not on a flat
## platform above it. Coordinates remain in the production visual root.
func _courier_roof_height(x: float, z: float) -> float:
	var taper := clampf((z-2.1), 0.0, 1.0)
	var width := lerpf(1.1, 1.03, taper)
	var height := lerpf(0.85, 0.78, taper)
	var offset := -0.01*taper
	var fraction := absf(x)/width
	if fraction <= 0.64:
		return height+offset
	for step in 8:
		var a := PI*0.5-float(step)*PI/16.0
		var b := a-PI/16.0
		var start := Vector2(0.64+0.36*cos(a),0.48+0.52*sin(a))
		var finish := Vector2(0.64+0.36*cos(b),0.48+0.52*sin(b))
		if fraction <= finish.x:
			return lerpf(start.y,finish.y,(fraction-start.x)/(finish.x-start.x))*height+offset
	return 0.48*height+offset


## A closed pressed service skin: a gently crowned centre and curved shoulders,
## with a 35 mm returned edge seated into the hull. The underlying seal uses
## the same profile, so each cover gap exposes a recess without a raised shelf.
func _courier_roof_mesh(start_z: float, end_z: float, lift: float, material: Material) -> ArrayMesh:
	var fractions := PackedFloat32Array()
	for side in [-1.0,1.0]:
		for step in 7:
			var angle := PI*0.5-float(step)*PI/16.0
			fractions.append(side*(0.64+0.36*cos(angle)))
	fractions.append(0.0)
	fractions.sort()
	var stations := PackedFloat32Array([start_z,end_z])
	if start_z < 2.1 and end_z > 2.1:
		stations.insert(1,2.1)
	var rings: Array[PackedVector3Array] = []
	for z in stations:
		var width := lerpf(1.1,1.03,clampf(z-2.1,0.0,1.0))
		var ring := PackedVector3Array()
		for fraction in fractions:
			var x := fraction*width
			var crown := 0.083*(1.0-pow(absf(fraction)/fractions[-1],2.0))
			ring.append(Vector3(x,_courier_roof_height(x,z)+0.009+crown+lift,z))
		for index in range(fractions.size()-1,-1,-1):
			var point := ring[index]
			point.y -= 0.035
			ring.append(point)
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for station in rings.size()-1:
		for edge in rings[station].size():
			var next := (edge+1)%rings[station].size()
			if edge == fractions.size()-1 or next == 0:
				_emit_armour_triangle(surface,rings[station][edge],rings[station+1][edge],rings[station+1][next])
				_emit_armour_triangle(surface,rings[station][edge],rings[station+1][next],rings[station][next])
				continue
			# Smooth the rolled skin across profile stations while keeping its thin
			# cut ends and returned edges crisp. The silhouette still has real arcs.
			var first := 0 if edge < fractions.size() else fractions.size()
			var last := fractions.size()-1 if first == 0 else rings[station].size()-1
			for address: Vector2i in [Vector2i(station,edge),Vector2i(station+1,next),Vector2i(station+1,edge),
				Vector2i(station,edge),Vector2i(station,next),Vector2i(station+1,next)]:
				var point := rings[address.x][address.y]
				var around := rings[address.x][mini(last,address.y+1)]-rings[address.x][maxi(first,address.y-1)]
				var along := rings[mini(rings.size()-1,address.x+1)][address.y]-rings[maxi(0,address.x-1)][address.y]
				surface.set_normal(along.cross(around).normalized())
				surface.set_uv(Vector2(point.x,point.z))
				surface.add_vertex(point)
	# Cap each wafer as a strip: a fan would overlap this concave section.
	for end in [0,rings.size()-1]:
		var ring := rings[end]
		for edge in fractions.size()-1:
			var a := ring[edge]
			var b := ring[edge+1]
			var c := ring[ring.size()-2-edge]
			var d := ring[ring.size()-1-edge]
			if end == 0:
				_emit_armour_triangle(surface,a,b,c)
				_emit_armour_triangle(surface,a,c,d)
			else:
				_emit_armour_triangle(surface,a,c,b)
				_emit_armour_triangle(surface,a,d,c)
	surface.generate_tangents()
	return surface.commit()


## Closed planar pressure fittings: stations contain z, lower half-width,
## upper half-width and crown height. The bottom remains seated on its mount.
func _courier_upper_mesh(stations: Array, bottom: float, material: Material) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = []
	for station: Vector4 in stations:
		rings.append(PackedVector3Array([
			Vector3(-station.z,station.w,station.x), Vector3(station.z,station.w,station.x),
			Vector3(station.y,bottom,station.x), Vector3(-station.y,bottom,station.x),
		]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for station in rings.size()-1:
		for edge in 4:
			var next := (edge+1)%4
			_emit_armour_triangle(surface,rings[station][edge],rings[station+1][edge],rings[station+1][next])
			_emit_armour_triangle(surface,rings[station][edge],rings[station+1][next],rings[station][next])
	for edge in range(1,3):
		_emit_armour_triangle(surface,rings[0][0],rings[0][edge],rings[0][edge+1])
		_emit_armour_triangle(surface,rings[-1][0],rings[-1][edge+1],rings[-1][edge])
	surface.generate_tangents()
	return surface.commit()


## Continuous rolled nacelle, recessed passive liner and external retention ring.
## Both sides share stock; only existing plume/light owners emit engine light.
func _courier_engine_mesh(collar: bool) -> ArrayMesh:
	var profile := PackedVector2Array([
		Vector2(0.0, -0.9), Vector2(0.46, -0.9),
		Vector2(0.59, -0.78), Vector2(0.62, -0.62),
		Vector2(0.62, 0.47), Vector2(0.60, 0.59),
		Vector2(0.57, 0.96), Vector2(0.55, 1.06),
		Vector2(0.47, 1.06), Vector2(0.44, 0.96),
		Vector2(0.35, 0.57), Vector2(0.28, 0.40),
		Vector2(0.0, 0.40),
	])
	if collar:
		profile = PackedVector2Array([
			Vector2(0.619, 0.30), Vector2(0.66, 0.33),
			Vector2(0.66, 0.43), Vector2(0.62, 0.49),
			Vector2(0.619, 0.30),
		])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_materials.courier_clay)
	var distance := 0.0
	const SEGMENTS := 64
	for section in profile.size() - 1:
		var start := profile[section]
		var end := profile[section + 1]
		var slope := end - start
		var tint := Color(0.27, 0.29, 0.30)
		if collar or section in [6, 7]:
			tint = Color(0.72, 0.67, 0.58)
		elif section >= 8:
			tint = Color(0.035, 0.04, 0.045)
		for segment in SEGMENTS:
			var a := TAU * float(segment) / float(SEGMENTS)
			var b := TAU * float(segment + 1) / float(SEGMENTS)
			var points := PackedVector3Array([
				Vector3(cos(a) * start.x, sin(a) * start.x, start.y),
				Vector3(cos(b) * start.x, sin(b) * start.x, start.y),
				Vector3(cos(b) * end.x, sin(b) * end.x, end.y),
				Vector3(cos(a) * end.x, sin(a) * end.x, end.y),
			])
			for triangle in [[0, 2, 1], [0, 3, 2]]:
				if (points[triangle[2]] - points[triangle[0]]).cross(points[triangle[1]] - points[triangle[0]]).length_squared() < 1e-12:
					continue
				for index in triangle:
					var point := points[index]
					var radial := Vector2(point.x, point.y).normalized()
					surface.set_normal(Vector3(slope.y * radial.x, slope.y * radial.y, -slope.x).normalized())
					surface.set_color(tint)
					if not collar and section in [0, 11]:
						surface.set_uv(Vector2(point.x, point.y))
					else:
						surface.set_uv(Vector2(float(segment + (1 if index in [1, 2] else 0)) / float(SEGMENTS), distance + (slope.length() if index in [2, 3] else 0.0)))
					surface.add_vertex(point)
		distance += slope.length()
	surface.generate_tangents()
	var mesh := surface.commit()
	mesh.resource_local_to_scene = false
	return mesh
