class_name GameHUD
extends CanvasLayer

const FlightPathCueType := preload("res://scripts/ui/flight_path_cue.gd")
const PaletteType := preload("res://scripts/ui/hud_palette.gd")
const InputBindingProfileType := preload("res://scripts/settings/input_binding_profile.gd")
const InputRebindServiceType := preload("res://scripts/settings/input_rebind_service.gd")
const InputGlyphResolverType := preload("res://scripts/ui/input_glyph_resolver.gd")

signal start_requested
signal restart_requested
signal setting_change_requested(key: StringName, value: Variant)
signal settings_save_requested
signal settings_reset_requested

const INK := Color("07111d")
const PANEL := Color("101c2bd9")
const PANEL_SOLID := Color("0c1724")

## Semantic role names. Every state-bearing readout resolves its colour through
## these instead of a fixed constant, so a colour-vision preset can retint the
## complete HUD without any element being missed.
const NOMINAL := PaletteType.ROLE_NOMINAL
const NOMINAL_SOFT := PaletteType.ROLE_NOMINAL_SOFT
const CAUTION := PaletteType.ROLE_CAUTION
const DANGER := PaletteType.ROLE_DANGER
const PRIMARY := PaletteType.ROLE_PRIMARY
const MUTED := PaletteType.ROLE_MUTED

## Captions describe cue *events*, so they stay correct even when the audio
## backend is unavailable. Cues with no entry here are deliberately silent in the
## caption channel; footsteps in particular would drown every other line.
const CAPTION_TEXTS := {
	&"ui_confirm": "[ interface confirm ]",
	&"impact": "[ hull impact ]",
	&"target_destroyed": "[ range target destroyed ]",
	&"combat_alert": "[ combat alert ]",
	&"canopy_open": "[ canopy opening ]",
	&"canopy_close": "[ canopy closing ]",
	&"enemy_destroyed": "[ hostile craft destroyed ]",
	&"player_pulse_fire": "[ pulse cannon fires ]",
	&"defender_pulse_fire": "[ hostile pulse fire ]",
	&"dry_fire_click": "[ weapon dry click ]",
	&"hull_impact_light": "[ light hull impact ]",
	&"hull_impact_medium": "[ hull impact ]",
	&"hull_impact_heavy": "[ heavy hull impact ]",
	&"ship_explosion": "[ ship explosion ]",
}

const CAPTION_HISTORY_LIMIT := 3
const CAPTION_HOLD_SECONDS := 3.4

## Reduced motion keeps the informational content of the damage cue but removes
## the full-screen luminance sweep and the animated fades that cause discomfort.
const DAMAGE_FLASH_ALPHA := 0.24
const REDUCED_DAMAGE_FLASH_ALPHA := 0.07
const DAMAGE_FLASH_FADE_SECONDS := 0.42
const DAMAGE_DIRECTION_FADE_SECONDS := 0.62
const REDUCED_MOTION_HOLD_SECONDS := 0.45
## Smallest logical layout the HUD panels are authored for. The gameplay panels
## use fixed pixel offsets, so scaling past the point where that layout stops
## fitting the viewport makes readouts overlap instead of becoming more legible.
## The requested scale is therefore capped rather than honoured without limit.
##
## This is a *contract*, not an estimate: [method get_hud_panel_rects] measures
## the real rectangles and `tests/hud_panel_layout_test.gd` proves every pair is
## disjoint from this size upwards, for the worst-case text the game sets. The
## panels were re-anchored to honour it -- see [constant PANEL_LEFT_COLUMN_WIDTH]
## -- rather than raising the floor, because raising it to the ~1512 px the
## original offsets needed would also cap a plain 100% request on a 1280x720
## viewport and cost every player scale headroom on a 900p or 1080p screen.
const MIN_LOGICAL_WIDTH := 1180.0
const MIN_LOGICAL_HEIGHT := 690.0

## The gameplay HUD is a three-column layout: a fixed left gutter (wordmark and
## objective), a fixed right gutter (controls and telemetry), and a centre band
## that carries the transient panels. Every collision this layout can suffer is
## one of the centre panels meeting a gutter, and each such clearance is monotone
## in the logical width -- the gutters are pinned to the edges while the centre
## panels track the midpoint -- so proving the layout at
## [constant MIN_LOGICAL_WIDTH] proves it for every larger size.
##
## Measured worst-case content minimums at the time these were chosen (logical
## px): objective 154x125, controls 273x391, telemetry 226x217, toast 385x59,
## interaction 417x48, enemy 322x48, wordmark 254x51. Each width below keeps a
## margin over its minimum so a longer string grows the panel instead of pushing
## it into a neighbour.
const PANEL_MARGIN := 28.0
const PANEL_LEFT_COLUMN_WIDTH := 350.0
const PANEL_BRAND_WIDTH := 262.0
const PANEL_TELEMETRY_WIDTH := 312.0
const PANEL_HELP_WIDTH := 272.0
const MIN_UI_SCALE := 0.75
const MAX_UI_SCALE := 1.6
const GAMEPAD_CAPTURE_THRESHOLD := 0.75

const INPUT_ACTION_LABELS := {
	&"move_forward": "Move / thrust forward",
	&"move_back": "Move / thrust reverse",
	&"move_left": "Move / yaw left",
	&"move_right": "Move / yaw right",
	&"pitch_up": "Pitch up",
	&"pitch_down": "Pitch down",
	&"roll_left": "Roll left",
	&"roll_right": "Roll right",
	&"jump": "Jump",
	&"sprint_boost": "Sprint / boost",
	&"interact": "Interact / enter / exit",
	&"hover": "Hover assist",
	&"fire": "Fire",
	&"barrel_roll": "Barrel roll",
	&"landing_assist": "Landing assist",
	&"toggle_ship_camera_view": "Ship camera view",
	&"camera_distance_in": "Camera distance in",
	&"camera_distance_out": "Camera distance out",
	&"brake": "Brake",
	&"pause": "Pause",
	&"toggle_controls_overlay": "Controls overlay",
	&"toggle_first_person": "On-foot camera view",
}

const TOAST_FADE_IN_SECONDS := 0.18
const TOAST_FADE_OUT_SECONDS := 0.35
const INTRO_FADE_SECONDS := 0.45

## Where the player is standing when nothing more specific is known. On foot used
## to mean exactly one place; it no longer does.
const DEFAULT_ON_FOOT_LOCATION := "REGENERATION DECK"

## The embodiment the HUD is presenting. Every state-dependent readout -- the
## mode line, the controls card, the telemetry panel, the reticle -- is derived
## from this one value, so a state added by one caller cannot leave another
## readout describing the previous one. That is exactly the defect class already
## caught twice by rendering (`ON FOOT // REGENERATION DECK` while aboard a
## flying craft, and `EXIT: LANDED + OFFLINE` after the exit rule changed).
const MODE_PILOTING: StringName = &"piloting"
const MODE_ON_FOOT: StringName = &"on_foot"
## On foot, but inside a craft under way rather than on the station.
const MODE_ABOARD: StringName = &"aboard"
## Seated in a deck vehicle: not piloting, and not walking either.
const MODE_DRIVING: StringName = &"driving"

var _root: Control
var _intro: Control
var _hud: Control
var _hud_panels: Control
var _pause: Control
var _pause_panels: Control
var _pause_main_page: Control
var _settings_page: Control
var _settings_scroll: ScrollContainer
var _settings_controls: Dictionary = {}
var _settings_value_labels: Dictionary = {}
var _settings_status_label: Label
var _updating_settings := false
var _input_rebind_service: InputRebindService
var _input_binding_profile: InputBindingProfile
var _input_binding_defaults: InputBindingProfile
var _input_glyph_resolver: InputGlyphResolver
var _binding_rows: Dictionary = {}
var _binding_buttons: Dictionary = {}
var _binding_reset_buttons: Dictionary = {}
var _binding_capture_action: StringName = &""
var _pending_binding_conflict: Dictionary = {}
var _binding_conflict_panel: Control
var _binding_conflict_label: Label
var _binding_conflict_replace_button: Button
var _binding_conflict_cancel_button: Button
var _brand_block: VBoxContainer
var _objective_panel: PanelContainer
var _objective_label: Label
var _objective_kicker: Label
## Optional secondary objective supplied by the activity integration. It lives
## beside the ordinary GameFlow objective rather than replacing it, so docking,
## recovery, and guided-flight copy retain their existing authority.
var _activity_objective_label: Label
var _interaction_panel: PanelContainer
var _interaction_label: Label
var _mode_label: Label
var _engine_label: Label
var _speed_label: Label
var _altitude_label: Label
var _throttle_label: Label
var _throttle_bar: ProgressBar
var _hull_bar: ProgressBar
var _damage_status_label: Label
var _telemetry_panel: PanelContainer
var _target_label: Label
var _enemy_panel: PanelContainer
var _enemy_name_label: Label
var _enemy_health_bar: ProgressBar
var _enemy_status_label: Label
var _damage_flash: ColorRect
var _damage_direction: Label
var _damage_tween: Tween
var _toast_panel: PanelContainer
var _toast_title: Label
var _toast_detail: Label
var _help_panel: PanelContainer
var _reticle: Control
var _flight_cue_layer: FlightPathCue
var _toast_serial := 0
var _toast_tween: Tween
var _started := false
var _active_ship_name := "TORRENT-CLASS INTERCEPTOR"
var _active_ship_role := "INTERCEPTOR"

var _palette_mode: StringName = PaletteType.MODE_NONE
var _palette: Dictionary = PaletteType.get_palette(PaletteType.MODE_NONE)
## Every element whose colour is a palette role, recorded as it is built so a
## preset change retints the live HUD without rebuilding or reloading it.
var _palette_targets: Array[Dictionary] = []
var _ui_scale := 1.0
var _reduced_motion := false
var _captions_enabled := false
## Containers whose contents scale with the UI-scale preference. The reticle,
## flight-path cue, and damage flash are deliberately excluded: they are
## registered against camera-space pixels and must stay 1:1 with the viewport.
var _scaled_layers: Array[Control] = []
var _caption_panel: PanelContainer
var _caption_stack: VBoxContainer
var _caption_lines: Array[Label] = []
var _caption_log: Array[String] = []
var _caption_hold := 0.0
## Last known signal state, so a palette change repaints state colours
## immediately instead of waiting for the next telemetry tick.
var _state_piloting := false
var _state_mode: StringName = MODE_ON_FOOT
var _state_location := DEFAULT_ON_FOOT_LOCATION
var _state_engine := "OFFLINE"
var _state_damage := "HEALTHY"
var _state_throttle_reverse := false
var _state_enemy_breaking := false
var _activity_objective_report: Dictionary = {
	"visible": false,
	"activity_id": &"",
	"display_name": "",
	"state": CheckpointRouteActivity.State.IDLE,
	"generation": 0,
	"next_checkpoint_index": 0,
	"checkpoint_count": 0,
	"failure_reason": &"",
	"text": "",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_input_rebind_service = InputRebindServiceType.new()
	_input_binding_defaults = _input_rebind_service.get_defaults()
	_input_binding_profile = _input_binding_defaults.duplicate_profile()
	_input_glyph_resolver = InputGlyphResolverType.new()
	_build_interface()
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_apply_ui_scale):
		viewport.size_changed.connect(_apply_ui_scale)


func _process(delta: float) -> void:
	if _caption_hold <= 0.0:
		return
	_caption_hold = maxf(_caption_hold - delta, 0.0)
	if _caption_hold <= 0.0:
		_clear_captions()


func _input(event: InputEvent) -> void:
	_observe_prompt_device(event)


func _unhandled_input(event: InputEvent) -> void:
	if not _binding_capture_action.is_empty():
		_capture_binding_event(event)
		return
	if not _started and (event.is_action_pressed("interact") or event.is_action_pressed("jump")):
		_begin()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and _started:
		if _pause.visible and _settings_page != null and _settings_page.visible:
			_show_pause_main()
		else:
			set_paused(not _pause.visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_controls_overlay") and _started:
		# One InputMap action now owns the overlay so `F1` and the gamepad Back
		# button reach the identical toggle. `is_action_pressed()` still rejects
		# key repeats, so the previous physical-`F1` behaviour is unchanged.
		_help_panel.visible = not _help_panel.visible


func show_intro() -> void:
	_started = false
	_intro.visible = true
	_hud.visible = false
	_pause.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## `mode` names the embodiment and `on_foot_location` names where the player is
## standing while it is one of the on-foot ones. The location defaults to the
## station because that used to be the only place on-foot could mean; a crew
## member walking a craft's cabin under way is on foot somewhere else entirely,
## and the readout must not tell them they are on the regeneration deck.
##
## The mode string is matched rather than enumerated so existing callers passing
## `"piloting"` / `"on-foot"` keep working; `"driving"` and `"cabin"` reach the
## two states added since.
func set_mode(mode: String, on_foot_location: String = DEFAULT_ON_FOOT_LOCATION) -> void:
	_state_mode = _resolve_mode(mode)
	var location := on_foot_location.strip_edges().to_upper()
	if location.is_empty():
		location = DEFAULT_ON_FOOT_LOCATION
	_state_location = location
	_refresh_mode_readouts()


## Resolves a caller's mode word to one of the four embodiments. Unknown words
## resolve to on-foot, which is the state whose controls card is safe to show
## when nothing else is known.
func _resolve_mode(mode: String) -> StringName:
	var normalized := mode.to_lower()
	if normalized.contains("pilot"):
		return MODE_PILOTING
	if normalized.contains("driv") or normalized.contains("tractor") or normalized.contains("vehicle"):
		return MODE_DRIVING
	if normalized.contains("cabin") or normalized.contains("aboard"):
		return MODE_ABOARD
	return MODE_ON_FOOT


## Single writer of every readout that depends on the embodiment. Called from
## both [method set_mode] and [method set_ship_identity] so naming the craft can
## never leave the controls card describing a different state -- it previously
## overwrote the card with the walking hints whenever telemetry was hidden, which
## is every ground vehicle and cabin state there now is.
func _refresh_mode_readouts() -> void:
	var piloting := _state_mode == MODE_PILOTING
	_state_piloting = piloting
	if not is_instance_valid(_mode_label) or not is_instance_valid(_help_panel):
		return
	match _state_mode:
		MODE_PILOTING:
			_mode_label.text = "PILOTING  //  %s" % _active_ship_name
		MODE_DRIVING:
			_mode_label.text = "DRIVING  //  %s" % _state_location
		MODE_ABOARD:
			# Still on foot -- but aboard, not on the station. The state word is
			# placed before the craft name so it survives a clipped long name.
			_mode_label.text = "ON FOOT  //  ABOARD %s" % _state_location
		_:
			_mode_label.text = "ON FOOT  //  %s" % _state_location
	_mode_label.modulate = _c(CAUTION) if piloting else _c(NOMINAL)
	_telemetry_panel.visible = piloting
	_reticle.visible = piloting
	if _flight_cue_layer != null:
		_flight_cue_layer.set_piloting(piloting)
	_set_help_text(_help_rows_for_mode(_state_mode))


## The controls card for one embodiment. Every row here names a binding that is
## live in that state: a hint for a key that does nothing is the same defect as a
## missing one, only harder to notice.
func _help_rows_for_mode(mode: StringName) -> Array:
	match mode:
		MODE_PILOTING:
			return [
				[_action_prompts([&"move_forward", &"move_back"]), "FORWARD / REVERSE  //  AUTO POWER"],
				[_look_prompt(), "STEER"],
				[_action_prompts([&"pitch_up", &"pitch_down"]), "PITCH"],
				[_action_prompts([&"move_left", &"move_right"]), "YAW"],
				[_action_prompts([&"roll_left", &"roll_right"]), "ROLL"],
				[_action_prompts([&"fire"]), "FIRE"],
				[_action_prompts([&"sprint_boost", &"brake"]), "BOOST / BRAKE"],
				[_view_distance_prompts(), "VIEW / DISTANCE"],
				[_action_prompts([&"hover", &"barrel_roll"]), "HOVER / BARREL ROLL"],
				[_action_prompts([&"landing_assist"]), "LANDING ASSIST"],
				[_action_prompts([&"interact"]), "LEAVE SEAT: AUTO-OFFLINE"],
				[_action_prompts([&"toggle_controls_overlay"]), "CONTROLS"],
			]
		MODE_DRIVING:
			# The tractor brakes on `brake` *or* `jump`, steers on A/D, and hands
			# the seat back on `interact` only once it has come to a stop.
			return [
				[_action_prompts([&"move_forward", &"move_back"]), "DRIVE / REVERSE"],
				[_action_prompts([&"move_left", &"move_right"]), "STEER"],
				[_action_prompts([&"jump", &"brake"]), "BRAKE"],
				[_look_prompt(), "LOOK"],
				[_action_prompts([&"interact"]), "HOP OUT: STOPPED"],
				[_action_prompts([&"toggle_controls_overlay"]), "CONTROLS"],
			]
		MODE_ABOARD:
			# Inside a craft under way there is nothing to board and nowhere to
			# walk off to; the only thing `E` does here is sit back down.
			return [
				[_action_prompts([&"move_forward", &"move_back", &"move_left", &"move_right"]), "MOVE"],
				[_look_prompt(), "LOOK"],
				[_action_prompts([&"sprint_boost"]), "SPRINT"],
				[_action_prompts([&"jump"]), "JUMP"],
				[_action_prompts([&"interact"]), "TAKE THE PILOT SEAT"],
				[_action_prompts([&"toggle_first_person"]), "1ST / 3RD PERSON"],
				[_action_prompts([&"toggle_controls_overlay"]), "CONTROLS"],
			]
		_:
			return [
				[_action_prompts([&"move_forward", &"move_back", &"move_left", &"move_right"]), "MOVE"],
				[_look_prompt(), "LOOK"],
				[_action_prompts([&"sprint_boost"]), "SPRINT"],
				[_action_prompts([&"jump"]), "JUMP"],
				[_action_prompts([&"interact"]), "INTERACT / BOARD"],
				[_action_prompts([&"toggle_first_person"]), "1ST / 3RD PERSON"],
				[_action_prompts([&"toggle_controls_overlay"]), "CONTROLS"],
			]


func _action_prompts(actions: Array[StringName]) -> String:
	var parts := PackedStringArray()
	var shared_stick := ""
	for action in actions:
		var resolved := _input_glyph_resolver.resolve_action(_input_binding_profile, action)
		if bool(resolved.get("valid", false)):
			var text := str(resolved.get("text", "Unbound Input"))
			if text not in parts:
				parts.append(text)
			var token := str(resolved.get("glyph_token", ""))
			var stick := ""
			if token.contains(".left_stick."):
				stick = "Left Stick"
			elif token.contains(".right_stick."):
				stick = "Right Stick"
			if shared_stick.is_empty():
				shared_stick = stick
			elif shared_stick != stick:
				shared_stick = "mixed"
	if not parts.is_empty() and not shared_stick.is_empty() and shared_stick != "mixed":
		return shared_stick
	return "Unbound Input" if parts.is_empty() else " / ".join(parts)


func _look_prompt() -> String:
	return (
		"Right Stick"
		if InputGlyphResolverType.GAMEPAD_FAMILIES.has(
			_input_glyph_resolver.get_preferred_device_family()
		)
		else "Mouse"
	)


func _view_distance_prompts() -> String:
	var view := _action_prompts([&"toggle_ship_camera_view"])
	var distance := (
		_action_prompts([&"camera_distance_out"])
		if InputGlyphResolverType.GAMEPAD_FAMILIES.has(
			_input_glyph_resolver.get_preferred_device_family()
		)
		else "Mouse Wheel"
	)
	return "%s / %s" % [view, distance]


## The embodiment the HUD is currently presenting. Exposed so a regression can
## assert the state rather than parse the rendered label.
func get_hud_mode() -> StringName:
	return _state_mode


func set_ship_identity(display_name: String, role: String = "") -> void:
	_active_ship_name = display_name.strip_edges().to_upper()
	if _active_ship_name.is_empty():
		_active_ship_name = "SPACECRAFT"
	_active_ship_role = role.strip_edges().to_upper()
	if _mode_label != null:
		_refresh_mode_readouts()


func set_objective(text: String, kicker: String = "CURRENT OBJECTIVE") -> void:
	_objective_kicker.text = kicker
	_objective_label.text = text


## Consumes the director's side-effect-free snapshot as presentation only. The
## HUD never starts, advances, fails, resets, or rewards an activity.
func set_activity_objective(display_name: String, snapshot: Dictionary) -> void:
	var activity_id := StringName(snapshot.get("activity_id", &""))
	var state := int(snapshot.get("state", CheckpointRouteActivity.State.IDLE))
	var generation := int(snapshot.get("generation", 0))
	var next_index := maxi(int(snapshot.get("next_checkpoint_index", 0)), 0)
	var checkpoint_count := maxi(int(snapshot.get("checkpoint_count", 0)), 0)
	var failure_reason := StringName(snapshot.get("failure_reason", &""))
	var short_name := display_name.strip_edges().to_upper()
	if short_name.is_empty():
		short_name = str(activity_id).replace("_", " ").to_upper()
	var activity_text := ""
	match state:
		CheckpointRouteActivity.State.ACTIVE:
			activity_text = "%s  //  CHECKPOINT %d / %d" % [
				short_name,
				mini(next_index + 1, checkpoint_count),
				checkpoint_count,
			]
		CheckpointRouteActivity.State.COMPLETED:
			activity_text = "%s  //  ROUTE COMPLETE" % short_name
		CheckpointRouteActivity.State.FAILED:
			var readable_reason := str(failure_reason).replace("_", " ").to_upper()
			activity_text = "%s  //  FAILED%s" % [
				short_name,
				(" — " + readable_reason) if not readable_reason.is_empty() else "",
			]
		_:
			activity_text = ""
	var visible := not activity_text.is_empty()
	_activity_objective_report = {
		"visible": visible,
		"activity_id": activity_id,
		"display_name": display_name,
		"state": state,
		"generation": generation,
		"next_checkpoint_index": next_index,
		"checkpoint_count": checkpoint_count,
		"failure_reason": failure_reason,
		"text": activity_text,
	}
	if is_instance_valid(_activity_objective_label):
		_activity_objective_label.text = activity_text
		_activity_objective_label.visible = visible


func clear_activity_objective() -> void:
	set_activity_objective("", {})


## Detached copy for focused integration checks and non-visual accessibility
## consumers. Mutating it cannot change the live HUD state.
func get_activity_objective_report() -> Dictionary:
	return _activity_objective_report.duplicate(true)


func set_interaction(text: String, is_visible: bool = true) -> void:
	_interaction_label.text = text
	_interaction_panel.visible = is_visible and not text.is_empty()


func update_ship_telemetry(data: Dictionary) -> void:
	var speed: float = float(data.get("speed", 0.0))
	var altitude: float = maxf(0.0, float(data.get("altitude", 0.0)))
	var throttle: float = clampf(float(data.get("throttle", 0.0)), -1.0, 1.0)
	var maximum_hull: float = maxf(0.001, float(data.get("maximum_hull", 100.0)))
	var hull: float = clampf(float(data.get("hull", maximum_hull)), 0.0, maximum_hull)
	var damage_status := str(data.get("damage_status", "healthy")).to_upper()
	_state_damage = damage_status
	_state_throttle_reverse = throttle < -0.04
	var engine_power := clampf(float(data.get("engine_power", 1.0)), 0.0, 1.0)
	_speed_label.text = "%03d" % roundi(speed)
	_altitude_label.text = "%04d M" % roundi(altitude)
	_throttle_bar.value = absf(throttle) * 100.0
	_throttle_label.text = "THROTTLE  //  %s" % (
		"REVERSE" if throttle < -0.04 else ("FORWARD" if throttle > 0.04 else "NEUTRAL")
	)
	_throttle_label.modulate = _c(CAUTION) if throttle < -0.04 else _c(MUTED)
	_hull_bar.value = clampf(hull / maximum_hull, 0.0, 1.0) * 100.0
	_damage_status_label.text = "HULL  //  %s    ENGINE OUTPUT  %03d%%" % [
		damage_status,
		roundi(engine_power * 100.0),
	]
	_damage_status_label.modulate = _damage_status_color(damage_status)
	set_engine_state(str(data.get("engine_state", "OFFLINE")))
	if _flight_cue_layer != null:
		_flight_cue_layer.update_from_telemetry(data)


func get_flight_cue_report() -> Dictionary:
	if _flight_cue_layer == null:
		return {
			"schema_version": 1,
			"layer_visible": false,
			"marker_visible": false,
			"marker_position": Vector2.ZERO,
			"connector_visible": false,
			"clamped": false,
			"rearward": false,
			"alignment": 0.0,
			"camera_view": &"",
			"safe_center": Vector2.ZERO,
			"safe_radii": Vector2.ZERO,
			"safe_rect": Rect2(),
			"mouse_passthrough": true,
		}
	var report := _flight_cue_layer.get_audit_report()
	report["reticle_visible"] = _reticle != null and _reticle.visible
	return report


func set_engine_state(state: String) -> void:
	var normalized := state.to_upper()
	_state_engine = normalized
	_engine_label.text = "ENGINE  //  " + normalized
	match normalized:
		"ONLINE": _engine_label.modulate = _c(NOMINAL)
		"STARTING": _engine_label.modulate = _c(CAUTION)
		_: _engine_label.modulate = _c(DANGER)


func set_target_count(destroyed: int, total: int) -> void:
	_target_label.text = "RANGE TARGETS  %d / %d" % [destroyed, total]


func set_enemy_status(display_name: String, current: float, maximum: float, visible: bool = true) -> void:
	_enemy_panel.visible = visible
	if not visible:
		return
	_enemy_name_label.text = display_name.to_upper()
	var safe_maximum := maxf(maximum, 0.001)
	var ratio := clampf(current / safe_maximum, 0.0, 1.0)
	_state_enemy_breaking = ratio <= 0.35
	_enemy_health_bar.value = ratio * 100.0
	_enemy_status_label.text = "%03d%%  //  %s" % [
		roundi(ratio * 100.0),
		"BREAKING" if ratio <= 0.35 else "ENGAGED",
	]
	_enemy_health_bar.modulate = _c(DANGER) if ratio <= 0.35 else _c(CAUTION)


func flash_damage(intensity: float = 1.0, direction: Vector2 = Vector2.ZERO) -> void:
	var strength := clampf(intensity, 0.2, 1.0)
	if is_instance_valid(_damage_tween):
		_damage_tween.kill()
	_damage_flash.color = Color(0.95, 0.08, 0.035, get_damage_flash_alpha() * strength)
	_damage_flash.modulate = Color.WHITE
	var normalized_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.UP
	var viewport_size := get_viewport().get_visible_rect().size
	var indicator_center := viewport_size * 0.5 + normalized_direction * Vector2(
		viewport_size.x * 0.36,
		viewport_size.y * 0.28
	)
	# Keep the directional cue inside safe margins and below the centered enemy
	# status panel; the previous fixed 1600x900 coordinate overlapped combat UI
	# and drifted at other resolutions.
	indicator_center.x = clampf(indicator_center.x, 80.0, viewport_size.x - 80.0)
	indicator_center.y = clampf(indicator_center.y, 240.0, viewport_size.y - 100.0)
	_damage_direction.position = indicator_center - _damage_direction.pivot_offset
	_damage_direction.rotation = normalized_direction.angle() + PI * 0.5
	_damage_direction.modulate = Color(1.0, 1.0, 1.0, strength)
	_damage_direction.visible = true
	_damage_tween = create_tween()
	if _reduced_motion:
		# Reduced motion keeps the direction of the hit legible but removes the
		# animated full-screen luminance sweep: the cue simply holds, then clears.
		_damage_tween.tween_interval(REDUCED_MOTION_HOLD_SECONDS)
		_damage_tween.tween_callback(func() -> void:
			_damage_flash.modulate = Color.TRANSPARENT
			_damage_direction.modulate = Color.TRANSPARENT
			_damage_direction.visible = false
			_damage_tween = null
		)
		return
	_damage_tween.set_parallel(true)
	_damage_tween.tween_property(_damage_flash, "modulate", Color.TRANSPARENT, DAMAGE_FLASH_FADE_SECONDS)
	_damage_tween.tween_property(_damage_direction, "modulate", Color.TRANSPARENT, DAMAGE_DIRECTION_FADE_SECONDS)
	_damage_tween.chain().tween_callback(func() -> void:
		_damage_direction.visible = false
		_damage_tween = null
	)


func toast(title: String, detail: String = "", duration: float = 3.2) -> void:
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	_toast_serial += 1
	var serial := _toast_serial
	_toast_title.text = title.to_upper()
	_toast_detail.text = detail
	_toast_panel.modulate = Color.WHITE if _reduced_motion else Color.TRANSPARENT
	_toast_panel.visible = true
	_toast_tween = create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(_toast_panel, "modulate", Color.WHITE, get_toast_fade_seconds())
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_panel, "modulate", Color.TRANSPARENT, get_toast_fade_seconds())
	_toast_tween.tween_callback(func() -> void:
		if serial == _toast_serial:
			_toast_panel.visible = false
			_toast_tween = null
	)


func set_paused(paused: bool) -> void:
	_pause.visible = paused
	if paused:
		_show_pause_main()
	else:
		_binding_capture_action = &""
		_cancel_pending_input_conflict(false)
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused and _pause_main_page != null:
		var resume := _pause_main_page.find_child("ResumeButton", true, false) as Button
		if resume != null:
			resume.grab_focus()


## Populates every supplied preference without sending change requests back to
## the settings owner. Missing keys retain the values currently shown.
func set_settings_snapshot(snapshot: Dictionary) -> void:
	_updating_settings = true
	if snapshot.has("input_binding_profile"):
		var parsed_profile := InputBindingProfileType.from_dictionary(
			snapshot["input_binding_profile"]
		)
		if (
			parsed_profile != null
			and _input_rebind_service.is_profile_compatible_with_defaults(parsed_profile)
		):
			_input_binding_profile = parsed_profile.duplicate_profile()
			_refresh_input_prompts()
	for raw_key: Variant in snapshot:
		var key := StringName(str(raw_key))
		if not _settings_controls.has(key):
			continue
		var control := _settings_controls[key] as Control
		var value: Variant = snapshot[raw_key]
		if control is Range:
			(control as Range).value = float(value)
			_update_setting_value_label(key, float(value))
		elif control is CheckButton:
			(control as CheckButton).button_pressed = bool(value)
		elif control is OptionButton:
			var option := control as OptionButton
			option.select(clampi(int(value), 0, option.item_count - 1))
	_updating_settings = false


## Supplies the process-stable authored defaults owned by RuntimeSettings.
## Recreated HUDs cannot infer these from InputMap because the live map may
## already contain a persisted remap from the previous Main instance.
func set_input_binding_defaults(defaults: InputBindingProfile) -> bool:
	if defaults == null:
		return false
	var replacement_service := InputRebindServiceType.new(defaults)
	var detached_defaults := replacement_service.get_defaults()
	if not replacement_service.is_profile_compatible_with_defaults(detached_defaults):
		return false
	_input_rebind_service = replacement_service
	_input_binding_defaults = detached_defaults
	if (
		_input_binding_profile == null
		or not _input_rebind_service.is_profile_compatible_with_defaults(_input_binding_profile)
	):
		_input_binding_profile = _input_binding_defaults.duplicate_profile()
	_refresh_input_prompts()
	return true


func set_settings_status(text: String, success: bool = true) -> void:
	if _settings_status_label == null:
		return
	_settings_status_label.text = text
	_settings_status_label.modulate = _c(NOMINAL_SOFT) if success else _c(DANGER)
	_settings_status_label.visible = not text.is_empty()


## Applies a complete accessibility descriptor from
## [method RuntimeSettings.get_accessibility_descriptor]. Missing keys keep the
## current value, and every supplied value is revalidated here so the HUD can
## never be driven into an unreadable state by a malformed caller.
func set_accessibility(descriptor: Dictionary) -> void:
	if descriptor.has("ui_scale"):
		set_ui_scale(float(descriptor["ui_scale"]))
	if descriptor.has("colorblind_palette_id"):
		set_hud_palette(StringName(str(descriptor["colorblind_palette_id"])))
	if descriptor.has("reduced_motion"):
		set_reduced_motion(bool(descriptor["reduced_motion"]))
	if descriptor.has("captions_enabled"):
		set_captions_enabled(bool(descriptor["captions_enabled"]))


## Retints every registered element. An unknown ID resolves to the authored
## palette rather than leaving a half-applied preset on screen.
func set_hud_palette(mode_id: StringName) -> void:
	var resolved := mode_id if PaletteType.has_mode(mode_id) else PaletteType.MODE_NONE
	_palette_mode = resolved
	_palette = PaletteType.get_palette(resolved)
	# The help panel rebuilds its labels whenever the control hints change, so
	# prune retired targets here rather than letting the registry grow forever.
	var live: Array[Dictionary] = []
	for entry in _palette_targets:
		if _apply_palette_target(entry):
			live.append(entry)
	_palette_targets = live
	_refresh_state_tints()


func get_hud_palette_id() -> StringName:
	return _palette_mode


## Clamps a requested scale, then caps it at the largest factor whose logical
## layout still fits `viewport_size`. Exposed so callers and tests can reason
## about the ceiling without owning a viewport.
static func compute_effective_ui_scale(requested: float, viewport_size: Vector2) -> float:
	var validated := requested
	if is_nan(validated) or is_inf(validated):
		validated = 1.0
	validated = clampf(validated, MIN_UI_SCALE, MAX_UI_SCALE)
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return validated
	var ceiling := minf(
		viewport_size.x / MIN_LOGICAL_WIDTH,
		viewport_size.y / MIN_LOGICAL_HEIGHT
	)
	return minf(validated, maxf(ceiling, MIN_UI_SCALE))


## Every gameplay HUD panel's live rectangle, in the logical (pre-scale) space of
## the scaled panel layer, keyed by a stable name. Exposed so the layout contract
## in [constant MIN_LOGICAL_WIDTH] can be *measured* rather than asserted by
## inspection: two panels overlapping here is exactly the defect where a readout
## occludes another. Only laid-out panels appear; visibility is deliberately
## ignored, because a panel that is hidden right now still has to have somewhere
## to go when it appears.
func get_hud_panel_rects() -> Dictionary:
	var sources := {
		"brand": _brand_block,
		"objective": _objective_panel,
		"help": _help_panel,
		"interaction": _interaction_panel,
		"telemetry": _telemetry_panel,
		"toast": _toast_panel,
		"enemy": _enemy_panel,
		"caption": _caption_panel,
	}
	var rects := {}
	for key: String in sources:
		var control := sources[key] as Control
		if is_instance_valid(control):
			rects[key] = control.get_rect()
	return rects


## Lays the scaled layers out for an explicit viewport instead of the live one,
## and returns the effective factor that was applied. This is the single code
## path [method _apply_ui_scale] uses, exposed so the layout regression measures
## the shipping layout at window sizes a headless run cannot give the window.
func layout_for_viewport(viewport_size: Vector2) -> float:
	var effective := compute_effective_ui_scale(_ui_scale, viewport_size)
	var logical := viewport_size / maxf(effective, 0.01)
	for layer in _scaled_layers:
		if not is_instance_valid(layer):
			continue
		layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		layer.position = Vector2.ZERO
		layer.size = logical
		layer.scale = Vector2(effective, effective)
	return effective


## The logical size the gameplay panels are currently laid out into. This is the
## viewport divided by the effective scale, and is what the panel rectangles from
## [method get_hud_panel_rects] are expressed in.
func get_hud_logical_size() -> Vector2:
	if _hud_panels != null and is_instance_valid(_hud_panels):
		return _hud_panels.size
	return _viewport_size()


func set_ui_scale(scale: float) -> void:
	var validated := scale
	if is_nan(validated) or is_inf(validated):
		validated = 1.0
	_ui_scale = clampf(validated, MIN_UI_SCALE, MAX_UI_SCALE)
	_apply_ui_scale()


## The scale the player asked for, which persists unchanged across resolutions.
func get_ui_scale() -> float:
	return _ui_scale


## The scale actually in use once the current viewport's layout ceiling is
## applied. A small window honours less of a large request than a large one.
func get_effective_ui_scale() -> float:
	return compute_effective_ui_scale(_ui_scale, _viewport_size())


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func is_reduced_motion() -> bool:
	return _reduced_motion


func get_damage_flash_alpha() -> float:
	return REDUCED_DAMAGE_FLASH_ALPHA if _reduced_motion else DAMAGE_FLASH_ALPHA


func get_toast_fade_seconds() -> float:
	return 0.0 if _reduced_motion else TOAST_FADE_OUT_SECONDS


func set_captions_enabled(enabled: bool) -> void:
	if _captions_enabled == enabled:
		return
	_captions_enabled = enabled
	if not enabled:
		_clear_captions()
	elif _caption_panel != null:
		_caption_panel.visible = not _caption_log.is_empty()


func are_captions_enabled() -> bool:
	return _captions_enabled


## Presents one authored audio cue as readable text. Cues without an authored
## caption are ignored, and nothing is shown while captions are disabled.
func caption_cue(cue_id: StringName) -> bool:
	if not _captions_enabled or not CAPTION_TEXTS.has(cue_id):
		return false
	return show_caption(str(CAPTION_TEXTS[cue_id]))


func show_caption(text: String) -> bool:
	if not _captions_enabled or _caption_panel == null:
		return false
	var line := text.strip_edges()
	if line.is_empty():
		return false
	_caption_log.append(line)
	while _caption_log.size() > CAPTION_HISTORY_LIMIT:
		_caption_log.remove_at(0)
	_refresh_caption_lines()
	_caption_hold = CAPTION_HOLD_SECONDS
	_caption_panel.visible = true
	return true


func get_caption_log() -> PackedStringArray:
	return PackedStringArray(_caption_log)


## Detached snapshot of everything a preset changed. Tests and the settings owner
## read this instead of reaching into private HUD state.
func get_accessibility_report() -> Dictionary:
	return {
		"schema_version": 1,
		"ui_scale": _ui_scale,
		"effective_ui_scale": get_effective_ui_scale(),
		"viewport_size": _viewport_size(),
		"scaled_layer_count": _scaled_layers.size(),
		"scaled_layer_scale": _scaled_layers[0].scale.x if not _scaled_layers.is_empty() else 1.0,
		"reticle_scale": _reticle.scale.x if is_instance_valid(_reticle) else 1.0,
		"palette": _palette_mode,
		"palette_target_count": _palette_targets.size(),
		"nominal_color": _c(NOMINAL),
		"caution_color": _c(CAUTION),
		"danger_color": _c(DANGER),
		"muted_color": _c(MUTED),
		"engine_label_color": _engine_label.modulate if is_instance_valid(_engine_label) else Color.WHITE,
		"hull_label_color": _damage_status_label.modulate if is_instance_valid(_damage_status_label) else Color.WHITE,
		"reduced_motion": _reduced_motion,
		"damage_flash_alpha": get_damage_flash_alpha(),
		"toast_fade_seconds": get_toast_fade_seconds(),
		"captions_enabled": _captions_enabled,
		"caption_visible": _caption_panel != null and _caption_panel.visible,
		"caption_log": PackedStringArray(_caption_log),
	}


func _refresh_state_tints() -> void:
	if is_instance_valid(_mode_label):
		_mode_label.modulate = _c(CAUTION) if _state_piloting else _c(NOMINAL)
	if is_instance_valid(_engine_label):
		match _state_engine:
			"ONLINE": _engine_label.modulate = _c(NOMINAL)
			"STARTING": _engine_label.modulate = _c(CAUTION)
			_: _engine_label.modulate = _c(DANGER)
	if is_instance_valid(_throttle_label):
		_throttle_label.modulate = _c(CAUTION) if _state_throttle_reverse else _c(MUTED)
	if is_instance_valid(_damage_status_label):
		_damage_status_label.modulate = _damage_status_color(_state_damage)
	if is_instance_valid(_enemy_health_bar):
		_enemy_health_bar.modulate = _c(DANGER) if _state_enemy_breaking else _c(CAUTION)


func _apply_ui_scale() -> void:
	layout_for_viewport(_viewport_size())


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		var rect := viewport.get_visible_rect().size
		if rect.x > 1.0 and rect.y > 1.0:
			return rect
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	)


func _refresh_caption_lines() -> void:
	for index in _caption_lines.size():
		var label := _caption_lines[index]
		var source_index := _caption_log.size() - _caption_lines.size() + index
		if source_index < 0:
			label.text = ""
			label.visible = false
			continue
		label.text = _caption_log[source_index]
		label.visible = true
		label.modulate = Color(1.0, 1.0, 1.0, 0.55 if source_index < _caption_log.size() - 1 else 1.0)


func _clear_captions() -> void:
	_caption_log.clear()
	_caption_hold = 0.0
	_refresh_caption_lines()
	if _caption_panel != null:
		_caption_panel.visible = false


func _begin() -> void:
	if _started:
		return
	_started = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_intro, "modulate", Color.TRANSPARENT, 0.0 if _reduced_motion else INTRO_FADE_SECONDS)
	tween.tween_callback(func() -> void:
		_intro.visible = false
		_hud.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		start_requested.emit()
	)


func _build_interface() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_intro()
	_build_hud()
	_build_pause()
	_set_mouse_passthrough(_hud)
	_apply_ui_scale()
	show_intro()


func _build_intro() -> void:
	_intro = Control.new()
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_intro)

	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = load("res://assets/keth-nebula.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color("879eae")
	_intro.add_child(backdrop)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("02071194")
	_intro.add_child(shade)

	var corner := MarginContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.offset_left = 72.0
	corner.offset_right = 690.0
	corner.offset_top = -410.0
	corner.offset_bottom = -62.0
	_intro.add_child(corner)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	corner.add_child(stack)

	var eyebrow := _label("INSPIRED BY ZOLARKETH'S CLASSIC SANDBOX", 14, CAUTION)
	eyebrow.add_theme_constant_override("outline_size", 5)
	eyebrow.add_theme_color_override("font_outline_color", INK)
	stack.add_child(eyebrow)

	var title := _label("MUDDS", 82, PRIMARY)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", INK)
	stack.add_child(title)

	var title_two := _label("SHIPYARDS", 54, NOMINAL)
	title_two.add_theme_constant_override("outline_size", 10)
	title_two.add_theme_color_override("font_outline_color", INK)
	stack.add_child(title_two)

	var subtitle := _label("MODERN FAN REMAKE  /  VERTICAL SLICE 02", 16, MUTED)
	stack.add_child(subtitle)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(310.0, 3.0)
	_tint_rect(rule, CAUTION)
	stack.add_child(rule)

	var copy := _label("Walk the yard. Board the ship. Apply thrust.\nThe launch deck is waiting.", 18, PRIMARY)
	copy.add_theme_constant_override("line_spacing", 6)
	stack.add_child(copy)

	var start := Button.new()
	start.text = "BEGIN SHIFT   [ E ]"
	start.custom_minimum_size = Vector2(280.0, 52.0)
	start.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start.add_theme_font_size_override("font_size", 16)
	start.add_theme_color_override("font_color", INK)
	start.add_theme_color_override("font_hover_color", INK)
	start.add_theme_stylebox_override("normal", _fill_box(NOMINAL, 4))
	start.add_theme_stylebox_override("hover", _fill_box(NOMINAL_SOFT, 4))
	start.add_theme_stylebox_override("pressed", _fill_box(CAUTION, 4))
	start.pressed.connect(_begin)
	stack.add_child(start)

	# "STANDALONE FAN PROTOTYPE" is the in-game half of the unofficial-fan-project
	# boundary README and ROADMAP rely on, so the footer stays. The second clause
	# it used to carry was dropped after a playtest; the label is right-aligned
	# inside a fixed box, so the shorter string moves no edge.
	var footer := _label("STANDALONE FAN PROTOTYPE", 11, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.position = Vector2(-570.0, -42.0)
	footer.size = Vector2(530.0, 20.0)
	_intro.add_child(footer)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.visible = false
	_root.add_child(_hud)

	# Everything inside this container obeys the UI-scale preference. The reticle,
	# flight-path cue, and damage flash are added to `_hud` directly because they
	# are positioned from camera-space pixels and must not be rescaled.
	_hud_panels = Control.new()
	_hud_panels.name = "HudScaledPanels"
	_hud_panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hud_panels)
	_scaled_layers.append(_hud_panels)

	# Sized to its own wordmark rather than to a round number. The block used to
	# reserve 460x96 for 254x51 of text, and that empty reservation is what the
	# centre-top toast was measured as colliding with.
	_brand_block = VBoxContainer.new()
	_brand_block.name = "BrandBlock"
	_brand_block.position = Vector2(30.0, 26.0)
	_brand_block.size = Vector2(PANEL_BRAND_WIDTH, 84.0)
	_brand_block.add_theme_constant_override("separation", 2)
	_hud_panels.add_child(_brand_block)
	_brand_block.add_child(_label("MUDDS  /  SHIPYARDS", 20, PRIMARY))
	_mode_label = _label("ON FOOT  //  %s" % DEFAULT_ON_FOOT_LOCATION, 12, NOMINAL)
	# The mode line is the one HUD string whose length the HUD does not control:
	# it carries a craft display name, and a longer craft than the one this block
	# was measured against widened the whole brand block past its authored
	# PANEL_BRAND_WIDTH and into the centre-top toast band. Clipping makes the
	# label's minimum width independent of its content, so the brand gutter holds
	# its authored width for any name and the layout contract cannot be broken by
	# adding a craft. `text` keeps the full string for callers and regressions.
	_mode_label.clip_text = true
	_mode_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mode_label.custom_minimum_size.x = PANEL_BRAND_WIDTH
	_brand_block.add_child(_mode_label)
	var brand_rule := ColorRect.new()
	brand_rule.custom_minimum_size = Vector2(245.0, 2.0)
	_tint_rect(brand_rule, NOMINAL)
	_brand_block.add_child(brand_rule)

	# The objective card defines the left gutter. It is narrower than the original
	# 440 so the centre-top enemy readout clears it at MIN_LOGICAL_WIDTH; the text
	# wraps to one more line instead of being occluded by that readout.
	_objective_panel = PanelContainer.new()
	_objective_panel.name = "ObjectivePanel"
	_objective_panel.position = Vector2(30.0, 126.0)
	_objective_panel.size = Vector2(PANEL_LEFT_COLUMN_WIDTH, 112.0)
	_objective_panel.add_theme_stylebox_override("panel", _box(PANEL, 8, 1, Color("315367")))
	_hud_panels.add_child(_objective_panel)
	var objective_margin := _margin(18, 14, 18, 14)
	_objective_panel.add_child(objective_margin)
	var objective_stack := VBoxContainer.new()
	objective_stack.add_theme_constant_override("separation", 6)
	objective_margin.add_child(objective_stack)
	_objective_kicker = _label("CURRENT OBJECTIVE", 11, CAUTION)
	objective_stack.add_child(_objective_kicker)
	_objective_label = _label("Approach the Torrent-class interceptor", 17, PRIMARY)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_stack.add_child(_objective_label)
	_activity_objective_label = _label("", 10, NOMINAL_SOFT)
	_activity_objective_label.name = "ActivityObjectiveLabel"
	_activity_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_activity_objective_label.visible = false
	objective_stack.add_child(_activity_objective_label)
	_target_label = _label("RANGE TARGETS  0 / 3", 11, MUTED)
	objective_stack.add_child(_target_label)

	_help_panel = PanelContainer.new()
	_help_panel.name = "HelpPanel"
	_help_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_help_panel.offset_left = -(PANEL_HELP_WIDTH + PANEL_MARGIN)
	_help_panel.offset_right = -PANEL_MARGIN
	_help_panel.offset_top = 28.0
	_help_panel.offset_bottom = 342.0
	_help_panel.add_theme_stylebox_override("panel", _box(PANEL, 8, 1, Color("315367")))
	_hud_panels.add_child(_help_panel)
	_set_help_text([])

	# Narrowed from +/-250 so the prompt clears the telemetry column at
	# MIN_LOGICAL_WIDTH. 430 still clears the longest authored prompt ("Clear the
	# berth before requesting a return approach", 417 px) on one line, and the
	# label wraps rather than widening the panel if a longer one is ever added.
	_interaction_panel = PanelContainer.new()
	_interaction_panel.name = "InteractionPanel"
	_interaction_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_panel.offset_left = -215.0
	_interaction_panel.offset_right = 215.0
	_interaction_panel.offset_top = -118.0
	_interaction_panel.offset_bottom = -54.0
	_interaction_panel.add_theme_stylebox_override("panel", _border_box(Color("101c2bf2"), 7, NOMINAL))
	_hud_panels.add_child(_interaction_panel)
	var interaction_margin := _margin(18, 12, 18, 12)
	_interaction_panel.add_child(interaction_margin)
	_interaction_label = _label("[ E ]  BOARD TORRENT", 15, PRIMARY)
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_margin.add_child(_interaction_label)
	_interaction_panel.visible = false

	_flight_cue_layer = FlightPathCueType.new() as FlightPathCue
	_flight_cue_layer.name = "FlightPathCue"
	_flight_cue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_flight_cue_layer)

	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.position = Vector2(-22.0, -22.0)
	_reticle.size = Vector2(44.0, 44.0)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_reticle)
	for rect_data: Array in [
		[Vector2(20, 0), Vector2(4, 12)], [Vector2(20, 32), Vector2(4, 12)],
		[Vector2(0, 20), Vector2(12, 4)], [Vector2(32, 20), Vector2(12, 4)]
	]:
		var mark := ColorRect.new()
		mark.position = rect_data[0]
		mark.size = rect_data[1]
		_tint_rect(mark, NOMINAL)
		_reticle.add_child(mark)
	_reticle.visible = false

	_build_telemetry()
	_build_enemy_status()
	_build_toast()
	_build_captions()
	_build_damage_flash()


func _build_telemetry() -> void:
	# The telemetry card defines the right gutter below the controls card. It is
	# narrower and shorter than the original 350x232 so the bottom-centre
	# interaction prompt clears it horizontally and the controls card clears it
	# vertically at the MIN_LOGICAL_WIDTH x MIN_LOGICAL_HEIGHT floor.
	_telemetry_panel = PanelContainer.new()
	_telemetry_panel.name = "TelemetryPanel"
	_telemetry_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_telemetry_panel.offset_left = -(PANEL_TELEMETRY_WIDTH + PANEL_MARGIN)
	_telemetry_panel.offset_right = -PANEL_MARGIN
	_telemetry_panel.offset_top = -250.0
	_telemetry_panel.offset_bottom = -PANEL_MARGIN
	_telemetry_panel.add_theme_stylebox_override("panel", _box(PANEL, 8, 1, Color("315367")))
	_hud_panels.add_child(_telemetry_panel)
	var margin := _margin(18, 15, 18, 15)
	_telemetry_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	_engine_label = _label("ENGINE  //  OFFLINE", 12, DANGER)
	stack.add_child(_engine_label)
	var readouts := HBoxContainer.new()
	readouts.add_theme_constant_override("separation", 26)
	stack.add_child(readouts)
	var speed_stack := VBoxContainer.new()
	readouts.add_child(speed_stack)
	_speed_label = _label("000", 38, PRIMARY)
	speed_stack.add_child(_speed_label)
	speed_stack.add_child(_label("M / S", 10, MUTED))
	var alt_stack := VBoxContainer.new()
	readouts.add_child(alt_stack)
	_altitude_label = _label("0000 M", 27, NOMINAL_SOFT)
	alt_stack.add_child(_altitude_label)
	alt_stack.add_child(_label("ALTITUDE", 10, MUTED))
	_throttle_label = _label("THROTTLE  //  NEUTRAL", 9, MUTED)
	stack.add_child(_throttle_label)
	_throttle_bar = _bar(NOMINAL)
	stack.add_child(_throttle_bar)
	stack.add_child(_label("HULL INTEGRITY", 9, MUTED))
	_hull_bar = _bar(CAUTION)
	_hull_bar.value = 100.0
	stack.add_child(_hull_bar)
	_damage_status_label = _label("HULL  //  HEALTHY    ENGINE OUTPUT  100%", 9, MUTED)
	stack.add_child(_damage_status_label)
	_telemetry_panel.visible = false


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_left = -255.0
	_toast_panel.offset_right = 255.0
	_toast_panel.offset_top = 32.0
	_toast_panel.offset_bottom = 112.0
	_toast_panel.add_theme_stylebox_override("panel", _border_box(PANEL_SOLID, 6, CAUTION))
	_hud_panels.add_child(_toast_panel)
	var margin := _margin(18, 10, 18, 10)
	_toast_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	_toast_title = _label("SYSTEM ONLINE", 13, CAUTION)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_toast_title)
	_toast_detail = _label("", 12, PRIMARY)
	_toast_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_toast_detail)
	_toast_panel.visible = false


func _build_enemy_status() -> void:
	# Narrowed from +/-238. This readout shares its band with the objective card,
	# and at MIN_LOGICAL_WIDTH a 476 px centred panel reached 118 px into it --
	# the measured defect that hid the objective text. There is no vertical slot
	# for it instead: the gap between the objective card and the caption panel is
	# 81 px at MIN_LOGICAL_HEIGHT and this readout is 68 px tall.
	_enemy_panel = PanelContainer.new()
	_enemy_panel.name = "EnemyPanel"
	_enemy_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_enemy_panel.offset_left = -180.0
	_enemy_panel.offset_right = 180.0
	_enemy_panel.offset_top = 124.0
	_enemy_panel.offset_bottom = 192.0
	_enemy_panel.add_theme_stylebox_override("panel", _border_box(Color("180f16e8"), 7, DANGER))
	_hud_panels.add_child(_enemy_panel)
	var margin := _margin(16, 9, 16, 9)
	_enemy_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	_enemy_name_label = _label("RANGE DEFENCE INTERCEPTOR", 11, PRIMARY)
	_enemy_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_enemy_name_label)
	_enemy_status_label = _label("100%  //  ENGAGED", 10, CAUTION)
	heading.add_child(_enemy_status_label)
	_enemy_health_bar = _bar(CAUTION)
	_enemy_health_bar.value = 100.0
	stack.add_child(_enemy_health_bar)
	_enemy_panel.visible = false


func _build_captions() -> void:
	_caption_panel = PanelContainer.new()
	_caption_panel.name = "CaptionPanel"
	_caption_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# Seated entirely above the telemetry panel's top edge (-250) and above the
	# interaction prompt, so captions never cover speed, altitude, hull state, or
	# the board/dock prompt at any supported UI scale. The three caption lines
	# push the real height to 94 px, so the authored 90 px band is the floor, not
	# the actual extent -- the clearance below is measured against 94.
	_caption_panel.offset_left = -235.0
	_caption_panel.offset_right = 235.0
	_caption_panel.offset_top = -362.0
	_caption_panel.offset_bottom = -272.0
	_caption_panel.add_theme_stylebox_override("panel", _border_box(Color("06101ae8"), 6, NOMINAL_SOFT))
	_hud_panels.add_child(_caption_panel)
	var margin := _margin(16, 10, 16, 10)
	_caption_panel.add_child(margin)
	_caption_stack = VBoxContainer.new()
	_caption_stack.add_theme_constant_override("separation", 3)
	margin.add_child(_caption_stack)
	for index in CAPTION_HISTORY_LIMIT:
		var line := _label("", 15, PRIMARY)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.visible = false
		_caption_stack.add_child(line)
		_caption_lines.append(line)
	_caption_panel.visible = false


func _build_damage_flash() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.95, 0.08, 0.035, 0.2)
	_damage_flash.modulate = Color.TRANSPARENT
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_damage_flash)
	_damage_direction = _label("▲", 30, DANGER)
	_damage_direction.size = Vector2(50.0, 50.0)
	_damage_direction.pivot_offset = Vector2(25.0, 25.0)
	_damage_direction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_direction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_damage_direction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_direction.visible = false
	_hud.add_child(_damage_direction)


func _build_pause() -> void:
	_pause = Control.new()
	_pause.name = "PauseOverlay"
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.visible = false
	_root.add_child(_pause)
	var dim := ColorRect.new()
	dim.name = "PauseDimmer"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color("020711c7")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.add_child(dim)
	# The dimmer stays viewport-sized; only the readable panels scale.
	_pause_panels = Control.new()
	_pause_panels.name = "PauseScaledPanels"
	_pause_panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.add_child(_pause_panels)
	_scaled_layers.append(_pause_panels)
	_build_pause_main_page()
	_build_settings_page()
	_show_pause_main()


func _build_pause_main_page() -> void:
	_pause_main_page = PanelContainer.new()
	_pause_main_page.name = "PauseMainPage"
	_pause_main_page.set_anchors_preset(Control.PRESET_CENTER)
	_pause_main_page.position = Vector2(-240.0, -204.0)
	_pause_main_page.size = Vector2(480.0, 408.0)
	_pause_main_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_main_page.add_theme_stylebox_override("panel", _border_box(PANEL_SOLID, 10, NOMINAL))
	_pause_panels.add_child(_pause_main_page)
	var margin := _margin(34, 28, 34, 28)
	_pause_main_page.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var paused_title := _label("SHIFT PAUSED", 30, PRIMARY)
	paused_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(paused_title)
	var paused_subtitle := _label("Station systems remain on standby.", 13, MUTED)
	paused_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(paused_subtitle)
	var resume := _menu_button("RESUME", NOMINAL)
	resume.name = "ResumeButton"
	resume.pressed.connect(func() -> void: set_paused(false))
	stack.add_child(resume)
	var settings := _menu_button("SETTINGS", NOMINAL_SOFT)
	settings.name = "SettingsOpenButton"
	settings.pressed.connect(_show_settings_page)
	stack.add_child(settings)
	var restart := _menu_button("RESTART SHIFT", CAUTION)
	restart.name = "RestartButton"
	restart.pressed.connect(func() -> void:
		set_paused(false)
		restart_requested.emit()
	)
	stack.add_child(restart)
	var exit := _menu_button("EXIT TO DESKTOP", DANGER)
	exit.name = "ExitButton"
	exit.pressed.connect(func() -> void: get_tree().quit())
	stack.add_child(exit)


func _build_settings_page() -> void:
	_settings_page = PanelContainer.new()
	_settings_page.name = "SettingsPage"
	_settings_page.set_anchors_preset(Control.PRESET_CENTER)
	_settings_page.position = Vector2(-430.0, -330.0)
	_settings_page.size = Vector2(860.0, 660.0)
	_settings_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_page.add_theme_stylebox_override("panel", _border_box(PANEL_SOLID, 10, NOMINAL))
	_pause_panels.add_child(_settings_page)

	var margin := _margin(30, 24, 30, 24)
	_settings_page.add_child(margin)
	var page_stack := VBoxContainer.new()
	page_stack.add_theme_constant_override("separation", 12)
	margin.add_child(page_stack)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 18)
	page_stack.add_child(heading)
	var heading_copy := VBoxContainer.new()
	heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_copy.add_theme_constant_override("separation", 2)
	heading.add_child(heading_copy)
	heading_copy.add_child(_label("SHIP SYSTEM SETTINGS", 25, PRIMARY))
	heading_copy.add_child(_label("Tune flight, camera, display and mix. Changes preview immediately.", 12, MUTED))
	var header_rule := ColorRect.new()
	header_rule.custom_minimum_size = Vector2(92.0, 3.0)
	header_rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tint_rect(header_rule, CAUTION)
	header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(header_rule)

	_settings_scroll = ScrollContainer.new()
	_settings_scroll.name = "SettingsScroll"
	_settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_settings_scroll.follow_focus = true
	_settings_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	page_stack.add_child(_settings_scroll)

	var columns := HBoxContainer.new()
	columns.custom_minimum_size.x = 780.0
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_settings_scroll.add_child(columns)
	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 12)
	columns.add_child(left_column)
	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 12)
	columns.add_child(right_column)

	var controls_group := _settings_group(left_column, "FLIGHT + CAMERA", "Input follows the direction you see.")
	_add_slider_setting(controls_group, &"ship_mouse_sensitivity", "Ship steering sensitivity", 0.0002, 0.02, 0.0001, 0.0022)
	_add_toggle_setting(controls_group, &"invert_ship_y", "Invert ship vertical look", false)
	_add_slider_setting(controls_group, &"on_foot_mouse_sensitivity", "On-foot look sensitivity", 0.0005, 0.02, 0.0001, 0.0025)
	_add_toggle_setting(controls_group, &"invert_on_foot_y", "Invert on-foot vertical look", false)
	_add_slider_setting(controls_group, &"camera_fov", "Camera field of view", 55.0, 110.0, 1.0, 72.0)
	_add_option_setting(controls_group, &"control_preset", "Control hints (labels only)", ["Modern", "Classic"], 0)

	var bindings_group := _settings_group(
		left_column,
		"INPUT BINDINGS",
		"Select an action, then press a keyboard, mouse, or gamepad control."
	)
	_build_input_binding_rows(bindings_group)

	var display_group := _settings_group(left_column, "DISPLAY", "Choose clarity or headroom.")
	_add_option_setting(display_group, &"graphics_profile", "Graphics quality", ["Low", "Medium", "High"], 2)
	_add_option_setting(display_group, &"window_mode", "Window mode", ["Windowed", "Borderless", "Fullscreen"], 0)

	var audio_group := _settings_group(right_column, "AUDIO MIX", "Independent linear volume controls.")
	_add_slider_setting(audio_group, &"master_volume", "Master", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"ambience_volume", "Shipyard ambience", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"engine_volume", "Engines", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"weapons_volume", "Weapons", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"ui_volume", "Interface", 0.0, 1.0, 0.01, 1.0)

	var accessibility_group := _settings_group(
		right_column,
		"ACCESSIBILITY",
		"Presentation only. Flight handling is never changed."
	)
	_add_slider_setting(accessibility_group, &"ui_scale", "HUD and menu scale", 0.75, 1.6, 0.05, 1.0)
	_add_option_setting(
		accessibility_group,
		&"colorblind_palette",
		"Colour-vision preset",
		["Off", "Deuteranopia", "Protanopia", "Tritanopia"],
		0
	)
	_add_toggle_setting(accessibility_group, &"reduced_motion", "Reduced motion", false)
	_add_toggle_setting(accessibility_group, &"captions_enabled", "Audio cue captions", false)

	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", _box(Color("122638"), 5, 1, Color("315367")))
	right_column.add_child(hint_panel)
	var hint_margin := _margin(14, 12, 14, 12)
	hint_panel.add_child(hint_margin)
	var hint := _label("TIP  //  Start with the cockpit camera and lower steering sensitivity if the nose feels too eager.", 11, NOMINAL_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_margin.add_child(hint)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	page_stack.add_child(footer)
	var save := _menu_button("APPLY + SAVE", NOMINAL)
	save.name = "SettingsSaveButton"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(func() -> void: settings_save_requested.emit())
	footer.add_child(save)
	var reset := _menu_button("RESET DEFAULTS", CAUTION)
	reset.name = "SettingsResetButton"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void: settings_reset_requested.emit())
	footer.add_child(reset)
	var back := _menu_button("BACK", MUTED)
	back.name = "SettingsBackButton"
	back.custom_minimum_size.x = 150.0
	back.pressed.connect(_show_pause_main)
	footer.add_child(back)
	_settings_status_label = _label("", 10, NOMINAL_SOFT)
	_settings_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_status_label.visible = false
	page_stack.add_child(_settings_status_label)


func _settings_group(parent: VBoxContainer, title: String, detail: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("101f2e"), 6, 1, Color("27465b")))
	parent.add_child(panel)
	var margin := _margin(16, 13, 16, 14)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)
	stack.add_child(_label(title, 12, CAUTION))
	stack.add_child(_label(detail, 10, MUTED))
	return stack


func _build_input_binding_rows(parent: VBoxContainer) -> void:
	var actions := PackedStringArray()
	for action: StringName in _input_binding_profile.bindings:
		actions.append(String(action))
	actions.sort()
	for raw_action: String in actions:
		var action := StringName(raw_action)
		var row := HBoxContainer.new()
		row.name = String(action).to_pascal_case() + "BindingRow"
		row.add_theme_constant_override("separation", 6)
		parent.add_child(row)
		var action_label := _label(
			str(INPUT_ACTION_LABELS.get(action, String(action).replace("_", " ").capitalize())),
			10,
			PRIMARY
		)
		action_label.custom_minimum_size.x = 126.0
		action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(action_label)
		var binding_button := _binding_button("")
		binding_button.name = String(action).to_pascal_case() + "BindingButton"
		binding_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binding_button.pressed.connect(func() -> void: begin_input_binding_capture(action))
		binding_button.focus_entered.connect(_scroll_to_input_binding.bind(binding_button))
		row.add_child(binding_button)
		var reset_button := _binding_button("RESET")
		reset_button.name = String(action).to_pascal_case() + "BindingResetButton"
		reset_button.custom_minimum_size.x = 58.0
		reset_button.pressed.connect(func() -> void: _reset_input_action(action))
		reset_button.focus_entered.connect(_scroll_to_input_binding.bind(reset_button))
		row.add_child(reset_button)
		_binding_rows[action] = row
		_binding_buttons[action] = binding_button
		_binding_reset_buttons[action] = reset_button

	_binding_conflict_panel = PanelContainer.new()
	_binding_conflict_panel.name = "InputBindingConflictPanel"
	_binding_conflict_panel.visible = false
	_binding_conflict_panel.add_theme_stylebox_override(
		"panel",
		_border_box(Color("301820"), 4, DANGER)
	)
	parent.add_child(_binding_conflict_panel)
	var conflict_margin := _margin(10, 8, 10, 8)
	_binding_conflict_panel.add_child(conflict_margin)
	var conflict_stack := VBoxContainer.new()
	conflict_stack.add_theme_constant_override("separation", 6)
	conflict_margin.add_child(conflict_stack)
	_binding_conflict_label = _label("", 10, DANGER)
	_binding_conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	conflict_stack.add_child(_binding_conflict_label)
	var conflict_actions := HBoxContainer.new()
	conflict_actions.add_theme_constant_override("separation", 6)
	conflict_stack.add_child(conflict_actions)
	_binding_conflict_replace_button = _binding_button("REPLACE CONFLICTS")
	_binding_conflict_replace_button.name = "InputBindingConflictReplaceButton"
	_binding_conflict_replace_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_binding_conflict_replace_button.pressed.connect(_replace_pending_input_conflict)
	conflict_actions.add_child(_binding_conflict_replace_button)
	_binding_conflict_cancel_button = _binding_button("CANCEL")
	_binding_conflict_cancel_button.name = "InputBindingConflictCancelButton"
	_binding_conflict_cancel_button.pressed.connect(_cancel_pending_input_conflict)
	conflict_actions.add_child(_binding_conflict_cancel_button)

	var reset_all := _binding_button("RESET ALL BINDINGS")
	reset_all.name = "InputBindingsResetAllButton"
	reset_all.pressed.connect(_reset_all_input_bindings)
	parent.add_child(reset_all)
	_refresh_all_binding_rows()


func _scroll_to_input_binding(control: Control) -> void:
	if _settings_scroll != null:
		_settings_scroll.ensure_control_visible.call_deferred(control)


func _binding_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32.0
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 9)
	_tint_theme_color(button, &"font_color", NOMINAL_SOFT)
	_tint_theme_color(button, &"font_hover_color", PRIMARY)
	_tint_theme_color(button, &"font_focus_color", PRIMARY)
	button.add_theme_stylebox_override("normal", _box(Color("142536"), 4, 1, Color("315367")))
	button.add_theme_stylebox_override("hover", _border_box(Color("173044"), 4, NOMINAL))
	button.add_theme_stylebox_override("focus", _border_box(Color("173044"), 4, CAUTION))
	return button


## Begins one raw-event capture. It is public so controller-driven menus and
## focused regression tests can enter the same state as the row button.
func begin_input_binding_capture(action: StringName) -> bool:
	if (
		_input_binding_profile == null
		or not _input_binding_profile.bindings.has(action)
		or _settings_page == null
		or not _settings_page.visible
	):
		return false
	_cancel_pending_input_conflict()
	_binding_capture_action = action
	_refresh_all_binding_rows()
	set_settings_status(
		"LISTENING  //  %s  //  ESC CANCELS" % _input_action_label(action).to_upper(),
		true
	)
	return true


func _capture_binding_event(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.physical_keycode == KEY_ESCAPE:
			_cancel_input_binding_capture()
			_get_viewport_and_handle_input()
			return
	elif event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed:
			return
	elif event is InputEventJoypadButton:
		if not (event as InputEventJoypadButton).pressed:
			return
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) < GAMEPAD_CAPTURE_THRESHOLD:
			return
		var normalized_motion := InputEventJoypadMotion.new()
		normalized_motion.axis = motion.axis
		normalized_motion.axis_value = signf(motion.axis_value)
		event = normalized_motion
	else:
		return
	var candidate := InputRebindServiceType.event_to_binding(event)
	if candidate.is_empty():
		return
	var action := _binding_capture_action
	_binding_capture_action = &""
	_attempt_input_rebind(action, candidate)
	_get_viewport_and_handle_input()


func _attempt_input_rebind(action: StringName, candidate: Dictionary) -> void:
	var replacement_base := _profile_without_binding_family(
		_input_binding_profile,
		action,
		_binding_device_family(candidate)
	)
	var result := _input_rebind_service.rebind(
		replacement_base,
		action,
		candidate,
		InputRebindServiceType.CONFLICT_REJECT
	)
	if bool(result.get("ok", false)):
		_commit_input_binding_profile(
			result.get("profile") as InputBindingProfile,
			"BOUND  //  %s  //  %s" % [
				_input_action_label(action).to_upper(),
				_binding_text(candidate).to_upper(),
			]
		)
		return
	var conflicts := result.get("conflicts", []) as Array
	if conflicts.is_empty():
		set_settings_status("BINDING REJECTED", false)
		_refresh_all_binding_rows()
		return
	_pending_binding_conflict = {
		"action": action,
		"candidate": candidate.duplicate(true),
		"conflicts": conflicts.duplicate(true),
		"replacement_base": replacement_base,
	}
	var conflict_names := PackedStringArray()
	for conflict: Dictionary in conflicts:
		conflict_names.append(_input_action_label(StringName(conflict.action)))
	_binding_conflict_label.text = "%s is already bound to %s." % [
		_binding_text(candidate),
		", ".join(conflict_names),
	]
	_binding_conflict_panel.visible = true
	set_settings_status("CONFLICT  //  CHOOSE REPLACE OR CANCEL", false)
	_binding_conflict_replace_button.grab_focus()
	_refresh_all_binding_rows()


func _replace_pending_input_conflict() -> void:
	if _pending_binding_conflict.is_empty():
		return
	var action := StringName(_pending_binding_conflict.action)
	var candidate := (_pending_binding_conflict.candidate as Dictionary).duplicate(true)
	var replacement_base := _pending_binding_conflict.replacement_base as InputBindingProfile
	var result := _input_rebind_service.rebind(
		replacement_base,
		action,
		candidate,
		InputRebindServiceType.CONFLICT_REPLACE
	)
	if bool(result.get("ok", false)):
		_commit_input_binding_profile(
			result.get("profile") as InputBindingProfile,
			"CONFLICT REPLACED  //  %s" % _input_action_label(action).to_upper()
		)
	else:
		set_settings_status("CONFLICT REPLACEMENT FAILED", false)
	_cancel_pending_input_conflict(false)


func _cancel_pending_input_conflict(clear_status: bool = true) -> void:
	var return_action := StringName(_pending_binding_conflict.get("action", &""))
	_pending_binding_conflict.clear()
	if _binding_conflict_panel != null:
		_binding_conflict_panel.visible = false
	if clear_status:
		set_settings_status("BINDING CHANGE CANCELLED", true)
	_refresh_all_binding_rows()
	if (
		not return_action.is_empty()
		and _settings_page != null
		and _settings_page.visible
		and _binding_buttons.has(return_action)
	):
		(_binding_buttons[return_action] as Button).grab_focus()


func _cancel_input_binding_capture() -> void:
	_binding_capture_action = &""
	set_settings_status("BINDING CAPTURE CANCELLED", true)
	_refresh_all_binding_rows()


func _reset_input_action(action: StringName) -> void:
	if not _input_binding_defaults.bindings.has(action):
		return
	var updated := _input_binding_profile.duplicate_profile()
	updated.set_bindings(action, [])
	for binding: Dictionary in _input_binding_defaults.get_bindings(action):
		var result := _input_rebind_service.rebind(
			updated,
			action,
			binding,
			InputRebindServiceType.CONFLICT_REPLACE
		)
		if not bool(result.get("ok", false)):
			set_settings_status("RESET FAILED  //  %s" % _input_action_label(action).to_upper(), false)
			return
		updated = result.get("profile") as InputBindingProfile
	updated.set_action_options(action, _input_binding_defaults.get_action_options(action))
	_commit_input_binding_profile(
		updated,
		"DEFAULT RESTORED  //  %s" % _input_action_label(action).to_upper()
	)


func _reset_all_input_bindings() -> void:
	_commit_input_binding_profile(
		_input_rebind_service.reset_to_defaults(),
		"ALL INPUT BINDINGS RESTORED"
	)


func _profile_without_binding_family(
	profile: InputBindingProfile,
	action: StringName,
	family: StringName
) -> InputBindingProfile:
	var updated := profile.duplicate_profile()
	var retained: Array[Dictionary] = []
	for existing: Dictionary in updated.get_bindings(action):
		if _binding_device_family(existing) != family:
			retained.append(existing)
	updated.set_bindings(action, retained)
	return updated


func _binding_device_family(binding: Dictionary) -> StringName:
	return (
		&"gamepad"
		if StringName(binding.get("device", &"")) == InputBindingProfileType.DEVICE_GAMEPAD
		else &"desktop"
	)


func _commit_input_binding_profile(profile: InputBindingProfile, status: String) -> void:
	if (
		profile == null
		or not _input_rebind_service.is_profile_compatible_with_defaults(profile)
	):
		set_settings_status("INVALID BINDING PROFILE REJECTED", false)
		return
	_input_binding_profile = profile.duplicate_profile()
	_refresh_input_prompts()
	set_settings_status(status, true)
	setting_change_requested.emit(
		&"input_binding_profile",
		_input_binding_profile.duplicate_profile()
	)


## Observes presentation preference only. This deliberately does not mark the
## event handled: gameplay and menu focus retain their existing input authority.
## A joy axis must match a stored direction and cross that action's own deadzone
## before it can replace keyboard/mouse prompts.
func _observe_prompt_device(event: InputEvent) -> void:
	if _input_glyph_resolver == null or _input_binding_profile == null:
		return
	var previous := _input_glyph_resolver.get_preferred_device_family()
	var observed := false
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var deadzone := _matching_axis_deadzone(motion)
		if deadzone < 0.0:
			return
		if absf(motion.axis_value) <= deadzone or is_equal_approx(absf(motion.axis_value), deadzone):
			return
		observed = _input_glyph_resolver.observe_input_event(event, deadzone)
	else:
		observed = _input_glyph_resolver.observe_input_event(event)
	if (
		observed
		and previous != _input_glyph_resolver.get_preferred_device_family()
	):
		_refresh_input_prompts()


func _matching_axis_deadzone(event: InputEventJoypadMotion) -> float:
	if is_zero_approx(event.axis_value):
		return -1.0
	var matched_deadzone := 1.0
	var matched := false
	for action: StringName in _input_binding_profile.bindings:
		for binding: Dictionary in _input_binding_profile.get_bindings(action):
			if (
				StringName(binding.get("type", &"")) == &"joy_motion"
				and int(binding.get("axis", -1)) == event.axis
				and signf(float(binding.get("axis_value", 0.0))) == signf(event.axis_value)
			):
				matched = true
				matched_deadzone = minf(
					matched_deadzone,
					float(_input_binding_profile.get_action_options(action).get("deadzone", 0.18))
				)
	return clampf(matched_deadzone, 0.0, 1.0) if matched else -1.0


func _refresh_input_prompts() -> void:
	_refresh_all_binding_rows()
	if is_instance_valid(_help_panel):
		_set_help_text(_help_rows_for_mode(_state_mode))


func _refresh_all_binding_rows() -> void:
	if _input_binding_profile == null:
		return
	for action: StringName in _binding_buttons:
		var button := _binding_buttons[action] as Button
		button.text = (
			"PRESS A CONTROL..."
			if action == _binding_capture_action
			else _action_bindings_text(action)
		)


func _action_bindings_text(action: StringName) -> String:
	var resolved := _input_glyph_resolver.resolve_action(_input_binding_profile, action)
	return (
		str(resolved.get("text", "Unbound Input"))
		if bool(resolved.get("valid", false))
		else "UNBOUND  //  SELECT TO ADD"
	)


func _binding_text(binding: Dictionary) -> String:
	var resolved := _input_glyph_resolver.resolve_binding(
		binding,
		_input_glyph_resolver.get_preferred_device_family()
	)
	return str(resolved.get("text", "Unbound Input"))


func _input_action_label(action: StringName) -> String:
	return str(INPUT_ACTION_LABELS.get(action, String(action).replace("_", " ").capitalize()))


func _get_viewport_and_handle_input() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


## Detached audit snapshot for settings owners and focused UI tests.
func get_input_binding_report() -> Dictionary:
	var actions := PackedStringArray()
	var bindings := {}
	for action: StringName in _input_binding_profile.bindings:
		actions.append(String(action))
	actions.sort()
	for raw_action: String in actions:
		var action := StringName(raw_action)
		bindings[action] = _input_binding_profile.get_bindings(action)
	return {
		"actions": actions,
		"action_count": actions.size(),
		"bindings": bindings,
		"capturing_action": _binding_capture_action,
		"has_pending_conflict": not _pending_binding_conflict.is_empty(),
		"preferred_device_family": _input_glyph_resolver.get_preferred_device_family(),
	}


func _add_slider_setting(
	parent: VBoxContainer,
	key: StringName,
	title: String,
	minimum: float,
	maximum: float,
	step: float,
	initial: float
) -> void:
	var row := VBoxContainer.new()
	row.name = String(key).to_pascal_case() + "Row"
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var copy := HBoxContainer.new()
	row.add_child(copy)
	var title_label := _label(title, 11, PRIMARY)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(title_label)
	var value_label := _label("", 10, NOMINAL_SOFT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 68.0
	copy.add_child(value_label)
	var slider := HSlider.new()
	slider.name = String(key).to_pascal_case() + "Control"
	slider.custom_minimum_size.y = 18.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	var slider_track := _box(Color("29475b"), 4, 0, Color.TRANSPARENT)
	slider_track.content_margin_top = 3.0
	slider_track.content_margin_bottom = 3.0
	var slider_fill := _fill_box(NOMINAL, 4, 0.28)
	slider_fill.content_margin_top = 3.0
	slider_fill.content_margin_bottom = 3.0
	var slider_fill_highlight := _fill_box(NOMINAL, 4)
	slider_fill_highlight.content_margin_top = 3.0
	slider_fill_highlight.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("slider", slider_track)
	slider.add_theme_stylebox_override("grabber_area", slider_fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_fill_highlight)
	slider.value_changed.connect(func(value: float) -> void: _on_setting_value_changed(key, value))
	row.add_child(slider)
	_settings_controls[key] = slider
	_settings_value_labels[key] = value_label
	_update_setting_value_label(key, initial)


func _add_toggle_setting(parent: VBoxContainer, key: StringName, title: String, initial: bool) -> void:
	var toggle := CheckButton.new()
	toggle.name = String(key).to_pascal_case() + "Control"
	toggle.text = title
	toggle.button_pressed = initial
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.add_theme_font_size_override("font_size", 11)
	_tint_theme_color(toggle, &"font_color", PRIMARY)
	_tint_theme_color(toggle, &"font_hover_color", NOMINAL_SOFT)
	toggle.toggled.connect(func(value: bool) -> void: _on_setting_value_changed(key, value))
	parent.add_child(toggle)
	_settings_controls[key] = toggle


func _add_option_setting(
	parent: VBoxContainer,
	key: StringName,
	title: String,
	options: Array,
	initial: int
) -> void:
	var row := VBoxContainer.new()
	row.name = String(key).to_pascal_case() + "Row"
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	row.add_child(_label(title, 11, PRIMARY))
	var selector := OptionButton.new()
	selector.name = String(key).to_pascal_case() + "Control"
	selector.custom_minimum_size.y = 38.0
	selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	selector.add_theme_font_size_override("font_size", 11)
	_tint_theme_color(selector, &"font_color", PRIMARY)
	selector.add_theme_stylebox_override("normal", _box(Color("142536"), 4, 1, Color("315367")))
	selector.add_theme_stylebox_override("hover", _border_box(Color("173044"), 4, NOMINAL))
	for option: Variant in options:
		selector.add_item(str(option))
	selector.select(initial)
	selector.item_selected.connect(func(index: int) -> void: _on_setting_value_changed(key, index))
	row.add_child(selector)
	_settings_controls[key] = selector


func _on_setting_value_changed(key: StringName, value: Variant) -> void:
	if value is float:
		_update_setting_value_label(key, float(value))
	if not _updating_settings:
		setting_change_requested.emit(key, value)


func _update_setting_value_label(key: StringName, value: float) -> void:
	if not _settings_value_labels.has(key):
		return
	var value_label := _settings_value_labels[key] as Label
	match key:
		&"ship_mouse_sensitivity":
			value_label.text = "%d%%" % roundi(value / 0.0022 * 100.0)
		&"on_foot_mouse_sensitivity":
			value_label.text = "%d%%" % roundi(value / 0.0025 * 100.0)
		&"camera_fov":
			value_label.text = "%d°" % roundi(value)
		_:
			value_label.text = "%d%%" % roundi(value * 100.0)


func _show_settings_page() -> void:
	_pause_main_page.visible = false
	_settings_page.visible = true
	var first_control := _settings_controls.get(&"ship_mouse_sensitivity") as Control
	if first_control != null:
		first_control.grab_focus()


func _show_pause_main() -> void:
	if _pause_main_page == null or _settings_page == null:
		return
	_binding_capture_action = &""
	_cancel_pending_input_conflict(false)
	_pause_main_page.visible = true
	_settings_page.visible = false
	var settings_button := _pause_main_page.find_child("SettingsOpenButton", true, false) as Button
	if _pause.visible and settings_button != null:
		settings_button.grab_focus()


func _set_help_text(rows: Array) -> void:
	for child in _help_panel.get_children():
		child.queue_free()
	var margin := _margin(16, 14, 16, 14)
	_help_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	var heading := _label(
		"CONTROLS  //  %s" % _action_prompts([&"toggle_controls_overlay"]),
		11,
		CAUTION
	)
	stack.add_child(heading)
	for row: Array in rows:
		var line := HBoxContainer.new()
		var key := _label(str(row[0]), 11, NOMINAL_SOFT)
		key.custom_minimum_size.x = 92.0
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(key)
		var detail := _label(str(row[1]), 10, MUTED)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(detail)
		stack.add_child(line)
	_set_mouse_passthrough(_help_panel)


func _label(text: String, size: int, role: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	_tint_theme_color(label, &"font_color", role)
	return label


## Resolves a semantic role to the colour of the active palette.
func _c(role: StringName) -> Color:
	return _palette.get(role, _palette[PaletteType.ROLE_PRIMARY]) as Color


func _damage_status_color(damage_status: String) -> Color:
	if damage_status == "CRITICAL":
		return _c(DANGER)
	return _c(CAUTION) if damage_status == "DAMAGED" else _c(MUTED)


func _register_palette_target(entry: Dictionary) -> void:
	_palette_targets.append(entry)
	_apply_palette_target(entry)


func _tint_theme_color(node: Control, property: StringName, role: StringName) -> void:
	_register_palette_target({"kind": &"theme_color", "node": node, "property": property, "role": role})


func _tint_rect(rect: ColorRect, role: StringName) -> void:
	_register_palette_target({"kind": &"rect", "node": rect, "role": role})


func _fill_box(role: StringName, radius: int, darken := 0.0) -> StyleBoxFlat:
	var box := _box(Color.TRANSPARENT, radius, 0, Color.TRANSPARENT)
	_register_palette_target({"kind": &"box_fill", "box": box, "role": role, "darken": darken})
	return box


func _border_box(fill: Color, radius: int, role: StringName) -> StyleBoxFlat:
	var box := _box(fill, radius, 1, Color.TRANSPARENT)
	_register_palette_target({"kind": &"box_border", "box": box, "role": role, "darken": 0.0})
	return box


## Repaints one registered element. Returns false when the target no longer
## exists, which is how retired help-panel labels leave the registry.
func _apply_palette_target(entry: Dictionary) -> bool:
	var role := StringName(entry.get("role", PRIMARY))
	var color := _c(role)
	var darken := float(entry.get("darken", 0.0))
	if darken > 0.0:
		color = color.darkened(darken)
	match StringName(entry.get("kind", &"")):
		&"theme_color":
			var raw_node: Variant = entry.get("node")
			if not is_instance_valid(raw_node):
				return false
			(raw_node as Control).add_theme_color_override(String(entry["property"]), color)
			return true
		&"rect":
			var raw_rect: Variant = entry.get("node")
			if not is_instance_valid(raw_rect):
				return false
			(raw_rect as ColorRect).color = color
			return true
		&"box_fill":
			var fill_box := entry.get("box") as StyleBoxFlat
			if fill_box == null:
				return false
			fill_box.bg_color = color
			return true
		&"box_border":
			var border_box := entry.get("box") as StyleBoxFlat
			if border_box == null:
				return false
			border_box.border_color = color
			return true
	return false


func _box(color: Color, radius: int, border_width: int, border_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.border_color = border_color
	return box


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _bar(role: StringName) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 8.0)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box(Color("213444"), 3, 0, Color.TRANSPARENT))
	bar.add_theme_stylebox_override("fill", _fill_box(role, 3))
	return bar


func _menu_button(text: String, role: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	_tint_theme_color(button, &"font_color", PRIMARY)
	button.add_theme_stylebox_override("normal", _box(Color("142536"), 4, 1, Color("315367")))
	var hover := _fill_box(role, 4, 0.55)
	hover.border_width_left = 1
	hover.border_width_top = 1
	hover.border_width_right = 1
	hover.border_width_bottom = 1
	_register_palette_target({"kind": &"box_border", "box": hover, "role": role, "darken": 0.0})
	var pressed := _fill_box(role, 4, 0.35)
	pressed.border_width_left = 1
	pressed.border_width_top = 1
	pressed.border_width_right = 1
	pressed.border_width_bottom = 1
	_register_palette_target({"kind": &"box_border", "box": pressed, "role": role, "darken": 0.0})
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _set_mouse_passthrough(control: Control) -> void:
	# Gameplay look/steer is handled through `_unhandled_input`; non-interactive
	# HUD controls must never consume motion or fire clicks before they reach it.
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_set_mouse_passthrough(child as Control)
