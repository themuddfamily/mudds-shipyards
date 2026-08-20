class_name ResolverBackedOpponent
extends RangeOpponent

## Shared authority plumbing for opponent archetypes that resolve their own
## shots on the single live `CombatResolver`.
##
## `GameFlow` hard-binds its pulse style, fire cue and damage handling to
## exactly two identities — the player fleet and `$RangeOpponent` — so any third
## combatant that raised `projectile_fired` and waited for the coordinator would
## either be presented in the player's cyan with the player's fire cue, or be
## dropped on the floor. `StandoffPicketOpponent` solved that for itself by
## submitting to the same resolver under its own registered identity. This base
## lifts that solution out so a *new* archetype does not have to copy eighty
## lines of receipt bookkeeping to get it, and so the fixes below apply to every
## archetype at once instead of once per craft.
##
## Authority reuse (nothing here owns a second damage path):
##   * identity, faction and weapon envelope    -> LiveCombatAuthority.register_source
##   * damage proxy                             -> LiveCombatAuthority.attach_lifecycle_damageable
##   * every shot                               -> the one live CombatResolver
##   * presentation receipts                    -> LiveCombatAuthority's 64-bit allocator
##   * hull/damage/destruction/debris lifecycle -> inherited from RangeOpponent
##   * shot visuals                             -> the shared fixed PulseWeaponPresentation pool
##   * fire/impact/explosion cues               -> the shared ten-voice CombatAudioPresentation
##
## ### The fire-time authorization gate
##
## `bugs.md` records, under SANDBOX-002, that the picket's withdrawal is keyed
## to the defender's `is_active()` and evaluated in the picket's own
## `_physics_process`, so a charge committed on the frame the defender dies can
## still land one lance during `RETURN_TO_YARD`. The general shape of that
## defect is: *dispatch* is authorized, and the craft then assumes the
## authorization survives until its next tactical update.
##
## Every archetype built on this base is gated the other way round.
## `_fire_at_target()` re-asks `_is_fire_authorized()` on the frame the shot is
## actually dispatched, and refuses if the answer has changed — a committed
## charge that becomes unauthorized mid-flight is dropped, not delivered. The
## authorization is the encounter's, not the craft's: a scenario that has
## concluded for *any* reason, including the player simply leaving, withdraws
## fire rights from everything it dispatched in the same call that concludes it.
##
## Evidence status: modern_interpretation. No original Keth Shipyards craft,
## weapon, tactic, or class name is authenticated or claimed by this component.

signal shot_resolved(origin: Vector3, direction: Vector3, result: Dictionary)

const RESOLVER_BACKED_SCHEMA_VERSION := 1
const MAX_PENDING_SHOT_RECEIPTS := 8

@export_category("Combat authority")
## Stable session identity. Must not collide with the fleet, the defender, the
## picket, or any sibling archetype.
@export var source_id := 0
@export var faction_id: StringName = &"range_defence"
@export var weapon_range := 220.0
@export var weapon_damage := 8.0
@export var weapon_origin_tolerance := 22.0

@export_category("Encounter wiring")
@export var combat_authority_path := NodePath("../CombatAuthority")
@export var pulse_presentation_path := NodePath("../PulseWeaponPresentation")
@export var combat_audio_path := NodePath("../CombatAudioPresentation")
@export var encounter_host_path := NodePath("..")
@export var hud_path := NodePath("../HUD")
## The scenario that dispatched this craft. When it is present it is the sole
## authority on whether this craft may fire; when it is absent (isolated
## fixtures, evidence harnesses, tools) the craft's own `_active` latch is.
@export var scenario_director_path := NodePath("../EncounterScenarios")

var _registered := false
var _shot_receipts: Dictionary = {}
var _shot_receipt_order: Array[int] = []
var _pulse_signals_connected := false
var _shots_fired := 0
var _shots_withheld := 0
var _last_shot_result: Dictionary = {}


# ------------------------------------------------------------- lifecycle ----

func _enter_tree() -> void:
	super()
	# A whole-`Main` detach/re-entry re-adds this node without calling `_ready()`
	# again. Restoring the registration is deferred so the coordinator's own
	# deferred combat restore observes the same source roster it built at boot.
	if _built:
		call_deferred("_restore_after_reentry")


func _ready() -> void:
	super()
	_attach_damage_proxy()
	_connect_pulse_signals()


func _exit_tree() -> void:
	_disconnect_pulse_signals()
	# Damage authority is already final; only queued presentation is dropped so a
	# streamed teardown can never resurrect a transient on re-entry.
	_discard_shot_receipts()
	# The resolver drops the live registration through its own `tree_exiting`
	# hook while deliberately retaining this identity's replay high-water mark.
	# Mirror that here so the claim cannot outlive the registration it describes.
	_registered = false
	super()


func activate(spawn_transform: Transform3D) -> Dictionary:
	var activation := super(spawn_transform) as Dictionary
	if not bool(activation.get("accepted", false)):
		return activation
	_shots_fired = 0
	_shots_withheld = 0
	_last_shot_result = {}
	_discard_shot_receipts()
	_register_combat_source()
	return activation


func deactivate() -> void:
	_release_combat_registration()
	_discard_shot_receipts()
	super()


func _destroy_interceptor(death_position: Vector3) -> void:
	_release_combat_registration()
	super(death_position)


func _restore_after_reentry() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	_connect_pulse_signals()
	_attach_damage_proxy()
	if _active:
		_register_combat_source()


# -------------------------------------------------------- public contract ----

func get_display_name() -> String:
	return "Resolver-backed opponent"


func get_component_id() -> StringName:
	return &"resolver-backed-opponent"


func get_pulse_style_id() -> StringName:
	return PulseWeaponPresentation.STYLE_AMBER


func get_weapon_id() -> StringName:
	return &"resolver_backed_cannon"


## Stable ordering key used by `WingCoordinator` to break exact geometric ties.
func get_wing_priority() -> int:
	return source_id


func is_combat_source_registered() -> bool:
	return _registered


func get_pending_shot_receipt_count() -> int:
	return _shot_receipts.size()


func get_shots_fired() -> int:
	return _shots_fired


## Shots this craft charged and then deliberately did not dispatch because the
## encounter had withdrawn its fire rights. A non-zero value here is the
## SANDBOX-002 class of defect being caught rather than delivered.
func get_shots_withheld() -> int:
	return _shots_withheld


func get_last_shot_result() -> Dictionary:
	return _last_shot_result.duplicate(true)


## Immutable authority envelope submitted to `LiveCombatAuthority`.
func get_weapon_profiles() -> Dictionary:
	return {
		get_weapon_id(): {
			"range": weapon_range,
			"damage": weapon_damage,
			"origin_tolerance": weapon_origin_tolerance,
		},
	}.duplicate(true)


func get_sustained_damage_per_second() -> float:
	var cycle := maxf(0.001, telegraph_time + weapon_cooldown)
	return weapon_damage / cycle


## Ordered trade-off axes read by the opponent role-differentiation audit. Every
## value has an unambiguous "better for this opponent" reading, so no-strict-
## dominance is measured the same way the fleet audit measures the player craft.
func get_tactics_profile() -> Dictionary:
	return {
		"maximum_health": maximum_health,
		"cruise_speed": cruise_speed,
		"chase_speed": chase_speed,
		"acceleration": acceleration,
		"turn_speed_degrees": turn_speed_degrees,
		"engagement_range": engagement_range,
		"weapon_range": weapon_range,
		"weapon_damage": weapon_damage,
		"sustained_damage_per_second": get_sustained_damage_per_second(),
		"telegraph_time": telegraph_time,
		"weapon_cooldown": weapon_cooldown,
		"minimum_arming_range": 0.0,
		"preferred_engagement_distance": preferred_range,
	}.duplicate(true)


func get_resolver_backed_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _built:
		errors.append("opponent presentation has not been built")
	if source_id <= 0:
		errors.append("source_id must be a positive stable identity")
	if faction_id.is_empty():
		errors.append("faction_id is required")
	if not is_finite(weapon_range) or weapon_range <= 0.0:
		errors.append("weapon range must be finite and positive")
	if not is_finite(weapon_damage) or weapon_damage <= 0.0:
		errors.append("weapon damage must be finite and positive")
	if not is_finite(weapon_origin_tolerance) or weapon_origin_tolerance <= 0.0:
		errors.append("weapon origin tolerance must be finite and positive")
	if not PulseWeaponPresentation.STYLE_IDS.has(get_pulse_style_id()):
		errors.append("pulse style must be one of the pooled presentation's frozen styles")
	if _registered and not is_instance_valid(_get_combat_authority()):
		errors.append("registration is claimed without a live combat authority")
	if _shot_receipts.size() > MAX_PENDING_SHOT_RECEIPTS:
		errors.append("pending shot receipts exceed the fixed bound")
	if _active and is_inside_tree() and not _registered:
		errors.append("an active opponent must own a live combat registration")
	if not _active and _registered:
		errors.append("a dormant opponent must not retain a live combat registration")
	return errors


# ------------------------------------------------------- fire authority ----

## The gate described in the header. Re-asked on the dispatch frame, never
## cached from the frame the charge began.
func _is_fire_authorized() -> bool:
	if not _active or not is_inside_tree():
		return false
	var director := _get_scenario_director()
	if is_instance_valid(director) and director.has_method(&"is_fire_authorized"):
		return bool(director.call(&"is_fire_authorized", self))
	return true


## Resolves one shot on the single live `CombatResolver` under this craft's
## registered identity, then consumes the shared pooled presentation seams. No
## ray query, health store, or damage application lives here.
func _fire_at_target(target_position: Vector3) -> void:
	if not _active or not is_inside_tree():
		return
	if not _is_fire_authorized():
		# The charge was committed while the encounter still authorized it and
		# the authorization has since been withdrawn. Dropping it here, in the
		# same frame it would otherwise be dispatched, is the whole point: this
		# is where a shot would otherwise land after its scenario had ended.
		_telegraph_remaining = 0.0
		_cooldown_remaining = maxf(_cooldown_remaining, weapon_cooldown)
		_shots_withheld += 1
		_last_shot_result = {"accepted": false, "status": &"fire_unauthorized"}
		return
	var authority := _get_combat_authority()
	var resolver: CombatResolver = (
		authority.get_resolver() as CombatResolver if is_instance_valid(authority) else null
	)
	if not is_instance_valid(resolver) or not _registered:
		_cooldown_remaining = weapon_cooldown
		return
	var muzzle := _get_firing_muzzle()
	var origin: Vector3 = muzzle.global_position
	var direction := target_position - origin
	if direction.length_squared() <= 0.000001:
		direction = -global_basis.z
	direction = direction.normalized()

	# One receipt from the shared session-monotonic allocator. Saturation fails
	# closed here exactly as it does inside the authority's own submit path.
	var receipt_id := authority.allocate_presentation_receipt_id()
	if receipt_id < 0:
		_cooldown_remaining = weapon_cooldown
		_last_shot_result = {"accepted": false, "status": &"receipt_exhausted"}
		return
	var sequence := resolver.get_last_sequence(self, source_id) + 1
	var request := ShotRequest.new(
		self,
		source_id,
		faction_id,
		get_weapon_id(),
		sequence,
		origin,
		direction,
		weapon_range,
		weapon_damage,
		receipt_id
	)
	var result := resolver.resolve_hitscan(request)
	_cooldown_remaining = weapon_cooldown
	_last_shot_result = result.duplicate(true)
	_shots_fired += 1
	# `projectile_fired` is deliberately NOT raised. On the defender that signal
	# is a request for the coordinator to submit a shot; this craft has already
	# resolved its own, so re-raising it could produce a second submission.
	shot_resolved.emit(origin, direction, result.duplicate(true))
	if not bool(result.get("accepted", false)) or not bool(result.get("resolved", false)):
		return
	_spawn_muzzle_flash(origin)
	_present_resolved_shot(origin, direction, receipt_id, result)


## Which port this shot leaves from. Overridden by archetypes that mount their
## gun somewhere other than the nose.
func _get_firing_muzzle() -> Node3D:
	return _muzzle_port if is_instance_valid(_muzzle_port) else self as Node3D


func _present_resolved_shot(
		origin: Vector3,
		direction: Vector3,
		receipt_id: int,
		result: Dictionary
	) -> void:
	var endpoint := origin + direction * weapon_range
	if bool(result.get("hit", false)):
		var resolved_position: Variant = result.get("position", endpoint)
		if resolved_position is Vector3 and (resolved_position as Vector3).is_finite():
			endpoint = resolved_position as Vector3
	var audio := _get_combat_audio()
	if is_instance_valid(audio):
		audio.play_defender_fire(origin, get_instance_id())
	var damaged := bool(result.get("damaged", false))
	if damaged:
		_record_shot_receipt(receipt_id, result, endpoint)
		_flash_target_damage(origin, result)
	# A receipt only travels with a shot that actually queued target
	# presentation. A miss or a blocked shot carries none, so no listener can be
	# handed an ID with nothing behind it.
	var presented := false
	var pulse := _get_pulse_presentation()
	if is_instance_valid(pulse):
		presented = pulse.present_shot(
			origin,
			endpoint,
			get_pulse_style_id(),
			self,
			bool(result.get("hit", false)),
			receipt_id if damaged else -1
		)
	if damaged and not presented:
		# The pool refused or is unavailable. Authority is already final, so the
		# queued target presentation is released immediately rather than stranded.
		_finalize_shot_receipt(receipt_id, endpoint, true)


func _record_shot_receipt(receipt_id: int, result: Dictionary, endpoint: Vector3) -> void:
	var target_entity: Variant = result.get("target_entity")
	var terminal := bool(result.get("destroyed", false))
	var terminal_position := endpoint
	var target_instance_id := 0
	if is_instance_valid(target_entity):
		target_instance_id = (target_entity as Object).get_instance_id()
		if terminal and target_entity is Node3D:
			terminal_position = (target_entity as Node3D).global_position
	_shot_receipts[receipt_id] = {
		"target": weakref(target_entity) if is_instance_valid(target_entity) else null,
		"target_instance_id": target_instance_id,
		"endpoint": endpoint,
		"terminal_position": terminal_position,
		"terminal": terminal,
	}
	_shot_receipt_order.append(receipt_id)
	while _shot_receipt_order.size() > MAX_PENDING_SHOT_RECEIPTS:
		var evicted: int = _shot_receipt_order.pop_front()
		_shot_receipts.erase(evicted)


## Directional hit feedback. The coordinator owns this cue for the defender it
## knows about; a resolver-backed craft raises the same presentation-only cue
## for its own shots without touching hull, score, or phase state.
func _flash_target_damage(origin: Vector3, result: Dictionary) -> void:
	var hud := get_node_or_null(hud_path)
	var target_entity: Variant = result.get("target_entity")
	if (
		not is_instance_valid(hud)
		or not hud.has_method(&"flash_damage")
		or not is_instance_valid(target_entity)
		or target_entity is not Node3D
	):
		return
	var target_node := target_entity as Node3D
	var local_source := target_node.global_basis.inverse() * (origin - target_node.global_position)
	hud.call(
		&"flash_damage",
		float(result.get("applied_damage", weapon_damage)) / 20.0,
		Vector2(local_source.x, local_source.z)
	)


# ------------------------------------------------------ receipt lifecycle ----

func _on_shot_receipt_ready(receipt_id: int, position: Vector3) -> void:
	if not _shot_receipts.has(receipt_id):
		return
	_finalize_shot_receipt(receipt_id, position, false)


func _on_shot_receipt_aborted(receipt_id: int) -> void:
	if not _shot_receipts.has(receipt_id):
		return
	# The visual was recycled or torn down before arrival. Damage authority is
	# already committed, so release the queued target presentation now instead of
	# leaving a damaged hull visually pending forever.
	_finalize_shot_receipt(receipt_id, Vector3.INF, true)


func _finalize_shot_receipt(
		receipt_id: int,
		arrival_position: Vector3,
		play_impact_cue: bool
	) -> void:
	var record := _shot_receipts.get(receipt_id, {}) as Dictionary
	_shot_receipts.erase(receipt_id)
	_shot_receipt_order.erase(receipt_id)
	if record.is_empty():
		return
	var endpoint := record.get("endpoint", Vector3.INF) as Vector3
	if arrival_position.is_finite():
		endpoint = arrival_position
	var audio := _get_combat_audio()
	if play_impact_cue and is_instance_valid(audio) and endpoint.is_finite() and is_inside_tree():
		audio.play_impact(endpoint, 0.9, get_instance_id())
	var target_reference := record.get("target") as WeakRef
	var target := target_reference.get_ref() as Node if target_reference != null else null
	# The target's own commit is one-shot and idempotent, so it does not matter
	# whether the coordinator's pooled-impact listener reached it first; the
	# queued presentation is released exactly once either way. The lethal cue is
	# still ours to raise, because the coordinator holds no record of a shot it
	# did not submit and would otherwise leave a destroyed hull silent.
	if is_instance_valid(target) and target.has_method(&"commit_deferred_damage_presentation"):
		target.call(&"commit_deferred_damage_presentation", receipt_id)
	if bool(record.get("terminal", false)) and is_instance_valid(audio) and is_inside_tree():
		var effect_position := record.get("terminal_position", endpoint) as Vector3
		if not effect_position.is_finite():
			effect_position = endpoint
		if effect_position.is_finite():
			audio.play_explosion(
				effect_position,
				maxi(int(record.get("target_instance_id", 0)), 0)
			)


func _discard_shot_receipts() -> void:
	_shot_receipts.clear()
	_shot_receipt_order.clear()


# ------------------------------------------------------------- authority ----

func _register_combat_source() -> void:
	var authority := _get_combat_authority()
	if not is_instance_valid(authority):
		return
	if _registered and authority.get_source_id(self) == source_id:
		return
	_registered = authority.register_source(self, source_id, faction_id, get_weapon_profiles())


func _release_combat_registration() -> void:
	if not _registered:
		return
	_registered = false
	var authority := _get_combat_authority()
	if is_instance_valid(authority):
		# Retire only the live registration: the stable identity keeps its replay
		# high-water mark so a captured pre-withdrawal request stays stale.
		authority.retire_source_registration(self, source_id)


func _attach_damage_proxy() -> void:
	var authority := _get_combat_authority()
	if not is_instance_valid(authority):
		return
	authority.attach_lifecycle_damageable(
		self,
		LifecycleDamageableAdapter.LifecycleKind.RANGE_OPPONENT,
		faction_id
	)


func _get_combat_authority() -> LiveCombatAuthority:
	return get_node_or_null(combat_authority_path) as LiveCombatAuthority


func _get_pulse_presentation() -> PulseWeaponPresentation:
	return get_node_or_null(pulse_presentation_path) as PulseWeaponPresentation


func _get_combat_audio() -> CombatAudioPresentation:
	return get_node_or_null(combat_audio_path) as CombatAudioPresentation


func _get_scenario_director() -> Node:
	return get_node_or_null(scenario_director_path)


func _get_encounter_host() -> Node:
	return get_node_or_null(encounter_host_path)


func _connect_pulse_signals() -> void:
	if _pulse_signals_connected:
		return
	var pulse := _get_pulse_presentation()
	if not is_instance_valid(pulse):
		return
	if not pulse.impact_receipt_ready.is_connected(_on_shot_receipt_ready):
		pulse.impact_receipt_ready.connect(_on_shot_receipt_ready)
	if not pulse.impact_receipt_aborted.is_connected(_on_shot_receipt_aborted):
		pulse.impact_receipt_aborted.connect(_on_shot_receipt_aborted)
	_pulse_signals_connected = true


func _disconnect_pulse_signals() -> void:
	_pulse_signals_connected = false
	var pulse := _get_pulse_presentation()
	if not is_instance_valid(pulse):
		return
	if pulse.impact_receipt_ready.is_connected(_on_shot_receipt_ready):
		pulse.impact_receipt_ready.disconnect(_on_shot_receipt_ready)
	if pulse.impact_receipt_aborted.is_connected(_on_shot_receipt_aborted):
		pulse.impact_receipt_aborted.disconnect(_on_shot_receipt_aborted)
