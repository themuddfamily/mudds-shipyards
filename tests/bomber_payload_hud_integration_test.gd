extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
var _assertions := 0
var _failures: PackedStringArray = []
var _intents: Array[Dictionary] = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var hud := HudType.new()
	hud.presentation_intent_requested.connect(_on_intent)
	root.add_child(hud)
	await process_frame
	_check(hud.apply_bomber_payload_snapshot({"generation": 1, "active": true, "ammo": 2, "cooldown_remaining": 0.0, "action_glyph": "A"}), "ready bomber snapshot renders")
	var panel := hud.get("_runtime_status_panel") as PanelContainer
	_check(panel.visible and (hud.get("_runtime_status_title") as Label).text == "BOMBER PAYLOAD", "bomber status uses the retained runtime panel")
	var action_button := (hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) as Button
	var ready_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(ready_detail.contains("[ARMED]") and ready_detail.contains("NEXT // RELEASE PAYLOAD") and ready_detail.contains("PAYLOADS REMAINING // 2") and action_button.text.contains("RELEASE PAYLOAD") and action_button.focus_mode == Control.FOCUS_ALL, "armed state gives a text-first next action without changing action focus")
	var release := hud.request_bomber_payload_release()
	_check(bool(release.accepted) and _intents.size() == 1 and _intents[0].kind == &"bomber", "release emits a caller-owned presentation intent")
	action_button.pressed.emit()
	_check(_intents.size() == 2 and _intents[1].kind == &"bomber", "focused action row routes through the same release intent")
	hud.apply_bomber_payload_snapshot({"generation": 2, "active": true, "ammo": 1, "cooldown_remaining": 1.5, "action_glyph": "Cross", "reduced_motion": true})
	await process_frame
	var cooldown_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(cooldown_detail.contains("[WAIT]") and cooldown_detail.contains("PAYLOADS REMAINING // 1") and cooldown_detail.contains("COOLDOWN // 1.5 S") and (hud.get("_runtime_status_actions") as HBoxContainer).get_child_count() == 0, "cooldown state shows remaining payloads and seconds")
	hud.apply_bomber_payload_snapshot({"generation": 3, "active": true, "ammo": 0, "cooldown_remaining": 0.0, "denied_reason": "hardpoint_locked"})
	await process_frame
	var denied_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(denied_detail.contains("[DENIED]") and denied_detail.contains("UNAVAILABLE // HARDPOINT_LOCKED"), "denied state shows an explicit unavailable reason")
	var armed := _payload_snapshot(4, 2, [])
	_check(hud.apply_bomber_payload_snapshot(armed), "a newer payload actor generation is admitted")
	var flying := _payload_snapshot(4, 1, [_projectile(4, 1, &"flying", &"", 1.0)])
	_check(hud.apply_bomber_payload_snapshot(flying), "an exact release receipt advances the payload HUD")
	await process_frame
	var flight_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(flight_detail.contains("[IN FLIGHT]") and flight_detail.contains("PAYLOAD IN FLIGHT") and flight_detail.contains("NEXT // RELEASE ANOTHER PAYLOAD") and flight_detail.contains("PAYLOADS REMAINING // 1"), "release and flight show status, ammo, and the next available action in text")
	_check(not hud.apply_bomber_payload_snapshot(armed) and (hud.get("_runtime_status_detail") as Label).text == flight_detail, "a stale same-generation pre-release receipt cannot repaint flight status")
	var progressed_flight := _payload_snapshot(4, 1, [_projectile(4, 1, &"flying", &"", 2.0)])
	_check(hud.apply_bomber_payload_snapshot(progressed_flight), "monotonic flight progress remains presentable within one release sequence")
	var impact := _payload_snapshot(4, 1, [_projectile(4, 1, &"terminal", &"impact", 1.0)])
	_check(hud.apply_bomber_payload_snapshot(impact), "the matching terminal sequence advances the flight receipt")
	await process_frame
	var impact_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(impact_detail.contains("[IMPACT]") and impact_detail.contains("IMPACT CONFIRMED") and impact_detail.contains("NEXT // RELEASE NEXT PAYLOAD"), "impact confirmation names the next release action without relying on colour")
	_check(not hud.apply_bomber_payload_snapshot(flying) and (hud.get("_runtime_status_detail") as Label).text == impact_detail, "a reordered flight receipt cannot repaint a terminal result")
	var expiry := _payload_snapshot(4, 0, [_projectile(4, 2, &"terminal", &"expiry", 0.5)])
	_check(hud.apply_bomber_payload_snapshot(expiry), "a newer release sequence admits its terminal receipt")
	await process_frame
	var expiry_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(expiry_detail.contains("[EXPIRED]") and expiry_detail.contains("PAYLOAD EXPIRED") and expiry_detail.contains("NO FURTHER RELEASE AVAILABLE") and expiry_detail.contains("PAYLOADS REMAINING // 0"), "expiry and exhausted ammo produce an explicit text next action")
	var abort := _payload_snapshot(5, 1, [_projectile(5, 1, &"terminal", &"", 0.0)])
	_check(hud.apply_bomber_payload_snapshot(abort), "a newer actor generation admits its exact abort tombstone")
	await process_frame
	var abort_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(abort_detail.contains("[ABORTED]") and abort_detail.contains("RELEASE ABORTED") and abort_detail.contains("NEXT // STAND BY"), "an authority-detach abort is visible as text and offers no release action")
	_check(not hud.apply_bomber_payload_snapshot(expiry) and (hud.get("_runtime_status_detail") as Label).text == abort_detail, "a stale actor generation cannot repaint a newer abort tombstone")
	hud.clear_bomber_payload_status()
	_check(not panel.visible, "detach clears bomber presentation")
	_check(hud.apply_bomber_payload_snapshot({"generation": 1, "active": true, "ammo": 1, "cooldown_remaining": 0.0}), "detach clears generation and sequence cursors for actor reuse")
	await process_frame
	_check((hud.get("_runtime_status_detail") as Label).text.contains("[ARMED]"), "a reused presenter cannot inherit the lost actor's abort state")
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


func _payload_snapshot(generation: int, ammo: int, projectiles: Array) -> Dictionary:
	return {
		"generation": generation,
		"active": true,
		"ammo": ammo,
		"cooldown_remaining": 0.0,
		"release_allowed": true,
		"projectiles": projectiles,
		"adapter": {"generation": generation, "last_release_sequence": 0},
	}


func _projectile(
		generation: int,
		sequence: int,
		state: StringName,
		terminal_kind: StringName,
		elapsed_lifetime: float
) -> Dictionary:
	var terminal := {}
	if not terminal_kind.is_empty():
		terminal = {
			"generation": generation,
			"release_sequence": sequence,
			"request_sequence": sequence,
			"terminal_sequence": 1,
			"kind": terminal_kind,
		}
	return {
		"generation": generation,
		"state": state,
		"release_sequence": sequence,
		"request_sequence": sequence,
		"elapsed_lifetime": elapsed_lifetime,
		"release_record": {
			"generation": generation,
			"release_sequence": sequence,
			"request_sequence": sequence,
		},
		"terminal_intent": terminal,
	}

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
