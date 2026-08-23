extends SceneTree

const CONTENT_SCENE := preload("res://scenes/activities/station_defense_encounter.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var authority := LiveCombatAuthority.new()
	authority.name = "SourceContractAuthority"
	root.add_child(authority)
	var content := CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	content.name = "SourceContractContent"
	root.add_child(content)
	await process_frame
	var configured := content.configure_external_combat_authority(authority)
	await process_frame
	var resolver := authority.get_resolver()
	var contract := content.get_live_source_registration_contract()
	_check(
		bool(configured.get("accepted", false))
		and bool(contract.valid)
		and int(contract.authority_instance_id) == authority.get_instance_id()
		and int(contract.resolver_instance_id) == resolver.get_instance_id()
		and int(contract.expected_source_count) == 3
		and int(contract.registered_source_key_count) == 3
		and int(contract.exact_registration_count) == 3
		and contract.faction_id == content.contract_definition.hostile_faction_id
		and contract.weapon_id == StationDefenseEncounterContent.HOSTILE_WEAPON_ID
		and (contract.sources as Array).map(
			func(row: Dictionary) -> int: return int(row.source_id)
		) == [2121, 2122, 2123]
		and (contract.sources as Array).all(
			func(row: Dictionary) -> bool: return bool(row.exact)
		),
		"contract proves the exact three authored entities, IDs, faction, profiles, keys and external authority"
	)
	(contract.sources as Array).clear()
	_check(
		(content.get_live_source_registration_contract().sources as Array).size() == 3,
		"source registration contract is deeply detached"
	)

	var alpha := content.get_node(
		^"OpponentRoster/PerimeterRaiderAlpha"
	) as RangeOpponent
	var substitute := Node3D.new()
	substitute.name = "UnauthoredSameCountSubstitute"
	root.add_child(substitute)
	var substitute_profiles := {
		&"substitute_pulse": {
			"range": 170.0,
			"damage": 11.0,
			"origin_tolerance": 18.0,
		},
	}
	authority.forget_source(alpha, 2121)
	var substituted := authority.register_source(
		substitute, 9299, &"station_defense_hostiles", substitute_profiles
	)
	var substitution_red := content.get_live_source_registration_contract()
	_check(
		substituted
		and resolver.get_registered_source_count() == 3
		and not bool(substitution_red.valid)
		and int(substitution_red.exact_registration_count) == 2,
		"an arbitrary substitute fails the authored contract even at the same total source count"
	)
	authority.forget_source(substitute, 9299)
	_check(
		authority.register_source(
			alpha,
			2121,
			content.contract_definition.hostile_faction_id,
			StationDefenseEncounterContent.HOSTILE_WEAPON_PROFILES
		)
		and bool(content.get_live_source_registration_contract().valid),
		"restoring alpha's exact identity, faction and profile restores the contract"
	)

	content.queue_free()
	substitute.queue_free()
	authority.queue_free()
	for _cleanup_frame in 3:
		await process_frame
	if _failures.is_empty():
		print("STATION_DEFENSE_SOURCE_REGISTRATION_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
