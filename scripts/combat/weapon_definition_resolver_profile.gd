class_name WeaponDefinitionResolverProfile
extends RefCounted

## Pure fail-closed conversion from authored weapon data to the one profile
## shape accepted by CombatResolver. This object owns no registration or shot
## state and deliberately does not widen LiveCombatAuthority's API.

const WeaponDefinitionType := preload("res://scripts/combat/weapon_definition.gd")
const SCATTER_PELLET_COUNT := 3


static func get_conversion_errors(
	definition: WeaponDefinition,
	registered_faction_id: StringName,
	origin_tolerance_meters: float
	) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("weapon definition is required")
		return errors
	for validation_error in definition.get_validation_errors():
		errors.append("weapon definition invalid: %s" % validation_error)
	if definition.resolution_mode != WeaponDefinitionType.ResolutionMode.HITSCAN:
		errors.append("current CombatResolver conversion supports hitscan only")
	if registered_faction_id.is_empty():
		errors.append("registered_faction_id is required")
	elif definition.faction_policy == WeaponDefinitionType.FactionPolicy.FIXED_FACTION \
			and definition.fixed_faction_id != registered_faction_id:
		errors.append("fixed_faction_id must match the registered source faction")
	if definition.friendly_fire_policy != WeaponDefinitionType.FriendlyFirePolicy.DENY:
		errors.append("current CombatResolver conversion supports denied friendly fire only")
	if definition.heat_enabled:
		errors.append("current CombatResolver conversion does not support heat")
	if definition.ammunition_enabled:
		errors.append("current CombatResolver conversion does not support ammunition")
	if not is_finite(origin_tolerance_meters) or origin_tolerance_meters <= 0.0:
		errors.append("origin_tolerance_meters must be finite and positive")
	return errors


## Returns the exact existing registration dictionary keyed by stable weapon ID.
## An empty dictionary is the only failure result; there is no legacy fallback.
static func to_resolver_profiles(
	definition: WeaponDefinition,
	registered_faction_id: StringName,
	origin_tolerance_meters: float
	) -> Dictionary:
	if not get_conversion_errors(
		definition, registered_faction_id, origin_tolerance_meters
	).is_empty():
		return {}
	var profile := {
		"range": definition.range_meters,
		"damage": definition.damage_per_hit,
		"origin_tolerance": origin_tolerance_meters,
	}
	if definition.spread_enabled:
		# The first production spread case is intentionally frozen to one small,
		# odd fan. `damage_per_hit` remains the trigger budget authored by the
		# resource; the resolver divides it across these three authoritative rays.
		profile["damage"] = definition.damage_per_hit / float(SCATTER_PELLET_COUNT)
		profile["trigger_damage"] = definition.damage_per_hit
		profile["spread_degrees"] = definition.spread_degrees
		profile["pellet_count"] = SCATTER_PELLET_COUNT
	return {definition.weapon_id: profile}.duplicate(true)
