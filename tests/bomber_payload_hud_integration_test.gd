extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const GameFlowType := preload("res://scripts/game/game_flow.gd")
const AuthorityType := preload("res://scripts/combat/bomber_payload_authority.gd")
const ProjectileType := preload("res://scripts/combat/bomber_payload_projectile.gd")
const AdapterType := preload("res://scripts/combat/bomber_payload_combat_adapter.gd")
var _assertions := 0
var _failures: PackedStringArray = []
var _intents: Array[Dictionary] = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	_check(GameFlowType != null, "production bomber HUD coordinator compiles")
	var hud := HudType.new()
	hud.presentation_intent_requested.connect(_on_intent)
	root.add_child(hud)
	await process_frame
	_check(hud.set_runtime_status_card(&"surface", {"title": "SURFACE ROUTE", "message": "CLEAR"}), "a non-bomber runtime owner registers independently")
	_check(hud.apply_bomber_payload_snapshot({"generation": 1, "active": true, "ammo": 2, "cooldown_remaining": 0.0, "action_glyph": "A"}), "ready bomber snapshot renders")
	var panel := hud.get("_bomber_status_panel") as PanelContainer
	_check(panel.visible and not (hud.get("_runtime_status_panel") as PanelContainer).visible and (hud.get("_bomber_status_title") as Label).text == "BOMBER PAYLOAD", "bomber status uses its dedicated foreground band")
	var action_button := (hud.get("_bomber_status_actions") as HBoxContainer).get_child(0) as Button
	var ready_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(ready_detail.contains("[ARMED]") and ready_detail.contains("NEXT // RELEASE PAYLOAD") and ready_detail.contains("PAYLOADS REMAINING // 2") and action_button.text.contains("RELEASE PAYLOAD") and action_button.focus_mode == Control.FOCUS_ALL, "armed state gives a text-first next action without changing action focus")
	var release := hud.request_bomber_payload_release()
	_check(bool(release.accepted) and _intents.size() == 1 and _intents[0].kind == &"bomber", "release emits a caller-owned presentation intent")
	action_button.pressed.emit()
	_check(_intents.size() == 2 and _intents[1].kind == &"bomber", "focused action row routes through the same release intent")
	hud.apply_bomber_payload_snapshot({"generation": 2, "active": true, "ammo": 1, "cooldown_remaining": 1.5, "action_glyph": "Cross", "reduced_motion": true})
	await process_frame
	var cooldown_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(cooldown_detail.contains("[WAIT]") and cooldown_detail.contains("PAYLOADS REMAINING // 1") and cooldown_detail.contains("COOLDOWN // 1.5 S") and (hud.get("_bomber_status_actions") as HBoxContainer).get_child_count() == 0, "cooldown state shows remaining payloads and seconds")
	hud.apply_bomber_payload_snapshot({"generation": 3, "active": true, "ammo": 0, "cooldown_remaining": 0.0, "denied_reason": "hardpoint_locked"})
	await process_frame
	var denied_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(denied_detail.contains("[DENIED]") and denied_detail.contains("UNAVAILABLE // HARDPOINT_LOCKED"), "denied state shows an explicit unavailable reason")
	var authority := AuthorityType.new(1, 2, 0.0)
	var adapter := AdapterType.new(1)
	_check(bool(authority.begin_generation(4).accepted) and bool(adapter.begin_generation(4).accepted), "production payload sources begin one HUD generation")
	var armed := _local_snapshot(authority, [], adapter.get_snapshot())
	_check(hud.apply_bomber_payload_snapshot(armed), "a newer payload actor generation is admitted")
	var first_record := _release(authority, 4, 1)
	var first_projectile := ProjectileType.new(1, Vector3.ZERO, 10.0, 500.0, 100_000.0)
	first_projectile.begin_generation(4)
	first_projectile.consume_release_record(1, first_record)
	first_projectile.advance(1.0)
	var flying := _local_snapshot(authority, [first_projectile.get_snapshot()], adapter.get_snapshot())
	_check(hud.apply_bomber_payload_snapshot(flying), "an exact release receipt advances the payload HUD")
	await process_frame
	var flight_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(flight_detail.contains("[IN FLIGHT]") and flight_detail.contains("PAYLOAD IN FLIGHT") and flight_detail.contains("NEXT // RELEASE ANOTHER PAYLOAD") and flight_detail.contains("PAYLOADS REMAINING // 1"), "release and flight show status, ammo, and the next available action in text")
	_check(not hud.apply_bomber_payload_snapshot(armed) and (hud.get("_bomber_status_detail") as Label).text == flight_detail, "a stale same-generation pre-release receipt cannot repaint flight status")
	first_projectile.advance(1.0)
	var progressed_flight := _local_snapshot(authority, [first_projectile.get_snapshot()], adapter.get_snapshot())
	_check(hud.apply_bomber_payload_snapshot(progressed_flight), "monotonic flight progress remains presentable within one release sequence")
	var first_position := first_projectile.get_snapshot().get("position", Vector3.ZERO) as Vector3
	first_projectile.submit_impact(1, first_position, Vector3.UP)
	var resolved_adapter := adapter.get_snapshot()
	resolved_adapter["last_release_sequence"] = 1
	var impact := _local_snapshot(authority, [first_projectile.get_snapshot()], resolved_adapter)
	_check(hud.apply_bomber_payload_snapshot(impact), "the matching terminal sequence advances the flight receipt")
	await process_frame
	var impact_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(impact_detail.contains("[IMPACT]") and impact_detail.contains("IMPACT CONFIRMED") and impact_detail.contains("NEXT // RELEASE NEXT PAYLOAD"), "impact confirmation names the next release action without relying on colour")
	_check(not hud.apply_bomber_payload_snapshot(flying) and (hud.get("_bomber_status_detail") as Label).text == impact_detail, "a reordered flight receipt cannot repaint a terminal result")
	var second_record := _release(authority, 4, 2)
	var second_projectile := ProjectileType.new(1, Vector3.ZERO, 0.5, 500.0, 100_000.0)
	second_projectile.begin_generation(4)
	second_projectile.consume_release_record(1, second_record)
	var next_flight := _local_snapshot(authority, [
		second_projectile.get_snapshot(), first_projectile.get_snapshot(),
	], resolved_adapter)
	_check(hud.apply_bomber_payload_snapshot(next_flight), "a newer live payload advances beyond the retained impact receipt")
	await process_frame
	var next_flight_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(next_flight_detail.contains("PAYLOAD IN FLIGHT") and not next_flight_detail.contains("2 PAYLOADS IN FLIGHT"), "a retained terminal tombstone is not counted as a live payload")
	second_projectile.advance(0.5)
	resolved_adapter["last_release_sequence"] = 2
	var expiry := _local_snapshot(authority, [second_projectile.get_snapshot()], resolved_adapter)
	_check(hud.apply_bomber_payload_snapshot(expiry), "a newer release sequence admits its terminal receipt")
	await process_frame
	var expiry_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(expiry_detail.contains("[EXPIRED]") and expiry_detail.contains("PAYLOAD EXPIRED") and expiry_detail.contains("NO FURTHER RELEASE AVAILABLE") and expiry_detail.contains("PAYLOADS REMAINING // 0"), "expiry and exhausted ammo produce an explicit text next action")
	var stale_request := expiry.duplicate(true)
	var stale_request_projectile := (stale_request.projectiles as Array)[0] as Dictionary
	stale_request_projectile.release_sequence = 3
	(stale_request_projectile.release_record as Dictionary).release_sequence = 3
	(stale_request_projectile.terminal_intent as Dictionary).release_sequence = 3
	_check(not hud.apply_bomber_payload_snapshot(stale_request) and (hud.get("_bomber_status_detail") as Label).text == expiry_detail, "a future release cannot carry a stale request sequence")
	var mismatched_terminal := expiry.duplicate(true)
	(((mismatched_terminal.projectiles as Array)[0] as Dictionary).terminal_intent as Dictionary).kind = &"impact"
	_check(not hud.apply_bomber_payload_snapshot(mismatched_terminal) and (hud.get("_bomber_status_detail") as Label).text == expiry_detail, "one terminal sequence cannot repaint expiry as impact")
	var replica_authority := AuthorityType.new(1, 2, 0.0)
	replica_authority.begin_generation(5)
	var replica_record := _release(replica_authority, 5, 1)
	var replica_projectile := ProjectileType.new(1, Vector3.ZERO, 10.0, 500.0, 100_000.0)
	replica_projectile.begin_generation(5)
	replica_projectile.consume_release_record(1, replica_record)
	var network_flight := _network_projectile(replica_projectile.get_snapshot(), 40, false)
	_check(hud.apply_bomber_payload_snapshot(_replica_snapshot(network_flight)), "a validated production network projectile shape reaches the HUD")
	await process_frame
	var network_flight_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(network_flight_detail.contains("[IN FLIGHT]") and network_flight_detail.contains("NEXT // TRACK SERVER AUTHORITY") and (hud.get("_bomber_status_actions") as HBoxContainer).get_child_count() == 0, "a replica is readable but exposes no local release action")
	var abort_projectile := _network_projectile(replica_projectile.get_snapshot(), 41, true)
	var abort := _replica_snapshot(abort_projectile)
	_check(hud.apply_bomber_payload_snapshot(abort), "a newer actor generation admits its exact abort tombstone")
	await process_frame
	var abort_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(abort_detail.contains("[ABORTED]") and abort_detail.contains("RELEASE ABORTED") and abort_detail.contains("NEXT // STAND BY"), "an authority-detach abort is visible as text and offers no release action")
	_check(not hud.apply_bomber_payload_snapshot(expiry) and (hud.get("_bomber_status_detail") as Label).text == abort_detail, "a stale actor generation cannot repaint a newer abort tombstone")
	hud.clear_bomber_payload_status()
	_check(
		not panel.visible
		and (hud.get("_runtime_status_panel") as PanelContainer).visible
		and (hud.get("_runtime_status_title") as Label).text == "SURFACE ROUTE",
		"bomber detach clears only its owner and restores the retained runtime card"
	)
	_check(hud.apply_bomber_payload_snapshot({"generation": 1, "active": true, "ammo": 1, "cooldown_remaining": 0.0}), "detach clears generation and sequence cursors for actor reuse")
	await process_frame
	_check((hud.get("_bomber_status_detail") as Label).text.contains("[ARMED]"), "a reused presenter cannot inherit the lost actor's abort state")
	hud.clear_bomber_payload_status()
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOMBER_PAYLOAD_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _on_intent(kind: StringName, payload: Dictionary) -> void:
	_intents.append({"kind": kind, "payload": payload.duplicate(true)})


func _local_snapshot(authority, projectiles: Array, adapter: Dictionary) -> Dictionary:
	var authority_snapshot := authority.get_snapshot() as Dictionary
	return {
		"generation": int(authority_snapshot.generation),
		"active": bool(authority_snapshot.active),
		"ammo": int(authority_snapshot.ammunition_remaining),
		"cooldown_remaining": float(authority_snapshot.cooldown_remaining),
		"release_allowed": true,
		"projectiles": projectiles,
		"adapter": adapter.duplicate(true),
	}


func _release(authority, generation: int, request_sequence: int) -> Dictionary:
	var result := authority.submit_release_intent(1, &"player_pilot", {
		"generation": generation,
		"payload_id": &"cinder_payload_alpha",
		"weapon_id": &"bomber_payload_release",
		"presentation_id": &"cinder_payload_trail",
		"audio_id": &"bomber_payload_release",
		"release_position": Vector3.ZERO,
		"release_velocity": Vector3(0.0, 0.0, -220.0),
	}, request_sequence) as Dictionary
	_check(bool(result.get("accepted", false)), "production payload authority emits release %d" % request_sequence)
	return (result.get("record", {}) as Dictionary).duplicate(true)


func _network_projectile(local: Dictionary, update_tick: int, aborted: bool) -> Dictionary:
	var record := local.get("release_record", {}) as Dictionary
	var velocity := local.get("velocity", Vector3.FORWARD) as Vector3
	return {
		"projectile_id": StringName(record.get("record_id", &"")),
		"projectile_generation": int(local.get("generation", 0)),
		"source_entity_id": &"cinder_long_range_bomber",
		"source_generation": int(local.get("generation", 0)),
		"owner_peer_id": 1,
		"position": local.get("position", Vector3.ZERO),
		"direction": velocity.normalized(),
		"last_update_tick": update_tick,
		"state": &"terminal" if aborted else &"flying",
		"release_record": record.duplicate(true),
		"terminal_intent": {},
	}


func _replica_snapshot(projectile: Dictionary) -> Dictionary:
	var record := projectile.get("release_record", {}) as Dictionary
	return {
		"generation": int(projectile.get("projectile_generation", 0)),
		"active": true,
		"ammo": int(record.get("ammunition_remaining", 0)),
		"cooldown_remaining": float(record.get("cooldown_remaining", 0.0)),
		"release_allowed": false,
		"release_denied_reason": &"server_authority",
		"projectiles": [projectile.duplicate(true)],
		"adapter": {},
	}

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
