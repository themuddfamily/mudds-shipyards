extends SceneTree

const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")


class FakeHost:
	extends EmberSurfaceLoopHost

	var fake_generation := 12
	var fake_attachment_generation := 4
	var fake_player_instance_id := 0
	var fake_ship_instance_id := 0
	var fake_session := RefCounted.new()

	func get_generation() -> int:
		return fake_generation

	func get_attachment_generation() -> int:
		return fake_attachment_generation

	func get_phase() -> int:
		return EmberSurfaceLoopHost.Phase.ON_FOOT

	func get_travel_session_observation_source() -> Object:
		return fake_session

	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop",
			"attached": true,
			"phase": EmberSurfaceLoopHost.Phase.ON_FOOT,
			"phase_id": &"on_foot",
			"generation": fake_generation,
			"attachment_generation": fake_attachment_generation,
			"identities": {
				"world_id": &"ember_moon",
				"player_instance_id": fake_player_instance_id,
				"ship_instance_id": fake_ship_instance_id,
			},
		}.duplicate(true)


class FakeSurfaceComposition:
	extends Node

	var reward_owner: Object
	var activity: Dictionary

	func get_snapshot() -> Dictionary:
		return {"adapter": {"activity_reward": activity.duplicate(true)}}

	func commit_relay_survey_reward() -> Dictionary:
		var pending := activity.get("pending_reward", {}) as Dictionary
		var authority_result := reward_owner.call(
			&"_commit_relay_reward_through_authority", pending.duplicate(true)
		) as Dictionary
		if not bool(authority_result.get("accepted", false)):
			return authority_result
		var committed := pending.duplicate(true)
		committed["authority_result"] = authority_result.duplicate(true)
		activity["pending_reward"] = {}
		activity["committed_reward"] = committed
		activity["state"] = &"completed"
		return {
			"accepted": true,
			"reason": &"reward_committed",
			"persistence": {
				"accepted": true,
				"reason": &"committed",
				"generation": 7,
			},
		}.duplicate(true)


var _grant_calls := 0
var _last_grant_request: Dictionary = {}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var binding := BindingScript.new()
	var methods := [
		&"start_planetary_relay_survey",
		&"submit_planetary_relay_survey_position",
		&"submit_planetary_relay_survey_landmark",
		&"commit_planetary_relay_survey_reward",
	]
	for method in methods:
		if not binding.has_method(method):
			push_error("missing production relay survey method: %s" % method)
			quit(1)
			return

	var host := FakeHost.new()
	var player := Node.new()
	var ship := Node.new()
	var composition := FakeSurfaceComposition.new()
	root.add_child(host)
	root.add_child(player)
	root.add_child(ship)
	root.add_child(binding)
	binding.add_child(composition)
	host.fake_player_instance_id = player.get_instance_id()
	host.fake_ship_instance_id = ship.get_instance_id()
	var pending := {
		"world_id": &"ember_moon",
		"activity_id": &"ember_beacon_survey",
		"objective_id": &"survey_beacon_network",
		"activity_generation": 3,
		"reward_id": &"ember_beacon_data",
		"reward_store_id": &"game_flow_reward_store",
		"reward_authority_id": &"game_flow_reward_authority",
		"return_target_id": &"mudds_shipyards",
		"recovery_id": &"return_to_landed_ship",
		"run_generation": host.fake_generation,
		"attachment_generation": host.fake_attachment_generation,
	}.duplicate(true)
	composition.reward_owner = binding
	composition.activity = {
		"state": &"awaiting_reward",
		"activity_id": &"ember_beacon_survey",
		"completed_activity_id": &"ember_beacon_survey",
		"activity_generation": 3,
		"run_generation": host.fake_generation,
		"attachment_generation": host.fake_attachment_generation,
		"pending_reward": pending,
		"committed_reward": {},
	}.duplicate(true)
	binding.set("_configured", true)
	binding.set("_generation", 6)
	binding.set("_state", EmberSurfaceLoopProductionBinding.State.RUNNING)
	binding.set("_host", host)
	binding.set("_host_instance_id", host.get_instance_id())
	binding.set("_player_instance_id", player.get_instance_id())
	binding.set("_ship_instance_id", ship.get_instance_id())
	binding.set("_planetary_composition", composition)
	binding.set("_relay_survey_persistence_store", RefCounted.new())
	binding.set("_relay_survey_persistence_slot", &"ember_relay_survey_completion")
	binding.set("_planetary_reward_authority", Callable(self, &"_grant_reward"))
	await physics_frame
	var current_frame := int(Engine.get_physics_frames())
	binding.set("_last_consumed_caller_serial", 9)
	binding.set("_last_consumed_physics_frame", current_frame)
	var envelope := {
		"actor_sample": {
			"available": true,
			"position": Vector3(540.0, 120030.0, -210.0),
			"actor_kind": &"player",
			"actor_instance_id": player.get_instance_id(),
		},
		"caller_serial": 9,
		"physics_frame": current_frame,
		"host_generation": host.fake_generation,
		"host_attachment_generation": host.fake_attachment_generation,
	}.duplicate(true)
	var valid_evidence := binding.call(
		&"_build_relay_reward_evidence", envelope, composition.activity
	) as Dictionary
	var stale_evidence := valid_evidence.duplicate(true)
	stale_evidence["owner_generation"] = 5
	var forged_actor := valid_evidence.duplicate(true)
	forged_actor["actor_instance_id"] = ship.get_instance_id()
	var forged_session := valid_evidence.duplicate(true)
	forged_session["session_instance_id"] = host.fake_session.get_instance_id() + 1
	_check(
		binding.call(
			&"_relay_reward_evidence_rejection", stale_evidence,
			composition.activity
		) == &"stale_relay_reward_evidence",
		"stale owner evidence rejects before authority",
	)
	_check(
		binding.call(
			&"_relay_reward_evidence_rejection", forged_actor,
			composition.activity
		) == &"forged_relay_reward_actor_session_evidence",
		"a forged actor cannot claim the pending survey reward",
	)
	_check(
		binding.call(
			&"_relay_reward_evidence_rejection", forged_session,
			composition.activity
		) == &"forged_relay_reward_actor_session_evidence",
		"a forged retained session cannot claim the pending survey reward",
	)
	_check(
		binding.call(
			&"_commit_relay_reward_through_authority", pending
		).reason == &"relay_reward_evidence_unavailable"
			and _grant_calls == 0,
		"authority cannot be called without the live late evidence latch",
	)
	_check(
		binding.commit_planetary_relay_survey_reward().reason
			== &"relay_reward_requires_late_actor_evidence",
		"the old manual intent API cannot bypass production actor evidence",
	)
	var commit_reason := binding.call(
		&"_commit_pending_relay_reward", envelope, composition.activity
	) as StringName
	var committed_snapshot := binding.get_snapshot().relay_reward_commit as Dictionary
	_check(
		commit_reason.is_empty() and _grant_calls == 1
			and int(committed_snapshot.authority_commit_count) == 1
			and int(committed_snapshot.persistence_commit_count) == 1
			and not (committed_snapshot.commit_receipt as Dictionary).is_empty(),
		"one live player/session generation grants and persists once",
	)
	_check(
		_last_grant_request.get("production_commit_id")
			== "ember-relay-survey:12:3"
			and int((_last_grant_request.production_evidence as Dictionary).actor_instance_id)
				== player.get_instance_id()
			and int((_last_grant_request.production_evidence as Dictionary).session_instance_id)
				== host.fake_session.get_instance_id(),
		"the external authority receives the fenced actor/session commit witness",
	)
	_check(
		binding.call(
			&"_commit_pending_relay_reward", envelope, composition.activity
		) == &"relay_reward_replayed"
			and _grant_calls == 1,
		"a same-generation reward replay cannot call authority or persistence",
	)
	root.remove_child(binding)
	root.add_child(binding)
	var reentered := binding.get_snapshot().relay_reward_commit as Dictionary
	_check(
		int(reentered.authority_commit_count) == 1
			and int(reentered.persistence_commit_count) == 1
			and not (reentered.commit_receipt as Dictionary).is_empty()
			and _grant_calls == 1,
		"whole-binding detach/re-entry retains the exactly-once commit fence",
	)

	print("EMBER_SURFACE_LOOP_RELAY_SURVEY_API_TEST_OK: 8 assertions")
	quit(0)


func _grant_reward(request: Dictionary) -> Dictionary:
	_grant_calls += 1
	_last_grant_request = request.duplicate(true)
	return {"accepted": true, "reason": &"game_flow_reward_committed"}


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
