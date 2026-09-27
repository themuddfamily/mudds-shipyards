extends SceneTree

## The pause footer identifies a stamped release package from its executable
## filename (GameHUD.resolve_build_identity). Linux exports are named
## MuddsShipyards-<short>.x86_64 by tools/release/export_linux_candidate.sh, so
## an intact Linux filename must claim its revision exactly as an intact Windows
## filename does, and near-miss Linux names must stay honestly unstamped.

var _failures: Array[String] = []


func _initialize() -> void:
	_test_linux_stamped_binary()
	_test_windows_behaviour_unchanged()
	_test_linux_near_misses_stay_unstamped()
	_finish()


func _test_linux_stamped_binary() -> void:
	var stamped := GameHUD.resolve_build_identity(
		"/home/pilot/Games/MuddsShipyards-a1b2c3d/MuddsShipyards-A1B2C3D.x86_64",
		"0.12.0",
		false,
	)
	_check(
		stamped.get("mode") == &"stamped_package"
		and stamped.get("revision") == "a1b2c3d"
		and stamped.get("exact_revision") == true
		and stamped.get("executable_name") == "MuddsShipyards-A1B2C3D.x86_64"
		and stamped.get("display_text") == "BUILD A1B2C3D  //  v0.12.0",
		"an intact Linux release filename exposes its exact seven-character revision",
	)


func _test_windows_behaviour_unchanged() -> void:
	var windows := GameHUD.resolve_build_identity(
		"C:\\Builds\\MuddsShipyards-a1B2c3D.exe", "0.12.0", false
	)
	_check(
		windows.get("mode") == &"stamped_package" and windows.get("revision") == "a1b2c3d",
		"the Windows release filename is still stamped",
	)
	var source := GameHUD.resolve_build_identity("/usr/bin/godot", "0.12.0", true)
	_check(source.get("mode") == &"source_run", "a Linux editor binary is still a source run")


func _test_linux_near_misses_stay_unstamped() -> void:
	for path: String in [
		"/opt/mudds/MuddsShipyards.x86_64",
		"/opt/mudds/MuddsShipyards-a1b2c3d.x86_64.bak",
		"/opt/mudds/MuddsShipyards-a1b2c3d.x86_32",
		"/opt/mudds/MuddsShipyards-a1b2c3d",
		"/opt/mudds/MuddsShipyards-a1b2c3dx86_64",
		"/opt/mudds/MuddsShipyards-a1b2c3d-linux-x86_64.tar.gz",
	]:
		var identity := GameHUD.resolve_build_identity(path, "0.12.0", false)
		_check(
			identity.get("mode") == &"unstamped_package"
			and identity.get("revision") == ""
			and identity.get("exact_revision") == false,
			"a non-release Linux name does not claim a revision: %s" % path.get_file(),
		)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("LINUX_BUILD_IDENTITY_TEST_OK")
		quit(0)
	else:
		print("LINUX_BUILD_IDENTITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
