extends SceneTree

## Focused Bulwark multicrew coverage. The server-owned seat authority admits
## the optional gunner, while HeroShip remains the pilot projectile request
## seam and the shared CombatResolver remains gunner damage authority.

const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Bulwark := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const LiveCombatAuthority := preload("res://scripts/combat/live_combat_authority.gd")
const WeaponDefinitionResolverProfile := preload(
	"res://scripts/combat/weapon_definition_resolver_profile.gd"
)
const PILOT_WEAPON_ID: StringName = &"bulwark_sustained_pulse_cannon"

class RewardFaultFilesystem:
	extends UserDataFilesystem
	var reject_rewards := true

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if reject_rewards and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-"):
			return ERR_CANT_CREATE
		return super.write_bytes_and_flush(path, bytes)


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := BULWARK_SCENE.instantiate() as HeroShip
	_check(craft != null, "production Bulwark instantiates for optional gunner gameplay")
	if craft == null:
		_finish()
		return
	root.add_child(craft)
	var combat_authority := LiveCombatAuthority.new()
	combat_authority.name = "BulwarkCombatAuthority"
	root.add_child(combat_authority)
	await process_frame
	await physics_frame
	await physics_frame
	var profiles := WeaponDefinitionResolverProfile.to_resolver_profiles(
		craft.get_gunner_weapon_definition(), Bulwark.BULWARK_CREW_FACTION_ID, 12.0
	)
	profiles[PILOT_WEAPON_ID] = {
		"range": 360.0,
		"damage": 50.0,
		"origin_tolerance": 24.0,
	}
	_check(
		combat_authority.register_source(
			craft,
			Bulwark.COMBAT_SOURCE_ID,
			Bulwark.BULWARK_CREW_FACTION_ID,
			profiles
		),
		"production-style source starts with both pilot and siege-lance profiles"
	)

	var authority = _build_authority()
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"Bulwark accepts the sealed server-owned pilot/gunner role roster"
	)
	_check(craft.get_pilot_seat_anchor() != null, "pilot seat remains immediately available")
	_check(
		bool(craft.attach_gunner_combat_authority(combat_authority).get("accepted", false)),
		"Bulwark gunner binds the shared resolver authority"
	)
	_check(
		combat_authority.get_weapon_profile(craft, PILOT_WEAPON_ID)
			== profiles.get(PILOT_WEAPON_ID, {}),
		"gunner attach preserves the existing pilot-only dictionary entry"
	)
	var pilot_only_craft := BULWARK_SCENE.instantiate() as HeroShip
	var pilot_only_authority := LiveCombatAuthority.new()
	root.add_child(pilot_only_craft)
	root.add_child(pilot_only_authority)
	await process_frame
	var pilot_only_profile := profiles.get(PILOT_WEAPON_ID, {}) as Dictionary
	_check(
		pilot_only_authority.register_source(
			pilot_only_craft,
			Bulwark.COMBAT_SOURCE_ID,
			Bulwark.BULWARK_CREW_FACTION_ID,
			{PILOT_WEAPON_ID: pilot_only_profile}
		),
		"pilot-only regression fixture owns source 1107"
	)
	var rejected_attach: Dictionary = pilot_only_craft.attach_gunner_combat_authority(
		pilot_only_authority
	)
	_check(
		not bool(rejected_attach.get("accepted", true))
		and rejected_attach.get("status", &"") == &"siege_lance_profile_missing",
		"gunner attach fails closed when an existing source lacks the siege profile"
	)
	_check(
		pilot_only_authority.get_weapon_profile(pilot_only_craft, PILOT_WEAPON_ID)
			== pilot_only_profile
		and pilot_only_authority.get_weapon_profile(
			pilot_only_craft, Bulwark.BULWARK_CREW_WEAPON_ID
		).is_empty(),
		"failed gunner attach never replaces a pilot-only weapon dictionary"
	)
	pilot_only_craft.queue_free()
	pilot_only_authority.queue_free()
	_check(
		craft.get_engineer_status_text().contains("[READY]"),
		"the physical Bulwark crew display boots with engineer repair ready"
	)

	var emitted := [0]
	var selected := [0]
	var cleared := [0]
	var selected_generation := [0]
	var clear_reason := [StringName(&"")]
	craft.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void:
		emitted[0] += 1
	)
	craft.gunner_target_selected.connect(
		func(_target_id: StringName, generation: int, _receipt: Dictionary) -> void:
			selected[0] += 1
			selected_generation[0] = generation
	)
	craft.gunner_target_cleared.connect(
		func(_target_id: StringName, _generation: int, reason: StringName) -> void:
			cleared[0] += 1
			clear_reason[0] = reason
	)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)

	var fired = craft.submit_crew_intent(
		1,
		88,
		&"bulwark_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_00",
			"trigger": true,
			"target_generation": 1,
		},
		2
	)
	var effect := fired.get("effect", {}) as Dictionary
	_check(
		bool(fired.get("accepted", false))
			and bool(fired.get("consumed", false))
			and fired.get("status", &"") == &"intent_consumed"
			and effect.get("status", &"") == &"charge_started"
			and is_equal_approx(float(effect.get("charge_progress", -1.0)), 0.0),
		"admitted gunner receipt starts the bounded siege-lance charge"
	)
	_check(emitted[0] == 0, "gunner dispatch does not take over the pilot projectile seam")
	_check(selected[0] == 1 and selected_generation[0] == 1, "fire selects the bounded target generation")
	_check(
		(craft.get_gunner_gameplay_state().get("role_charges", {}) as Dictionary).size() == 1,
		"charge progress remains detached and inspectable while physics advances"
	)
	for _frame in 30:
		await physics_frame

	var resolved = craft.submit_crew_intent(
		1,
		88,
		&"bulwark_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_00",
			"trigger": true,
			"target_generation": 1,
		},
		3
	)
	var resolved_effect := resolved.get("effect", {}) as Dictionary
	_check(
		bool(resolved.get("accepted", false))
			and bool(resolved.get("consumed", false))
			and resolved_effect.get("status", &"") == &"siege_lance_resolved"
			and bool((resolved_effect.get("resolution", {}) as Dictionary).get("accepted", false)),
		"the charged gunner receipt reaches the shared siege-lance resolver"
	)
	_check(
		resolved_effect.get("source_id", 0) == Bulwark.COMBAT_SOURCE_ID
			and resolved_effect.get("faction_id", &"") == Bulwark.BULWARK_CREW_FACTION_ID
			and resolved_effect.get("weapon_id", &"") == Bulwark.BULWARK_CREW_WEAPON_ID,
		"request carries Bulwark source, faction, and weapon identity"
	)

	var selection_only = craft.submit_crew_intent(
		1,
		88,
		&"bulwark_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_01",
			"trigger": false,
			"target_generation": 1,
		},
		4
	)
	_check(
		bool(selection_only.get("accepted", false))
			and bool(selection_only.get("consumed", false))
			and (selection_only.get("effect", {}) as Dictionary).get("status", &"") == &"target_selected"
			and selected[0] == 3
			and emitted[0] == 0,
		"target selection is consumable independently of fire cadence"
	)

	var cooldown = craft.submit_crew_intent(
		1,
		88,
		&"bulwark_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_01",
			"trigger": true,
			"target_generation": 1,
		},
		5
	)
	_check(
		bool(cooldown.get("accepted", false))
			and not bool(cooldown.get("consumed", false))
			and (cooldown.get("effect", {}) as Dictionary).get("status", &"") == &"role_cooldown"
			and emitted[0] == 0,
		"gunner siege-lance cadence blocks a second request without affecting pilot fire"
	)
	craft.set("_weapon_timer", 0.0)
	_check(
		not bool(craft.get_gunner_gameplay_state().get("weapon_ready", true)),
		"gunner readiness reports the seated gunner's own siege-lance cooldown, not the idle pilot cannon"
	)

	var handoff = craft.handoff_crew_role(
		1,
		88,
		&"bulwark_gunner",
		&"gunner_station",
		6,
		99,
		&"replacement_gunner",
		Authority.ROLE_GUNNER,
		7
	)
	_check(
		bool(handoff.get("accepted", false))
			and cleared[0] == 1
			and clear_reason[0] == &"role_handoff",
		"gunner handoff clears the outgoing target exactly once"
	)
	craft.set("_weapon_timer", 10.0)
	_check(
		bool(craft.get_gunner_gameplay_state().get("weapon_ready", false)),
		"a fresh gunner's siege lance reads ready while only the pilot cannon is cooling"
	)

	var stale = craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_02",
			"trigger": false,
			"target_generation": 1,
		},
		8
	)
	_check(
		bool(stale.get("accepted", false))
			and not bool(stale.get("consumed", false))
			and (stale.get("effect", {}) as Dictionary).get("status", &"") == &"stale_target_generation",
		"old target generation cannot be reused after handoff"
	)

	var replacement = craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_02",
			"trigger": false,
			"target_generation": 2,
		},
		9
	)
	_check(
		bool(replacement.get("accepted", false))
			and bool(replacement.get("consumed", false))
			and selected_generation[0] == 2,
		"replacement gunner selects against the fresh generation"
	)

	var replacement_charge = craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_02",
			"trigger": true,
			"target_generation": 2,
		},
		10
	)
	var replacement_charge_effect := replacement_charge.get("effect", {}) as Dictionary
	_check(
		bool(replacement_charge.get("accepted", false))
			and bool(replacement_charge.get("consumed", false))
			and replacement_charge_effect.get("status", &"") == &"charge_started",
		"replacement gunner starts without inheriting the old charge"
	)
	for _frame in 30:
		await physics_frame
	var replacement_fire = craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_02",
			"trigger": true,
			"target_generation": 2,
		},
		11
	)
	var replacement_effect := replacement_fire.get("effect", {}) as Dictionary
	_check(
		bool(replacement_fire.get("accepted", false))
			and bool(replacement_fire.get("consumed", false))
			and replacement_effect.get("status", &"") == &"siege_lance_resolved"
			and replacement_effect.get("ammunition_remaining", -1) == 1,
		"replacement gunner dispatches with fresh cooldown and ammunition state"
	)

	var released = craft.release_crew_role(
		1,
		99,
		&"replacement_gunner",
		&"gunner_station",
		12
	)
	_check(bool(released.get("accepted", false)), "replacement gunner releases through the same authority")
	await physics_frame
	_check(cleared[0] == 2 and clear_reason[0] == &"role_released", "detach clears replacement target state")

	var component_model := craft.get_component_damage()
	_check(component_model != null and component_model.is_configured(), "Bulwark exposes the existing component damage ledger")
	component_model.record_damage(300.0)
	var repair_target: StringName = &"port_wing"
	var adjacent_target: StringName = &"starboard_wing"
	var repair_integrity_before := component_model.get_component_integrity(repair_target)
	var adjacent_integrity_before := component_model.get_component_integrity(adjacent_target)
	var failed_component := craft.get_gunner_gameplay_state().get("gunner_component", {}) as Dictionary
	_check(
		not bool(failed_component.get("available", true))
			and failed_component.get("reason", &"") == &"gunner_weapon_component_failed",
		"a failed weapon component blocks a new gunner charge with an inspectable reason"
	)
	_check(
		bool(authority.claim(1, 88, &"fresh_gunner", &"gunner_station", Authority.ROLE_GUNNER, 13).get("accepted", false)),
		"server admits a fresh gunner after the previous release"
	)
	var blocked = craft.submit_crew_intent(
		1,
		88,
		&"fresh_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"failed_target",
			"trigger": true,
			"target_generation": 3,
		},
		14
	)
	_check(
		bool(blocked.get("accepted", false))
			and not bool(blocked.get("consumed", false))
			and (blocked.get("effect", {}) as Dictionary).get("status", &"") == &"gunner_weapon_component_failed",
		"failed component rejects the authorized gunner dispatch before charge"
	)
	craft.set("_landed", true)
	var repaired_once: Dictionary = craft.submit_crew_intent(
		1,
		77,
		&"bulwark_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{
			"system_id": &"port_wing",
			"repair": 0.1,
			"system_generation": 1,
		},
		2
	)
	var repair_started := repaired_once.get("effect", {}) as Dictionary
	_check(
		bool(repaired_once.get("accepted", false))
			and bool(repaired_once.get("consumed", false))
			and repair_started.get("status", &"") == &"repair_started"
			and is_equal_approx(
				component_model.get_component_integrity(repair_target),
				repair_integrity_before
			)
			and is_equal_approx(
				component_model.get_component_integrity(adjacent_target),
				adjacent_integrity_before
			)
			and craft.get_engineer_status_text().contains("[WORK"),
		"the authorized engineer reserves visible work without immediate mutation"
	)
	await physics_frame
	await physics_frame
	var repair_integrity_at_departure := component_model.get_component_integrity(repair_target)
	_check(
		repair_integrity_at_departure > repair_integrity_before,
		"HeroShip passive berth repair continues while Bulwark engineer work is pending"
	)
	craft.set("_landed", false)
	await physics_frame
	var interrupted_repair: Dictionary = craft.get_engineer_repair_state()
	_check(
		StringName(interrupted_repair.get("status", &"")) == &"interrupted"
			and StringName(interrupted_repair.get("reason", &"")) == &"left_berth"
			and is_equal_approx(
				component_model.get_component_integrity(repair_target),
				repair_integrity_at_departure
			)
			and is_zero_approx(float(interrupted_repair.get("cooldown_remaining", -1.0)))
			and craft.get_engineer_status_text().contains("[INTERRUPTED]"),
		"departing the berth visibly interrupts Bulwark repair without commit or cooldown"
	)
	craft.set("_landed", true)
	_check(
		bool(component_model.record_damage(80.0, Vector3.INF).get("accepted", false)),
		"the interrupted component ledger accepts fresh damage before retry"
	)
	var restart_before := component_model.get_component_integrity(repair_target)
	var adjacent_restart_before := component_model.get_component_integrity(adjacent_target)
	var restarted_repair: Dictionary = craft.submit_crew_intent(
		1,
		77,
		&"bulwark_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{
			"system_id": repair_target,
			"repair": 0.1,
			"system_generation": 1,
		},
		3
	)
	_check(
		bool(restarted_repair.get("consumed", false))
			and (restarted_repair.get("effect", {}) as Dictionary).get("status", &"") == &"repair_started",
		"an interrupted Bulwark repair preserves its resource for retry"
	)
	for _frame in 60:
		if StringName(craft.get_engineer_repair_state().get("status", &"")) == &"completed":
			break
		await physics_frame
	var completed_repair: Dictionary = craft.get_engineer_repair_state()
	var repair_receipt := completed_repair.get("receipt", {}) as Dictionary
	var repair_operation := repair_receipt.get("operation", {}) as Dictionary
	var selected_gain := component_model.get_component_integrity(repair_target) - restart_before
	var adjacent_gain := component_model.get_component_integrity(adjacent_target) - adjacent_restart_before
	_check(
		StringName(completed_repair.get("status", &"")) == &"completed"
			and int(repair_operation.get("repaired_components", 0)) == 1
			and selected_gain > adjacent_gain
			and float(completed_repair.get("cooldown_remaining", 0.0)) > 0.0
			and int(completed_repair.get("resource_units", -1)) == 5
			and int(completed_repair.get("resource_capacity", -1)) == 6
			and craft.get_engineer_status_text().contains("KITS 5/6"),
		"completed Bulwark work targets one component and visibly spends one repair kit"
	)
	var service_integrity := component_model.get_component_integrity(repair_target)
	var service_cooldown := float(completed_repair.get("cooldown_remaining", 0.0))
	var restocked: Dictionary = craft.call(&"restock_engineer_repair_kits") as Dictionary
	_check(
		bool(restocked.get("accepted", false))
			and restocked.get("reason", &"") == &"resource_restocked"
			and int(restocked.get("resource_units", -1)) == 6
			and is_equal_approx(
				component_model.get_component_integrity(repair_target), service_integrity
			)
			and is_equal_approx(
				float(craft.get_engineer_repair_state().get("cooldown_remaining", -1.0)),
				service_cooldown
			)
			and craft.get_engineer_status_text().contains("KITS 6/6"),
		"landed Bulwark service fills its locker without repairing damage or clearing cooldown"
	)
	var cooldown_attempt: Dictionary = craft.submit_crew_intent(
		1,
		77,
		&"bulwark_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{
			"system_id": repair_target,
			"repair": 0.1,
			"system_generation": 1,
		},
		4
	)
	_check(
		bool(cooldown_attempt.get("accepted", false))
			and not bool(cooldown_attempt.get("consumed", false))
			and (cooldown_attempt.get("effect", {}) as Dictionary).get("status", &"") == &"cooldown",
		"a second Bulwark repair is rejected until the visible cooldown expires"
	)
	var replayed_repair: Dictionary = craft.submit_crew_intent(
		1,
		77,
		&"bulwark_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{
			"system_id": repair_target,
			"repair": 0.1,
			"system_generation": 1,
		},
		4
	)
	_check(
		not bool(replayed_repair.get("accepted", false))
			and replayed_repair.get("status", &"") == &"stale_request_sequence",
		"replayed Bulwark engineer receipts cannot commit twice"
	)
	var impaired_component := craft.get_gunner_gameplay_state().get("gunner_component", {}) as Dictionary
	_check(
		bool(impaired_component.get("available", false))
			and float(impaired_component.get("fire_multiplier", 1.0)) < 1.0,
		"a damaged weapon component exposes a reduced allowed cadence"
	)
	# Keep the craft in the damaged flight state while the charge/cooldown
	# evidence is observed; the passive berth repair proven above remains untouched.
	craft.set("_landed", false)
	var impaired_charge: Dictionary = craft.submit_crew_intent(
		1,
		88,
		&"fresh_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"impaired_target",
			"trigger": true,
			"target_generation": 3,
		},
		15
	)
	var impaired_effect := impaired_charge.get("effect", {}) as Dictionary
	_check(
		bool(impaired_charge.get("accepted", false))
			and impaired_effect.get("status", &"") == &"charge_started"
			and float(impaired_effect.get("charge_remaining", 0.0)) > Bulwark.GUNNER_SIEGE_CHARGE_TIME,
		"impaired weapon component lengthens the siege-lance charge window"
	)
	for _frame in 100:
		await physics_frame
	var impaired_fire: Dictionary = craft.submit_crew_intent(
		1,
		88,
		&"fresh_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"impaired_target",
			"trigger": true,
			"target_generation": 3,
		},
		16
	)
	_check(
		bool(impaired_fire.get("consumed", false))
			and float((impaired_fire.get("effect", {}) as Dictionary).get("cooldown_remaining", 0.0)) > 1.0 / 0.2083333,
		"impaired weapon component lengthens the resolved siege-lance cooldown"
	)
	craft.set("_landed", true)
	var repaired_nominal: Dictionary = craft.submit_crew_intent(
		1,
		77,
		&"bulwark_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{
			"system_id": &"port_wing",
			"repair": 0.1,
			"system_generation": 1,
		},
		5
	)
	_check(
		bool(repaired_nominal.get("consumed", false))
			and (repaired_nominal.get("effect", {}) as Dictionary).get("status", &"") == &"repair_started",
		"engineer can start another repair after the cooldown expires"
	)
	for _frame in 60:
		if StringName(craft.get_engineer_repair_state().get("status", &"")) == &"completed":
			break
		await physics_frame
	_check(
		StringName(craft.get_engineer_repair_state().get("status", &"")) == &"completed",
		"post-cooldown engineer work returns the weapon component toward nominal"
	)

	craft.queue_free()
	await process_frame
	await _test_real_service_route()
	_finish()


func _test_real_service_route() -> void:
	var filesystem := RewardFaultFilesystem.new()
	var path := "user://ordinary-bulwark-gunner-%d.json" % OS.get_process_id()
	var store := UserDataStore.new(path, filesystem)
	var game := preload("res://scenes/main.tscn").instantiate() as GameFlow
	_check(game.configure_runtime_settings_persistence(store), "real Main owns the private flushed user-data file before startup")
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	game.start_shift()
	await process_frame
	var actor := game.player
	var craft := game.get_node("BulwarkHeavyGunship") as BulwarkHeavyGunship
	actor.teleport_to(Transform3D(craft.global_basis,
		craft.get_boarding_position() + craft.global_basis.y * 0.05))
	for tick in 8:
		await physics_frame
		await process_frame
	await _press_interact()
	_check(await _wait_until(func() -> bool: return actor.is_seated_at(craft.get_pilot_seat_anchor()), 4.0),
		"ordinary Main E boards the unchanged actual Bulwark helm before the service walk")
	if not actor.is_seated_at(craft.get_pilot_seat_anchor()):
		game.queue_free()
		await process_frame
		return
	var berth_origin := craft.global_position
	Input.action_press(&"move_forward")
	for tick in 400:
		if craft.global_position.distance_to(berth_origin) > 110.0:
			break
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	Input.action_press(&"brake")
	await _wait_until(func() -> bool: return craft.velocity.length() < 30.0, 4.0)
	Input.action_release(&"brake")
	for tick in int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 4:
		await physics_frame
		await process_frame
	_check(craft.global_position.distance_to(berth_origin) > 100.0
		and craft.get_telemetry().engine_state == HeroShip.ENGINE_OFFLINE,
		"ordinary flight carries Bulwark clear before its sealed service-cabin walk")
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	game._unhandled_input(event)
	_check(await _wait_until(func() -> bool: return actor.is_control_enabled() and actor.is_cabin_containment_active(), 4.0),
		"ordinary pilot E leaves the actual helm onto Bulwark's supported service floor")
	for tick in 8:
		await physics_frame
		await process_frame
	var hull_origin := craft.global_position
	var reached_aft := await _walk_route_leg(&"move_back", func() -> bool: return craft.to_local(actor.global_position).z > 1.72)
	var crossed := await _walk_route_leg(&"move_right", func() -> bool: return craft.to_local(actor.global_position).x > 1.20)
	var approached := await _walk_route_leg(&"move_forward", func() -> bool: return craft.to_local(actor.global_position).z < 0.70)
	var local := craft.to_local(actor.global_position)
	print("BULWARK_REAL_GUNNER_APPROACH: ", local, " floor=", actor.is_on_floor(), " legs=", [reached_aft, crossed, approached], " drift=", craft.global_position.distance_to(hull_origin), " velocity=", craft.velocity, " control=", actor.is_control_enabled(), " pilot=", craft.is_piloted(), " canopy=", craft.get("_canopy_open"), " registered=", craft.get_moving_interior_component().is_occupant_registered(actor))
	var frame := craft.get_moving_interior_component()
	_check(reached_aft and crossed and approached and actor.is_on_floor()
		and absf(local.y - Bulwark.CABIN_FLOOR_Y) < 0.05
		and actor.is_control_enabled() and not actor.is_seated()
		and not craft.is_piloted() and frame.is_occupant_registered(actor)
		and not bool(craft.get("_canopy_open")) and craft.global_position.distance_to(hull_origin) > 0.10,
		"ordinary full-capsule input crosses the real aft vestibule and reaches the gunner approach while the sealed hull drifts")
	await _look_toward(actor, craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	print("BULWARK_GUNNER_DISCOVERY: mouse=", Input.mouse_mode, " facing=", actor.get_interaction_direction(), " candidate=", game.station_interaction_candidate, " nearby=", actor.get_nearby_interactables(), " contract=", craft.get_gunner_station_role_contract())
	await _press_interact()
	var gunner_seated := await _wait_until(func() -> bool: return actor.is_seated_at(craft.get_gunner_station_anchor()) and not bool(game.get("_transition_busy")), 4.0)
	var crew_status := game.get_solo_crew_seat_status()
	_check(gunner_seated and crew_status.get("assignment", {}).get("role", &"") == Authority.ROLE_GUNNER
		and actor.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META) and frame.is_occupant_registered(actor)
		and not craft.is_piloted(), "ordinary E seats the actual Player at the gunner chair with the existing role and frame owners, without helm")
	if gunner_seated:
		var drone := game.get_node("ShipyardWorld/ExteriorTargetRange/TargetDrone03") as Node3D
		var health_before := float(drone.get_meta("health", 0.0))
		var receipts: Array[Dictionary] = []
		var pilot_shots := [0]
		craft.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void: pilot_shots[0] += 1)
		game.get_combat_authority().authoritative_shot_submitted.connect(func(request, result: Dictionary) -> void:
			if request.source_entity == craft and request.weapon_id == Bulwark.BULWARK_CREW_WEAPON_ID:
				receipts.append(result.duplicate(true)))
		# Match the existing local-input focus fixture; FIRE remains actual InputMap input.
		craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		await _look_toward(actor, drone.global_position)
		_check(await _set_fire_mode(game, InputBindingProfile.HOLD), "actual RuntimeSettings installs HOLD FIRE in the retained fleet producer")
		craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		print("BULWARK_FIRE_GATE: available=", game.call("_solo_gunner_input_is_available"), " current=", game.call("_solo_crew_claim_is_current"), " physics=", game.is_physics_processing(), " initialized=", game.get("_initialized"), " owner=", craft.get_local_input_source().is_enabled_owner(), " focus=", craft.get_local_input_source().get("_application_focused"), " config=", craft.get_local_input_source().is_input_configuration_valid(), " source=", craft.get_command_source() == craft.get_local_input_source())
		Input.action_press(&"fire")
		await _track_target_until(actor, drone, func() -> bool: return float(drone.get_meta("health", health_before)) < health_before, 3.0)
		Input.action_release(&"fire")
		await physics_frame
		print("BULWARK_ORDINARY_GUNNER_FIRE: health=", [health_before, drone.get_meta("health")], " receipts=", receipts, " state=", craft.get_gunner_gameplay_state(), " gate=", game.call("_solo_gunner_input_is_available"), " logical=", game.get("_solo_gunner_fire"), " audit=", craft.get_local_input_source().get_input_integration_audit().get("sampler"))
		print("BULWARK_FIRE_DOWNSTREAM: engine=", craft.get_telemetry().engine_state, " tag=", actor.get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META, {}), " muzzle=", craft.get_node_or_null("LeftMuzzle"), " profile=", game.get_combat_authority().get_weapon_profile(craft, Bulwark.BULWARK_CREW_WEAPON_ID), " stream=", [game.get("_solo_gunner_source_stream"), craft.get_local_input_source().get_stream_id()], " profilegen=", [game.get("_solo_gunner_source_profile"), craft.get_local_input_source().get_input_profile_generation()], " sourcecurrent=", game.call("_solo_gunner_source_is_current"), " elapsed=", game.get("_solo_gunner_input_elapsed"), " intent=", craft.get_crew_role_authority().get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID), " sequence=", game.get("_solo_crew_sequence"))
		var damaged := false
		for receipt in receipts:
			damaged = damaged or (bool(receipt.get("accepted", false)) and bool(receipt.get("damaged", false)))
		_check(damaged and float(drone.get_meta("health", health_before)) < health_before
			and craft.get_gunner_gameplay_state().get("target_selection", {}).get("target_id", &"") == &"DRONE-03"
			and pilot_shots[0] == 0 and not craft.is_piloted() and not craft.get_last_ship_command().fire,
			"held ordinary FIRE selects and damages the existing range drone through the shared siege-lance owner without pilot fire or helm")
		var released_sequence := int(craft.get_crew_role_authority().get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).get("request_sequence", 0))
		for tick in 12:
			await physics_frame
			await process_frame
		_check(not bool(game.get("_solo_gunner_fire")) and int(craft.get_crew_role_authority().get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).get("request_sequence", 0)) == released_sequence,
			"HOLD release stops Main's actual gunner intent stream")
		await _wait_until(func() -> bool: return craft.get_gunner_gameplay_state().get("role_cooldowns", {}).values().all(func(value) -> bool: return float(value) <= 0.0), 6.0)
		_check(await _set_fire_mode(game, InputBindingProfile.TOGGLE), "actual RuntimeSettings installs TOGGLE FIRE without replacing the crew owner")
		craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		var toggle_health := float(drone.get_meta("health", 0.0))
		await _tap_fire()
		_check(await _track_target_until(actor, drone, func() -> bool: return float(drone.get_meta("health", toggle_health)) < toggle_health, 3.0)
			and not Input.is_action_pressed(&"fire") and bool(game.get("_solo_gunner_fire")),
			"released physical TOGGLE FIRE continues the actual siege charge and damages the real target")
		await _tap_fire()
		await physics_frame
		await process_frame
		_check(not bool(game.get("_solo_gunner_fire")), "second ordinary TOGGLE press stops Main gunner FIRE")
		await _set_fire_mode(game, InputBindingProfile.HOLD)
		await _press_interact()
		_check(await _wait_until(func() -> bool: return not actor.is_seated() and actor.is_control_enabled() and actor.is_on_floor(), 4.0)
			and not actor.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META) and frame.is_occupant_registered(actor)
			and craft.get_crew_role_authority() == null and not craft.is_piloted(),
			"ordinary E stands on the actual supported service floor and releases only the gunner role")
	await _look_toward(actor, actor.global_position - craft.global_basis.z * 20.0 + Vector3.UP * 1.5)
	var returned_aft := await _walk_route_leg(&"move_back", func() -> bool: return craft.to_local(actor.global_position).z > 1.72)
	var returned_port := await _walk_route_leg(&"move_left", func() -> bool: return craft.to_local(actor.global_position).x < -0.54)
	var returned_helm := await _walk_route_leg(&"move_forward", func() -> bool: return craft.to_local(actor.global_position).z < -0.70)
	print("BULWARK_REAL_RETURN: ", craft.to_local(actor.global_position), " legs=", [returned_aft, returned_port, returned_helm], " floor=", actor.is_on_floor(), " phase=", game.phase)
	await _press_interact()
	_check(returned_aft and returned_port and returned_helm
		and await _wait_until(func() -> bool: return actor.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted(), 4.0)
		and not frame.is_occupant_registered(actor) and not actor.is_cabin_containment_active(),
		"ordinary input returns through the connected corridor and E retakes the existing actual helm")
	await _test_gunner_file_recovery_and_cleanup(game, craft, store, filesystem, path)



func _test_gunner_file_recovery_and_cleanup(game: GameFlow, craft: BulwarkHeavyGunship, store: UserDataStore, filesystem: RewardFaultFilesystem, path: String) -> void:
	# Only activity positioning uses the existing fixture. Actual pilot ownership
	# has already been acquired by ordinary E and is never injected here.
	_check(game.player.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted()
		and bool(game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT).accepted),
		"fixture-positioned convoy begins with the actually acquired Bulwark pilot")
	await preload("res://scripts/diagnostics/in_world_interruption_probe.gd")._position_escort_fixture(game, craft)
	_check(game.player.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted()
		and bool(game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID).accepted),
		"existing activity positioning preserves actual pilot ownership and starts the real convoy")
	_check(await preload("res://scripts/diagnostics/in_world_interruption_probe.gd").finish_convoy(game, craft),
		"the existing convoy/combat owners finish the fixture-positioned activity while its reward write fails")
	var activity_boundary := JSON.stringify(store.get_snapshot().get("cinder_convoy_session", {}))
	var reward_boundary := JSON.stringify(game.get_activity_reward_report().get("authority", {}).get("record", {}))
	var activities: Array = store.get_snapshot().get("cinder_convoy_session", {}).get("activities", [])
	_check(not activities.is_empty() and bool(activities[0].reward_requested) and not bool(activities[0].reward_granted),
		"real activity debt is durable before the gunner interruption")
	await _leave_actual_helm(game, craft)
	_check(await _walk_and_sit_gunner(game, craft), "actual ordinary walk/E gunner admission carries the terminal activity debt")
	game.call("_capture_solo_safe_recovery_context")
	var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	_check(context.size() == 4 and context.get("mode") == "crew" and context.get("craft_id") == String(craft.get_ship_id())
		and game.player.is_seated_at(craft.get_gunner_station_anchor()) and FileAccess.file_exists(path),
		"actual seated gunner captures only the existing four safe fields to the real private file")
	var old_player_id := game.player.get_instance_id()
	var old_craft_id := craft.get_instance_id()
	game.queue_free()
	await _settle_frames(3)
	var cold_store := UserDataStore.new(path, filesystem)
	var loaded := cold_store.load()
	_check(bool(loaded.get("accepted", false)) and cold_store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {}) == context,
		"a fresh production UserDataStore reloads the exact gunner preference before Main resets")
	var cold := preload("res://scenes/main.tscn").instantiate() as GameFlow
	_check(cold.configure_runtime_settings_persistence(cold_store), "fresh Main accepts the existing store owner")
	root.add_child(cold)
	await _settle_frames(3)
	craft = cold.get_node("BulwarkHeavyGunship") as BulwarkHeavyGunship
	var actor := cold.player
	var pending := cold.get_recovery_available_snapshot()
	_check(not pending.is_empty() and cold.get_session_recovery_save_summary().contains("Bulwark")
		and cold.get_session_recovery_save_summary().contains("awake") and cold.get_session_recovery_save_summary().contains("home berth"),
		"the real-file interruption offers an explicit awake Bulwark home-cabin Resume")
	if pending.is_empty():
		cold.queue_free()
		await _settle_frames(3)
		return
	var stale: Dictionary = cold.call("_handle_hud_session_recovery_choice", &"normal_start", int(pending.session_id), int(pending.startup_generation) + 1)
	_check(not bool(stale.accepted) and not actor.is_cabin_containment_active(), "stale Resume cannot acquire a gunner or cabin owner")
	var accepted: Dictionary = cold.call("_handle_hud_session_recovery_choice", &"normal_start", int(pending.session_id), int(pending.startup_generation))
	_check(bool(accepted.accepted) and not actor.is_cabin_containment_active(), "fenced Resume stages recovery until actual BEGIN SHIFT")
	cold.start_shift()
	await _settle_frames(12)
	var frame := craft.get_moving_interior_component()
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var berth := cold.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	_check(actor.get_instance_id() != old_player_id and craft.get_instance_id() != old_craft_id
		and cold.active_ship == craft and actor.is_on_floor() and actor.is_control_enabled() and not actor.is_seated() and not actor.is_sleeping()
		and frame.is_occupant_registered(actor) and actor.is_cabin_containment_active() and area.get_reservation_token() == actor
		and berth.get_occupant() == craft and berth.get_reservation_owner() == craft and not craft.is_piloted()
		and craft.get_crew_role_authority() == null and not actor.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META),
		"cold Resume reacquires fresh supported cabin/hatch/home-berth owners without restoring any old gunner or pilot claim")
	_check(JSON.stringify(cold_store.get_snapshot().get("cinder_convoy_session", {})) == activity_boundary
		and JSON.stringify(cold.get_activity_reward_report().get("authority", {}).get("record", {})) == reward_boundary,
		"awake cold gunner recovery preserves the exact terminal activity and unpaid reward")
	await _look_toward(actor, actor.global_position - craft.global_basis.z * 20.0 + Vector3.UP * 1.5)
	var helm := await _walk_route_leg(&"move_forward", func() -> bool: return craft.to_local(actor.global_position).z < -0.70)
	print("BULWARK_COLD_HELM: pose=", craft.to_local(actor.global_position), " candidate=", cold.boarding_candidate, " station=", cold.station_interaction_candidate, " engine=", craft.get_telemetry().engine_state, " busy=", cold.get("_transition_busy"), " facing=", actor.get_interaction_direction())
	await _press_interact()
	_check(helm and await _wait_until(func() -> bool: return actor.is_seated_at(craft.get_pilot_seat_anchor()) and craft.is_piloted(), 4.0),
		"the recovered Player walks back and takes the actual home helm through ordinary E")
	cold.call("_try_exit_ship")
	_check(await _wait_until(func() -> bool: return cold.phase == GameFlow.Phase.APPROACH_SHIP and not actor.is_cabin_containment_active() and not actor.is_seated() and actor.is_control_enabled() and actor.is_on_floor() and not craft.is_piloted(), 4.0),
		"existing landed exit owner returns the recovered Player to the supported shipyard deck")
	_check(JSON.stringify(cold_store.get_snapshot().get("cinder_convoy_session", {})) == activity_boundary,
		"gunner ownership, walking, helm and deck exit leave the exact debt boundary unchanged")
	filesystem.reject_rewards = false
	cold.call("_retry_owed_game_flow_activity_rewards")
	var paid := JSON.stringify(cold.get_activity_reward_report().get("authority", {}).get("record", {}))
	cold.call("_retry_owed_game_flow_activity_rewards")
	_check(bool(cold_store.get_snapshot().get("cinder_convoy_session", {}).get("activities", [])[0].reward_granted)
		and JSON.stringify(cold.get_activity_reward_report().get("authority", {}).get("record", {})) == paid,
		"actual existing reward owner pays the preserved gunner debt exactly once")
	# The landed-exit owner deliberately blocks immediate reboard until the
	# Player walks clear of the same interaction volume and returns.
	await _look_toward(actor, actor.global_position - craft.global_basis.z * 20.0 + Vector3.UP * 1.5)
	await _walk_route_leg(&"move_left", func() -> bool: return craft.to_local(actor.global_position).x < -11.0)
	await _look_toward(actor, craft.get_boarding_position() + Vector3.UP)
	await _walk_route_leg(&"move_forward", func() -> bool: return craft.to_local(actor.global_position).x > -6.3)
	print("BULWARK_DECK_REBOARD: pose=", craft.to_local(actor.global_position), " candidate=", cold.boarding_candidate, " phase=", cold.phase, " blocked=", cold.get("_reboard_blocked_ship"), " engine=", craft.get_telemetry().engine_state)
	await _press_interact()
	_check(await _wait_until(func() -> bool: return actor.is_seated_at(craft.get_pilot_seat_anchor()), 4.0), "ordinary deck E reboards the same recovered craft before retirement coverage")
	craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	Input.action_press(&"move_forward")
	var launch_origin := craft.global_position
	await _wait_until(func() -> bool: return craft.global_position.distance_to(launch_origin) > 110.0, 7.0)
	Input.action_release(&"move_forward")
	Input.action_press(&"brake")
	await _wait_until(func() -> bool: return craft.velocity.length() < 30.0, 4.0)
	Input.action_release(&"brake")
	await _leave_actual_helm(cold, craft)
	var readmitted := await _walk_and_sit_gunner(cold, craft)
	_check(readmitted, "ordinary pilot leave/walk/E settles a genuine gunner before its actual craft is freed")
	if readmitted:
		var retiring_authority := craft.get_crew_role_authority()
		craft.queue_free()
		await _settle_frames(3)
		await _wait_until(func() -> bool: return actor.is_on_floor() and actor.is_control_enabled() and not actor.is_seated(), 1.0)
		_check(not is_instance_valid(craft) and retiring_authority.get_snapshot().assignments.is_empty()
			and not actor.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META) and not actor.is_seated() and actor.is_control_enabled()
			and actor.is_on_floor() and not actor.is_cabin_containment_active()
			and cold.get_solo_crew_seat_status().get("assignment", {}).is_empty(),
			"actual craft retirement releases only the old gunner owners and returns the same Player to a supported usable deck")
	cold.queue_free()
	await _settle_frames(3)
	await _test_retained_foreign_gunner_power()



func _test_retained_foreign_gunner_power() -> void:
	var cold := preload("res://scenes/main.tscn").instantiate() as GameFlow
	cold.configure_runtime_settings_persistence(UserDataStore.new("user://bulwark-foreign-owner-%d.json" % OS.get_process_id()))
	root.add_child(cold)
	await _settle_frames(3)
	cold.start_shift()
	var craft := cold.get_node("BulwarkHeavyGunship") as BulwarkHeavyGunship
	var actor := cold.player
	actor.teleport_to(Transform3D(craft.global_basis, craft.get_boarding_position() + Vector3.UP * 0.05))
	await _settle_frames(8)
	await _press_interact()
	_check(await _wait_until(func() -> bool: return actor.is_seated_at(craft.get_pilot_seat_anchor()), 4.0), "separate ownership context acquires its actual pilot through E")
	var origin := craft.global_position
	craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	Input.action_press(&"move_forward")
	await _wait_until(func() -> bool: return craft.global_position.distance_to(origin) > 110.0, 7.0)
	Input.action_release(&"move_forward")
	Input.action_press(&"brake")
	await _wait_until(func() -> bool: return craft.velocity.length() < 30.0, 4.0)
	Input.action_release(&"brake")
	await _leave_actual_helm(cold, craft)
	_check(await _walk_and_sit_gunner(cold, craft), "separate real Main ordinary controls reach the gunner before retained/foreign-owner checks")
	var retained_authority := craft.get_crew_role_authority()
	root.remove_child(cold)
	await process_frame
	root.add_child(cold)
	await _settle_frames(12)
	_check(cold.player == actor and retained_authority.get_snapshot().assignments.is_empty()
		and not actor.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META) and not actor.is_seated() and actor.is_control_enabled() and actor.is_on_floor(),
		"retained Main keeps the actual Player and releases its interrupted gunner claim on detach")
	_check(await _sit_nearby_gunner(cold, craft), "ordinary E can reacquire the released chair after retained Main reentry")
	craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	var engine_before := craft.get_telemetry().engine_state
	var latch_before := bool(craft.get("_docked_latch"))
	var power_owned_before := bool(actor.get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META, {}).get("weapon_power_started", false))
	Input.action_press(&"fire")
	var powered := await _wait_until(func() -> bool: return craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE and not craft.get_crew_role_authority().get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty(), 1.0)
	Input.action_release(&"fire")
	print("BULWARK_RETAINED_POWER: before=", engine_before, " after=", craft.get_telemetry().engine_state, " latch=", [latch_before, craft.get("_docked_latch")], " tag=", actor.get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META, {}))
	_check(powered and not craft.is_piloted() and bool(craft.get("_docked_latch")) == latch_before
		and bool(actor.get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META, {}).get("weapon_power_started", false)) == (true if engine_before == HeroShip.ENGINE_OFFLINE else power_owned_before),
		"actual seated gunner FIRE uses weapon demand, preserves the witnessed dock latch and owns only power it woke")
	var old_authority := craft.get_crew_role_authority()
	var assignment := old_authority.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID)
	var release_sequence := maxi(int(assignment.get("claim_sequence", 0)), int(old_authority.get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).get("request_sequence", 0))) + 1
	var released := old_authority.release(1, 1, GameFlow.SOLO_CREW_AVATAR_ID, &"gunner_station", release_sequence, int(assignment.get("seat_generation", 0)))
	var replacement := Authority.new(1)
	var roster := replacement.register_bulwark_roster()
	var detached := craft.detach_crew_role_authority(old_authority)
	var attached := craft.attach_crew_role_authority(replacement)
	var foreign := replacement.claim(1, 2, &"replacement_gunner", &"gunner_station", Authority.ROLE_GUNNER, 1)
	_check(bool(released.accepted) and detached and bool(roster.accepted) and bool(attached.accepted) and bool(foreign.accepted),
		"existing owner APIs transfer the empty local ledger to a genuine competing gunner ledger")
	await _settle_frames(8)
	_check(not actor.is_seated() and actor.is_on_floor() and actor.is_control_enabled() and not actor.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META)
		and craft.get_crew_role_authority() == replacement and replacement.get_assignment(2, &"replacement_gunner") == foreign.assignment
		and old_authority.get_snapshot().assignments.is_empty() and craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE,
		"old exact-owner cleanup restores usable cabin controls and preserves replacement gunner claim and power")
	await _look_toward(actor, craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	await _press_interact()
	await _settle_frames(8)
	_check(not actor.is_seated() and replacement.get_assignment(2, &"replacement_gunner") == foreign.assignment,
		"ordinary E refuses the competing chair without stealing its ledger")
	cold.queue_free()
	await _settle_frames(3)

func _leave_actual_helm(game: GameFlow, craft: HeroShip) -> void:
	await _settle_frames(int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 4)
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	game._unhandled_input(event)
	await _wait_until(func() -> bool: return game.player.is_control_enabled() and game.player.is_cabin_containment_active() and not game.player.is_seated(), 4.0)
	await _look_toward(game.player, game.player.global_position - craft.global_basis.z * 20.0 + Vector3.UP * 1.5)


func _walk_and_sit_gunner(game: GameFlow, craft: BulwarkHeavyGunship) -> bool:
	var actor := game.player
	await _look_toward(actor, actor.global_position - craft.global_basis.z * 20.0 + Vector3.UP * 1.5)
	var aft := await _walk_route_leg(&"move_back", func() -> bool: return craft.to_local(actor.global_position).z > 1.72)
	var crossed := await _walk_route_leg(&"move_right", func() -> bool: return craft.to_local(actor.global_position).x > 1.20)
	var approached := await _walk_route_leg(&"move_forward", func() -> bool: return craft.to_local(actor.global_position).z < 0.70)
	return aft and crossed and approached and actor.is_on_floor() and await _sit_nearby_gunner(game, craft)


func _sit_nearby_gunner(game: GameFlow, craft: BulwarkHeavyGunship) -> bool:
	await _look_toward(game.player, craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	await _press_interact()
	return await _wait_until(func() -> bool: return game.player.is_seated_at(craft.get_gunner_station_anchor()) and bool(game.get_solo_crew_seat_status().get("seated", false)) and not bool(game.get("_transition_busy")), 4.0)


func _tap_fire() -> void:
	Input.action_press(&"fire")
	await _settle_frames(3)
	Input.action_release(&"fire")
	await _settle_frames(3)


func _settle_frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame

func _set_fire_mode(game: GameFlow, mode: StringName) -> bool:
	var profile := game.runtime_settings.get_input_binding_profile()
	var options := profile.get_action_options(&"fire")
	options.hold_mode = mode
	var accepted := profile.set_action_options(&"fire", options) and game.runtime_settings.set_input_binding_profile(profile)
	for tick in 3:
		await physics_frame
		await process_frame
	return accepted and game.active_ship.get_local_input_source().get_input_binding_profile().get_action_options(&"fire").hold_mode == mode


func _apply_mouse_look(actor: PlayerController, target: Vector3) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		actor._unhandled_input(click)
	var desired := actor.global_basis.inverse() * (target - actor.get_camera().global_position).normalized()
	var current := actor.global_basis.inverse() * actor.get_interaction_direction().normalized()
	var yaw_delta := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
	var pitch_delta := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-yaw_delta, pitch_delta * (1.0 if actor.invert_mouse_y else -1.0)) / actor.mouse_sensitivity
	actor._unhandled_input(motion)


func _look_toward(actor: PlayerController, target: Vector3) -> void:
	for tick in 4:
		_apply_mouse_look(actor, target)
		await physics_frame
		await process_frame


func _track_target_until(actor: PlayerController, target: Node3D, reached: Callable, seconds: float) -> bool:
	for tick in int(ceil(seconds * Engine.physics_ticks_per_second)):
		if reached.call():
			return true
		_apply_mouse_look(actor, target.global_position)
		await physics_frame
		await process_frame
	return bool(reached.call())


func _walk_route_leg(action: StringName, arrived: Callable) -> bool:
	Input.action_press(action)
	for tick in 180:
		if arrived.call():
			break
		await physics_frame
		await process_frame
	Input.action_release(action)
	for tick in 8:
		await physics_frame
		await process_frame
	return bool(arrived.call())


func _press_interact() -> void:
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	await physics_frame
	await process_frame


func _wait_until(predicate: Callable, seconds: float) -> bool:
	var budget := int(ceil(seconds * Engine.physics_ticks_per_second))
	for tick in budget:
		if predicate.call():
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _build_authority():
	var authority := Authority.new(1)
	for seat in [
		[&"pilot_station", Authority.ROLE_PILOT, &"pilot_seat_anchor"],
		[&"gunner_station", Authority.ROLE_GUNNER, &"gunner_station_anchor"],
		[&"passenger_slot", Authority.ROLE_PASSENGER, &""],
		[&"engineer_slot", Authority.ROLE_ENGINEER, &""],
	]:
		var result := authority.register_seat(
			seat[0],
			&"bulwark_heavy_gunship",
			seat[1],
			&"bulwark_flight_deck",
			1,
			seat[2]
		)
		_check(bool(result.get("accepted", false)), "Bulwark role seat registers: %s" % seat[0])
	var sealed := authority.seal_roster()
	_check(bool(sealed.get("accepted", false)), "Bulwark role roster seals before claims")
	_check(
		bool(authority.claim(1, 88, &"bulwark_gunner", &"gunner_station", Authority.ROLE_GUNNER, 1).get("accepted", false)),
		"server admits the optional gunner at the physical station"
	)
	_check(
		bool(authority.claim(1, 77, &"bulwark_engineer", &"engineer_slot", Authority.ROLE_ENGINEER, 1).get("accepted", false)),
		"server admits the optional engineer at the systems station"
	)
	return authority


func _finish() -> void:
	for action in [&"fire", &"interact", &"move_forward", &"move_back", &"move_left", &"move_right", &"brake"]:
		Input.action_release(action)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("BULWARK_CREW_GUNNER_GAMEPLAY: %d checks, %d failures" % [_checks, _failures.size()])
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
	quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + message)
