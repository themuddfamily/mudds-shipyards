extends Node
## Passive physical guest for the existing independent-Main browser route.
## No device/display is selected implicitly. Only an operator-authorized dedicated
## X11 session may be supplied; the coordinator itself must remain headless.
## Source/config checks do not constitute a physical-controller qualification.

# Executed before either peer is spawned, and again by the guest. No X connection
# or input device is opened by this preflight. Tests execute this exact function.
const PREFLIGHT := r"""
import hashlib, json, os, pathlib, re, socket, stat, struct, subprocess, sys

def check(c, project, executable, guest_pid=0):
    required = {'display', 'xauthority', 'display_pid', 'display_start_ticks',
                'device_node', 'device_sysfs', 'device_guid', 'device_name',
                'vendor_id', 'product_id', 'backend', 'source_commit', 'executable_sha256'}
    if not isinstance(c, dict) or required - c.keys():
        raise ValueError('missing physical session/device/candidate binding')
    match = re.fullmatch(r'127\.0\.0\.1:([1-9][0-9]{0,4})(?:\.0)?', str(c['display']))
    if not match or int(match[1]) > 59535:
        raise ValueError('dedicated DISPLAY must be explicit loopback TCP X11')
    if c['display'] == os.environ.get('DISPLAY') and not guest_pid:
        raise ValueError('coordinator must not use the guest display')
    if c['backend'] != 'SDL3/linux-evdev':
        raise ValueError('only explicitly bound SDL3/linux-evdev is supported')
    if not re.fullmatch(r'[0-9a-f]{32}', str(c['device_guid'])) or not str(c['device_name']).strip():
        raise ValueError('controller GUID/name must be explicitly bound')
    if any(type(c[k]) is not int or not 0 < c[k] <= 65535 for k in ('vendor_id', 'product_id')):
        raise ValueError('invalid controller vendor/product')
    auth = pathlib.Path(c['xauthority'])
    if not auth.is_absolute() or auth.is_symlink() or not auth.is_file():
        raise ValueError('XAUTHORITY must be an absolute private regular file')
    info = auth.stat()
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600 or stat.S_IMODE(auth.parent.stat().st_mode) != 0o700:
        raise ValueError('XAUTHORITY requires own 0600 file in 0700 directory')
    data, offset, authenticated = auth.read_bytes(), 0, False
    try:
        while offset < len(data):
            family = struct.unpack_from('>H', data, offset)[0]
            offset += 2
            fields = []
            for _ in range(4):
                length = struct.unpack_from('>H', data, offset)[0]
                offset += 2
                if offset + length > len(data):
                    raise ValueError('truncated authority')
                fields.append(data[offset:offset + length])
                offset += length
            address = (family == 0 and fields[0] == b'\x7f\x00\x00\x01') or (family == 256 and fields[0] == socket.gethostname().encode())
            authenticated |= address and fields[1:3] == [str(int(match[1])).encode(), b'MIT-MAGIC-COOKIE-1'] and len(fields[3]) == 16
    except struct.error as error:
        raise ValueError('malformed XAUTHORITY') from error
    if not authenticated:
        raise ValueError('XAUTHORITY has no matching display cookie')
    pid = c['display_pid']
    if type(pid) is not int or pid <= 1 or not str(c['display_start_ticks']).isdigit():
        raise ValueError('invalid dedicated display process identity')
    proc = pathlib.Path('/proc') / str(pid)
    fields = (proc / 'stat').read_text().rsplit(')', 1)[1].split()
    command = (proc / 'cmdline').read_bytes().split(b'\0')
    if fields[19] != str(c['display_start_ticks']) or not any(a.decode(errors='replace') in (':' + match[1], ':' + match[1] + '.0') for a in command):
        raise ValueError('dedicated display process identity mismatch')
    if pathlib.Path(os.readlink(proc / 'exe')).name not in ('Xorg', 'Xvnc', 'Xtigervnc'):
        raise ValueError('display must be a dedicated X server, not the active desktop bridge')
    node = pathlib.Path(c['device_node'])
    sysfs = pathlib.Path(c['device_sysfs'])
    if not re.fullmatch(r'/dev/input/event[0-9]+', str(node)) or not stat.S_ISCHR(node.stat().st_mode):
        raise ValueError('device_node must name the actual Linux event device')
    actual_sysfs = (pathlib.Path('/sys/class/input') / node.name / 'device').resolve(strict=True)
    if not sysfs.is_absolute() or sysfs.resolve(strict=True) != actual_sysfs or '/devices/virtual/' in str(actual_sysfs):
        raise ValueError('physical event-device sysfs identity mismatch')
    for key, filename in [('vendor_id', 'vendor'), ('product_id', 'product')]:
        if int((actual_sysfs / 'id' / filename).read_text().strip(), 16) != c[key]:
            raise ValueError('event-device vendor/product mismatch')
    if (actual_sysfs / 'name').read_text().strip() != c['device_name']:
        raise ValueError('event-device name mismatch')
    if not re.fullmatch(r'[0-9a-f]{64}', str(c['executable_sha256'])) or hashlib.sha256(pathlib.Path(executable).read_bytes()).hexdigest() != c['executable_sha256']:
        raise ValueError('candidate executable SHA-256 mismatch')
    if not re.fullmatch(r'[0-9a-f]{40}', str(c['source_commit'])):
        raise ValueError('candidate source commit must be exact')
    head = subprocess.check_output(['git', '-C', project, 'rev-parse', 'HEAD'], text=True).strip()
    dirty = subprocess.check_output(['git', '-C', project, 'status', '--porcelain', '--untracked-files=normal'], text=True).strip()
    if head != c['source_commit'] or dirty:
        raise ValueError('candidate source must be the bound clean commit')
    if guest_pid:
        if os.environ.get('DISPLAY') != c['display'] or os.environ.get('XAUTHORITY') != c['xauthority']:
            raise ValueError('guest X11 environment mismatch')
        if os.environ.get('SDL_JOYSTICK_HIDAPI') != '0':
            raise ValueError('guest must use Linux event backend')
        # GUID alone cannot identify an event source. SDL must actually hold this
        # physical event node; exactly one connected Godot pad is checked below.
        descriptors = pathlib.Path('/proc') / str(guest_pid) / 'fd'
        targets = []
        for fd in descriptors.iterdir():
            try:
                targets.append(os.readlink(fd))
            except FileNotFoundError:
                pass
        if str(node) not in targets:
            raise ValueError('selected SDL guest has no open bound event device')
    return c

if __name__ == '__main__':
    try:
        c = check(json.loads(pathlib.Path(sys.argv[1]).read_text()), sys.argv[2], sys.argv[3], int(sys.argv[4]))
        print(json.dumps(c, sort_keys=True))
    except (ValueError, OSError, TypeError, KeyError, subprocess.SubprocessError) as error:
        print('PHYSICAL_BROWSER_CONFIG_REJECTED: ' + str(error), file=sys.stderr)
        sys.exit(2)
"""

var caller: SceneTree
var binding: Dictionary = {}
var device := -1
var fault := ""
var events: Array[Dictionary] = []
var _expected: StringName = &""
var _pressed := false
var _released := false
var _walking := false
var _walk_action: StringName = &""
var _prompt: Label
var _layer: CanvasLayer


static func preflight(path: String, project: String, executable: String, guest_pid: int = 0) -> Dictionary:
	var output: Array = []
	var code := OS.execute("/usr/bin/python3", PackedStringArray(["-c", PREFLIGHT, path, project, executable, str(guest_pid)]), output, true)
	if code != 0:
		return {"error": str(output)}
	var parsed: Variant = JSON.parse_string(str(output[0]) if not output.is_empty() else "")
	return parsed if parsed is Dictionary else {"error": "invalid preflight response"}


func start(tree: SceneTree, config: Dictionary, config_path: String) -> bool:
	caller = tree
	binding = config
	var pads := Input.get_connected_joypads()
	if pads.size() != 1:
		return fail("physical guest requires exactly one connected controller")
	device = int(pads[0])
	if DisplayServer.get_name().to_lower() != "x11" or RenderingServer.get_current_rendering_driver_name() != "opengl3" or "--disable-render-loop" in OS.get_cmdline_args() or AudioServer.get_driver_name() != "Dummy":
		return fail("physical guest requires normal X11/OpenGL rendering and silent audio")
	if not identity_matches():
		return fail("actual selected controller GUID/name/backend/mapping does not match binding")
	var checked := preflight(config_path, ProjectSettings.globalize_path("res://"), OS.get_executable_path(), OS.get_process_id())
	if checked.has("error") or checked != binding:
		return fail("physical guest configuration changed or failed: " + str(checked.get("error", "binding mismatch")))
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_prompt = Label.new()
	_prompt.position = Vector2(16, 8)
	_prompt.add_theme_color_override("font_color", Color.YELLOW)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.focus_mode = Control.FOCUS_NONE
	_layer.add_child(_prompt)
	add_child(_layer)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	return true


func identity_matches() -> bool:
	if device not in Input.get_connected_joypads() or Input.get_connected_joypads().size() != 1:
		return false
	var info := Input.get_joy_info(device)
	return Input.get_joy_guid(device) == str(binding.device_guid) and str(info.get("raw_name", "")) == str(binding.device_name) and int(info.get("vendor_id", -1)) == int(binding.vendor_id) and int(info.get("product_id", -1)) == int(binding.product_id) and bool(info.get("mapping_handled", false)) and not info.has("steam_input_index")


func _process(_delta: float) -> void:
	if caller != null and fault.is_empty() and not identity_matches():
		fail("physical controller identity or connection changed during the route")


func _input(event: InputEvent) -> void:
	if caller == null or not fault.is_empty():
		return
	if event is InputEventAction or (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		fail("guest received synthetic action/keyboard/pointer input")
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event.device != device or not identity_matches():
		fail("guest input came from a different or changed controller")
		return
	if event is InputEventJoypadMotion:
		if event.axis_value != 0.0 and absf(event.axis_value) > 0.18 and (not _walking or event.axis != JOY_AXIS_LEFT_Y):
			fail("unexpected controller axis outside the selected walk")
		return
	if _expected.is_empty():
		if event.pressed:
			fail("unexpected controller button outside the requested step")
		return
	if not event.is_action(_expected):
		if event.pressed:
			fail("unexpected physical menu action; no route retry")
		return
	var focus := caller.root.gui_get_focus_owner()
	events.append({"action": str(_expected), "pressed": event.pressed, "button": event.button_index, "device": event.device, "guid": Input.get_joy_guid(device), "focus": str(focus.name) if focus != null else "", "frame": Engine.get_process_frames()})
	if event.pressed:
		if _pressed:
			fail("menu action requires one distinct physical press/release")
		_pressed = true
	elif _pressed:
		_released = true


func fail(reason: String) -> bool:
	if fault.is_empty():
		fault = reason
		if caller != null:
			caller.call("_check", false, reason)
	return false


func prompt(text: String) -> void:
	if _prompt != null:
		_prompt.text = "PHYSICAL BROWSER // " + text
	print("PHYSICAL_BROWSER_ACTION: ", text)


func _healthy() -> bool:
	return fault.is_empty() and identity_matches() and caller.root.has_focus()


func focus(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and caller.root.gui_get_focus_owner() == control


func button(name: String) -> Button:
	return caller.get("_live_game").hud.find_child(name, true, false) as Button


func tap(action: StringName, target: Control, label: String, expected_focus: Control = null) -> bool:
	if not await caller.call("_live_boundary", func(): return _healthy() and (action == &"pause" or focus(target)), 5.0, "physical current focus: " + label):
		return false
	_pressed = false
	_released = false
	_expected = action
	var activated := [action != &"ui_accept"]
	var callback := func(): activated[0] = true
	if action == &"ui_accept":
		if not target is Button or (target as Button).disabled:
			return fail("physical accept target is not enabled")
		(target as Button).pressed.connect(callback, CONNECT_ONE_SHOT)
	prompt(label + " (press and release; 5s)")
	var reached: bool = await caller.call("_live_boundary", func(): return not fault.is_empty() or (_healthy() and _pressed and _released and bool(activated[0]) and (expected_focus == null or focus(expected_focus))), 5.0, "physical press/release and actual focus/callback: " + label)
	_expected = &""
	if is_instance_valid(target) and target is Button and (target as Button).pressed.is_connected(callback):
		(target as Button).pressed.disconnect(callback)
	return reached and fault.is_empty()


func move(action: StringName, destination: Control, label: String) -> bool:
	return await tap(action, caller.root.gui_get_focus_owner(), label, destination)


func accept(name: String, destination: Control = null) -> bool:
	return await tap(&"ui_accept", button(name), "Accept " + name, destination)


func run() -> void:
	if not await caller.call("_live_wait_file", "host.ready", 20.0):
		return
	if not await move(&"ui_down", button("IntroServerBrowserButton"), "Down to Server Browser") or not await accept("IntroServerBrowserButton", button("ServerBrowserRefreshButton")):
		return
	if not await accept("ServerBrowserRefreshButton"):
		return
	var hosted: Dictionary = caller.call("_live_read", "host.ready")
	var session_id := StringName(str(hosted.get("session_id", "")))
	if not await caller.call("_live_boundary", func(): return caller.call("_live_row", session_id) != null, 10.0, "physical Refresh discovers actual host row"):
		return
	var game: GameFlow = caller.get("_live_game")
	var row := caller.call("_live_row", session_id) as Button
	var eligible := 0
	for child in (game.hud.get("_server_browser_rows") as VBoxContainer).get_children():
		if child is Button and child.is_visible_in_tree() and not child.disabled:
			eligible += 1
	var endpoint: Dictionary = game.get_lan_discovery().get_endpoint(session_id)
	if eligible != 1 or row.disabled or session_id.is_empty() or int(endpoint.get("port", 0)) != int(hosted.get("port", -1)) or str(endpoint.get("address", "")).is_empty():
		fail("physical discovery must identify exactly the advertised owned non-full host endpoint")
		return
	caller.call("_live_write", "guest.discovered", {"session_id": str(session_id), "endpoint": endpoint})
	if not await move(&"ui_up", row, "Up to owned host " + str(session_id)) or not await tap(&"ui_accept", row, "Accept actual discovered host"):
		return
	if not await caller.call("_live_boundary", Callable(caller, "_live_authenticated"), 20.0, "physical discovered-row join authenticates guest"):
		return
	var session := game.network_session
	var peer: Dictionary = (session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {})
	var guest_id := session.multiplayer.get_unique_id()
	var native := session.get("_peer") as ENetMultiplayerPeer
	caller.call("_live_write", "guest.admitted", {"pid": OS.get_process_id(), "peer_id": guest_id, "peer_generation": int(peer.get("peer_generation", 0)), "player": caller.call("_live_player_identity")})
	if not await move(&"ui_down", button("ServerBrowserRefreshButton"), "Down to Refresh"):
		return
	for name in ["ServerBrowserHostButton", "ServerBrowserManualJoinButton", "ServerBrowserDisconnectButton", "ServerBrowserBackButton"]:
		if not await move(&"ui_right", button(name), "Right to " + name):
			return
	if not await accept("ServerBrowserBackButton", button("IntroServerBrowserButton")) or not await move(&"ui_up", button("IntroBeginShiftButton"), "Up to Begin Shift") or not await accept("IntroBeginShiftButton"):
		return
	if not await caller.call("_live_boundary", func(): return game.phase != GameFlow.Phase.INTRO, 5.0, "physical Begin Shift exposes playable Main"):
		return
	var dismiss := button("RuntimeStatusDismissButton")
	if dismiss != null and dismiss.is_visible_in_tree() and not dismiss.disabled:
		if not focus(button("RuntimeStatusNextButton")) or not await move(&"ui_right", button("RuntimeStatusRepeatButton"), "Right to Repeat") or not await move(&"ui_right", dismiss, "Right to Dismiss") or not await accept("RuntimeStatusDismissButton"):
			fail("physical tutorial focus/action did not complete")
			return
	if not await caller.call("_live_wait_file", "host.allow_leave", 20.0) or not await walk("connected", &"move_forward", true):
		return
	if not await tap(&"pause", caller.root.gui_get_focus_owner(), "Start to pause", button("ResumeButton")):
		return
	if not await move(&"ui_down", button("SettingsOpenButton"), "Down to Settings") or not await move(&"ui_down", button("ServerBrowserButton"), "Down to Server Browser") or not await accept("ServerBrowserButton"):
		return
	# Observe the actual retained linked focus graph; never assign focus.
	if not await to_refresh():
		return
	for name in ["ServerBrowserHostButton", "ServerBrowserManualJoinButton", "ServerBrowserDisconnectButton"]:
		if not await move(&"ui_right", button(name), "Right to " + name):
			return
	if button("ServerBrowserDisconnectButton").text != "DISCONNECT" or not await accept("ServerBrowserDisconnectButton"):
		fail("physical connected session action must be DISCONNECT")
		return
	if not caller.call("_live_record_guest_retirement", "guest.retired", guest_id, native):
		return
	var observation: Dictionary = caller.call("_live_browser_retry_observation")
	(caller.get("_live_walks") as Dictionary)["after_leave"] = observation
	if not caller.call("_live_browser_retry_ready", observation) or not focus(button("ServerBrowserDisconnectButton")):
		fail("physical Disconnect must retain focused enabled exact live Retry tuple")
		return
	if not await to_refresh() or not await accept("ServerBrowserRefreshButton"):
		return
	for name in ["ServerBrowserHostButton", "ServerBrowserManualJoinButton", "ServerBrowserDisconnectButton", "ServerBrowserBackButton"]:
		if not await move(&"ui_right", button(name), "Right to " + name):
			return
	if not await accept("ServerBrowserBackButton", button("ServerBrowserButton")) or not await move(&"ui_up", button("SettingsOpenButton"), "Up to Settings") or not await move(&"ui_up", button("ResumeButton"), "Up to Resume") or not await accept("ResumeButton"):
		return
	if not await walk("solo", &"move_back", false):
		return
	await caller.call("_live_wait_file", "host.cleared", 20.0)


func to_refresh() -> bool:
	for _step in range(16):
		var current := caller.root.gui_get_focus_owner()
		if current == button("ServerBrowserRefreshButton"):
			return true
		if current == null:
			return fail("physical browser lost current focus")
		var horizontal := current.name in [&"ServerBrowserHostButton", &"ServerBrowserManualJoinButton", &"ServerBrowserDisconnectButton", &"ServerBrowserBackButton"]
		var neighbor: NodePath = current.focus_neighbor_left if horizontal else current.focus_neighbor_bottom
		var action: StringName = &"ui_left" if horizontal else &"ui_down"
		if neighbor.is_empty():
			return fail("physical browser has no linked route to Refresh")
		var next := current.get_node_or_null(neighbor) as Control
		if next == null or next == current or not await move(action, next, ("Left" if horizontal else "Down") + " toward Refresh"):
			return fail("physical browser traversal did not reach Refresh")
	return fail("physical browser finite traversal exhausted")


func walk(name: String, action: StringName, connected: bool) -> bool:
	_walking = true
	_walk_action = action
	prompt("Stick neutral; waiting for supported controls")
	var result: bool = await caller.call("_live_walk", name, action, connected)
	_walking = false
	_walk_action = &""
	return result and fault.is_empty()


func receipt() -> Dictionary:
	return {"binding": binding, "display": OS.get_environment("DISPLAY"), "xauthority": OS.get_environment("XAUTHORITY"), "display_driver": DisplayServer.get_name(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(), "device": device, "joy_info": Input.get_joy_info(device) if device >= 0 else {}, "events": events, "fault": fault, "physical_qualification": "PENDING_COORDINATOR_CHECKS"}
