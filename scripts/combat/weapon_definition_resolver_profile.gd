class_name WeaponDefinitionResolverProfile
extends RefCounted

## Pure fail-closed conversion from authored weapon data to the one profile
## shape accepted by CombatResolver. This object owns no registration or shot
## state and deliberately does not widen LiveCombatAuthority's API.

const WeaponDefinitionType := preload("res://scripts/combat/weapon_definition.gd")
const SCATTER_PELLET_COUNT := 3

## Profile keys that carry an accepted projectile's travel envelope into the
## resolver registry. A hitscan definition emits none of them, so an existing
## hitscan profile dictionary is byte-for-byte what it always was.
const PROJECTILE_SPEED_KEY := "projectile_speed"
const PROJECTILE_LIFETIME_KEY := "projectile_lifetime"
const PROJECTILE_RADIUS_KEY := "projectile_radius"
const PROJECTILE_PROFILE_KEYS := [
	PROJECTILE_SPEED_KEY,
	PROJECTILE_LIFETIME_KEY,
	PROJECTILE_RADIUS_KEY,
]


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
	if definition.resolution_mode != WeaponDefinitionType.ResolutionMode.HITSCAN \
			and definition.resolution_mode != WeaponDefinitionType.ResolutionMode.PROJECTILE:
		errors.append("current CombatResolver conversion supports hitscan and projectile only")
	if definition.resolution_mode == WeaponDefinitionType.ResolutionMode.PROJECTILE \
			and not definition.has_projectile_travel_envelope():
		# The one place a travelling weapon's speed is mandatory: a definition that
		# never authored one cannot reach the resolver at all, and is certainly
		# never approximated as an instantaneous hitscan.
		errors.append(
			"projectile_speed_mps must be positive, with lifetime and radius, "
			+ "before a projectile weapon can be converted"
		)
	if definition.resolution_mode == WeaponDefinitionType.ResolutionMode.PROJECTILE \
			and definition.spread_enabled:
		# One travelling bolt is one authoritative contact. The bounded scatter fan
		# is a hitscan-only trigger shape and is not approximated here.
		errors.append("current CombatResolver conversion does not support projectile spread")
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
	if definition.is_projectile_resolution():
		# The travel envelope is authority data, not presentation data: the
		# registry owns it so a travelling bolt can never widen its own speed,
		# flight ceiling, or contact radius after launch.
		profile[PROJECTILE_SPEED_KEY] = definition.projectile_speed_mps
		profile[PROJECTILE_LIFETIME_KEY] = definition.projectile_lifetime_seconds
		profile[PROJECTILE_RADIUS_KEY] = definition.projectile_radius_meters
		return {definition.weapon_id: profile}.duplicate(true)
	if definition.spread_enabled:
		# The first production spread case is intentionally frozen to one small,
		# odd fan. `damage_per_hit` remains the trigger budget authored by the
		# resource; the resolver divides it across these three authoritative rays.
		profile["damage"] = definition.damage_per_hit / float(SCATTER_PELLET_COUNT)
		profile["trigger_damage"] = definition.damage_per_hit
		profile["spread_degrees"] = definition.spread_degrees
		profile["pellet_count"] = SCATTER_PELLET_COUNT
	return {definition.weapon_id: profile}.duplicate(true)


## True when a registered resolver profile carries a complete travel envelope.
static func profile_is_projectile(profile: Dictionary) -> bool:
	for key: String in PROJECTILE_PROFILE_KEYS:
		if not profile.has(key):
			return false
	return true
