@tool
extends EditorPlugin

const AuthoredExport := preload("res://addons/zenith_authored_export/export_plugin.gd")

var _authored_export: EditorExportPlugin


func _enter_tree() -> void:
	_authored_export = AuthoredExport.new()
	add_export_plugin(_authored_export)


func _exit_tree() -> void:
	if _authored_export != null:
		remove_export_plugin(_authored_export)
		_authored_export = null
