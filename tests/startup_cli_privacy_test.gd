extends SceneTree

const StartupLoaderType := preload("res://scripts/game/startup_loader.gd")

class TitleHUD extends Control:
	var _intro_start_button: Button

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for route: String in ["arrow-return-reuse", "life-tow", "life-gantry", "life-arm", "life-patrol", "beacon-entry", "beacon-settlement"]:
		var life_args := PackedStringArray(["--native-sortie-observer=" + route])
		_check(StartupLoaderType.native_sortie_request(life_args, "X11", "Dummy", true).accepted,
			"%s explicitly admits only the silent private X11 observer" % route)
		for row: Array in [["headless", "Dummy", true], ["wayland", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
			_check(not StartupLoaderType.native_sortie_request(life_args, row[0], row[1], row[2]).accepted,
				"%s requires private X11 and Dummy audio" % route)
		for conflict: String in ["--native-sortie-observer=arrow-return-reuse", "--native-sortie-observer=beacon-settlement", "--native-sortie-observer=beacon-entry", "--native-sortie-observer", "--native-sortie-observer=life-tow", "--native-sortie-observer=life-gantry", "--native-sortie-observer=life-arm", "--native-sortie-observer=life-patrol", "--native-sortie-observer=habitat-restart", "--native-sortie-observer=habitat-loop", "--native-sortie-observer=sandbox-walk", "--native-sortie-observer=sandbox", "--native-sortie-observer=ember", "--native-sortie-observer=hulk-arrival", "--native-sortie-observer=hulk-breaker", "--native-sortie-observer=hulk-home", "--startup-check", "--frame-capture", "--version", "--help", "--support-info", "--support-export", "--reflection-reentry-check", "--in-world-interruption-stage=arm"]:
			var conflicting := life_args.duplicate()
			conflicting.append(conflict)
			_check(not StartupLoaderType.native_sortie_request(conflicting, "X11", "Dummy", true).accepted,
				"%s rejects duplicate or competing mode: %s" % [route, conflict])
		for malformed: String in ["--native-sortie-observer=Arrow-return-reuse", "--native-sortie-observer=arrow-return-reuse-extra", "--native-sortie-observer=arrow-return-reuse=", "--native-sortie-observer arrow-return-reuse", "--native-sortie-observer=Beacon-settlement", "--native-sortie-observer=beacon-settlement-extra", "--native-sortie-observer=beacon-settlement=", "--native-sortie-observer beacon-settlement", "--native-sortie-observer=Beacon-entry", "--native-sortie-observer=beacon-entry-extra", "--native-sortie-observer=beacon-entry=", "--native-sortie-observer beacon-entry", "--native-sortie-observer=Life-patrol", "--native-sortie-observer=life-patrol-extra", "--native-sortie-observer=life-patrol=", "--native-sortie-observer life-patrol","--native-sortie-observer=Life-arm", "--native-sortie-observer=life-arm-extra", "--native-sortie-observer=life-arm=", "--native-sortie-observer life-arm", "--native-sortie-observer=Life-tow", "--native-sortie-observer=Life-gantry", "--native-sortie-observer=life-gantry-extra", "--native-sortie-observer=life-gantry=", "--native-sortie-observer life-gantry", "--native-sortie-observer=life-tow-extra", "--native-sortie-observer=life-tow=", "--native-sortie-observer life-tow"]:
			_check(not StartupLoaderType.native_sortie_request(PackedStringArray([malformed]), "X11", "Dummy", true).accepted,
				"%s rejects malformed observer selector: %s" % [route, malformed])
	var native_args := PackedStringArray(["--native-sortie-observer"])
	_check(not StartupLoaderType.native_sortie_request(PackedStringArray(), "X11", "Dummy", true).requested,
		"ordinary Boot leaves the native sortie observer unloaded")
	_check(StartupLoaderType.native_sortie_request(native_args, "X11", "Dummy", true).accepted,
		"native sortie observation admits the explicit silent private X11 route")
	var sandbox_args := PackedStringArray(["--native-sortie-observer=sandbox-walk"])
	_check(StartupLoaderType.native_sortie_request(sandbox_args, "X11", "Dummy", true).accepted,
		"scoped station walking uses the same explicit private observer admission")
	var hulk_arrival_args := PackedStringArray(["--native-sortie-observer=hulk-arrival"])
	_check(StartupLoaderType.native_sortie_request(hulk_arrival_args, "X11", "Dummy", true).accepted,
		"HULK arrival explicitly admits the same silent private OS-input route")
	for row: Array in [["headless", "Dummy", true], ["wayland", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
		_check(not StartupLoaderType.native_sortie_request(hulk_arrival_args, row[0], row[1], row[2]).accepted,
			"HULK arrival preserves private X11 and Dummy admission")
	for conflict in ["--native-sortie-observer", "--native-sortie-observer=hulk-arrival", "--native-sortie-observer=sandbox", "--startup-check", "--frame-capture", "--version", "--support-info", "--support-export", "--reflection-reentry-check", "--in-world-interruption-stage=arm"]:
		var conflicting := hulk_arrival_args.duplicate()
		conflicting.append(conflict)
		_check(not StartupLoaderType.native_sortie_request(conflicting, "X11", "Dummy", true).accepted,
			"HULK arrival rejects duplicate or competing mode: %s" % conflict)
	var hulk_breaker_args := PackedStringArray(["--native-sortie-observer=hulk-breaker"])
	_check(StartupLoaderType.native_sortie_request(hulk_breaker_args, "X11", "Dummy", true).accepted,
		"HULK breaker explicitly admits the same silent private OS-input route")
	for row: Array in [["headless", "Dummy", true], ["wayland", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
		_check(not StartupLoaderType.native_sortie_request(hulk_breaker_args, row[0], row[1], row[2]).accepted,
			"HULK breaker preserves private X11 and Dummy admission")
	for conflict in ["--native-sortie-observer", "--native-sortie-observer=hulk-arrival", "--native-sortie-observer=hulk-breaker", "--native-sortie-observer=sandbox", "--startup-check", "--frame-capture", "--version", "--support-info", "--support-export", "--reflection-reentry-check", "--in-world-interruption-stage=arm"]:
		var breaker_conflicting: PackedStringArray = hulk_breaker_args.duplicate()
		breaker_conflicting.append(conflict)
		_check(not StartupLoaderType.native_sortie_request(breaker_conflicting, "X11", "Dummy", true).accepted,
			"HULK breaker rejects duplicate or competing mode: %s" % conflict)
	var hulk_home_args := PackedStringArray(["--native-sortie-observer=hulk-home"])
	_check(StartupLoaderType.native_sortie_request(hulk_home_args, "X11", "Dummy", true).accepted,
		"HULK home explicitly admits the same silent private OS-input route")
	for row: Array in [["headless", "Dummy", true], ["wayland", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
		_check(not StartupLoaderType.native_sortie_request(hulk_home_args, row[0], row[1], row[2]).accepted,
			"HULK home preserves private X11 and Dummy admission")
	for conflict in ["--native-sortie-observer", "--native-sortie-observer=hulk-arrival", "--native-sortie-observer=hulk-breaker", "--native-sortie-observer=hulk-home", "--native-sortie-observer=sandbox", "--startup-check", "--frame-capture", "--version", "--support-info", "--support-export", "--reflection-reentry-check", "--in-world-interruption-stage=arm"]:
		var home_conflicting: PackedStringArray = hulk_home_args.duplicate()
		home_conflicting.append(conflict)
		_check(not StartupLoaderType.native_sortie_request(home_conflicting, "X11", "Dummy", true).accepted,
			"HULK home rejects duplicate or competing mode: %s" % conflict)
	var ember_observer_args := PackedStringArray(["--native-sortie-observer=ember"])
	_check(StartupLoaderType.native_sortie_request(ember_observer_args, "X11", "Dummy", true).accepted,
		"Ember observation admits only the same silent private X11 route")
	for row: Array in [["headless", "Dummy", true], ["wayland", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
		_check(not StartupLoaderType.native_sortie_request(ember_observer_args, row[0], row[1], row[2]).accepted,
			"Ember preserves private X11 and Dummy admission")
	for conflict in ["--native-sortie-observer", "--native-sortie-observer=ember", "--native-sortie-observer=sandbox-walk", "--native-sortie-observer=sandbox", "--native-sortie-observer=hulk-arrival", "--native-sortie-observer=hulk-breaker", "--native-sortie-observer=hulk-home", "--startup-check", "--frame-capture", "--version", "--help", "--support-info", "--support-export", "--reflection-reentry-check", "--in-world-interruption-stage=arm"]:
		var ember_conflicting := ember_observer_args.duplicate()
		ember_conflicting.append(conflict)
		_check(not StartupLoaderType.native_sortie_request(ember_conflicting, "X11", "Dummy", true).accepted,
			"Ember rejects duplicate or competing mode: %s" % conflict)
	for malformed in ["--native-sortie-observer=Ember", "--native-sortie-observer=ember-extra", "--native-sortie-observer=ember=", "--native-sortie-observer ember"]:
		_check(not StartupLoaderType.native_sortie_request(PackedStringArray([malformed]), "X11", "Dummy", true).accepted,
			"Ember rejects malformed selector: %s" % malformed)
	var habitat_args := PackedStringArray(["--native-sortie-observer=habitat-loop"])
	_check(StartupLoaderType.native_sortie_request(habitat_args, "X11", "Dummy", true).accepted,
		"Habitat loop admits explicit silent private OS input")
	for row: Array in [["headless", "Dummy", true], ["wayland", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
		_check(not StartupLoaderType.native_sortie_request(habitat_args, row[0], row[1], row[2]).accepted,
			"Habitat loop preserves private X11 and Dummy admission")
	for conflict in ["--native-sortie-observer", "--native-sortie-observer=habitat-loop", "--native-sortie-observer=sandbox", "--native-sortie-observer=ember", "--native-sortie-observer=hulk-home", "--startup-check", "--frame-capture", "--version", "--help", "--support-info", "--support-export", "--reflection-reentry-check", "--in-world-interruption-stage=arm"]:
		var habitat_conflicting := habitat_args.duplicate()
		habitat_conflicting.append(conflict)
		_check(not StartupLoaderType.native_sortie_request(habitat_conflicting, "X11", "Dummy", true).accepted,
			"Habitat loop rejects duplicate or competing mode: %s" % conflict)
	for malformed in ["--native-sortie-observer=Habitat-loop", "--native-sortie-observer=habitat-loop-extra", "--native-sortie-observer=habitat-loop=", "--native-sortie-observer habitat-loop"]:
		_check(not StartupLoaderType.native_sortie_request(PackedStringArray([malformed]), "X11", "Dummy", true).accepted,
			"Habitat loop rejects malformed selector: %s" % malformed)
	var restart_args := PackedStringArray(["--native-sortie-observer=habitat-restart"])
	_check(StartupLoaderType.native_sortie_request(restart_args, "X11", "Dummy", true).accepted,
		"Habitat restart admits explicit silent private OS input")
	for row: Array in [["headless", "Dummy", true], ["wayland", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
		_check(not StartupLoaderType.native_sortie_request(restart_args, row[0], row[1], row[2]).accepted,
			"Habitat restart preserves private X11 and Dummy admission")
	for conflict: String in ["--native-sortie-observer", "--native-sortie-observer=habitat-restart", "--native-sortie-observer=habitat-loop", "--native-sortie-observer=sandbox", "--native-sortie-observer=ember", "--native-sortie-observer=hulk-home", "--startup-check", "--frame-capture", "--version", "--help", "--support-info", "--support-export", "--reflection-reentry-check", "--in-world-interruption-stage=arm"]:
		var restart_conflicting: PackedStringArray = restart_args.duplicate()
		restart_conflicting.append(conflict)
		_check(not StartupLoaderType.native_sortie_request(restart_conflicting, "X11", "Dummy", true).accepted,
			"Habitat restart rejects duplicate or competing mode: %s" % conflict)
	for malformed: String in ["--native-sortie-observer=Habitat-restart", "--native-sortie-observer=habitat-restart-extra", "--native-sortie-observer=habitat-restart=", "--native-sortie-observer habitat-restart"]:
		_check(not StartupLoaderType.native_sortie_request(PackedStringArray([malformed]), "X11", "Dummy", true).accepted,
			"Habitat restart rejects malformed selector: %s" % malformed)
	var supply_args := PackedStringArray(["--native-sortie-observer=cinder-supply"])
	_check(StartupLoaderType.native_sortie_request(supply_args, "X11", "Dummy", true).accepted,
		"Cinder supply observation admits the owned silent ordinary OS-input route")
	for row: Array in [["headless", "Dummy", true], ["wayland", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
		_check(not StartupLoaderType.native_sortie_request(supply_args, row[0], row[1], row[2]).accepted,
			"Cinder supply preserves display, audio and private input admission")
	for conflict: String in ["--native-sortie-observer=cinder-supply", "--native-sortie-observer", "--startup-check", "--support-info"]:
		var supply_conflicting: PackedStringArray = supply_args.duplicate()
		supply_conflicting.append(conflict)
		_check(not StartupLoaderType.native_sortie_request(supply_conflicting, "X11", "Dummy", true).accepted,
			"Cinder supply rejects duplicate or competing startup selectors")
	var fleet_args := PackedStringArray(["--native-sortie-observer=sandbox"])
	_check(StartupLoaderType.native_sortie_request(fleet_args, "X11", "Dummy", true).accepted,
		"full Sandbox observation admits only the same silent private input route")
	for row: Array in [["headless", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
		_check(not StartupLoaderType.native_sortie_request(fleet_args, row[0], row[1], row[2]).accepted,
			"full Sandbox preserves private display and silent audio admission")
	_check(not StartupLoaderType.native_sortie_request(sandbox_args, "X11", "Dummy", false).accepted,
		"station walking cannot enable telemetry on an unowned display")
	_check(not StartupLoaderType.native_sortie_request(PackedStringArray([
		"--native-sortie-observer", "--native-sortie-observer=sandbox-walk"]), "X11", "Dummy", true).accepted,
		"two observer routes cannot compete")
	for row: Array in [["headless", "Dummy", true], ["wayland", "Dummy", true], ["X11", "PulseAudio", true], ["X11", "Dummy", false]]:
		_check(not StartupLoaderType.native_sortie_request(native_args, row[0], row[1], row[2]).accepted,
			"native observer rejects unsupported display/audio/ownership")
	for conflict in ["--native-sortie-observer", "--startup-check", "--frame-capture", "--version", "--support-info", "--support-export", "--reflection-reentry-check", "--in-world-interruption-stage=arm"]:
		var conflicting := native_args.duplicate()
		conflicting.append(conflict)
		_check(not StartupLoaderType.native_sortie_request(conflicting, "X11", "Dummy", true).accepted,
			"native observer rejects duplicate or competing mode: %s" % conflict)
	_check(not StartupLoaderType.native_sortie_request(PackedStringArray(["--native-sortie-observer=wrong"]), "X11", "Dummy", true).accepted,
		"native observer rejects malformed selector")
	for script_path in [
		"res://scripts/diagnostics/native_sortie_observer.gd",
		"res://scripts/game/game_flow.gd",
		"res://scripts/world/shipyard_world.gd",
		"res://scripts/ships/hero_ship.gd",
	]:
		_check(not ResourceLoader.has_cached(script_path),
			"early Boot and CLI compilation leaves %s for the Main worker" % script_path.get_file())
	var reflection_args := PackedStringArray(["--reflection-reentry-check"])
	_check(not StartupLoaderType.reflection_reentry_probe_request(PackedStringArray(), "X11", "Dummy", "forward_plus", true, 4096).requested,
		"ordinary Boot does not opt into the packaged reflection lifecycle check")
	_check(StartupLoaderType.reflection_reentry_probe_request(reflection_args, "X11", "Dummy", "forward_plus", true, 4096).accepted,
		"packaged reflection lifecycle admits exact isolated rendered diagnostic inputs")
	for row: Array in [["headless", "Dummy", "forward_plus", true, 4096], ["X11", "PulseAudio", "forward_plus", true, 4096],
		["X11", "Dummy", "gl_compatibility", true, 4096], ["X11", "Dummy", "forward_plus", false, 4096], ["X11", "Dummy", "forward_plus", true, 256]]:
		_check(not StartupLoaderType.reflection_reentry_probe_request(reflection_args, row[0], row[1], row[2], row[3], row[4]).accepted,
			"reflection lifecycle refuses unsupported renderer/audio/profile/capacity input")
	for conflict in ["--reflection-reentry-check", "--startup-check", "--frame-capture", "--version", "--support-info", "--support-export", "--in-world-interruption-stage=arm"]:
		var conflicting := reflection_args.duplicate()
		conflicting.append(conflict)
		_check(not StartupLoaderType.reflection_reentry_probe_request(conflicting, "X11", "Dummy", "forward_plus", true, 4096).accepted,
			"reflection lifecycle refuses duplicate or competing modes: %s" % conflict)
	var probe_args := PackedStringArray(["--in-world-interruption-stage=arm"])
	_check(not bool(StartupLoaderType.in_world_probe_request(PackedStringArray(), "headless", "Dummy").requested),
		"ordinary boot does not opt into the in-world fixture")
	_check(bool(StartupLoaderType.in_world_probe_request(probe_args, "headless", "Dummy").accepted),
		"one explicit headless Dummy arm stage is admitted")
	_check(StartupLoaderType.in_world_probe_request(probe_args, "headless", "Dummy").recovery_context == "pilot",
		"omitted recovery context keeps the existing pilot contract")
	_check(StartupLoaderType.in_world_probe_request(probe_args, "headless", "Dummy").activity == "convoy",
		"omitted activity keeps the existing convoy contract")
	var beacon_args := probe_args.duplicate()
	beacon_args.append("--in-world-interruption-activity=beacon")
	_check(StartupLoaderType.in_world_probe_request(beacon_args, "headless", "Dummy").accepted,
		"the beacon interruption selector admits the supported pilot context")
	for context in ["cabin", "rest", "crew", "engineer", "on_foot", "docking"]:
		var unsupported := beacon_args.duplicate()
		unsupported.append("--in-world-interruption-context=" + context)
		_check(not StartupLoaderType.in_world_probe_request(unsupported, "headless", "Dummy").accepted,
			"beacon refuses unsupported context before Main loading: %s" % context)
	var scan_args := PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=scan"])
	_check(StartupLoaderType.in_world_probe_request(scan_args, "headless", "Dummy").accepted,
		"scan interruption admits its supported pilot recovery")
	for context in ["cabin", "rest", "crew", "engineer", "on_foot", "docking"]:
		var unsupported := scan_args.duplicate()
		unsupported.append("--in-world-interruption-context=" + context)
		_check(not StartupLoaderType.in_world_probe_request(unsupported, "headless", "Dummy").accepted,
			"scan refuses unsupported context before Main loading: %s" % context)
	_check(not StartupLoaderType.in_world_probe_request(scan_args, "x11", "Dummy").accepted
		and not StartupLoaderType.in_world_probe_request(scan_args, "headless", "PulseAudio").accepted,
		"scan refuses active display or audible driver before Main loading")
	var mining_args := PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=mining"])
	_check(StartupLoaderType.in_world_probe_request(mining_args, "headless", "Dummy").accepted,
		"the mining interruption selector admits the supported pilot context")
	for context in ["cabin", "rest", "crew", "engineer", "on_foot", "docking"]:
		var unsupported := mining_args.duplicate()
		unsupported.append("--in-world-interruption-context=" + context)
		_check(not StartupLoaderType.in_world_probe_request(unsupported, "headless", "Dummy").accepted,
			"mining refuses unsupported context before Main loading: %s" % context)
	_check(not StartupLoaderType.in_world_probe_request(mining_args, "x11", "Dummy").accepted
		and not StartupLoaderType.in_world_probe_request(mining_args, "headless", "PulseAudio").accepted,
		"mining refuses an active display or audible driver before Main loading")
	var hulk_args := PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=hulk"])
	_check(StartupLoaderType.in_world_probe_request(hulk_args, "headless", "Dummy").accepted,
		"hulk interruption admits its supported pilot recovery")
	for context in ["cabin", "rest", "crew", "engineer", "on_foot", "docking"]:
		var unsupported := hulk_args.duplicate()
		unsupported.append("--in-world-interruption-context=" + context)
		_check(not StartupLoaderType.in_world_probe_request(unsupported, "headless", "Dummy").accepted,
			"hulk refuses unsupported context before Main loading: %s" % context)
	_check(not StartupLoaderType.in_world_probe_request(hulk_args, "x11", "Dummy").accepted
		and not StartupLoaderType.in_world_probe_request(hulk_args, "headless", "PulseAudio").accepted,
		"hulk refuses active display and audible driver before Main loading")
	for breach_stage in ["arm", "resume"]:
		var breach_args := PackedStringArray(["--in-world-interruption-stage=" + breach_stage, "--in-world-interruption-activity=breach"])
		_check(StartupLoaderType.in_world_probe_request(breach_args, "headless", "Dummy").accepted,
			"Heavy Breach admits its explicit silent terminal recovery stage: %s" % breach_stage)
		for context in ["cabin", "rest", "crew", "engineer", "on_foot", "docking"]:
			var unsupported := breach_args.duplicate()
			unsupported.append("--in-world-interruption-context=" + context)
			_check(not StartupLoaderType.in_world_probe_request(unsupported, "headless", "Dummy").accepted,
				"Heavy Breach refuses unsupported recovery context: %s" % context)
		_check(not StartupLoaderType.in_world_probe_request(breach_args, "X11", "Dummy").accepted
			and not StartupLoaderType.in_world_probe_request(breach_args, "headless", "PulseAudio").accepted
			and not StartupLoaderType.in_world_probe_request(breach_args, "headless", "Dummy", true).accepted,
			"Heavy Breach preserves silent headless admission and rejects private engineer widening")
	var ember_args := PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=ember"])
	_check(StartupLoaderType.in_world_probe_request(ember_args, "headless", "Dummy").accepted,
		"ember interruption admits its supported pilot recovery")
	for context in ["cabin", "rest", "crew", "engineer", "on_foot", "docking"]:
		var unsupported := ember_args.duplicate()
		unsupported.append("--in-world-interruption-context=" + context)
		_check(not StartupLoaderType.in_world_probe_request(unsupported, "headless", "Dummy").accepted,
			"ember refuses unsupported context before Main loading: %s" % context)
	_check(not StartupLoaderType.in_world_probe_request(ember_args, "x11", "Dummy").accepted
		and not StartupLoaderType.in_world_probe_request(ember_args, "headless", "PulseAudio").accepted,
		"ember refuses active display and audible driver before Main loading")
	for malformed in [
		PackedStringArray(["--in-world-interruption-activity=ember"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=ember", "--in-world-interruption-activity=ember"]),
	]:
		_check(not StartupLoaderType.in_world_probe_request(malformed, "headless", "Dummy").accepted,
			"Ember refuses a missing stage or duplicate selector before Main loading")
	var defense_args := PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=stationdefense"])
	_check(StartupLoaderType.in_world_probe_request(defense_args, "headless", "Dummy").accepted,
		"station-defense interruption admits only its supported pilot recovery")
	for context in ["cabin", "rest", "crew", "engineer", "on_foot", "docking"]:
		var unsupported := defense_args.duplicate()
		unsupported.append("--in-world-interruption-context=" + context)
		_check(not StartupLoaderType.in_world_probe_request(unsupported, "headless", "Dummy").accepted,
			"station defense refuses unsupported context before Main loading: %s" % context)
	_check(not StartupLoaderType.in_world_probe_request(defense_args, "x11", "Dummy").accepted
		and not StartupLoaderType.in_world_probe_request(defense_args, "headless", "PulseAudio").accepted,
		"station defense refuses active display and audible input before Main loading")
	for context in ["pilot", "cabin", "rest", "crew", "on_foot"]:
		var selected := probe_args.duplicate()
		selected.append("--in-world-interruption-context=" + context)
		var request := StartupLoaderType.in_world_probe_request(selected, "headless", "Dummy")
		_check(bool(request.accepted) and request.recovery_context == context,
			"the Boot selector admits and preserves exact context %s" % context)
	for stage in ["arm", "resume"]:
		var foot_args := PackedStringArray(["--in-world-interruption-stage=" + stage,
			"--in-world-interruption-context=on_foot", "--in-world-interruption-activity=convoy"])
		_check(StartupLoaderType.in_world_probe_request(foot_args, "headless", "Dummy").accepted,
			"settled exterior convoy admits the explicit silent %s stage" % stage)
		for unsafe_display in ["X11", "wayland"]:
			_check(not StartupLoaderType.in_world_probe_request(foot_args, unsafe_display, "Dummy").accepted,
				"on-foot recovery stays isolated from rendered displays")
		_check(not StartupLoaderType.in_world_probe_request(foot_args, "headless", "PulseAudio").accepted
			and not StartupLoaderType.in_world_probe_request(foot_args, "headless", "Dummy", true).accepted,
			"on-foot recovery requires actual Dummy and cannot inherit engineer input admission")
	for stage in ["arm", "resume"]:
		var docking_args := PackedStringArray(["--in-world-interruption-stage=" + stage,
			"--in-world-interruption-context=docking", "--in-world-interruption-activity=convoy"])
		var request := StartupLoaderType.in_world_probe_request(docking_args, "headless", "Dummy")
		_check(request.accepted and request.recovery_context == "docking" and request.activity == "convoy",
			"actual docking convoy admits only the explicit silent %s stage" % stage)
		for unsafe_display in ["X11", "wayland"]:
			_check(not StartupLoaderType.in_world_probe_request(docking_args, unsafe_display, "Dummy").accepted,
				"docking interruption remains isolated from rendered displays")
		for unsafe_audio in ["", "PulseAudio", "WASAPI"]:
			_check(not StartupLoaderType.in_world_probe_request(docking_args, "headless", unsafe_audio).accepted,
				"docking interruption requires the actual Dummy driver")
		_check(not StartupLoaderType.in_world_probe_request(docking_args, "headless", "Dummy", true).accepted,
			"docking cannot inherit private engineer input admission")
		for conflict in ["--startup-check", "--frame-capture", "--version", "--support-info", "--support-export"]:
			var conflicting := docking_args.duplicate()
			conflicting.append(conflict)
			_check(not StartupLoaderType.in_world_probe_request(conflicting, "headless", "Dummy").accepted,
				"docking refuses competing exit modes before Main loading")
	var engineer_args := PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-context=engineer"])
	_check(StartupLoaderType.in_world_probe_request(engineer_args, "X11", "Dummy", true).accepted,
		"engineer admits only the explicitly owned private X11 Dummy input path")
	for display in ["headless", "wayland", ""]:
		_check(not StartupLoaderType.in_world_probe_request(engineer_args, display, "Dummy", true).accepted,
			"engineer refuses unsupported private display %s" % display)
	_check(not StartupLoaderType.in_world_probe_request(engineer_args, "X11", "Dummy").accepted
		and not StartupLoaderType.in_world_probe_request(engineer_args, "X11", "PulseAudio", true).accepted,
		"engineer refuses unowned X11 and audible input")
	_check(not StartupLoaderType.in_world_probe_request(probe_args, "headless", "Dummy", true).accepted,
		"private engineer input marker cannot broaden other contexts")
	for other_activity in ["beacon", "mining", "stationdefense", "scan", "hulk", "ember", "breach"]:
		var incompatible := engineer_args.duplicate()
		incompatible.append("--in-world-interruption-activity=" + other_activity)
		_check(not StartupLoaderType.in_world_probe_request(incompatible, "X11", "Dummy", true).accepted,
			"private engineer input cannot broaden activity %s" % other_activity)
	probe_args[0] = "--in-world-interruption-stage=resume"
	_check(bool(StartupLoaderType.in_world_probe_request(probe_args, "headless", "Dummy").accepted),
		"one explicit headless Dummy resume stage is admitted")
	_check(not bool(StartupLoaderType.in_world_probe_request(probe_args, "x11", "Dummy").accepted),
		"the fixture cannot run on a rendered display")
	for audio_driver in ["", "WASAPI", "PulseAudio"]:
		_check(not bool(StartupLoaderType.in_world_probe_request(probe_args, "headless", audio_driver).accepted),
			"the fixture requires the actual Dummy driver: %s" % audio_driver)
	for unsafe in [
		PackedStringArray(["--in-world-interruption-activity=breach"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity", "breach"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=breach", "--in-world-interruption-activity=breach"]),
		PackedStringArray(["--in-world-interruption-activity=hulk"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity", "hulk"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=hulk", "--in-world-interruption-activity=hulk"]),
		PackedStringArray(["--in-world-interruption-activity=scan"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity", "scan"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=scan", "--in-world-interruption-activity=scan"]),
		PackedStringArray(["--in-world-interruption-activity=stationdefense"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity", "stationdefense"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=stationdefense", "--in-world-interruption-activity=stationdefense"]),
		PackedStringArray(["--in-world-interruption-activity=mining"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity", "mining"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=mining", "--in-world-interruption-activity=mining"]),
		PackedStringArray(["--in-world-interruption-activity=beacon"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=unknown"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity", "beacon"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-activity=beacon", "--in-world-interruption-activity=beacon"]),
		PackedStringArray(["--in-world-interruption-context=docking"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-context", "docking"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-context=docking", "--in-world-interruption-context=docking"]),
		PackedStringArray(["--in-world-interruption-context=on_foot"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-context=on_foot", "--in-world-interruption-context=on_foot"]),
		PackedStringArray(["--in-world-interruption-context=cabin"]),
		PackedStringArray(["--in-world-interruption-context=crew"]),
		PackedStringArray(["--in-world-interruption-context=engineer"]),
		PackedStringArray(["--in-world-interruption-stage=arm", "--in-world-interruption-context=engineer", "--in-world-interruption-context=engineer"]),
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
	var main := Control.new()
	var hud := TitleHUD.new()
	hud.name = "HUD"
	main.add_child(hud)
	root.add_child(main)
	var start := Button.new()
	start.text = "BEGIN SHIFT   [ E ]"
	hud.add_child(start)
	hud._intro_start_button = start
	var decoy := Button.new()
	decoy.text = "BEGIN SHIFT"
	main.add_child(decoy)
	_check(StartupLoaderType.is_title_menu_ready(main), "production HUD uses its actual live Begin Shift button")
	start.disabled = true
	_check(not StartupLoaderType.is_title_menu_ready(main), "visible decoy cannot override disabled actual Begin Shift")
	start.disabled = false
	hud.hide()
	_check(not StartupLoaderType.is_title_menu_ready(main), "hidden production HUD cannot pass readiness")
	hud.show()
	start.text = "OTHER ACTION"
	_check(not StartupLoaderType.is_title_menu_ready(main), "retained control must still be the Begin Shift action")
	start.text = "BEGIN SHIFT   [ R ]"
	hud.remove_child(start)
	_check(not StartupLoaderType.is_title_menu_ready(main), "detached retained Begin Shift cannot pass readiness")
	main.add_child(start)
	_check(not StartupLoaderType.is_title_menu_ready(main), "reparented retained button cannot impersonate the HUD action")
	main.remove_child(start)
	hud.add_child(start)
	_check(StartupLoaderType.is_title_menu_ready(main), "remapped reattached actual Begin Shift is checked afresh")
	start.free()
	_check(not StartupLoaderType.is_title_menu_ready(main), "freed production button cannot fall back to a visible decoy")
	main.free()
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
