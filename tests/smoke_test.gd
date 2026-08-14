extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	_check(main.has_method("start_shift"), "main gameplay coordinator API exists")
	_check(main.has_method("get_runtime_settings"), "main exposes persisted runtime settings")
	var world := main.get_node_or_null("ShipyardWorld")
	var player := main.get_node_or_null("Player")
	var ship := main.get_node_or_null("TorrentInterceptor")
	var arrow_ship := main.get_node_or_null("ArrowReconShip")
	var jovian_ship := main.get_node_or_null("JovianLightFreighter")
	var zenith_ship := main.get_node_or_null("ZenithInterceptor")
	var opponent := main.get_node_or_null("RangeOpponent")
	var hud := main.get_node_or_null("HUD")
	var pulse_presentation := main.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	_check(world != null, "shipyard world is instantiated")
	_check(player != null, "physical player is instantiated")
	_check(ship != null, "Torrent interceptor is physically parked")
	_check(arrow_ship is ArrowReconShip, "the provisional Arrow recon craft is physically parked")
	_check(jovian_ship is JovianLightFreighter, "the provisional Jovian light freighter is physically parked")
	_check(zenith_ship is ZenithInterceptor, "the B7-observed Zenith interceptor is physically parked")
	var fleet: Array[HeroShip] = main.call("get_flyable_ships")
	_check(fleet.size() == 4, "production scene registers exactly four physical flyable craft")
	_check(fleet.has(ship) and fleet.has(arrow_ship) and fleet.has(jovian_ship) and fleet.has(zenith_ship), "fleet registry contains Torrent, Arrow, Jovian, and Zenith")
	_check(main.get_node_or_null("ReserveInterceptor") == null, "retired duplicate Torrent article is absent")
	_check(opponent != null, "opposing interceptor is staged in the shared world")
	_check(hud != null, "HUD is instantiated")
	_check(
		pulse_presentation != null and bool(pulse_presentation.get_audit_report().valid),
		"production scene owns one valid bounded pulse presentation pool"
	)
	var expected_audio_profiles := {
		&"torrent_provisional": &"standard_fighter",
		&"arrow_provisional": &"efficient_twin_recon",
		&"jovian_provisional": &"heavy_quad_freighter",
		&"zenith_b7_observed": &"standard_fighter",
	}
	for fleet_ship in fleet:
		var rig := fleet_ship.get_ship_audio_rig()
		_check(
			rig != null
			and bool(rig.get_audit_report().valid)
			and rig.get_profile_id() == expected_audio_profiles.get(fleet_ship.get_ship_id(), &""),
			"%s owns its exact valid ship-local audio profile" % fleet_ship.name
		)

	if world != null:
		_check(world.has_method("get_player_spawn"), "world exposes player spawn")
		_check(world.has_method("get_ship_spawn"), "world exposes ship spawn")
		_check(world.has_method("is_landing_position"), "world exposes landing test")
		_check(world.has_method("get_berth_ids"), "world exposes a physical berth registry")
		_check(world.call("get_berth_ids").size() == 4, "world provides exactly four production landing berths")
		_check(world.has_method("get_ship_berth_feedback_nodes"), "world exposes exact berth-feedback discovery")
		var berth_feedback_nodes: Array = world.call("get_ship_berth_feedback_nodes")
		_check(berth_feedback_nodes.size() == 4, "each authoritative production berth owns one visual feedback component")
		var feedback_audit: Dictionary = world.call("get_ship_berth_feedback_audit_report")
		_check(
			bool(feedback_audit.get("valid", false))
			and int(feedback_audit.get("component_count", 0)) == 4,
			"the complete production berth-feedback roster passes its fail-red audit"
		)
		for feedback in berth_feedback_nodes:
			_check(
				feedback is ShipBerthFeedback
				and feedback.get_parent() is ShipBerth
				and feedback.get_feedback_state() == &"occupied",
				"production berth feedback begins synchronized to its occupied physical lease"
			)
		_check(world.has_method("apply_visual_quality"), "world supports live graphics profiles")
	if player != null:
		_check(player.has_method("set_control_enabled"), "player supports control handoff")
		_check(player.has_method("get_interaction_origin"), "player supports physical interaction")
		_check(player.has_method("set_camera_fov"), "player accepts shared camera FOV settings")
	if ship != null:
		_check(ship.has_method("set_piloted"), "ship supports physical piloting handoff")
		_check(ship.has_method("request_engine_start"), "ship has explicit engine startup")
		_check(ship.has_method("request_landing"), "ship supports landing")
		_check(ship.has_method("get_exit_transform"), "ship supports same-world exit")
		_check(ship.has_method("get_pilot_seat_anchor"), "ship exposes a physical pilot seat")
		_check(ship.has_method("set_canopy_open"), "ship exposes an animated canopy")
		_check(ship.has_method("set_camera_fov"), "ship accepts shared camera FOV settings")
		_check(ship.has_method("set_cockpit_view"), "ship exposes physical cockpit camera selection")
		var telemetry: Dictionary = ship.call("get_telemetry")
		_check(telemetry.has("speed"), "ship reports speed")
		_check(telemetry.has("engine_state"), "ship reports engine state")
	if arrow_ship != null:
		_check(arrow_ship.call("get_ship_id") == &"arrow_provisional", "Arrow exposes its stable provisional identity")
		_check(arrow_ship.call("get_home_berth_id") == &"arrow_recon_berth", "Arrow owns the dedicated recon berth")
		_check(arrow_ship.has_method("reset_for_reuse"), "Arrow supports same-world regeneration")
		_check(arrow_ship.get_node_or_null("ShipBoardingArea") != null, "Arrow has a physical interaction volume")
		_check(not arrow_ship.call("get_ship_id") == ship.call("get_ship_id"), "flyable ship IDs are unique")
	if jovian_ship != null:
		_check(jovian_ship.call("get_ship_id") == &"jovian_provisional", "Jovian exposes its stable provisional identity")
		_check(jovian_ship.call("get_home_berth_id") == &"jovian_freight_berth", "Jovian owns the dedicated freight berth")
		_check(jovian_ship.get_node_or_null("ShipBoardingArea") != null, "Jovian has a physical interaction volume")
		_check(
			jovian_ship.call("get_ship_id") != ship.call("get_ship_id")
			and jovian_ship.call("get_ship_id") != arrow_ship.call("get_ship_id"),
			"Jovian's stable ID is unique within the production fleet"
		)
		if world != null and world.has_method("get_berth_node"):
			var jovian_berth := world.call("get_berth_node", &"jovian_freight_berth") as ShipBerth
			_check(
				jovian_berth != null
				and jovian_berth.get_reservation_owner() == jovian_ship
				and jovian_berth.get_occupant() == jovian_ship
				and jovian_berth.get_reserved_ship_id() == &"jovian_provisional",
				"Jovian begins with the authoritative occupied lease for its freight berth"
			)
	if zenith_ship != null:
		_check(zenith_ship.call("get_ship_id") == &"zenith_b7_observed", "Zenith exposes its stable B7-observed identity")
		_check(zenith_ship.call("get_home_berth_id") == &"zenith_fleet_dock_berth", "Zenith owns the assigned fleet-dock berth")
		_check(zenith_ship.get_node_or_null("ShipBoardingArea") != null, "Zenith has a physical interaction volume")
		_check(
			zenith_ship.call("get_ship_id") != ship.call("get_ship_id")
			and zenith_ship.call("get_ship_id") != arrow_ship.call("get_ship_id")
			and zenith_ship.call("get_ship_id") != jovian_ship.call("get_ship_id"),
			"Zenith's stable ID is unique within the production fleet"
		)
		if world != null and world.has_method("get_berth_node"):
			var zenith_berth := world.call("get_berth_node", &"zenith_fleet_dock_berth") as ShipBerth
			_check(
				zenith_berth != null
				and zenith_berth.get_reservation_owner() == zenith_ship
				and zenith_berth.get_occupant() == zenith_ship
				and zenith_berth.get_reserved_ship_id() == &"zenith_b7_observed",
				"Zenith begins with the authoritative occupied lease for fleet dock 01"
			)
	if opponent != null:
		_check(opponent.has_method("activate"), "opposing interceptor supports encounter activation")
		_check(opponent.has_method("apply_damage"), "opposing interceptor participates in damage")
		_check(opponent.has_method("is_active"), "opposing interceptor exposes encounter state")
		_check(not bool(opponent.call("is_active")), "opposing interceptor starts dormant")
	if hud != null:
		_check(hud.has_method("set_enemy_status"), "HUD exposes opposing craft status")
		_check(hud.has_method("flash_damage"), "HUD exposes directional hull feedback")
		_check(hud.has_method("set_settings_snapshot"), "HUD exposes guarded settings population")
		_check(hud.has_signal("setting_change_requested"), "HUD exposes live setting requests")
		if jovian_ship != null:
			hud.call("update_ship_telemetry", jovian_ship.call("get_telemetry"))
			var hull_bar := hud.get("_hull_bar") as ProgressBar
			_check(
				hull_bar != null and is_equal_approx(hull_bar.value, 100.0),
				"HUD normalizes full hull correctly for craft with more than 100 durability"
			)

	var settings: RuntimeSettings = null
	if main.has_method("get_runtime_settings"):
		settings = main.call("get_runtime_settings") as RuntimeSettings
	_check(settings != null, "runtime settings have a strong gameplay owner")
	if settings != null and hud != null and ship != null:
		var original_sensitivity := settings.ship_mouse_sensitivity
		var requested_sensitivity := minf(original_sensitivity + 0.0007, RuntimeSettings.MAX_SHIP_MOUSE_SENSITIVITY)
		hud.emit_signal("setting_change_requested", &"ship_mouse_sensitivity", requested_sensitivity)
		_check(
			is_equal_approx(settings.ship_mouse_sensitivity, requested_sensitivity)
			and is_equal_approx(float(ship.get("mouse_sensitivity")), requested_sensitivity),
			"pause setting requests apply immediately to flight controls"
		)
		hud.emit_signal("setting_change_requested", &"ship_mouse_sensitivity", original_sensitivity)

	if main.has_method("start_shift"):
		main.call("start_shift")
		await process_frame
		_check(player == null or player.call("is_control_enabled"), "start grants on-foot control")
		if hud != null:
			_check(
				_has_visible_label_text(hud, "INTERACT / BOARD"),
				"on-foot mode populates the controls panel instead of leaving an empty frame"
			)
	if player != null:
		_check(player.has_method("begin_boarding"), "player supports visible boarding transitions")
		_check(player.has_method("begin_disembark"), "player supports visible disembarking transitions")
		_check(player.has_method("force_recovery_to_on_foot"), "player supports destructive transition recovery")
		_check(player.has_method("is_seated"), "player exposes physical seated state")

	main.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_finish()


func _has_visible_label_text(search_root: Node, text_fragment: String) -> bool:
	for candidate in search_root.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label != null and text_fragment in label.text:
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE_TEST_OK")
		quit(0)
	else:
		print("SMOKE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
