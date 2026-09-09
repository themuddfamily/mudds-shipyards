extends SceneTree

## Focused presentation regression: authoritative health remains an input while
## persistent hull and engine distress gain a continuous visible severity read.

const HeroDamagePresentationType := preload(
	"res://scripts/effects/hero_damage_presentation.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var presentation := HeroDamagePresentationType.new() as HeroDamagePresentation
	host.add_child(presentation)

	var hull_sparks := presentation.get_node("DamageSparks") as CPUParticles3D
	var engine_sparks := presentation.get_node("EngineFailureSparks") as CPUParticles3D
	var engine_smoke := presentation.get_node("EngineSmoke") as CPUParticles3D

	presentation.update_state(0.68, HeroDamagePresentation.STATE_ACTIVE)
	var damaged_amount := hull_sparks.amount
	var damaged_speed := hull_sparks.initial_velocity_max
	_check(
		damaged_amount == HeroDamagePresentation.HULL_SPARK_DAMAGED_AMOUNT
		and hull_sparks.emitting
		and not engine_smoke.emitting,
		"damaged boundary begins with the restrained hull-spark grade"
	)

	presentation.update_state(0.50, HeroDamagePresentation.STATE_ACTIVE)
	_check(
		hull_sparks.amount > damaged_amount
		and hull_sparks.amount < HeroDamagePresentation.HULL_SPARK_CRITICAL_AMOUNT
		and hull_sparks.initial_velocity_max > damaged_speed,
		"worsening resolved hull health visibly increases spark density and speed"
	)

	presentation.update_state(0.32, HeroDamagePresentation.STATE_ACTIVE)
	var critical_engine_amount := engine_sparks.amount
	var critical_smoke_amount := engine_smoke.amount
	var critical_smoke_lifetime := engine_smoke.lifetime
	_check(
		hull_sparks.amount == HeroDamagePresentation.HULL_SPARK_CRITICAL_AMOUNT
		and critical_engine_amount == HeroDamagePresentation.ENGINE_SPARK_CRITICAL_AMOUNT
		and critical_smoke_amount == HeroDamagePresentation.ENGINE_SMOKE_CRITICAL_AMOUNT
		and engine_sparks.emitting
		and engine_smoke.emitting,
		"critical boundary combines the maximum hull grade with initial engine distress"
	)

	presentation.update_state(0.08, HeroDamagePresentation.STATE_ACTIVE)
	_check(
		engine_sparks.amount > critical_engine_amount
		and engine_smoke.amount > critical_smoke_amount
		and engine_smoke.lifetime > critical_smoke_lifetime
		and engine_smoke.scale_amount_max > 1.45,
		"near-terminal resolved health produces denser, larger, longer engine venting"
	)
	_check(
		presentation.get_damage_stage() == HeroDamagePresentation.DamageStage.CRITICAL,
		"severity presentation does not invent a new authoritative damage stage"
	)

	await _test_continuous_particles_survive_same_state(presentation)

	host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HERO_DAMAGE_SEVERITY_VISUAL_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)


func _test_continuous_particles_survive_same_state(presentation: HeroDamagePresentation) -> void:
	# The native amount setter clears every active particle even when the count
	# is unchanged. A continuous burst must not report finished while its live
	# particles are still younger than their authored minimum lifetime.
	var emitters: Array[CPUParticles3D] = [
		presentation.get_node("DamageSparks"),
		presentation.get_node("EngineFailureSparks"),
		presentation.get_node("EngineSmoke"),
	]
	var finished_counts := [0, 0, 0]
	presentation.update_state(0.08, HeroDamagePresentation.STATE_ACTIVE)
	for index in emitters.size():
		var emitter := emitters[index]
		emitter.use_fixed_seed = true
		emitter.seed = 4701 + index
		emitter.finished.connect(func() -> void: finished_counts[index] += 1)
		emitter.restart(true)
	for frame in 3:
		await physics_frame
	for frame in 12:
		presentation.update_state(0.08, HeroDamagePresentation.STATE_ACTIVE)
		await physics_frame
	for index in emitters.size():
		_check(finished_counts[index] == 0 and emitters[index].emitting,
			"%s keeps its live continuous burst through repeated identical severity updates" % emitters[index].name)
	print("RETAINED_PARTICLE_CONTINUITY: premature_finished=", finished_counts)
	presentation.reset_for_reuse(1.0, HeroDamagePresentation.STATE_POWERED_DOWN)
	_check(not emitters[0].emitting and not emitters[1].emitting and not emitters[2].emitting
		and emitters[0].amount == HeroDamagePresentation.HULL_SPARK_DAMAGED_AMOUNT
		and emitters[1].amount == HeroDamagePresentation.ENGINE_SPARK_CRITICAL_AMOUNT
		and emitters[2].amount == HeroDamagePresentation.ENGINE_SMOKE_CRITICAL_AMOUNT,
		"reuse restores nominal particle counts and stops the same retained emitters")
	presentation.update_state(0.32, HeroDamagePresentation.STATE_ACTIVE)
	_check(emitters[0].emitting and emitters[1].emitting and emitters[2].emitting
		and emitters[0].amount == HeroDamagePresentation.HULL_SPARK_CRITICAL_AMOUNT,
		"a real severity transition after reuse still changes counts and resumes all channels")
