extends SceneTree

## Entry heat / compression reaches every flyable craft on an atmosphere world.
##
## Drives the production PlanetaryAtmosphereFlightEffects with the real Aurora
## atmosphere composition (profile and world definition) against all nine
## craft: the six authored scenes and the three Cinder craft composed from
## script exactly as FleetExpansionProductionBinding composes them. Each craft
## must glow in fast descent, cap under reduced flash, go dark above the
## atmosphere and when slow, and release its envelope on loss and reset. An
## airless world (no atmosphere source) never attaches anything.

const FlightEffectsScript := preload(
	"res://scripts/world/planetary_atmosphere_flight_effects.gd"
)
const COMPOSITION_SCENE := preload(
	"res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn"
)
const CRAFT_SCENES := {
	"TorrentInterceptor": preload("res://scenes/ships/torrent_interceptor.tscn"),
	"ArrowReconShip": preload("res://scenes/ships/arrow_recon_ship.tscn"),
	"JovianLightFreighter": preload("res://scenes/ships/jovian_light_freighter.tscn"),
	"ZenithInterceptor": preload("res://scenes/ships/zenith_interceptor.tscn"),
	"HalyardCrewTransport": preload("res://scenes/ships/halyard_crew_transport.tscn"),
	"BulwarkHeavyGunship": preload("res://scenes/ships/bulwark_heavy_gunship.tscn"),
}
const CRAFT_SCRIPTS := {
	"CinderLightInterceptor": preload("res://scripts/ships/cinder_light_interceptor.gd"),
	"CinderCargoHauler": preload("res://scripts/ships/cinder_cargo_hauler.gd"),
	"CinderLongRangeBomber": preload("res://scripts/ships/cinder_long_range_bomber.gd"),
}
const EXPECTED_CRAFT_COUNT := 9
const BODY_RADIUS_M := 120_000.0
const TICK := 1.0 / 60.0
const OVERLAY_PARAMETER := &"entry_effect_intensity_unitless"


class StubAtmosphereSource:
	extends Node
	var composition: PlanetaryAtmosphereComposition
	var world: Node3D
	var states: Array = []
	var cleared := 0

	func get_atmosphere_composition() -> PlanetaryAtmosphereComposition:
		return composition

	func get_loaded_instance() -> Node3D:
		return world

	func get_atmosphere_weather_scalar() -> float:
		return 0.4

	func set_surface_atmosphere_state(
			blend: float, wind: float, clock: float
		) -> Dictionary:
		states.append([blend, wind, clock])
		return {"accepted": true}

	func clear_surface_atmosphere_state() -> void:
		cleared += 1


var _assertions := 0
var _failures: PackedStringArray = []
var _exercised: PackedStringArray = []
var _hud: GameHUD
var _source: StubAtmosphereSource
var _body: Node3D


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_hud = GameHUD.new()
	_hud.name = "HUD"
	root.add_child(_hud)
	_body = Node3D.new()
	_body.name = "AtmosphereBody"
	root.add_child(_body)
	var composition := COMPOSITION_SCENE.instantiate() as PlanetaryAtmosphereComposition
	_body.add_child(composition)
	_source = StubAtmosphereSource.new()
	_source.composition = composition
	_source.world = _body
	root.add_child(_source)
	await process_frame

	await _check_airless_world_attaches_nothing()

	for craft_name: String in CRAFT_SCENES:
		var craft := (CRAFT_SCENES[craft_name] as PackedScene).instantiate() as HeroShip
		await _exercise(craft_name, craft)
	for craft_name: String in CRAFT_SCRIPTS:
		var craft := (CRAFT_SCRIPTS[craft_name] as GDScript).new() as HeroShip
		if craft != null:
			craft.name = craft_name
		await _exercise(craft_name, craft)
	_check(
		_exercised.size() == EXPECTED_CRAFT_COUNT,
		"entry heat enumerates all %d flyable craft (%s)"
			% [EXPECTED_CRAFT_COUNT, ", ".join(_exercised)]
	)
	_finish()


func _check_airless_world_attaches_nothing() -> void:
	var craft := (CRAFT_SCENES["TorrentInterceptor"] as PackedScene).instantiate() as HeroShip
	root.add_child(craft)
	await process_frame
	craft.set_physics_process(false)
	craft.global_position = Vector3(0.0, BODY_RADIUS_M + 12_000.0, 0.0)
	craft.velocity = Vector3(0.0, -600.0, 0.0)
	var effects := FlightEffectsScript.new()
	effects.advance(TICK, craft, true, null, _hud, [])
	var visual := craft.get_variant_visual_root()
	_check(
		not effects.is_active()
			and visual.get_node_or_null(NodePath(String(
				FlightEffectsScript.ENVELOPE_NAME
			))) == null,
		"an airless world with no atmosphere source attaches no entry envelope"
	)
	craft.queue_free()
	await process_frame


func _exercise(craft_name: String, craft: HeroShip) -> void:
	_check(craft != null, "%s composes" % craft_name)
	if craft == null:
		return
	root.add_child(craft)
	await process_frame
	await physics_frame
	craft.set_physics_process(false)
	var effects := FlightEffectsScript.new()
	# Fast descent at 12 km: inside the density ramp, well above full speed.
	craft.global_position = Vector3(0.0, BODY_RADIUS_M + 12_000.0, 0.0)
	craft.velocity = Vector3(0.0, -600.0, 0.0)
	effects.advance(TICK, craft, true, null, _hud, [_source])
	var snapshot := effects.get_snapshot()
	var entry := snapshot.get("entry", {}) as Dictionary
	var visual := craft.get_variant_visual_root()
	var envelope := visual.get_node_or_null(NodePath(String(
		FlightEffectsScript.ENVELOPE_NAME
	))) as Node3D if visual != null else null
	var envelope_snapshot := (
		(entry.get("binding", {}) as Dictionary).get("envelope", {})
	) as Dictionary
	var hot_opacity := float(envelope_snapshot.get("effect_opacity", 0.0))
	_check(
		bool(snapshot.get("active", false)) and bool(entry.get("attached", false))
			and float(entry.get("intensity_unitless", 0.0)) > 0.0
			and envelope != null and hot_opacity > 0.0,
		"%s shows a compression envelope in fast atmospheric descent" % craft_name
	)
	if craft is ArrowReconShip:
		# The Arrow's overlay adapter configures permanently, and a configured
		# target makes its Ember-owned presenter treat Ember as atmospheric.
		var arrow_target := (craft as ArrowReconShip).get_entry_heat_target()
		_check(
			not bool(arrow_target.get_presentation().get_state_snapshot().get(
				"configured", true
			))
				and float(arrow_target.get_material().get_shader_parameter(
					OVERLAY_PARAMETER
				)) == 0.0,
			"Aurora never configures the Arrow's permanent heat overlay (no Ember plasma later)"
		)

	_hud.set_reduced_flash(true)
	effects.advance(TICK, craft, true, null, _hud, [_source])
	var reduced := (
		((effects.get_snapshot().entry as Dictionary).binding as Dictionary)
			.get("envelope", {})
	) as Dictionary
	_check(
		float(reduced.get("effect_opacity", 1.0)) <= 0.42
			and float(reduced.get("effect_opacity", 1.0)) <= hot_opacity,
		"%s caps the envelope under reduced flash" % craft_name
	)
	_hud.set_reduced_flash(false)

	craft.velocity = Vector3(0.0, -100.0, 0.0)
	effects.advance(TICK, craft, true, null, _hud, [_source])
	_check(
		float((effects.get_snapshot().entry as Dictionary).intensity_unitless) == 0.0,
		"%s is cold below the entry minimum speed" % craft_name
	)
	# Dropping straight from a hot descent to zero arms the envelope's brief
	# "ENTRY RECOVER" hold. Flying on slowly (touchdown, taxi, parked) must let
	# that hold run out rather than leave the ring and marker up for good.
	var hot_level := int(roundi(float(
		(snapshot.get("entry", {}) as Dictionary).get("intensity_unitless", 0.0)
	) * 5.0))
	for _i in 120:
		effects.advance(TICK, craft, true, null, _hud, [_source])
	var settled := (
		((effects.get_snapshot().entry as Dictionary).binding as Dictionary)
			.get("envelope", {})
	) as Dictionary
	_check(
		hot_level >= 3 and not bool(settled.get("visible", true))
			and not bool(settled.get("recovery_ring_visible", true))
			and str(settled.get("marker_text", "?")).is_empty(),
		"%s clears the entry-recovery cue once slow flight settles (level %d, %s)"
			% [craft_name, hot_level, settled.get("marker_text", "?")]
	)
	craft.global_position = Vector3(0.0, BODY_RADIUS_M + 25_000.0, 0.0)
	craft.velocity = Vector3(0.0, -2_000.0, 0.0)
	effects.advance(TICK, craft, true, null, _hud, [_source])
	_check(
		float((effects.get_snapshot().entry as Dictionary).intensity_unitless) == 0.0,
		"%s is cold above the atmosphere top however fast it moves" % craft_name
	)

	# Craft loss/replacement releases the envelope.
	effects.advance(TICK, null, false, null, _hud, [_source])
	_check(
		not bool((effects.get_snapshot().entry as Dictionary).attached)
			and (not is_instance_valid(envelope) or envelope.is_queued_for_deletion()),
		"%s releases its envelope when the craft is lost" % craft_name
	)
	await process_frame
	# Reattach (after the retry window) then reset as a whole-Main exit would.
	craft.global_position = Vector3(0.0, BODY_RADIUS_M + 12_000.0, 0.0)
	craft.velocity = Vector3(0.0, -600.0, 0.0)
	for _i in FlightEffectsScript.ENTRY_ATTACH_RETRY_TICKS + 2:
		effects.advance(TICK, craft, true, null, _hud, [_source])
	var cleared_before := _source.cleared
	effects.reset(&"test_game_flow_detached")
	await process_frame
	_check(
		not effects.is_active()
			and not bool((effects.get_snapshot().entry as Dictionary).attached)
			and visual.get_node_or_null(NodePath(String(
				FlightEffectsScript.ENVELOPE_NAME
			))) == null
			and _source.cleared == cleared_before + 1,
		"%s reset removes the envelope and clears the source state" % craft_name
	)
	_exercised.append(craft_name)
	craft.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("PASS planetary_entry_heat_all_craft_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL planetary_entry_heat_all_craft_test (%d/%d failed)" % [
			_failures.size(), _assertions,
		])
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
