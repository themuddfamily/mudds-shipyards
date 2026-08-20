class_name ModernFleetRoleProfile
extends RefCounted

## A data-only role candidate for the next fleet increment.
##
## This is deliberately not a ship, scene, berth, or historical claim.  It is
## the pre-art budget gate for one modern interpretation of a gunship.  A
## future implementation may consume this profile only after it supplies the
## normal ShipDefinition, presentation, collision, boarding, and lifecycle
## contracts.  Keeping the candidate here means a geometry pass cannot quietly
## turn a role into a statistical upgrade.

const SCHEMA_VERSION := 1
const PROFILE_ID: StringName = &"bulwark_gunship_candidate"
const ROLE_ID: StringName = &"gunship"
const EVIDENCE_STATUS: StringName = &"new"

const HIGHER_IS_BETTER := [
	"maximum_speed", "thrust_acceleration", "brake_acceleration", "boost_speed",
	"boost_multiplier", "yaw_speed_degrees", "roll_speed_degrees",
	"throttle_response", "maximum_hull", "landing_maximum_speed",
]
const LOWER_IS_BETTER := ["passive_drag", "engine_start_time", "weapon_cooldown"]
const REQUIRED_AXES := HIGHER_IS_BETTER + LOWER_IS_BETTER

## The deliberate trade: a gunship owns hull and sustained fire, but gives up
## small-craft agility, launch response, and landing margin.
const PROFILE := {
	"profile_id": PROFILE_ID,
	"role_id": ROLE_ID,
	"display_name": "Bulwark Gunship (modern candidate)",
	"role_name": "Gunship",
	"evidence_status": EVIDENCE_STATUS,
	"evidence_references": [],
	"compatibility_tags": [&"medium_craft", &"gunship", &"single_pilot"],
	"scale_band": &"medium",
	"interior_expected": false,
	"crew_story": "Hold the line: trade fighter agility for durable, repeatable fire.",
	"weakness": "Slow to launch, turn, and land; it needs space and a committed pilot.",
	"signature_axes": {
		"maximum_hull": &"maximum",
		"weapon_cooldown": &"minimum",
	},
	"flight_profile": {
		# Just enough top-end to cross a firing lane; still below the transport
		# specialist and nowhere near the recon/response envelope once turn rate
		# and launch response are counted.
		"maximum_speed": 98.0,
		"thrust_acceleration": 22.0,
		"brake_acceleration": 30.0,
		"passive_drag": 2.35,
		"throttle_response": 6.4,
		"boost_speed": 96.0,
		"boost_multiplier": 1.22,
		"yaw_speed_degrees": 46.0,
		"roll_speed_degrees": 68.0,
	},
	"systems_profile": {
		"engine_start_time": 2.75,
		"weapon_cooldown": 0.30,
		"maximum_hull": 320.0,
		"landing_maximum_speed": 13.0,
	},
}


static func get_profile() -> Dictionary:
	return (PROFILE as Dictionary).duplicate(true)


static func get_required_axes() -> Array:
	return REQUIRED_AXES.duplicate()


## Compare the candidate against the current production definitions' merged
## flight/system profiles.  This is a budget check only; it has no runtime
## authority and intentionally does not instantiate a scene.
static func audit_against_profiles(existing: Dictionary) -> Dictionary:
	var candidate: Dictionary = get_profile()
	var candidate_values := _merged_values(candidate)
	var errors := PackedStringArray()
	var wins := {}
	var losses := {}
	for id in existing:
		var other: Dictionary = existing[id]
		var other_values := _merged_values(other)
		var candidate_wins := 0
		var other_wins := 0
		for axis: String in REQUIRED_AXES:
			var ours := float(candidate_values[axis])
			var theirs := float(other_values.get(axis, NAN))
			if is_nan(theirs) or is_equal_approx(ours, theirs):
				continue
			var higher := HIGHER_IS_BETTER.has(axis)
			if (higher and ours > theirs) or (not higher and ours < theirs):
				candidate_wins += 1
			else:
				other_wins += 1
		if candidate_wins < 2:
			errors.append("candidate has fewer than two advantages over %s" % id)
		if other_wins < 2:
			errors.append("candidate has fewer than two deliberate weaknesses against %s" % id)
		wins[id] = candidate_wins
		losses[id] = other_wins
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"candidate": candidate,
		"candidate_wins": wins,
		"candidate_weaknesses": losses,
	}


static func _merged_values(profile: Dictionary) -> Dictionary:
	var values: Dictionary = (profile.get("flight_profile", {}) as Dictionary).duplicate()
	values.merge(profile.get("systems_profile", {}) as Dictionary)
	return values
