extends SceneTree

## The opponent half of the project's "lateral role trade-offs rather than
## straight statistical upgrades" rule.
##
## `tests/fleet_role_differentiation_test.gd` enforces that rule across the four
## player craft. Nothing enforced it across opponents, which is how an opponent
## roster quietly becomes a difficulty ladder: each new craft a little tougher,
## a little longer-ranged, a little faster, and every fight the same fight with
## bigger numbers. This suite applies the same three tests to the opponents:
##
##   1. **No strict dominance.** For every ordered pair, the second archetype
##      must beat the first on at least one trade-off axis. Nothing in the
##      roster is a pure upgrade of anything else.
##   2. **A role signature.** Each archetype is the *sole* extreme on axes that
##      name what it is for, and pays for them on axes it is worst at.
##   3. **Distinct behaviour, not distinct numbers.** Identical stats with
##      identical manoeuvring would pass (1) and (2) on paper and produce four
##      craft that fly the same way. The last section puts every archetype in
##      exactly the same position, relative to exactly the same target, asks
##      each what it wants to do, and requires the answers to point in
##      materially different directions.
##
## Authored values are read from the production `res://scenes/main.tscn`, not
## from source constants, so a scene that overrides a script default is measured
## as the player meets it. No handling, damage, or balance value is modified
## anywhere in this suite.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const COURIER_SCENE := preload("res://scenes/ships/courier_runner_opponent.tscn")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")
const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const DEFENDER_SCENE := preload("res://scenes/ships/range_opponent.tscn")

# Trade-off axes with an unambiguous "better for this opponent" reading.
# `preferred_engagement_distance` is excluded from the dominance test on
# purpose: preferring to fight far away is not better or worse than preferring
# to fight close, it is the difference between two roles.
const HIGHER_IS_BETTER := [
	"maximum_health", "cruise_speed", "chase_speed", "acceleration",
	"turn_speed_degrees", "engagement_range", "weapon_range", "weapon_damage",
	"sustained_damage_per_second",
]
const LOWER_IS_BETTER := ["telegraph_time", "weapon_cooldown", "minimum_arming_range"]
const PROFILE_AXES := 13

## Two archetypes may legitimately share an axis whose value is structurally
## zero for both — only the picket gates its weapon on a minimum arming range,
## so three of the four sit at 0 there. Twelve of thirteen is what that allows
## and no more.
const MINIMUM_DIFFERING_AXES := 12

## Minimum angle, in degrees, between any two archetypes' chosen manoeuvres from
## an identical starting geometry. Measured across the five behaviours below;
## the smallest observed separation is printed as evidence on every run so a
## later tuning pass can see how much headroom it is spending.
const MINIMUM_BEHAVIOUR_SEPARATION_DEGREES := 25.0

var _failures: Array[String] = []
var _assertion_count := 0
var _evidence: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_children := root.get_child_count()
	await _test_production_roster()
	await _test_courier_visual_resource_sharing()
	await _test_distinct_manoeuvres()
	for line in _evidence:
		print(line)
	_check(
		root.get_child_count() == original_children,
		"the opponent differentiation fixtures clean up without leaving scene nodes"
	)
	_finish()


# ------------------------------------------------------------- profiles ----

func _test_production_roster() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the opponent role audit")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var defender := game.get_node_or_null("RangeOpponent") as RangeOpponent
	var picket := game.get_node_or_null("StandoffPicket") as StandoffPicketOpponent
	var lead := game.get_node_or_null("WingSkirmisherLead") as FlankingSkirmisherOpponent
	var wing := game.get_node_or_null("WingSkirmisherWing") as FlankingSkirmisherOpponent
	var courier := game.get_node_or_null("CourierRunner") as CourierRunnerOpponent
	_check(
		defender != null and picket != null and lead != null and wing != null and courier != null,
		"the production scene stages all four opponent archetypes"
	)
	if defender == null or picket == null or lead == null or courier == null or wing == null:
		await _free_game(game)
		return

	_check(
		lead.source_id != wing.source_id
		and lead.source_id != courier.source_id
		and picket.source_id != courier.source_id
		and lead.source_id != GameFlow.OPPONENT_SOURCE_ID
		and courier.source_id != GameFlow.OPPONENT_SOURCE_ID,
		"every staged opponent carries a distinct stable combat identity"
	)

	var profiles := {
		&"range_defender": _defender_profile(defender),
		&"standoff_picket": picket.get_tactics_profile(),
		&"wing_skirmisher": lead.get_tactics_profile(),
		&"contract_courier": courier.get_tactics_profile(),
	}
	for archetype: StringName in profiles:
		var profile: Dictionary = profiles[archetype]
		_check(
			profile.size() == PROFILE_AXES,
			"%s publishes all %d trade-off axes (%d)" % [archetype, PROFILE_AXES, profile.size()]
		)

	var ids: Array = profiles.keys()
	ids.sort()

	# 1. Every pair genuinely differs, and neither half of any pair is a pure
	#    upgrade of the other.
	var minimum_differing := 99
	for first_index in ids.size():
		for second_index in range(first_index + 1, ids.size()):
			var first: StringName = ids[first_index]
			var second: StringName = ids[second_index]
			var differing := _count_differing(profiles[first], profiles[second])
			minimum_differing = mini(minimum_differing, differing)
			_check(
				differing >= MINIMUM_DIFFERING_AXES,
				"%s and %s differ on at least %d of the %d trade-off axes (%d)"
					% [first, second, MINIMUM_DIFFERING_AXES, PROFILE_AXES, differing]
			)
	for first: StringName in ids:
		for second: StringName in ids:
			if first == second:
				continue
			var advantages := _count_advantages(profiles[first], profiles[second])
			_check(
				advantages > 0,
				"%s is not a strict statistical upgrade over %s (%d lateral advantages)"
					% [second, first, advantages]
			)
	_evidence.append(
		"OPPONENT_ROLE_EVIDENCE: minimum_differing_axes=%d of %d"
			% [minimum_differing, PROFILE_AXES]
	)

	# 2. Frozen role signatures. Each archetype owns its own extremes and pays
	#    for them somewhere the player can exploit.
	_check(
		_is_sole_extreme(profiles, &"range_defender", "maximum_health", true),
		"the range defender alone owns the deepest hull in the opponent roster"
	)
	_check(
		_is_sole_extreme(profiles, &"standoff_picket", "weapon_range", true)
		and _is_sole_extreme(profiles, &"standoff_picket", "weapon_damage", true)
		and _is_sole_extreme(profiles, &"standoff_picket", "cruise_speed", false)
		and _is_sole_extreme(profiles, &"standoff_picket", "telegraph_time", true)
		and _is_sole_extreme(profiles, &"standoff_picket", "minimum_arming_range", true),
		"the picket alone owns the longest reach and heaviest shot, and alone pays"
			+ " with the slowest hull, the longest telegraph, and a minimum arming range"
	)
	_check(
		_is_sole_extreme(profiles, &"wing_skirmisher", "turn_speed_degrees", true)
		and _is_sole_extreme(profiles, &"wing_skirmisher", "acceleration", true)
		and _is_sole_extreme(profiles, &"wing_skirmisher", "sustained_damage_per_second", true)
		and _is_sole_extreme(profiles, &"wing_skirmisher", "maximum_health", false)
		and _is_sole_extreme(profiles, &"wing_skirmisher", "weapon_damage", false),
		"the skirmisher alone owns the sharpest turn, acceleration and sustained output,"
			+ " and alone pays with the thinnest hull and the weakest single shot"
	)
	_check(
		_is_sole_extreme(profiles, &"contract_courier", "cruise_speed", true)
		and _is_sole_extreme(profiles, &"contract_courier", "chase_speed", true)
		and _is_sole_extreme(profiles, &"contract_courier", "turn_speed_degrees", false)
		and _is_sole_extreme(profiles, &"contract_courier", "engagement_range", false)
		and _is_sole_extreme(profiles, &"contract_courier", "sustained_damage_per_second", false),
		"the courier alone owns the highest straight-line speed, and alone pays with"
			+ " the worst turn rate, the shortest reach, and the lowest sustained output"
	)

	# A wing skirmisher is weak on purpose: half a coordinated pair must not
	# out-fight a lone archetype by itself, or the coordination is decoration.
	var skirmisher_profile: Dictionary = profiles[&"wing_skirmisher"]
	var defender_profile: Dictionary = profiles[&"range_defender"]
	_check(
		float(skirmisher_profile["maximum_health"]) < float(defender_profile["maximum_health"])
		and float(skirmisher_profile["weapon_damage"]) < float(defender_profile["weapon_damage"])
		and float(skirmisher_profile["engagement_range"]) < float(defender_profile["engagement_range"]),
		"one skirmisher is strictly frailer, weaker-hitting and shorter-ranged than the lone defender"
	)
	_check(
		float(skirmisher_profile["sustained_damage_per_second"]) * 2.0
			> float(defender_profile["sustained_damage_per_second"]) * 1.5,
		"the pair together is worth more than the lone defender, so the coordination pays"
	)

	# Every opponent is unregistered modern interpretation, and none of them
	# names a craft from the evidence ledger.
	for craft in [picket, lead, wing, courier]:
		var evidence: Dictionary = craft.call(&"get_evidence_metadata")
		_check(
			String(evidence.evidence_status) == "modern_interpretation"
			and not bool(evidence.historically_supported)
			and not bool(evidence.claims_historical_class_name),
			"%s is declared as an unregistered modern interpretation" % craft.name
		)
	var names := [
		lead.get_display_name(), courier.get_display_name(), picket.get_display_name(),
	]
	for display_name: String in names:
		for ledger_craft in ["Torrent", "Arrow", "Jovian", "Zenith"]:
			_check(
				not display_name.contains(ledger_craft),
				"'%s' does not borrow the ledger craft name '%s'" % [display_name, ledger_craft]
			)

	await _free_game(game)


func _test_courier_visual_resource_sharing() -> void:
	var host := Node3D.new()
	host.name = "CourierVisualResourceWorld"
	root.add_child(host)
	var couriers: Array[CourierRunnerOpponent] = []
	for index in 3:
		var courier := COURIER_SCENE.instantiate() as CourierRunnerOpponent
		courier.name = "ResourceCourier%d" % (index + 1)
		host.add_child(courier)
		couriers.append(courier)
	await process_frame
	await physics_frame

	var audits: Array[Dictionary] = []
	var unique_material_ids := {}
	var aggregate_counts := {
		"node_count": 0,
		"mesh_instance_nodes": 0,
		"particle_nodes": 0,
		"geometry_submissions": 0,
		"material_bindings": 0,
		"light_nodes": 0,
		"collision_shape_nodes": 0,
	}
	for courier in couriers:
		var audit := courier.get_visual_resource_audit()
		audits.append(audit)
		for material_id in (audit.identity_by_key as Dictionary).values():
			unique_material_ids[int(material_id)] = true
		var counts := audit.counts as Dictionary
		for key: String in aggregate_counts:
			aggregate_counts[key] = int(aggregate_counts[key]) + int(counts[key])

	var legacy_material_resources := (
		couriers.size() * int(audits[0].legacy_material_resources_per_instance)
	)
	var sharing_evidence := {
		"component_instances": couriers.size(),
		"material_resources_old": legacy_material_resources,
		"material_resources_new": unique_material_ids.size(),
		"nodes_old": int(aggregate_counts.node_count),
		"nodes_new": int(aggregate_counts.node_count),
		"geometry_submissions_old": int(aggregate_counts.geometry_submissions),
		"geometry_submissions_new": int(aggregate_counts.geometry_submissions),
		"mesh_instance_nodes_old": int(aggregate_counts.mesh_instance_nodes),
		"mesh_instance_nodes_new": int(aggregate_counts.mesh_instance_nodes),
		"light_nodes_old": int(aggregate_counts.light_nodes),
		"light_nodes_new": int(aggregate_counts.light_nodes),
	}
	print("COURIER_RUNNER_RESOURCE_SHARING: ", sharing_evidence)
	_check(
		bool(audits[0].valid) and bool(audits[1].valid) and bool(audits[2].valid)
		and audits[0].scope == &"courier_runner_process_wide_immutable_material_catalog"
		and audits[0].mapping_state_scope == &"courier_runner_instance"
		and int(audits[0].catalog_build_count) == 1,
		"courier materials build once process-wide while runner mapping state stays instance-owned"
	)
	_check(
		(audits[0].identity_by_key as Dictionary) == (audits[1].identity_by_key as Dictionary)
		and (audits[0].identity_by_key as Dictionary) == (audits[2].identity_by_key as Dictionary)
		and (audits[0].identity_by_key as Dictionary).size() == 19,
		"three live couriers bind one exact nineteen-entry Material identity roster"
	)
	_check(
		(audits[0].visible_parameters_by_key as Dictionary)
			== (audits[1].visible_parameters_by_key as Dictionary)
		and (audits[0].visible_parameters_by_key as Dictionary)
			== (audits[2].visible_parameters_by_key as Dictionary)
		and _binding_identity_counts(audits[0].visual_material_bindings as Dictionary)
			== _binding_identity_counts(audits[1].visual_material_bindings as Dictionary)
		and _binding_identity_counts(audits[0].visual_material_bindings as Dictionary)
			== _binding_identity_counts(audits[2].visual_material_bindings as Dictionary)
		and (audits[0].visual_material_bindings as Dictionary).size() == 26
		and (audits[1].visual_material_bindings as Dictionary).size() == 26
		and (audits[2].visual_material_bindings as Dictionary).size() == 26,
		"shared courier materials preserve every visible parameter and semantic binding"
	)
	_check(
		legacy_material_resources == 57 and unique_material_ids.size() == 19,
		"three couriers reduce immutable Material allocations from 57 to 19"
	)
	_check(
		int(aggregate_counts.node_count) == 108
		and int(aggregate_counts.mesh_instance_nodes) == 72
		and int(aggregate_counts.particle_nodes) == 6
		and int(aggregate_counts.geometry_submissions) == 78
		and int(aggregate_counts.material_bindings) == 78
		and int(aggregate_counts.light_nodes) == 12
		and int(aggregate_counts.collision_shape_nodes) == 9,
		"sharing preserves 108 nodes, 78 submissions, 12 lights, and all collision shapes"
	)

	# The catalog is shared; the distress latch, visibility, lights, and lifecycle
	# remain private to one runner.
	couriers[0].activate(Transform3D(Basis.IDENTITY, Vector3(8.0, 2.0, -14.0)))
	_check(couriers[0].begin_distress_broadcast(), "first resource fixture enters distress")
	var first_beacon := couriers[0].get_node(
		"ContractCourierVisual/DistressBeacon"
	) as MeshInstance3D
	var second_beacon := couriers[1].get_node(
		"ContractCourierVisual/DistressBeacon"
	) as MeshInstance3D
	var first_light := couriers[0].get_node(
		"ContractCourierVisual/DistressLight"
	) as OmniLight3D
	var second_light := couriers[1].get_node(
		"ContractCourierVisual/DistressLight"
	) as OmniLight3D
	_check(
		first_beacon.visible and not second_beacon.visible
		and is_equal_approx(first_light.light_energy, 4.2)
		and is_zero_approx(second_light.light_energy)
		and couriers[0].is_active() and not couriers[1].is_active(),
		"shared materials do not share distress, light, visibility, or lifecycle state"
	)
	couriers[0].deactivate()

	# A shared Resource drift invalidates every consumer and restores cleanly.
	var hull := couriers[0].get_node(
		"ContractCourierVisual/HullBody"
	) as MeshInstance3D
	var hull_material := hull.mesh.surface_get_material(0) as StandardMaterial3D
	var pod_band := couriers[0].get_node(
		"ContractCourierVisual/PodBand"
	) as MeshInstance3D
	var pod_band_material := pod_band.mesh.surface_get_material(0) as StandardMaterial3D
	hull.mesh.surface_set_material(0, pod_band_material)
	_check(
		not bool(couriers[0].get_visual_resource_audit().valid)
		and bool(couriers[1].get_visual_resource_audit().valid)
		and bool(couriers[2].get_visual_resource_audit().valid),
		"semantic material-binding drift remains instance-owned and fails its local audit"
	)
	hull.mesh.surface_set_material(0, hull_material)
	_check(
		bool(couriers[0].get_visual_resource_audit().valid),
		"restoring the semantic material binding restores the local audit"
	)
	var original_roughness := hull_material.roughness
	hull_material.roughness = 0.99
	_check(
		not bool(couriers[0].get_visual_resource_audit().valid)
		and not bool(couriers[1].get_visual_resource_audit().valid)
		and not bool(couriers[2].get_visual_resource_audit().valid),
		"catalog audit fails red for shared visible-parameter drift"
	)
	hull_material.roughness = original_roughness
	_check(
		bool(couriers[0].get_visual_resource_audit().valid)
		and bool(couriers[1].get_visual_resource_audit().valid)
		and bool(couriers[2].get_visual_resource_audit().valid),
		"restoring the visible parameter restores every courier catalog audit"
	)

	root.remove_child(host)
	host.queue_free()
	for _index in 8:
		await process_frame
	couriers.clear()
	audits.clear()


func _binding_identity_counts(bindings: Dictionary) -> Dictionary:
	var counts := {}
	for material_id in bindings.values():
		counts[int(material_id)] = int(counts.get(int(material_id), 0)) + 1
	return counts


func _defender_profile(defender: RangeOpponent) -> Dictionary:
	# The base defender predates the shared tactics contract: `GameFlow` owns its
	# weapon envelope, so its profile is assembled here from the same two places
	# the live authority reads it from. Nothing is invented.
	var envelope: Dictionary = GameFlow.OPPONENT_WEAPON_PROFILES[GameFlow.OPPONENT_WEAPON_ID]
	var damage := float(envelope["damage"])
	return {
		"maximum_health": defender.maximum_health,
		"cruise_speed": defender.cruise_speed,
		"chase_speed": defender.chase_speed,
		"acceleration": defender.acceleration,
		"turn_speed_degrees": defender.turn_speed_degrees,
		"engagement_range": defender.engagement_range,
		"weapon_range": float(envelope["range"]),
		"weapon_damage": damage,
		"sustained_damage_per_second": damage
			/ maxf(0.001, defender.telegraph_time + defender.weapon_cooldown),
		"telegraph_time": defender.telegraph_time,
		"weapon_cooldown": defender.weapon_cooldown,
		"minimum_arming_range": 0.0,
		"preferred_engagement_distance": defender.preferred_range,
	}


func _count_differing(first: Dictionary, second: Dictionary) -> int:
	var differing := 0
	for key: String in first:
		if not is_equal_approx(float(first[key]), float(second[key])):
			differing += 1
	return differing


func _count_advantages(first: Dictionary, second: Dictionary) -> int:
	var advantages := 0
	for key: String in HIGHER_IS_BETTER:
		if float(second[key]) > float(first[key]):
			advantages += 1
	for key: String in LOWER_IS_BETTER:
		if float(second[key]) < float(first[key]):
			advantages += 1
	return advantages


func _is_sole_extreme(
		profiles: Dictionary,
		archetype: StringName,
		key: String,
		want_maximum: bool
	) -> bool:
	var subject := float((profiles[archetype] as Dictionary)[key])
	for other: StringName in profiles:
		if other == archetype:
			continue
		var value := float((profiles[other] as Dictionary)[key])
		if want_maximum and value >= subject:
			return false
		if not want_maximum and value <= subject:
			return false
	return true


# ------------------------------------------------------------ behaviour ----

## Identical geometry, identical target, five different answers.
##
## Each craft is placed at exactly the same point relative to the same target
## and asked for its desired manoeuvre. This is the test that catches a roster
## which is differentiated on the spreadsheet and homogeneous in play: numbers
## can be pulled apart without anything changing about how a fight feels, but
## two craft that both fly straight at the player cannot produce two different
## direction vectors from the same starting point.
func _test_distinct_manoeuvres() -> void:
	var host := Node3D.new()
	host.name = "OpponentManoeuvreWorld"
	root.add_child(host)

	var target := CharacterBody3D.new()
	target.name = "ManoeuvreTarget"
	host.add_child(target)
	target.global_transform = Transform3D(
		Basis.looking_at(Vector3.FORWARD, Vector3.UP).orthonormalized(),
		Vector3.ZERO
	)

	# One placement for every craft: off the target's starboard bow, above it,
	# at a distance that sits outside the skirmisher's station, inside the
	# picket's standoff band, and inside the courier's evade trigger.
	var placement := Vector3(70.0, 26.0, -84.0)

	var defender := DEFENDER_SCENE.instantiate() as RangeOpponent
	defender.name = "ManoeuvreDefender"
	host.add_child(defender)
	var picket := PICKET_SCENE.instantiate() as StandoffPicketOpponent
	picket.name = "ManoeuvrePicket"
	picket.escort_enabled = false
	host.add_child(picket)
	var skirmisher := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	skirmisher.name = "ManoeuvreSkirmisher"
	host.add_child(skirmisher)
	var courier := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	courier.name = "ManoeuvreCourier"
	host.add_child(courier)
	await process_frame
	await physics_frame

	var behaviours := {}
	behaviours[&"defender_orbit"] = _sample_manoeuvre(defender, target, placement)
	behaviours[&"picket_standoff"] = _sample_manoeuvre(picket, target, placement)
	skirmisher.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	behaviours[&"skirmisher_anchor"] = _sample_manoeuvre(skirmisher, target, placement)
	skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	behaviours[&"skirmisher_flank"] = _sample_manoeuvre(skirmisher, target, placement)
	courier.set_escape_run(placement, Vector3(0.6, 0.2, -0.8), 900.0)
	behaviours[&"courier_run"] = _sample_manoeuvre(courier, target, placement)

	var ids: Array = behaviours.keys()
	ids.sort()
	var smallest := 180.0
	var smallest_pair := ""
	for first_index in ids.size():
		for second_index in range(first_index + 1, ids.size()):
			var first: StringName = ids[first_index]
			var second: StringName = ids[second_index]
			var separation := rad_to_deg(
				(behaviours[first] as Vector3).angle_to(behaviours[second] as Vector3)
			)
			if separation < smallest:
				smallest = separation
				smallest_pair = "%s/%s" % [first, second]
			_check(
				separation >= MINIMUM_BEHAVIOUR_SEPARATION_DEGREES,
				"%s and %s choose materially different manoeuvres from identical geometry"
					% [first, second]
					+ " (%.1f degrees)" % separation
			)
	_evidence.append(
		"OPPONENT_BEHAVIOUR_EVIDENCE: smallest_manoeuvre_separation=%.1f degrees (%s)"
			% [smallest, smallest_pair]
	)

	# The flanker's whole identity is that it goes for the player's back. From a
	# forward-arc placement, its manoeuvre must actually carry it aft.
	var flank_direction: Vector3 = behaviours[&"skirmisher_flank"]
	var anchor_direction: Vector3 = behaviours[&"skirmisher_anchor"]
	var target_forward := -target.global_basis.z
	_check(
		flank_direction.dot(target_forward) < anchor_direction.dot(target_forward),
		"the flanking role moves aft of the player relative to the anchoring role"
	)
	# The runner's manoeuvre must not be an approach at all.
	var to_target := (target.global_position - placement).normalized()
	var courier_direction: Vector3 = behaviours[&"courier_run"]
	_check(
		courier_direction.dot(to_target) < 0.0,
		"the courier's chosen manoeuvre carries it away from the player, not toward him"
	)
	_check(
		(behaviours[&"defender_orbit"] as Vector3).dot(to_target) > 0.0,
		"the range defender's chosen manoeuvre still closes on the player"
	)

	root.remove_child(host)
	host.queue_free()
	for _index in 6:
		await process_frame


func _sample_manoeuvre(craft: RangeOpponent, target: Node3D, placement: Vector3) -> Vector3:
	var facing := target.global_position - placement
	if facing.length_squared() <= 0.001:
		facing = Vector3.FORWARD
	craft.global_transform = Transform3D(
		Basis.looking_at(facing.normalized(), Vector3.UP).orthonormalized(),
		placement
	)
	craft.set_target(target)
	# The elapsed clock feeds each craft's weave, so it is pinned to zero for
	# every sample: the separation measured below is between doctrines, not
	# between two craft caught at different phases of the same sine.
	craft.set("_elapsed", 0.0)
	craft.set("_orbit_sign", 1.0)
	var offset := target.global_position - placement
	var distance := offset.length()
	return craft.call(&"_choose_motion_direction", offset / distance, distance) as Vector3


# ------------------------------------------------------------- harness ----

func _free_game(game: GameFlow) -> void:
	if not is_instance_valid(game):
		return
	var audio := game.get_node_or_null("CombatAudioPresentation")
	if is_instance_valid(audio) and audio.get_parent() != null:
		audio.get_parent().remove_child(audio)
		audio.queue_free()
		await process_frame
	root.remove_child(game)
	game.queue_free()
	for _index in 8:
		await process_frame


func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		print("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("OPPONENT_ROLE_DIFFERENTIATION_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print("OPPONENT_ROLE_DIFFERENTIATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
