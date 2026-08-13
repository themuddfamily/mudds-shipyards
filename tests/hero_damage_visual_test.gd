extends SceneTree

const DAMAGE_PRESENTATION_SCENE := "res://scenes/effects/hero_damage_presentation.tscn"

var _failures: Array[String] = []
var _stage_events: Array[Vector2] = []
var _status_events: Array[StringName] = []
var _alarm_events: Array[Vector2] = []
var _engine_events: Array[Vector2] = []
var _destruction_events: Array[Dictionary] = []
var _clear_events := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	var host := Node3D.new()
	host.name = "HeroDamageVisualTestWorld"
	root.add_child(host)
	var transformed_ship := Node3D.new()
	transformed_ship.name = "TransformedShipFixture"
	transformed_ship.transform = Transform3D(
		Basis(Vector3.UP, 0.47).scaled(Vector3(1.35, 0.82, 1.14)),
		Vector3(12.0, 7.0, -19.0)
	)
	host.add_child(transformed_ship)

	var packed := load(DAMAGE_PRESENTATION_SCENE) as PackedScene
	if packed == null:
		_fail("hero damage presentation scene loads")
		await _clean_up(host)
		_finish()
		return
	var presentation := packed.instantiate() as Node3D
	if presentation == null:
		_fail("hero damage presentation instantiates as Node3D")
		await _clean_up(host)
		_finish()
		return

	presentation.set("impact_effect_lifetime", 0.08)
	presentation.set("destruction_effect_lifetime", 0.18)
	presentation.set("destruction_debris_count", 7)
	presentation.connect(&"stage_changed", Callable(self, "_on_stage_changed"))
	presentation.connect(&"status_changed", Callable(self, "_on_status_changed"))
	presentation.connect(&"alarm_changed", Callable(self, "_on_alarm_changed"))
	presentation.connect(&"engine_failure_changed", Callable(self, "_on_engine_failure_changed"))
	presentation.connect(&"destruction_started", Callable(self, "_on_destruction_started"))
	presentation.connect(&"effects_cleared", Callable(self, "_on_effects_cleared"))
	transformed_ship.add_child(presentation)
	await process_frame

	var damage_sparks := presentation.get_node_or_null("DamageSparks") as CPUParticles3D
	var failure_sparks := presentation.get_node_or_null("EngineFailureSparks") as CPUParticles3D
	var engine_smoke := presentation.get_node_or_null("EngineSmoke") as CPUParticles3D
	var warning_light := presentation.get_node_or_null("DamageWarningLight") as OmniLight3D
	var failure_light := presentation.get_node_or_null("EngineFailureLight") as OmniLight3D
	_check(damage_sparks != null, "component builds persistent damage sparks")
	_check(failure_sparks != null, "component builds engine-failure sparks")
	_check(engine_smoke != null, "component builds persistent engine smoke")
	_check(warning_light != null and failure_light != null, "component builds warning and engine-failure light cues")
	_check(int(presentation.call("get_damage_stage")) == 0, "presentation begins healthy")
	_check(not damage_sparks.emitting and not engine_smoke.emitting, "healthy presentation has no damage particles")

	# Exact threshold values enter the damaged and critical stages immediately.
	presentation.call("update_state", 0.68, &"active", Vector3(4.0, 1.0, -7.0))
	_check(int(presentation.call("get_damage_stage")) == 1, "damaged threshold is inclusive")
	_check(StringName(presentation.call("get_status")) == &"damaged", "damaged stage exposes a stable status label")
	_check(damage_sparks.emitting, "damaged stage emits persistent sparks")
	_check(not engine_smoke.emitting and not failure_sparks.emitting, "damaged stage does not show critical engine cues early")
	_check(bool(presentation.call("is_alarm_active")), "an active damaged ship requests a warning alarm")
	_check(not bool(presentation.call("is_engine_failure_active")), "damaged stage retains normal engine behavior")

	var impact_position := Vector3(-5.0, 13.0, 21.0)
	presentation.call("present_impact", impact_position, Vector3.RIGHT, 1.25)
	_check(int(presentation.call("get_live_world_effect_count")) == 1, "impact creates one tracked world-space transient")

	var critical_velocity := Vector3(18.0, -2.0, 41.0)
	presentation.call("update_state", 0.32, &"active", critical_velocity)
	_check(int(presentation.call("get_damage_stage")) == 2, "critical threshold is inclusive")
	_check(StringName(presentation.call("get_status")) == &"critical", "critical stage exposes a stable status label")
	_check(damage_sparks.emitting and failure_sparks.emitting, "critical stage combines hull and engine sparks")
	_check(engine_smoke.emitting, "critical stage emits persistent engine smoke")
	_check(bool(presentation.call("is_alarm_active")), "critical stage keeps the alarm active")
	_check(bool(presentation.call("is_engine_failure_active")), "critical stage raises an engine-failure cue")
	_check((presentation.call("get_last_world_velocity") as Vector3).is_equal_approx(critical_velocity), "component retains authoritative world velocity")
	await process_frame
	_check(float(presentation.call("get_engine_power_multiplier")) < 0.9, "critical engine cue produces a readable power stutter")
	_check(warning_light.light_energy > 0.0 and failure_light.light_energy > 0.0, "critical alarm and failed-engine lights animate headlessly")
	var engine_events_before_repeat := _engine_events.size()
	var stutter_before_repeat := float(presentation.call("get_engine_power_multiplier"))
	critical_velocity = Vector3(21.0, -1.5, 39.0)
	presentation.call("update_state", 0.32, &"active", critical_velocity)
	_check(_engine_events.size() == engine_events_before_repeat, "repeated authoritative updates do not spam engine-failure signals")
	_check(is_equal_approx(float(presentation.call("get_engine_power_multiplier")), stutter_before_repeat), "repeated updates preserve the live engine stutter")
	_check((presentation.call("get_last_world_velocity") as Vector3).is_equal_approx(critical_velocity), "repeated updates refresh destruction inheritance velocity")

	# Powered-down craft continue to show physical damage without powered alarms.
	presentation.call("set_ship_state", &"powered_down", critical_velocity)
	_check(engine_smoke.emitting and damage_sparks.emitting, "powered-down craft retain visible physical damage")
	_check(not bool(presentation.call("is_alarm_active")), "powered-down state silences the warning alarm")
	_check(not bool(presentation.call("is_engine_failure_active")), "powered-down state disables the running-engine failure cue")
	presentation.call("set_ship_state", &"active", critical_velocity)
	_check(bool(presentation.call("is_alarm_active")) and bool(presentation.call("is_engine_failure_active")), "reactivating a critical craft restores its cues")

	# Terminal presentation occurs once and is detached from the transformed ship.
	var expected_destruction_position := presentation.global_position
	presentation.call("present_destruction", critical_velocity)
	var destruction_root := presentation.call("get_destruction_effect_root") as Node3D
	_check(int(presentation.call("get_damage_stage")) == 3, "lethal presentation enters the destroyed stage")
	_check(StringName(presentation.call("get_status")) == &"destroyed", "destroyed stage exposes a stable status label")
	_check(destruction_root != null and destruction_root.is_inside_tree(), "destruction creates a detached world effect root")
	_check(destruction_root != null and not transformed_ship.is_ancestor_of(destruction_root), "destruction effects are independent of the ship transform")
	_check(destruction_root != null and destruction_root.global_position.is_equal_approx(expected_destruction_position), "destruction begins at the ship's exact world position")
	_check(destruction_root != null and destruction_root.get_node_or_null("ExplosionSparks") != null, "lethal stage creates explosion sparks")
	_check(destruction_root != null and destruction_root.get_node_or_null("ExplosionSmoke") != null, "lethal stage creates explosion smoke")
	_check(destruction_root != null and destruction_root.get_node_or_null("ExplosionFlash") != null, "lethal stage creates a flash")
	_check(destruction_root != null and destruction_root.get_node_or_null("ExplosionShockwave") != null, "lethal stage creates a shockwave")
	_check(_count_debris(destruction_root) == 7, "lethal stage creates the configured physical debris count")
	_check(not damage_sparks.emitting and not engine_smoke.emitting, "lethal stage stops persistent ship-local emitters")
	_check(_destruction_events.size() == 1, "lethal stage reports destruction once")
	if not _destruction_events.is_empty():
		var event_position: Vector3 = _destruction_events[0].get("position", Vector3.ZERO)
		var event_velocity: Vector3 = _destruction_events[0].get("velocity", Vector3.ZERO)
		_check(event_position.is_equal_approx(expected_destruction_position), "destruction signal reports the exact world position")
		_check(event_velocity.is_equal_approx(critical_velocity), "destruction signal reports inherited world velocity")

	transformed_ship.position += Vector3(80.0, -15.0, 24.0)
	await process_frame
	_check(destruction_root != null and destruction_root.global_position.is_equal_approx(expected_destruction_position), "ship motion cannot drag detached destruction effects")
	presentation.call("present_destruction", Vector3.ONE * 99.0)
	presentation.call("update_state", 1.0, &"active", Vector3.ZERO)
	_check(_destruction_events.size() == 1, "destroyed presentation ignores duplicate lethal and ordinary updates")

	# Explicit reuse synchronously clears every detached effect and restores cues.
	var clear_events_before_reset := _clear_events
	presentation.call("reset_for_reuse", 1.0, &"powered_down")
	_check(int(presentation.call("get_damage_stage")) == 0, "reset returns the component to healthy")
	_check(StringName(presentation.call("get_ship_state")) == &"powered_down", "reset accepts the respawn operating state")
	_check(int(presentation.call("get_live_world_effect_count")) == 0, "reset clears impact and destruction world effects synchronously")
	_check(presentation.call("get_destruction_effect_root") == null, "reset drops the destruction effect reference")
	_check(not destruction_root.is_inside_tree(), "reset detaches the old lethal effect root")
	_check(not damage_sparks.emitting and not failure_sparks.emitting and not engine_smoke.emitting, "reset clears every local damage emitter")
	_check(not bool(presentation.call("is_alarm_active")) and not bool(presentation.call("is_engine_failure_active")), "reset clears alarm and engine-failure state")
	_check(_clear_events == clear_events_before_reset + 1, "reset reports completed effect cleanup")

	# A reused component can be destroyed again and automatically expires cleanly.
	presentation.call("update_state", 0.0, &"active", Vector3(-3.0, 2.0, 9.0))
	_check(_destruction_events.size() == 2, "reset makes the lethal presentation reusable")
	var second_root := presentation.call("get_destruction_effect_root") as Node3D
	_check(second_root != null and second_root.is_inside_tree(), "reused component creates a fresh destruction root")
	# Real-time margin avoids coupling cleanup coverage to a renderer's frame rate.
	await create_timer(0.35).timeout
	await process_frame
	_check(int(presentation.call("get_live_world_effect_count")) == 0, "lethal effects expire without timers or orphan nodes")
	_check(not is_instance_valid(second_root) or not second_root.is_inside_tree(), "automatic expiry detaches the second effect root")

	# Explicit disposal is idempotent and owner teardown leaves no root siblings.
	presentation.call("dispose_effects")
	presentation.call("dispose_effects")
	_check(int(presentation.call("get_live_world_effect_count")) == 0, "effect disposal is idempotent")
	await _clean_up(host)
	_check(root.get_child_count() == original_root_child_count, "hero damage fixture cleans up all scene nodes")
	_check(_stage_events.has(Vector2(1.0, 0.68)) and _stage_events.has(Vector2(2.0, 0.32)), "stage signals cover damaged and critical thresholds")
	_check(_status_events.has(&"damaged") and _status_events.has(&"critical") and _status_events.has(&"destroyed"), "status signals cover every non-healthy state")
	_check(not _alarm_events.is_empty() and not _engine_events.is_empty(), "alarm and engine-failure contracts emit deterministic events")
	_finish()


func _count_debris(effect_root: Node3D) -> int:
	if not is_instance_valid(effect_root):
		return 0
	var count := 0
	for child in effect_root.get_children():
		if String(child.name).begins_with("HeroHullDebris"):
			count += 1
	return count


func _clean_up(host: Node) -> void:
	if is_instance_valid(host):
		host.queue_free()
	for _frame in 4:
		await process_frame


func _on_stage_changed(stage: int, health_ratio: float) -> void:
	_stage_events.append(Vector2(float(stage), health_ratio))


func _on_status_changed(status: StringName, _health_ratio: float) -> void:
	_status_events.append(status)


func _on_alarm_changed(active: bool, urgency: float) -> void:
	_alarm_events.append(Vector2(1.0 if active else 0.0, urgency))


func _on_engine_failure_changed(active: bool, power_multiplier: float) -> void:
	_engine_events.append(Vector2(1.0 if active else 0.0, power_multiplier))


func _on_destruction_started(world_position: Vector3, inherited_velocity: Vector3) -> void:
	_destruction_events.append({
		"position": world_position,
		"velocity": inherited_velocity,
	})


func _on_effects_cleared() -> void:
	_clear_events += 1


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("HERO_DAMAGE_VISUAL_TEST_OK")
		quit(0)
	else:
		print("HERO_DAMAGE_VISUAL_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
