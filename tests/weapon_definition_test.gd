extends SceneTree

const DefinitionScript := preload("res://scripts/combat/weapon_definition.gd")
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const COMMON_EVIDENCE_KEYS := [
	"content_class", "status", "scope", "references", "notes",
]

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_identity_modes_and_core_envelope()
	_test_faction_and_optional_system_contracts()
	_test_strict_validation()
	_test_detached_snapshots_audit_and_zero_authority()
	_test_resource_round_trip()
	_finish()


func _test_identity_modes_and_core_envelope() -> void:
	var defaults := _definition()
	_check(defaults is Resource, "WeaponDefinition is a reusable Godot Resource")
	_check(defaults.is_definition_valid(), "the canonical disabled-optional default validates")
	_check(defaults.weapon_id == &"unnamed_weapon", "weapon identity is an explicit stable StringName")
	_check(defaults.get_resolution_mode_id() == &"hitscan", "resolution never relies on an implicit runtime default")

	var weapon := _complete_definition()
	_check(weapon.is_definition_valid(), "a complete projectile definition validates")
	var resolution := weapon.get_resolution_snapshot()
	_check(
		resolution.mode == &"projectile"
			and resolution.range_meters == 825.5
			and resolution.damage_per_hit == 17.25
			and resolution.cadence_shots_per_second == 6.5,
		"resolution snapshot exposes explicit mode, metre range, damage, and shots-per-second cadence"
	)
	_check(
		weapon.get_evidence_status_id() == &"provisional",
		"evidence enum publishes a stable textual status without authenticating it"
	)

	for invalid_id in ["", "9weapon", "Weapon", "weapon id", "weapon-id", "_weapon", "weapon_", "weapon__id"]:
		var bad_id := _definition()
		bad_id.weapon_id = StringName(invalid_id)
		_check(not bad_id.is_definition_valid(), "invalid stable weapon ID is rejected: '%s'" % invalid_id)

	var invalid_resolution := _definition()
	invalid_resolution.resolution_mode = 99
	_check(
		invalid_resolution.get_resolution_mode_id() == &"invalid"
			and _has_error(invalid_resolution.get_validation_errors(), "resolution_mode"),
		"unknown resolution modes fail closed without masquerading as hitscan"
	)


func _test_faction_and_optional_system_contracts() -> void:
	var weapon := _complete_definition()
	var policy := weapon.get_policy_snapshot()
	_check(
		policy.faction_policy == &"fixed_faction"
			and policy.fixed_faction_id == &"range_defence"
			and policy.friendly_fire_policy == &"allow",
		"faction source and friendly-fire behavior are explicit independent policies"
	)
	var optional := weapon.get_optional_systems_snapshot()
	_check(
		bool((optional.spread as Dictionary).enabled)
			and (optional.spread as Dictionary).degrees == 1.75,
		"bounded spread is present only through its explicit enabled contract"
	)
	_check(
		(optional.heat as Dictionary).per_shot == 8.0
			and (optional.heat as Dictionary).capacity == 40.0
			and (optional.heat as Dictionary).cooldown_per_second == 5.0,
		"bounded heat records per-shot cost, capacity, and cooldown"
	)
	_check(
		(optional.ammunition as Dictionary).magazine_capacity == 24
			and (optional.ammunition as Dictionary).reserve == 96
			and (optional.ammunition as Dictionary).per_shot == 2,
		"bounded ammunition records magazine, reserve, and per-shot cost"
	)
	var presentation := weapon.get_presentation_snapshot()
	_check(
		presentation.presentation_id == &"amber_bolt"
			and presentation.fire_audio_id == &"amber_bolt_fire"
			and presentation.impact_audio_id == &"amber_bolt_impact"
			and presentation.dry_fire_audio_id == &"amber_bolt_dry_fire",
		"presentation and each audio cue remain stable data IDs"
	)


func _test_strict_validation() -> void:
	var invalid_range := _definition()
	invalid_range.range_meters = INF
	_check(_has_error(invalid_range.get_validation_errors(), "range_meters"), "infinite range is rejected")
	var invalid_damage := _definition()
	invalid_damage.damage_per_hit = NAN
	_check(_has_error(invalid_damage.get_validation_errors(), "damage_per_hit"), "NaN damage is rejected")
	var invalid_cadence := _definition()
	invalid_cadence.cadence_shots_per_second = -INF
	_check(_has_error(invalid_cadence.get_validation_errors(), "cadence_shots_per_second"), "non-finite cadence is rejected")

	var inherited_with_fixed := _definition()
	inherited_with_fixed.fixed_faction_id = &"range_defence"
	_check(_has_error(inherited_with_fixed.get_validation_errors(), "must be empty"), "inherited faction rejects contradictory fixed identity")
	var fixed_without_id := _definition()
	fixed_without_id.faction_policy = DefinitionScript.FactionPolicy.FIXED_FACTION
	_check(_has_error(fixed_without_id.get_validation_errors(), "fixed_faction_id"), "fixed faction requires a stable faction ID")
	var invalid_faction_policy := _definition()
	invalid_faction_policy.faction_policy = 99
	_check(_has_error(invalid_faction_policy.get_validation_errors(), "faction_policy"), "unknown faction policy is rejected")
	var invalid_friendly_fire := _definition()
	invalid_friendly_fire.friendly_fire_policy = 99
	_check(_has_error(invalid_friendly_fire.get_validation_errors(), "friendly_fire_policy"), "unknown friendly-fire policy is rejected")

	var disabled_spread_data := _definition()
	disabled_spread_data.spread_degrees = 0.25
	_check(_has_error(disabled_spread_data.get_validation_errors(), "exactly zero"), "disabled spread cannot retain ambiguous tuning")
	var enabled_zero_spread := _definition()
	enabled_zero_spread.spread_enabled = true
	_check(_has_error(enabled_zero_spread.get_validation_errors(), "positive"), "enabled spread must be positive")
	var non_finite_spread := _definition()
	non_finite_spread.spread_enabled = true
	non_finite_spread.spread_degrees = NAN
	_check(_has_error(non_finite_spread.get_validation_errors(), "spread_degrees"), "spread rejects non-finite values")

	var disabled_heat_data := _definition()
	disabled_heat_data.heat_per_shot = 1.0
	_check(_has_error(disabled_heat_data.get_validation_errors(), "heat fields"), "disabled heat requires a canonical all-zero state")
	var invalid_heat := _definition()
	invalid_heat.heat_enabled = true
	invalid_heat.heat_per_shot = 11.0
	invalid_heat.heat_capacity = 10.0
	invalid_heat.heat_cooldown_per_second = 1.0
	_check(_has_error(invalid_heat.get_validation_errors(), "must not exceed"), "one shot cannot exceed heat capacity")
	var non_finite_heat := _complete_definition()
	non_finite_heat.heat_capacity = INF
	_check(_has_error(non_finite_heat.get_validation_errors(), "heat_capacity"), "heat bounds reject infinities")

	var disabled_ammunition_data := _definition()
	disabled_ammunition_data.reserve_ammunition = 1
	_check(_has_error(disabled_ammunition_data.get_validation_errors(), "ammunition fields"), "disabled ammunition requires a canonical all-zero state")
	var invalid_ammunition := _definition()
	invalid_ammunition.ammunition_enabled = true
	invalid_ammunition.magazine_capacity = 3
	invalid_ammunition.ammunition_per_shot = 4
	_check(_has_error(invalid_ammunition.get_validation_errors(), "must not exceed"), "one shot cannot cost more ammunition than a magazine holds")
	var excessive_ammunition := _complete_definition()
	excessive_ammunition.reserve_ammunition = DefinitionScript.MAX_AMMUNITION + 1
	_check(_has_error(excessive_ammunition.get_validation_errors(), "reserve_ammunition"), "ammunition has a finite integer ceiling")

	var invalid_presentation := _definition()
	invalid_presentation.presentation_id = &"Bad Presentation"
	invalid_presentation.fire_audio_id = &""
	invalid_presentation.impact_audio_id = &"Impact"
	invalid_presentation.dry_fire_audio_id = &"dry-fire"
	_check(invalid_presentation.get_validation_errors().size() >= 4, "presentation and audio identifiers all use stable-ID grammar")

	var invalid_status := _definition()
	invalid_status.evidence_status = 99
	_check(
		invalid_status.get_evidence_status_id() == &"invalid"
			and _has_error(invalid_status.get_validation_errors(), "evidence_status"),
		"unknown evidence state cannot inherit a more credible status"
	)
	var unsourced_claim := _definition()
	unsourced_claim.evidence_status = DefinitionScript.EvidenceStatus.AUTHENTICATED
	_check(_has_error(unsourced_claim.get_validation_errors(), "evidence reference"), "authenticated claims require evidence")
	var duplicate_reference := _complete_definition()
	duplicate_reference.evidence_references = PackedStringArray(["design_log_a", "design_log_a"])
	_check(_has_error(duplicate_reference.get_validation_errors(), "duplicated"), "evidence references are unique")
	var padded_reference := _complete_definition()
	padded_reference.evidence_references = PackedStringArray([" padded"])
	_check(_has_error(padded_reference.get_validation_errors(), "trimmed"), "evidence references are bounded clean single-line text")


func _test_detached_snapshots_audit_and_zero_authority() -> void:
	var weapon := _complete_definition()
	var snapshot := weapon.get_definition_snapshot()
	_check(
		_dictionary_has_exact_keys(snapshot.evidence as Dictionary, COMMON_EVIDENCE_KEYS),
		"definition snapshot exposes the exact common evidence core"
	)
	(snapshot.resolution as Dictionary)["damage_per_hit"] = -1.0
	((snapshot.optional_systems as Dictionary).heat as Dictionary)["capacity"] = -1.0
	(snapshot.evidence.references as PackedStringArray).append("mutation")
	(snapshot.authority as Dictionary)["gameplay"] = true
	var fresh := weapon.get_definition_snapshot()
	_check((fresh.resolution as Dictionary).damage_per_hit == 17.25, "resolution snapshots are detached")
	_check(((fresh.optional_systems as Dictionary).heat as Dictionary).capacity == 40.0, "nested optional-system snapshots are detached")
	_check(not (fresh.evidence.references as PackedStringArray).has("mutation"), "evidence arrays are detached")
	_check(not bool((fresh.authority as Dictionary).gameplay), "snapshot authority mutation cannot alter the Resource")

	var audit := weapon.get_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "audit reports validation without mutating the definition")
	((audit.definition as Dictionary).presentation as Dictionary)["presentation_id"] = &"mutation"
	(audit.authority as Dictionary)["audio"] = true
	var fresh_audit := weapon.get_audit_report()
	_check(
		((fresh_audit.definition as Dictionary).presentation as Dictionary).presentation_id == &"amber_bolt",
		"nested audit dictionaries are detached"
	)
	_check(not bool((fresh_audit.authority as Dictionary).audio), "audit authority dictionaries are detached")

	var authority := weapon.get_authority_report()
	var exact_zero := _dictionary_has_exact_keys(authority, COMMON_AUTHORITY_KEYS)
	for key in COMMON_AUTHORITY_KEYS:
		exact_zero = exact_zero and authority[key] is bool and not bool(authority[key])
	_check(exact_zero, "WeaponDefinition owns exactly zero common renderer, gameplay, streaming, save, network, physics, generation, origin, clock, or audio authority")
	_check(not weapon.has_method("_process") and not weapon.has_method("_physics_process"), "data Resource has no frame or physics lifecycle")


func _test_resource_round_trip() -> void:
	var weapon := _complete_definition()
	weapon.weapon_id = &"round_trip_lance"
	var resource_path := "user://weapon_definition_test_%d.tres" % Time.get_ticks_usec()
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var save_error := ResourceSaver.save(weapon, resource_path)
	_check(save_error == OK, "WeaponDefinition saves as a normal typed Godot Resource")
	var loaded := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as WeaponDefinition
	_check(loaded != null, "saved definition reloads with its concrete type")
	if loaded != null:
		_check(loaded.is_definition_valid(), "round-tripped definition remains valid")
		_check(loaded.get_definition_snapshot() == weapon.get_definition_snapshot(), "round trip preserves the complete detached data contract")
		_check(loaded.get_audit_report() == weapon.get_audit_report(), "round trip preserves evidence, validation, and audit meaning")
		_check(loaded.get_authority_report() == weapon.get_authority_report(), "round trip preserves exact zero authority")
	if FileAccess.file_exists(resource_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		_check(remove_error == OK, "temporary WeaponDefinition Resource is removed")


func _complete_definition() -> WeaponDefinition:
	var weapon := _definition()
	weapon.weapon_id = &"test_amber_lance"
	weapon.display_name = "Test amber lance"
	weapon.resolution_mode = DefinitionScript.ResolutionMode.PROJECTILE
	weapon.range_meters = 825.5
	weapon.damage_per_hit = 17.25
	weapon.cadence_shots_per_second = 6.5
	weapon.faction_policy = DefinitionScript.FactionPolicy.FIXED_FACTION
	weapon.fixed_faction_id = &"range_defence"
	weapon.friendly_fire_policy = DefinitionScript.FriendlyFirePolicy.ALLOW
	weapon.spread_enabled = true
	weapon.spread_degrees = 1.75
	weapon.heat_enabled = true
	weapon.heat_per_shot = 8.0
	weapon.heat_capacity = 40.0
	weapon.heat_cooldown_per_second = 5.0
	weapon.ammunition_enabled = true
	weapon.magazine_capacity = 24
	weapon.reserve_ammunition = 96
	weapon.ammunition_per_shot = 2
	weapon.presentation_id = &"amber_bolt"
	weapon.fire_audio_id = &"amber_bolt_fire"
	weapon.impact_audio_id = &"amber_bolt_impact"
	weapon.dry_fire_audio_id = &"amber_bolt_dry_fire"
	weapon.evidence_status = DefinitionScript.EvidenceStatus.PROVISIONAL
	weapon.evidence_references = PackedStringArray(["design_log_a", "balance_sheet_b"])
	weapon.evidence_notes = "Provisional test fixture; not authenticated."
	return weapon


func _definition() -> WeaponDefinition:
	return DefinitionScript.new() as WeaponDefinition


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _dictionary_has_exact_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("WEAPON_DEFINITION_TEST_OK")
		quit(0)
	else:
		print("WEAPON_DEFINITION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
