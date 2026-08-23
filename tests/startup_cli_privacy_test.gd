extends SceneTree

const StartupLoaderType := preload("res://scripts/game/startup_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		StartupLoaderType.cli_mode(PackedStringArray(["--version"])) == &"version",
		"version flag selects the early version path"
	)
	_check(
		StartupLoaderType.cli_mode(PackedStringArray(["--support-info"])) == &"support_info",
		"support-info flag selects the early support path"
	)
	_check(
		StartupLoaderType.cli_mode(PackedStringArray(["--support-info", "--version"])) == &"support_info",
		"support-info deterministically wins when both information flags are present"
	)
	var version := StartupLoaderType.format_cli_output(&"version")
	_check(version == "Mudds Shipyards 0.12.0", "version output is stable project identity only")
	var support := StartupLoaderType.format_cli_output(&"support_info")
	for required in ["Project: Mudds Shipyards", "Version: 0.12.0", "Godot: ", "OS: ", "Architecture: ", "Renderer: ", "Display: "]:
		_check(support.contains(required), "support output includes %s" % required.trim_suffix(": "))
	for forbidden in ["user://", "res://", "/root/", "\\Users\\", "token", "save"]:
		_check(not support.to_lower().contains(forbidden.to_lower()), "support output omits %s" % forbidden)
	_check(
		StartupLoaderType.format_cli_output(&"unknown") == "",
		"unsupported output mode remains empty"
	)
	if _failures.is_empty():
		print("STARTUP_CLI_PRIVACY_TEST_OK")
		quit(0)
		return
	print("STARTUP_CLI_PRIVACY_TEST_FAILED: ", "; ".join(_failures))
	quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
