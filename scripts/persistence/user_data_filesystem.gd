class_name UserDataFilesystem
extends RefCounted

## Narrow filesystem seam used by UserDataStore. Production writes are flushed
## through FileAccess before publication; Godot 4.7 does not expose an fsync or
## directory-sync primitive to GDScript.


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func directory_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))


func ensure_parent_directory(path: String) -> Error:
	var parent := ProjectSettings.globalize_path(path).get_base_dir()
	if parent.is_empty() or DirAccess.dir_exists_absolute(parent):
		return OK
	return DirAccess.make_dir_recursive_absolute(parent)


func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error(), "bytes": PackedByteArray()}
	var length := file.get_length()
	if length < 0 or length > maximum_bytes:
		file.close()
		return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
	var bytes := file.get_buffer(length)
	var read_error := file.get_error()
	file.close()
	if read_error != OK or bytes.size() != length:
		return {
			"error": read_error if read_error != OK else ERR_FILE_CORRUPT,
			"bytes": PackedByteArray(),
		}
	return {"error": OK, "bytes": bytes}


func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_buffer(bytes)
	var store_error := file.get_error()
	if not stored or store_error != OK:
		file.close()
		return store_error if store_error != OK else ERR_FILE_CANT_WRITE
	file.flush()
	var flush_error := file.get_error()
	file.close()
	return flush_error


func remove_path(path: String) -> Error:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func rename_path(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	)
