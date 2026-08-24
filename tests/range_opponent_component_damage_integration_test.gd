extends SceneTree

const AdapterType := preload(
	"res://scripts/combat/range_opponent_component_damage_adapter.gd"
)
const LifecycleAdapterType := preload(
	"res://scripts/combat/lifecycle_damageable_adapter.gd"
)
const OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")
const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const COURIER_SCENE := preload("res://scenes/ships/courier_runner_opponent.tscn")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")
const SHIP_LAYER := 1 << 2
const TARGET_LAYER := 1 << 5

var _failures := PackedStringArray()
var _assertions := 0
var _health_events: Array[Vector2] = []
var _destroyed_positions: Array[Vector3] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_detached_adapter_contract()
	await _test_runtime_modifier_consumption()
	await _test_derived_archetype_component_presentation()
	await _test_production_lifecycle()
	_finish()


func _test_detached_adapter_contract() -> void:
	var adapter := AdapterType.new(85.0) as RangeOpponentComponentDamageAdapter
	var dormant := adapter.get_snapshot()
	var definition := dormant.get("definition", {}) as Dictionary
	var components := definition.get("components", []) as Array
	var stages := (
		(components[0] as Dictionary).get("damage_stages", []) as Array
		if components.size() == 4
		else []
	)
	_check(
		adapter != null
		and adapter.is_configuration_valid()
		and is_equal_approx(adapter.get_maximum_health(), 85.0)
		and int((dormant.get("model", {}) as Dictionary).get("generation", -1)) == 0
		and adapter.get_health() == 0.0,
		"the production adapter captures one valid dormant hull and operational model"
	)
	var expected_stages := [
		[&"nominal", 1.0, false, 1.0],
		[&"damaged", 0.67, false, 1.0],
		[&"critical", 0.34, false, 1.0],
		[&"destroyed", 0.0, true, 0.0],
	]
	var stages_exact := stages.size() == expected_stages.size()
	for index in mini(stages.size(), expected_stages.size()):
		var stage := stages[index] as Dictionary
		var expected := expected_stages[index] as Array
		stages_exact = stages_exact \
			and stage.get("stage_id", &"") == expected[0] \
			and float(stage.get("health_ratio_at_or_below", -1.0)) == float(expected[1]) \
			and bool(stage.get("disabled", false)) == bool(expected[2]) \
			and float(stage.get("performance_multiplier", -1.0)) == float(expected[3])
	_check(
		components.size() == 4
		and (components[0] as Dictionary).get("component_id", &"") == &"hull"
		and (components[1] as Dictionary).get("component_id", &"") == &"engine"
		and (components[2] as Dictionary).get("component_id", &"") == &"weapon"
		and (components[3] as Dictionary).get("component_id", &"") == &"sensor"
		and stages_exact,
		"one ledger freezes the hull authority plus engine, weapon, and sensor consequence roster"
	)
	var authority := definition.get("authority", {}) as Dictionary
	var zero_authority := authority.size() == 12
	for value in authority.values():
		zero_authority = zero_authority and value == false
	_check(
		zero_authority,
		"the adapted model still declares zero renderer/gameplay/collision/audio authority"
	)
	var source_text := FileAccess.get_file_as_string("res://scripts/ships/range_opponent.gd")
	_check(
		not source_text.contains("var _health")
		and source_text.contains("var _hull_damage: RangeOpponentComponentDamageAdapter"),
		"RangeOpponent owns the typed model adapter instead of a mirrored scalar health ledger"
	)


func _test_runtime_modifier_consumption() -> void:
	var host := Node3D.new()
	host.name = "RangeOpponentOperationalModifierWorld"
	root.add_child(host)
	var target := Node3D.new()
	target.name = "OperationalTarget"
	target.position = Vector3(0.0, 0.0, -120.0)
	host.add_child(target)
	var opponent := OPPONENT_SCENE.instantiate() as RangeOpponent
	host.add_child(opponent)
	opponent.set_physics_process(false)
	opponent.set_target(target)
	var shots: Array[Vector3] = []
	opponent.projectile_fired.connect(
		func(_origin: Vector3, direction: Vector3) -> void: shots.append(direction)
	)
	await process_frame
	opponent.activate(Transform3D.IDENTITY)
	var nominal := opponent.get_operational_modifiers()
	_check(
		is_equal_approx(float(nominal.mobility_multiplier), 1.0)
		and is_equal_approx(float(nominal.fire_multiplier), 1.0)
		and is_equal_approx(float(nominal.targeting_multiplier), 1.0),
		"activation publishes nominal operational modifiers from the real component ledger"
	)
	target.position = Vector3(0.0, 0.0, -320.0)
	_check(
		bool(opponent.call("_has_target_awareness", nominal)),
		"nominal sensors preserve the established coordinator-owned distant target"
	)
	target.position = Vector3(0.0, 0.0, -120.0)
	opponent.velocity = Vector3.ZERO
	opponent.call("_physics_process", 0.1)
	var nominal_response := opponent.velocity.length()
	var target_direction := (target.global_position - opponent.global_position).normalized()
	var marginal_forward := target_direction.rotated(Vector3.UP, acos(0.945))
	opponent.global_basis = Basis.looking_at(marginal_forward, Vector3.UP)
	opponent.set("_cooldown_remaining", 0.0)
	opponent.set("_telegraph_remaining", 0.0)
	opponent.call(
		"_update_weapon",
		target.global_position,
		target_direction,
		opponent.global_position.distance_to(target.global_position),
		0.0
	)
	var nominal_accepts_marginal_aim := float(opponent.get("_telegraph_remaining")) > 0.0
	opponent.call("_fire_at_target", target.global_position)
	var nominal_cooldown := float(opponent.get("_cooldown_remaining"))

	opponent.global_transform = Transform3D.IDENTITY
	opponent.velocity = Vector3.ZERO
	opponent.apply_damage(34.0, opponent.global_position)
	var degraded := opponent.get_operational_modifiers()
	opponent.set("_telegraph_remaining", 0.0)
	opponent.set("_cooldown_remaining", 0.0)
	opponent.call("_physics_process", 0.1)
	var degraded_response := opponent.velocity.length()
	target_direction = (target.global_position - opponent.global_position).normalized()
	marginal_forward = target_direction.rotated(Vector3.UP, acos(0.945))
	opponent.global_basis = Basis.looking_at(marginal_forward, Vector3.UP)
	opponent.set("_cooldown_remaining", 0.0)
	opponent.set("_telegraph_remaining", 0.0)
	opponent.call(
		"_update_weapon",
		target.global_position,
		target_direction,
		opponent.global_position.distance_to(target.global_position),
		0.0
	)
	var degraded_rejects_marginal_aim := is_zero_approx(
		float(opponent.get("_telegraph_remaining"))
	)
	opponent.call("_fire_at_target", target.global_position)
	var degraded_cooldown := float(opponent.get("_cooldown_remaining"))
	_check(
		is_equal_approx(float(degraded.mobility_multiplier), 0.72)
		and degraded_response < nominal_response
		and nominal_response > 0.0,
		"resolved engine damage scales the real maneuver response without moving authority into the model"
	)
	_check(
		nominal_accepts_marginal_aim and degraded_rejects_marginal_aim,
		"resolved sensor damage tightens the real aim-acceptance gate"
	)
	target.position = Vector3(0.0, 0.0, -320.0)
	opponent.global_transform = Transform3D.IDENTITY
	opponent.velocity = Vector3.ZERO
	opponent.set("_telegraph_remaining", opponent.telegraph_time)
	opponent.call("_physics_process", 0.1)
	_check(
		not bool(opponent.call("_has_target_awareness", degraded))
		and opponent.velocity.is_zero_approx()
		and is_zero_approx(float(opponent.get("_telegraph_remaining"))),
		"damaged sensors drop distant pursuit and cancel weapon commitment without clearing target identity"
	)
	_check(
		shots.size() == 2
		and is_equal_approx(nominal_cooldown, opponent.weapon_cooldown)
		and degraded_cooldown > nominal_cooldown
		and is_equal_approx(
			degraded_cooldown,
			opponent.weapon_cooldown / float(degraded.fire_multiplier)
		),
		"resolved weapon damage lengthens cadence on actual projectile dispatch"
	)
	var damaged_generation := int(
		(opponent.get_component_damage_snapshot().get("model", {}) as Dictionary).get(
			"generation",
			-1
		)
	)
	host.remove_child(opponent)
	await process_frame
	host.add_child(opponent)
	await process_frame
	_check(
		int(
			(opponent.get_component_damage_snapshot().get("model", {}) as Dictionary).get(
				"generation",
				-1
			)
		) == damaged_generation
		and not bool(opponent.call("_has_target_awareness", opponent.get_operational_modifiers())),
		"whole-owner re-entry preserves the degraded sensor generation and awareness consequence"
	)
	opponent.deactivate()
	opponent.activate(Transform3D.IDENTITY)
	var restored := opponent.get_operational_modifiers()
	_check(
		is_equal_approx(float(restored.mobility_multiplier), 1.0)
		and is_equal_approx(float(restored.fire_multiplier), 1.0)
		and is_equal_approx(float(restored.targeting_multiplier), 1.0)
		and bool(opponent.call("_has_target_awareness", restored)),
		"reuse repair restores all runtime operational modifiers through the same model"
	)
	host.queue_free()
	await process_frame


func _test_derived_archetype_component_presentation() -> void:
	var host := Node3D.new()
	host.name = "DerivedOpponentComponentPresentationWorld"
	root.add_child(host)
	var archetypes := [
		[&"range_defender", OPPONENT_SCENE, &"AmberCanopy"],
		[&"standoff_picket", PICKET_SCENE, &"SensorBlister"],
		[&"courier_runner", COURIER_SCENE, &"DistressBeacon"],
		[&"flanking_skirmisher", SKIRMISHER_SCENE, &"RoleLamp"],
	]
	for archetype_index in archetypes.size():
		var archetype := archetypes[archetype_index] as Array
		var archetype_id := StringName(archetype[0])
		var scene := archetype[1] as PackedScene
		var sensor_anchor_name := StringName(archetype[2])
		var opponent := scene.instantiate() as RangeOpponent
		host.add_child(opponent)
		opponent.set_physics_process(false)
		opponent.set_process(false)
		await process_frame
		var activated := opponent.activate_with_result(
			Transform3D(Basis.IDENTITY, Vector3(archetype_index * 20.0, 0.0, 0.0))
		)
		var weapon_sparks := opponent.get_node_or_null("WeaponDamageSparks") as CPUParticles3D
		var sensor_light := opponent.get_node_or_null("SensorDamageLight") as OmniLight3D
		var engine_lights := opponent.get("_engine_lights") as Array
		var engine_glows := opponent.get("_engine_glows") as Array
		opponent.call("_update_presentation", 0.1)
		var nominal_engine_energies: Array[float] = []
		for light_variant in engine_lights:
			var engine_light := light_variant as OmniLight3D
			nominal_engine_energies.append(
				engine_light.light_energy if engine_light != null else 0.0
			)
		_check(
			bool(activated.get("accepted", false))
				and weapon_sparks != null
				and not weapon_sparks.emitting
				and sensor_light != null
				and is_zero_approx(sensor_light.light_energy)
				and engine_lights.size() == 2
				and engine_glows.size() == 2,
			"%s activation starts with clean localized component presentation" % archetype_id
		)
		var presentation_sequence := 1000 + archetype_index
		opponent.apply_damage(
			opponent.get_maximum_health() * 0.4,
			opponent.global_position,
			presentation_sequence,
			true
		)
		_check(
			not weapon_sparks.emitting
				and is_zero_approx(sensor_light.light_energy)
				and opponent.commit_deferred_damage_presentation(presentation_sequence),
			"%s local component effects remain receipt-timed" % archetype_id
		)
		opponent.call("_update_presentation", 0.1)
		var muzzle := opponent.call("_get_firing_muzzle") as Node3D
		_check(
			weapon_sparks.emitting
				and muzzle != null
				and weapon_sparks.global_position.is_equal_approx(muzzle.global_position),
			"%s weapon degradation sparks at its real archetype muzzle" % archetype_id
		)
		var sensor_anchor := opponent.find_child(
			String(sensor_anchor_name), true, false
		) as Node3D
		_check(
			sensor_light.light_energy > 0.0
				and sensor_anchor != null
				and sensor_light.global_position.is_equal_approx(sensor_anchor.global_position),
			"%s sensor degradation lights its authored sensor/mast location" % archetype_id
		)
		var engine_state := _component_state(opponent, &"engine")
		var all_propulsion_mounts_dimmed := engine_lights.size() == nominal_engine_energies.size()
		for engine_index in engine_lights.size():
			var engine_light := engine_lights[engine_index] as OmniLight3D
			all_propulsion_mounts_dimmed = all_propulsion_mounts_dimmed \
				and engine_light != null \
				and engine_light.light_energy > 0.0 \
				and engine_light.light_energy < nominal_engine_energies[engine_index]
		_check(
			(engine_state.get("stage", {}) as Dictionary).get("stage_id", &"") == &"damaged"
				and all_propulsion_mounts_dimmed,
			"%s engine degradation dims both authored propulsion mounts" % archetype_id
		)
		opponent.apply_damage(
			opponent.get_maximum_health() * 0.3,
			opponent.global_position
		)
		opponent.call("_update_presentation", 0.1)
		var engine_smoke := opponent.get("_damage_smoke") as CPUParticles3D
		var port_engine := engine_glows[0] as MeshInstance3D
		engine_state = _component_state(opponent, &"engine")
		_check(
			(engine_state.get("stage", {}) as Dictionary).get("stage_id", &"") == &"critical"
				and engine_smoke != null
				and engine_smoke.emitting
				and port_engine != null
				and engine_smoke.global_position.distance_to(port_engine.global_position) < 1.2,
			"%s critical engine stage reuses smoke at the authored port propulsion mount" % archetype_id
		)
		opponent.apply_damage(opponent.get_health(), opponent.global_position)
		var propulsion_presentation_cleared := not engine_smoke.emitting
		for light_variant in engine_lights:
			var engine_light := light_variant as OmniLight3D
			propulsion_presentation_cleared = propulsion_presentation_cleared \
				and engine_light != null \
				and is_zero_approx(engine_light.light_energy)
		_check(
			not opponent.is_active()
				and not weapon_sparks.emitting
				and is_zero_approx(sensor_light.light_energy)
				and propulsion_presentation_cleared
				and opponent.get_destruction_effect_root() != null
				and not (opponent.get("_debris") as Dictionary).is_empty()
				and not (opponent.get("_transient_effects") as Dictionary).is_empty(),
			"%s destruction clears localized component presentation" % archetype_id
		)
		var destroyed_generation := int(
			(opponent.get_component_damage_snapshot().get("model", {}) as Dictionary).get(
				"generation", -1
			)
		)
		var reused := opponent.activate_with_result(opponent.global_transform)
		var weapon_state := _component_state(opponent, &"weapon")
		var sensor_state := _component_state(opponent, &"sensor")
		var recovery := opponent.get_component_recovery_report()
		_check(
			bool(reused.get("accepted", false))
				and bool((reused.get("recovery", {}) as Dictionary).get("valid", false))
				and bool(recovery.get("valid", false))
				and int(recovery.get("model_generation", -1)) == destroyed_generation + 1
				and not weapon_sparks.emitting
				and (weapon_state.get("stage", {}) as Dictionary).get("stage_id", &"") == &"nominal"
				and is_zero_approx(sensor_light.light_energy)
				and (sensor_state.get("stage", {}) as Dictionary).get("stage_id", &"") == &"nominal"
				and opponent.get_destruction_effect_root() == null
				and (opponent.get("_debris") as Dictionary).is_empty()
				and (opponent.get("_transient_effects") as Dictionary).is_empty(),
			"%s authoritative reuse restores components and leaves no VFX/debris/engine residue" % archetype_id
		)

		# Structured red: live emitter drift must be visible in the detached
		# recovery report, then return green once the mutation is restored.
		engine_smoke.emitting = true
		var red_recovery := opponent.get_component_recovery_report()
		_check(
			not bool(red_recovery.get("valid", true))
				and (red_recovery.get("errors", PackedStringArray()) as PackedStringArray).has(
					"engine_smoke_emitting"
				),
			"%s structured-red smoke mutation fails the recovery contract" % archetype_id
		)
		opponent.call("_restart_particles_cleared", engine_smoke)
		_check(
			bool(opponent.get_component_recovery_report().get("valid", false)),
			"%s recovery contract returns green after the mutation is restored" % archetype_id
		)

		# Presentation records carry both the model generation/sequence and the
		# owner activation generation. Corrupting the private generation is a
		# bounded red-path probe: commit rejects without spawning impact residue.
		var fenced_receipt := 2000 + archetype_index
		opponent.apply_damage(1.0, opponent.global_position, fenced_receipt, true)
		var pending := opponent.get("_pending_damage_presentations") as Dictionary
		var corrupted := (pending.get(fenced_receipt, {}) as Dictionary).duplicate(true)
		corrupted["damage_generation"] = destroyed_generation
		pending[fenced_receipt] = corrupted
		opponent.set("_pending_damage_presentations", pending)
		_check(
			not opponent.commit_deferred_damage_presentation(fenced_receipt)
				and (opponent.get("_transient_effects") as Dictionary).is_empty()
				and opponent.get_pending_damage_presentation_count() == 0,
			"%s stale-generation receipt rejects before presentation mutation" % archetype_id
		)
		var sequence_receipt := 3000 + archetype_index
		opponent.apply_damage(1.0, opponent.global_position, sequence_receipt, true)
		pending = opponent.get("_pending_damage_presentations") as Dictionary
		corrupted = (pending.get(sequence_receipt, {}) as Dictionary).duplicate(true)
		corrupted["sequence"] = sequence_receipt + 1
		pending[sequence_receipt] = corrupted
		opponent.set("_pending_damage_presentations", pending)
		_check(
			not opponent.commit_deferred_damage_presentation(sequence_receipt)
				and (opponent.get("_transient_effects") as Dictionary).is_empty()
				and opponent.get_pending_damage_presentation_count() == 0,
			"%s mismatched sequence receipt rejects before presentation mutation" % archetype_id
		)
		var fence_reset := opponent.activate_with_result(opponent.global_transform)
		_check(
			bool(fence_reset.get("accepted", false))
				and bool(opponent.get_component_recovery_report().get("valid", false)),
			"%s generation-fence probes finish on a clean reusable opponent" % archetype_id
		)
		opponent.queue_free()
		await process_frame
	host.queue_free()
	await process_frame


func _test_production_lifecycle() -> void:
	var host := Node3D.new()
	host.name = "RangeOpponentComponentDamageWorld"
	root.add_child(host)
	var opponent := OPPONENT_SCENE.instantiate() as RangeOpponent
	_check(opponent != null, "the production RangeOpponent scene instantiates")
	if opponent == null:
		host.queue_free()
		await process_frame
		return
	opponent.health_changed.connect(_on_health_changed)
	opponent.destroyed.connect(_on_destroyed)
	host.add_child(opponent)
	var lifecycle_proxy := LifecycleAdapterType.new() as LifecycleDamageableAdapter
	lifecycle_proxy.name = "AuthoritativeDamageable"
	lifecycle_proxy.lifecycle_kind = LifecycleDamageableAdapter.LifecycleKind.RANGE_OPPONENT
	lifecycle_proxy.faction_id = &"range_defence"
	lifecycle_proxy.target_entity_path = NodePath("..")
	opponent.add_child(lifecycle_proxy)
	await process_frame
	await physics_frame
	var damage_audio: RefCounted = opponent.get_damage_audio_binding()
	var damage_cues: Array[StringName] = []
	damage_audio.semantic_damage_cue_emitted.connect(func(cue_id: StringName, _intensity: float) -> void: damage_cues.append(cue_id))
	_check(bool(damage_audio.get_snapshot().attached), "RangeOpponent composes its damage audio binding")
	_check(int(damage_audio.get_snapshot().maximum_simultaneous_voices) == 2, "opponent damage audio preserves a two-voice ceiling")

	var dormant := opponent.get_component_damage_snapshot()
	_check(
		not opponent.is_active()
		and opponent.get_health() == 0.0
		and int((dormant.get("model", {}) as Dictionary).get("generation", -1)) == 0,
		"the checked scene remains dormant without starting a damage generation"
	)

	var spawn := Transform3D(Basis(Vector3.UP, 0.3), Vector3(8.0, 3.0, -15.0))
	var activation := opponent.activate_with_result(spawn)
	_check(damage_cues.is_empty(), "activation reset clears stale opponent damage cues")
	var active_snapshot := opponent.get_component_damage_snapshot()
	_check(
		bool(activation.get("accepted", false))
		and opponent.is_active()
		and opponent.collision_layer == SHIP_LAYER | TARGET_LAYER
		and opponent.collision_mask == 1 | SHIP_LAYER
		and is_equal_approx(opponent.get_health(), 85.0)
		and int((active_snapshot.get("model", {}) as Dictionary).get("generation", -1)) == 1
		and _health_events.size() == 1
		and _health_events[0].is_equal_approx(Vector2(85.0, 85.0)),
		"typed activation starts one model generation while preserving health, signal, and collision authority"
	)

	var sparks := opponent.get_node_or_null("DamageSparks") as CPUParticles3D
	var smoke := opponent.get_node_or_null("EngineSmoke") as CPUParticles3D
	var visual := opponent.get_node_or_null("RangeInterceptorVisual") as Node3D
	opponent.apply_damage(34.0, opponent.global_position + Vector3.RIGHT)
	_check(damage_cues == [&"opponent_component_degraded"], "degraded component stage emits one external semantic cue")
	var damaged := _hull_state(opponent)
	_check(
		is_equal_approx(opponent.get_health(), 51.0)
		and (damaged.get("stage", {}) as Dictionary).get("stage_id", &"") == &"damaged"
		and sparks != null and sparks.emitting
		and smoke != null and not smoke.emitting,
		"one immediate hit commits model health and the existing damaged spark threshold once"
	)

	var deferred_hit := opponent.global_position + Vector3.UP
	opponent.apply_damage(25.5, deferred_hit, 700, true)
	var critical := _hull_state(opponent)
	var critical_snapshot := opponent.get_component_damage_snapshot()
	_check(
		is_equal_approx(opponent.get_health(), 25.5)
		and (critical.get("stage", {}) as Dictionary).get("stage_id", &"") == &"critical"
		and int(opponent.get_pending_damage_presentation_count()) == 1
		and not smoke.emitting
		and int((critical_snapshot.get("model", {}) as Dictionary).get("last_damage_sequence", -1)) == 7
		and int(critical_snapshot.get("next_damage_sequence", -1)) == 8,
		"authoritative critical state advances on its private sequence while deferred smoke remains receipt-timed"
	)
	_check(
		opponent.commit_deferred_damage_presentation(700) and smoke.emitting,
		"the unchanged presentation receipt commits the critical smoke cue"
	)
	_check(damage_cues == [&"opponent_component_degraded", &"opponent_component_critical"], "critical component stage emits one deduplicated semantic cue")

	var before_rejections := opponent.get_component_damage_snapshot()
	var health_event_count := _health_events.size()
	var pending_count := opponent.get_pending_damage_presentation_count()
	for invalid_damage in [NAN, INF, -INF, 1.0e-300]:
		opponent.apply_damage(invalid_damage, opponent.global_position)
	_check(
		opponent.get_component_damage_snapshot() == before_rejections
		and _health_events.size() == health_event_count
		and opponent.get_pending_damage_presentation_count() == pending_count,
		"nonfinite and sub-ULP no-effect damage reject atomically without sequence, signal, or presentation mutation"
	)

	var captured_maximum := opponent.maximum_health
	opponent.maximum_health = captured_maximum + 1.0
	var drifted := opponent.get_component_damage_snapshot()
	opponent.apply_damage(1.0, opponent.global_position)
	_check(
		not bool(drifted.get("configuration_current", true))
		and opponent.get_component_damage_snapshot() == drifted
		and _health_events.size() == health_event_count
		and is_equal_approx(lifecycle_proxy.get_maximum_health(), captured_maximum),
		"a live authored-maximum drift fails damage closed while every health reader retains the captured model maximum"
	)
	opponent.deactivate()
	var before_rejected_activation := opponent.get_component_damage_snapshot()
	var rejected_activation := opponent.activate_with_result(spawn.translated(Vector3.RIGHT * 12.0))
	_check(
		not bool(rejected_activation.get("accepted", true))
		and rejected_activation.get("reason", &"") == &"maximum_health_drift"
		and not opponent.is_active()
		and opponent.collision_layer == 0
		and opponent.get_component_damage_snapshot() == before_rejected_activation,
		"typed activation reports maximum-health drift and performs no reset or partial lifecycle activation"
	)
	opponent.maximum_health = captured_maximum
	var second_activation := opponent.activate_with_result(spawn)
	_check(
		bool(second_activation.get("accepted", false))
		and int((opponent.get_component_damage_snapshot().get("model", {}) as Dictionary).get("generation", -1)) == 2
		and is_equal_approx(opponent.get_health(), captured_maximum),
		"restoring the captured definition permits one clean reuse generation"
	)

	# Whole-owner detach drops presentation only. The RefCounted health ledger and
	# its private sequence remain on the same physical opponent instance.
	opponent.apply_damage(4.0, opponent.global_position, 800, true)
	var before_detach := opponent.get_component_damage_snapshot()
	var health_before_detach := opponent.get_health()
	var opponent_id := opponent.get_instance_id()
	host.remove_child(opponent)
	await process_frame
	_check(
		not opponent.commit_deferred_damage_presentation(800)
		and opponent.get_pending_damage_presentation_count() == 0,
		"tree exit invalidates the old receipt without presenting it"
	)
	host.add_child(opponent)
	await process_frame
	_check(
		opponent.get_instance_id() == opponent_id
		and opponent.get_component_damage_snapshot() == before_detach
		and is_equal_approx(opponent.get_health(), health_before_detach),
		"whole-owner re-entry preserves the exact model generation, sequence, revision, and health"
	)

	var cues_before_third := damage_cues.size()
	var third_activation := opponent.activate_with_result(spawn)
	_check(damage_cues.size() == cues_before_third, "reuse generation clears prior opponent damage presentation without emitting stale cues")
	var generation_three := opponent.get_component_damage_snapshot()
	_check(
		bool(third_activation.get("accepted", false))
		and int((generation_three.get("model", {}) as Dictionary).get("generation", -1)) == 3
		and int((generation_three.get("model", {}) as Dictionary).get("last_damage_sequence", -2)) == -1
		and int(generation_three.get("next_damage_sequence", -1)) == 0,
		"explicit reuse alone advances generation and resets only the private model sequence"
	)

	var death_position := opponent.global_position
	opponent.apply_damage(captured_maximum, death_position, 900, true)
	var destroyed := _hull_state(opponent)
	var destroyed_stage := destroyed.get("stage", {}) as Dictionary
	_check(
		opponent.get_health() == 0.0
		and destroyed_stage.get("stage_id", &"") == &"destroyed"
		and bool(destroyed_stage.get("disabled", false))
		and float(destroyed_stage.get("performance_multiplier", -1.0)) == 0.0
		and not opponent.is_active()
		and opponent.collision_layer == 0 and opponent.collision_mask == 0
		and _destroyed_positions.size() == 1
		and _destroyed_positions[0].is_equal_approx(death_position)
		and visual != null and visual.visible
		and opponent.get_destruction_effect_root() == null,
		"lethal model damage leaves collision/destruction authority immediate and VFX deferred exactly once"
	)
	_check(
		opponent.commit_deferred_damage_presentation(900)
		and not visual.visible
		and opponent.get_destruction_effect_root() != null
		and not opponent.commit_deferred_damage_presentation(900),
		"the terminal receipt alone commits one existing destruction presentation and cannot replay"
	)

	host.queue_free()
	await process_frame
	await process_frame


func _hull_state(opponent: RangeOpponent) -> Dictionary:
	return _component_state(opponent, &"hull")


func _component_state(opponent: RangeOpponent, component_id: StringName) -> Dictionary:
	var snapshot := opponent.get_component_damage_snapshot()
	var model := snapshot.get("model", {}) as Dictionary
	for component_variant in model.get("components", []) as Array:
		if not component_variant is Dictionary:
			continue
		var component := component_variant as Dictionary
		if StringName(component.get("component_id", &"")) == component_id:
			return component.duplicate(true)
	return {}


func _on_health_changed(current: float, maximum: float) -> void:
	_health_events.append(Vector2(current, maximum))


func _on_destroyed(position: Vector3) -> void:
	_destroyed_positions.append(position)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("RANGE_OPPONENT_COMPONENT_DAMAGE_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print(
			"RANGE_OPPONENT_COMPONENT_DAMAGE_INTEGRATION_TEST_FAILED: ",
			", ".join(_failures)
		)
		quit(1)
