extends SceneTree

## Focused regression for the standoff picket lance archetype.
##
## Behaviour groups, each with at least one structured-red mutation that the
## suite proves turns the production audit or behaviour red:
##
##   A. contract and evidence audit
##   B. lateral role differentiation against the existing range defender
##   C. combat-authority identity lifecycle (register / retire / re-entry / replay)
##   D. standoff tactics: arming band, committed-charge abort, engagement state
##   E. lance firing through the one live resolver and the pooled presentation
##
## Every wait is a bounded frame budget on a fixed physics step. Nothing in this
## suite reads a wall clock, and no craft handling, weapon, or balance value of
## the player fleet is touched.

const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const DEFENDER_SCENE := preload("res://scenes/ships/range_opponent.tscn")
const PULSE_SCENE := preload("res://scenes/effects/pulse_weapon_presentation.tscn")
const AUDIO_SCENE := preload("res://scenes/audio/combat_audio_presentation.tscn")
const AuthorityScript := preload("res://scripts/combat/live_combat_authority.gd")
const AdapterScript := preload("res://scripts/combat/lifecycle_damageable_adapter.gd")
const ShotRequestScript := preload("res://scripts/combat/shot_request.gd")

const TARGET_FACTION: StringName = &"picket_test_flight"
const FIRE_FRAME_BUDGET := 420
const SETTLE_FRAME_BUDGET := 120

# Trade-off axes with an unambiguous "better for this opponent" reading.
const HIGHER_IS_BETTER := [
	"maximum_health", "cruise_speed", "chase_speed", "acceleration",
	"turn_speed_degrees", "engagement_range", "weapon_range", "weapon_damage",
	"sustained_damage_per_second",
]
const LOWER_IS_BETTER := ["telegraph_time", "weapon_cooldown", "minimum_arming_range"]

var _failures: Array[String] = []
var _assertion_count := 0
var _lance_events: Array[Dictionary] = []
var _state_events: Array[StringName] = []
var _audio_cues: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	await _test_contract_and_evidence()
	await _test_pooled_audio_cue()
	await _test_role_differentiation()
	await _test_authority_identity_lifecycle()
	await _test_standoff_tactics()
	await _test_lance_firing_and_receipts()
	_check(
		root.get_child_count() == original_root_child_count,
		"every picket fixture cleans up without leaving scene nodes behind"
	)
	_finish()


# ------------------------------------------------- A. contract / evidence ----

func _test_contract_and_evidence() -> void:
	var fixture := await _make_fixture()
	var picket: StandoffPicketOpponent = fixture.picket

	var audit: Dictionary = picket.get_audit_report()
	_check(bool(audit.valid), "a freshly built picket audits clean: %s" % [audit.errors])
	_check(
		StringName(audit.component_id) == StandoffPicketOpponent.COMPONENT_ID
		and int(audit.schema_version) == StandoffPicketOpponent.SCHEMA_VERSION,
		"the audit carries a stable component ID and schema version"
	)
	var evidence: Dictionary = audit.evidence
	_check(
		StringName(evidence.evidence_status) == &"modern_interpretation"
		and not bool(evidence.historically_supported)
		and not bool(evidence.authenticated_original_weapon)
		and not bool(evidence.authenticated_original_tactic)
		and not bool(evidence.claims_historical_class_name),
		"the archetype is tagged modern_interpretation and authenticates nothing"
	)
	_check(
		StringName(picket.get_meta("evidence_status", &"")) == &"modern_interpretation"
		and not bool(picket.get_meta("historically_supported", true)),
		"the runtime node carries the same modern-interpretation metadata"
	)
	_check(
		not picket.get_display_name().to_lower().contains("arrow")
		and not picket.get_display_name().to_lower().contains("jovian")
		and not picket.get_display_name().to_lower().contains("zenith")
		and not picket.get_display_name().to_lower().contains("torrent"),
		"the display name borrows no fleet or historical class name"
	)

	# Reports are deep copies; a caller cannot mutate component state.
	audit.tactics["weapon_damage"] = 999.0
	_check(
		is_equal_approx(float(picket.get_tactics_profile()["weapon_damage"]), picket.lance_damage),
		"audit reports are deep copies rather than live component state"
	)

	_check(
		not picket.is_active()
		and picket.collision_layer == 0
		and picket.collision_mask == 0
		and not picket.visible
		and picket.get_engagement_state() == StandoffPicketOpponent.STATE_DORMANT
		and not picket.is_combat_source_registered(),
		"the picket ships dormant, hidden, non-colliding and unregistered"
	)
	_check(
		picket.get_node_or_null("StandoffPicketVisual") != null
		and picket.get_node_or_null("LanceMuzzle") != null,
		"the picket presentation and lance muzzle are built while dormant"
	)

	# --- boundary: invalid input is refused rather than clamped silently ---
	var profiles: Dictionary = picket.get_weapon_profiles()
	_check(
		profiles.size() == 1
		and profiles.has(StandoffPicketOpponent.LANCE_WEAPON_ID)
		and is_equal_approx(float(profiles[StandoffPicketOpponent.LANCE_WEAPON_ID]["range"]), picket.lance_range),
		"the picket declares exactly one immutable lance weapon profile"
	)

	# --- structured red A1: a non-positive lance damage must fail the audit ---
	var healthy_damage := picket.lance_damage
	picket.lance_damage = 0.0
	_check(
		not bool(picket.get_audit_report().valid)
		and picket.get_validation_errors().has("lance damage must be finite and positive"),
		"RED A1: zero lance damage turns the picket audit red"
	)
	picket.lance_damage = healthy_damage

	# --- structured red A2: an arming radius outside the standoff band is invalid ---
	var healthy_minimum := picket.minimum_arming_range
	picket.minimum_arming_range = picket.standoff_range + 1.0
	_check(
		not bool(picket.get_audit_report().valid)
		and picket.get_validation_errors().has(
			"minimum arming range must sit inside the standoff band"
		),
		"RED A2: an arming radius outside the standoff band turns the audit red"
	)
	picket.minimum_arming_range = healthy_minimum

	# --- structured red A3: an unusable source identity is invalid ---
	var healthy_source_id := picket.source_id
	picket.source_id = 0
	_check(
		not bool(picket.get_audit_report().valid)
		and picket.get_validation_errors().has("source_id must be a positive stable identity"),
		"RED A3: a non-positive source identity turns the audit red"
	)
	picket.source_id = healthy_source_id
	_check(bool(picket.get_audit_report().valid), "the audit recovers once every mutation is reverted")

	await _free_fixture(fixture)


# ------------------------------------------------- A2. pooled audio cue -----

## The picket must sound like an opponent, not like the player, and an aborted
## visual must still raise its impact cue. Both cues come from the shared
## ten-voice bank; the picket owns no audio node of its own.
func _test_pooled_audio_cue() -> void:
	var fixture := await _make_fixture(true)
	var picket: StandoffPicketOpponent = fixture.picket
	var target: RangeOpponent = fixture.target
	var pulse: PulseWeaponPresentation = fixture.pulse
	var audio: CombatAudioPresentation = fixture.audio
	_check(audio != null, "the shared combat audio bank is staged for the cue section")
	if audio == null:
		await _free_fixture(fixture)
		return
	pulse.set_auto_advance_enabled(false)
	picket.acceleration = 0.0
	_place(picket, Vector3.ZERO, Vector3(0.0, 0.0, -100.0))
	_place_target(target, Vector3(0.0, 0.0, -100.0))
	picket.activate(picket.global_transform)
	picket.set_target(target)
	await _advance_physics(2)

	_audio_cues.clear()
	picket._cooldown_remaining = 0.0
	picket._fire_at_target(target.global_position)
	_check(
		_audio_cues.has(CombatAudioPresentation.CUE_DEFENDER_FIRE)
		and not _audio_cues.has(CombatAudioPresentation.CUE_PLAYER_FIRE),
		"the lance raises the opponent fire cue and never the player's"
	)
	_audio_cues.clear()
	pulse.clear_effects()
	_check(
		_audio_cues.has(CombatAudioPresentation.CUE_IMPACT_MEDIUM)
		or _audio_cues.has(CombatAudioPresentation.CUE_IMPACT_HEAVY),
		"an aborted lance visual still raises its positional impact cue"
	)
	picket.deactivate()
	pulse.set_auto_advance_enabled(true)
	await _free_fixture(fixture)


# --------------------------------------------- B. role differentiation ------

func _test_role_differentiation() -> void:
	var fixture := await _make_fixture()
	var picket: StandoffPicketOpponent = fixture.picket
	var defender: RangeOpponent = fixture.defender

	var picket_profile: Dictionary = picket.get_tactics_profile()
	var defender_profile := _defender_tactics_profile(defender)

	var differing := 0
	for key: String in HIGHER_IS_BETTER + LOWER_IS_BETTER:
		if not is_equal_approx(float(picket_profile[key]), float(defender_profile[key])):
			differing += 1
	_check(
		differing == HIGHER_IS_BETTER.size() + LOWER_IS_BETTER.size(),
		"the two opponents differ on all %d trade-off axes (%d)"
			% [HIGHER_IS_BETTER.size() + LOWER_IS_BETTER.size(), differing]
	)

	var picket_advantages := _count_advantages(defender_profile, picket_profile)
	var defender_advantages := _count_advantages(picket_profile, defender_profile)
	_check(
		picket_advantages > 0,
		"the picket is not a strict downgrade of the defender (%d lateral advantages)"
			% picket_advantages
	)
	_check(
		defender_advantages > 0,
		"the picket is not a strict statistical upgrade over the defender (%d lateral advantages)"
			% defender_advantages
	)
	print(
		"PICKET_ROLE_EVIDENCE: picket_advantages=%d defender_advantages=%d axes=%d"
			% [picket_advantages, defender_advantages, differing]
	)

	# Frozen role signature: the picket buys reach and burst with fragility,
	# cadence, agility and a radius inside which it cannot shoot at all.
	_check(
		float(picket_profile.weapon_range) > float(defender_profile.weapon_range)
		and float(picket_profile.weapon_damage) > float(defender_profile.weapon_damage)
		and float(picket_profile.engagement_range) > float(defender_profile.engagement_range),
		"the picket alone owns the longer reach and the heavier single shot"
	)
	_check(
		float(picket_profile.maximum_health) < float(defender_profile.maximum_health)
		and float(picket_profile.turn_speed_degrees) < float(defender_profile.turn_speed_degrees)
		and float(picket_profile.chase_speed) < float(defender_profile.chase_speed)
		and float(picket_profile.sustained_damage_per_second)
			< float(defender_profile.sustained_damage_per_second),
		"the picket pays for that reach in hull, agility, pursuit and sustained damage"
	)
	_check(
		float(picket_profile.telegraph_time) > float(defender_profile.telegraph_time) * 2.0,
		"the picket telegraphs its shot for more than twice as long as the defender"
	)
	_check(
		float(defender_profile.minimum_arming_range) <= 0.0
		and float(picket_profile.minimum_arming_range) > 0.0,
		"only the picket has a radius inside which its weapon cannot arm"
	)
	_check(
		float(picket_profile.preferred_engagement_distance)
			> float(defender_profile.preferred_engagement_distance) * 2.0,
		"the picket holds a standoff band far outside the defender's orbit"
	)

	# --- structured red B1: making the picket beat the defender on every axis
	# must break the no-strict-dominance property this suite exists to freeze ---
	var healthy_health := picket.maximum_health
	var healthy_turn := picket.turn_speed_degrees
	var healthy_chase := picket.chase_speed
	var healthy_cruise := picket.cruise_speed
	var healthy_acceleration := picket.acceleration
	var healthy_telegraph := picket.telegraph_time
	var healthy_cooldown := picket.weapon_cooldown
	var healthy_minimum := picket.minimum_arming_range
	picket.maximum_health = defender.maximum_health + 10.0
	picket.turn_speed_degrees = defender.turn_speed_degrees + 10.0
	picket.chase_speed = defender.chase_speed + 10.0
	picket.cruise_speed = defender.cruise_speed + 10.0
	picket.acceleration = defender.acceleration + 10.0
	picket.telegraph_time = defender.telegraph_time * 0.5
	picket.weapon_cooldown = defender.weapon_cooldown * 0.5
	picket.minimum_arming_range = 0.0
	_check(
		_count_advantages(picket.get_tactics_profile(), defender_profile) == 0,
		"RED B1: an all-axis buff makes the picket a strict upgrade and turns the dominance check red"
	)
	picket.maximum_health = healthy_health
	picket.turn_speed_degrees = healthy_turn
	picket.chase_speed = healthy_chase
	picket.cruise_speed = healthy_cruise
	picket.acceleration = healthy_acceleration
	picket.telegraph_time = healthy_telegraph
	picket.weapon_cooldown = healthy_cooldown
	picket.minimum_arming_range = healthy_minimum
	_check(
		_count_advantages(picket.get_tactics_profile(), defender_profile) > 0,
		"the defender keeps its lateral advantages once the buff is reverted"
	)

	await _free_fixture(fixture)


func _defender_tactics_profile(defender: RangeOpponent) -> Dictionary:
	# GameFlow owns the defender's authoritative weapon envelope; the axes below
	# are read from the production coordinator constant rather than re-invented.
	var profile: Dictionary = GameFlow.OPPONENT_WEAPON_PROFILES[GameFlow.OPPONENT_WEAPON_ID]
	var cycle := maxf(0.001, defender.telegraph_time + defender.weapon_cooldown)
	return {
		"maximum_health": defender.maximum_health,
		"cruise_speed": defender.cruise_speed,
		"chase_speed": defender.chase_speed,
		"acceleration": defender.acceleration,
		"turn_speed_degrees": defender.turn_speed_degrees,
		"engagement_range": defender.engagement_range,
		"weapon_range": float(profile["range"]),
		"weapon_damage": float(profile["damage"]),
		"sustained_damage_per_second": float(profile["damage"]) / cycle,
		"telegraph_time": defender.telegraph_time,
		"weapon_cooldown": defender.weapon_cooldown,
		# The defender has no arming radius at all: it can shoot from contact range.
		"minimum_arming_range": 0.0,
		"preferred_engagement_distance": defender.preferred_range,
	}


func _count_advantages(baseline: Dictionary, candidate: Dictionary) -> int:
	var advantages := 0
	for key: String in HIGHER_IS_BETTER:
		if float(candidate[key]) > float(baseline[key]):
			advantages += 1
	for key: String in LOWER_IS_BETTER:
		if float(candidate[key]) < float(baseline[key]):
			advantages += 1
	return advantages


# ------------------------------------------ C. authority identity lifecycle --

func _test_authority_identity_lifecycle() -> void:
	var fixture := await _make_fixture()
	var picket: StandoffPicketOpponent = fixture.picket
	var authority: LiveCombatAuthority = fixture.authority
	var resolver: CombatResolver = authority.get_resolver()

	_check(
		resolver.get_registered_source_count() == 0,
		"a dormant picket registers no combat source, so a coordinator source census is unchanged"
	)
	_check(
		picket.get_node_or_null("AuthoritativeDamageable") is LifecycleDamageableAdapter,
		"the picket reuses the shared lifecycle damageable proxy instead of its own health store"
	)

	picket.activate(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)))
	_check(
		picket.is_combat_source_registered()
		and resolver.get_registered_source_count() == 1
		and authority.get_source_id(picket) == picket.source_id
		and authority.get_source_faction(picket) == picket.faction_id,
		"activation registers exactly one authority-owned identity"
	)
	var registered_profile := authority.get_weapon_profile(
		picket, StandoffPicketOpponent.LANCE_WEAPON_ID
	)
	_check(
		is_equal_approx(float(registered_profile.get("range", 0.0)), picket.lance_range)
		and is_equal_approx(float(registered_profile.get("damage", 0.0)), picket.lance_damage),
		"the registered weapon envelope matches the declared lance profile"
	)

	# --- duplicate activation must not create a second registration ---
	picket.activate(Transform3D(Basis.IDENTITY, Vector3(4.0, 0.0, 0.0)))
	_check(
		resolver.get_registered_source_count() == 1,
		"re-activating the same picket does not duplicate its resolver registration"
	)

	# Consume one sequence so the replay ledger has a real high-water mark.
	var accepted := resolver.resolve_hitscan(_make_request(picket, 0))
	_check(
		bool(accepted.get("accepted", false)) and resolver.get_last_sequence(picket, picket.source_id) == 0,
		"the picket identity resolves a first shot and advances the shared replay ledger"
	)

	picket.deactivate()
	_check(
		not picket.is_combat_source_registered()
		and resolver.get_registered_source_count() == 0,
		"withdrawing the picket retires its live registration"
	)
	_check(
		resolver.get_last_sequence(picket, picket.source_id) == 0,
		"withdrawal retires the registration without discarding the replay high-water mark"
	)

	picket.activate(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)))
	var replay := resolver.resolve_hitscan(_make_request(picket, 0))
	_check(
		not bool(replay.get("accepted", false))
		and StringName(replay.get("status", &"")) == &"duplicate_sequence",
		"a request captured before withdrawal is still stale after the picket redeploys"
	)
	var fresh := resolver.resolve_hitscan(_make_request(picket, 1))
	_check(bool(fresh.get("accepted", false)), "the redeployed picket still resolves newer sequences")

	# --- detach / re-entry ---
	var parent := picket.get_parent()
	var captured_while_attached := _make_request(picket, 1)
	parent.remove_child(picket)
	_check(
		not picket.is_combat_source_registered() and resolver.get_registered_source_count() == 0,
		"a detached picket claims no live registration"
	)
	var stale_while_detached := resolver.resolve_hitscan(captured_while_attached)
	_check(
		not bool(stale_while_detached.get("accepted", false)),
		"a detached picket cannot resolve a captured request"
	)
	parent.add_child(picket)
	await process_frame
	await process_frame
	_check(
		picket.is_combat_source_registered()
		and resolver.get_registered_source_count() == 1
		and authority.get_source_id(picket) == picket.source_id,
		"whole-subtree re-entry restores exactly one registration for the same identity"
	)
	var post_reentry_replay := resolver.resolve_hitscan(_make_request(picket, 1))
	_check(
		not bool(post_reentry_replay.get("accepted", false))
		and StringName(post_reentry_replay.get("status", &"")) == &"duplicate_sequence",
		"re-entry cannot make a captured pre-detach request current again"
	)

	# --- structured red C1: a foreign source may not steal the picket identity ---
	var impostor := Node3D.new()
	impostor.name = "ImpostorPicket"
	parent.add_child(impostor)
	_check(
		not authority.register_source(
			impostor, picket.source_id, picket.faction_id, picket.get_weapon_profiles()
		),
		"RED C1: a different node cannot take over the live picket source identity"
	)
	impostor.queue_free()

	# --- structured red C2: an unregistered picket cannot resolve a shot ---
	picket.deactivate()
	var unregistered := resolver.resolve_hitscan(_make_request(picket, 99))
	_check(
		not bool(unregistered.get("accepted", false))
		and StringName(unregistered.get("status", &"")) == &"unregistered_source",
		"RED C2: a withdrawn picket cannot resolve a shot at all"
	)

	await _free_fixture(fixture)


func _make_request(picket: StandoffPicketOpponent, sequence: int) -> ShotRequest:
	return ShotRequestScript.new(
		picket,
		picket.source_id,
		picket.faction_id,
		StandoffPicketOpponent.LANCE_WEAPON_ID,
		sequence,
		picket.global_position,
		Vector3.FORWARD,
		picket.lance_range,
		picket.lance_damage
	) as ShotRequest


# ------------------------------------------------- D. standoff tactics ------

func _test_standoff_tactics() -> void:
	var fixture := await _make_fixture()
	var picket: StandoffPicketOpponent = fixture.picket
	var target: RangeOpponent = fixture.target

	# Evidence control: the craft is pinned in place so the tactic under test is
	# the weapon arming rule, not a navigation race. Attitude, telegraph, cooldown
	# and firing all continue to run through the production code paths.
	picket.acceleration = 0.0

	# Normal case: held at the standoff band, the picket commits and fires.
	_place(picket, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -120.0))
	_place_target(target, Vector3(0.0, 0.0, -120.0))
	picket.activate(picket.global_transform)
	picket.set_target(target)
	var fired := await _advance_until(
		func() -> bool: return _lance_events.size() > 0,
		FIRE_FRAME_BUDGET
	)
	_check(fired, "a picket holding its standoff band charges and fires its lance")
	_check(
		picket.get_engagement_state() == StandoffPicketOpponent.STATE_HOLDING,
		"the picket reports the holding engagement state inside its standoff band"
	)
	picket.deactivate()
	_lance_events.clear()

	# --- boundary: exactly inside the arming radius the lance cannot arm ---
	var inside := picket.minimum_arming_range - 2.0
	_place(picket, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -inside))
	_place_target(target, Vector3(0.0, 0.0, -inside))
	picket.activate(picket.global_transform)
	picket.set_target(target)
	var stayed_silent := not await _advance_until(
		func() -> bool: return _lance_events.size() > 0,
		FIRE_FRAME_BUDGET
	)
	_check(stayed_silent, "a target inside the arming radius cannot be shot at all")
	_check(
		picket.get_engagement_state() == StandoffPicketOpponent.STATE_BREAKING,
		"the picket reports the breaking engagement state inside its arming radius"
	)
	var disarmed_lifecycle := picket.get_audit_report().lifecycle as Dictionary
	_check(
		int(disarmed_lifecycle.shots_fired) == 0,
		"no shot is recorded at all while the lance is disarmed"
	)
	# The arming gate and the charge-hold gate are separate rules. A picket that
	# begins a charge it must abort every frame has lost the arming gate even
	# though it never manages to fire.
	_check(
		int(disarmed_lifecycle.shots_aborted) == 0
		and is_zero_approx(float(picket.get("_telegraph_remaining"))),
		"the lance never even begins a charge against a target inside the arming radius"
	)
	picket.deactivate()
	_lance_events.clear()

	# --- committed charge is abortable: closing mid-telegraph costs the picket ---
	_place(picket, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -110.0))
	_place_target(target, Vector3(0.0, 0.0, -110.0))
	picket.activate(picket.global_transform)
	picket.set_target(target)
	var charging := await _advance_until(
		func() -> bool: return float(picket.get("_telegraph_remaining")) > 0.0,
		FIRE_FRAME_BUDGET
	)
	_check(charging, "the picket visibly commits to a long lance charge before firing")
	_place_target(target, Vector3(0.0, 0.0, -(picket.minimum_arming_range - 6.0)))
	await _advance_physics(2)
	var audit: Dictionary = picket.get_audit_report()
	_check(
		int((audit.lifecycle as Dictionary).shots_aborted) >= 1
		and is_zero_approx(float(picket.get("_telegraph_remaining")))
		and _lance_events.is_empty(),
		"closing inside the arming radius aborts the committed charge before it fires"
	)
	_check(
		float(picket.get("_cooldown_remaining")) >= picket.lance_abort_recovery - 0.05,
		"an aborted charge costs the picket its full recovery window"
	)

	# --- structured red D1: removing the arming radius lets the picket shoot
	# a target it must not be able to shoot ---
	picket.deactivate()
	_lance_events.clear()
	picket.minimum_arming_range = 1.0
	picket.retreat_range = 1.0
	var close := 30.0
	_place(picket, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -close))
	_place_target(target, Vector3(0.0, 0.0, -close))
	picket.activate(picket.global_transform)
	picket.set_target(target)
	var fired_point_blank := await _advance_until(
		func() -> bool: return _lance_events.size() > 0,
		FIRE_FRAME_BUDGET
	)
	_check(
		fired_point_blank,
		"RED D1: collapsing the arming radius lets the picket fire point blank, which the boundary case above forbids"
	)
	picket.deactivate()
	_lance_events.clear()

	await _free_fixture(fixture)


# ------------------------------- E. lance firing, resolver and receipts ------

func _test_lance_firing_and_receipts() -> void:
	var fixture := await _make_fixture()
	var picket: StandoffPicketOpponent = fixture.picket
	var target: RangeOpponent = fixture.target
	var pulse: PulseWeaponPresentation = fixture.pulse
	var resolver: CombatResolver = (fixture.authority as LiveCombatAuthority).get_resolver()

	pulse.set_auto_advance_enabled(false)
	picket.acceleration = 0.0
	_place(picket, Vector3.ZERO, Vector3(0.0, 0.0, -100.0))
	_place_target(target, Vector3(0.0, 0.0, -100.0))
	picket.activate(picket.global_transform)
	picket.set_target(target)
	await _advance_physics(2)

	var health_before := target.get_health()
	var pulse_before: int = int(pulse.get_statistics().presented)
	picket._fire_at_target(target.global_position)
	var result := picket.get_last_shot_result()
	_check(
		bool(result.get("accepted", false)) and bool(result.get("resolved", false)),
		"the lance resolves through the one live CombatResolver"
	)
	_check(
		bool(result.get("damaged", false))
		and is_equal_approx(float(result.get("applied_damage", 0.0)), picket.lance_damage)
		and is_equal_approx(target.get_health(), health_before - picket.lance_damage),
		"one accepted lance shot applies exactly one authoritative damage commit"
	)
	_check(
		int(pulse.get_statistics().presented) == pulse_before + 1,
		"the lance consumes the shared fixed pulse pool rather than allocating its own visual"
	)
	var snapshots := pulse.get_active_shot_snapshots()
	# The literal styles are asserted on purpose: the point of the property is
	# that the picket does NOT read as the player's cyan or as the defender's
	# amber, so a renamed constant must not be able to satisfy it.
	_check(
		snapshots.size() == 1
		and StringName((snapshots[0] as Dictionary).style_id) == &"magenta"
		and int((snapshots[0] as Dictionary).source_instance_id) == picket.get_instance_id(),
		"the lance is presented in magenta, distinct from the player's cyan and the defender's amber"
	)
	_check(
		StandoffPicketOpponent.LANCE_PULSE_STYLE != &"cyan"
		and StandoffPicketOpponent.LANCE_PULSE_STYLE != &"amber"
		and PulseWeaponPresentation.STYLE_IDS.has(StandoffPicketOpponent.LANCE_PULSE_STYLE),
		"the declared lance style is a supported pool style that no existing combatant already uses"
	)
	_check(
		picket.get_pending_lance_receipt_count() == 1
		and target.get_pending_damage_presentation_count() == 1,
		"the damaged target holds exactly one deferred presentation receipt"
	)

	# Reverse-order safety: the target presentation commits only at pulse arrival.
	pulse.advance_simulation(0.5)
	_check(
		picket.get_pending_lance_receipt_count() == 0
		and target.get_pending_damage_presentation_count() == 0,
		"the deferred target presentation is committed exactly at pulse arrival"
	)

	# --- an aborted visual must still release the queued presentation ---
	picket._cooldown_remaining = 0.0
	picket._fire_at_target(target.global_position)
	_check(
		picket.get_pending_lance_receipt_count() == 1
		and target.get_pending_damage_presentation_count() == 1,
		"a second lance shot queues its own presentation receipt"
	)
	pulse.clear_effects()
	_check(
		picket.get_pending_lance_receipt_count() == 0
		and target.get_pending_damage_presentation_count() == 0,
		"a recycled or cleared visual releases the queued presentation instead of stranding it"
	)

	# --- friendly fire is refused by the shared resolver, not re-implemented ---
	var friendly := DEFENDER_SCENE.instantiate() as RangeOpponent
	friendly.name = "FriendlyDefender"
	picket.get_parent().add_child(friendly)
	(fixture.authority as LiveCombatAuthority).attach_lifecycle_damageable(
		friendly,
		AdapterScript.LifecycleKind.RANGE_OPPONENT,
		picket.faction_id
	)
	friendly.activate(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -40.0)))
	await _advance_physics(2)
	var friendly_health := friendly.get_health()
	picket._cooldown_remaining = 0.0
	picket._fire_at_target(friendly.global_position)
	_check(
		StringName(picket.get_last_shot_result().get("status", &"")) == &"friendly_fire_blocked"
		and is_equal_approx(friendly.get_health(), friendly_health),
		"the shared resolver blocks same-faction lance fire without a second faction rule here"
	)
	friendly.deactivate()
	friendly.queue_free()
	await process_frame

	# --- boundary: receipt saturation fails closed, exactly as the authority does ---
	var authority: LiveCombatAuthority = fixture.authority
	var saved_allocator: int = int(authority.get("_next_presentation_receipt_id"))
	authority.set("_next_presentation_receipt_id", LiveCombatAuthority.MAX_PRESENTATION_RECEIPT_ID)
	var saturated_health := target.get_health()
	picket._cooldown_remaining = 0.0
	picket._fire_at_target(target.global_position)
	_check(
		StringName(picket.get_last_shot_result().get("status", &"")) == &"receipt_exhausted"
		and is_equal_approx(target.get_health(), saturated_health),
		"a saturated receipt allocator fails closed and no damage is applied"
	)
	authority.set("_next_presentation_receipt_id", saved_allocator)

	# --- structured red E1: a lance that skipped the resolver would damage a
	# target without consuming a sequence. Prove the sequence is consumed. ---
	var sequence_before := resolver.get_last_sequence(picket, picket.source_id)
	picket._cooldown_remaining = 0.0
	picket._fire_at_target(target.global_position)
	_check(
		resolver.get_last_sequence(picket, picket.source_id) == sequence_before + 1,
		"RED E1: every lance shot consumes exactly one monotonic resolver sequence"
	)

	# --- structured red E2: an unregistered picket cannot damage anything ---
	pulse.clear_effects()
	picket._release_combat_registration()
	var protected_health := target.get_health()
	picket._cooldown_remaining = 0.0
	picket._fire_at_target(target.global_position)
	_check(
		is_equal_approx(target.get_health(), protected_health)
		and picket.get_pending_lance_receipt_count() == 0,
		"RED E2: a picket without a live registration cannot apply damage or queue presentation"
	)

	picket.deactivate()
	pulse.set_auto_advance_enabled(true)
	await _free_fixture(fixture)


# ---------------------------------------------------------------- fixture ----

func _make_fixture(include_audio: bool = false) -> Dictionary:
	_lance_events.clear()
	_state_events.clear()
	var host := Node3D.new()
	host.name = "PicketTestWorld"
	root.add_child(host)

	var authority := AuthorityScript.new() as LiveCombatAuthority
	authority.name = "CombatAuthority"
	host.add_child(authority)

	var pulse := PULSE_SCENE.instantiate() as PulseWeaponPresentation
	pulse.name = "PulseWeaponPresentation"
	host.add_child(pulse)
	# The positional voice bank is staged only for the cue section. Every other
	# section runs voice-free so the suite never depends on audio-server timing.
	var audio: CombatAudioPresentation = null
	if include_audio:
		audio = AUDIO_SCENE.instantiate() as CombatAudioPresentation
		audio.name = "CombatAudioPresentation"
		host.add_child(audio)
		audio.cue_started.connect(_on_cue_started)

	var defender := DEFENDER_SCENE.instantiate() as RangeOpponent
	defender.name = "RangeOpponent"
	host.add_child(defender)

	var target := DEFENDER_SCENE.instantiate() as RangeOpponent
	target.name = "LanceTarget"
	host.add_child(target)
	authority.attach_lifecycle_damageable(
		target, AdapterScript.LifecycleKind.RANGE_OPPONENT, TARGET_FACTION
	)

	var picket := PICKET_SCENE.instantiate() as StandoffPicketOpponent
	picket.name = "StandoffPicket"
	picket.escort_enabled = false
	picket.combat_authority_path = NodePath("../CombatAuthority")
	picket.pulse_presentation_path = NodePath("../PulseWeaponPresentation")
	picket.combat_audio_path = (
		NodePath("../CombatAudioPresentation") if include_audio else NodePath("../MissingAudioBank")
	)
	picket.defender_path = NodePath("../RangeOpponent")
	picket.encounter_host_path = NodePath("..")
	picket.hud_path = NodePath("../MissingHud")
	host.add_child(picket)
	picket.lance_fired.connect(_on_lance_fired)
	picket.engagement_state_changed.connect(_on_engagement_state_changed)

	await process_frame
	await physics_frame
	await process_frame
	return {
		"host": host,
		"authority": authority,
		"pulse": pulse,
		"audio": audio,
		"defender": defender,
		"target": target,
		"picket": picket,
	}


func _free_fixture(fixture: Dictionary) -> void:
	var audio := fixture.get("audio") as CombatAudioPresentation
	if is_instance_valid(audio) and audio.get_parent() != null:
		# Retire the shared positional voices first: the component's own exit
		# transaction stops and detaches every pooled voice, so no cue outlives
		# the fixture that raised it.
		audio.get_parent().remove_child(audio)
		audio.queue_free()
		await process_frame
	var host := fixture.get("host") as Node3D
	if is_instance_valid(host):
		root.remove_child(host)
		host.queue_free()
	# A bounded settle budget, not a wall-clock wait: pooled voices and queued
	# node deletions both complete inside a handful of frames.
	for _index in 8:
		await process_frame


func _place(picket: StandoffPicketOpponent, origin: Vector3, look_at_position: Vector3) -> void:
	var facing := look_at_position - origin
	if facing.length_squared() <= 0.001:
		facing = Vector3.FORWARD
	picket.global_transform = Transform3D(
		Basis.looking_at(facing.normalized(), Vector3.UP).orthonormalized(),
		origin
	)
	picket.velocity = Vector3.ZERO


func _place_target(target: RangeOpponent, origin: Vector3) -> void:
	if not target.is_active():
		target.activate(Transform3D(Basis.IDENTITY, origin))
	target.global_position = origin
	target.velocity = Vector3.ZERO


func _advance_physics(frames: int) -> void:
	for _index in frames:
		await physics_frame
		await process_frame


func _advance_until(condition: Callable, frame_budget: int) -> bool:
	for _index in frame_budget:
		if bool(condition.call()):
			return true
		await physics_frame
		await process_frame
	return bool(condition.call())


func _on_lance_fired(origin: Vector3, direction: Vector3, result: Dictionary) -> void:
	_lance_events.append({"origin": origin, "direction": direction, "result": result})


func _on_engagement_state_changed(state: StringName) -> void:
	_state_events.append(state)


func _on_cue_started(
		cue_id: StringName,
		_voice_name: StringName,
		_world_position: Vector3,
		_source_instance_id: int
	) -> void:
	_audio_cues.append(cue_id)


func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("STANDOFF_PICKET_OPPONENT_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print(
			"STANDOFF_PICKET_OPPONENT_TEST_FAILED: %d of %d assertions failed: %s"
				% [_failures.size(), _assertion_count, "; ".join(_failures)]
		)
		quit(1)
