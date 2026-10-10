class_name SalvageInspectionStation
extends Node3D

## Authored modern station inspection, separate from the geometry-only terrace.
## Observations never move stock or grant resources. GameFlow supplies the shared
## store callbacks; this owner never opens a file or replaces its whole payload.

signal snapshot_changed(snapshot: Dictionary)

const INTERACTABLE := preload("res://scripts/interaction/salvage_inspection_interactable.gd")
const PERSISTENCE_SLOT := "salvage_terrace_inspection"
const CONSOLE_ID: StringName = &"manifest"
const COMPONENT_IDS := ["field_coil", "relay_board", "cracked_coupling"]
const COMPONENT_NAMES := ["FIELD COIL", "RELAY BOARD", "CRACKED COUPLING"]
const COMPONENT_RESULTS := ["GRADE A // USABLE", "GRADE B // USABLE", "GRADE D // RECYCLE"]
const TARGET_POSITIONS := [
	Vector3(-16.0, 1.05, 8.25), Vector3(-14.4, 1.05, 8.25),
	Vector3(-12.8, 1.05, 8.25), Vector3(-9.5, 1.05, 8.25),
]

var _inspected: Array[String] = []
var _manifest_requested := false
var _durable_record: Dictionary = {"inspected": [], "manifest_published": false}
var _read: Callable
var _write: Callable
var _loaded := false
var _busy := false
var _last_save_reason := "STORE NOT CONNECTED"
var _targets: Dictionary = {}
var _labels: Dictionary = {}


func _ready() -> void:
	set_meta("evidence_status", &"modern_interpretation")
	set_meta("historical_authenticity_claim", false)
	if _targets.is_empty():
		_build_controls()
	_refresh_presentation()


## read(slot) -> {accepted: bool, record: Dictionary}; an absent slot is {}.
## write(slot, record) -> {accepted: bool, ...}. The integration owner must load
## the current shared envelope, retain all unrelated keys, refuse unsafe store
## recovery/unsupported slot data and use its existing atomic commit generation.
## Reconfiguration merges durable observations with genuine unsaved work; it
## never resets earned progress and never writes during a read/re-entry.
func configure_persistence(read: Callable, write: Callable) -> Dictionary:
	if _busy or not read.is_valid() or not write.is_valid():
		return {"accepted": false, "reason": &"invalid_persistence_binding"}
	_read = read
	_write = write
	_loaded = false
	_busy = true
	var result := _load_record()
	_busy = false
	_refresh_presentation()
	return result


func get_interactable(target_id: StringName) -> Area3D:
	return _targets.get(target_id) as Area3D


func get_readout_text(target_id: StringName) -> String:
	var mesh := _labels.get(target_id) as TextMesh
	return mesh.text if mesh != null else ""


func get_snapshot() -> Dictionary:
	return {
		"inspected": _inspected.duplicate(),
		"manifest_requested": _manifest_requested,
		"manifest_published": bool(_durable_record.manifest_published),
		"save_pending": _record() != _durable_record,
		"persistence_ready": _loaded,
		"last_save_reason": _last_save_reason,
		"inventory_authority": false,
		"reward_authority": false,
	}.duplicate(true)


func get_prompt(target_id: StringName) -> String:
	if not is_inside_tree() or is_queued_for_deletion():
		return ""
	if target_id == CONSOLE_ID:
		if bool(_durable_record.manifest_published):
			return "[ E ]  SALVAGE MANIFEST PUBLISHED // 3/3"
		if _record() != _durable_record:
			return "[ E ]  RETRY SALVAGE SAVE // %d/3 INSPECTED" % _inspected.size()
		if _inspected.size() < COMPONENT_IDS.size():
			return "[ E ]  SALVAGE INSPECTION // %d/3 // INSPECT ALL COMPONENTS" % _inspected.size()
		return "[ E ]  PUBLISH SALVAGE MANIFEST // %d/3 INSPECTED" % _inspected.size()
	var index := COMPONENT_IDS.find(String(target_id))
	if index < 0:
		return ""
	if _inspected.has(String(target_id)):
		return "[ E ]  %s // %s%s" % [COMPONENT_NAMES[index], COMPONENT_RESULTS[index],
			" // SAVE PENDING" if not (_durable_record.inspected as Array).has(String(target_id)) else ""]
	return "[ E ]  INSPECT %s" % COMPONENT_NAMES[index]


func inspect(target_id: StringName, actor: Node) -> Dictionary:
	var target := get_interactable(target_id)
	if _busy or not is_inside_tree() or is_queued_for_deletion() \
			or not is_instance_valid(target) or not bool(target.call("can_interact", actor)):
		return {"accepted": false, "reason": &"inspection_unavailable"}
	_busy = true
	if target_id == CONSOLE_ID:
		if _inspected.size() == COMPONENT_IDS.size():
			_manifest_requested = true
	elif COMPONENT_IDS.has(String(target_id)) and not _inspected.has(String(target_id)):
		_inspected.append(String(target_id))
		_order_inspected()
	var saved := _save_record() if _record() != _durable_record else {"accepted": true, "reason": &"unchanged"}
	_busy = false
	_refresh_presentation()
	return {"accepted": true,
		"reason": &"manifest_incomplete" if target_id == CONSOLE_ID and _inspected.size() < 3 else &"inspection_recorded",
		"persistence": saved}.duplicate(true)


func _record() -> Dictionary:
	return {"inspected": _inspected.duplicate(), "manifest_published": _manifest_requested}


func _load_record() -> Dictionary:
	var response: Variant = _read.call(PERSISTENCE_SLOT)
	if not response is Dictionary or not response.get("accepted") is bool \
			or not bool(response.accepted):
		_last_save_reason = "LOAD REFUSED // RETRY AT CONSOLE"
		return {"accepted": false, "reason": &"inspection_load_refused"}
	var raw: Variant = response.get("record", null)
	if not is_valid_persistence_record(raw):
		_last_save_reason = "UNSUPPORTED RECORD // SAVE BLOCKED"
		return {"accepted": false, "reason": &"invalid_inspection_record"}
	var record: Dictionary = (raw as Dictionary).duplicate(true) if not (raw as Dictionary).is_empty() else {"inspected": [], "manifest_published": false}
	# IDs are a set of observations; differing JSON array order must not cause
	# a replay write. Always present/save them in the authored component order.
	var ordered_ids: Array[String] = []
	for component_id in COMPONENT_IDS:
		if (record.inspected as Array).has(component_id):
			ordered_ids.append(component_id)
	record.inspected = ordered_ids
	# A binding cannot rewind a previously confirmed record on the retained node.
	for component_id in _durable_record.inspected:
		if not (record.inspected as Array).has(component_id):
			_last_save_reason = "OLDER RECORD // SAVE BLOCKED"
			return {"accepted": false, "reason": &"inspection_record_regressed"}
	if bool(_durable_record.manifest_published) and not bool(record.manifest_published):
		_last_save_reason = "OLDER MANIFEST // SAVE BLOCKED"
		return {"accepted": false, "reason": &"inspection_record_regressed"}
	_durable_record = record.duplicate(true)
	for component_id in record.inspected:
		if not _inspected.has(component_id):
			_inspected.append(component_id)
	_order_inspected()
	_manifest_requested = _manifest_requested or bool(record.manifest_published)
	_loaded = true
	_last_save_reason = "SAVED"
	return {"accepted": true, "reason": &"inspection_restored"}


func _save_record() -> Dictionary:
	if not _read.is_valid() or not _write.is_valid():
		_last_save_reason = "STORE NOT CONNECTED // RETRY AT CONSOLE"
		return {"accepted": false, "reason": &"inspection_store_unavailable"}
	if not _loaded:
		var loaded := _load_record()
		if not bool(loaded.accepted):
			return loaded
	var record := _record()
	var response: Variant = _write.call(PERSISTENCE_SLOT, record.duplicate(true))
	if not response is Dictionary or not response.get("accepted") is bool \
			or not bool(response.accepted):
		_last_save_reason = "SAVE REFUSED // RETRY AT CONSOLE"
		return {"accepted": false, "reason": &"inspection_save_pending"}
	_durable_record = record.duplicate(true)
	_last_save_reason = "SAVED"
	return {"accepted": true, "reason": &"inspection_saved"}


static func is_valid_persistence_record(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	if raw.size() != 2 or not raw.get("inspected") is Array \
			or not raw.get("manifest_published") is bool:
		return false
	var ids: Array = raw.inspected
	if ids.size() > COMPONENT_IDS.size():
		return false
	var seen: Array[String] = []
	for id in ids:
		if not id is String or not COMPONENT_IDS.has(id) or seen.has(id):
			return false
		seen.append(id)
	return not bool(raw.manifest_published) or ids.size() == COMPONENT_IDS.size()


func _order_inspected() -> void:
	var ordered: Array[String] = []
	for id in COMPONENT_IDS:
		if _inspected.has(id):
			ordered.append(id)
	_inspected = ordered


func _refresh_presentation() -> void:
	for target_id: StringName in _labels:
		var mesh := _labels[target_id] as TextMesh
		if target_id == CONSOLE_ID:
			mesh.text = "SALVAGE INSPECTION\n%d/3 INSPECTED\n%s\nMODERN INTERPRETATION" % [
				_inspected.size(), "MANIFEST PUBLISHED" if bool(_durable_record.manifest_published)
				else ("MANIFEST SAVE PENDING" if _manifest_requested else _last_save_reason)]
		else:
			var index := COMPONENT_IDS.find(String(target_id))
			mesh.text = "%s\n%s" % [COMPONENT_NAMES[index], COMPONENT_RESULTS[index]
				if _inspected.has(String(target_id)) else "UNINSPECTED"]
			if _inspected.has(String(target_id)) and not (_durable_record.inspected as Array).has(String(target_id)):
				mesh.text += "\nSAVE PENDING"
	snapshot_changed.emit(get_snapshot())


func _build_controls() -> void:
	# A narrow physical bench at the lower pad's aft edge, beside the existing
	# stored cages/trolley. Nothing widens the floor or occupies its through route.
	_box("InspectionBench", Vector3(-14.4, 0.82, 8.25), Vector3(4.8, 0.14, 0.7), Color("334f59"))
	_box("BenchLegPort", Vector3(-16.5, 0.375, 8.25), Vector3(0.18, 0.75, 0.5), Color("172930"))
	_box("BenchLegStarboard", Vector3(-12.3, 0.375, 8.25), Vector3(0.18, 0.75, 0.5), Color("172930"))
	_box("ManifestPedestal", Vector3(-9.5, 0.45, 8.25), Vector3(0.85, 0.9, 0.7), Color("334f59"))
	for index in range(4):
		var target := INTERACTABLE.new()
		var id := CONSOLE_ID if index == 3 else StringName(COMPONENT_IDS[index])
		target.name = "ManifestConsole" if index == 3 else COMPONENT_NAMES[index].to_pascal_case()
		target.position = TARGET_POSITIONS[index]
		target.configure(id, inspect, get_prompt)
		add_child(target)
		_targets[id] = target
		var mesh: PrimitiveMesh
		if index == 0:
			var coil := CylinderMesh.new()
			coil.top_radius = 0.20
			coil.bottom_radius = 0.20
			coil.height = 0.30
			mesh = coil
		else:
			var block := BoxMesh.new()
			block.size = Vector3(0.50, 0.12, 0.32) if index == 1 else Vector3(0.32, 0.30, 0.32)
			mesh = block
		var visual := MeshInstance3D.new()
		visual.name = "InspectedComponent" if index < 3 else "ConsoleFace"
		visual.mesh = mesh
		visual.position.y = -0.10 if index == 1 else (-0.01 if index < 3 else 0.0)
		visual.material_override = _material(Color("bd8b50") if index < 3 else Color("172930"))
		target.add_child(visual)
		var label := MeshInstance3D.new()
		label.name = "InspectionReadout"
		var text := TextMesh.new()
		text.font_size = 28
		text.pixel_size = 0.0035 if index < 3 else 0.003
		text.depth = 0.0
		label.mesh = text
		label.material_override = _material(Color("9ff5f2"), true)
		label.position = Vector3(0.0, 0.55, -0.30)
		label.rotation.y = PI
		target.add_child(label)
		_labels[id] = text


func _box(node_name: String, at: Vector3, size: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(colour)
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _material(colour: Color, readout: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.55
	if readout:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
