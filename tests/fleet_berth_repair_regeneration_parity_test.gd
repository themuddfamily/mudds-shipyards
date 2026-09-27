extends SceneTree

# Resolve the concrete subtype before shared HeroShip references to avoid retained script resources.
const ArrowShipType := preload("res://scripts/ships/arrow_recon_ship.gd")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")

## Berth repair and crash regeneration parity across all nine flyable craft.
##
## Every craft must recover from component damage the same way: nothing heals
## while it is flying, the one passive berth-repair path (`ShipComponentDamage.
## tick_repair()` through `HeroShip._sync_component_damage()`, authorized only
## while landed and intact) restores every component in the same short window,
## and a destroyed hull passes the exact preflight/commit reuse pair GameFlow's
## berth regeneration runs, inside the one shared crash-recovery window.
## An outlier here is a craft that stays broken on its pad, repairs in flight,
## repairs slower than its siblings, or refuses regeneration and falls into the
## "Regeneration holding" retry.

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
const TICK := 1.0 / 60.0
## Generous ceiling on the passive repair window: FAILED -> NOMINAL at the shared
## 0.62 integrity/s rate is ~1.6 s. Anything slower is an outlier.
const MAX_REPAIR_SECONDS := 4.0
const DAMAGED_COMPONENTS: Array[StringName] = [
	ShipComponentDamage.COMPONENT_ENGINE_BAY,
	ShipComponentDamage.COMPONENT_PORT_WING,
	ShipComponentDamage.COMPONENT_CORE_SYSTEMS,
]

var _assertions := 0
var _failures: PackedStringArray = []
var _exercised: PackedStringArray = []
var _repair_seconds: Dictionary = {}


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check(
		GameFlowScript.DESTROYED_SHIP_REGENERATION_DELAY_MSEC
			<= int(round(CombatRecoveryPolicy.new().recovery_seconds * 1000.0)),
		"berth regeneration waits no longer than the shared %.1f s crash-recovery window"
			% CombatRecoveryPolicy.new().recovery_seconds
	)
	var host := Node3D.new()
	host.name = "FleetBerthRepairParityHost"
	root.add_child(host)
	for craft_name: String in CRAFT_SCENES:
		var craft := (CRAFT_SCENES[craft_name] as PackedScene).instantiate() as HeroShip
		_check(craft != null, "%s production scene instantiates" % craft_name)
		if craft == null:
			continue
		host.add_child(craft)
		await process_frame
		await physics_frame
		_exercise_craft(craft_name, craft)
		craft.queue_free()
		await process_frame
	for craft_name: String in CRAFT_SCRIPTS:
		var craft := (CRAFT_SCRIPTS[craft_name] as GDScript).new() as HeroShip
		_check(craft != null, "%s production script composes" % craft_name)
		if craft == null:
			continue
		craft.name = craft_name
		host.add_child(craft)
		await process_frame
		await physics_frame
		_exercise_craft(craft_name, craft)
		craft.queue_free()
		await process_frame
	_check(
		_exercised.size() == EXPECTED_CRAFT_COUNT,
		"berth repair parity enumerates all %d production craft (%s)"
			% [EXPECTED_CRAFT_COUNT, ", ".join(_exercised)]
	)
	var fastest := INF
	var slowest := 0.0
	for seconds: float in _repair_seconds.values():
		fastest = minf(fastest, seconds)
		slowest = maxf(slowest, seconds)
	_check(
		_repair_seconds.size() == EXPECTED_CRAFT_COUNT and slowest - fastest <= TICK * 2.0,
		"every craft repairs its failed components in the same window (%.2f..%.2f s)"
			% [fastest, slowest]
	)
	host.queue_free()
	await process_frame
	_finish()


## Synchronous on purpose: no physics frame may run between the damage and the
## measurement, so the only repair ticks are the ones driven here.
func _exercise_craft(craft_name: String, craft: HeroShip) -> void:
	_exercised.append(craft_name)
	var component := craft.get_component_damage()
	_check(
		component != null and component.is_configured(),
		"%s carries a configured component ledger" % craft_name
	)
	if component == null or not component.is_configured():
		return
	_check(
		bool(craft.get("_landed")) and not craft.is_destroyed(),
		"%s starts parked on its berth and intact" % craft_name
	)
	for component_id in DAMAGED_COMPONENTS:
		var result := component.record_projectile_damage(
			craft.maximum_hull, _component_local_position(component, component_id)
		)
		_check(bool(result.get("accepted", false)), "%s damages %s" % [craft_name, component_id])
	craft.call(&"_sync_component_damage", 0.0)
	var failed := craft.get_operational_modifiers()
	_check(
		bool(failed.get("mobility_disabled", false))
			and bool(failed.get("fire_disabled", false))
			and bool(failed.get("targeting_disabled", false)),
		"%s loses engine, weapon and sensor function from component damage" % craft_name
	)

	# In flight: the same path must refuse to repair.
	craft.set("_landed", false)
	for _index in 60:
		craft.call(&"_sync_component_damage", TICK)
	_check(
		_damaged_count(component) == DAMAGED_COMPONENTS.size(),
		"%s does not repair any component while flying" % craft_name
	)

	# On its berth: the one passive repair path restores everything.
	craft.set("_landed", true)
	var elapsed := 0.0
	while elapsed < MAX_REPAIR_SECONDS and _damaged_count(component) > 0:
		craft.call(&"_sync_component_damage", TICK)
		elapsed += TICK
	_repair_seconds[craft_name] = elapsed
	var repaired := craft.get_operational_modifiers()
	var presentation := craft.get_damage_presentation()
	_check(
		_damaged_count(component) == 0
			and not bool(repaired.get("mobility_disabled", true))
			and not bool(repaired.get("fire_disabled", true))
			and not bool(repaired.get("targeting_disabled", true)),
		"%s repairs every component at its berth within %.1f s (took %.2f s)"
			% [craft_name, MAX_REPAIR_SECONDS, elapsed]
	)
	_check(
		presentation != null and presentation.get_active_component_effect_count() == 0,
		"%s clears every localized component damage cue once repaired" % craft_name
	)

	# Crash: GameFlow's regeneration runs exactly this preflight/commit pair.
	craft.apply_damage(craft.maximum_hull * 3.0, craft.global_position, Vector3.UP)
	_check(craft.is_destroyed(), "%s is destroyed by a lethal hit" % craft_name)
	var preflight := craft.preflight_reset_for_reuse(craft.global_transform)
	_check(
		bool(preflight.get("accepted", false)),
		"%s accepts regeneration preflight on the first attempt (no holding retry)" % craft_name
	)
	var committed := craft.commit_reset_for_reuse(preflight)
	_check(
		bool(committed.get("accepted", false))
			and not craft.is_destroyed()
			and is_equal_approx(float(craft.get("_hull")), craft.maximum_hull)
			and _damaged_count(component) == 0
			and bool(craft.get("_landed"))
			and bool(craft.get_component_recovery_report().get("valid", false)),
		"%s regenerates whole, landed and with a clean component ledger" % craft_name
	)


func _damaged_count(component: ShipComponentDamage) -> int:
	var damaged := 0
	for state: Dictionary in component.get_component_states():
		if int(state.get("state", ShipComponentDamage.ComponentState.NOMINAL)) \
				!= ShipComponentDamage.ComponentState.NOMINAL:
			damaged += 1
	return damaged


func _component_local_position(component: ShipComponentDamage, component_id: StringName) -> Vector3:
	for state: Dictionary in component.get_component_states():
		if StringName(state.get("id", &"")) == component_id:
			return state.get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_BERTH_REPAIR_REGENERATION_PARITY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("FLEET_BERTH_REPAIR_REGENERATION_PARITY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
