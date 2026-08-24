extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

const VIEWPORTS := [
	Vector2(1180.0, 690.0),
	Vector2(1280.0, 720.0),
	# Exact physical sizes from the composed-state screenshots that exposed the
	# caption/card/reticle collision after the ordinary panel sweep was green.
	Vector2(1712.0, 963.0),
	Vector2(1900.0, 1068.0),
	Vector2(1920.0, 1080.0),
]
const REQUESTED_SCALES := [1.0, 1.6]

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	await _seed_composed_hud(hud)
	_check(
		hud.apply_first_sortie_tutorial_snapshot({
			"step_id": &"board", "generation": 8, "revision": 1,
		}),
		"tutorial supplies the ordinary runtime card",
	)
	await _check_composed_rects(hud, &"runtime_status")
	_check(
		hud.apply_bomber_payload_snapshot({
			"generation": 1, "active": true, "ammo": 2, "cooldown_remaining": 0.0,
		}),
		"bomber supplies the dedicated payload band",
	)
	await _check_composed_rects(hud, &"bomber_payload")
	_check(
		hud.clear_runtime_status_card(&"surface") == false
		and (hud.get("_bomber_status_panel") as Control).visible,
		"clearing an absent source cannot erase the active bomber card",
	)
	var bomber_actions := hud.get("_bomber_status_actions") as HBoxContainer
	var bomber_action := bomber_actions.get_child(0) as Button
	bomber_action.grab_focus()
	await process_frame
	_check(
		hud.set_runtime_status_card(
			&"surface", {"title": "SURFACE ROUTE", "message": "Background update"}
		)
		and bomber_actions.get_child(0) == bomber_action
		and hud.get_viewport().gui_get_focus_owner() == bomber_action,
		"ordinary background update preserves the focused bomber action instance",
	)
	_check(
		hud.clear_runtime_status_card(&"surface")
		and bomber_actions.get_child(0) == bomber_action
		and hud.get_viewport().gui_get_focus_owner() == bomber_action,
		"ordinary background clear preserves the focused bomber action instance",
	)
	_check(
		hud.apply_bomber_payload_snapshot({
			"generation": 2,
			"active": true,
			"ammo": 1,
			"cooldown_remaining": 1.5,
			"action_id": &"fire",
		}),
		"the longest ordinary cooldown status reaches the compact bomber band",
	)
	await _check_composed_rects(hud, &"bomber_payload")
	var cooldown_detail := (hud.get("_bomber_status_detail") as Label).text
	_check(
		cooldown_detail.contains("[WAIT]")
		and cooldown_detail.contains("STATE // COOLDOWN")
		and cooldown_detail.contains("PAYLOADS REMAINING // 1")
		and cooldown_detail.contains("COOLDOWN // 1.5 S")
		and cooldown_detail.contains("NEXT // HOLD 1.5 S TO RELEASE"),
		"the bounded bomber band retains phase, ammo, cooldown, and NEXT semantics",
	)
	_check(
		hud.apply_bomber_payload_snapshot({
			"generation": 3,
			"active": true,
			"ammo": 1,
			"cooldown_remaining": 0.0,
			"action_id": &"fire",
		}),
		"a newer armed status restores the actionable payload row",
	)
	var restored_bomber_action := (
		(hud.get("_bomber_status_actions") as HBoxContainer).get_child(0) as Button
	)
	restored_bomber_action.grab_focus()
	await process_frame
	_check(
		hud.get_viewport().gui_get_focus_owner() == restored_bomber_action,
		"the compact bomber action remains controller-focusable after a phase transition",
	)
	hud.clear_bomber_payload_status()
	_check(
		(hud.get("_runtime_status_panel") as Control).visible
		and not (hud.get("_bomber_status_panel") as Control).visible,
		"bomber clear restores the retained tutorial composition",
	)
	hud.update_copilot_navigation_support({
		"role": "copilot",
		"occupant": "Mira",
		"request_state": "pending",
	})
	var cards := hud.get("_runtime_status_cards") as Dictionary
	var copilot_serial := int((cards[&"copilot"] as Dictionary).get("serial", -1))
	var tutorial_serial := int((cards[&"tutorial"] as Dictionary).get("serial", -1))
	var copilot_action := (hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) as Button
	copilot_action.grab_focus()
	await process_frame
	hud.call("_refresh_input_prompts")
	await process_frame
	cards = hud.get("_runtime_status_cards") as Dictionary
	_check(
		hud.get("_runtime_status_kind") == &"copilot"
		and int((cards[&"copilot"] as Dictionary).get("serial", -1)) == copilot_serial
		and int((cards[&"tutorial"] as Dictionary).get("serial", -1)) == tutorial_serial
		and hud.get_viewport().gui_get_focus_owner() == copilot_action,
		"tutorial prompt refresh retains copilot foreground serial and focus",
	)
	hud.clear_first_sortie_tutorial(&"session_lost")
	await process_frame
	_check(
		not (hud.get("_runtime_status_cards") as Dictionary).has(&"tutorial")
		and hud.get("_runtime_status_kind") == &"copilot"
		and (hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) == copilot_action
		and hud.get_viewport().gui_get_focus_owner() == copilot_action,
		"background tutorial clear preserves the focused copilot action instance",
	)
	_check(
		hud.apply_first_sortie_tutorial_snapshot({
			"step_id": &"board", "generation": 9, "revision": 1,
		}),
		"tutorial can reactivate after its background owner was cleared",
	)
	hud.update_loadmaster_telemetry({
		"role": "loadmaster",
		"occupant": "Rhea",
		"manifest_state": "review",
	})
	cards = hud.get("_runtime_status_cards") as Dictionary
	var loadmaster_serial := int((cards[&"loadmaster"] as Dictionary).get("serial", -1))
	tutorial_serial = int((cards[&"tutorial"] as Dictionary).get("serial", -1))
	var loadmaster_action := (hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) as Button
	loadmaster_action.grab_focus()
	await process_frame
	hud.call("_refresh_input_prompts")
	await process_frame
	cards = hud.get("_runtime_status_cards") as Dictionary
	_check(
		hud.get("_runtime_status_kind") == &"loadmaster"
		and int((cards[&"loadmaster"] as Dictionary).get("serial", -1)) == loadmaster_serial
		and int((cards[&"tutorial"] as Dictionary).get("serial", -1)) == tutorial_serial
		and hud.get_viewport().gui_get_focus_owner() == loadmaster_action,
		"tutorial prompt refresh retains loadmaster foreground serial and focus",
	)
	var copilot_background := (
		(cards[&"copilot"] as Dictionary).get("snapshot", {}) as Dictionary
	).duplicate(true)
	copilot_background["message"] = "Background support updated"
	_check(
		hud.set_runtime_status_card(&"copilot", copilot_background, false)
		and (hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) == loadmaster_action
		and hud.get_viewport().gui_get_focus_owner() == loadmaster_action,
		"copilot background update preserves the focused loadmaster action instance",
	)
	hud.clear_copilot_navigation_support()
	await process_frame
	_check(
		not (hud.get("_runtime_status_cards") as Dictionary).has(&"copilot")
		and hud.get("_runtime_status_kind") == &"loadmaster"
		and (hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) == loadmaster_action
		and hud.get_viewport().gui_get_focus_owner() == loadmaster_action,
		"copilot background clear preserves the focused loadmaster action instance",
	)
	# The network presenter publishes the longest currently bounded ordinary
	# status: ownership transfer, denial notices, and all four retained history
	# receipts. It must overflow only inside the scroll body; title and actions
	# stay visible and the panel itself remains in the composed band.
	hud.update_network_session_status(_network_snapshot(20, 40, 2, []))
	hud.update_network_session_status(_network_snapshot(21, 41, 7, [
		"Host accepted the production session generation",
		"Craft ownership transferred to remote peer seven",
		"Pilot seat ownership changed during host migration",
		"Local controls fenced pending authoritative recovery",
	]))
	await _check_composed_rects(hud, &"runtime_status")
	var runtime_panel := hud.get("_runtime_status_panel") as PanelContainer
	var runtime_scroll := hud.get("_runtime_status_scroll") as ScrollContainer
	var runtime_actions := hud.get("_runtime_status_actions") as HBoxContainer
	var runtime_detail := hud.get("_runtime_status_detail") as Label
	var disconnect := runtime_actions.get_child(0) as Button
	var runtime_panel_rect := runtime_panel.get_global_rect().grow(0.1)
	_check(
		runtime_panel_rect.encloses(runtime_scroll.get_global_rect())
		and runtime_panel_rect.encloses(runtime_actions.get_global_rect())
		and runtime_scroll.get_v_scroll_bar().max_value
			> runtime_scroll.get_v_scroll_bar().page
		and runtime_detail.text.contains("TRANSFER // CINDER_LONG_RANGE_BOMBER")
		and runtime_detail.text.contains(
			"HISTORY // LOCAL CONTROLS FENCED PENDING AUTHORITATIVE RECOVERY"
		)
		and disconnect.text == "Disconnect",
		"the longest network body scrolls internally while its full action remains visible",
	)
	disconnect.grab_focus()
	await process_frame
	_check(
		hud.get_viewport().gui_get_focus_owner() == disconnect,
		"the action outside the runtime scroll body retains controller focus",
	)
	_check(
		hud.clear_runtime_status_card(&"network"),
		"clearing the longest network owner restores the retained keyed background",
	)
	hud.clear_runtime_status()
	hud.call("_refresh_input_prompts")
	await process_frame
	_check(
		(hud.get("_runtime_status_cards") as Dictionary).is_empty()
		and (hud.get("_first_sortie_tutorial_source_snapshot") as Dictionary).is_empty()
		and not (hud.get("_runtime_status_panel") as Control).visible,
		"legacy runtime all-clear retires tutorial redraw state without resurrection",
	)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RUNTIME_STATUS_CARD_COMPOSITION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_composed_rects(hud: GameHUD, active_key: StringName) -> void:
	for viewport in VIEWPORTS:
		for requested_scale in REQUESTED_SCALES:
			hud.set_ui_scale(requested_scale)
			var effective := hud.layout_for_viewport(viewport)
			await process_frame
			await process_frame
			var rects := hud.get_hud_panel_rects()
			var key := String(active_key)
			var inactive_key := "bomber_payload" if key == "runtime_status" else "runtime_status"
			var active_rect := rects.get(key, Rect2()) as Rect2
			print("MEASURED: %s %.0fx%.0f scale %.2f -> %s" % [key, viewport.x, viewport.y, requested_scale, str(active_rect)])
			var overlaps: PackedStringArray = []
			for other_key_variant: Variant in rects.keys():
				var other_key := str(other_key_variant)
				if other_key == key:
					continue
				if other_key == "caption" and not (hud.get("_caption_presenter") as Control).visible:
					continue
				var intersection := active_rect.intersection(rects[other_key] as Rect2)
				if intersection.size.x > 0.0 and intersection.size.y > 0.0:
					overlaps.append(other_key)
			var reticle_rect := _visible_control_tree_rect(
				hud.get("_reticle") as Control
			)
			# The reticle intentionally remains in one-to-one camera space, outside
			# the scaled panel layer. Headless windows cannot be resized reliably,
			# so translate the live anchored rect to the explicit viewport centre.
			reticle_rect.position += (
				viewport - hud.get_viewport().get_visible_rect().size
			) * 0.5
			var active_physical := Rect2(
				active_rect.position * effective, active_rect.size * effective
			)
			var caption_physical := Rect2()
			if rects.has("caption"):
				var caption_logical := rects["caption"] as Rect2
				caption_physical = Rect2(
					caption_logical.position * effective,
					caption_logical.size * effective
				)
			var interaction_logical := rects.get("interaction", Rect2()) as Rect2
			var interaction_physical := Rect2(
				interaction_logical.position * effective,
				interaction_logical.size * effective
			)
			var viewport_physical := Rect2(Vector2.ZERO, viewport)
			var caption_reticle_overlap := caption_physical.intersection(reticle_rect)
			var card_reticle_overlap := active_physical.intersection(reticle_rect)
			var card_caption_overlap := active_physical.intersection(caption_physical)
			var card_interaction_overlap := active_physical.intersection(
				interaction_physical
			)
			var composed_clear := (
				viewport_physical.encloses(active_physical)
				and viewport_physical.encloses(reticle_rect)
				and card_reticle_overlap.size.x * card_reticle_overlap.size.y <= 0.0
				and caption_reticle_overlap.size.x * caption_reticle_overlap.size.y <= 0.0
				and card_caption_overlap.size.x * card_caption_overlap.size.y <= 0.0
				and card_interaction_overlap.size.x * card_interaction_overlap.size.y <= 0.0
			)
			_check(
				rects.has(key)
				and not rects.has(inactive_key)
				and active_rect.size.x > 0.0
				and active_rect.size.y > 0.0
				and overlaps.is_empty(),
				"%s is registered and disjoint at %.0fx%.0f scale %.2f%s" % [
					key, viewport.x, viewport.y, requested_scale,
					"" if overlaps.is_empty() else " (overlaps " + ", ".join(overlaps) + ")",
				],
			)
			_check(
				composed_clear,
				(
					"%s, caption, full reticle, and interaction have no positive-area "
					+ "intersection at %.0fx%.0f scale %.2f"
				) % [key, viewport.x, viewport.y, requested_scale],
			)


func _seed_composed_hud(hud: GameHUD) -> void:
	hud.set("_started", true)
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	hud.set_mode("piloting")
	hud.set_ship_identity("Cinder long-range bomber", "Long-range bomber")
	hud.set_interaction(
		"Clear the berth before requesting a return approach", true
	)
	hud.set_target_lock_state(&"acquired", "Mudds range defence interceptor")
	hud.set_captions_enabled(true)
	var service := CaptionPresentationService.new()
	service.enqueue(CaptionPresentationEvent.new(
		&"layout.composed-status",
		CaptionPresentationEvent.Category.AMBIENT,
		"S".repeat(CaptionPresentationEvent.MAX_SPEAKER_LENGTH),
		"[ hostile craft destroyed ]",
		12.0,
		90
	))
	_check(
		hud.apply_caption_presentation_snapshot(service.get_presentation_snapshot()),
		"the composed regression shows the production caption presenter",
	)
	await process_frame
	await process_frame


func _visible_control_tree_rect(control: Control) -> Rect2:
	var combined := control.get_global_rect()
	for candidate_variant: Variant in control.find_children("*", "Control", true, false):
		var candidate := candidate_variant as Control
		if candidate.visible:
			combined = combined.merge(candidate.get_global_rect())
	return combined


func _network_snapshot(
	sequence: int, revision: int, owner_peer_id: int, history: Array
) -> Dictionary:
	return {
		"generation": 20,
		"sequence": sequence,
		"state": &"connected",
		"local_role": &"pilot",
		"local_peer_id": 2,
		"peer_generation": 99,
		"session_generation": 99,
		"controlled_craft": "Cinder long-range bomber production prototype",
		"controlled_craft_id": &"cinder_long_range_bomber",
		"detail": (
			"Session ready; authoritative ownership changed while the local pilot "
			+ "controls remain fenced."
		),
		"history": history,
		"authoritative_snapshot": {
			"authority_peer_id": 1,
			"revision": revision,
			"sections": {
				&"ownership": [{
					"ship_id": &"cinder_long_range_bomber",
					"ship_generation": 1,
					"owner_peer_id": owner_peer_id,
					"ownership_generation": 2 if owner_peer_id == 2 else 3,
				}],
				&"boarding": [{
					"seat_id": &"cinder_long_range_bomber_pilot",
					"seat_generation": 1,
					"occupant_peer_id": owner_peer_id,
					"avatar_id": &"production_pilot_avatar",
					"vessel_id": &"cinder_long_range_bomber",
					"role": &"pilot",
				}],
			},
		},
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
