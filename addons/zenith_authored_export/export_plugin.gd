@tool
extends EditorExportPlugin

const MANIFEST_PATH := "res://assets/models/zenith/zenith_authored_asset_manifest.json"
const RAW_FILES := {
	"res://assets/models/zenith/zenith_authored_art.glb": "glb_sha256",
	"res://art_source/zenith/zenith_authored_v1.blend": "blend_sha256",
}


func _get_name() -> String:
	return "ZenithAuthoredSources"


func _export_begin(
	_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int
) -> void:
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		_refuse("Cannot read the authored asset manifest.")
		return
	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	if not parsed is Dictionary:
		_refuse("The authored asset manifest is not a dictionary.")
		return
	var manifest := parsed as Dictionary
	var payloads := {}
	for resource_path: String in RAW_FILES:
		var file := FileAccess.open(resource_path, FileAccess.READ)
		if file == null:
			_refuse("Cannot read authored source: %s" % resource_path)
			return
		var length := file.get_length()
		var bytes := file.get_buffer(length)
		if bytes.is_empty() or bytes.size() != length:
			_refuse("Authored source is empty or incomplete: %s" % resource_path)
			return
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		var digest := hash.finish().hex_encode()
		if digest != str(manifest.get(RAW_FILES[resource_path], "")):
			_refuse("Authored source hash differs from the manifest: %s" % resource_path)
			return
		payloads[resource_path] = bytes
	# Validate both inputs before injecting either one. Keep the ordinary GLB
	# import remap; FileAccess reads these original bytes for the strict audit.
	for resource_path: String in RAW_FILES:
		add_file(resource_path, payloads[resource_path], false)


func _refuse(reason: String) -> void:
	get_export_platform().add_message(
		EditorExportPlatform.EXPORT_MESSAGE_ERROR, "Zenith authored sources", reason
	)
	push_error("ZENITH_AUTHORED_EXPORT_INPUT_ERROR: %s" % reason)
