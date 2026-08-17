extends SceneTree

const AdapterType := preload(
	"res://scripts/combat/range_opponent_component_damage_adapter.gd"
)
const LifecycleAdapterType := preload(
	"res://scripts/combat/lifecycle_damageable_adapter.gd"
)
const OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")
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
	await _test_production_lifecycle()
	_finish()


func _test_detached_adapter_contract() -> void:
	var adapter := AdapterType.new(85.0) as RangeOpponentComponentDamageAdapter
	var dormant := adapter.get_snapshot()
	var definition := dormant.get("definition", {}) as Dictionary
	var components := definition.get("components", []) as Array
	var stages := (
		(components[0] as Dictionary).get("damage_stages", []) as Array
		if components.size() == 1
		else []
	)
	_check(
		adapter != null
		and adapter.is_configuration_valid()
		and is_equal_approx(adapter.get_maximum_health(), 85.0)
		and int((dormant.get("model", {}) as Dictionary).get("generation", -1)) == 0
		and adapter.get_health() == 0.0,
		"the production adapter captures one valid dormant 85-health hull model"
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
		components.size() == 1
		and (components[0] as Dictionary).get("component_id", &"") == &"hull"
		and stages_exact,
		"the sole hull component freezes the exact nominal/damaged/critical/destroyed data stages"
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

	var dormant := opponent.get_component_damage_snapshot()
	_check(
		not opponent.is_active()
		and opponent.get_health() == 0.0
		and int((dormant.get("model", {}) as Dictionary).get("generation", -1)) == 0,
		"the checked scene remains dormant without starting a damage generation"
	)

	var spawn := Transform3D(Basis(Vector3.UP, 0.3), Vector3(8.0, 3.0, -15.0))
	var activation := opponent.activate_with_result(spawn)
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
		and int((critical_snapshot.get("model", {}) as Dictionary).get("last_damage_sequence", -1)) == 1
		and int(critical_snapshot.get("next_damage_sequence", -1)) == 2,
		"authoritative critical state advances on its private sequence while deferred smoke remains receipt-timed"
	)
	_check(
		opponent.commit_deferred_damage_presentation(700) and smoke.emitting,
		"the unchanged presentation receipt commits the critical smoke cue"
	)

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

	var third_activation := opponent.activate_with_result(spawn)
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
	var snapshot := opponent.get_component_damage_snapshot()
	var model := snapshot.get("model", {}) as Dictionary
	var components := model.get("components", []) as Array
	return (components[0] as Dictionary).duplicate(true) if components.size() == 1 else {}


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
