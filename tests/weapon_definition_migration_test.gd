extends SceneTree

const ConverterScript := preload(
	"res://scripts/combat/weapon_definition_resolver_profile.gd"
)
const LiveCombatAuthorityScript := preload(
	"res://scripts/combat/live_combat_authority.gd"
)
const TORRENT_DEFINITION_PATH := "res://assets/weapons/torrent_combat_pulse.tres"
const SOURCE_ID := 1101
const SOURCE_FACTION: StringName = &"shipyard_flight_test"
const WEAPON_ID: StringName = &"combat_pulse_cannon"
const ORIGIN_TOLERANCE := 24.0
const EXPECTED_PROFILE := {
	"range": 360.0,
	"damage": 34.0,
	"origin_tolerance": ORIGIN_TOLERANCE,
}

var _failures := PackedStringArray()
var _assertions := 0
var _captured_requests: Array[ShotRequest] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := ResourceLoader.load(
		TORRENT_DEFINITION_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as WeaponDefinition
	_test_checked_in_resource(definition)
	_test_pure_converter(definition)
	_test_production_selection(definition)
	await _test_authority_lifecycle(definition)
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


func _test_pure_converter(definition: WeaponDefinition) -> void:
	if definition == null:
		return
	var profiles := ConverterScript.to_resolver_profiles(
		definition, SOURCE_FACTION, ORIGIN_TOLERANCE
	)
	_check(
		profiles.size() == 1
			and profiles.has(WEAPON_ID)
			and (profiles[WEAPON_ID] as Dictionary) == EXPECTED_PROFILE,
		"converter emits the exact existing detached resolver profile shape"
	)
	(profiles[WEAPON_ID] as Dictionary)["damage"] = -1.0
	var fresh := ConverterScript.to_resolver_profiles(
		definition, SOURCE_FACTION, ORIGIN_TOLERANCE
	)
	_check(
		(fresh[WEAPON_ID] as Dictionary) == EXPECTED_PROFILE
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


func _test_production_selection(definition: WeaponDefinition) -> void:
	if definition == null:
		return
	var flow := GameFlow.new()
	var candidate := HeroShip.new()
	candidate.ship_id = GameFlow.TORRENT_SHIP_ID
	candidate.weapon_cooldown = 0.22
	var profiles := flow.call("_get_player_weapon_profiles", candidate) as Dictionary
	_check(
		profiles.size() == 2
			and (profiles.get(WEAPON_ID, {}) as Dictionary) == EXPECTED_PROFILE,
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
		GameFlow.TORRENT_COMBAT_WEAPON_DEFINITION == definition
			or GameFlow.TORRENT_COMBAT_WEAPON_DEFINITION.resource_path
				== definition.resource_path,
		"GameFlow binds the checked-in Torrent resource rather than a test fixture"
	)
	candidate.weapon_cooldown = 0.23
	_check(
		(flow.call("_get_player_weapon_profiles", candidate) as Dictionary).is_empty(),
		"cadence drift rejects Torrent registration instead of falling back to the legacy dictionary"
	)
	candidate.ship_id = &"arrow_provisional"
	candidate.weapon_cooldown = 0.38
	var arrow_profiles := flow.call("_get_player_weapon_profiles", candidate) as Dictionary
	_check(
		(arrow_profiles.get(WEAPON_ID, {}) as Dictionary) == {
			"range": 410.0,
			"damage": 25.0,
			"origin_tolerance": 24.0,
		},
		"unmigrated Arrow keeps its exact existing override"
	)
	candidate.free()
	flow.free()


func _test_authority_lifecycle(definition: WeaponDefinition) -> void:
	if definition == null:
		return
	var original_root_child_count := root.get_child_count()
	var streamed_main := Node3D.new()
	streamed_main.name = "WeaponDefinitionMigrationMain"
	root.add_child(streamed_main)
	var authority := LiveCombatAuthorityScript.new() as LiveCombatAuthority
	authority.name = "CombatAuthority"
	streamed_main.add_child(authority)
	var source := Node3D.new()
	source.name = "TorrentSource"
	streamed_main.add_child(source)
	authority.authoritative_shot_submitted.connect(_on_shot_submitted)
	await process_frame
	await physics_frame

	var profiles := ConverterScript.to_resolver_profiles(
		definition, SOURCE_FACTION, ORIGIN_TOLERANCE
	)
	_check(
		authority.register_source(source, SOURCE_ID, SOURCE_FACTION, profiles),
		"converted profile registers through the unchanged LiveCombatAuthority API"
	)
	_check(
		authority.get_weapon_profile(source, WEAPON_ID) == EXPECTED_PROFILE,
		"authority stores the exact converted resolver envelope"
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
			and first_request.source_id == SOURCE_ID
			and first_request.faction_id == SOURCE_FACTION
			and first_request.weapon_id == WEAPON_ID
			and first_request.sequence == 0
			and first_request.presentation_receipt_id == 1
			and is_equal_approx(first_request.range, 360.0)
			and is_equal_approx(first_request.damage, 34.0),
		"converted production values preserve request identity, range, damage, sequence, and receipt allocation"
	)

	root.remove_child(streamed_main)
	await process_frame
	_check(
		authority.get_source_id(source) == 0
			and authority.get_resolver().get_registered_source_count() == 0
			and authority.get_last_submitted_sequence(source) == 0,
		"whole-Main detach retires only live registration and retains sequence history"
	)
	root.add_child(streamed_main)
	await process_frame
	await physics_frame
	_check(
		authority.register_source(
			source,
			SOURCE_ID,
			SOURCE_FACTION,
			ConverterScript.to_resolver_profiles(
				definition, SOURCE_FACTION, ORIGIN_TOLERANCE
			)
		),
		"same physical source re-registers from a fresh conversion after re-entry"
	)
	var replay := authority.get_resolver().resolve_hitscan(first_request)
	_check(
		replay.get("status") == &"duplicate_sequence"
			and not bool(replay.get("accepted", true)),
		"definition conversion cannot revive a stale pre-detach source generation"
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
		"re-entry preserves monotonic source sequence and session receipt identity"
	)
	var returned_profile := authority.get_weapon_profile(source, WEAPON_ID)
	returned_profile["damage"] = -1.0
	_check(
		authority.get_weapon_profile(source, WEAPON_ID) == EXPECTED_PROFILE,
		"authority profile getter remains detached after converted registration"
	)

	streamed_main.queue_free()
	await process_frame
	await process_frame
	_check(
		root.get_child_count() == original_root_child_count,
		"migration lifecycle fixture releases every node"
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
