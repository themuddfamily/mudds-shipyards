class_name PressRepeaterOpponent
extends ResolverBackedOpponent

## Dedicated Hold contact. The inherited formed interceptor hull and pressing
## station movement are presentation/motion stock; every shot and damage event
## still belongs to the single live resolver and its existing lifecycle adapter.
const Catalog := preload("res://scripts/combat/combat_scenario_catalog.gd")


func _ready() -> void:
	var profile := Catalog.new().get_profile_snapshot(&"press_repeater")
	var weapon := profile.get("weapon", {}) as Dictionary
	var tactics := profile.get("tactics", {}) as Dictionary
	weapon_range = float(weapon.get("range", 260.0))
	weapon_damage = float(weapon.get("damage_per_shot", 9.0))
	weapon_origin_tolerance = float(weapon.get("origin_tolerance", 22.0))
	engagement_range = float(tactics.get("engagement_range", 220.0))
	preferred_range = float(tactics.get("preferred_engagement_distance", 70.0))
	retreat_range = float(tactics.get("minimum_arming_range", 20.0))
	telegraph_time = float(tactics.get("telegraph_time", 0.16))
	weapon_cooldown = float(tactics.get("weapon_cooldown", 0.18))
	super()


func get_display_name() -> String:
	return "Perimeter press repeater"


func get_component_id() -> StringName:
	return &"press-repeater-opponent"


func get_weapon_id() -> StringName:
	return &"perimeter_press_repeater"


func get_pulse_profile_id() -> StringName:
	return PulseWeaponPresentation.PROFILE_REPEATER


func get_combat_audio_profile_id() -> StringName:
	return CombatAudioPresentation.WEAPON_PROFILE_REPEATER
