extends SceneTree

## Focused Phase 6 recovery parity against the five production HeroShip scenes.
## It dirties the shared component model and every generic damage-presentation
## family, then proves one authoritative reuse restores the same physical craft.

const CRAFT_SCENES := {
	"TorrentInterceptor": preload("res://scenes/ships/torrent_interceptor.tscn"),
	"ArrowReconShip": preload("res://scenes/ships/arrow_recon_ship.tscn"),
	"JovianLightFreighter": preload("res://scenes/ships/jovian_light_freighter.tscn"),
	"ZenithInterceptor": preload("res://scenes/ships/zenith_interceptor.tscn"),
	"HalyardCrewTransport": preload("res://scenes/ships/halyard_crew_transport.tscn"),
}

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "HeroComponentRecoveryParityHost"
	root.add_child(host)
	for craft_name: String in CRAFT_SCENES:
		var packed := CRAFT_SCENES[craft_name] as PackedScene
		var craft := packed.instantiate() as HeroShip
		_check(craft != null, "%s production scene instantiates" % craft_name)
		if craft == null:
			continue
		host.add_child(craft)
		await process_frame
		await physics_frame
		await _exercise_craft(craft_name, craft)
		craft.queue_free()
		await process_frame
	host.queue_free()
	await process_frame
	_finish()


func _exercise_craft(craft_name: String, craft: HeroShip) -> void:
	var component := craft.get_component_damage()
	var presentation := craft.get_damage_presentation()
	var initial_model := component.get_ledger_snapshot()
	var initial_generation := int(initial_model.get("generation", 0))
	_check(
		initial_generation > 0
			and presentation.get_presented_component_generation() == initial_generation,
		"%s starts with one model/presentation generation" % craft_name
	)

	# Fail the exact engine, one weapon section, and sensor/core section without
	# applying a second hull loss. These are the existing shared model seams.
	for component_id: StringName in [
		ShipComponentDamage.COMPONENT_ENGINE_BAY,
		ShipComponentDamage.COMPONENT_PORT_WING,
		ShipComponentDamage.COMPONENT_CORE_SYSTEMS,
	]:
		var local_position := _component_local_position(component, component_id)
		var result := component.record_projectile_damage(craft.maximum_hull, local_position)
		_check(bool(result.get("accepted", false)), "%s damages %s" % [craft_name, component_id])
	craft.call(&"_sync_component_damage", 0.0)
	craft.call(&"_sync_engine_visuals_immediately")
	craft.call(&"_sync_weapon_component_presentation")
	var failed_modifiers := craft.get_operational_modifiers()
	_check(
		bool(failed_modifiers.get("mobility_disabled", false))
			and bool(failed_modifiers.get("fire_disabled", false))
			and bool(failed_modifiers.get("targeting_disabled", false))
			and presentation.get_active_component_effect_count() >= 3,
		"%s exposes failed engine, weapon, sensor, and localized component rigs" % craft_name
	)

	# Dirties hull sparks/smoke, a detached impact, terminal debris, plus one
	# delayed receipt that must not cross the reuse generation.
	craft.apply_damage(
		craft.maximum_hull * 0.75,
		craft.global_position,
		Vector3.UP
	)
	var fence := component.get_ledger_snapshot()
	var stale_receipt := 7100 + _assertions
	_check(
		presentation.defer_damage_presentation(
			stale_receipt,
			craft.global_position,
			Vector3.UP,
			1.0,
			false,
			Vector3.ZERO,
			craft.global_transform,
			ShipComponentDamage.COMPONENT_ENGINE_BAY,
			1.0,
			int(fence.get("generation", 0)),
			int(fence.get("last_operation_sequence", -1)),
			int(fence.get("revision", 0))
		),
		"%s queues one generation-fenced old-life receipt" % craft_name
	)
	presentation.present_impact(craft.global_position + Vector3.UP, Vector3.UP, 1.0)
	presentation.present_destruction(Vector3(2.0, 0.0, -1.0), craft.global_transform)
	_check(
		presentation.get_live_world_effect_count() >= 2
			and presentation.get_pending_damage_presentation_count() == 1,
		"%s carries impact, destruction/debris, and delayed presentation residue" % craft_name
	)

	var reset := craft.reset_for_reuse(craft.global_transform)
	var recovery := craft.get_component_recovery_report()
	_check(
		bool(reset.get("accepted", false))
			and bool(recovery.get("valid", false))
			and int(recovery.get("model_generation", 0)) == initial_generation + 1
			and int(recovery.get("presentation_generation", 0)) == initial_generation + 1
			and int(recovery.get("component_sequence", -2)) == -1,
		"%s authoritative reuse restores model and presentation in one new generation" % craft_name
	)
	_check(
		not craft.commit_deferred_damage_presentation(stale_receipt)
			and presentation.get_pending_damage_presentation_count() == 0
			and presentation.get_live_world_effect_count() == 0
			and presentation.get_destruction_effect_root() == null,
		"%s old receipt cannot replay impact or debris after reuse" % craft_name
	)

	# Structured red: a live smoke emitter mutation is visible without mutating
	# the authoritative model, then the presentation-only restoration returns green.
	var smoke := presentation.get_node_or_null("EngineSmoke") as CPUParticles3D
	smoke.emitting = true
	var red := craft.get_component_recovery_report()
	_check(
		not bool(red.get("valid", true))
			and (red.get("errors", PackedStringArray()) as PackedStringArray).has(
				"engine_smoke_emitting"
			),
		"%s structured-red smoke mutation fails recovery audit" % craft_name
	)
	presentation.reset_for_reuse(
		1.0,
		HeroDamagePresentation.STATE_POWERED_DOWN,
		component.get_ledger_generation()
	)
	_check(bool(craft.get_component_recovery_report().get("valid", false)), "%s restored audit is green" % craft_name)

	# Corrupt the private component generation and sequence on fresh records.
	# Commit consumes each record but rejects before transient/semantic mutation.
	var generation_receipt := stale_receipt + 1
	craft.apply_damage(1.0, craft.global_position, Vector3.UP, generation_receipt, true)
	var pending := presentation.get("_pending_damage_presentations") as Dictionary
	var corrupted := (pending.get(generation_receipt, {}) as Dictionary).duplicate(true)
	corrupted["component_generation"] = component.get_ledger_generation() - 1
	pending[generation_receipt] = corrupted
	presentation.set("_pending_damage_presentations", pending)
	_check(
		not craft.commit_deferred_damage_presentation(generation_receipt)
			and presentation.get_pending_damage_presentation_count() == 0
			and presentation.get_live_world_effect_count() == 0,
		"%s stale component generation rejects before presentation mutation" % craft_name
	)
	var fence_reset := craft.reset_for_reuse(craft.global_transform)
	_check(bool(fence_reset.get("accepted", false)), "%s generation-fence reset commits" % craft_name)

	var fenced_receipt := stale_receipt + 2
	craft.apply_damage(1.0, craft.global_position, Vector3.UP, fenced_receipt, true)
	pending = presentation.get("_pending_damage_presentations") as Dictionary
	corrupted = (pending.get(fenced_receipt, {}) as Dictionary).duplicate(true)
	corrupted["component_sequence"] = int(
		component.get_ledger_snapshot().get("last_operation_sequence", -1)
	) + 1
	pending[fenced_receipt] = corrupted
	presentation.set("_pending_damage_presentations", pending)
	_check(
		not craft.commit_deferred_damage_presentation(fenced_receipt)
			and presentation.get_pending_damage_presentation_count() == 0
			and presentation.get_live_world_effect_count() == 0,
		"%s future component sequence rejects before presentation mutation" % craft_name
	)
	var final_reset := craft.reset_for_reuse(craft.global_transform)
	_check(
		bool(final_reset.get("accepted", false))
			and bool(craft.get_component_recovery_report().get("valid", false)),
		"%s sequence-fence probe finishes on a clean reusable craft" % craft_name
	)


func _component_local_position(component: ShipComponentDamage, component_id: StringName) -> Vector3:
	for state: Dictionary in component.get_component_states():
		if StringName(state.get("id", &"")) == component_id:
			return state.get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("HERO_COMPONENT_RECOVERY_PARITY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("HERO_COMPONENT_RECOVERY_PARITY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
