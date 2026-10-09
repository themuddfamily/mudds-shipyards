extends SceneTree

const StartupLoaderType := preload("res://scripts/game/startup_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for script_path in [
		"res://scripts/game/game_flow.gd",
		"res://scripts/world/shipyard_world.gd",
		"res://scripts/ships/hero_ship.gd",
	]:
		_check(not ResourceLoader.has_cached(script_path),
			"early Boot and CLI compilation leaves %s for the Main worker" % script_path.get_file())
	var probe_args := PackedStringArray(["--in-world-interruption-stage=arm"])
	_check(not bool(StartupLoaderType.in_world_probe_request(PackedStringArray(), "headless", "Dummy").requested),
		"ordinary boot does not opt into the in-world fixture")
	_check(bool(StartupLoaderType.in_world_probe_request(probe_args, "headless", "Dummy").accepted),
		"one explicit headless Dummy arm stage is admitted")
	_check(StartupLoaderType.in_world_probe_request(probe_args, "headless", "Dummy").recovery_context == "pilot",
		"omitted recovery context keeps the existing pilot contract")
	for context in ["pilot", "cabin", "rest", "crew"]:
		var selected := probe_args.duplicate()
		selected.append("--in-world-interruption-context=" + context)
		var request := StartupLoaderType.in_world_probe_request(selected, "headless", "Dummy")
		_check(bool(request.accepted) and request.recovery_context == context,
			"the Boot selector admits and preserves exact context %s" % context)
	probe_args[0] = "--in-world-interruption-stage=resume"
	_check(bool(StartupLoaderType.in_world_probe_request(probe_args, "headless", "Dummy").accepted),
		"one explicit headless Dummy resume stage is admitted")
	_check(not bool(StartupLoaderType.in_world_probe_request(probe_args, "x11", "Dummy").accepted),
		"the fixture cannot run on a rendered display")
	for audio_driver in ["", "WASAPI", "PulseAudio"]:
		_check(not bool(StartupLoaderType.in_world_probe_request(probe_args, "headless", audio_driver).accepted),
			"the fixture requires the actual Dummy driver: %s" % audio_driver)
	for unsafe in [
		PackedStringArray(["--in-world-interruption-context=cabin"]),
		PackedStringArray(["--in-world-interruption-context=crew"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-context=crew", "--in-world-interruption-context=crew"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-context=invalid"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-context", "rest"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-context=cabin", "--in-world-interruption-context=rest"]),
		PackedStringArray(["--in-world-interruption-stage=invalid"]),
		PackedStringArray(["--in-world-interruption-stage", "arm"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-stage=resume"]),
	]:
		_check(not bool(StartupLoaderType.in_world_probe_request(unsafe, "headless", "Dummy").accepted),
			"unsafe or ambiguous in-world stage is rejected: %s" % str(unsafe))
	for conflicting in ["--startup-check", "--frame-capture", "--version", "--support-info", "--support-export"]:
		var conflicting_args := probe_args.duplicate()
		conflicting_args.append(conflicting)
		_check(not bool(StartupLoaderType.in_world_probe_request(conflicting_args, "headless", "Dummy").accepted),
			"in-world entry rejects competing exit mode %s" % conflicting)
	_check(StartupLoaderType.cli_mode(PackedStringArray(["--startup-check"])) == &"", "package startup check follows the real boot path")
	var menu := Control.new()
	var button := Button.new()
	button.text = "BEGIN SHIFT"
	menu.add_child(button)
	_check(not StartupLoaderType.is_title_menu_ready(menu), "detached menu cannot pass the package check")
	root.add_child(menu)
	button.disabled = true
	_check(not StartupLoaderType.is_title_menu_ready(menu), "disabled menu cannot pass the package check")
	button.disabled = false
	menu.hide()
	_check(not StartupLoaderType.is_title_menu_ready(menu), "hidden menu cannot pass the package check")
	menu.show()
	_check(StartupLoaderType.is_title_menu_ready(menu), "visible enabled menu passes the package check")
	menu.free()
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
	_check(
		StartupLoaderType.cli_mode(PackedStringArray(["--support-export", "user://diagnostics/exports"])) == &"support_export",
		"support-export selects the early export path"
	)
	_check(
		StartupLoaderType.cli_support_export_path(PackedStringArray(["--support-export", "user://diagnostics/exports"])) == "user://diagnostics/exports",
		"support-export reads one explicit destination argument"
	)
	_check(
		StartupLoaderType.cli_support_export_path(PackedStringArray(["--support-export"])) == "",
		"support-export rejects a missing destination argument"
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
