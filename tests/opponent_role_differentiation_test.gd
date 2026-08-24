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
	await _test_skirmisher_mirrored_trim_resource_sharing()
	await _test_skirmisher_role_currentness()
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
	var scatter_definition := lead.get_weapon_definition()
	var scatter_profile := lead.get_weapon_profiles().get(
		FlankingSkirmisherOpponent.SKIRMISHER_WEAPON_ID, {}
	) as Dictionary
	_check(
		scatter_definition != null
		and scatter_definition.weapon_id == &"skirmisher_flank_scatter"
		and scatter_definition.spread_enabled
		and is_equal_approx(scatter_definition.spread_degrees, 5.0)
		and is_equal_approx(scatter_definition.damage_per_hit, 14.0),
		"production skirmishers consume the authored short-range five-degree scatter trigger"
	)
	_check(
		int(scatter_profile.get("pellet_count", 0)) == 3
		and is_equal_approx(float(scatter_profile.get("trigger_damage", 0.0)), 14.0)
		and is_equal_approx(float(scatter_profile.get("damage", 0.0)) * 3.0, 14.0)
		and lead.get_pulse_style_id() == PulseWeaponPresentation.STYLE_AMBER
		and lead.get_pulse_profile_id() == PulseWeaponPresentation.PROFILE_REPEATER,
		"the role binds three capped resolver pellets to three pooled amber pulse silhouettes"
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


func _test_skirmisher_mirrored_trim_resource_sharing() -> void:
	var skirmisher := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	skirmisher.name = "WingMirroredTrimResourceFixture"
	root.add_child(skirmisher)
	await process_frame
	await physics_frame

	var audit := skirmisher.get_wing_chalk_band_resource_audit()
	var allocation_evidence := {
		"mesh_resources_old": int(audit.mesh_resources_old),
		"mesh_resources_new": int(audit.mesh_resources_new),
		"box_mesh_resources_old": int(audit.box_mesh_resources_old),
		"box_mesh_resources_new": int(audit.box_mesh_resources_new),
		"wing_chalk_band_mesh_resources_old": int(audit.wing_chalk_band_mesh_resources_old),
		"wing_chalk_band_mesh_resources_new": int(audit.wing_chalk_band_mesh_resources_new),
		"winglet_fin_mesh_resources_old": int(audit.winglet_fin_mesh_resources_old),
		"winglet_fin_mesh_resources_new": int(audit.winglet_fin_mesh_resources_new),
		"wing_mesh_resources_old": int(audit.wing_mesh_resources_old),
		"wing_mesh_resources_new": int(audit.wing_mesh_resources_new),
		"nodes_old": int(audit.visual_nodes_old),
		"nodes_new": int(audit.visual_nodes_new),
		"drawn_copies_old": int(audit.drawn_copies_old),
		"drawn_copies_new": int(audit.drawn_copies_new),
		"submissions_old": int(audit.structural_submissions_old),
		"submissions_new": int(audit.structural_submissions_new),
	}
	print("WING_SKIRMISHER_MIRRORED_TRIM_RESOURCE_SHARING: ", allocation_evidence)
	_check(
		bool(audit.valid)
		and audit.scope == &"wing_skirmisher_mirrored_childless_trim",
		"the skirmisher publishes a valid component-local mirrored-trim sharing audit"
	)
	_check(
		int(audit.mesh_resources_old) == 16
		and int(audit.mesh_resources_new) == 13
		and int(audit.box_mesh_resources_old) == 6
		and int(audit.box_mesh_resources_new) == 4
		and int(audit.wing_mesh_resources_old) == 2
		and int(audit.wing_mesh_resources_new) == 1
		and int(audit.wing_chalk_band_mesh_resources_old) == 2
		and int(audit.wing_chalk_band_mesh_resources_new) == 1
		and int(audit.winglet_fin_mesh_resources_old) == 2
		and int(audit.winglet_fin_mesh_resources_new) == 1,
		"three shared mirrored recipes reduce retained Mesh identities from 16 to 13"
	)
	_check(
		int(audit.descendant_nodes_old) == 32
		and int(audit.descendant_nodes_new) == 32
		and int(audit.visual_nodes_old) == 21
		and int(audit.visual_nodes_new) == 21
		and int(audit.mesh_instance_nodes_old) == 18
		and int(audit.mesh_instance_nodes_new) == 18
		and int(audit.drawn_copies_old) == 18
		and int(audit.drawn_copies_new) == 18
		and int(audit.structural_submissions_old) == 18
		and int(audit.structural_submissions_new) == 18
		and int(audit.wing_chalk_band_submissions_old) == 2
		and int(audit.wing_chalk_band_submissions_new) == 2
		and int(audit.winglet_fin_submissions_old) == 2
		and int(audit.winglet_fin_submissions_new) == 2
		and int(audit.wing_submissions_old) == 2
		and int(audit.wing_submissions_new) == 2,
		"sharing preserves every node, MeshInstance, visible copy, and submission"
	)
	_check(
		int(audit.material_resources_old) == 8
		and int(audit.material_resources_new) == 8
		and int(audit.light_nodes_old) == 5
		and int(audit.light_nodes_new) == 5
		and int(audit.collision_shapes_old) == 3
		and int(audit.collision_shapes_new) == 3
		and int(audit.particle_nodes_old) == 3
		and int(audit.particle_nodes_new) == 3
		and int(audit.authority_node_count) == 0
		and int(audit.scripted_node_count) == 0
		and int(audit.child_node_count) == 0
		and int(audit.metadata_entry_count) == 0
		and int(audit.processing_node_count) == 0,
		"the selected leaves stay material-identical, childless, non-colliding, and inert"
	)
	var behavior_rows := audit.behavior_rows as Array
	_check(
		behavior_rows.size() == 2
		and String((behavior_rows[0] as Dictionary).side) == "port"
		and String((behavior_rows[1] as Dictionary).side) == "starboard"
		and _float_array_matches(
			(behavior_rows[0] as Dictionary).position as Array, [-2.5, 0.06, 0.4]
		)
		and _float_array_matches(
			(behavior_rows[1] as Dictionary).position as Array, [2.5, 0.06, 0.4]
		)
		and _float_array_matches(
			(behavior_rows[0] as Dictionary).rotation as Array, [0.0, 0.0, 0.0]
		)
		and _float_array_matches(
			(behavior_rows[1] as Dictionary).rotation as Array, [0.0, 0.0, 0.0]
		)
		and _float_array_matches(
			(behavior_rows[0] as Dictionary).scale as Array, [1.0, 1.0, 1.0]
		)
		and _float_array_matches(
			(behavior_rows[1] as Dictionary).scale as Array, [1.0, 1.0, 1.0]
		)
		and _float_array_matches(
			(behavior_rows[0] as Dictionary).size as Array, [2.4, 0.05, 0.3]
		)
		and _float_array_matches(
			(behavior_rows[1] as Dictionary).size as Array, [2.4, 0.05, 0.3]
		)
		and String((behavior_rows[0] as Dictionary).material) == "skirmisher_chalk"
		and String((behavior_rows[1] as Dictionary).material) == "skirmisher_chalk",
		"both authored chalk-band transforms and their exact visible recipe stay frozen"
	)
	var wing_rows := audit.wing_behavior_rows as Array
	_check(
		wing_rows.size() == 2
		and String((wing_rows[0] as Dictionary).side) == "port"
		and String((wing_rows[1] as Dictionary).side) == "starboard"
		and _float_array_matches(
			(wing_rows[0] as Dictionary).position as Array, [-2.4, -0.06, 1.0]
		)
		and _float_array_matches(
			(wing_rows[1] as Dictionary).position as Array, [2.4, -0.06, 1.0]
		)
		and _float_array_matches(
			(wing_rows[0] as Dictionary).scale as Array, [1.0, 1.0, 1.0]
		)
		and _float_array_matches(
			(wing_rows[1] as Dictionary).scale as Array, [-1.0, 1.0, 1.0]
		)
		and is_equal_approx(float((wing_rows[0] as Dictionary).effective_skew), -0.06)
		and is_equal_approx(float((wing_rows[1] as Dictionary).effective_skew), 0.06)
		and _float_array_matches(
			(wing_rows[0] as Dictionary).size as Array, [3.0, 0.22, 3.8]
		)
		and _float_array_matches(
			(wing_rows[1] as Dictionary).size as Array, [3.0, 0.22, 3.8]
		),
		"the shared ArrayMesh preserves both asymmetric wing silhouettes by exact mirroring"
	)
	var fin_rows := audit.fin_behavior_rows as Array
	_check(
		fin_rows.size() == 2
		and _float_array_matches((fin_rows[0] as Dictionary).position as Array, [-3.7, 0.36, 1.9])
		and _float_array_matches((fin_rows[1] as Dictionary).position as Array, [3.7, 0.36, 1.9])
		and _float_array_matches((fin_rows[0] as Dictionary).rotation as Array, [0.0, -0.16, 0.22])
		and _float_array_matches((fin_rows[1] as Dictionary).rotation as Array, [0.0, 0.16, -0.22])
		and _float_array_matches((fin_rows[0] as Dictionary).size as Array, [0.16, 0.9, 1.3])
		and _float_array_matches((fin_rows[1] as Dictionary).size as Array, [0.16, 0.9, 1.3]),
		"both winglet silhouettes retain their mirrored authored transforms and recipe"
	)
	_check(
		not bool(audit.batched)
		and not bool(audit.renderer_consumed_values_changed)
		and not bool(audit.frame_time_claimed)
		and not bool(audit.gpu_draw_call_claimed)
		and not bool(audit.vram_claimed)
		and not bool(audit.whole_scene_budget_claimed),
		"the audit claims retained resources only, without inventing renderer savings"
	)

	var visual := skirmisher.get_node("WingSkirmisherVisual") as Node3D
	var port_band := visual.get_node("WingChalkBand") as MeshInstance3D
	var starboard_band: MeshInstance3D
	for raw_node in visual.get_children():
		var candidate := raw_node as MeshInstance3D
		if candidate != null and candidate.position.is_equal_approx(Vector3(2.5, 0.06, 0.4)):
			starboard_band = candidate
			break
	_check(
		port_band != null and starboard_band != null and port_band.mesh == starboard_band.mesh,
		"the two live named/transform slots bind the same immutable BoxMesh identity"
	)
	if port_band != null and starboard_band != null:
		var shared_mesh := port_band.mesh as BoxMesh
		var duplicate_mesh := shared_mesh.duplicate(false) as BoxMesh
		starboard_band.mesh = duplicate_mesh
		var identity_red := skirmisher.get_wing_chalk_band_resource_audit()
		_check(
			not bool(identity_red.valid)
			and (identity_red.errors as PackedStringArray).has(
				"wing_chalk_band_mesh_identity_not_shared"
			),
			"an exact-looking but separately allocated band fails red on Resource identity"
		)
		starboard_band.mesh = shared_mesh
		_check(
			bool(skirmisher.get_wing_chalk_band_resource_audit().valid),
			"restoring the shared mesh identity restores the allocation audit"
		)

		var original_size := shared_mesh.size
		shared_mesh.size = Vector3(2.41, original_size.y, original_size.z)
		var recipe_red := skirmisher.get_wing_chalk_band_resource_audit()
		_check(
			not bool(recipe_red.valid)
			and (recipe_red.errors as PackedStringArray).has(
				"wing_chalk_band_mesh_recipe_drift:0"
			),
			"shared mesh geometry drift fails red on the frozen visible recipe"
		)
		shared_mesh.size = original_size
		_check(
			bool(skirmisher.get_wing_chalk_band_resource_audit().valid),
			"restoring the band size restores the exact recipe audit"
		)

	var port_fin: MeshInstance3D
	var starboard_fin: MeshInstance3D
	for raw_node in visual.get_children():
		var candidate := raw_node as MeshInstance3D
		if candidate == null:
			continue
		if candidate.position.is_equal_approx(Vector3(-3.7, 0.36, 1.9)):
			port_fin = candidate
		elif candidate.position.is_equal_approx(Vector3(3.7, 0.36, 1.9)):
			starboard_fin = candidate
	_check(
		port_fin != null and starboard_fin != null and port_fin.mesh == starboard_fin.mesh,
		"the two live winglet slots bind the same immutable BoxMesh identity"
	)
	if port_fin != null and starboard_fin != null:
		var shared_fin_mesh := port_fin.mesh as BoxMesh
		starboard_fin.mesh = shared_fin_mesh.duplicate(false) as BoxMesh
		var fin_identity_red := skirmisher.get_wing_chalk_band_resource_audit()
		_check(
			not bool(fin_identity_red.valid)
			and (fin_identity_red.errors as PackedStringArray).has("winglet_fin_mesh_identity_not_shared"),
			"a separately allocated winglet mesh fails red on Resource identity"
		)
		starboard_fin.mesh = shared_fin_mesh
		_check(
			bool(skirmisher.get_wing_chalk_band_resource_audit().valid),
			"restoring the shared winglet mesh identity restores the allocation audit"
		)

	var port_wing: MeshInstance3D
	var starboard_wing: MeshInstance3D
	for raw_node in visual.get_children():
		var candidate := raw_node as MeshInstance3D
		if candidate == null:
			continue
		if candidate.position.is_equal_approx(Vector3(-2.4, -0.06, 1.0)):
			port_wing = candidate
		elif candidate.position.is_equal_approx(Vector3(2.4, -0.06, 1.0)):
			starboard_wing = candidate
	_check(
		port_wing != null and starboard_wing != null and port_wing.mesh == starboard_wing.mesh,
		"the mirrored live wing nodes bind the same immutable ArrayMesh identity"
	)
	if port_wing != null and starboard_wing != null:
		var shared_wing_mesh := port_wing.mesh as ArrayMesh
		starboard_wing.mesh = shared_wing_mesh.duplicate(false) as ArrayMesh
		var wing_identity_red := skirmisher.get_wing_chalk_band_resource_audit()
		_check(
			not bool(wing_identity_red.valid)
			and (wing_identity_red.errors as PackedStringArray).has("wing_mesh_identity_not_shared"),
			"a separately allocated mirrored wing fails red on Resource identity"
		)
		starboard_wing.mesh = shared_wing_mesh
		_check(
			bool(skirmisher.get_wing_chalk_band_resource_audit().valid),
			"restoring the shared wing mesh identity restores the allocation audit"
		)

	root.remove_child(skirmisher)
	skirmisher.queue_free()
	for _index in 4:
		await process_frame


func _test_skirmisher_role_currentness() -> void:
	var skirmisher := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	skirmisher.name = "WingRoleCurrentnessFixture"
	root.add_child(skirmisher)
	await process_frame
	await physics_frame
	var role_events: Array[StringName] = []
	skirmisher.wing_role_changed.connect(func(role: StringName) -> void:
		role_events.append(role)
	)
	skirmisher.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	role_events.clear()
	var parent := skirmisher.get_parent()
	parent.remove_child(skirmisher)
	var detached_before := _skirmisher_role_snapshot(skirmisher)
	skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	_check(
		not skirmisher.is_inside_tree()
		and _skirmisher_role_snapshot(skirmisher) == detached_before
		and role_events.is_empty(),
		"a detached skirmisher rejects direct wing-role assignment without visual or signal mutation"
	)

	parent.add_child(skirmisher)
	await process_frame
	skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	var role_lamp := skirmisher.get_node_or_null("WingSkirmisherVisual/RoleLamp") as MeshInstance3D
	var role_material := role_lamp.get_active_material(0) as StandardMaterial3D if role_lamp != null else null
	_check(
		skirmisher.is_inside_tree()
		and skirmisher.get_wing_role() == WingCoordinator.ROLE_FLANKER
		and role_events == [WingCoordinator.ROLE_FLANKER]
		and role_material != null
		and role_material.albedo_color.is_equal_approx(Color("58ff9b")),
		"a reattached skirmisher accepts one fresh flanker assignment and updates its role lamp"
	)

	role_events.clear()
	var queued_before := _skirmisher_role_snapshot(skirmisher)
	skirmisher.queue_free()
	skirmisher.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	_check(
		skirmisher.is_inside_tree()
		and skirmisher.is_queued_for_deletion()
		and _skirmisher_role_snapshot(skirmisher) == queued_before
		and role_events.is_empty(),
		"a queued skirmisher rejects direct wing-role assignment without retained presentation mutation"
	)
	await process_frame
	_check(not is_instance_valid(skirmisher), "the wing-role currentness fixture frees normally")


func _skirmisher_role_snapshot(skirmisher: FlankingSkirmisherOpponent) -> Dictionary:
	var role_lamp := skirmisher.get_node_or_null("WingSkirmisherVisual/RoleLamp") as MeshInstance3D
	var role_light := skirmisher.get_node_or_null("WingSkirmisherVisual/RoleLampLight") as OmniLight3D
	var muzzle_lens := skirmisher.get_node_or_null("WingSkirmisherVisual/RepeaterLens") as MeshInstance3D
	var material := role_lamp.get_active_material(0) as StandardMaterial3D if role_lamp != null else null
	return {
		"role": skirmisher.get_wing_role(),
		"weapon_safed": skirmisher.is_weapon_safed(),
		"role_lamp_visible": role_lamp.visible if role_lamp != null else false,
		"role_lamp_color": material.albedo_color if material != null else Color.TRANSPARENT,
		"role_lamp_emission": material.emission if material != null else Color.TRANSPARENT,
		"role_lamp_energy": material.emission_energy_multiplier if material != null else -1.0,
		"role_light_visible": role_light.visible if role_light != null else false,
		"role_light_color": role_light.light_color if role_light != null else Color.TRANSPARENT,
		"role_light_energy": role_light.light_energy if role_light != null else -1.0,
		"muzzle_visible": muzzle_lens.visible if muzzle_lens != null else false,
	}.duplicate(true)


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
		and (audits[0].visual_material_bindings as Dictionary).size() == 24
		and (audits[1].visual_material_bindings as Dictionary).size() == 24
		and (audits[2].visual_material_bindings as Dictionary).size() == 24,
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
		and int(aggregate_counts.geometry_submissions) == 72
		and int(aggregate_counts.material_bindings) == 72
		and int(aggregate_counts.light_nodes) == 12
		and int(aggregate_counts.collision_shape_nodes) == 9,
		"sharing preserves 108 nodes, 72 submissions, 12 lights, and all collision shapes"
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


func _float_array_matches(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if not is_equal_approx(float(actual[index]), float(expected[index])):
			return false
	return true


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
