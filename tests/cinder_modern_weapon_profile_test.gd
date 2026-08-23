extends SceneTree

const Cargo := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var cargo := Cargo.new()
	var interceptor := Interceptor.new()
	root.add_child(cargo)
	root.add_child(interceptor)
	await process_frame
	var cargo_weapon := cargo.get_weapon_definition()
	var interceptor_weapon := interceptor.get_weapon_definition()
	_check(cargo_weapon != null and cargo_weapon.is_definition_valid(), "cargo publishes a valid WeaponDefinition")
	_check(interceptor_weapon != null and interceptor_weapon.is_definition_valid(), "interceptor publishes a valid WeaponDefinition")
	_check(cargo_weapon.weapon_id != interceptor_weapon.weapon_id, "role-specific weapon IDs are distinct")
	_check(cargo_weapon.weapon_id == Cargo.WEAPON_ID, "cargo identity is explicit and stable")
	_check(interceptor_weapon.weapon_id == Interceptor.WEAPON_ID, "interceptor identity is explicit and stable")
	_check(cargo_weapon.get_evidence_status_id() == &"new" and interceptor_weapon.get_evidence_status_id() == &"new", "both profiles remain explicitly modern")
	var copied := cargo.get_weapon_definition()
	copied.weapon_id = &"tampered"
	_check(cargo.get_weapon_definition().weapon_id == Cargo.WEAPON_ID, "cargo profile is immutable-by-copy")
	_check(bool(cargo.get_audit_report().get("weapon_definition_valid", false)), "cargo audit includes its valid weapon identity")
	_check(bool(interceptor.get_audit_report().get("weapon_definition_valid", false)), "interceptor audit includes its valid weapon identity")
	cargo.queue_free()
	interceptor.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_modern_weapon_profile_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
