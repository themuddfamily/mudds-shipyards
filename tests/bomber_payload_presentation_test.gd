extends SceneTree

const Presentation := preload("res://scripts/effects/bomber_payload_presentation.gd")
const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const Projectile := preload("res://scripts/combat/bomber_payload_projectile.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _finished_ids: Array[StringName] = []
var _recycled_pairs: Array[Array] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "BomberPayloadPresentationTestWorld"
	host.transform = Transform3D(Basis(Vector3.UP, 0.41), Vector3(30.0, 8.0, -14.0))
	root.add_child(host)

	var presentation = Presentation.new()
	_check(
		not bool(presentation.consume_release_record(_release(1, Vector3.ZERO, Vector3.DOWN)).accepted),
		"pre-tree records cannot allocate or activate presentation"
	)
	presentation.payload_visual_finished.connect(func(record_id: StringName) -> void:
		_finished_ids.append(record_id)
	)
	presentation.payload_visual_recycled.connect(func(old_id: StringName, new_id: StringName) -> void:
		_recycled_pairs.append([old_id, new_id])
	)
	host.add_child(presentation)
	await process_frame

	var audit: Dictionary = presentation.get_audit_report()
	var performance := audit.performance as Dictionary
	var integration := audit.integration as Dictionary
	print("BOMBER_PAYLOAD_PRESENTATION_PERFORMANCE: ", performance)
	_check(bool(audit.valid), "fresh payload presentation passes its exact structural budget")
	_check(
		int(performance.pool_capacity) == 4
		and int(performance.generated_nodes) == 32
		and int(performance.mesh_instances) == 28,
		"four slots preallocate exactly thirty-two generated nodes and twenty-eight meshes"
	)
	_check(
		int(performance.lights) == 0
		and int(performance.audio_nodes) == 0
		and int(performance.particle_emitters) == 0
		and int(audit.collision_nodes) == 0,
		"component has zero light, voice, particle, collision, and query authority"
	)
	_check(
		int(performance.shared_mesh_resources) == 5
		and int(performance.shared_material_resources) == 4
		and not bool(performance.runtime_node_allocation)
		and not bool(performance.runtime_resource_allocation),
		"all slots use the fixed shared five-mesh/four-material catalog"
	)
	_check(
		integration.authority_policy == &"accepted_release_and_terminal_records_presentation_only"
		and integration.coordinate_space == &"world_space_records"
		and int(integration.light_budget) == 0
		and integration.voice_policy == &"voice_free_no_audio_nodes",
		"integration contract retains projectile, resolver, and audio authority outside presentation"
	)
	_check(
		presentation.is_in_group(&"bomber_payload_presentation")
		and bool(presentation.get_meta(&"presentation_only", false))
		and not bool(presentation.get_meta(&"gameplay_authority", true)),
		"component is discoverable and explicitly marked presentation-only"
	)

	var release_position := Vector3(-18.0, 42.0, 73.0)
	var release_velocity := Vector3(3.0, -28.0, -7.0)
	var release := _release(1, release_position, release_velocity)
	var accepted: Dictionary = presentation.consume_release_record(release)
	_check(bool(accepted.accepted), "an accepted authority release record enters the pool")
	release.release_position = Vector3(900.0, 900.0, 900.0)
	var snapshot := presentation.get_active_snapshots()[0] as Dictionary
	_check(
		(snapshot.release_position as Vector3).is_equal_approx(release_position)
		and (snapshot.release_velocity as Vector3).is_equal_approx(release_velocity)
		and (snapshot.visual_position as Vector3).is_equal_approx(release_position),
		"release pose is copied exactly in world space and detached from caller mutation"
	)
	_check(
		bool(snapshot.silhouette_visible) and bool(snapshot.trail_visible)
		and not bool(snapshot.terminal_visible),
		"accepted release reads as a compact finned bomb with a bounded trail"
	)
	var exact_world_position := snapshot.visual_position as Vector3
	host.position += Vector3(120.0, -20.0, 44.0)
	snapshot = presentation.get_active_snapshots()[0] as Dictionary
	_check(
		(snapshot.visual_position as Vector3).is_equal_approx(exact_world_position),
		"top-level pool slot preserves submitted world pose when its host moves"
	)
	_check(presentation.advance_simulation(0.25), "manual clock advances one live presentation")
	snapshot = presentation.get_active_snapshots()[0] as Dictionary
	_check(
		(snapshot.visual_position as Vector3).is_equal_approx(release_position + release_velocity * 0.25),
		"flight art uses bounded visual extrapolation without changing the copied release pose"
	)

	var impact_position := Vector3(-17.25, 34.5, 70.25)
	var impact_velocity := Vector3(2.0, -31.0, -8.0)
	var impact_normal := Vector3(0.2, 0.95, 0.1).normalized()
	var terminal := _terminal(1, &"impact", impact_position, impact_velocity, impact_normal)
	_check(
		bool(presentation.consume_terminal_record(terminal).accepted),
		"matching resolver-ready impact record transitions the live slot"
	)
	terminal.position = Vector3.ZERO
	snapshot = presentation.get_active_snapshots()[0] as Dictionary
	_check(
		(snapshot.terminal_position as Vector3).is_equal_approx(impact_position)
		and (snapshot.terminal_velocity as Vector3).is_equal_approx(impact_velocity)
		and (snapshot.terminal_normal as Vector3).is_equal_approx(impact_normal)
		and (snapshot.visual_position as Vector3).is_equal_approx(impact_position),
		"impact snaps to and retains the exact detached terminal world pose"
	)
	_check(
		not bool(snapshot.silhouette_visible) and not bool(snapshot.trail_visible)
		and bool(snapshot.terminal_visible) and snapshot.terminal_kind == &"impact",
		"impact replaces flight art with one compact flare and ring"
	)
	_check(
		not bool(presentation.consume_terminal_record(_terminal(1, &"impact", impact_position, impact_velocity, impact_normal)).accepted),
		"one release cannot present a terminal record twice"
	)
	_check(presentation.advance_simulation(9.0), "a terminal hitch is consumed deterministically")
	_check(
		presentation.get_active_snapshots().is_empty()
		and _finished_ids.has(&"bomber_payload_release_000001"),
		"hitch retires terminal art exactly once without leaving a slot live"
	)

	var expiry_release := _release(2, Vector3(4.0, 20.0, -8.0), Vector3(0.0, -12.0, 2.0))
	presentation.consume_release_record(expiry_release)
	var expiry := _terminal(2, &"expiry", Vector3(4.0, 2.0, -5.0), Vector3(0.0, -12.0, 2.0), Vector3.ZERO)
	_check(bool(presentation.consume_terminal_record(expiry).accepted), "resolver-ready expiry uses the same bounded terminal pool")
	snapshot = presentation.get_active_snapshots()[0] as Dictionary
	_check(
		snapshot.terminal_kind == &"expiry"
		and (snapshot.visual_position as Vector3).is_equal_approx(expiry.position),
		"expiry art preserves its exact zero-normal terminal position"
	)
	presentation.advance_simulation(0.33)
	_check(presentation.get_active_snapshots().is_empty(), "compact expiry art self-cleans after 0.32 seconds")

	# Saturation recycles only the oldest presentation and allocates no nodes or resources.
	var before_nodes := _count_descendants(presentation)
	var before_resources: Dictionary = presentation.get_resource_identity_audit()
	for sequence in range(10, 15):
		presentation.consume_release_record(
			_release(sequence, Vector3(float(sequence), 10.0, 0.0), Vector3.DOWN * 5.0)
		)
	var active: Array = presentation.get_active_snapshots()
	_check(active.size() == 4, "five simultaneous releases remain bounded to the four-slot pool")
	_check(
		_recycled_pairs.has([&"bomber_payload_release_000010", &"bomber_payload_release_000014"]),
		"saturation deterministically replaces the oldest visual"
	)
	_check(
		_count_descendants(presentation) == before_nodes
		and presentation.get_resource_identity_audit() == before_resources,
		"release, terminal, hitch, and saturation allocate no nodes or visual resources"
	)

	presentation.detach()
	_check(presentation.get_active_snapshots().is_empty(), "explicit detach synchronously hides every active slot")
	_check(
		not bool(presentation.consume_release_record(_release(20, Vector3.ZERO, Vector3.DOWN)).accepted),
		"explicitly detached presentation fails closed"
	)
	presentation.reset_for_reuse()
	_check(
		bool(presentation.consume_release_record(_release(21, Vector3(1.0, 2.0, 3.0), Vector3.DOWN)).accepted),
		"reset reuses the same fixed pool without rebuilding"
	)

	# Removing the component clears slots; normal tree re-entry is safe and does
	# not require a new node or resource catalog.
	host.remove_child(presentation)
	_check(presentation.get_active_snapshots().is_empty(), "tree detach clears active visuals synchronously")
	host.add_child(presentation)
	await process_frame
	_check(
		bool(presentation.consume_release_record(_release(22, Vector3(7.0, 8.0, 9.0), Vector3.FORWARD)).accepted),
		"tree re-entry accepts a fresh record on the retained pool"
	)

	var second = Presentation.new()
	host.add_child(second)
	await process_frame
	_check(
		second.get_resource_identity_audit() == presentation.get_resource_identity_audit()
		and int(second.get_performance_audit().catalog_build_count) == 1,
		"multiple components share one immutable process-wide visual catalog"
	)
	var invalid := _release(30, Vector3.ZERO, Vector3.DOWN)
	invalid.release_position = Vector3(INF, 0.0, 0.0)
	_check(
		not bool(second.consume_release_record(invalid).accepted)
		and not bool(second.consume_terminal_record(_terminal(999, &"impact", Vector3.ZERO, Vector3.ZERO, Vector3.UP)).accepted),
		"invalid poses and terminal records without a live release fail closed"
	)

	# Production composition: the Cinder bomber owns the visual node and mirrors
	# only records that have already passed payload/projectile authority.
	var bomber = Bomber.new()
	bomber.name = "ProductionCinderBomber"
	host.add_child(bomber)
	await process_frame
	await process_frame
	var composed = bomber.get_payload_presentation()
	_check(
		is_instance_valid(composed)
		and composed.get_parent() == bomber
		and composed.name == "BomberPayloadPresentation"
		and bool(bomber.get_audit_report().payload_presentation_composed),
		"production Cinder instantiates one bounded bomber-owned presentation pool"
	)
	_check(bool(bomber.begin_payload_generation(1).accepted), "production payload generation starts through Cinder authority")
	var live_release: Dictionary = bomber.request_payload_release(
		1, &"production_gunner", 1, 1, 0, Vector3(2.0, -36.0, -8.0)
	)
	var live_record := live_release.get("record", {}) as Dictionary
	var live_presentation := live_release.get("presentation", {}) as Dictionary
	var live_snapshots: Array = composed.get_active_snapshots()
	_check(
		bool(live_release.accepted)
		and bool(live_presentation.accepted)
		and live_snapshots.size() == 1,
		"one authority-accepted production release is immediately fed to the composed pool"
	)
	_check(
		(live_snapshots[0].release_position as Vector3).is_equal_approx(live_record.release_position)
		and (live_snapshots[0].release_velocity as Vector3).is_equal_approx(live_record.release_velocity),
		"production composition preserves the exact hardpoint world pose record"
	)

	var projectile = Projectile.new(1, Vector3.ZERO, 3.0, 200.0, 500.0)
	projectile.begin_generation(1)
	_check(
		bool(projectile.consume_release_record(1, live_record).accepted),
		"the same accepted production record enters the real projectile authority"
	)
	projectile.advance(0.2)
	var resolved_position := (projectile.get_snapshot().position as Vector3) + Vector3(0.0, -2.0, 0.0)
	var projectile_terminal: Dictionary = projectile.submit_impact(
		1, resolved_position, Vector3(0.1, 0.98, 0.05).normalized(), &"resolved_target", 3
	)
	var live_terminal := projectile_terminal.get("terminal_intent", {}) as Dictionary
	_check(
		bool(projectile_terminal.accepted)
		and bool(bomber.present_payload_terminal_record(live_terminal).accepted),
		"the real projectile terminal record is fed through Cinder's non-authoritative presentation seam"
	)
	live_snapshots = composed.get_active_snapshots()
	_check(
		live_snapshots.size() == 1
		and live_snapshots[0].phase == &"terminal"
		and (live_snapshots[0].terminal_position as Vector3).is_equal_approx(live_terminal.position),
		"live production impact snaps the composed visual to the exact resolved terminal pose"
	)
	composed.advance_simulation(0.33)
	_check(composed.get_active_snapshots().is_empty(), "production terminal art self-cleans on the fixed pool clock")

	bomber.advance_payload_cooldown(1.0)
	var switch_release: Dictionary = bomber.request_payload_release(
		1, &"production_gunner", 1, 2, 1, Vector3(0.0, -30.0, 0.0)
	)
	_check(
		bool(switch_release.accepted) and composed.get_active_snapshots().size() == 1,
		"a live payload visual exists before ship-switch reuse"
	)
	var switch_result: Dictionary = bomber.reset_for_reuse(
		Transform3D(Basis.IDENTITY, Vector3(80.0, 12.0, -40.0))
	)
	_check(
		bool(switch_result.accepted)
		and composed.get_active_snapshots().is_empty()
		and not bool(bomber.get_payload_authority_snapshot().active),
		"ship-switch reuse atomically detaches payload authority and clears presentation"
	)
	_check(
		bool(bomber.reset_payload_for_reuse(2).accepted),
		"new payload generation resets the retained visual pool after a ship switch"
	)
	var reused_release: Dictionary = bomber.request_payload_release(
		1, &"replacement_gunner", 2, 1, 2, Vector3(0.0, -24.0, 3.0)
	)
	_check(
		bool(reused_release.accepted)
		and bool((reused_release.presentation as Dictionary).accepted)
		and composed.get_active_snapshots().size() == 1,
		"re-entered production generation feeds a fresh release into the same pool"
	)
	_check(
		bool(bomber.detach_payload_authority(&"combat_owner_detached").accepted)
		and composed.get_active_snapshots().is_empty(),
		"explicit production authority detach synchronously clears its live visual"
	)

	host.queue_free()
	await process_frame
	await process_frame
	_finish()


func _release(sequence: int, position: Vector3, velocity: Vector3) -> Dictionary:
	return {
		"schema_version": 1,
		"record_id": StringName("bomber_payload_release_%06d" % sequence),
		"release_sequence": sequence,
		"generation": 7,
		"actor_id": &"cinder_bomber",
		"request_sequence": sequence,
		"payload_id": &"cinder_payload_alpha",
		"weapon_id": &"bomber_payload_release",
		"presentation_id": &"payload_release_flash",
		"audio_id": &"payload_release_audio",
		"release_position": position,
		"release_velocity": velocity,
		"ammunition_remaining": 4,
		"cooldown_remaining": 1.0,
	}


func _terminal(sequence: int, kind: StringName, position: Vector3, velocity: Vector3, normal: Vector3) -> Dictionary:
	return {
		"schema_version": 1,
		"terminal_sequence": 1,
		"generation": 7,
		"release_sequence": sequence,
		"request_sequence": sequence,
		"record_id": StringName("bomber_payload_release_%06d" % sequence),
		"kind": kind,
		"position": position,
		"velocity": velocity,
		"normal": normal,
		"target_id": &"target" if kind == &"impact" else &"",
		"target_generation": 2 if kind == &"impact" else 0,
		"expiry_reason": &"lifetime" if kind == &"expiry" else &"",
		"resolver_ready": true,
	}


func _count_descendants(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		count += 1 + _count_descendants(child)
	return count


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	print("BOMBER_PAYLOAD_PRESENTATION_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("BOMBER_PAYLOAD_PRESENTATION_TEST_OK")
		quit(0)
	else:
		print("BOMBER_PAYLOAD_PRESENTATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
