extends SceneTree

## Coverage audit for the roadmap's "extend the hero/enemy impact, staged
## sparks/smoke, engine degradation, destruction, debris, and failure
## presentations into consistent coverage" item.
##
## The point of this suite is *consistency*, not richness. A new opponent that
## fights well and then dies with nothing on screen is worse than no new
## opponent at all, and the way that happens is never a decision — it is an
## archetype that inherited a hull builder, populated some of the presentation
## seams its base class drives, and quietly left the rest empty. So every
## archetype is walked through the same six categories and measured the same
## way, and the hero's own presentation is measured against the same six so the
## word "consistent" means something across the seam:
##
##   1. **Impact.** A non-lethal hit produces a world-space spark burst.
##   2. **Staged sparks.** Sparks begin emitting at the damaged threshold.
##   3. **Staged smoke.** Smoke begins emitting at the critical threshold.
##   4. **Engine degradation.** Engine output at critical hull is measurably
##      below engine output at full hull.
##   5. **Destruction and debris.** A lethal hit produces a detached world-owned
##      effect root carrying a burst, smoke, a flash light, and real debris
##      bodies — and that root is cleaned up afterwards rather than leaked.
##   6. **Failure presentation.** The hull itself stops being drawn.
##
## ### Why nothing here samples an oscillator
##
## `HeroDamagePresentation`'s `DamageWarningLight` and `EngineFailureLight`
## drive their energies from `sin(elapsed * 13)` and
## `sin(elapsed * 29) + sin(elapsed * 61)` of accumulated presentation time.
## Any single-frame capture of those values is phase-dependent, and gating on
## one was the root cause of a long-standing flaky gate. Every measurement below
## is therefore taken from a **latch or a stage**, never from a sampled energy:
## `emitting` booleans, `get_damage_stage()`, `is_engine_failure_active()`,
## node counts, and visibility. The one continuous quantity that is compared —
## engine glow — is compared between two states of the *same* craft with its
## presentation clock pinned to the same value, so the sine term is identical on
## both sides of the comparison and cancels.

const DEFENDER_SCENE := preload("res://scenes/ships/range_opponent.tscn")
const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")
const COURIER_SCENE := preload("res://scenes/ships/courier_runner_opponent.tscn")
const HERO_PRESENTATION_SCENE := "res://scenes/effects/hero_damage_presentation.tscn"

## The inherited staging thresholds, as authored in `RangeOpponent`.
const SPARK_THRESHOLD := 0.67
const SMOKE_THRESHOLD := 0.34
const MINIMUM_DEBRIS_BODIES := 4

var _failures: Array[String] = []
var _assertion_count := 0
var _coverage: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_children := root.get_child_count()
	await _audit_derived_weapon_telegraphs()
	for entry in [
		{"id": &"range_defender", "scene": DEFENDER_SCENE},
		{"id": &"standoff_picket", "scene": PICKET_SCENE},
		{"id": &"wing_skirmisher", "scene": SKIRMISHER_SCENE},
		{"id": &"contract_courier", "scene": COURIER_SCENE},
	]:
		await _audit_opponent(entry["id"], entry["scene"])
	await _audit_hero_presentation()
	for line in _coverage:
		print(line)
	_check(
		root.get_child_count() == original_children,
		"every presentation coverage fixture cleans up without leaving scene nodes"
	)
	_finish()


# ------------------------------------------------------------ opponents ----

func _audit_derived_weapon_telegraphs() -> void:
	var host := Node3D.new()
	host.name = "DerivedWeaponTelegraphWorld"
	root.add_child(host)
	var picket_target := Node3D.new()
	picket_target.name = "PicketTelegraphTarget"
	picket_target.position = Vector3(0.0, 0.0, -100.0)
	host.add_child(picket_target)
	var courier_target := Node3D.new()
	courier_target.name = "CourierTelegraphTarget"
	courier_target.position = Vector3(0.0, 0.0, 60.0)
	host.add_child(courier_target)
	var skirmisher_target := Node3D.new()
	skirmisher_target.name = "SkirmisherTelegraphTarget"
	skirmisher_target.position = Vector3(0.0, 0.0, -60.0)
	host.add_child(skirmisher_target)
	var picket := PICKET_SCENE.instantiate() as StandoffPicketOpponent
	var courier := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	var skirmisher := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	picket.escort_enabled = false
	for craft in [picket, courier, skirmisher]:
		host.add_child(craft)
	await process_frame
	await physics_frame

	_check(
		picket.telegraph_time > courier.telegraph_time
		and courier.telegraph_time > skirmisher.telegraph_time,
		"derived pre-fire silhouettes follow the authored lance, turret, then repeater cadence"
	)

	var telegraph_nodes := {
		&"picket": [
			picket.get_node("StandoffPicketVisual/LanceEmitter") as MeshInstance3D,
			picket.get_node("StandoffPicketVisual/LanceChargeLens") as MeshInstance3D,
			picket.get_node("StandoffPicketVisual/LanceSpineLens") as MeshInstance3D,
		],
		&"courier": [
			courier.get_node("ContractCourierVisual/TailTurretLens") as MeshInstance3D,
		],
		&"skirmisher": [
			skirmisher.get_node("WingSkirmisherVisual/RepeaterLens") as MeshInstance3D,
		],
	}
	var retained_node_ids := _telegraph_node_ids(telegraph_nodes)
	var retained_resource_ids := _telegraph_resource_ids(telegraph_nodes)

	# Enter each real cancellable charge branch without advancing to dispatch.
	picket.activate(Transform3D.IDENTITY)
	picket.set_target(picket_target)
	picket.set("_cooldown_remaining", 0.0)
	picket.call("_update_weapon", picket_target.position, Vector3.FORWARD, 100.0, 0.0)
	picket.call("_update_presentation", 0.0)
	var picket_charge_scales := _telegraph_scales(telegraph_nodes.picket as Array)

	courier.activate(Transform3D.IDENTITY)
	courier.set_target(courier_target)
	courier.set("_cooldown_remaining", 0.0)
	courier.call("_update_weapon", courier_target.position, Vector3.BACK, 60.0, 0.0)
	courier.call("_update_presentation", 0.0)
	var courier_charge_scales := _telegraph_scales(telegraph_nodes.courier as Array)

	skirmisher.activate(Transform3D.IDENTITY)
	skirmisher.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	skirmisher.set_target(skirmisher_target)
	skirmisher.set("_cooldown_remaining", 0.0)
	skirmisher.call("_update_weapon", skirmisher_target.position, Vector3.FORWARD, 60.0, 0.0)
	skirmisher.call("_update_presentation", 0.0)
	var skirmisher_charge_scales := _telegraph_scales(telegraph_nodes.skirmisher as Array)

	var picket_emitter := picket_charge_scales[0] as Vector3
	var picket_lens := picket_charge_scales[1] as Vector3
	var picket_spine := picket_charge_scales[2] as Vector3
	var courier_lens := courier_charge_scales[0] as Vector3
	var repeater_lens := skirmisher_charge_scales[0] as Vector3
	_check(
		picket.get_lance_charge_snapshot().active
		and picket_emitter.y > picket_emitter.x * 2.0
		and is_equal_approx(picket_lens.x, picket_lens.y)
		and picket_lens.x > picket_spine.x,
		"the slow siege lance forms a lengthened emitter with large muzzle focus and small spine witness"
	)
	_check(
		float(courier.get("_telegraph_remaining")) > 0.0
		and courier_lens.x > courier_lens.y * 2.5
		and float(skirmisher.get("_telegraph_remaining")) > 0.0
		and not skirmisher.is_weapon_safed()
		and repeater_lens.y > repeater_lens.x * 2.5,
		"the tail turret presents a broad aperture while the fast repeater presents a narrow vertical tick"
	)
	_check(
		_telegraph_node_ids(telegraph_nodes) == retained_node_ids
		and _telegraph_resource_ids(telegraph_nodes) == retained_resource_ids,
		"all three cadence signatures reuse the exact retained nodes, meshes, and materials"
	)

	# Whole-owner re-entry must retain the warning without restarting its phase.
	var charged_remaining := {
		&"picket": float(picket.get("_telegraph_remaining")),
		&"courier": float(courier.get("_telegraph_remaining")),
		&"skirmisher": float(skirmisher.get("_telegraph_remaining")),
	}
	for craft in [picket, courier, skirmisher]:
		host.remove_child(craft)
		host.add_child(craft)
	await process_frame
	for craft in [picket, courier, skirmisher]:
		craft.call("_update_presentation", 0.0)
	var reentered_picket_scales := _telegraph_scales(telegraph_nodes.picket as Array)
	var reentered_courier_scale := (
		_telegraph_scales(telegraph_nodes.courier as Array)[0] as Vector3
	)
	var reentered_repeater_scale := (
		_telegraph_scales(telegraph_nodes.skirmisher as Array)[0] as Vector3
	)
	var reentered_picket_emitter := reentered_picket_scales[0] as Vector3
	_check(
		float(picket.get("_telegraph_remaining")) > 0.0
		and float(picket.get("_telegraph_remaining")) <= float(charged_remaining.picket)
		and float(courier.get("_telegraph_remaining")) > 0.0
		and float(courier.get("_telegraph_remaining")) <= float(charged_remaining.courier)
		and float(skirmisher.get("_telegraph_remaining")) > 0.0
		and float(skirmisher.get("_telegraph_remaining")) <= float(charged_remaining.skirmisher)
		and reentered_picket_emitter.y > reentered_picket_emitter.x * 2.0
		and reentered_courier_scale.x > reentered_courier_scale.y * 2.5
		and reentered_repeater_scale.y > reentered_repeater_scale.x * 2.5
		and _telegraph_node_ids(telegraph_nodes) == retained_node_ids,
		"same-instance re-entry preserves each static pre-fire silhouette without restarting its charge"
	)

	# Exercise each existing cancel seam, then explicit reuse.
	picket.cancel_lance_charge(&"presentation_fixture")
	courier.call("_update_weapon", courier_target.position, Vector3.FORWARD, 60.0, 0.0)
	skirmisher.assign_wing_role(WingCoordinator.ROLE_UNASSIGNED)
	skirmisher.call("_update_weapon", skirmisher_target.position, Vector3.FORWARD, 60.0, 0.0)
	for craft in [picket, courier, skirmisher]:
		craft.call("_update_presentation", 0.0)
	var cancellation_clear := _derived_telegraphs_are_idle(telegraph_nodes, [
		picket, courier, skirmisher,
	])
	for craft in [picket, courier, skirmisher]:
		craft.deactivate()
		craft.activate(Transform3D.IDENTITY)
		craft.call("_update_presentation", 0.0)
	_check(
		cancellation_clear
		and _derived_telegraphs_are_idle(telegraph_nodes, [picket, courier, skirmisher]),
		"charge cancellation and explicit reuse restore all retained lenses to the nominal idle silhouette"
	)

	await _free_host(host)


func _telegraph_scales(nodes: Array) -> Array[Vector3]:
	var scales: Array[Vector3] = []
	for node_variant in nodes:
		var node := node_variant as MeshInstance3D
		scales.append(node.scale)
	return scales


func _telegraph_node_ids(nodes_by_archetype: Dictionary) -> Dictionary:
	var identities := {}
	for archetype in nodes_by_archetype:
		var node_ids: Array[int] = []
		for node_variant in nodes_by_archetype[archetype] as Array:
			var node := node_variant as MeshInstance3D
			node_ids.append(node.get_instance_id())
		identities[archetype] = node_ids
	return identities


func _telegraph_resource_ids(nodes_by_archetype: Dictionary) -> Dictionary:
	var identities := {}
	for archetype in nodes_by_archetype:
		var resource_ids: Array[int] = []
		for node_variant in nodes_by_archetype[archetype] as Array:
			var node := node_variant as MeshInstance3D
			var material := node.get_active_material(0)
			resource_ids.append(node.mesh.get_instance_id())
			resource_ids.append(material.get_instance_id() if material != null else 0)
		identities[archetype] = resource_ids
	return identities


func _derived_telegraphs_are_idle(nodes_by_archetype: Dictionary, crafts: Array) -> bool:
	for nodes_variant in nodes_by_archetype.values():
		for node_variant in nodes_variant as Array:
			var node := node_variant as MeshInstance3D
			if not node.scale.is_equal_approx(Vector3.ONE * 0.8):
				return false
	for craft_variant in crafts:
		var craft := craft_variant as RangeOpponent
		var warning_light := craft.get("_warning_light") as OmniLight3D
		if warning_light != null and not is_zero_approx(warning_light.light_energy):
			return false
	return true


func _audit_opponent(archetype: StringName, scene: PackedScene) -> void:
	var host := Node3D.new()
	host.name = "PresentationCoverageWorld"
	root.add_child(host)
	var craft := scene.instantiate() as RangeOpponent
	craft.name = "AuditedOpponent"
	if craft is StandoffPicketOpponent:
		(craft as StandoffPicketOpponent).escort_enabled = false
	host.add_child(craft)
	await process_frame
	await physics_frame

	craft.activate(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -300.0)))
	# No target: the craft holds station and its own physics pass cannot move it
	# out from under the measurements below.
	await _advance(2)

	var sparks := craft.get_node_or_null("DamageSparks") as CPUParticles3D
	var smoke := _find_persistent_smoke(craft)
	_check(
		sparks != null and smoke != null,
		"%s mounts both a persistent spark emitter and a persistent smoke emitter"
			% archetype
	)
	if sparks == null or smoke == null:
		await _free_host(host)
		return
	_check(
		not sparks.emitting and not smoke.emitting,
		"%s shows no damage staging at full hull" % archetype
	)

	# 4a. Engine output at full hull, with the presentation clock pinned.
	craft.set("_elapsed", 0.0)
	craft.call("_update_presentation", 0.5)
	var healthy_engine := _engine_output(craft)
	_check(
		healthy_engine > 0.0,
		"%s lights its engines while active (%.3f)" % [archetype, healthy_engine]
	)

	# 1. Impact. A non-lethal hit spawns a world-space spark burst that is
	#    parented outside the craft, so it survives the craft's own motion.
	var world_effects_before := _world_effect_count(craft)
	var hit_position := craft.global_position + Vector3(1.0, 0.5, -2.0)
	craft.apply_damage(craft.maximum_health * 0.4, hit_position)
	await _advance(2)
	_check(
		_world_effect_count(craft) > world_effects_before,
		"%s spawns a world-space impact burst on a non-lethal hit" % archetype
	)

	# 2. Staged sparks at the damaged threshold.
	var ratio_after_first := craft.get_health() / craft.maximum_health
	_check(
		ratio_after_first <= SPARK_THRESHOLD and sparks.emitting,
		"%s begins emitting sparks once its hull drops past the damaged threshold"
			% archetype
	)
	_check(
		not smoke.emitting,
		"%s holds its smoke back until the critical threshold" % archetype
	)

	# 3. Staged smoke at the critical threshold.
	craft.apply_damage(craft.maximum_health * 0.4, hit_position)
	await _advance(2)
	var ratio_after_second := craft.get_health() / craft.maximum_health
	_check(
		ratio_after_second <= SMOKE_THRESHOLD and smoke.emitting and sparks.emitting,
		"%s adds smoke to its sparks once its hull is critical" % archetype
	)

	# 4b. Engine degradation, measured against the same pinned clock.
	craft.set("_elapsed", 0.0)
	craft.call("_update_presentation", 0.5)
	var critical_engine := _engine_output(craft)
	_check(
		critical_engine < healthy_engine,
		"%s visibly loses engine output at critical hull (%.3f -> %.3f)"
			% [archetype, healthy_engine, critical_engine]
	)

	# 5/6. Destruction, debris, and the failure presentation.
	var visual_root := craft.get_node_or_null("%s" % _visual_root_name(craft)) as Node3D
	craft.apply_damage(craft.maximum_health, hit_position)
	await _advance(3)
	var destruction_root := craft.get_destruction_effect_root()
	_check(
		destruction_root != null and destruction_root.get_parent() != craft,
		"%s detaches its destruction effects into the world, not under the dying hull"
			% archetype
	)
	var debris := 0
	var burst := 0
	var destruction_smoke := 0
	var flash := 0
	if destruction_root != null:
		for child in destruction_root.get_children():
			if child is RigidBody3D:
				debris += 1
			elif child is OmniLight3D:
				flash += 1
			elif child is CPUParticles3D:
				if (child as CPUParticles3D).mesh is QuadMesh:
					destruction_smoke += 1
				else:
					burst += 1
	_check(
		debris >= MINIMUM_DEBRIS_BODIES,
		"%s throws at least %d physical debris bodies (%d)"
			% [archetype, MINIMUM_DEBRIS_BODIES, debris]
	)
	_check(
		burst >= 1 and destruction_smoke >= 1 and flash >= 1,
		"%s pairs its debris with a spark burst, a smoke burst, and a flash light"
			% archetype
	)
	_check(
		not craft.is_active() and not sparks.emitting and not smoke.emitting,
		"%s stops its staged damage emitters when it dies" % archetype
	)
	_check(
		visual_root != null and not visual_root.visible,
		"%s stops drawing its hull once destroyed" % archetype
	)
	_coverage.append(
		"OPPONENT_PRESENTATION_COVERAGE: %s impact=yes sparks=yes smoke=yes"
			% archetype
		+ " engine=%.3f->%.3f debris=%d burst=%d smoke_burst=%d flash=%d"
			% [healthy_engine, critical_engine, debris, burst, destruction_smoke, flash]
	)

	# The detached root is world-owned, so a torn-down craft must not leak it.
	await _free_host(host)


func _find_persistent_smoke(craft: RangeOpponent) -> CPUParticles3D:
	# Each archetype names its own persistent smoke emitter after the part of the
	# hull it vents from, so the audit finds it by the field the base class
	# actually drives rather than by a fixed node name.
	return craft.get("_damage_smoke") as CPUParticles3D


func _visual_root_name(craft: RangeOpponent) -> String:
	var visual := craft.get("_visual_root") as Node3D
	return String(visual.name) if is_instance_valid(visual) else "MissingVisualRoot"


func _engine_output(craft: RangeOpponent) -> float:
	var total := 0.0
	var lights: Array = craft.get("_engine_lights")
	for light in lights:
		if is_instance_valid(light):
			total += (light as OmniLight3D).light_energy
	var glows: Array = craft.get("_engine_glows")
	for glow in glows:
		if is_instance_valid(glow):
			total += (glow as MeshInstance3D).scale.y
	return total


func _world_effect_count(craft: RangeOpponent) -> int:
	var effects: Dictionary = craft.get("_transient_effects")
	return effects.size()


# ---------------------------------------------------------------- hero ----

## The same six categories on the player's side of the seam. Measured through
## the presentation component's own state API — stage, latch, node counts — so
## nothing here samples the two sine-driven lights named in the header.
func _audit_hero_presentation() -> void:
	var host := Node3D.new()
	host.name = "HeroPresentationCoverageWorld"
	root.add_child(host)
	var packed := load(HERO_PRESENTATION_SCENE) as PackedScene
	_check(packed != null, "the hero damage presentation scene loads for the coverage audit")
	if packed == null:
		await _free_host(host)
		return
	var presentation := packed.instantiate() as Node3D
	presentation.set("destruction_effect_lifetime", 0.2)
	presentation.set("impact_effect_lifetime", 0.1)
	host.add_child(presentation)
	await _advance(2)

	presentation.call("update_state", 1.0, HeroDamagePresentation.STATE_ACTIVE)
	await _advance(1)
	_check(
		int(presentation.call("get_damage_stage")) == HeroDamagePresentation.DamageStage.HEALTHY
		and not bool(presentation.call("is_alarm_active"))
		and not bool(presentation.call("is_engine_failure_active")),
		"the hero presentation shows no damage staging at full hull"
	)

	# 1. Impact.
	var before := int(presentation.call("get_live_world_effect_count"))
	presentation.call("present_impact", Vector3(2.0, 1.0, -3.0), Vector3.UP, 1.0)
	await _advance(1)
	_check(
		int(presentation.call("get_live_world_effect_count")) > before,
		"the hero presentation spawns a world-space impact burst on a hit"
	)

	# 2/3. Staged damage, then staged critical damage.
	presentation.call("update_state", 0.55, HeroDamagePresentation.STATE_ACTIVE)
	await _advance(1)
	_check(
		int(presentation.call("get_damage_stage")) == HeroDamagePresentation.DamageStage.DAMAGED
		and bool(presentation.call("is_alarm_active")),
		"the hero presentation stages damaged sparks and raises its alarm latch"
	)
	presentation.call("update_state", 0.15, HeroDamagePresentation.STATE_ACTIVE)
	await _advance(1)
	_check(
		int(presentation.call("get_damage_stage")) == HeroDamagePresentation.DamageStage.CRITICAL,
		"the hero presentation stages critical smoke"
	)

	# 4. Engine degradation, read from the authority latch rather than a light.
	_check(
		bool(presentation.call("is_engine_failure_active"))
		and float(presentation.call("get_engine_power_multiplier")) < 1.0,
		"the hero presentation degrades engine output at critical hull (%.3f)"
			% float(presentation.call("get_engine_power_multiplier"))
	)

	# 5/6. Destruction, debris, and the failure presentation.
	presentation.call("present_destruction", Vector3(0.0, 0.0, -20.0))
	await _advance(2)
	var destruction_root := presentation.call("get_destruction_effect_root") as Node3D
	var debris := 0
	var lights := 0
	var particles := 0
	if destruction_root != null:
		for child in destruction_root.get_children():
			if child is RigidBody3D:
				debris += 1
			elif child is OmniLight3D:
				lights += 1
			elif child is CPUParticles3D:
				particles += 1
	_check(
		destruction_root != null and destruction_root.get_parent() != presentation,
		"the hero presentation detaches its destruction effects into the world"
	)
	_check(
		debris >= MINIMUM_DEBRIS_BODIES and particles >= 1 and lights >= 1,
		"the hero destruction pairs debris with particles and a flash light (%d/%d/%d)"
			% [debris, particles, lights]
	)
	_check(
		int(presentation.call("get_damage_stage")) == HeroDamagePresentation.DamageStage.DESTROYED,
		"the hero presentation records its own failure state"
	)
	_coverage.append(
		"HERO_PRESENTATION_COVERAGE: impact=yes sparks=yes smoke=yes engine=%.3f debris=%d particles=%d flash=%d"
			% [
				float(presentation.call("get_engine_power_multiplier")),
				debris, particles, lights,
			]
	)
	presentation.call("dispose_effects")
	await _free_host(host)


# ------------------------------------------------------------- harness ----

func _advance(frames: int) -> void:
	for _index in frames:
		await physics_frame
		await process_frame


func _free_host(host: Node3D) -> void:
	if is_instance_valid(host):
		root.remove_child(host)
		host.queue_free()
	for _index in 10:
		await process_frame


func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		print("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("OPPONENT_PRESENTATION_COVERAGE_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print("OPPONENT_PRESENTATION_COVERAGE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
