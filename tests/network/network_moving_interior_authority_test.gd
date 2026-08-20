extends SceneTree

## Focused detached coverage for server moving-interior occupancy. It does not
## start MultiplayerPeer, production physics, renderer, or the full test suite.

const Authority := preload("res://scripts/network/network_moving_interior_authority.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_server_owned_registration()
	_test_generation_and_sample_handoff()
	_test_stale_occupancy_and_detachment()
	if _failures.is_empty():
		print("OK: network moving interior authority (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _sample(tick: int, entity_generation: int = 4, frame_generation: int = 7, arrival := 1.100) -> Dictionary:
	return {
		"snapshot": Relationship.create(
			tick, &"pilot_7", entity_generation, &"jovian_frame", frame_generation,
			Transform3D(Basis.IDENTITY, Vector3(0.5, 1.0, -2.0)),
			Vector3(2.0, 0.0, 0.0), Vector3.ZERO, tick
		).get_snapshot(),
		"arrival_time_seconds": arrival,
	}


func _register_standard(authority: Authority) -> void:
	authority.register_frame(99, &"jovian_frame", 7)
	authority.register_occupancy(99, 7, &"pilot_7", 4, &"jovian_frame", 7)
	authority.set_server_tick(99, 100)


func _test_server_owned_registration() -> void:
	var authority := Authority.new(99, 3, 2)
	_check(
		not authority.register_frame(7, &"jovian_frame", 7).accepted
		and authority.get_last_result().status == &"unauthorized_source",
		"clients cannot register moving-interior frame generations"
	)
	_check(authority.register_frame(99, &"jovian_frame", 7).accepted, "server registers a frame generation")
	_check(
		not authority.register_occupancy(7, 7, &"pilot_7", 4, &"jovian_frame", 7).accepted,
		"clients cannot mutate occupancy registration"
	)
	_check(
		authority.register_occupancy(99, 7, &"pilot_7", 4, &"jovian_frame", 7).accepted,
		"server binds one occupant to the current frame generation"
	)
	_check(
		not authority.register_occupancy(99, 7, &"pilot_7", 4, &"jovian_frame", 7).accepted
		and authority.get_last_result().status == &"duplicate_occupancy",
		"duplicate occupancy cannot create a second server record"
	)


func _test_generation_and_sample_handoff() -> void:
	var authority := Authority.new(99, 3, 2)
	_register_standard(authority)
	var sample := authority.handoff_latency_sample(99, _sample(100))
	_check(sample.accepted and sample.status == &"sample_handed_off", "server accepts the current frame-local sample")
	var handoff := sample.get("sample_handoff", {}) as Dictionary
	_check(
		handoff.has("snapshot") and handoff.has("arrival_time_seconds")
		and int((handoff.snapshot as Dictionary).get("parent_frame_generation", 0)) == 7,
		"latency observer receives a detached frame-generation-bearing sample handoff"
	)
	var second := authority.handoff_latency_sample(99, _sample(101, 4, 7, 1.117))
	_check(second.accepted and authority.get_occupancy(&"pilot_7").sample_count == 2, "later samples advance the occupancy stream")
	var replay := authority.handoff_latency_sample(99, _sample(101, 4, 7, 1.118))
	_check(not replay.accepted and replay.status == &"stale_occupancy_tick", "replayed sample tick is rejected")
	var future := authority.handoff_latency_sample(99, _sample(103, 4, 7, 1.150))
	_check(not future.accepted and future.status == &"sample_tick_too_far_ahead", "future sample outside the server tick window is rejected")


func _test_stale_occupancy_and_detachment() -> void:
	var authority := Authority.new(99, 3, 2)
	_register_standard(authority)
	var stale_entity := authority.handoff_latency_sample(99, _sample(100, 3, 7))
	_check(not stale_entity.accepted and stale_entity.status == &"stale_entity_generation", "stale occupant generation cannot hand off a sample")
	var stale_frame := authority.handoff_latency_sample(99, _sample(100, 4, 6))
	_check(not stale_frame.accepted and stale_frame.status == &"stale_frame_generation", "stale frame generation cannot hand off a sample")
	var spoofed := authority.handoff_latency_sample(7, _sample(100))
	_check(not spoofed.accepted and spoofed.status == &"unauthorized_source", "non-authoritative sample handoff is rejected")
	var snapshot := authority.get_snapshot()
	(snapshot.occupancies as Array).clear()
	_check(authority.get_snapshot().occupancies.size() == 1, "snapshots are detached from retained occupancy")
	var audit := authority.audit()
	_check(
		bool(audit.server_owns_frame_generation)
		and bool(audit.server_owns_occupancy)
		and bool(audit.stale_occupancy_rejected)
		and bool(audit.latency_sample_handoff)
		and not bool(audit.client_can_mutate_occupancy)
		and not bool(audit.owns_physical_compensation),
		"audit exposes generation, occupancy, and latency ownership boundaries"
	)
	var retired := authority.retire_frame(99, &"jovian_frame", 7)
	_check(retired.accepted and retired.released_occupancies.size() == 1, "retiring a frame releases its occupancy atomically")
	_check(
		authority.register_frame(99, &"jovian_frame", 8).accepted,
		"server can register the next frame generation after retirement"
	)
	_check(
		not authority.register_frame(99, &"jovian_frame", 7).accepted
		and authority.get_last_result().status == &"stale_frame_generation",
		"late frame generations cannot replace the current frame"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
