extends SceneTree

## Focused pre-art acceptance for one Phase 5 gunship role.  This test does
## not boot Main, create geometry, alter a ShipDefinition, or run lifecycle.

const Candidate := preload("res://scripts/fleet/modern_role_profile.gd")
const DEFINITIONS := [
	preload("res://assets/ships/torrent_provisional.tres"),
	preload("res://assets/ships/arrow_provisional.tres"),
	preload("res://assets/ships/jovian_provisional.tres"),
	preload("res://assets/ships/zenith_b7_observed.tres"),
	preload("res://assets/ships/halyard_new_design.tres"),
]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	var profile := Candidate.get_profile()
	_check(str(profile.get("profile_id", "")) == "bulwark_gunship_candidate", "candidate has a stable pre-art ID")
	_check(str(profile.get("role_id", "")) == "gunship", "candidate is explicitly a gunship role")
	_check(str(profile.get("evidence_status", "")) == "new", "candidate is marked as a modern new design")
	_check((profile.get("evidence_references", []) as Array).is_empty(), "candidate carries no historical evidence references")
	_check((profile.get("compatibility_tags", []) as Array).has(&"medium_craft"), "candidate publishes its medium-craft scale band")
	_check((profile.get("compatibility_tags", []) as Array).has(&"gunship"), "candidate publishes the gunship compatibility tag")
	_check(not str(profile.get("crew_story", "")).is_empty(), "candidate states the intended player story")
	_check(not str(profile.get("weakness", "")).is_empty(), "candidate states its lateral weakness")
	_check((profile.get("signature_axes", {}) as Dictionary).has("maximum_hull"), "candidate owns a durability signature")
	_check((profile.get("signature_axes", {}) as Dictionary).has("weapon_cooldown"), "candidate owns a sustained-fire signature")

	var existing := {}
	for definition: ShipDefinition in DEFINITIONS:
		var values := definition.get_flight_profile().duplicate()
		values.merge(definition.get_systems_profile())
		existing[definition.get_ship_id()] = {"flight_profile": values}
	var report := Candidate.audit_against_profiles(existing)
	_check(bool(report.get("valid", false)), "candidate clears the pairwise lateral trade-off budget")
	_check((report.get("candidate_wins", {}) as Dictionary).size() == DEFINITIONS.size(), "candidate is compared against every current craft")
	_check((report.get("candidate_weaknesses", {}) as Dictionary).size() == DEFINITIONS.size(), "candidate records a weakness against every current craft")
	for ship_id in existing:
		_check(int((report.get("candidate_wins", {}) as Dictionary).get(ship_id, 0)) >= 2, "%s has at least two candidate advantages" % ship_id)
		_check(int((report.get("candidate_weaknesses", {}) as Dictionary).get(ship_id, 0)) >= 2, "%s preserves at least two candidate weaknesses" % ship_id)
	_check(Candidate.get_required_axes().size() == 13, "candidate budget covers all 13 shared handling axes")

	print("MODERN_GUNSHIP_ROLE_PROFILE: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
