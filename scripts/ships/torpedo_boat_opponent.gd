class_name TorpedoBoatOpponent
extends ResolverBackedOpponent

## Torpedo boat — an opponent whose one weapon you can see coming, dodge, and
## shoot down.
##
## Every other opponent weapon in the yard is either instantaneous or a straight
## travelling bolt. This craft carries slow seeker torpedoes instead: it holds
## off at stand-off range, spends a long, loudly telegraphed lock on the player
## (lime brackets closing over its hull while its charge lenses swell), and then
## launches one torpedo that steers toward the player at a bounded turn rate.
##
## The counters are the point, and each is real authority rather than a scripted
## escape:
##   * break the lock — leave its firing cone or put structure between you and it
##     while the brackets are closing, and the inherited charge is cancelled;
##   * dodge — a torpedo turns at 42 deg/s at 34 m/s, so a hard break across its
##     nose makes it overshoot, and once the target is far enough off its nose the
##     seeker gives up for good and the torpedo runs straight until it expires;
##   * shoot it down — every torpedo carries its own small Damageable on a
##     generous hurtbox, and destroying it drops its authority flight before any
##     arrival can be committed;
##   * kill the boat — its torpedoes still in the air fizzle with it.
##
## Authority reuse (nothing here owns a second damage path):
##   * identity, faction and travel envelope  -> LiveCombatAuthority.register_source
##   * every torpedo                          -> one resolver flight, opened at launch
##                                               and committed on its terminal segment
##   * the torpedo's own health               -> a stock Damageable the one resolver
##                                               damages like any other target
##   * hull/damage/destruction lifecycle      -> inherited from RangeOpponent
##   * fire/impact cues                       -> the shared CombatAudioPresentation
##   * launch/lock/flight/intercept/detonation -> the pool's TorpedoRunAudio bank
##   * fire rights                            -> the dispatching scenario, re-asked on
##                                               the launch frame
##
## The torpedo pool must stay a child of this craft: the resolver excludes a
## source's own collision tree from its terminal re-sweep, which is what keeps a
## torpedo from detonating on its own (or its sibling's) hurtbox.
##
## Evidence status: modern_interpretation. No original Keth Shipyards craft,
## weapon, tactic, or class name is authenticated or claimed here.

signal torpedo_away(record: Dictionary)
signal torpedo_intercepted(record: Dictionary)
signal torpedo_detonated(record: Dictionary, result: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"torpedo-boat-opponent"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DISPLAY_NAME := "Torpedo boat"

const DEFAULT_SOURCE_ID := 2106
const TORPEDO_WEAPON_ID: StringName = &"torpedo_boat_seeker"
## Authored warhead and travel envelope. 34 m/s for 7.5 s covers 255 m, which
## meets the 250 m registered range the resolver requires a flight to reach.
const TORPEDO_RANGE := 250.0
const TORPEDO_DAMAGE := 34.0
const TORPEDO_SPEED := 34.0
const TORPEDO_LIFETIME := 7.5
const TORPEDO_RADIUS := 0.6
const TORPEDO_ORIGIN_TOLERANCE := 14.0
const TORPEDO_POOL_CAPACITY := 2
## Launch from under the nose, clear of the hull collision.
const TORPEDO_TUBE_OFFSET := Vector3(0.0, -1.35, -5.4)

## Lock cue: two steady lime strokes above the hull name what the launcher is
## doing, read from the state that already drives it. Presentation only.
const LOCK_CUE_ID: StringName = &"torpedo_boat_lock"
const POSTURE_NONE: StringName = &""
const POSTURE_STALKING: StringName = &"stalking"
const POSTURE_LOCKING: StringName = &"locking"
const POSTURE_TRACKING: StringName = &"tracking"
## The closing brackets move in discrete steps rather than continuously, so any
## frame of one lock step photographs identically to any other.
const LOCK_STEP_COUNT := 3
const LOCK_STROKE_WIDTH := 0.6
const LOCK_STROKE_DEPTH := 0.35
const LOCK_LIME := Color("d4ff3a")
const LOCK_EMISSION_ENERGY := 4.8
const REDUCED_FLASH_LOCK_EMISSION_ENERGY := 1.6
const TUBE_COLOR := Color("2d3530")

var _torpedoes: SeekerTorpedoProjectile
var _lock_cue: Node3D
var _lock_strokes: Array[MeshInstance3D] = []
var _lock_material: StandardMaterial3D
var _reduced_lock_material: StandardMaterial3D
var _lock_visible: StringName = POSTURE_NONE
var _lock_visible_step := -1
var _lock_target_instance_id := 0
var _lock_activation_generation := 0
var _torpedoes_launched := 0
var _torpedoes_intercepted := 0
var _torpedo_hits := 0
var _launch_warning_given := false
var _weapon_definition: WeaponDefinition


# ------------------------------------------------------------- lifecycle ----

func _ready() -> void:
	if source_id <= 0:
		source_id = DEFAULT_SOURCE_ID
	weapon_range = TORPEDO_RANGE
	weapon_damage = TORPEDO_DAMAGE
	weapon_origin_tolerance = TORPEDO_ORIGIN_TOLERANCE
	_weapon_definition = _build_weapon_definition()
	super()
	set_meta("component_id", COMPONENT_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("historically_supported", false)
	set_meta("modern_interpretation", &"torpedo_boat_opponent")
	_ensure_torpedo_pool()
	_build_torpedo_tubes()
	_build_lock_cue()


func _exit_tree() -> void:
	# The pool abandons its own flights on exit; the cue must not survive a
	# streamed detach showing a lock for a scenario that no longer exists.
	_clear_lock_cue()
	super()


func activate(spawn_transform: Transform3D) -> Dictionary:
	var activation := super(spawn_transform) as Dictionary
	if not bool(activation.get("accepted", false)):
		return activation
	_ensure_torpedo_pool()
	_torpedoes.abandon_all(&"reactivated")
	_torpedoes.bind_authority(_get_combat_authority())
	_torpedoes.faction_id = faction_id
	_torpedoes_launched = 0
	_torpedoes_intercepted = 0
	_torpedo_hits = 0
	_launch_warning_given = false
	_clear_lock_cue()
	_sync_lock_cue()
	return activation


func deactivate() -> void:
	if is_instance_valid(_torpedoes):
		_torpedoes.abandon_all(&"stood_down")
	_clear_lock_cue()
	super()


func _destroy_interceptor(death_position: Vector3) -> void:
	# Killing the launcher takes its torpedoes out of the air with it.
	if is_instance_valid(_torpedoes):
		_torpedoes.abandon_source_torpedoes(self, &"launcher_destroyed")
	_clear_lock_cue()
	super(death_position)


func _restore_after_reentry() -> void:
	super()
	if is_instance_valid(_torpedoes):
		_torpedoes.bind_authority(_get_combat_authority())


# -------------------------------------------------------- public contract ----

func get_display_name() -> String:
	return DISPLAY_NAME


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_weapon_id() -> StringName:
	return TORPEDO_WEAPON_ID


func get_combat_audio_profile_id() -> StringName:
	return CombatAudioPresentation.WEAPON_PROFILE_SIEGE_LANCE


func get_weapon_definition() -> WeaponDefinition:
	if _weapon_definition == null:
		_weapon_definition = _build_weapon_definition()
	return _weapon_definition.duplicate(true) as WeaponDefinition


## Immutable authority envelope, converted through the one fail-closed seam, so
## the torpedo registers with its travel envelope or not at all.
func get_weapon_profiles() -> Dictionary:
	var definition := get_weapon_definition()
	if definition == null or definition.weapon_id != TORPEDO_WEAPON_ID:
		return {}
	return WeaponDefinitionResolverProfile.to_resolver_profiles(
		definition,
		faction_id,
		weapon_origin_tolerance,
	)


func get_torpedo_pool() -> SeekerTorpedoProjectile:
	return _torpedoes if is_instance_valid(_torpedoes) else null


func get_torpedoes_launched() -> int:
	return _torpedoes_launched


func get_torpedoes_intercepted() -> int:
	return _torpedoes_intercepted


func get_torpedo_hits() -> int:
	return _torpedo_hits


func get_sustained_damage_per_second() -> float:
	return TORPEDO_DAMAGE / maxf(0.001, telegraph_time + weapon_cooldown)


func get_tactics_profile() -> Dictionary:
	var profile := super() as Dictionary
	profile["weapon_range"] = TORPEDO_RANGE
	profile["weapon_damage"] = TORPEDO_DAMAGE
	profile["sustained_damage_per_second"] = get_sustained_damage_per_second()
	profile["projectile_speed"] = TORPEDO_SPEED
	profile["projectile_turn_rate_degrees"] = (
		_torpedoes.turn_rate_degrees if is_instance_valid(_torpedoes)
		else SeekerTorpedoProjectile.DEFAULT_TURN_RATE_DEGREES
	)
	profile["projectile_destructible"] = true
	return profile


## Detached view of the lock strokes. The posture is derived from the charge,
## the torpedo pool and the target that already drive the craft; the cue selects
## nothing and moves nothing.
func get_lock_cue_snapshot() -> Dictionary:
	var active := _is_lock_cue_current()
	return {
		"cue_id": LOCK_CUE_ID,
		"active": active,
		"posture": _lock_visible if active else POSTURE_NONE,
		"lock_step": _lock_visible_step if active else -1,
		"target_instance_id": _lock_target_instance_id if active else 0,
		"activation_generation": _lock_activation_generation if active else 0,
		"reduced_flash": _reduced_flash,
		"emission_energy": (
			REDUCED_FLASH_LOCK_EMISSION_ENERGY if _reduced_flash else LOCK_EMISSION_ENERGY
		),
		"flicker": false,
		"presentation_only": true,
		"movement_authority": false,
		"fire_authority": false,
	}.duplicate(true)


func set_reduced_flash_enabled(enabled: bool) -> Dictionary:
	var result := super(enabled) as Dictionary
	if is_instance_valid(_torpedoes):
		_torpedoes.set_reduced_flash_enabled(enabled)
	_apply_lock_material()
	result["torpedo_presentation"] = (
		_torpedoes.get_presentation_profile_snapshot() if is_instance_valid(_torpedoes) else {}
	)
	result["lock_cue"] = get_lock_cue_snapshot()
	return result


func get_resolver_backed_errors() -> PackedStringArray:
	var errors := super() as PackedStringArray
	if get_weapon_profiles().is_empty():
		errors.append("torpedo weapon definition does not convert to a resolver profile")
	if not is_instance_valid(_torpedoes) or _torpedoes.get_parent() != self:
		errors.append("the torpedo pool must be a child of its launcher")
	elif not _torpedoes.get_validation_errors().is_empty():
		for error in _torpedoes.get_validation_errors():
			errors.append("torpedo pool: %s" % error)
	return errors


# ------------------------------------------------------- fire authority ----

## Launches one seeker torpedo. Re-asks the scenario's fire gate on the launch
## frame, exactly like every resolver-backed archetype; the torpedo then belongs
## to one authority flight whose arrival the resolver alone commits.
func _fire_at_target(target_position: Vector3) -> void:
	if not _active or not is_inside_tree():
		return
	if not _is_fire_authorized():
		_telegraph_remaining = 0.0
		_cooldown_remaining = maxf(_cooldown_remaining, weapon_cooldown)
		_shots_withheld += 1
		_last_shot_result = {"accepted": false, "status": &"fire_unauthorized"}
		return
	var authority := _get_combat_authority()
	if not is_instance_valid(authority) or not _registered or not _has_current_target():
		_cooldown_remaining = weapon_cooldown
		return
	_ensure_torpedo_pool()
	if _torpedoes.get_bound_authority() != authority:
		_torpedoes.bind_authority(authority)
	var origin := global_transform * TORPEDO_TUBE_OFFSET
	var direction := target_position - origin
	if direction.length_squared() <= 0.000001:
		direction = -global_basis.z
	# Leaves the tube along the boat's nose, pitched toward the target: the seeker
	# does the rest after its straight run off the rail.
	direction = (-global_basis.z).slerp(direction.normalized(), 0.5).normalized()
	var launch := _torpedoes.launch(self, TORPEDO_WEAPON_ID, origin, direction, _target)
	_cooldown_remaining = weapon_cooldown
	_last_shot_result = launch.duplicate(true)
	if not bool(launch.get("accepted", false)):
		return
	_shots_fired += 1
	_torpedoes_launched += 1
	_spawn_muzzle_flash(origin)
	_play_weapon_fire_audio(origin)
	if not _launch_warning_given:
		_launch_warning_given = true
		var hud := get_node_or_null(hud_path)
		if is_instance_valid(hud) and hud.has_method(&"toast"):
			hud.call(
				&"toast",
				"Torpedo inbound",
				"Break hard across its nose, or shoot it down",
				3.0
			)
	_sync_lock_cue()
	torpedo_away.emit((launch.get("record", {}) as Dictionary).duplicate(true))


func _on_torpedo_resolved(record: Dictionary, result: Dictionary) -> void:
	var position := record.get("terminal_position", Vector3.INF) as Vector3
	if bool(result.get("damaged", false)):
		_torpedo_hits += 1
		var origin := record.get("position", position) as Vector3
		_flash_target_damage(origin, result)
		var audio := _get_combat_audio()
		if is_instance_valid(audio) and position.is_finite() and is_inside_tree():
			audio.play_impact(position, 1.0, get_instance_id())
			if bool(result.get("destroyed", false)):
				audio.play_explosion(position, maxi(get_instance_id(), 0))
	_sync_lock_cue()
	torpedo_detonated.emit(record.duplicate(true), result.duplicate(true))


func _on_torpedo_intercepted(record: Dictionary) -> void:
	_torpedoes_intercepted += 1
	var position := record.get("position", Vector3.INF) as Vector3
	var audio := _get_combat_audio()
	if is_instance_valid(audio) and position.is_finite() and is_inside_tree():
		audio.play_impact(position, 0.6, get_instance_id())
	_sync_lock_cue()
	torpedo_intercepted.emit(record.duplicate(true))


func _on_torpedo_abandoned(_record: Dictionary, _reason: StringName) -> void:
	_sync_lock_cue()


# ------------------------------------------------------------ presentation ----

func _update_presentation(delta: float) -> void:
	super(delta)
	if _reduced_flash and _built and _active and _telegraph_remaining > 0.0:
		# The inherited charge lenses carry a small ~5 Hz shimmer and a pulsing
		# warning light. Under reduced flash they swell steadily instead and the
		# light stays dark; the lime lock brackets carry the read on their own.
		var progress := clampf(
			1.0 - _telegraph_remaining / maxf(telegraph_time, 0.001), 0.0, 1.0
		)
		var steady := Vector3.ONE * (0.8 + (0.22 + progress * 1.15) * 0.55)
		for lens in _warning_lenses:
			if is_instance_valid(lens):
				lens.scale = steady
		if is_instance_valid(_warning_light):
			_warning_light.light_energy = 0.0
	_sync_lock_cue()


func _ensure_torpedo_pool() -> void:
	if is_instance_valid(_torpedoes) and not _torpedoes.is_queued_for_deletion():
		return
	_torpedoes = SeekerTorpedoProjectile.new()
	_torpedoes.name = "SeekerTorpedoes"
	_torpedoes.pool_capacity = TORPEDO_POOL_CAPACITY
	_torpedoes.faction_id = faction_id
	add_child(_torpedoes)
	_torpedoes.bind_authority(_get_combat_authority())
	_torpedoes.set_reduced_flash_enabled(_reduced_flash)
	_torpedoes.torpedo_resolved.connect(_on_torpedo_resolved)
	_torpedoes.torpedo_intercepted.connect(_on_torpedo_intercepted)
	_torpedoes.torpedo_abandoned.connect(_on_torpedo_abandoned)


func _build_weapon_definition() -> WeaponDefinition:
	var definition := WeaponDefinition.new()
	definition.weapon_id = TORPEDO_WEAPON_ID
	definition.display_name = "Torpedo boat seeker torpedo"
	definition.resolution_mode = WeaponDefinition.ResolutionMode.PROJECTILE
	definition.evidence_status = WeaponDefinition.EvidenceStatus.NEW
	definition.evidence_notes = "Original-modern seeker torpedo tuning; not a recovered historical weapon specification."
	definition.range_meters = TORPEDO_RANGE
	definition.damage_per_hit = TORPEDO_DAMAGE
	definition.cadence_shots_per_second = 1.0 / maxf(0.2, weapon_cooldown)
	definition.projectile_speed_mps = TORPEDO_SPEED
	definition.projectile_lifetime_seconds = TORPEDO_LIFETIME
	definition.projectile_radius_meters = TORPEDO_RADIUS
	definition.presentation_id = &"seeker_torpedo"
	definition.fire_audio_id = &"torpedo_boat_launch"
	definition.impact_audio_id = &"torpedo_boat_warhead"
	definition.dry_fire_audio_id = &"torpedo_boat_tube_empty"
	return definition


## Two dark launch tubes slung under the hull with lime seeker caps make the
## boat read as "not the defender" at combat range.
func _build_torpedo_tubes() -> void:
	if not is_instance_valid(_visual_root) or _visual_root.has_node(^"TorpedoTubePort"):
		return
	var tube_material := _material(TUBE_COLOR, 0.6, 0.35)
	var cap_material := _material(LOCK_LIME, 0.1, 0.3, LOCK_LIME, 1.4)
	for side: float in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_cylinder(
			_visual_root, "TorpedoTube%s" % side_name,
			Vector3(side * 1.25, -1.2, -1.2), 0.42, 6.2, tube_material,
			Vector3(90.0, 0.0, 0.0)
		)
		_cylinder(
			_visual_root, "TorpedoTubeCap%s" % side_name,
			Vector3(side * 1.25, -1.2, -4.35), 0.34, 0.2, cap_material,
			Vector3(90.0, 0.0, 0.0)
		)


func _build_lock_cue() -> void:
	if is_instance_valid(_lock_cue):
		return
	_lock_material = _material(LOCK_LIME, 0.1, 0.2, LOCK_LIME, LOCK_EMISSION_ENERGY)
	_reduced_lock_material = _material(
		LOCK_LIME, 0.1, 0.2, LOCK_LIME, REDUCED_FLASH_LOCK_EMISSION_ENERGY
	)
	var stroke := BoxMesh.new()
	stroke.size = Vector3(1.0, LOCK_STROKE_WIDTH, LOCK_STROKE_DEPTH)
	_lock_cue = Node3D.new()
	_lock_cue.name = "TorpedoLockCue"
	_lock_cue.visible = false
	_lock_cue.process_mode = Node.PROCESS_MODE_DISABLED
	_lock_cue.set_meta(&"presentation_only", true)
	_lock_cue.set_meta(&"cue_id", LOCK_CUE_ID)
	add_child(_lock_cue)
	for index in 2:
		var instance := MeshInstance3D.new()
		instance.name = "PortStroke" if index == 0 else "StarboardStroke"
		instance.mesh = stroke
		instance.layers = 1
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lock_cue.add_child(instance)
		_lock_strokes.append(instance)
	_apply_lock_material()


func _apply_lock_material() -> void:
	var material := _reduced_lock_material if _reduced_flash else _lock_material
	for stroke in _lock_strokes:
		if is_instance_valid(stroke):
			stroke.material_override = material


func _is_lock_target_live() -> bool:
	if not _has_current_target():
		return false
	if _target.has_method(&"is_destroyed") and bool(_target.call(&"is_destroyed")):
		return false
	return true


## The one mapping from authoritative state to posture. Nothing here writes
## charge, target, movement or weapon state.
func _derive_lock_posture() -> StringName:
	if not _active or not is_inside_tree() or not _is_lock_target_live():
		return POSTURE_NONE
	if _telegraph_remaining > 0.0:
		return POSTURE_LOCKING
	if is_instance_valid(_torpedoes) and _torpedoes.get_active_torpedo_count() > 0:
		return POSTURE_TRACKING
	return POSTURE_STALKING


func _derive_lock_step(posture: StringName) -> int:
	if posture != POSTURE_LOCKING:
		return -1
	var progress := 1.0 - _telegraph_remaining / maxf(telegraph_time, 0.001)
	return clampi(int(floor(progress * float(LOCK_STEP_COUNT))), 0, LOCK_STEP_COUNT - 1)


func _is_lock_cue_current() -> bool:
	if not is_instance_valid(_lock_cue) or not _lock_cue.visible:
		return false
	var posture := _derive_lock_posture()
	return (
		posture != POSTURE_NONE
		and posture == _lock_visible
		and _lock_visible_step == _derive_lock_step(posture)
		and _lock_target_instance_id == _target.get_instance_id()
		and _lock_activation_generation == _activation_generation
	)


func _sync_lock_cue() -> void:
	if not is_instance_valid(_lock_cue):
		return
	var posture := _derive_lock_posture()
	if posture == POSTURE_NONE:
		_clear_lock_cue()
		return
	if _is_lock_cue_current():
		return
	var step := _derive_lock_step(posture)
	var left_from := Vector3.ZERO
	var left_to := Vector3.ZERO
	var right_from := Vector3.ZERO
	var right_to := Vector3.ZERO
	match posture:
		POSTURE_STALKING:
			# Two flat dashes: hunting, no lock yet.
			left_from = Vector3(-3.0, 4.3, 0.4)
			left_to = Vector3(-0.8, 4.3, 0.4)
			right_from = Vector3(0.8, 4.3, 0.4)
			right_to = Vector3(3.0, 4.3, 0.4)
		POSTURE_LOCKING:
			# Upright brackets that close in steps as the lock completes.
			var half_width := 3.6 - 1.0 * float(step)
			left_from = Vector3(-half_width, 2.4, 0.4)
			left_to = Vector3(-half_width, 6.2, 0.4)
			right_from = Vector3(half_width, 2.4, 0.4)
			right_to = Vector3(half_width, 6.2, 0.4)
		POSTURE_TRACKING:
			# A downward chevron: a torpedo from this boat is in the air.
			left_from = Vector3(-2.6, 6.4, 0.4)
			left_to = Vector3(0.0, 3.0, 0.4)
			right_from = Vector3(2.6, 6.4, 0.4)
			right_to = Vector3(0.0, 3.0, 0.4)
	_lock_strokes[0].transform = _lock_stroke(left_from, left_to)
	_lock_strokes[1].transform = _lock_stroke(right_from, right_to)
	_lock_visible = posture
	_lock_visible_step = step
	_lock_target_instance_id = _target.get_instance_id()
	_lock_activation_generation = _activation_generation
	_lock_cue.visible = true
	# Lock pips: the pool's audio bank voices each closing bracket step.
	if is_instance_valid(_torpedoes):
		_torpedoes.present_lock_cue(posture, step, global_position, _activation_generation)


func _lock_stroke(from_point: Vector3, to_point: Vector3) -> Transform3D:
	var vector := to_point - from_point
	var angle := atan2(vector.y, vector.x)
	return Transform3D(
		Basis(Vector3.BACK, angle) * Basis.from_scale(Vector3(maxf(vector.length(), 0.01), 1.0, 1.0)),
		(from_point + to_point) * 0.5
	)


func _clear_lock_cue() -> void:
	if is_instance_valid(_torpedoes):
		_torpedoes.present_lock_cue(POSTURE_NONE, -1, Vector3.INF, _activation_generation)
	_lock_visible = POSTURE_NONE
	_lock_visible_step = -1
	_lock_target_instance_id = 0
	_lock_activation_generation = 0
	if is_instance_valid(_lock_cue):
		_lock_cue.visible = false
