extends SceneTree

const FEEDBACK_SCENE := preload("res://scenes/world/components/ship_berth_feedback.tscn")
const BERTH_SCENE := preload("res://scenes/world/components/ship_berth.tscn")
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")

var _failures: Array[String] = []
var _assertions := 0
var _reentry_berth: ShipBerth
var _reentry_feedback: ShipBerthFeedback
var _reentry_ship: Node3D
var _reentry_listener_a: Array[Dictionary] = []
var _reentry_listener_b: Array[Dictionary] = []
var _reentry_occupy_results: Array[bool] = []
var _weak_reconcile_states: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var berth := BERTH_SCENE.instantiate() as ShipBerth
	berth.berth_id = &"feedback_test_berth"
	stage.add_child(berth)
	var feedback := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	feedback.cue_half_width = 6.0
	feedback.cue_half_length = 8.0
	berth.add_child(feedback)
	await process_frame

	_check(feedback != null and feedback.get_component_id() == &"ship_berth_feedback", "typed feedback scene exposes stable component identity")
	_check(feedback.get_parent() == berth and feedback.is_in_group(&"ship_berth_feedback"), "feedback binds only to its direct authoritative ShipBerth")
	_check(feedback.get_feedback_state() == &"released", "fresh unclaimed berth renders released state")
	_check(bool(feedback.get_audit_report().valid), "fresh component passes its complete audit")
	var perf := feedback.get_performance_report()
	_check(int(perf.mesh_instances) == 11 and int(perf.material_resources) == 4, "component owns exactly eleven meshes and four instance-local materials")
	_check(int(perf.collision_nodes) == 0 and int(perf.lights) == 0 and int(perf.audio_nodes) == 0 and int(perf.particle_emitters) == 0, "feedback adds no collision, light, audio, or particle authority")
	_check(feedback.get_evidence_metadata().evidence_status == &"modern_interpretation" and not bool(feedback.get_evidence_metadata().historically_supported), "feedback remains an explicit unsupported modern interpretation")

	var ship := Node3D.new()
	ship.name = "LeaseOwner"
	stage.add_child(ship)
	var token := berth.try_reserve(ship, TORRENT_DEFINITION)
	await process_frame
	_check(not token.is_empty() and feedback.get_feedback_state() == &"approach", "real reservation transition renders approach state")
	_check(feedback.get_state_snapshot().label == "APPROACH VECTOR", "approach state publishes its exact visible label")
	_check(berth.occupy(ship, token), "fixture converts the exact opaque lease to occupancy")
	await process_frame
	_check(feedback.get_feedback_state() == &"occupied" and feedback.get_state_snapshot().label == "BERTH SECURED", "real occupancy transition renders secured state")
	_check(berth.release(ship, token), "fixture releases the authoritative occupied lease")
	await process_frame
	_check(feedback.get_feedback_state() == &"released", "real lease release restores open state")

	feedback.set_auto_advance_enabled(false)
	feedback.seek_simulation(0.0)
	feedback.advance_simulation(0.25)
	_check(is_equal_approx(float(feedback.get_state_snapshot().elapsed), 0.25), "manual deterministic clock advances by exact elapsed time")
	var first_phase := float(feedback.get_state_snapshot().phase)
	feedback.seek_simulation(0.0)
	for _step in 30:
		feedback.advance_simulation(1.0 / 120.0)
	_check(absf(float(feedback.get_state_snapshot().phase) - first_phase) < 0.00001, "manual animation is invariant between one-step and 120 Hz subdivision")
	feedback.set_feedback_paused(true)
	feedback.advance_simulation(1.0)
	_check(absf(float(feedback.get_state_snapshot().elapsed) - 0.25) < 0.00001, "paused feedback rejects manual time advancement")
	feedback.set_feedback_paused(false)
	feedback.set_feedback_enabled(false)
	_check(not feedback.visible and int(feedback.get_performance_report().visible_meshes) == 0, "disabled lifecycle hides every presentation mesh")
	_check(bool(feedback.get_audit_report().valid), "disabled presentation remains a valid intentional lifecycle state")
	feedback.set_feedback_enabled(true)
	_check(bool(feedback.get_audit_report().valid), "re-enabled feedback restores a valid presentation")

	var berth_two := BERTH_SCENE.instantiate() as ShipBerth
	berth_two.berth_id = &"feedback_isolation_berth"
	stage.add_child(berth_two)
	var feedback_two := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	berth_two.add_child(feedback_two)
	await process_frame
	var first_ids: Dictionary = feedback.get_audit_report().performance
	var material_a := (feedback.get_node("FeedbackVisual/LeaseStatePlate") as MeshInstance3D).material_override
	var material_b := (feedback_two.get_node("FeedbackVisual/LeaseStatePlate") as MeshInstance3D).material_override
	_check(material_a != material_b, "two berth instances never share mutable presentation materials")
	var ship_two := Node3D.new()
	stage.add_child(ship_two)
	var token_two := berth_two.try_reserve(ship_two, TORRENT_DEFINITION)
	await process_frame
	_check(not token_two.is_empty() and feedback_two.get_feedback_state() == &"approach" and feedback.get_feedback_state() == &"released", "one berth state cannot bleed into another instance")
	berth_two.release(ship_two, token_two)
	ship_two.queue_free()

	# A listener may synchronously advance the authoritative lease while an outer
	# feedback event is still being delivered. Both listeners must observe the
	# complete approach -> occupied sequence, with getters and live copy coherent
	# with each event rather than leaking the nested state into the outer event.
	var reentry_berth := BERTH_SCENE.instantiate() as ShipBerth
	reentry_berth.berth_id = &"feedback_reentry_berth"
	stage.add_child(reentry_berth)
	var reentry_feedback := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	reentry_berth.add_child(reentry_feedback)
	var reentry_ship := Node3D.new()
	reentry_ship.name = "ReentrantLeaseOwner"
	stage.add_child(reentry_ship)
	await process_frame
	_reentry_berth = reentry_berth
	_reentry_feedback = reentry_feedback
	_reentry_ship = reentry_ship
	_reentry_listener_a.clear()
	_reentry_listener_b.clear()
	_reentry_occupy_results.clear()
	reentry_feedback.state_changed.connect(_on_reentry_listener_a)
	reentry_feedback.state_changed.connect(_on_reentry_listener_b)
	var reentry_token := reentry_berth.try_reserve(reentry_ship, TORRENT_DEFINITION)
	_check(
		not reentry_token.is_empty()
		and _reentry_occupy_results == [true]
		and reentry_berth.get_occupant() == reentry_ship,
		"first synchronous feedback listener can convert the live reservation to occupancy exactly once"
	)
	_check(
		_reentry_observations_are_coherent(_reentry_listener_a)
		and _reentry_observations_are_coherent(_reentry_listener_b),
		"both synchronous listeners observe exact approach then occupied events with coherent getter and label state"
	)
	reentry_feedback.state_changed.disconnect(_on_reentry_listener_a)
	reentry_feedback.state_changed.disconnect(_on_reentry_listener_b)
	_check(reentry_berth.release(reentry_ship, reentry_token), "reentrant lease fixture releases through the returned authoritative token")
	reentry_ship.queue_free()

	# Weak-reference reconciliation must keep polling while presentation animation
	# is both manually clocked and paused. Inspect the emitted transition and live
	# label first: neither a state getter nor manual advancement may cause the fix.
	feedback.set_auto_advance_enabled(false)
	feedback.set_feedback_paused(true)
	_weak_reconcile_states.clear()
	feedback.state_changed.connect(_on_weak_reconcile_state_changed)
	var passive_owner := Node3D.new()
	passive_owner.name = "PassiveWeakLeaseOwner"
	stage.add_child(passive_owner)
	var passive_token := berth.try_reserve(passive_owner, TORRENT_DEFINITION)
	_check(not passive_token.is_empty() and feedback.is_processing(), "paused manual-clock feedback keeps its allocation-free berth reconciliation poll active")
	_weak_reconcile_states.clear()
	passive_owner.queue_free()
	await process_frame
	await process_frame
	await process_frame
	var passive_label := feedback.get_node("FeedbackVisual/LeaseStateLabel") as Label3D
	_check(
		_weak_reconcile_states == [&"released"] and passive_label.text == "BERTH OPEN",
		"paused manual-clock polling reconciles a freed weak owner into released state and live copy without getter or advance"
	)
	feedback.state_changed.disconnect(_on_weak_reconcile_state_changed)
	feedback.set_feedback_paused(false)

	berth.remove_child(feedback)
	berth.add_child(feedback)
	await process_frame
	_check(feedback.get_feedback_state() == &"released" and bool(feedback.get_audit_report().valid), "child detach and re-add reconnects lifecycle without rebuilding")

	var stale_owner := Node3D.new()
	stage.add_child(stale_owner)
	var stale_token := berth.try_reserve(stale_owner, TORRENT_DEFINITION)
	_check(not stale_token.is_empty(), "stale-owner fixture obtains a real reservation")
	stale_owner.queue_free()
	await process_frame
	feedback.advance_simulation(0.0)
	_check(feedback.get_feedback_state() == &"released", "polling reconciles weak-owner cleanup even without a berth signal")

	# Every immutable presentation contract must fail red on live drift and return
	# green after the exact value is restored.
	_check(bool(feedback.get_audit_report().valid), "integrity mutation fixture starts from a valid released presentation")
	feedback.visible = false
	_check(not bool(feedback.get_audit_report().valid), "audit rejects direct component visibility drift")
	feedback.visible = true
	_check(bool(feedback.get_audit_report().valid), "restoring component visibility restores a green audit")

	var visual_root := feedback.get_node("FeedbackVisual") as Node3D
	var rogue_label := Label3D.new()
	rogue_label.name = "RogueLeaseLabel"
	visual_root.add_child(rogue_label)
	_check(not bool(feedback.get_audit_report().valid), "audit rejects an unowned second Label3D")
	visual_root.remove_child(rogue_label)
	rogue_label.free()
	_check(bool(feedback.get_audit_report().valid), "removing the rogue label restores exact hierarchy integrity")

	var plate := feedback.get_node("FeedbackVisual/LeaseStatePlate") as MeshInstance3D
	var plate_transform := plate.transform
	plate.position += Vector3(0.25, 0.0, -0.1)
	_check(not bool(feedback.get_audit_report().valid), "audit rejects lease-state plate transform drift")
	plate.transform = plate_transform
	_check(bool(feedback.get_audit_report().valid), "restoring the exact plate transform restores a green audit")

	var plate_box := plate.mesh as BoxMesh
	var plate_box_size := plate_box.size
	plate_box.size += Vector3(0.2, 0.01, 0.15)
	_check(not bool(feedback.get_audit_report().valid), "audit rejects in-place BoxMesh size drift")
	plate_box.size = plate_box_size
	_check(bool(feedback.get_audit_report().valid), "restoring the exact BoxMesh size restores a green audit")

	var plate_material := plate.material_override as StandardMaterial3D
	var billboard_mode := plate_material.billboard_mode
	plate_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_check(not bool(feedback.get_audit_report().valid), "audit rejects shared presentation material billboard drift")
	plate_material.billboard_mode = billboard_mode
	_check(bool(feedback.get_audit_report().valid), "restoring material billboard mode restores a green audit")
	var cull_mode := plate_material.cull_mode
	plate_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_check(not bool(feedback.get_audit_report().valid), "audit rejects shared presentation material cull drift")
	plate_material.cull_mode = cull_mode
	_check(bool(feedback.get_audit_report().valid), "restoring material cull mode restores a green audit")

	var state_label := feedback.get_node("FeedbackVisual/LeaseStateLabel") as Label3D
	var label_text := state_label.text
	state_label.text = "MUTATED LEASE COPY"
	_check(not bool(feedback.get_audit_report().valid), "audit rejects live state-label text drift")
	state_label.text = label_text
	_check(bool(feedback.get_audit_report().valid), "restoring state-label text restores a green audit")
	var label_double_sided := state_label.double_sided
	state_label.double_sided = not label_double_sided
	_check(not bool(feedback.get_audit_report().valid), "audit rejects state-label double-sided drift")
	state_label.double_sided = label_double_sided
	_check(bool(feedback.get_audit_report().valid), "restoring label sidedness restores a green audit")
	var label_transform := state_label.transform
	state_label.position += Vector3(0.0, 0.1, 0.2)
	_check(not bool(feedback.get_audit_report().valid), "audit rejects state-label transform drift")
	state_label.transform = label_transform
	_check(bool(feedback.get_audit_report().valid), "restoring the exact label transform restores a green audit")

	# Detachment is recoverable; freeing is tested on a sacrificial component so
	# repeated fail-red audits can prove stale cached references remain safe.
	feedback.remove_child(visual_root)
	var detached_audit_a := feedback.get_audit_report()
	var detached_audit_b := feedback.get_audit_report()
	_check(
		not bool(detached_audit_a.valid)
		and not bool(detached_audit_b.valid)
		and detached_audit_a.errors == detached_audit_b.errors,
		"detached FeedbackVisual fails red consistently across repeated audits"
	)
	feedback.add_child(visual_root)
	await process_frame
	_check(bool(feedback.get_audit_report().valid), "re-attaching the same FeedbackVisual restores the immutable hierarchy")

	var freed_berth := BERTH_SCENE.instantiate() as ShipBerth
	freed_berth.berth_id = &"feedback_freed_visual_berth"
	stage.add_child(freed_berth)
	var freed_feedback := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	freed_berth.add_child(freed_feedback)
	await process_frame
	var doomed_visual := freed_feedback.get_node("FeedbackVisual") as Node3D
	doomed_visual.queue_free()
	await process_frame
	await process_frame
	var freed_audit_a := freed_feedback.get_audit_report()
	var freed_audit_b := freed_feedback.get_audit_report()
	_check(
		not bool(freed_audit_a.valid)
		and not bool(freed_audit_b.valid)
		and freed_audit_a.errors == freed_audit_b.errors,
		"freed FeedbackVisual fails red deterministically without recurring audit errors"
	)

	stage.queue_free()
	await process_frame
	await process_frame
	_finish()


func _on_reentry_listener_a(state: StringName) -> void:
	_record_reentry_observation(_reentry_listener_a, state)
	if state != &"approach" or not is_instance_valid(_reentry_berth) or not is_instance_valid(_reentry_ship):
		return
	var live_token := _reentry_berth.get_reservation_token(_reentry_ship)
	_reentry_occupy_results.append(_reentry_berth.occupy(_reentry_ship, live_token))


func _on_reentry_listener_b(state: StringName) -> void:
	_record_reentry_observation(_reentry_listener_b, state)


func _record_reentry_observation(target: Array[Dictionary], state: StringName) -> void:
	var label := _reentry_feedback.get_node("FeedbackVisual/LeaseStateLabel") as Label3D
	target.append({
		"event": state,
		"getter": _reentry_feedback.get_feedback_state(),
		"label": label.text,
	})


func _reentry_observations_are_coherent(observations: Array[Dictionary]) -> bool:
	if observations.size() != 2:
		return false
	var expected_states: Array[StringName] = [&"approach", &"occupied"]
	var expected_labels := ["APPROACH VECTOR", "BERTH SECURED"]
	for index in expected_states.size():
		var observation := observations[index]
		if observation.get("event", &"") != expected_states[index] \
				or observation.get("getter", &"") != expected_states[index] \
				or str(observation.get("label", "")) != expected_labels[index]:
			return false
	return true


func _on_weak_reconcile_state_changed(state: StringName) -> void:
	_weak_reconcile_states.append(state)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_BERTH_FEEDBACK_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("SHIP_BERTH_FEEDBACK_TEST_FAILED: %s" % ", ".join(_failures))
		quit(1)
