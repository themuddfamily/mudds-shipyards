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
