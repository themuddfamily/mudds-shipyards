extends SceneTree

const ConverterScript := preload(
	"res://scripts/combat/weapon_definition_resolver_profile.gd"
)
const LiveCombatAuthorityScript := preload(
	"res://scripts/combat/live_combat_authority.gd"
)
const TORRENT_DEFINITION_PATH := "res://assets/weapons/torrent_combat_pulse.tres"
const ARROW_DEFINITION_PATH := "res://assets/weapons/arrow_combat_pulse.tres"
const TORRENT_SOURCE_ID := 1101
const ARROW_SOURCE_ID := 1102
const SOURCE_FACTION: StringName = &"shipyard_flight_test"
const WEAPON_ID: StringName = &"combat_pulse_cannon"
const ORIGIN_TOLERANCE := 24.0
const TORRENT_EXPECTED_PROFILE := {
	"range": 360.0,
	"damage": 34.0,
	"origin_tolerance": ORIGIN_TOLERANCE,
}
const ARROW_EXPECTED_PROFILE := {
	"range": 410.0,
	"damage": 25.0,
	"origin_tolerance": ORIGIN_TOLERANCE,
}

var _failures := PackedStringArray()
var _assertions := 0
var _captured_requests: Array[ShotRequest] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var torrent_definition := ResourceLoader.load(
		TORRENT_DEFINITION_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as WeaponDefinition
	var arrow_definition := ResourceLoader.load(
		ARROW_DEFINITION_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as WeaponDefinition
	_test_checked_in_resource(torrent_definition)
	_test_arrow_checked_in_resource(arrow_definition)
	_test_pure_converter(torrent_definition)
	_test_production_selection(torrent_definition, arrow_definition)
	await _test_authority_lifecycle(
		torrent_definition,
		TORRENT_SOURCE_ID,
		TORRENT_EXPECTED_PROFILE,
		360.0,
		34.0,
		"Torrent"
	)
	await _test_authority_lifecycle(
		arrow_definition,
		ARROW_SOURCE_ID,
		ARROW_EXPECTED_PROFILE,
		410.0,
		25.0,
		"Arrow"
	)
	_finish()


func _test_checked_in_resource(definition: WeaponDefinition) -> void:
	_check(definition != null, "checked-in Torrent weapon definition loads with its concrete type")
	if definition == null:
		return
	_check(definition.resource_path == TORRENT_DEFINITION_PATH, "production definition has one checked-in resource identity")
	_check(definition.is_definition_valid(), "production Torrent definition passes strict validation")
	_check(
		definition.weapon_id == WEAPON_ID
			and definition.resolution_mode == WeaponDefinition.ResolutionMode.HITSCAN,
		"resource preserves the existing combat weapon ID and hitscan mode"
	)
	_check(
		is_equal_approx(definition.range_meters, 360.0)
			and is_equal_approx(definition.damage_per_hit, 34.0),
		"resource preserves Torrent's exact production range and damage"
	)
	_check(
		is_equal_approx(1.0 / definition.cadence_shots_per_second, 0.22),
		"resource cadence is exactly equivalent to Torrent's existing 0.22 second cooldown"
	)
	_check(
		definition.faction_policy == WeaponDefinition.FactionPolicy.INHERIT_SOURCE
			and definition.fixed_faction_id.is_empty()
			and definition.friendly_fire_policy == WeaponDefinition.FriendlyFirePolicy.DENY,
		"resource preserves registered source faction and denied friendly fire"
	)
	_check(
		definition.presentation_id == &"cyan"
			and definition.fire_audio_id == &"player_pulse_fire"
			and definition.impact_audio_id == &"hull_impact_medium"
			and definition.dry_fire_audio_id == &"dry_fire_click",
		"resource records the unchanged player presentation and audio route"
	)
	_check(
		definition.evidence_status == WeaponDefinition.EvidenceStatus.NEW
			and definition.evidence_notes.contains("not a recovered historical"),
		"migrated balance remains explicit new-design evidence"
	)


func _test_arrow_checked_in_resource(definition: WeaponDefinition) -> void:
	_check(definition != null, "checked-in Arrow weapon definition loads with its concrete type")
	if definition == null:
		return
	_check(
		definition.resource_path == ARROW_DEFINITION_PATH,
		"Arrow production definition has one checked-in resource identity"
	)
	_check(definition.is_definition_valid(), "production Arrow definition passes strict validation")
	_check(
		definition.weapon_id == WEAPON_ID
			and definition.resolution_mode == WeaponDefinition.ResolutionMode.HITSCAN,
		"Arrow resource preserves the existing combat weapon ID and hitscan mode"
	)
	_check(
		is_equal_approx(definition.range_meters, 410.0)
			and is_equal_approx(definition.damage_per_hit, 25.0),
		"Arrow resource preserves its exact production range and damage"
	)
	_check(
		is_equal_approx(1.0 / definition.cadence_shots_per_second, 0.38),
		"Arrow resource cadence is exactly equivalent to its existing 0.38 second cooldown"
	)
	_check(
		definition.faction_policy == WeaponDefinition.FactionPolicy.INHERIT_SOURCE
			and definition.fixed_faction_id.is_empty()
			and definition.friendly_fire_policy == WeaponDefinition.FriendlyFirePolicy.DENY,
		"Arrow resource preserves registered source faction and denied friendly fire"
	)
	_check(
		definition.presentation_id == &"cyan"
			and definition.fire_audio_id == &"player_pulse_fire"
			and definition.impact_audio_id == &"hull_impact_medium"
			and definition.dry_fire_audio_id == &"dry_fire_click",
		"Arrow resource records the unchanged player presentation and audio route"
	)
	_check(
		definition.evidence_status == WeaponDefinition.EvidenceStatus.NEW
			and definition.evidence_notes.contains("not a recovered historical"),
		"Arrow weapon balance remains explicit new-design evidence"
	)
	var converted := ConverterScript.to_resolver_profiles(
		definition, SOURCE_FACTION, ORIGIN_TOLERANCE
	)
	(converted.get(WEAPON_ID, {}) as Dictionary)["range"] = -1.0
	var fresh := ConverterScript.to_resolver_profiles(
		definition, SOURCE_FACTION, ORIGIN_TOLERANCE
	)
	_check(
		(fresh.get(WEAPON_ID, {}) as Dictionary) == ARROW_EXPECTED_PROFILE
			and is_equal_approx(definition.range_meters, 410.0),
		"Arrow conversion output is detached from the resource and later conversions"
	)


func _test_pure_converter(definition: WeaponDefinition) -> void:
	if definition == null:
		return
	var profiles := ConverterScript.to_resolver_profiles(
		definition, SOURCE_FACTION, ORIGIN_TOLERANCE
	)
	_check(
		profiles.size() == 1
			and profiles.has(WEAPON_ID)
			and (profiles[WEAPON_ID] as Dictionary) == TORRENT_EXPECTED_PROFILE,
		"converter emits the exact existing detached resolver profile shape"
	)
	(profiles[WEAPON_ID] as Dictionary)["damage"] = -1.0
	var fresh := ConverterScript.to_resolver_profiles(
		definition, SOURCE_FACTION, ORIGIN_TOLERANCE
	)
	_check(
		(fresh[WEAPON_ID] as Dictionary) == TORRENT_EXPECTED_PROFILE
			and is_equal_approx(definition.damage_per_hit, 34.0),
		"mutating converted nested data cannot alter the definition or a later conversion"
	)

	var fixed_match := definition.duplicate(true) as WeaponDefinition
	fixed_match.faction_policy = WeaponDefinition.FactionPolicy.FIXED_FACTION
	fixed_match.fixed_faction_id = SOURCE_FACTION
	_check(
		not ConverterScript.to_resolver_profiles(
			fixed_match, SOURCE_FACTION, ORIGIN_TOLERANCE
		).is_empty(),
		"fixed faction converts only when it exactly matches the registered source"
	)
	_check(
		ConverterScript.to_resolver_profiles(
			fixed_match, &"other_faction", ORIGIN_TOLERANCE
		).is_empty(),
		"fixed faction mismatch fails closed"
	)

	var projectile := definition.duplicate(true) as WeaponDefinition
	projectile.resolution_mode = WeaponDefinition.ResolutionMode.PROJECTILE
	_check(
		_has_error(
			ConverterScript.get_conversion_errors(
				projectile, SOURCE_FACTION, ORIGIN_TOLERANCE
			),
			"hitscan only"
		),
		"unsupported projectile mode cannot be approximated as hitscan"
	)
	var friendly_fire := definition.duplicate(true) as WeaponDefinition
	friendly_fire.friendly_fire_policy = WeaponDefinition.FriendlyFirePolicy.ALLOW
	_check(
		ConverterScript.to_resolver_profiles(
			friendly_fire, SOURCE_FACTION, ORIGIN_TOLERANCE
		).is_empty(),
		"unsupported allowed friendly fire fails closed"
	)
	var spread := definition.duplicate(true) as WeaponDefinition
	spread.spread_enabled = true
	spread.spread_degrees = 1.0
	_check(
		ConverterScript.to_resolver_profiles(
			spread, SOURCE_FACTION, ORIGIN_TOLERANCE
		).is_empty(),
		"unsupported spread fails closed"
	)
	var heat := definition.duplicate(true) as WeaponDefinition
	heat.heat_enabled = true
	heat.heat_per_shot = 1.0
	heat.heat_capacity = 4.0
	heat.heat_cooldown_per_second = 1.0
	_check(
		ConverterScript.to_resolver_profiles(
			heat, SOURCE_FACTION, ORIGIN_TOLERANCE
		).is_empty(),
		"unsupported heat fails closed"
	)
	var ammunition := definition.duplicate(true) as WeaponDefinition
	ammunition.ammunition_enabled = true
	ammunition.magazine_capacity = 10
	ammunition.reserve_ammunition = 20
	ammunition.ammunition_per_shot = 1
	_check(
		ConverterScript.to_resolver_profiles(
			ammunition, SOURCE_FACTION, ORIGIN_TOLERANCE
		).is_empty(),
		"unsupported ammunition fails closed"
	)
	var invalid := definition.duplicate(true) as WeaponDefinition
	invalid.range_meters = NAN
	_check(
		ConverterScript.to_resolver_profiles(
			invalid, SOURCE_FACTION, ORIGIN_TOLERANCE
		).is_empty(),
		"invalid WeaponDefinition cannot enter authority registration"
	)
	_check(
		ConverterScript.to_resolver_profiles(definition, &"", ORIGIN_TOLERANCE).is_empty()
			and ConverterScript.to_resolver_profiles(definition, SOURCE_FACTION, INF).is_empty()
			and ConverterScript.to_resolver_profiles(null, SOURCE_FACTION, ORIGIN_TOLERANCE).is_empty(),
		"missing faction, non-finite tolerance, and missing definition all fail closed"
	)


func _test_production_selection(
	torrent_definition: WeaponDefinition,
	arrow_definition: WeaponDefinition
	) -> void:
	if torrent_definition == null or arrow_definition == null:
		return
	var flow := GameFlow.new()
	var candidate := HeroShip.new()
	candidate.ship_id = GameFlow.TORRENT_SHIP_ID
	candidate.weapon_cooldown = 0.22
	var profiles := flow.call("_get_player_weapon_profiles", candidate) as Dictionary
	_check(
		profiles.size() == 2
			and (profiles.get(WEAPON_ID, {}) as Dictionary) == TORRENT_EXPECTED_PROFILE,
		"production Torrent selection combines the migrated combat profile with the unchanged range profile"
	)
	_check(
		(profiles.get(GameFlow.RANGE_WEAPON_ID, {}) as Dictionary) == {
			"range": 360.0,
			"damage": 50.0,
			"origin_tolerance": 24.0,
		},
		"Torrent's separate range-target pulse remains exactly unchanged"
	)
	_check(
		not GameFlow.PLAYER_WEAPON_PROFILES.has(WEAPON_ID),
		"production constants contain no legacy Torrent combat fallback"
	)
	_check(
		GameFlow.TORRENT_COMBAT_WEAPON_DEFINITION == torrent_definition
			or GameFlow.TORRENT_COMBAT_WEAPON_DEFINITION.resource_path
				== torrent_definition.resource_path,
		"GameFlow binds the checked-in Torrent resource rather than a test fixture"
	)
	candidate.weapon_cooldown = 0.23
	_check(
		(flow.call("_get_player_weapon_profiles", candidate) as Dictionary).is_empty(),
		"cadence drift rejects Torrent registration instead of falling back to the legacy dictionary"
	)
	candidate.ship_id = GameFlow.ARROW_SHIP_ID
	candidate.weapon_cooldown = 0.38
	var arrow_profiles := flow.call("_get_player_weapon_profiles", candidate) as Dictionary
	_check(
		arrow_profiles.size() == 2
			and (arrow_profiles.get(WEAPON_ID, {}) as Dictionary) == ARROW_EXPECTED_PROFILE,
		"production Arrow selection combines the migrated combat profile with the unchanged range profile"
	)
	_check(
		not GameFlow.PLAYER_COMBAT_WEAPON_OVERRIDES.has(GameFlow.ARROW_SHIP_ID),
		"production overrides contain no legacy Arrow combat fallback"
	)
	_check(
		GameFlow.ARROW_COMBAT_WEAPON_DEFINITION == arrow_definition
			or GameFlow.ARROW_COMBAT_WEAPON_DEFINITION.resource_path
				== arrow_definition.resource_path,
		"GameFlow binds the checked-in Arrow resource rather than a test fixture"
	)
	_check(
		GameFlow.ARROW_COMBAT_WEAPON_DEFINITION != arrow_definition
			and GameFlow.ARROW_COMBAT_WEAPON_DEFINITION.resource_path
				== arrow_definition.resource_path,
		"cache-ignored Arrow fixture is a detached Resource identity with the same checked-in path"
	)

	var production_arrow_definition := (
		GameFlow.ARROW_COMBAT_WEAPON_DEFINITION as WeaponDefinition
	)
	var original_arrow_range := production_arrow_definition.range_meters
	production_arrow_definition.range_meters = NAN
	var rejected_mutation := flow.call(
		"_get_player_weapon_profiles", candidate
	) as Dictionary
	production_arrow_definition.range_meters = original_arrow_range
	var restored_profiles := flow.call(
		"_get_player_weapon_profiles", candidate
	) as Dictionary
	_check(
		rejected_mutation.is_empty()
			and (restored_profiles.get(WEAPON_ID, {}) as Dictionary)
				== ARROW_EXPECTED_PROFILE,
		"invalid live Arrow resource mutation fails closed without a legacy fallback and restores cleanly"
	)
	candidate.weapon_cooldown = 0.39
	_check(
		(flow.call("_get_player_weapon_profiles", candidate) as Dictionary).is_empty(),
		"cadence drift rejects Arrow registration instead of borrowing another player profile"
	)

	candidate.ship_id = &"jovian_provisional"
	candidate.weapon_cooldown = 0.62
	var jovian_profiles := flow.call("_get_player_weapon_profiles", candidate) as Dictionary
	_check(
		(jovian_profiles.get(WEAPON_ID, {}) as Dictionary) == {
			"range": 315.0,
			"damage": 23.0,
			"origin_tolerance": 32.0,
		},
		"unmigrated Jovian keeps its exact existing override"
	)
	candidate.free()
	flow.free()


func _test_authority_lifecycle(
	definition: WeaponDefinition,
	source_id: int,
	expected_profile: Dictionary,
	expected_range: float,
	expected_damage: float,
	label: String
	) -> void:
	if definition == null:
		return
	_captured_requests.clear()
	var original_root_child_count := root.get_child_count()
	var streamed_main := Node3D.new()
	streamed_main.name = "%sWeaponDefinitionMigrationMain" % label
	root.add_child(streamed_main)
	var authority := LiveCombatAuthorityScript.new() as LiveCombatAuthority
	authority.name = "CombatAuthority"
	streamed_main.add_child(authority)
	var source := Node3D.new()
	source.name = "%sSource" % label
	streamed_main.add_child(source)
	authority.authoritative_shot_submitted.connect(_on_shot_submitted)
	await process_frame
	await physics_frame

	var profiles := ConverterScript.to_resolver_profiles(
		definition, SOURCE_FACTION, ORIGIN_TOLERANCE
	)
	_check(
		authority.register_source(source, source_id, SOURCE_FACTION, profiles),
		"%s converted profile registers through the unchanged LiveCombatAuthority API" % label
	)
	_check(
		authority.get_weapon_profile(source, WEAPON_ID) == expected_profile,
		"%s authority stores the exact converted resolver envelope" % label
	)
	var first := authority.submit_hitscan_with_deferred_presentation(
		source, WEAPON_ID, source.global_position, Vector3.UP
	)
	var first_request: ShotRequest = (
		_captured_requests.back() if not _captured_requests.is_empty() else null
	)
	_check(
		bool(first.get("accepted", false))
			and first.get("status") == &"miss"
			and first_request != null
			and first_request.source_id == source_id
			and first_request.faction_id == SOURCE_FACTION
			and first_request.weapon_id == WEAPON_ID
			and first_request.sequence == 0
			and first_request.presentation_receipt_id == 1
			and is_equal_approx(first_request.range, expected_range)
			and is_equal_approx(first_request.damage, expected_damage),
		"%s converted values preserve request identity, range, damage, sequence, and receipt allocation" % label
	)

	root.remove_child(streamed_main)
	await process_frame
	_check(
		authority.get_source_id(source) == 0
			and authority.get_resolver().get_registered_source_count() == 0
			and authority.get_last_submitted_sequence(source) == 0,
		"%s whole-Main detach retires only live registration and retains sequence history" % label
	)
	root.add_child(streamed_main)
	await process_frame
	await physics_frame
	_check(
		authority.register_source(
			source,
			source_id,
			SOURCE_FACTION,
			ConverterScript.to_resolver_profiles(
				definition, SOURCE_FACTION, ORIGIN_TOLERANCE
			)
		),
		"%s physical source re-registers from a fresh conversion after re-entry" % label
	)
	var replay := authority.get_resolver().resolve_hitscan(first_request)
	_check(
		replay.get("status") == &"duplicate_sequence"
			and not bool(replay.get("accepted", true)),
		"%s conversion cannot revive a stale pre-detach source generation" % label
	)
	var second := authority.submit_hitscan_with_deferred_presentation(
		source, WEAPON_ID, source.global_position, Vector3.UP
	)
	var second_request: ShotRequest = (
		_captured_requests.back() if not _captured_requests.is_empty() else null
	)
	_check(
		bool(second.get("accepted", false))
			and second_request != null
			and second_request.sequence == 1
			and second_request.presentation_receipt_id == 2,
		"%s re-entry preserves monotonic source sequence and session receipt identity" % label
	)
	var returned_profile := authority.get_weapon_profile(source, WEAPON_ID)
	returned_profile["damage"] = -1.0
	_check(
		authority.get_weapon_profile(source, WEAPON_ID) == expected_profile,
		"%s authority profile getter remains detached after converted registration" % label
	)

	streamed_main.queue_free()
	await process_frame
	await process_frame
	_check(
		root.get_child_count() == original_root_child_count,
		"%s migration lifecycle fixture releases every node" % label
	)


func _on_shot_submitted(request: ShotRequest, _result: Dictionary) -> void:
	_captured_requests.append(request)


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("WEAPON_DEFINITION_MIGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("WEAPON_DEFINITION_MIGRATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
