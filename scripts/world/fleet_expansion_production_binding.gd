class_name FleetExpansionProductionBinding
extends Node3D

## Standalone composition of the authored FleetExpansionBerths and three NEW
## craft. This node owns composition only; each craft and berth retains its
## caller-owned contracts and no flight/lease authority crosses this seam.

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const Cargo := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")
const CRAFT_SPECS: Array[Dictionary] = [
	{"pad_id": &"dock_04_cargo", "craft_id": &"cinder_cargo_hauler", "script": Cargo},
	{"pad_id": &"dock_05_bomber", "craft_id": &"cinder_long_range_bomber", "script": Bomber},
	{"pad_id": &"dock_06_interceptor", "craft_id": &"cinder_light_interceptor", "script": Interceptor},
]

var _berths: Node3D
var _craft_by_id: Dictionary = {}
var _built := false
var _composition_error: StringName = &""


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	call_deferred("_assemble")


func _assemble() -> void:
	if _built or is_queued_for_deletion() or not is_inside_tree():
		return
	_berths = Berths.new()
	_berths.name = "FleetExpansionBerths"
	add_child(_berths)
	for spec in CRAFT_SPECS:
		var craft := (spec.get("script") as GDScript).new() as Node3D
		craft.name = String(spec.craft_id)
		craft.set_meta(&"evidence_status", &"NEW")
		add_child(craft)
		_craft_by_id[spec.craft_id] = craft
	await get_tree().process_frame
	for spec in CRAFT_SPECS:
		var result: Dictionary = _berths.call(
			"attach_craft", spec.pad_id, _craft_by_id[spec.craft_id], spec.craft_id
		)
		if not bool(result.get("accepted", false)):
			_composition_error = StringName(result.get("reason", &"attachment_failed"))
			return
	_built = true


func detach_craft(craft_id: StringName) -> Dictionary:
	if _berths == null or not _craft_by_id.has(craft_id):
		return {"accepted": false, "reason": &"unknown_craft"}
	for spec in CRAFT_SPECS:
		if spec.craft_id == craft_id:
			return _berths.call("detach_craft", spec.pad_id, _craft_by_id[craft_id])
	return {"accepted": false, "reason": &"unknown_craft"}


func reattach_craft(craft_id: StringName) -> Dictionary:
	if _berths == null or not _craft_by_id.has(craft_id):
		return {"accepted": false, "reason": &"unknown_craft"}
	for spec in CRAFT_SPECS:
		if spec.craft_id == craft_id:
			return _berths.call("attach_craft", spec.pad_id, _craft_by_id[craft_id], craft_id)
	return {"accepted": false, "reason": &"unknown_craft"}


func get_fleet_snapshot() -> Dictionary:
	var craft_snapshots: Array[Dictionary] = []
	for spec in CRAFT_SPECS:
		var craft := _craft_by_id.get(spec.craft_id) as Node3D
		craft_snapshots.append({
			"craft_id": spec.craft_id,
			"pad_id": spec.pad_id,
			"attached": bool((_berths.call("get_attachment_snapshot", spec.pad_id) if _berths != null else {}).get("attached", false)),
			"instance_id": craft.get_instance_id() if is_instance_valid(craft) else 0,
			"boarding_anchor": craft.call("get_boarding_marker").global_position if is_instance_valid(craft) else Vector3.INF,
		})
	return {"built": _built, "composition_error": _composition_error, "craft": craft_snapshots}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _built:
		errors.append("fleet expansion composition is not built")
	if _composition_error != &"":
		errors.append("composition failed: %s" % _composition_error)
	if _berths != null and not bool(_berths.call("get_audit_report").get("valid", false)):
		errors.append("berth audit failed")
	for spec in CRAFT_SPECS:
		var craft := _craft_by_id.get(spec.craft_id) as Node3D
		if craft == null or not bool(craft.call("get_audit_report").get("valid", false)):
			errors.append("craft audit failed: %s" % spec.craft_id)
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"fleet_count": _craft_by_id.size(),
		"ship_authority": false,
		"flight_authority": false,
		"berth_lease_authority": false,
		"network_authority": false,
	}.duplicate(true)
