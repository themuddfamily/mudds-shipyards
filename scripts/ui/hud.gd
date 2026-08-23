class_name GameHUD
extends CanvasLayer

const FlightPathCueType := preload("res://scripts/ui/flight_path_cue.gd")
const PaletteType := preload("res://scripts/ui/hud_palette.gd")
const InputBindingProfileType := preload("res://scripts/settings/input_binding_profile.gd")
const InputRebindServiceType := preload("res://scripts/settings/input_rebind_service.gd")
const RuntimeInputRemappingControllerType := preload("res://scripts/settings/runtime_input_remapping_controller.gd")
const RuntimeInputRemappingPresenterType := preload("res://scripts/ui/runtime_input_remapping_presenter.gd")
const RuntimeInputRebindPresenterType := preload("res://scripts/ui/runtime_input_rebind_presenter.gd")
const InputGlyphResolverType := preload("res://scripts/ui/input_glyph_resolver.gd")
const RuntimeInputGlyphPresenterType := preload("res://scripts/ui/runtime_input_glyph_presenter.gd")
const UltrawideSafeAreaContractType := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")
const CaptionPresenterScene := preload("res://scenes/ui/caption_presenter.tscn")
const DebugOverlayType := preload("res://scripts/ui/debug_overlay.gd")
const MinimapType := preload("res://scripts/ui/minimap.gd")
const NetworkSessionStatusPresenterType := preload("res://scripts/ui/network_session_status_presenter.gd")
const CrewRoleSeatPresenterType := preload("res://scripts/ui/crew_role_seat_presenter.gd")
const SurfaceRouteHazardPresenterType := preload("res://scripts/ui/surface_route_hazard_presenter.gd")
const AtmosphericEntryGuidancePresenterType := preload("res://scripts/ui/atmospheric_entry_guidance_presenter.gd")
const SemanticAudioCuePresenterType := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")
const FirstSortieTutorialPresenterType := preload("res://scripts/ui/first_sortie_tutorial_presenter.gd")
const ServerBrowserPresenterType := preload("res://scripts/ui/server_browser_presenter.gd")
const NearbySectorActivityPresenterType := preload("res://scripts/ui/nearby_sector_activity_presenter.gd")

signal start_requested
signal restart_requested
signal activity_selection_requested(activity_kind: StringName)
signal planetary_cruise_toggle_requested(request_serial: int)
signal setting_change_requested(key: StringName, value: Variant)
signal settings_save_requested
signal settings_reset_requested
signal orderly_shutdown_requested
signal presentation_intent_requested(kind: StringName, payload: Dictionary)
signal nearby_activity_intent_requested(intent: Dictionary)

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
const CAPTION_CUES := {
	&"ui_confirm": [&"system", "Interface", "[ interface confirm ]", 30],
	&"impact": [&"ambient", "Hull sensors", "[ hull impact ]", 65],
	&"target_destroyed": [&"system", "Range control", "[ range target destroyed ]", 60],
	&"combat_alert": [&"system", "Threat warning", "[ combat alert ]", 90],
	&"canopy_open": [&"ambient", "Canopy", "[ canopy opening ]", 40],
	&"canopy_close": [&"ambient", "Canopy", "[ canopy closing ]", 40],
	&"enemy_destroyed": [&"system", "Combat computer", "[ hostile craft destroyed ]", 90],
	&"player_pulse_fire": [&"ambient", "Weapon audio", "[ pulse cannon fires ]", 45],
	&"defender_pulse_fire": [&"ambient", "Threat audio", "[ hostile pulse fire ]", 70],
	&"dry_fire_click": [&"ambient", "Weapon audio", "[ weapon dry click ]", 55],
	&"crew_role_joined": [&"system", "Crew status", "[ crew role joined ]", 45],
	&"crew_role_left": [&"system", "Crew status", "[ crew role left ]", 60],
	&"crew_engineer_route_changed": [&"system", "Crew status", "[ engineer power route changed ]", 65],
	&"crew_departure_ready": [&"system", "Crew status", "[ crew departure ready ]", 70],
	&"crew_emergency_handoff": [&"system", "Crew status", "[ emergency pilot handoff ]", 90],
	&"crew_emergency_pilot_handoff": [&"system", "Crew status", "[ emergency pilot handoff ]", 90],
	&"hull_impact_light": [&"ambient", "Hull sensors", "[ light hull impact ]", 65],
	&"hull_impact_medium": [&"ambient", "Hull sensors", "[ hull impact ]", 75],
	&"hull_impact_heavy": [&"ambient", "Hull sensors", "[ heavy hull impact ]", 85],
	&"ship_explosion": [&"ambient", "Combat audio", "[ ship explosion ]", 90],
	&"engine_damage_alarm": [&"system", "Engine monitor", "[ engine damage alarm ]", 95],
	&"engine_damage_alarm_cleared": [&"system", "Engine monitor", "[ engine damage alarm cleared ]", 45],
	&"ship_landing_contact": [&"ambient", "Landing sensors", "[ landing contact ]", 70],
	&"station_machinery_available": [&"system", "Station machinery", "[ station machinery available ]", 45],
	&"station_machinery_offline": [&"system", "Station machinery", "[ station machinery offline ]", 85],
	&"boarding_confirmed": [&"system", "Boarding computer", "[ boarding confirmed ]", 55],
	&"disembark_confirmed": [&"system", "Boarding computer", "[ disembark confirmed ]", 55],
	&"surface_entry_severe": [&"system", "Entry guidance", "[ severe surface entry ]", 95],
	&"surface_entry_clear": [&"system", "Entry guidance", "[ surface entry clear ]", 45],
	&"surface_touchdown": [&"system", "Surface guidance", "[ surface touchdown ]", 70],
	&"surface_departure": [&"system", "Surface guidance", "[ surface departure ]", 70],
	&"ship_destroyed": [&"system", "Damage control", "[ ship destroyed ]", 100],
	&"ship_audio_recovery_ready": [&"system", "Audio recovery", "[ ship audio recovery ready ]", 50],
	&"station_service_servo": [&"ambient", "Station service", "[ station service servo ]", 40],
	&"station_service_latch": [&"system", "Station service", "[ station service latch ]", 65],
	&"target_lock_acquired": [&"system", "Targeting computer", "[ target lock acquired ]", 75],
	&"target_lock_lost": [&"system", "Targeting computer", "[ target lock lost ]", 50],
	&"weapon_not_ready": [&"system", "Weapons computer", "[ weapon not ready ]", 70],
	&"weapon_ready": [&"system", "Weapons computer", "[ weapon ready ]", 45],
	&"engine_started": [&"system", "Engine monitor", "[ engine started ]", 45],
	&"engine_stopped": [&"system", "Engine monitor", "[ engine stopped ]", 70],
	&"boost_engaged": [&"system", "Flight computer", "[ boost engaged ]", 70],
	&"boost_released": [&"system", "Flight computer", "[ boost released ]", 45],
	&"thrust_load_engaged": [&"system", "Flight computer", "[ thrust load engaged ]", 70],
	&"thrust_load_released": [&"system", "Flight computer", "[ thrust load released ]", 45],
	&"activity_selected": [&"system", "Activity board", "[ {activity} selected ]", 45],
	&"activity_started": [&"system", "Activity board", "[ {activity} started ]", 60],
	&"activity_checkpoint": [&"system", "Activity board", "[ {activity} checkpoint reached ]", 65],
	&"activity_progress": [&"system", "Activity board", "[ {activity} progress updated ]", 50],
	&"activity_complete": [&"system", "Activity board", "[ {activity} complete ]", 75],
	&"activity_reward_pending": [&"system", "Activity board", "[ {activity} reward pending ]", 70],
	&"activity_reset": [&"system", "Activity board", "[ {activity} reset ]", 45],
}

const CAPTION_DURATION_PHYSICS_SECONDS := 3.4
## The bottom band already occupied by interaction and telemetry. The presenter
## receives this in final viewport pixels after the HUD scale ceiling resolves.
const CAPTION_BOTTOM_SAFE_LOGICAL := 272.0
## Gutter exclusions keep the wide presenter between objectives on the left and
## controls/telemetry on the right. Its own safe margins sit inside this host.
const CAPTION_HOST_LEFT_LOGICAL := PANEL_LEFT_COLUMN_WIDTH + PANEL_MARGIN
const CAPTION_HOST_RIGHT_LOGICAL := PANEL_TELEMETRY_WIDTH + PANEL_MARGIN

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
const MAX_PLANETARY_CRUISE_TOGGLE_SERIAL := 9_007_199_254_740_991
const PLANETARY_CRUISE_STATUS_IDS := [
	&"ready",
	&"queued",
	&"accelerating",
	&"cruising",
	&"braking_to_speed",
	&"braking",
	&"unavailable",
]
const PLANETARY_CRUISE_UNAVAILABLE_TEXTS := [
	"UNAVAILABLE — SYSTEM OFFLINE",
	"UNAVAILABLE — NO ACTIVE SHIP",
	"UNAVAILABLE — SHIP DESTROYED",
	"UNAVAILABLE — PILOT REQUIRED",
	"UNAVAILABLE — LANDING ACTIVE",
	"UNAVAILABLE — COMBAT ACTIVE",
	"UNAVAILABLE — SHIP RECOVERY",
	"UNAVAILABLE — DEPART SHIPYARD",
	"UNAVAILABLE — ACTIVITY RUNNING",
	"UNAVAILABLE — NAVIGATION OFFLINE",
	"UNAVAILABLE — ORIGIN SHIFT PENDING",
	"UNAVAILABLE — NOT AVAILABLE",
]

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
const SCREENSHOT_ACTION: StringName = &"capture_screenshot"
const DEBUG_OVERLAY_KEY := KEY_F3
const SCREENSHOT_DIRECTORY_URI := "user://screenshots"
const SCREENSHOT_FILE_PREFIX := "mudds_shipyards_"
const SCREENSHOT_MAX_COLLISION_SUFFIX := 999

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
var _debug_overlay: DebugOverlay
var _minimap: Minimap
var _intro: Control
var _hud: Control
var _hud_panels: Control
var _pause: Control
var _pause_panels: Control
var _pause_main_page: Control
var _activity_selection_page: Control
var _server_browser_page: Control
var _server_browser_title: Label
var _server_browser_detail: Label
var _server_browser_feedback: Label
var _server_browser_address: LineEdit
var _server_browser_port: LineEdit
var _server_browser_player_name: LineEdit
var _server_browser_rows: VBoxContainer
var _server_browser_actions: HBoxContainer
var _activity_selection_buttons: Dictionary = {}
var _activity_selection_status_label: Label
var _activity_selection_kind: StringName = &"timed_race"
var _activity_selection_locked := false
var _nearby_activity_presenter: RefCounted
var _nearby_activity_page: Control
var _nearby_activity_rows: VBoxContainer
var _nearby_activity_feedback: Label
var _nearby_activity_snapshot: Dictionary = {}
var _planetary_cruise_button: Button
var _planetary_cruise_status_label: Label
var _planetary_cruise_status_id: StringName = &"unavailable"
var _planetary_cruise_status_text := "UNAVAILABLE — SYSTEM OFFLINE"
var _planetary_cruise_toggle_enabled := false
var _planetary_cruise_engagement_requested := false
var _planetary_cruise_toggle_serial := 0
var _planetary_cruise_request_dispatch_active := false
var _settings_page: Control
var _settings_scroll: ScrollContainer
var _settings_controls: Dictionary = {}
var _settings_value_labels: Dictionary = {}
const _CONTROLLER_GLYPH_FAMILY_KEY := &"controller_glyph_family"
var _settings_status_label: Label
var _settings_dirty := false
var _settings_reset_confirmation: PanelContainer
## The pause overlay survives a whole-Main detach, but Viewport focus does not.
## Retain the exact in-overlay target so controller users return to the same
## reachable control instead of an open page with no GUI focus owner.
var _pause_reentry_focus_target: Control
var _updating_settings := false
var _input_rebind_service: InputRebindService
var _input_remapping_controller: RuntimeInputRemappingController
var _input_remapping_presenter: RuntimeInputRemappingPresenter
var _runtime_input_rebind_presenter: RefCounted
var _input_binding_profile: InputBindingProfile
var _input_binding_defaults: InputBindingProfile
var _input_glyph_resolver: InputGlyphResolver
var _runtime_input_glyph_presenter
var _safe_area_insets := Rect2()
var _binding_rows: Dictionary = {}
var _binding_buttons: Dictionary = {}
var _binding_reset_buttons: Dictionary = {}
var _binding_option_controls: Dictionary = {}
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
var _help_margin: MarginContainer
var _help_stack: VBoxContainer
var _help_heading: Label
## Stable row controls reused when mode, device family, or binding text changes.
## Re-entry reapplies an unchanged snapshot, so rebuilding these nodes there
## would violate whole-Main identity even though the displayed copy is the same.
var _help_row_controls: Array[Dictionary] = []
var _reticle: Control
var _reticle_state_label: Label
var _reticle_state: StringName = &"searching"
var _flight_cue_layer: FlightPathCue
var _toast_serial := 0
var _toast_tween: Tween
## A focused suite supplies a tiny CPU image here so it can prove the complete
## F2-to-file path without depending on a GPU-backed test viewport. Production
## always reads the actual viewport texture below.
var _screenshot_image_provider_for_test := Callable()
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
var _caption_preview_revision := 0
## Containers whose contents scale with the UI-scale preference. The reticle,
## flight-path cue, and damage flash are deliberately excluded: they are
## registered against camera-space pixels and must stay 1:1 with the viewport.
var _scaled_layers: Array[Control] = []
var _layout_effective_ui_scale := 1.0
var _caption_presenter: CaptionPresenter
var _network_status_presenter := NetworkSessionStatusPresenterType.new()
var _crew_role_presenter := CrewRoleSeatPresenterType.new()
var _surface_route_presenter := SurfaceRouteHazardPresenterType.new()
var _entry_guidance_presenter := AtmosphericEntryGuidancePresenterType.new()
var _semantic_audio_cue_presenter := SemanticAudioCuePresenterType.new()
var _first_sortie_tutorial_presenter := FirstSortieTutorialPresenterType.new()
var _server_browser_presenter := ServerBrowserPresenterType.new()
var _runtime_status_panel: PanelContainer
var _runtime_status_title: Label
var _runtime_status_detail: Label
var _runtime_status_rows: VBoxContainer
var _runtime_status_actions: HBoxContainer
## Request-only route into the GameFlow-owned service. The HUD stores no queue,
## timer, event ID, or parallel visible-caption state.
var _caption_event_submitter := Callable()
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
	"activity_kind": &"",
	"display_name": "",
	"state": TimedCheckpointRace.State.IDLE,
	"state_id": &"idle",
	"generation": 0,
	"session_generation": 0,
	"activity_generation": 0,
	"race_generation": 0,
	"lap_number": 0,
	"lap_count": 0,
	"next_checkpoint_index": 0,
	"checkpoint_count": 0,
	"countdown_remaining_seconds": 0.0,
	"current_time_seconds": 0.0,
	"last_time_seconds": -1.0,
	"best_time_seconds": -1.0,
	"penalty_seconds": 0.0,
	"failure_reason": &"",
	"phase_id": &"idle",
	"completed_checkpoint_count": 0,
	"dwell_remaining_seconds": 0.0,
	"terminal_reason": &"",
	"deadline_remaining_seconds": 0.0,
	"quantity": 0,
	"item_id": &"",
	"item_display_name": "",
	"text": "",
}


func _enter_tree() -> void:
	# `_ready()` is not called when the retained Main subtree re-enters. Defer
	# until every pause-page descendant is back in the tree before reclaiming the
	# focus that the Viewport necessarily dropped during detach.
	if _pause != null:
		call_deferred("_restore_pause_focus_after_reentry")


func _exit_tree() -> void:
	clear_nearby_activity_snapshot()
	if _pause == null or not _pause.visible:
		return
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	if is_instance_valid(focus_owner) and is_ancestor_of(focus_owner):
		_pause_reentry_focus_target = focus_owner


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_nearby_activity_presenter = NearbySectorActivityPresenterType.new()
	_caption_presenter = get_node_or_null(^"CaptionPresenter") as CaptionPresenter
	if not is_instance_valid(_caption_presenter):
		_caption_presenter = CaptionPresenterScene.instantiate() as CaptionPresenter
		_caption_presenter.name = "CaptionPresenter"
		add_child(_caption_presenter)
	_input_rebind_service = InputRebindServiceType.new()
	_input_binding_defaults = _input_rebind_service.get_defaults()
	_input_binding_profile = _input_binding_defaults.duplicate_profile()
	_input_glyph_resolver = InputGlyphResolverType.new()
	_runtime_input_glyph_presenter = RuntimeInputGlyphPresenterType.new(_input_glyph_resolver)
	_runtime_input_glyph_presenter.attach(_input_binding_profile)
	_rebuild_input_remapping_presenter(_input_binding_defaults, _input_binding_profile)
	_runtime_input_rebind_presenter = RuntimeInputRebindPresenterType.new(
		_input_rebind_service,
		_input_glyph_resolver
	)
	_runtime_input_rebind_presenter.attach(_input_binding_profile)
	_build_interface()
	set_process_input(true)
	set_process_unhandled_input(true)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_apply_ui_scale):
		viewport.size_changed.connect(_apply_ui_scale)
	if viewport != null and not viewport.gui_focus_changed.is_connected(
		_on_viewport_gui_focus_changed
	):
		viewport.gui_focus_changed.connect(_on_viewport_gui_focus_changed)


func _on_viewport_gui_focus_changed(control: Control) -> void:
	# The Viewport emits `null` when detaching the focused subtree. Retain the
	# last valid in-overlay target across that clear so `_enter_tree()` can return
	# controller navigation to the exact row rather than merely reopening a page.
	if (
		_pause != null
		and _pause.visible
		and is_instance_valid(control)
		and is_ancestor_of(control)
	):
		_pause_reentry_focus_target = control


func _input(event: InputEvent) -> void:
	_observe_prompt_device(event)


func _unhandled_input(event: InputEvent) -> void:
	if not _binding_capture_action.is_empty():
		_capture_binding_event(event)
		return
	if _started and _is_debug_overlay_toggle_event(event):
		_debug_overlay.visible = not _debug_overlay.visible
		if _debug_overlay.visible:
			_refresh_debug_overlay_from_host()
		get_viewport().set_input_as_handled()
		return
	if _is_screenshot_capture_event(event):
		if is_debug_overlay_visible():
			_refresh_debug_overlay_from_host()
		_capture_screenshot()
		get_viewport().set_input_as_handled()
		return
	if not _started and (event.is_action_pressed("interact") or event.is_action_pressed("jump")):
		_begin()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and _started:
		if (
			_pause.visible
			and (
				(_settings_page != null and _settings_page.visible)
				or (
					_activity_selection_page != null
					and _activity_selection_page.visible
				)
			)
		):
			_show_pause_main()
		else:
			set_paused(not _pause.visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_controls_overlay") and _started:
		# One InputMap action now owns the overlay so `F1` and the gamepad Back
		# button reach the identical toggle. `is_action_pressed()` still rejects
		# key repeats, so the previous physical-`F1` behaviour is unchanged.
		_help_panel.visible = not _help_panel.visible


func _is_screenshot_capture_event(event: InputEvent) -> bool:
	if not event.is_action_pressed(SCREENSHOT_ACTION):
		return false
	return not (event is InputEventKey and (event as InputEventKey).echo)


func _is_debug_overlay_toggle_event(event: InputEvent) -> bool:
	if event is not InputEventKey:
		return false
	var key_event := event as InputEventKey
	return (
		key_event.pressed
		and not key_event.echo
		and (
			key_event.physical_keycode == DEBUG_OVERLAY_KEY
			or (key_event.physical_keycode == 0 and key_event.keycode == DEBUG_OVERLAY_KEY)
		)
	)


func is_debug_overlay_visible() -> bool:
	return is_instance_valid(_debug_overlay) and _debug_overlay.visible


func update_debug_overlay(snapshot: Dictionary) -> void:
	if not is_debug_overlay_visible():
		return
	_debug_overlay.present(snapshot)


func get_debug_overlay_report() -> Dictionary:
	if not is_instance_valid(_debug_overlay):
		return {
			"schema_version": DebugOverlay.SCHEMA_VERSION,
			"visible": false,
			"mouse_passthrough": true,
			"text": "",
			"snapshot": {},
		}
	return _debug_overlay.get_report()


## Presentation-only map input. GameFlow remains the sole owner of live actor,
## contact, and topology observations; the HUD retains only the detached,
## validated snapshot that the custom-drawn minimap accepted.
func update_minimap(snapshot: Dictionary) -> bool:
	if not is_instance_valid(_minimap):
		return false
	return _minimap.apply_snapshot(snapshot)


## Caller-owned route and landing guidance is rendered inside the minimap's
## already safe-area-adjusted surface. The minimap returns the detached record
## so controller/UI callers can mirror the same readable marker text.
func update_offscreen_route_marker(
	direction: Vector2, distance_m: float, route_kind: StringName, reduced_motion := false
) -> Dictionary:
	if not is_instance_valid(_minimap):
		return {"accepted": false, "reason": &"minimap_unavailable"}
	return _minimap.present_offscreen_route_marker(
		direction, distance_m, route_kind, reduced_motion or _reduced_motion
	)


func clear_offscreen_route_marker() -> void:
	if is_instance_valid(_minimap):
		_minimap.clear_offscreen_route_marker()


func get_offscreen_route_marker() -> Dictionary:
	if not is_instance_valid(_minimap):
		return {}
	return _minimap.get_offscreen_route_marker()


func get_minimap_report() -> Dictionary:
	if not is_instance_valid(_minimap):
		return {
			"schema_version": Minimap.SNAPSHOT_SCHEMA_VERSION,
			"valid": false,
			"visible": false,
			"errors": PackedStringArray(["minimap is unavailable"]),
		}
	return _minimap.get_audit_report()


func _refresh_debug_overlay_from_host() -> void:
	var host := get_parent()
	if host != null and host.has_method(&"get_debug_overlay_snapshot"):
		update_debug_overlay(host.call(&"get_debug_overlay_snapshot") as Dictionary)


## Captures after the current frame has drawn, which makes the saved image the
## actual player viewport rather than a pre-render UI tree snapshot. The toast
## follows the write so it confirms the result without appearing in its own PNG.
func _capture_screenshot() -> void:
	# A test-supplied CPU image bypasses the renderer-only post-draw signal. The
	# production route always waits for that signal before reading its viewport.
	if not _screenshot_image_provider_for_test.is_valid():
		await RenderingServer.frame_post_draw
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var image := _capture_screenshot_image()
	var result := _save_screenshot_image(image)
	_show_screenshot_capture_result(result)


func _capture_screenshot_image() -> Image:
	if _screenshot_image_provider_for_test.is_valid():
		var supplied: Variant = _screenshot_image_provider_for_test.call()
		return supplied as Image if supplied is Image else null
	var viewport := get_viewport()
	if viewport == null:
		return null
	var texture := viewport.get_texture()
	return texture.get_image() if texture != null else null


func _save_screenshot_image(image: Image) -> Dictionary:
	if image == null or image.is_empty():
		return {"accepted": false, "detail": "Viewport image is unavailable."}
	var directory := ProjectSettings.globalize_path(SCREENSHOT_DIRECTORY_URI)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		return {
			"accepted": false,
			"detail": "Could not create %s (%s)." % [directory, error_string(directory_error)],
		}
	var path := _next_screenshot_path(directory)
	if path.is_empty():
		return {
			"accepted": false,
			"detail": "No collision-safe filename is available in %s." % directory,
		}
	var save_error := image.save_png(path)
	if save_error != OK:
		return {
			"accepted": false,
			"detail": "Could not save %s (%s)." % [path, error_string(save_error)],
		}
	return {"accepted": true, "path": path}


func _next_screenshot_path(directory: String) -> String:
	var now := Time.get_datetime_dict_from_system()
	var stamp := "%04d-%02d-%02d_%02d-%02d-%02d_%03d" % [
		int(now.get("year", 0)), int(now.get("month", 0)), int(now.get("day", 0)),
		int(now.get("hour", 0)), int(now.get("minute", 0)), int(now.get("second", 0)),
		int(Time.get_ticks_msec() % 1000),
	]
	for suffix in range(SCREENSHOT_MAX_COLLISION_SUFFIX + 1):
		var collision_suffix := "" if suffix == 0 else "_%03d" % suffix
		var path := "%s/%s%s%s.png" % [
			directory, SCREENSHOT_FILE_PREFIX, stamp, collision_suffix,
		]
		if not FileAccess.file_exists(path):
			return path
	return ""


func _show_screenshot_capture_result(result: Dictionary) -> void:
	if bool(result.get("accepted", false)):
		toast("Screenshot saved", str(result.get("path", "")), 5.0)
		return
	toast("Screenshot failed", str(result.get("detail", "Unknown capture failure.")), 5.0)


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
	if not is_inside_tree() or is_queued_for_deletion():
		return
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
		var resolved: Dictionary = _runtime_input_glyph_presenter.resolve_action(action)
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


## Consumes the session's detached snapshot as presentation only. The HUD never
## starts, advances, fails, resets, or rewards an activity. Legacy director
## snapshots remain readable for isolated HUD callers while production uses the
## timed state ids below.
func set_activity_objective(display_name: String, snapshot: Dictionary) -> void:
	var activity_id := StringName(snapshot.get("activity_id", &""))
	var activity_kind := StringName(snapshot.get("activity_kind", &""))
	var state := int(snapshot.get("state", CheckpointRouteActivity.State.IDLE))
	var state_id := StringName(snapshot.get("state_id", &""))
	var phase_id := StringName(snapshot.get("phase_id", &"idle"))
	var session_generation := int(snapshot.get("session_generation", snapshot.get("generation", 0)))
	var activity_generation := int(snapshot.get("activity_generation", session_generation))
	var race_generation := int(snapshot.get("race_generation", session_generation))
	var lap_number := maxi(int(snapshot.get("lap_number", 0)), 0)
	var lap_count := maxi(int(snapshot.get("lap_count", 0)), 0)
	var next_index := maxi(int(snapshot.get("next_checkpoint_index", 0)), 0)
	var checkpoint_count := maxi(int(snapshot.get("checkpoint_count", 0)), 0)
	var countdown_remaining := maxf(float(snapshot.get("countdown_remaining_seconds", 0.0)), 0.0)
	var current_time := float(snapshot.get("current_time_seconds", 0.0))
	var last_time := float(snapshot.get("last_time_seconds", -1.0))
	var best_time := float(snapshot.get("best_time_seconds", -1.0))
	var penalty := maxf(float(snapshot.get("penalty_seconds", 0.0)), 0.0)
	var failure_reason := StringName(snapshot.get("failure_reason", &""))
	var terminal_reason := StringName(snapshot.get("terminal_reason", failure_reason))
	var completed_checkpoints := maxi(
		int(snapshot.get("completed_checkpoint_count", 0)), 0
	)
	var dwell_remaining := maxf(
		float(snapshot.get("dwell_remaining_seconds", 0.0)), 0.0
	)
	var last_duration := float(snapshot.get("last_duration_seconds", -1.0))
	var deadline_remaining := maxf(
		float(snapshot.get("deadline_remaining_seconds", 0.0)), 0.0
	)
	var quantity := maxi(int(snapshot.get("quantity", 0)), 0)
	var item_id := StringName(snapshot.get("item_id", &""))
	var item_display_name := str(snapshot.get("item_display_name", "")).strip_edges()
	var escort_distance := float(snapshot.get("escort_distance", -1.0))
	var activation_distance := float(snapshot.get("activation_distance", -1.0))
	var terminal_result_id := StringName(snapshot.get("terminal_result_id", &"none"))
	var short_name := display_name.strip_edges().to_upper()
	if short_name.is_empty():
		short_name = str(activity_id).replace("_", " ").to_upper()
	var activity_text := ""
	if activity_kind == &"convoy_escort":
		match state_id:
			&"idle":
				activity_text = "CONVOY  RENDEZVOUS %s  SAFE LANE +20M" % (
					"%.0fm" % activation_distance if activation_distance >= 0.0 else "--"
				)
			&"active":
				activity_text = "CONVOY  L%d/%d  %s  %s" % [
					mini(next_index + 1, checkpoint_count),
					checkpoint_count,
					"%.0fm" % escort_distance if escort_distance >= 0.0 else "--",
					_format_activity_time(current_time),
				]
			&"completed":
				activity_text = "CONVOY  ARRIVED  %s  %d/%d" % [
					_format_activity_time(current_time),
					completed_checkpoints,
					checkpoint_count,
				]
			&"failed", &"aborted":
				var readable_reason := str(terminal_reason).replace("_", " ").to_upper()
				activity_text = "CONVOY  %s%s  %d/%d" % [
					"LOST" if state_id == &"failed" else "ABORTED",
					(" — " + readable_reason) if not readable_reason.is_empty() else "",
					completed_checkpoints,
					checkpoint_count,
				]
			_:
				activity_text = ""
	elif activity_kind == &"cargo_delivery":
		match state_id:
			&"active":
				activity_text = "DELIVERY  %s  %d/%d  %s LEFT" % [
					"OUTBOUND" if phase_id == &"outbound" else "RETURN",
					mini(completed_checkpoints, checkpoint_count),
					checkpoint_count,
					_format_activity_time(deadline_remaining),
				]
			&"completed":
				activity_text = "DELIVERY  COMPLETE  %d %s" % [
					quantity,
					(
						item_display_name.to_upper()
						if not item_display_name.is_empty()
						else str(item_id).replace("_", " ").to_upper()
					),
				]
			&"failed", &"expired":
				var readable_reason := str(terminal_reason).replace("_", " ").to_upper()
				activity_text = "DELIVERY  %s%s" % [
					"EXPIRED" if state_id == &"expired" else "FAILED",
					(" — " + readable_reason) if not readable_reason.is_empty() else "",
				]
			_:
				activity_text = ""
	elif activity_kind == &"patrol":
		var gate_number := mini(next_index + 1, checkpoint_count)
		match state_id:
			&"active":
				if phase_id == &"dwell":
					activity_text = "PATROL  DWELL G%d/%d  HOLD %s" % [
						gate_number,
						checkpoint_count,
						_format_activity_time(dwell_remaining),
					]
				else:
					activity_text = "PATROL  TRAVEL G%d/%d  %s" % [
						gate_number,
						checkpoint_count,
						_format_activity_time(current_time),
					]
			&"completed":
				activity_text = "PATROL  COMPLETE %d/%d  %s" % [
					completed_checkpoints,
					checkpoint_count,
					_format_activity_time(last_duration),
				]
			&"failed", &"aborted":
				var readable_reason := str(terminal_reason).replace("_", " ").to_upper()
				activity_text = "PATROL  %s%s  %d/%d" % [
					"ABORTED" if state_id == &"aborted" else "FAILED",
					(" — " + readable_reason) if not readable_reason.is_empty() else "",
					completed_checkpoints,
					checkpoint_count,
				]
			_:
				activity_text = ""
	elif not state_id.is_empty():
		match state_id:
			&"countdown":
				activity_text = "RACE  START %s  L%d/%d  BEST %s" % [
					_format_activity_time(countdown_remaining),
					lap_number,
					lap_count,
					_format_activity_time(best_time),
				]
			&"active":
				activity_text = "RACE  L%d/%d  G%d/%d  %s  BEST %s" % [
					lap_number,
					lap_count,
					mini(next_index + 1, checkpoint_count),
					checkpoint_count,
					_format_activity_time(current_time),
					_format_activity_time(best_time),
				]
			&"completed":
				activity_text = "RACE  FINISH %s  BEST %s" % [
					_format_activity_time(last_time),
					_format_activity_time(best_time),
				]
			&"failed":
				var readable_reason := str(failure_reason).replace("_", " ").to_upper()
				activity_text = "RACE  FAILED%s" % (
					(" — " + readable_reason) if not readable_reason.is_empty() else ""
				)
			_:
				activity_text = ""
	else:
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
		"activity_kind": activity_kind,
		"display_name": display_name,
		"state": state,
		"state_id": state_id if not state_id.is_empty() else &"legacy",
		"generation": session_generation,
		"session_generation": session_generation,
		"activity_generation": activity_generation,
		"race_generation": race_generation,
		"lap_number": lap_number,
		"lap_count": lap_count,
		"next_checkpoint_index": next_index,
		"checkpoint_count": checkpoint_count,
		"countdown_remaining_seconds": countdown_remaining,
		"current_time_seconds": current_time,
		"last_time_seconds": last_time,
		"best_time_seconds": best_time,
		"penalty_seconds": penalty,
		"failure_reason": failure_reason,
		"phase_id": phase_id,
		"completed_checkpoint_count": completed_checkpoints,
		"dwell_remaining_seconds": dwell_remaining,
		"terminal_reason": terminal_reason,
		"deadline_remaining_seconds": deadline_remaining,
		"quantity": quantity,
		"item_id": item_id,
		"item_display_name": item_display_name,
		"escort_distance": escort_distance,
		"activation_distance": activation_distance,
		"terminal_result_id": terminal_result_id,
		"text": activity_text,
	}
	if is_instance_valid(_activity_objective_label):
		_activity_objective_label.text = activity_text
		_activity_objective_label.visible = visible


func _format_activity_time(seconds: float) -> String:
	if not is_finite(seconds) or seconds < 0.0:
		return "--"
	if seconds < 60.0:
		return "%.1fs" % seconds
	var whole_minutes := floori(seconds / 60.0)
	return "%d:%04.1f" % [whole_minutes, seconds - whole_minutes * 60.0]


func clear_activity_objective() -> void:
	set_activity_objective("", {})


## Detached copy for focused integration checks and non-visual accessibility
## consumers. Mutating it cannot change the live HUD state.
func get_activity_objective_report() -> Dictionary:
	return _activity_objective_report.duplicate(true)


func set_interaction(text: String, is_visible: bool = true) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var display_text := text
	if text.begins_with("[ E ]"):
		var interact_prompt := _action_prompts([&"interact"])
		if not interact_prompt.is_empty():
			display_text = "[ %s ]%s" % [interact_prompt, text.substr(5)]
	_interaction_label.text = display_text
	_interaction_panel.visible = is_visible and not text.is_empty()


## Presentation-only transition copy for the first boarding/seat handoff. The
## caller still owns the actual interact action and transition authority.
func present_seat_transition_prompt(transition: StringName, subject: String = "") -> void:
	var target := subject.strip_edges().to_upper()
	var action_text: String = str({
		&"board": "BOARD",
		&"exit": "EXIT SEAT",
		&"take_seat": "TAKE PILOT SEAT",
	}.get(transition, "INTERACT"))
	set_interaction("[ E ]  %s%s" % [action_text, "  //  " + target if not target.is_empty() else ""], true)


func dismiss_seat_transition_prompt() -> void:
	set_interaction("", false)


func update_ship_telemetry(data: Dictionary) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
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
	_damage_status_label.text = "%s    ENGINE OUTPUT  %03d%%" % [
		_damage_status_accessible_text(damage_status),
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
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var normalized := state.to_upper()
	_state_engine = normalized
	_engine_label.text = "ENGINE  //  " + normalized
	match normalized:
		"ONLINE": _engine_label.modulate = _c(NOMINAL)
		"STARTING": _engine_label.modulate = _c(CAUTION)
		_: _engine_label.modulate = _c(DANGER)


func set_target_count(destroyed: int, total: int) -> void:
	_target_label.text = "RANGE TARGETS  %d / %d" % [destroyed, total]


## Updates the lock readout with shape and text semantics; palette colour is
## only a supporting cue and never the state itself.
func set_target_lock_state(state: StringName, target_name: String = "") -> void:
	var presentation := get_target_lock_presentation(state, target_name)
	_reticle_state = presentation.state
	if not is_instance_valid(_reticle_state_label):
		return
	_reticle_state_label.text = "%s  %s" % [presentation.marker, presentation.label]
	_reticle_state_label.modulate = _c(presentation.role)


static func get_target_lock_presentation(state: StringName, target_name: String = "") -> Dictionary:
	var safe_target := target_name.strip_edges().to_upper()
	match state:
		&"acquired":
			return {"state": &"acquired", "marker": "[+]", "label": "LOCKED  %s" % safe_target if not safe_target.is_empty() else "LOCKED", "role": NOMINAL}
		&"friendly_blocked":
			return {"state": &"friendly_blocked", "marker": "[=]", "label": "FRIENDLY  HOLD FIRE", "role": CAUTION}
		&"invalid":
			return {"state": &"invalid", "marker": "[?]", "label": "INVALID TARGET", "role": MUTED}
		_:
			return {"state": &"searching", "marker": "[...]", "label": "SEARCHING", "role": NOMINAL_SOFT}


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
	if _reduced_motion:
		# Reduced motion keeps the toast readable at full opacity and uses a
		# process-always timer for dismissal rather than a zero-duration tween.
		var reduced_timer := get_tree().create_timer(duration, true, false, true)
		reduced_timer.timeout.connect(func() -> void:
			if serial == _toast_serial:
				_toast_panel.visible = false
		)
		return
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
		_pause_reentry_focus_target = null
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused and _pause_main_page != null:
		var resume := _pause_main_page.find_child("ResumeButton", true, false) as Button
		if resume != null:
			resume.grab_focus()


func _restore_pause_focus_after_reentry() -> void:
	if is_queued_for_deletion() or not is_inside_tree() or _pause == null or not _pause.visible:
		return
	var target := _pause_reentry_focus_target
	if (
		not is_instance_valid(target)
		or not is_ancestor_of(target)
		or not target.is_visible_in_tree()
		or target.focus_mode == Control.FOCUS_NONE
		or (target is BaseButton and (target as BaseButton).disabled)
	):
		target = _pause_focus_fallback()
	if not is_instance_valid(target):
		return
	target.grab_focus()
	if (
		_settings_scroll != null
		and _settings_page != null
		and _settings_page.visible
		and _settings_page.is_ancestor_of(target)
	):
		_request_settings_scroll(target)


func _pause_focus_fallback() -> Control:
	if _binding_conflict_panel != null and _binding_conflict_panel.visible:
		return _binding_conflict_replace_button
	if _settings_page != null and _settings_page.visible:
		if (
			not _binding_capture_action.is_empty()
			and _binding_buttons.has(_binding_capture_action)
		):
			return _binding_buttons[_binding_capture_action] as Control
		return _settings_controls.get(&"ship_mouse_sensitivity") as Control
	if _activity_selection_page != null and _activity_selection_page.visible:
		return _activity_selection_buttons.get(_activity_selection_kind) as Control
	if _pause_main_page != null and _pause_main_page.visible:
		return _pause_main_page.find_child("ResumeButton", true, false) as Control
	return null


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
			_runtime_input_glyph_presenter.refresh(_input_binding_profile)
			_rebuild_input_remapping_presenter(_input_binding_defaults, _input_binding_profile)
			_runtime_input_rebind_presenter.attach(_input_binding_profile)
			_refresh_input_prompts()
	for raw_key: Variant in snapshot:
		var key := StringName(str(raw_key))
		if key == _CONTROLLER_GLYPH_FAMILY_KEY:
			# Controller glyph layout is a local presentation preference. It is
			# intentionally not part of RuntimeSettings persistence.
			continue
		if not _settings_controls.has(key):
			continue
		var control := _settings_controls[key] as Control
		var value: Variant = snapshot[raw_key]
		if control is Range:
			(control as Range).value = float(value)
			_update_setting_value_label(key, float(value))
			if key == &"ui_scale":
				set_ui_scale(float(value))
		elif control is CheckButton:
			(control as CheckButton).button_pressed = bool(value)
			if key == &"captions_enabled":
				set_captions_enabled(bool(value))
		elif control is OptionButton:
			var option := control as OptionButton
			option.select(clampi(int(value), 0, option.item_count - 1))
		elif control is LineEdit:
			(control as LineEdit).text = str(value)
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
	_runtime_input_rebind_presenter = RuntimeInputRebindPresenterType.new(
		_input_rebind_service,
		_input_glyph_resolver
	)
	if (
		_input_binding_profile == null
		or not _input_rebind_service.is_profile_compatible_with_defaults(_input_binding_profile)
	):
		_input_binding_profile = _input_binding_defaults.duplicate_profile()
	if _runtime_input_glyph_presenter != null:
		_runtime_input_glyph_presenter.refresh(_input_binding_profile)
	_rebuild_input_remapping_presenter(_input_binding_defaults, _input_binding_profile)
	if _runtime_input_rebind_presenter != null:
		_runtime_input_rebind_presenter.attach(_input_binding_profile)
	_refresh_input_prompts()
	return true


func _rebuild_input_remapping_presenter(
	defaults: InputBindingProfile,
	initial: InputBindingProfile
	) -> void:
	if defaults == null:
		_input_remapping_controller = null
		_input_remapping_presenter = null
		return
	_input_remapping_controller = RuntimeInputRemappingControllerType.new(
		defaults,
		initial,
		_input_glyph_resolver.get_preferred_device_family()
		if _input_glyph_resolver != null else &"unknown"
	)
	_input_remapping_presenter = RuntimeInputRemappingPresenterType.new(
		_input_remapping_controller
	)


func set_settings_status(text: String, success: bool = true) -> void:
	if _settings_status_label == null:
		return
	_settings_status_label.text = text
	_settings_status_label.modulate = _c(NOMINAL_SOFT) if success else _c(DANGER)
	_settings_status_label.visible = not text.is_empty()


## Caller-owned persistence result. The HUD never writes settings; it only
## keeps the player informed about whether the last Apply/Reset request landed.
func present_settings_persistence_result(result: Dictionary, operation: StringName = &"save") -> bool:
	var accepted := bool(result.get("accepted", false))
	if accepted:
		_settings_dirty = false
		set_settings_status(
			"SETTINGS RESET" if operation == &"reset" else "SETTINGS SAVED",
			true
		)
		return true
	_settings_dirty = true
	var reason := str(result.get("reason", result.get("status", "unknown failure")))
	set_settings_status(
		("RESET FAILED  //  %s" if operation == &"reset" else "SAVE FAILED  //  %s") % reason.to_upper(),
		false
	)
	return false


func has_unsaved_settings() -> bool:
	return _settings_dirty


func _request_settings_reset() -> void:
	if not _settings_dirty:
		settings_reset_requested.emit()
		return
	if not is_instance_valid(_settings_reset_confirmation):
		return
	_settings_reset_confirmation.visible = true
	var confirm_button := _settings_reset_confirmation.find_child("ConfirmSettingsResetButton", true, false) as Button
	if is_instance_valid(confirm_button):
		confirm_button.grab_focus()


func _confirm_settings_reset() -> void:
	if is_instance_valid(_settings_reset_confirmation):
		_settings_reset_confirmation.visible = false
	settings_reset_requested.emit()
	set_settings_status("RESET REQUESTED", true)


func _cancel_settings_reset() -> void:
	if is_instance_valid(_settings_reset_confirmation):
		_settings_reset_confirmation.visible = false
	var reset_button := _settings_page.find_child("SettingsResetButton", true, false) as Button
	if is_instance_valid(reset_button):
		reset_button.grab_focus()
	set_settings_status("RESET CANCELLED", true)


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
	if is_instance_valid(_minimap):
		_minimap.set_palette(_palette)
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
		"minimap": _minimap,
		"help": _help_panel,
		"interaction": _interaction_panel,
		"telemetry": _telemetry_panel,
		"toast": _toast_panel,
		"enemy": _enemy_panel,
	}
	var rects := {}
	for key: String in sources:
		var control := sources[key] as Control
		if is_instance_valid(control):
			rects[key] = control.get_rect()
	if is_instance_valid(_caption_presenter):
		var effective := maxf(_layout_effective_ui_scale, 0.01)
		var report := _caption_presenter.get_layout_report()
		rects["caption"] = Rect2(
			(report.panel_rect as Rect2).position / effective,
			(report.panel_rect as Rect2).size / effective
		)
	return rects


## Lays the scaled layers out for an explicit viewport instead of the live one,
## and returns the effective factor that was applied. This is the single code
## path [method _apply_ui_scale] uses, exposed so the layout regression measures
## the shipping layout at window sizes a headless run cannot give the window.
func layout_for_viewport(viewport_size: Vector2) -> float:
	var effective := compute_effective_ui_scale(_ui_scale, viewport_size)
	_layout_effective_ui_scale = effective
	var logical := viewport_size / maxf(effective, 0.01)
	var safe_left := maxf(_safe_area_insets.position.x, 0.0) / maxf(effective, 0.01)
	var safe_top := maxf(_safe_area_insets.position.y, 0.0) / maxf(effective, 0.01)
	var safe_right := maxf(_safe_area_insets.size.x, 0.0) / maxf(effective, 0.01)
	var safe_bottom := maxf(_safe_area_insets.size.y, 0.0) / maxf(effective, 0.01)
	var contract_safe := UltrawideSafeAreaContractType.safe_rect(viewport_size, effective)
	safe_left = maxf(safe_left, contract_safe.position.x / maxf(effective, 0.01))
	safe_top = maxf(safe_top, contract_safe.position.y / maxf(effective, 0.01))
	safe_right = maxf(safe_right, (viewport_size.x - contract_safe.end.x) / maxf(effective, 0.01))
	safe_bottom = maxf(safe_bottom, (viewport_size.y - contract_safe.end.y) / maxf(effective, 0.01))
	_apply_safe_area_offsets(safe_left, safe_top, safe_right, safe_bottom)
	for layer in _scaled_layers:
		if not is_instance_valid(layer):
			continue
		layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		layer.position = Vector2.ZERO
		layer.size = logical
		layer.scale = Vector2(effective, effective)
	if is_instance_valid(_runtime_status_panel):
		var status_rect := compute_runtime_status_panel_rect(
			viewport_size, _safe_area_insets, effective
		)
		_runtime_status_panel.position = status_rect.position - logical * 0.5
		_runtime_status_panel.size = status_rect.size
	if is_instance_valid(_reticle):
		# The reticle remains camera-centred, but its state label follows the same
		# authored UI scale ceiling as the surrounding HUD.
		_reticle.scale = Vector2.ONE * effective
	if is_instance_valid(_caption_presenter):
		_caption_presenter.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_caption_presenter.position = Vector2(CAPTION_HOST_LEFT_LOGICAL * effective, 0.0)
		_caption_presenter.size = Vector2(
			maxf(
				1.0,
				viewport_size.x
					- (CAPTION_HOST_LEFT_LOGICAL + CAPTION_HOST_RIGHT_LOGICAL) * effective
			),
			viewport_size.y
		)
		_caption_presenter.set_ui_scale(effective)
		_caption_presenter.set_host_bottom_safe_margin(
			CAPTION_BOTTOM_SAFE_LOGICAL * effective
		)
	return effective


static func compute_runtime_status_panel_rect(
	viewport_size: Vector2, safe_insets: Rect2, effective_scale: float
) -> Rect2:
	var scale := maxf(effective_scale, 0.01)
	var logical := viewport_size / scale
	var left := maxf(safe_insets.position.x, 0.0) / scale
	var right := maxf(safe_insets.size.x, 0.0) / scale
	var top := maxf(safe_insets.position.y, 0.0) / scale
	var bottom := maxf(safe_insets.size.y, 0.0) / scale
	var available := maxf(360.0, logical.x - left - right - PANEL_MARGIN * 2.0)
	var width := clampf(available * 0.32, 460.0, 680.0)
	var center_x := left + (logical.x - left - right) * 0.5
	var center_y := top + (logical.y - top - bottom) * 0.5
	return Rect2(Vector2(center_x - width * 0.5, center_y - 150.0), Vector2(width, 300.0))


## Applies physical-pixel display cutout/overscan insets to edge-anchored HUD
## panels. The value is retained across viewport changes and intentionally lives
## in the HUD presentation layer rather than settings persistence.
func set_safe_area_insets(insets: Rect2) -> void:
	_safe_area_insets = Rect2(
		Vector2(maxf(insets.position.x, 0.0), maxf(insets.position.y, 0.0)),
		Vector2(maxf(insets.size.x, 0.0), maxf(insets.size.y, 0.0))
	)
	_apply_ui_scale()


func get_safe_area_insets() -> Rect2:
	return _safe_area_insets


func _apply_safe_area_offsets(left: float, top: float, right: float, bottom: float) -> void:
	if is_instance_valid(_brand_block):
		_brand_block.position.x = 30.0 + left
		_brand_block.position.y = 26.0 + top
	if is_instance_valid(_objective_panel):
		_objective_panel.position.x = 30.0 + left
		_objective_panel.position.y = 126.0 + top
	if is_instance_valid(_help_panel):
		_help_panel.offset_left = -(PANEL_HELP_WIDTH + PANEL_MARGIN + right)
		_help_panel.offset_right = -PANEL_MARGIN - right
		_help_panel.offset_top = 28.0 + top
		_help_panel.offset_bottom = 342.0 + top
	if is_instance_valid(_minimap):
		_minimap.offset_left = PANEL_MARGIN + left
		_minimap.offset_right = PANEL_MARGIN + 240.0 + left
		_minimap.offset_top = -270.0 - bottom
		_minimap.offset_bottom = -PANEL_MARGIN - bottom
	if is_instance_valid(_telemetry_panel):
		_telemetry_panel.offset_left = -(PANEL_TELEMETRY_WIDTH + PANEL_MARGIN + right)
		_telemetry_panel.offset_right = -PANEL_MARGIN - right
		_telemetry_panel.offset_top = -250.0 - bottom
		_telemetry_panel.offset_bottom = -PANEL_MARGIN - bottom


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
	_captions_enabled = enabled
	# Production immediately follows with a service snapshot commit. This local
	# gate also preserves the public HUD setter's fail-closed behavior for an
	# isolated or currently detached HUD, without fabricating service state.
	if not enabled and is_instance_valid(_caption_presenter):
		_caption_presenter.visible = false


func are_captions_enabled() -> bool:
	return _captions_enabled


## Presents one authored audio cue as readable text. Cues without an authored
## caption are ignored, and nothing is shown while captions are disabled.
func caption_cue(cue_id: StringName) -> bool:
	if not _captions_enabled or not CAPTION_CUES.has(cue_id):
		return false
	var cue := CAPTION_CUES[cue_id] as Array
	return _submit_caption_request({
		"cue_id": cue_id,
		"category_id": StringName(cue[0]),
		"speaker": str(cue[1]),
		"text": str(cue[2]),
		"duration_physics_seconds": CAPTION_DURATION_PHYSICS_SECONDS,
		"priority": int(cue[3]),
	})


## Activity captions retain the single caption ingress while adding the
## caller-supplied activity label. The label is presentation text only; the
## activity owner remains responsible for state and reward authority.
func caption_activity_cue(cue_id: StringName, activity_label: String) -> bool:
	if not _captions_enabled or not CAPTION_CUES.has(cue_id):
		return false
	var cue := CAPTION_CUES[cue_id] as Array
	var label := activity_label.strip_edges()
	if label.is_empty():
		label = "Activity"
	return _submit_caption_request({
		"cue_id": cue_id,
		"category_id": StringName(cue[0]),
		"speaker": str(cue[1]),
		"text": str(cue[2]).replace("{activity}", label),
		"duration_physics_seconds": CAPTION_DURATION_PHYSICS_SECONDS,
		"priority": int(cue[3]),
	})


## Translates an already-emitted semantic audio event into the one authoritative
## caption request path. This does not play audio or retain a second caption
## queue; CaptionPresenter continues to own scale, safe-area, and motion policy.
func present_semantic_audio_cue(
	cue_id: StringName, source: StringName, intensity: float, world_position: Vector3
) -> bool:
	if not _captions_enabled:
		return false
	var presentation := _semantic_audio_cue_presenter.present_cue(
		cue_id, source, intensity, world_position
	)
	if not bool(presentation.get("accepted", false)):
		return false
	var severity := StringName(presentation.get("severity", &"low"))
	var priority: int = int({&"low": 45, &"medium": 70, &"high": 90}.get(severity, 45))
	var text := "%s %s" % [presentation.get("severity_marker", "○"), presentation.caption]
	return _submit_caption_request({
		"category_id": &"system",
		"speaker": str(presentation.source),
		"text": text,
		"duration_physics_seconds": CAPTION_DURATION_PHYSICS_SECONDS,
		"priority": priority,
	})


func show_caption(text: String) -> bool:
	if not _captions_enabled:
		return false
	var line := text.strip_edges()
	if line.is_empty():
		return false
	return _submit_caption_request({
		"cue_id": &"manual",
		"category_id": &"system",
		"speaker": "Shipyard",
		"text": line,
		"duration_physics_seconds": CAPTION_DURATION_PHYSICS_SECONDS,
		"priority": 50,
	})


## GameFlow binds one request sink for the lifetime of a production Main. The
## Callable receives a detached descriptor and returns whether the typed service
## accepted it. Rebinding the same sink is idempotent; a competing owner fails.
func bind_caption_event_submitter(submitter: Callable) -> bool:
	if not submitter.is_valid():
		return false
	if _caption_event_submitter.is_valid() and _caption_event_submitter != submitter:
		return false
	_caption_event_submitter = submitter
	return true


func unbind_caption_event_submitter(submitter: Callable) -> bool:
	if not _caption_event_submitter.is_valid():
		return true
	if not submitter.is_valid() or _caption_event_submitter != submitter:
		return false
	_caption_event_submitter = Callable()
	return true


## The sole visual ingress: a detached presentation dictionary produced by the
## GameFlow-owned service. Invalid lookalikes never mutate the last view.
func apply_caption_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not is_instance_valid(_caption_presenter):
		return false
	return _caption_presenter.apply_presentation_snapshot(snapshot)


func get_caption_presentation_snapshot() -> Dictionary:
	return (
		_caption_presenter.get_applied_snapshot()
		if is_instance_valid(_caption_presenter)
		else {}
	)


func get_caption_presentation_report() -> Dictionary:
	if not is_instance_valid(_caption_presenter):
		return {}
	var report := _caption_presenter.get_layout_report()
	report["request_sink_bound"] = _caption_event_submitter.is_valid()
	report["presenter_instance_id"] = _caption_presenter.get_instance_id()
	return report.duplicate(true)


## Legacy read-only compatibility now projects the one authoritative active
## presentation. The retired three-line history is intentionally not recreated.
func get_caption_log() -> PackedStringArray:
	if not _captions_enabled:
		return PackedStringArray()
	var snapshot := get_caption_presentation_snapshot()
	if not bool(snapshot.get("visible", false)):
		return PackedStringArray()
	var caption := snapshot.get("caption", {}) as Dictionary
	return PackedStringArray([str(caption.get("text", ""))])


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
		"caption_visible": bool(get_caption_presentation_report().get("visible", false)),
		"caption_log": get_caption_log(),
		"caption_request_sink_bound": _caption_event_submitter.is_valid(),
		"caption_presenter_count": 1 if is_instance_valid(_caption_presenter) else 0,
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
	_refresh_planetary_cruise_row()


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


func _submit_caption_request(request: Dictionary) -> bool:
	if not _caption_event_submitter.is_valid():
		return false
	return bool(_caption_event_submitter.call(request.duplicate(true)))


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
	_build_debug_overlay()
	_set_mouse_passthrough(_hud)
	_apply_ui_scale()
	show_intro()


func _build_debug_overlay() -> void:
	_debug_overlay = DebugOverlayType.new() as DebugOverlay
	_debug_overlay.visible = false
	_root.add_child(_debug_overlay)


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

	_build_minimap()

	_flight_cue_layer = FlightPathCueType.new() as FlightPathCue
	_flight_cue_layer.name = "FlightPathCue"
	_flight_cue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_flight_cue_layer)

	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.position = Vector2(-22.0, -22.0)
	_reticle.size = Vector2(44.0, 44.0)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.pivot_offset = Vector2(22.0, 22.0)
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
	_reticle_state_label = _label("[...]  SEARCHING", 10, NOMINAL_SOFT)
	_reticle_state_label.position = Vector2(-46.0, 48.0)
	_reticle_state_label.size = Vector2(136.0, 22.0)
	_reticle_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.add_child(_reticle_state_label)
	_reticle.visible = false

	_build_telemetry()
	_build_enemy_status()
	_build_toast()
	_build_runtime_status_panel()
	_attach_caption_presenter()
	_build_damage_flash()


func _build_minimap() -> void:
	_minimap = MinimapType.new() as Minimap
	_minimap.name = "Minimap"
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_minimap.offset_left = PANEL_MARGIN
	_minimap.offset_right = PANEL_MARGIN + 240.0
	_minimap.offset_top = -270.0
	_minimap.offset_bottom = -PANEL_MARGIN
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.set_palette(_palette)
	_hud_panels.add_child(_minimap)


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
	_damage_status_label = _label("HULL  //  OK    ENGINE OUTPUT  100%", 9, MUTED)
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


func _build_runtime_status_panel() -> void:
	_runtime_status_panel = PanelContainer.new()
	_runtime_status_panel.name = "RuntimeStatusPanel"
	_runtime_status_panel.set_anchors_preset(Control.PRESET_CENTER)
	_runtime_status_panel.position = Vector2(-250.0, -150.0)
	_runtime_status_panel.size = Vector2(500.0, 300.0)
	_runtime_status_panel.add_theme_stylebox_override("panel", _border_box(PANEL_SOLID, 8, NOMINAL))
	_runtime_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_panels.add_child(_runtime_status_panel)
	var margin := _margin(18, 16, 18, 16)
	_runtime_status_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	_runtime_status_title = _label("STATUS", 18, PRIMARY)
	stack.add_child(_runtime_status_title)
	_runtime_status_detail = _label("", 11, NOMINAL_SOFT)
	_runtime_status_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_runtime_status_detail)
	_runtime_status_rows = VBoxContainer.new()
	_runtime_status_rows.add_theme_constant_override("separation", 4)
	stack.add_child(_runtime_status_rows)
	_runtime_status_actions = HBoxContainer.new()
	_runtime_status_actions.add_theme_constant_override("separation", 8)
	stack.add_child(_runtime_status_actions)
	_runtime_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runtime_status_panel.visible = false


func update_network_session_status(snapshot: Dictionary) -> void:
	_render_runtime_status(_network_status_presenter.present_snapshot(snapshot), &"network")


func update_crew_role_status(snapshot: Dictionary) -> void:
	_render_runtime_status(_crew_role_presenter.present_snapshot(snapshot), &"crew")


func update_surface_route_status(snapshot: Dictionary) -> void:
	_render_runtime_status(_surface_route_presenter.present_snapshot(snapshot), &"surface")


func update_atmospheric_entry_status(snapshot: Dictionary) -> void:
	_render_runtime_status(_entry_guidance_presenter.present_snapshot(snapshot), &"entry")


func apply_first_sortie_tutorial_snapshot(snapshot: Dictionary) -> bool:
	var presentation := _first_sortie_tutorial_presenter.present_snapshot(snapshot)
	if not bool(presentation.get("accepted", false)):
		return false
	var runtime_snapshot := presentation.duplicate(true)
	runtime_snapshot["message"] = presentation.prompt
	runtime_snapshot["detail"] = presentation.prompt
	_render_runtime_status(runtime_snapshot, &"tutorial")
	return true


func dismiss_first_sortie_tutorial() -> Dictionary:
	var result := _first_sortie_tutorial_presenter.request(&"dismiss")
	if bool(result.get("accepted", false)):
		presentation_intent_requested.emit(&"tutorial", result)
	clear_runtime_status()
	return result


func request_first_sortie_tutorial_action(action: StringName) -> Dictionary:
	var result := _first_sortie_tutorial_presenter.request(action)
	if bool(result.get("accepted", false)):
		presentation_intent_requested.emit(&"tutorial", result)
		if action == &"dismiss":
			clear_runtime_status()
	return result


func clear_runtime_status() -> void:
	if is_instance_valid(_runtime_status_panel):
		_runtime_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in _runtime_status_panel.find_children("*", "Control", true, false):
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_runtime_status_panel.visible = false


func _render_runtime_status(snapshot: Dictionary, kind: StringName) -> void:
	if not is_instance_valid(_runtime_status_panel):
		return
	_runtime_status_title.text = str(snapshot.get("title", "STATUS"))
	_runtime_status_detail.text = str(snapshot.get("message", snapshot.get("guidance", "")))
	for child in _runtime_status_rows.get_children():
		child.queue_free()
	for child in _runtime_status_actions.get_children():
		child.queue_free()
	var detail := _runtime_status_detail.text
	if snapshot.has("exposure_marker"):
		detail += "\n" + str(snapshot.exposure_marker)
	if snapshot.has("next_landmark"):
		detail += "\nNEXT // %s // %.1f M" % [snapshot.next_landmark, float(snapshot.distance_m)]
	if snapshot.has("state"):
		detail += "\nSTATE // " + str(snapshot.state).to_upper()
	_runtime_status_detail.text = detail
	for action: Dictionary in snapshot.get("actions", []):
		var button := _menu_button(str(action.get("label", "Action")), NOMINAL)
		button.name = "RuntimeStatus" + String(action.get("id", &"Action")).to_pascal_case() + "Button"
		button.focus_mode = Control.FOCUS_ALL
		var action_id := StringName(str(action.get("id", &"")))
		button.pressed.connect(func() -> void:
			presentation_intent_requested.emit(kind, {"action": action_id, "snapshot": snapshot.duplicate(true)})
		)
		_runtime_status_actions.add_child(button)
	_runtime_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_runtime_status_panel.visible = true


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


func _attach_caption_presenter() -> void:
	if not is_instance_valid(_caption_presenter):
		push_error("HUD scene is missing its authored CaptionPresenter")
		return
	_caption_presenter.reparent(_hud, false)
	_caption_presenter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_caption_presenter.position = Vector2.ZERO
	_caption_presenter.size = _viewport_size()
	_caption_presenter.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	_build_activity_selection_page()
	_build_nearby_activity_page()
	_build_server_browser_page()
	_build_settings_page()
	_show_pause_main()


func _build_pause_main_page() -> void:
	_pause_main_page = PanelContainer.new()
	_pause_main_page.name = "PauseMainPage"
	_pause_main_page.set_anchors_preset(Control.PRESET_CENTER)
	_pause_main_page.position = Vector2(-240.0, -250.0)
	_pause_main_page.size = Vector2(480.0, 500.0)
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
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 10)
	stack.add_child(menu_row)
	var settings := _menu_button("SETTINGS", NOMINAL_SOFT)
	settings.name = "SettingsOpenButton"
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(_show_settings_page)
	menu_row.add_child(settings)
	var activity_board := _menu_button("ACTIVITY BOARD", NOMINAL_SOFT)
	activity_board.name = "ActivityBoardButton"
	activity_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	activity_board.pressed.connect(_show_activity_selection_page)
	menu_row.add_child(activity_board)
	var server_browser := _menu_button("SERVER BROWSER", NOMINAL_SOFT)
	server_browser.name = "ServerBrowserButton"
	server_browser.pressed.connect(_show_server_browser_page)
	stack.add_child(server_browser)
	var cruise_row := VBoxContainer.new()
	cruise_row.name = "PlanetaryCruiseRow"
	cruise_row.add_theme_constant_override("separation", 4)
	stack.add_child(cruise_row)
	_planetary_cruise_button = _menu_button("EMBER CRUISE", NOMINAL_SOFT)
	_planetary_cruise_button.name = "PlanetaryCruiseToggleButton"
	_planetary_cruise_button.pressed.connect(_request_planetary_cruise_toggle)
	cruise_row.add_child(_planetary_cruise_button)
	_planetary_cruise_status_label = _label(
		_planetary_cruise_status_text,
		10,
		MUTED,
	)
	_planetary_cruise_status_label.name = "PlanetaryCruiseStatus"
	_planetary_cruise_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planetary_cruise_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cruise_row.add_child(_planetary_cruise_status_label)
	_refresh_planetary_cruise_row()
	var restart := _menu_button("RESTART SHIFT", CAUTION)
	restart.name = "RestartButton"
	restart.pressed.connect(func() -> void:
		set_paused(false)
		restart_requested.emit()
	)
	stack.add_child(restart)
	var exit := _menu_button("EXIT TO DESKTOP", DANGER)
	exit.name = "ExitButton"
	exit.pressed.connect(func() -> void: orderly_shutdown_requested.emit())
	stack.add_child(exit)
	# Freeze a controller-only path through the existing pause page. Horizontal
	# movement still crosses the paired Settings/Activity buttons; either route
	# reaches the cruise row on the next down press without pointer input.
	resume.focus_neighbor_bottom = resume.get_path_to(settings)
	settings.focus_neighbor_top = settings.get_path_to(resume)
	settings.focus_neighbor_right = settings.get_path_to(activity_board)
	settings.focus_neighbor_bottom = settings.get_path_to(_planetary_cruise_button)
	activity_board.focus_neighbor_top = activity_board.get_path_to(resume)
	activity_board.focus_neighbor_left = activity_board.get_path_to(settings)
	activity_board.focus_neighbor_bottom = activity_board.get_path_to(
		_planetary_cruise_button
	)
	_planetary_cruise_button.focus_neighbor_top = (
		_planetary_cruise_button.get_path_to(settings)
	)
	_planetary_cruise_button.focus_neighbor_bottom = (
		_planetary_cruise_button.get_path_to(restart)
	)
	restart.focus_neighbor_top = restart.get_path_to(_planetary_cruise_button)


## The smallest reachable selection surface for the four production activities.
## Buttons emit requests only; GameFlow remains the owner of validation, route
## exclusivity, and the post-start selection lock.
func _build_activity_selection_page() -> void:
	_activity_selection_page = PanelContainer.new()
	_activity_selection_page.name = "ActivitySelectionPage"
	_activity_selection_page.set_anchors_preset(Control.PRESET_CENTER)
	_activity_selection_page.position = Vector2(-340.0, -310.0)
	_activity_selection_page.size = Vector2(680.0, 620.0)
	_activity_selection_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_activity_selection_page.add_theme_stylebox_override(
		"panel",
		_border_box(PANEL_SOLID, 10, NOMINAL)
	)
	_pause_panels.add_child(_activity_selection_page)
	var margin := _margin(30, 24, 30, 24)
	_activity_selection_page.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	var title := _label("ACTIVITY BOARD", 26, PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label(
		"Choose the next sortie before launch. Starting it locks this board.",
		12,
		MUTED
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(subtitle)
	_add_activity_selection_row(
		stack,
		&"timed_race",
		"TIMED CINDER RACE",
		"Ordered Cinder anchors with countdown, lap time and timeout."
	)
	_add_activity_selection_row(
		stack,
		&"patrol",
		"CINDER PATROL",
		"Travel to each published anchor and hold through its dwell window."
	)
	_add_activity_selection_row(
		stack,
		&"cargo_delivery",
		"JOVIAN KIT DELIVERY",
		"Carry two fabrication kits from the Jovian craft to its freight berth."
	)
	_add_activity_selection_row(
		stack,
		&"convoy_escort",
		"EMBERLINE CONVOY ESCORT",
		"Rendezvous 20 m above the tender route and remain within escort range."
	)
	_activity_selection_status_label = _label("READY  //  TIMED CINDER RACE", 10, NOMINAL_SOFT)
	_activity_selection_status_label.name = "ActivitySelectionStatus"
	_activity_selection_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activity_selection_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_activity_selection_status_label)
	var back := _menu_button("BACK", MUTED)
	back.name = "ActivitySelectionBackButton"
	back.pressed.connect(_show_pause_main)
	stack.add_child(back)
	_refresh_activity_selection_page(&"")


func _build_nearby_activity_page() -> void:
	_nearby_activity_page = PanelContainer.new()
	_nearby_activity_page.name = "NearbyActivityPage"
	_nearby_activity_page.set_anchors_preset(Control.PRESET_CENTER)
	_nearby_activity_page.position = Vector2(-390.0, -330.0)
	_nearby_activity_page.size = Vector2(780.0, 660.0)
	_nearby_activity_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_nearby_activity_page.add_theme_stylebox_override("panel", _border_box(PANEL_SOLID, 10, NOMINAL))
	_pause_panels.add_child(_nearby_activity_page)
	var margin := _margin(24, 20, 24, 20)
	_nearby_activity_page.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var title := _label("CINDER ACTIVITY STATUS", 22, PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label("Select an activity, then forward an explicit start or reset intent.", 11, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	_nearby_activity_rows = VBoxContainer.new()
	_nearby_activity_rows.add_theme_constant_override("separation", 4)
	stack.add_child(_nearby_activity_rows)
	_nearby_activity_feedback = _label("No progress result received.", 10, MUTED)
	_nearby_activity_feedback.name = "NearbyActivityPersistenceFeedback"
	_nearby_activity_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nearby_activity_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_nearby_activity_feedback)
	var persistence_row := HBoxContainer.new()
	persistence_row.alignment = BoxContainer.ALIGNMENT_CENTER
	persistence_row.add_theme_constant_override("separation", 8)
	stack.add_child(persistence_row)
	var save := _menu_button("SAVE PROGRESS", MUTED)
	save.name = "NearbyActivitySaveButton"
	save.pressed.connect(_forward_nearby_activity_intent.bind(&"save", &""))
	persistence_row.add_child(save)
	var load := _menu_button("LOAD PROGRESS", MUTED)
	load.name = "NearbyActivityLoadButton"
	load.pressed.connect(_forward_nearby_activity_intent.bind(&"load", &""))
	persistence_row.add_child(load)
	var back := _menu_button("BACK", MUTED)
	back.name = "NearbyActivityBackButton"
	back.pressed.connect(_show_pause_main)
	stack.add_child(back)
	_nearby_activity_page.visible = false


func set_nearby_activity_snapshot(snapshot: Dictionary) -> Dictionary:
	_nearby_activity_snapshot = snapshot.duplicate(true)
	if _nearby_activity_presenter == null:
		_nearby_activity_presenter = NearbySectorActivityPresenterType.new()
	var view: Dictionary = _nearby_activity_presenter.call("present", _nearby_activity_snapshot)
	_render_nearby_activity_view(view)
	return view


func apply_nearby_activity_persistence_result(result: Dictionary) -> Dictionary:
	if _nearby_activity_presenter == null:
		_nearby_activity_presenter = NearbySectorActivityPresenterType.new()
	var view: Dictionary = _nearby_activity_presenter.call("present_persistence_result", result)
	_render_nearby_activity_view(view)
	return view


func _render_nearby_activity_view(view: Dictionary) -> void:
	if _nearby_activity_rows != null:
		for child in _nearby_activity_rows.get_children():
			child.queue_free()
		for card in view.get("cards", []) as Array:
			_add_nearby_activity_row(card as Dictionary)
	if _nearby_activity_feedback != null:
		_nearby_activity_feedback.text = str((view.get("persistence_feedback", {}) as Dictionary).get("text", ""))


func clear_nearby_activity_snapshot() -> void:
	_nearby_activity_snapshot.clear()
	if _nearby_activity_feedback != null:
		_nearby_activity_feedback.text = "No progress result received."
	if _nearby_activity_rows != null:
		for child in _nearby_activity_rows.get_children():
			child.queue_free()


func show_nearby_activity_page() -> void:
	if _nearby_activity_page == null:
		return
	_nearby_activity_page.visible = true
	var first := _nearby_activity_rows.get_child(0) as Control if _nearby_activity_rows.get_child_count() > 0 else null
	if first != null:
		first.grab_focus()


func get_nearby_activity_report() -> Dictionary:
	return {"visible": _nearby_activity_page != null and _nearby_activity_page.visible, "snapshot": _nearby_activity_snapshot.duplicate(true), "row_count": _nearby_activity_rows.get_child_count() if _nearby_activity_rows != null else 0}


func _add_nearby_activity_row(card: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "NearbyActivityRow_%s" % str(card.get("activity_id", "activity"))
	row.add_theme_constant_override("separation", 6)
	var label := _label(str(card.get("text", "ACTIVITY — AVAILABLE")), 10, NOMINAL_SOFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var activity_id := StringName(card.get("activity_id", &""))
	for action in [&"select", &"start", &"reset"]:
		var button := _menu_button(str(action).to_upper(), MUTED)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_forward_nearby_activity_intent.bind(action, activity_id))
		row.add_child(button)
	_nearby_activity_rows.add_child(row)


func _forward_nearby_activity_intent(action: StringName, activity_id: StringName) -> void:
	if _nearby_activity_presenter == null:
		return
	var intent: Dictionary
	if action == &"select":
		intent = _nearby_activity_presenter.call("select", activity_id)
	elif action == &"start":
		intent = _nearby_activity_presenter.call("start_intent", activity_id)
	elif action == &"reset":
		intent = _nearby_activity_presenter.call("reset_intent", activity_id)
	elif action == &"save":
		intent = _nearby_activity_presenter.call("save_progress_intent")
	else:
		intent = _nearby_activity_presenter.call("load_progress_intent")
	nearby_activity_intent_requested.emit(intent.duplicate(true))


func _build_server_browser_page() -> void:
	_server_browser_page = PanelContainer.new()
	_server_browser_page.name = "ServerBrowserPage"
	_server_browser_page.set_anchors_preset(Control.PRESET_CENTER)
	_server_browser_page.position = Vector2(-360.0, -300.0)
	_server_browser_page.size = Vector2(720.0, 600.0)
	_server_browser_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_server_browser_page.add_theme_stylebox_override("panel", _border_box(PANEL_SOLID, 10, NOMINAL))
	_pause_panels.add_child(_server_browser_page)
	var margin := _margin(28, 24, 28, 24)
	_server_browser_page.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	_server_browser_title = _label("SERVER BROWSER", 26, PRIMARY)
	_server_browser_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_server_browser_title)
	_server_browser_detail = _label("Select refresh to request a detached directory snapshot.", 12, MUTED)
	_server_browser_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_server_browser_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_server_browser_detail)
	var join_fields := HBoxContainer.new()
	join_fields.add_theme_constant_override("separation", 6)
	stack.add_child(join_fields)
	_server_browser_address = LineEdit.new()
	_server_browser_address.name = "ServerBrowserAddress"
	_server_browser_address.placeholder_text = "Address for manual join"
	_server_browser_address.text = "127.0.0.1"
	_server_browser_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_browser_address.focus_mode = Control.FOCUS_ALL
	join_fields.add_child(_server_browser_address)
	_server_browser_port = LineEdit.new()
	_server_browser_port.name = "ServerBrowserPort"
	_server_browser_port.placeholder_text = "Port"
	_server_browser_port.text = "27101"
	_server_browser_port.custom_minimum_size.x = 100.0
	_server_browser_port.focus_mode = Control.FOCUS_ALL
	join_fields.add_child(_server_browser_port)
	_server_browser_player_name = LineEdit.new()
	_server_browser_player_name.name = "ServerBrowserPlayerName"
	_server_browser_player_name.placeholder_text = "Player name"
	_server_browser_player_name.text = "Pilot"
	_server_browser_player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_browser_player_name.focus_mode = Control.FOCUS_ALL
	join_fields.add_child(_server_browser_player_name)
	_server_browser_feedback = _label("", 10, MUTED)
	_server_browser_feedback.name = "ServerBrowserFeedback"
	_server_browser_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_server_browser_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_server_browser_feedback)
	_server_browser_rows = VBoxContainer.new()
	_server_browser_rows.name = "ServerBrowserRows"
	_server_browser_rows.add_theme_constant_override("separation", 6)
	_server_browser_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_server_browser_rows)
	_server_browser_actions = HBoxContainer.new()
	_server_browser_actions.name = "ServerBrowserActions"
	_server_browser_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_server_browser_actions.add_theme_constant_override("separation", 10)
	stack.add_child(_server_browser_actions)
	var refresh := _menu_button("REFRESH", NOMINAL)
	refresh.name = "ServerBrowserRefreshButton"
	refresh.pressed.connect(request_server_browser_refresh)
	_server_browser_actions.add_child(refresh)
	var host := _menu_button("HOST SESSION", NOMINAL)
	host.name = "ServerBrowserHostButton"
	host.pressed.connect(request_server_browser_host)
	_server_browser_actions.add_child(host)
	var manual_join := _menu_button("MANUAL JOIN", NOMINAL_SOFT)
	manual_join.name = "ServerBrowserManualJoinButton"
	manual_join.pressed.connect(request_server_browser_manual_join)
	_server_browser_actions.add_child(manual_join)
	var back := _menu_button("BACK", MUTED)
	back.name = "ServerBrowserBackButton"
	back.pressed.connect(_show_pause_main)
	_server_browser_actions.add_child(back)
	_server_browser_page.visible = false


func _show_server_browser_page() -> void:
	_pause_main_page.visible = false
	_activity_selection_page.visible = false
	_settings_page.visible = false
	_server_browser_page.visible = true
	var refresh := _server_browser_page.find_child("ServerBrowserRefreshButton", true, false) as Button
	if refresh != null:
		refresh.grab_focus()


## Applies a caller-owned discovery result to the pause browser surface. The
## presenter owns only textual shaping; refresh and join remain external
## intents, so this UI never queries a directory or opens a transport.
func apply_server_browser_result(result: Dictionary) -> bool:
	if not is_instance_valid(_server_browser_page):
		return false
	var presentation: Dictionary
	var requested_status := StringName(str(result.get("status", &"")))
	if requested_status == &"loading":
		presentation = {
			"status": &"loading",
			"rows": [],
			"error_message": "Searching for available sessions…",
			"actions": [],
		}
	else:
		presentation = _server_browser_presenter.present_result(result)
		if presentation.get("status", &"") == &"ready":
			var rows: Array = presentation.get("rows", [])
			if not rows.is_empty() and rows.all(func(row: Variant) -> bool: return bool((row as Dictionary).get("full", false))):
				presentation["status"] = &"full"
	_render_server_browser(presentation)
	if _server_browser_feedback != null:
		_server_browser_feedback.text = ""
	return true


func apply_server_browser_feedback(result: Dictionary) -> Dictionary:
	if not is_instance_valid(_server_browser_feedback):
		return result.duplicate(true)
	var message := str(result.get("validation_error", result.get("message", "")))
	if message.is_empty():
		message = "Session request accepted by caller." if bool(result.get("accepted", false)) else "Session request was not accepted."
	_server_browser_feedback.text = message
	return result.duplicate(true)


func request_server_browser_host() -> Dictionary:
	var request := _server_browser_presenter.host_session_intent(
		int(_server_browser_port.text.to_int()), _server_browser_player_name.text
	)
	if not bool(request.get("accepted", false)):
		return apply_server_browser_feedback(request)
	presentation_intent_requested.emit(&"server_browser", request.duplicate(true))
	return request


func request_server_browser_manual_join() -> Dictionary:
	var request := _server_browser_presenter.manual_join_intent(
		_server_browser_address.text,
		int(_server_browser_port.text.to_int()),
		_server_browser_player_name.text
	)
	if not bool(request.get("accepted", false)):
		return apply_server_browser_feedback(request)
	presentation_intent_requested.emit(&"server_browser", request.duplicate(true))
	return request


func request_server_browser_refresh() -> Dictionary:
	var request := _server_browser_presenter.request_retry()
	if not bool(request.get("accepted", false)):
		request = {"accepted": true, "reason": &"refresh_requested", "presentation_only": true}
	presentation_intent_requested.emit(&"server_browser", {"action": &"refresh", "request": request})
	return request


func request_server_browser_join(session_id: StringName) -> Dictionary:
	if session_id == &"":
		return {"accepted": false, "reason": &"missing_session_id", "presentation_only": true}
	var request := {"accepted": true, "reason": &"join_requested", "presentation_only": true}
	presentation_intent_requested.emit(&"server_browser", {
		"action": &"join",
		"session_id": session_id,
		"request": request,
	})
	return request


func _render_server_browser(presentation: Dictionary) -> void:
	var status := StringName(str(presentation.get("status", &"empty")))
	var status_title: String = {
		&"loading": "SEARCHING…",
		&"empty": "NO SESSIONS FOUND",
		&"error": "SERVER LIST UNAVAILABLE",
		&"full": "ALL SESSIONS FULL",
		&"ready": "AVAILABLE SESSIONS",
	}.get(status, "SERVER BROWSER")
	_server_browser_title.text = status_title
	_server_browser_detail.text = str(presentation.get("error_message", "Select a session to request joining."))
	for child in _server_browser_rows.get_children():
		child.queue_free()
	var rows: Array = presentation.get("rows", [])
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		var button := _menu_button(
			"%s  //  %s  //  %s  //  %s  //  %s" % [
				str(row.get("title", "Unnamed session")),
				str(row.get("region_label", "UNKNOWN")),
				str(row.get("ping_label", "Unavailable")),
				str(row.get("occupancy_label", "0/0 players")),
				str(row.get("capacity_label", "AVAILABLE")),
			],
			MUTED if bool(row.get("full", false)) else NOMINAL_SOFT
		)
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = bool(row.get("full", false))
		button.tooltip_text = "Session full" if button.disabled else "Request joining this session"
		button.pressed.connect(request_server_browser_join.bind(StringName(str(row.get("session_id", &"")))))
		_server_browser_rows.add_child(button)
	if status == &"error":
		var retry := _menu_button("RETRY SERVER LIST", NOMINAL)
		retry.name = "ServerBrowserRetryButton"
		retry.pressed.connect(request_server_browser_refresh)
		_server_browser_rows.add_child(retry)
	_server_browser_page.visible = true


func _add_activity_selection_row(
	parent: VBoxContainer,
	activity_kind: StringName,
	button_text: String,
	detail_text: String
	) -> void:
	var row := VBoxContainer.new()
	row.name = String(activity_kind).to_pascal_case() + "ActivityRow"
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var button := _menu_button(button_text, NOMINAL_SOFT)
	button.name = String(activity_kind).to_pascal_case() + "ActivityButton"
	button.pressed.connect(_request_activity_selection.bind(activity_kind))
	row.add_child(button)
	var detail := _label(detail_text, 10, MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail)
	_activity_selection_buttons[activity_kind] = button


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

	var network_group := _settings_group(left_column, "MULTIPLAYER", "Defaults for the server browser; joining remains caller-owned.")
	_add_text_setting(network_group, &"multiplayer_display_name", "Display name", "Pilot")
	_add_spin_setting(network_group, &"network_default_port", "Default host/join port", 1, 65535, 1, 27101)
	_add_spin_setting(network_group, &"multiplayer_max_players", "Host player capacity", 1, 32, 1, 8)

	var audio_group := _settings_group(right_column, "AUDIO MIX", "Independent linear volume controls.")
	_add_slider_setting(audio_group, &"master_volume", "Master", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"ambience_volume", "Shipyard ambience", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"music_volume", "Music", 0.0, 1.0, 0.01, 1.0)
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
	_add_toggle_setting_with_help(
		accessibility_group,
		&"reduced_dynamic_range",
		"Reduced dynamic range",
		"Limits extreme brightness and contrast changes while preserving readable state cues.",
		false
	)
	_add_toggle_setting(accessibility_group, &"captions_enabled", "Audio cue captions", false)
	_add_toggle_setting_with_help(
		accessibility_group,
		&"show_tutorials",
		"Show first-sortie tutorials",
		"Keep controller-readable onboarding prompts available until you turn them off.",
		true
	)
	_add_caption_preview_setting(accessibility_group)
	_add_controller_glyph_family_setting(accessibility_group)

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
	reset.pressed.connect(_request_settings_reset)
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
	_settings_reset_confirmation = PanelContainer.new()
	_settings_reset_confirmation.name = "SettingsResetConfirmation"
	_settings_reset_confirmation.visible = false
	_settings_reset_confirmation.add_theme_stylebox_override("panel", _border_box(Color("301820"), 6, CAUTION))
	var confirmation_margin := _margin(14, 10, 14, 10)
	_settings_reset_confirmation.add_child(confirmation_margin)
	var confirmation_stack := VBoxContainer.new()
	confirmation_stack.add_theme_constant_override("separation", 6)
	confirmation_margin.add_child(confirmation_stack)
	var confirmation_label := _label("RESET CHANGED SETTINGS?  YOUR UNSAVED EDITS WILL BE DISCARDED.", 10, CAUTION)
	confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_stack.add_child(confirmation_label)
	var confirmation_actions := HBoxContainer.new()
	confirmation_actions.add_theme_constant_override("separation", 6)
	confirmation_stack.add_child(confirmation_actions)
	var confirm_reset := _binding_button("CONFIRM RESET")
	confirm_reset.name = "ConfirmSettingsResetButton"
	confirm_reset.focus_mode = Control.FOCUS_ALL
	confirm_reset.pressed.connect(_confirm_settings_reset)
	confirmation_actions.add_child(confirm_reset)
	var cancel_reset := _binding_button("CANCEL")
	cancel_reset.name = "CancelSettingsResetButton"
	cancel_reset.focus_mode = Control.FOCUS_ALL
	cancel_reset.pressed.connect(_cancel_settings_reset)
	confirmation_actions.add_child(cancel_reset)
	page_stack.add_child(_settings_reset_confirmation)


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
	_binding_option_controls.clear()
	var actions := PackedStringArray()
	for action: StringName in _input_binding_profile.bindings:
		if action == SCREENSHOT_ACTION:
			continue
		actions.append(String(action))
	actions.sort()
	for raw_action: String in actions:
		var action := StringName(raw_action)
		if action == SCREENSHOT_ACTION:
			continue
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
		_add_binding_option_row(parent, action)

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
	_refresh_binding_option_controls()


func _add_binding_option_row(parent: VBoxContainer, action: StringName) -> void:
	var row := HBoxContainer.new()
	row.name = String(action).to_pascal_case() + "OptionsRow"
	row.add_theme_constant_override("separation", 5)
	var deadzone := HSlider.new()
	deadzone.name = String(action).to_pascal_case() + "DeadzoneControl"
	deadzone.min_value = 0.0
	deadzone.max_value = 1.0
	deadzone.step = 0.01
	deadzone.custom_minimum_size = Vector2(112.0, 22.0)
	deadzone.focus_mode = Control.FOCUS_ALL
	deadzone.tooltip_text = "Per-action gamepad deadzone"
	var curve := OptionButton.new()
	curve.name = String(action).to_pascal_case() + "CurveControl"
	curve.add_item("LINEAR")
	curve.add_item("SQUARED")
	curve.focus_mode = Control.FOCUS_ALL
	curve.custom_minimum_size.x = 86.0
	var hold_mode := OptionButton.new()
	hold_mode.name = String(action).to_pascal_case() + "HoldModeControl"
	hold_mode.add_item("HOLD")
	hold_mode.add_item("TOGGLE")
	hold_mode.focus_mode = Control.FOCUS_ALL
	hold_mode.custom_minimum_size.x = 82.0
	row.add_child(_label("OPTIONS", 9, MUTED))
	row.add_child(_label("DZ", 9, MUTED))
	row.add_child(deadzone)
	row.add_child(curve)
	row.add_child(hold_mode)
	parent.add_child(row)
	_binding_option_controls[action] = {"deadzone": deadzone, "curve": curve, "hold_mode": hold_mode}
	deadzone.value_changed.connect(func(_value: float) -> void: _commit_binding_options(action))
	curve.item_selected.connect(func(_index: int) -> void: _commit_binding_options(action))
	hold_mode.item_selected.connect(func(_index: int) -> void: _commit_binding_options(action))


func _refresh_binding_option_controls() -> void:
	if _input_binding_profile == null:
		return
	_updating_settings = true
	for action: StringName in _binding_option_controls:
		var controls := _binding_option_controls[action] as Dictionary
		var options := _input_binding_profile.get_action_options(action)
		var deadzone := controls.deadzone as HSlider
		var curve := controls.curve as OptionButton
		var hold_mode := controls.hold_mode as OptionButton
		deadzone.set_value_no_signal(float(options.get("deadzone", 0.18)))
		curve.select(1 if StringName(options.get("curve", &"linear")) == &"squared" else 0)
		hold_mode.select(1 if StringName(options.get("hold_mode", &"hold")) == &"toggle" else 0)
	_updating_settings = false


func _commit_binding_options(action: StringName) -> void:
	if _updating_settings or _input_remapping_presenter == null:
		return
	var controls := _binding_option_controls.get(action, {}) as Dictionary
	if controls.is_empty():
		return
	var snapshot := _input_remapping_presenter.commit_options(
		action,
		(controls.deadzone as HSlider).value,
		&"squared" if (controls.curve as OptionButton).selected == 1 else &"linear",
		&"toggle" if (controls.hold_mode as OptionButton).selected == 1 else &"hold"
	)
	if snapshot.status == &"committed":
		_commit_input_remapping_snapshot("OPTIONS UPDATED  //  %s" % _input_action_label(action).to_upper())
	else:
		set_settings_status("OPTIONS UPDATE REJECTED", false)

	_refresh_all_binding_rows()


func _scroll_to_input_binding(control: Control) -> void:
	_request_settings_scroll(control)


## Scroll mutation must belong to the currently live Settings hierarchy. Input
## capture and pause-focus restoration can schedule this at the same time as a
## whole HUD subtree is being retired, so the callback owns the liveness check.
func _request_settings_scroll(control: Control) -> void:
	_ensure_settings_control_visible.call_deferred(control)


func _ensure_settings_control_visible(control: Control) -> void:
	if (
		not is_inside_tree()
		or is_queued_for_deletion()
		or not is_instance_valid(_settings_scroll)
		or _settings_scroll.is_queued_for_deletion()
		or not _settings_scroll.is_inside_tree()
		or not is_instance_valid(_settings_page)
		or _settings_page.is_queued_for_deletion()
		or not _settings_page.is_inside_tree()
		or not _settings_page.visible
		or not _settings_page.is_visible_in_tree()
		or not is_instance_valid(control)
		or control.is_queued_for_deletion()
		or not control.is_inside_tree()
		or not control.is_visible_in_tree()
		or not _settings_page.is_ancestor_of(control)
	):
		return
	_settings_scroll.ensure_control_visible(control)


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
	if _runtime_input_rebind_presenter == null:
		return false
	var capture: Dictionary = _runtime_input_rebind_presenter.begin_capture(action)
	if not bool(capture.get("accepted", false)):
		return false
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
		if (
			key.physical_keycode == DEBUG_OVERLAY_KEY
			or (key.physical_keycode == 0 and key.keycode == DEBUG_OVERLAY_KEY)
		):
			set_settings_status("F3 IS RESERVED FOR SCREENSHOT DIAGNOSTICS", false)
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
	if _runtime_input_rebind_presenter == null:
		set_settings_status("BINDING REJECTED", false)
		return
	_runtime_input_rebind_presenter.attach(replacement_base)
	var capture: Dictionary = _runtime_input_rebind_presenter.begin_capture(action)
	var snapshot: Dictionary = _runtime_input_rebind_presenter.capture_replacement(
		action,
		candidate,
		int(capture.get("generation", -1))
	)
	if bool(snapshot.get("accepted", false)):
		_commit_input_rebind_result(
			snapshot,
			"BOUND  //  %s  //  %s" % [
				_input_action_label(action).to_upper(),
				_binding_text(candidate).to_upper(),
			]
		)
		return
	var conflicts := snapshot.get("conflicts", []) as Array
	if snapshot.get("intent", &"") != &"conflict" or conflicts.is_empty():
		set_settings_status("BINDING REJECTED", false)
		_refresh_all_binding_rows()
		return
	_pending_binding_conflict = {
		"action": action,
		"candidate": candidate.duplicate(true),
		"conflicts": conflicts.duplicate(true),
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
	if _pending_binding_conflict.is_empty() or _runtime_input_rebind_presenter == null:
		return
	var action := StringName(_pending_binding_conflict.action)
	var snapshot: Dictionary = _runtime_input_rebind_presenter.resolve_conflict(
		&"replace",
		int(_runtime_input_rebind_presenter.get_snapshot().get("generation", -1))
	)
	if bool(snapshot.get("accepted", false)):
		_commit_input_rebind_result(
			snapshot,
			"CONFLICT REPLACED  //  %s" % _input_action_label(action).to_upper()
		)
	else:
		set_settings_status("CONFLICT REPLACEMENT FAILED", false)
	_cancel_pending_input_conflict(false)


func _cancel_pending_input_conflict(clear_status: bool = true) -> void:
	var return_action := StringName(_pending_binding_conflict.get("action", &""))
	_pending_binding_conflict.clear()
	if _runtime_input_rebind_presenter != null:
		_runtime_input_rebind_presenter.resolve_conflict(
			&"cancel",
			int(_runtime_input_rebind_presenter.get_snapshot().get("generation", -1))
		)
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
	if _runtime_input_rebind_presenter == null or not _input_binding_defaults.bindings.has(action):
		return
	var result: Dictionary = _runtime_input_rebind_presenter.reset_action(
		action,
		int(_runtime_input_rebind_presenter.get_snapshot().get("generation", -1))
	)
	if not bool(result.get("accepted", false)):
		set_settings_status("RESET FAILED  //  %s" % _input_action_label(action).to_upper(), false)
		return
	_commit_input_rebind_result(
		result,
		"DEFAULT RESTORED  //  %s" % _input_action_label(action).to_upper()
	)


func _reset_all_input_bindings() -> void:
	if _runtime_input_rebind_presenter == null:
		return
	var snapshot: Dictionary = _runtime_input_rebind_presenter.reset(
		int(_runtime_input_rebind_presenter.get_snapshot().get("generation", -1))
	)
	if bool(snapshot.get("accepted", false)):
		_commit_input_rebind_result(snapshot, "ALL INPUT BINDINGS RESTORED")
	else:
		set_settings_status("ALL INPUT BINDINGS RESET FAILED", false)


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


func _commit_input_remapping_snapshot(status: String) -> void:
	if _input_remapping_controller == null:
		set_settings_status("INVALID BINDING CONTROLLER", false)
		return
	var profile := _input_remapping_controller.get_profile()
	if profile == null or not _input_rebind_service.is_profile_compatible_with_defaults(profile):
		set_settings_status("INVALID BINDING PROFILE REJECTED", false)
		return
	_input_binding_profile = profile.duplicate_profile()
	_runtime_input_glyph_presenter.refresh(_input_binding_profile)
	_rebuild_input_remapping_presenter(_input_binding_defaults, _input_binding_profile)
	_refresh_input_prompts()
	_refresh_binding_option_controls()
	set_settings_status(status, true)
	setting_change_requested.emit(&"input_binding_profile", _input_binding_profile.duplicate_profile())


func _commit_input_binding_profile(profile: InputBindingProfile, status: String) -> void:
	if (
		profile == null
		or not _input_rebind_service.is_profile_compatible_with_defaults(profile)
	):
		set_settings_status("INVALID BINDING PROFILE REJECTED", false)
		return
	_input_binding_profile = profile.duplicate_profile()
	_runtime_input_glyph_presenter.refresh(_input_binding_profile)
	_rebuild_input_remapping_presenter(_input_binding_defaults, _input_binding_profile)
	_refresh_input_prompts()
	_refresh_binding_option_controls()
	set_settings_status(status, true)
	setting_change_requested.emit(
		&"input_binding_profile",
		_input_binding_profile.duplicate_profile()
	)


func _commit_input_rebind_result(result: Dictionary, status: String) -> void:
	var raw_profile: Variant = result.get("profile", {})
	var profile := InputBindingProfileType.from_dictionary(raw_profile)
	if profile == null:
		set_settings_status("INVALID BINDING PROFILE REJECTED", false)
		return
	_commit_input_binding_profile(profile, status)


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
	# A settings row is also a live prompt surface: show the binding for the
	# currently active device family, including the resolver's deterministic
	# fallback when that family has no binding.  Rendering every retained family
	# here (for example `F / Left Mouse / Right Trigger`) makes controller users
	# read a desktop prompt and makes a remap appear not to take effect until
	# another screen refreshes.  The editor still retains every family in the
	# profile; this is presentation-only selection.
	var resolved: Dictionary = _runtime_input_glyph_presenter.resolve_action(action)
	if bool(resolved.get("valid", false)):
		return str(resolved.get("text", "Unbound Input"))
	return "UNBOUND  //  SELECT TO ADD"


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
		if action == SCREENSHOT_ACTION:
			continue
		actions.append(String(action))
	actions.sort()
	for raw_action: String in actions:
		var action := StringName(raw_action)
		if action == SCREENSHOT_ACTION:
			continue
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


func _add_text_setting(parent: VBoxContainer, key: StringName, title: String, initial: String) -> void:
	var row := VBoxContainer.new()
	row.name = String(key).to_pascal_case() + "Row"
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	row.add_child(_label(title, 11, PRIMARY))
	var edit := LineEdit.new()
	edit.name = String(key).to_pascal_case() + "Control"
	edit.text = initial
	edit.max_length = 32
	edit.placeholder_text = initial
	edit.custom_minimum_size.y = 36.0
	edit.focus_mode = Control.FOCUS_ALL
	edit.add_theme_font_size_override("font_size", 11)
	edit.text_submitted.connect(func(value: String) -> void: _on_setting_value_changed(key, value.strip_edges()))
	edit.focus_exited.connect(func() -> void: _on_setting_value_changed(key, edit.text.strip_edges()))
	row.add_child(edit)
	_settings_controls[key] = edit


func _add_spin_setting(
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
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	row.add_child(_label(title, 11, PRIMARY))
	var spin := SpinBox.new()
	spin.name = String(key).to_pascal_case() + "Control"
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = initial
	spin.custom_minimum_size.y = 36.0
	spin.focus_mode = Control.FOCUS_ALL
	spin.add_theme_font_size_override("font_size", 11)
	spin.value_changed.connect(func(value: float) -> void: _on_setting_value_changed(key, value))
	row.add_child(spin)
	_settings_controls[key] = spin


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


func _add_toggle_setting_with_help(
	parent: VBoxContainer, key: StringName, title: String, help: String, initial: bool
) -> void:
	var row := VBoxContainer.new()
	row.name = String(key).to_pascal_case() + "Row"
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var toggle := CheckButton.new()
	toggle.name = String(key).to_pascal_case() + "Control"
	toggle.text = title
	toggle.button_pressed = initial
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.add_theme_font_size_override("font_size", 11)
	_tint_theme_color(toggle, &"font_color", PRIMARY)
	_tint_theme_color(toggle, &"font_hover_color", NOMINAL_SOFT)
	toggle.toggled.connect(func(value: bool) -> void: _on_setting_value_changed(key, value))
	row.add_child(toggle)
	var hint := _label(help, 10, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hint)
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


func _add_controller_glyph_family_setting(parent: VBoxContainer) -> void:
	var row := VBoxContainer.new()
	row.name = "ControllerGlyphFamilyRow"
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var title := _label("Controller glyph layout", 11, PRIMARY)
	row.add_child(title)
	var selector := OptionButton.new()
	selector.name = "ControllerGlyphFamilyControl"
	selector.custom_minimum_size.y = 38.0
	selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	selector.add_theme_font_size_override("font_size", 11)
	_tint_theme_color(selector, &"font_color", PRIMARY)
	selector.add_theme_stylebox_override("normal", _box(Color("142536"), 4, 1, Color("315367")))
	selector.add_theme_stylebox_override("hover", _border_box(Color("173044"), 4, NOMINAL))
	for option: String in ["Automatic", "Generic", "Xbox", "PlayStation", "Nintendo"]:
		selector.add_item(option)
	selector.select(0)
	selector.item_selected.connect(_on_controller_glyph_family_selected)
	row.add_child(selector)
	var hint := _label("Presentation only — not saved with gameplay settings.", 10, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hint)
	_settings_controls[_CONTROLLER_GLYPH_FAMILY_KEY] = selector


func _add_caption_preview_setting(parent: VBoxContainer) -> void:
	var row := VBoxContainer.new()
	row.name = "CaptionPreviewRow"
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var preview := _menu_button("PREVIEW CAPTION", NOMINAL)
	preview.name = "CaptionPreviewButton"
	preview.custom_minimum_size.y = 34.0
	preview.pressed.connect(preview_caption)
	row.add_child(preview)
	var hint := _label("Shows a sample audio cue as text without playing sound.", 10, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hint)


func preview_caption() -> bool:
	if not _captions_enabled or not is_instance_valid(_caption_presenter):
		set_settings_status("ENABLE AUDIO CUE CAPTIONS TO PREVIEW", false)
		return false
	_caption_preview_revision += 1
	var accepted := apply_caption_presentation_snapshot({
		"schema_version": 1,
		"service_id": &"caption-presentation-service",
		"generation": 0,
		"revision": _caption_preview_revision,
		"visible": true,
		"captions_enabled": true,
		"reduced_flash": _reduced_motion,
		"transition_policy": &"steady_no_flash" if _reduced_motion else &"consumer_standard",
		"caption": {
			"stable_id": &"settings.caption-preview",
			"category": 1,
			"category_id": &"radio",
			"speaker": "Mudds Controller",
			"text": "Preview: docking corridor is clear.",
			"duration_physics_seconds": 4.0,
			"remaining_physics_seconds": 4.0,
			"priority": 50,
			"sequence": _caption_preview_revision,
		},
	})
	if accepted:
		set_settings_status("CAPTION PREVIEW // TEXT ONLY")
	return accepted


func _on_controller_glyph_family_selected(index: int) -> void:
	var families: Array[StringName] = [
		&"",
		InputGlyphResolverType.FAMILY_GAMEPAD_GENERIC,
		InputGlyphResolverType.FAMILY_GAMEPAD_XBOX,
		InputGlyphResolverType.FAMILY_GAMEPAD_PLAYSTATION,
		InputGlyphResolverType.FAMILY_GAMEPAD_NINTENDO,
	]
	if index < 0 or index >= families.size():
		return
	var family := families[index]
	if family.is_empty():
		_input_glyph_resolver.clear_explicit_device_family_override()
	else:
		_input_glyph_resolver.set_explicit_device_family_override(family)
	_refresh_input_prompts()
	set_settings_status(
		"CONTROLLER GLYPHS // %s // PRESENTATION ONLY" % String(family if not family.is_empty() else "AUTOMATIC").to_upper()
	)


func _on_setting_value_changed(key: StringName, value: Variant) -> void:
	if value is float:
		_update_setting_value_label(key, float(value))
		if key == &"ui_scale":
			# Apply the preview locally before the settings owner persists it. This
			# keeps an in-progress accessibility adjustment visible even when the
			# HUD is detached or the owner responds on a later frame.
			set_ui_scale(float(value))
	if not _updating_settings:
		_settings_dirty = true
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
	_activity_selection_page.visible = false
	_server_browser_page.visible = false
	_settings_page.visible = true
	var first_control := _settings_controls.get(&"ship_mouse_sensitivity") as Control
	if first_control != null:
		first_control.grab_focus()


func _show_pause_main() -> void:
	if (
		_pause_main_page == null
		or _activity_selection_page == null
		or _settings_page == null
	):
		return
	var returning_from_activity := _activity_selection_page.visible
	_binding_capture_action = &""
	_cancel_pending_input_conflict(false)
	_pause_main_page.visible = true
	_activity_selection_page.visible = false
	_server_browser_page.visible = false
	_settings_page.visible = false
	var focus_button := _pause_main_page.find_child(
		"ActivityBoardButton" if returning_from_activity else "SettingsOpenButton",
		true,
		false
	) as Button
	if _pause.visible and focus_button != null:
		focus_button.grab_focus()


func _show_activity_selection_page() -> void:
	_pause_main_page.visible = false
	_settings_page.visible = false
	_server_browser_page.visible = false
	_activity_selection_page.visible = true
	_refresh_activity_selection_page(&"")
	var selected_button := _activity_selection_buttons.get(
		_activity_selection_kind
	) as Button
	if selected_button != null:
		selected_button.grab_focus()


## Commits presentation only after GameFlow returns its validated result. A
## rejected button press therefore cannot make the board lie about selection.
func set_activity_selection_state(
	selected_kind: StringName,
	selection_locked: bool,
	status_reason: StringName = &""
	) -> void:
	if selected_kind not in [
		&"timed_race", &"patrol", &"cargo_delivery", &"convoy_escort"
	]:
		return
	_activity_selection_kind = selected_kind
	_activity_selection_locked = selection_locked
	_refresh_activity_selection_page(status_reason)
	if _activity_selection_page != null and _activity_selection_page.visible:
		var selected_button := _activity_selection_buttons.get(
			_activity_selection_kind
		) as Button
		# Activity authority may publish while the retained Main subtree is
		# detaching or re-entering. Do not ask an off-tree control for focus, and
		# do not replace the exact pause-page target retained for re-entry (for
		# example the Back button). A live selection request already originates
		# from one of these activity buttons, so only that focus may follow a
		# changed selection.
		var focus_owner := (
			get_viewport().gui_get_focus_owner()
			if is_inside_tree() and get_viewport() != null
			else null
		)
		if (
			selected_button != null
			and is_instance_valid(focus_owner)
			and _activity_selection_buttons.values().has(focus_owner)
		):
			selected_button.grab_focus()


func _request_activity_selection(activity_kind: StringName) -> void:
	activity_selection_requested.emit(activity_kind)


func _request_planetary_cruise_toggle() -> void:
	if (
		_planetary_cruise_request_dispatch_active
		or not _planetary_cruise_toggle_enabled
		or _planetary_cruise_toggle_serial >= MAX_PLANETARY_CRUISE_TOGGLE_SERIAL
	):
		return
	_planetary_cruise_toggle_serial += 1
	_refresh_planetary_cruise_row()
	_planetary_cruise_request_dispatch_active = true
	planetary_cruise_toggle_requested.emit(_planetary_cruise_toggle_serial)
	_planetary_cruise_request_dispatch_active = false


## Presentation-only ingress from GameFlow's synchronous production report.
## The exact state roster and bounded single-line copy prevent internal binding,
## policy, or lifecycle reasons from leaking through the pause UI.
func set_planetary_cruise_state(
	status_id: StringName,
	status_text: String,
	toggle_enabled: bool,
	engagement_requested: bool,
	) -> bool:
	if status_id not in PLANETARY_CRUISE_STATUS_IDS:
		return false
	var bounded_text := status_text.strip_edges()
	if (
		bounded_text.is_empty()
		or bounded_text.length() > 64
		or bounded_text.contains("\n")
		or bounded_text.contains("\r")
	):
		return false
	var exact_text := {
		&"ready": "READY — EMBER MOON",
		&"queued": "QUEUED",
		&"accelerating": "ACCELERATING",
		&"cruising": "CRUISING",
		&"braking_to_speed": "BRAKING TO SPEED",
		&"braking": "BRAKING",
	}.get(status_id, "") as String
	if (
		(not exact_text.is_empty() and bounded_text != exact_text)
		or (
			status_id == &"unavailable"
			and bounded_text not in PLANETARY_CRUISE_UNAVAILABLE_TEXTS
		)
	):
		return false
	var exact_semantics := (
		(status_id == &"ready" and toggle_enabled and not engagement_requested)
		or (status_id == &"queued" and toggle_enabled and engagement_requested)
		or (
			status_id in [&"accelerating", &"cruising", &"braking_to_speed"]
			and toggle_enabled == engagement_requested
		)
		or (
			status_id in [&"braking", &"unavailable"]
			and not toggle_enabled
			and not engagement_requested
		)
	)
	if not exact_semantics:
		return false
	if (
		_planetary_cruise_status_id == status_id
		and _planetary_cruise_status_text == bounded_text
		and _planetary_cruise_toggle_enabled == toggle_enabled
		and _planetary_cruise_engagement_requested == engagement_requested
	):
		return true
	_planetary_cruise_status_id = status_id
	_planetary_cruise_status_text = bounded_text
	_planetary_cruise_toggle_enabled = toggle_enabled
	_planetary_cruise_engagement_requested = engagement_requested
	_refresh_planetary_cruise_row()
	return true


func _refresh_planetary_cruise_row() -> void:
	if not is_instance_valid(_planetary_cruise_button):
		return
	_planetary_cruise_button.text = (
		"EMBER CRUISE  //  DISENGAGE"
		if _planetary_cruise_engagement_requested
		else "EMBER CRUISE  //  ENGAGE"
	)
	_planetary_cruise_button.disabled = (
		not _planetary_cruise_toggle_enabled
		or _planetary_cruise_toggle_serial >= MAX_PLANETARY_CRUISE_TOGGLE_SERIAL
	)
	if is_instance_valid(_planetary_cruise_status_label):
		_planetary_cruise_status_label.text = _planetary_cruise_status_text
		_planetary_cruise_status_label.modulate = (
			_c(DANGER)
			if _planetary_cruise_status_id == &"unavailable"
			else _c(CAUTION)
			if _planetary_cruise_status_id in [&"braking", &"braking_to_speed"]
			else _c(NOMINAL_SOFT)
		)


## Detached pause-row state and geometry for controller, re-entry, and layout
## evidence. It exposes no Callable and cannot issue a request.
func get_planetary_cruise_presentation_report() -> Dictionary:
	var row := (
		_planetary_cruise_button.get_parent() as Control
		if is_instance_valid(_planetary_cruise_button)
		else null
	)
	return {
		"status_id": _planetary_cruise_status_id,
		"status_text": _planetary_cruise_status_text,
		"toggle_enabled": (
			_planetary_cruise_toggle_enabled
			and _planetary_cruise_toggle_serial
				< MAX_PLANETARY_CRUISE_TOGGLE_SERIAL
		),
		"engagement_requested": _planetary_cruise_engagement_requested,
		"request_serial": _planetary_cruise_toggle_serial,
		"button_text": (
			_planetary_cruise_button.text
			if is_instance_valid(_planetary_cruise_button)
			else ""
		),
		"button_disabled": (
			_planetary_cruise_button.disabled
			if is_instance_valid(_planetary_cruise_button)
			else true
		),
		"button_rect": (
			_planetary_cruise_button.get_global_rect()
			if is_instance_valid(_planetary_cruise_button)
			else Rect2()
		),
		"status_rect": (
			_planetary_cruise_status_label.get_global_rect()
			if is_instance_valid(_planetary_cruise_status_label)
			else Rect2()
		),
		"row_rect": row.get_global_rect() if row != null else Rect2(),
		"pause_main_rect": (
			_pause_main_page.get_global_rect()
			if is_instance_valid(_pause_main_page)
			else Rect2()
		),
		"pause_visible": _pause != null and _pause.visible,
		"pause_main_visible": (
			_pause_main_page != null and _pause_main_page.visible
		),
		"actor_sampling_authority": false,
		"policy_authority": false,
		"movement_authority": false,
		"origin_authority": false,
		"destination_selection_authority": false,
	}.duplicate(true)


func _refresh_activity_selection_page(status_reason: StringName) -> void:
	for raw_kind: Variant in _activity_selection_buttons:
		var activity_kind := StringName(raw_kind)
		var button := _activity_selection_buttons[activity_kind] as Button
		if button == null:
			continue
		var selected := activity_kind == _activity_selection_kind
		button.disabled = _activity_selection_locked and not selected
		var base_text := {
			&"timed_race": "TIMED CINDER RACE",
			&"patrol": "CINDER PATROL",
			&"cargo_delivery": "JOVIAN KIT DELIVERY",
			&"convoy_escort": "EMBERLINE CONVOY ESCORT",
		}.get(activity_kind, String(activity_kind).to_upper()) as String
		button.text = ("SELECTED  //  " if selected else "") + base_text
	if _activity_selection_status_label == null:
		return
	var selected_text := {
		&"timed_race": "TIMED CINDER RACE",
		&"patrol": "CINDER PATROL",
		&"cargo_delivery": "JOVIAN KIT DELIVERY",
		&"convoy_escort": "EMBERLINE CONVOY ESCORT",
	}.get(_activity_selection_kind, String(_activity_selection_kind).to_upper()) as String
	if _activity_selection_locked:
		_activity_selection_status_label.text = "LOCKED  //  CURRENT SORTIE ALREADY STARTED"
		_activity_selection_status_label.modulate = _c(CAUTION)
	elif status_reason in [&"", &"selected", &"already_selected"]:
		_activity_selection_status_label.text = "READY  //  " + selected_text
		_activity_selection_status_label.modulate = _c(NOMINAL_SOFT)
	else:
		_activity_selection_status_label.text = (
			"NOT CHANGED  //  "
			+ str(status_reason).replace("_", " ").to_upper()
		)
		_activity_selection_status_label.modulate = _c(DANGER)


## Detached geometry/state evidence for the production button-route and layout
## regressions. It exposes no callback and cannot mutate selection.
func get_activity_selection_report() -> Dictionary:
	var buttons := {}
	var rows := {}
	for raw_kind: Variant in _activity_selection_buttons:
		var activity_kind := StringName(raw_kind)
		var button := _activity_selection_buttons[activity_kind] as Button
		buttons[activity_kind] = {
			"rect": button.get_global_rect(),
			"text": button.text,
			"disabled": button.disabled,
		}
		rows[activity_kind] = (button.get_parent() as Control).get_global_rect()
	var back := (
		_activity_selection_page.find_child(
			"ActivitySelectionBackButton", true, false
		) as Button
		if _activity_selection_page != null
		else null
	)
	return {
		"selected_activity_kind": _activity_selection_kind,
		"selection_locked": _activity_selection_locked,
		"page_visible": (
			_activity_selection_page != null
			and _activity_selection_page.visible
		),
		"page_rect": (
			_activity_selection_page.get_global_rect()
			if _activity_selection_page != null
			else Rect2()
		),
		"status": (
			_activity_selection_status_label.text
			if _activity_selection_status_label != null
			else ""
		),
		"status_rect": (
			_activity_selection_status_label.get_global_rect()
			if _activity_selection_status_label != null
			else Rect2()
		),
		"back_rect": back.get_global_rect() if back != null else Rect2(),
		"buttons": buttons,
		"row_rects": rows,
	}.duplicate(true)


func _set_help_text(rows: Array) -> void:
	if not is_instance_valid(_help_margin):
		_help_margin = _margin(16, 14, 16, 14)
		_help_margin.name = "HelpMargin"
		_help_panel.add_child(_help_margin)
		_help_stack = VBoxContainer.new()
		_help_stack.name = "HelpRows"
		_help_stack.add_theme_constant_override("separation", 7)
		_help_margin.add_child(_help_stack)
		_help_heading = _label("", 11, CAUTION)
		_help_heading.name = "HelpHeading"
		_help_stack.add_child(_help_heading)
	_help_heading.text = (
		"CONTROLS  //  %s" % _action_prompts([&"toggle_controls_overlay"])
	)
	while _help_row_controls.size() < rows.size():
		var index := _help_row_controls.size()
		var line := HBoxContainer.new()
		line.name = "HelpRow%02d" % (index + 1)
		var key := _label("", 11, NOMINAL_SOFT)
		key.name = "Binding"
		key.custom_minimum_size.x = 92.0
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(key)
		var detail := _label("", 10, MUTED)
		detail.name = "Action"
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(detail)
		_help_stack.add_child(line)
		_help_row_controls.append({
			"line": line,
			"key": key,
			"detail": detail,
		})
	for index in _help_row_controls.size():
		var controls := _help_row_controls[index] as Dictionary
		var line := controls.line as HBoxContainer
		var visible := index < rows.size()
		line.visible = visible
		if not visible:
			continue
		var row := rows[index] as Array
		(controls.key as Label).text = str(row[0])
		(controls.detail as Label).text = str(row[1])
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


func _damage_status_accessible_text(damage_status: String) -> String:
	match damage_status:
		"CRITICAL":
			return "HULL  //  !! CRITICAL !!"
		"DAMAGED":
			return "HULL  //  ! DAMAGED !"
		_:
			return "HULL  //  OK"


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
