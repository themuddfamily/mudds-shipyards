class_name ShipPerspectiveAudioSceneAdapter
extends Node

## Scene-local production composition for a HeroShip's caller-owned camera view.
## It forwards the parent signal only; camera and flight authority remain on the
## parent HeroShip and the resident ShipPerspectiveAudioBinding.

const Binding := preload("res://scripts/audio/ship_perspective_audio_binding.gd")

var _binding: RefCounted
var _parent: Node


func _enter_tree() -> void:
	if _binding != null:
		call_deferred("_rebind")


func _ready() -> void:
	call_deferred("_rebind")


func _exit_tree() -> void:
	_unbind()


func _rebind() -> void:
	if not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null or not parent.has_method(&"get_ship_audio_rig") \
			or not parent.has_signal(&"camera_view_changed"):
		return
	if _binding == null:
		_binding = Binding.new()
	_parent = parent
	var result: Dictionary = _binding.bind(parent.call(&"get_ship_audio_rig"))
	if bool(result.get("accepted", false)) \
			and not parent.camera_view_changed.is_connected(_on_camera_view_changed):
		parent.camera_view_changed.connect(_on_camera_view_changed)


func _unbind() -> void:
	if is_instance_valid(_parent) and _parent.camera_view_changed.is_connected(_on_camera_view_changed):
		_parent.camera_view_changed.disconnect(_on_camera_view_changed)
	if _binding != null and bool(_binding.get_snapshot().get("attached", false)):
		_binding.detach()


func _on_camera_view_changed(view: StringName) -> void:
	if _binding == null:
		return
	var perspective: StringName = &"cockpit" if view == &"COCKPIT" else &"exterior"
	var generation := int(_binding.get_snapshot().get("generation", -1))
	_binding.present_perspective(perspective, generation)


func get_snapshot() -> Dictionary:
	return _binding.get_snapshot() if _binding != null else {"attached": false}
