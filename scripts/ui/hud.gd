class_name GameHUD
extends CanvasLayer

const FlightPathCueType := preload("res://scripts/ui/flight_path_cue.gd")
const PaletteType := preload("res://scripts/ui/hud_palette.gd")
const InputBindingProfileType := preload("res://scripts/settings/input_binding_profile.gd")
const InputRebindServiceType := preload("res://scripts/settings/input_rebind_service.gd")
const RuntimeInputRemappingControllerType := preload("res://scripts/settings/runtime_input_remapping_controller.gd")
const RuntimeInputRemappingPresenterType := preload("res://scripts/ui/runtime_input_remapping_presenter.gd")
const RuntimeInputRebindPresenterType := preload("res://scripts/ui/runtime_input_rebind_presenter.gd")
const RuntimeDisplaySettingsPresenterType := preload("res://scripts/ui/runtime_display_settings_presenter.gd")
const RuntimeSettingsType := preload("res://scripts/settings/runtime_settings.gd")
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
const HeavyBreachActivityPresenterType := preload("res://scripts/ui/heavy_breach_activity_presenter.gd")
const FirstSortieTutorialPresenterType := preload("res://scripts/ui/first_sortie_tutorial_presenter.gd")
const ServerBrowserPresenterType := preload("res://scripts/ui/server_browser_presenter.gd")
const NearbySectorActivityPresenterType := preload("res://scripts/ui/nearby_sector_activity_presenter.gd")
const BomberPayloadPresenterType := preload("res://scripts/ui/bomber_payload_presenter.gd")
const SafeStartRecoveryPresenterType := preload("res://scripts/ui/safe_start_recovery_presenter.gd")
const CopilotNavigationSupportPresenterType := preload("res://scripts/ui/copilot_navigation_support_presenter.gd")
const ComponentDegradationPresenterType := preload("res://scripts/ui/component_degradation_presenter.gd")
const HeroComponentHudBindingType := preload("res://scripts/ui/hero_component_hud_binding.gd")
const LoadmasterTelemetryPresenterType := preload("res://scripts/ui/loadmaster_telemetry_presenter.gd")

signal start_requested
signal restart_requested
signal activity_selection_requested(activity_kind: StringName)
signal patrol_branch_selection_requested(branch_id: StringName)
signal planetary_cruise_toggle_requested(request_serial: int)
signal planetary_destination_requested(destination_id: StringName, request_serial: int)
signal setting_change_requested(key: StringName, value: Variant)
signal settings_save_requested
signal settings_reset_requested
signal settings_repair_confirmation_requested(confirmation: String)
signal display_settings_keep_requested(generation: int)
signal display_settings_revert_requested(generation: int)
signal orderly_shutdown_requested
signal presentation_intent_requested(kind: StringName, payload: Dictionary)
signal nearby_activity_intent_requested(intent: Dictionary)
signal session_recovery_safe_requested(recovery_token: int, recovery_generation: int)
signal session_recovery_continue_requested(recovery_token: int, recovery_generation: int)
signal session_recovery_discard_requested(recovery_token: int, recovery_generation: int)
signal session_recovery_support_export_requested(recovery_token: int, recovery_generation: int)

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
const SENSOR_RETICLE_CRITICAL_INTEGRITY := 0.40
const SENSOR_RETICLE_MARK_LAYOUT := [
	[Vector2(20.0, 0.0), Vector2(4.0, 12.0)],
	[Vector2(20.0, 32.0), Vector2(4.0, 12.0)],
	[Vector2(0.0, 20.0), Vector2(12.0, 4.0)],
	[Vector2(32.0, 20.0), Vector2(12.0, 4.0)],
]
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
## Autowrapped labels otherwise report a one-pixel minimum width while the HUD
## is hidden during construction. A safe-area position update can make the
## PanelContainer cache that narrow measurement, producing a viewport-tall
## objective card before the first visible layout pass.
const PANEL_OBJECTIVE_CONTENT_WIDTH := PANEL_LEFT_COLUMN_WIDTH - 38.0
const PANEL_BRAND_WIDTH := 262.0
const PANEL_INTERACTION_WIDTH := 424.0
## The toast remains centred, but this width preserves at least 16 logical px of
## contract headroom before it can meet the right-side controls card. It stays
## comfortably above the measured 385 px worst-case content minimum.
const PANEL_TOAST_WIDTH := 498.0
const PANEL_TELEMETRY_WIDTH := 312.0
## The telemetry geometry is authored as one logical band. Construction and
## safe-area relayout must share the same top reservation so the first frame and
## every later viewport update agree about where the occupied band begins.
const PANEL_TELEMETRY_TOP_OFFSET := 250.0
## Keep telemetry just right of the caption host without shrinking either card.
## The authored edge margin still retains 26 logical px before safe-area inset.
const PANEL_TELEMETRY_CAPTION_CLEARANCE := 2.0
const PANEL_HELP_WIDTH := 272.0
const PANEL_SEMANTIC_TRANSCRIPT_WIDTH := 450.0
const PANEL_SEMANTIC_TRANSCRIPT_MIN_HEIGHT := 212.0
## The expanded log uses the lane between the two edge gutters. A small right
## bias preserves clearance from the wider objective gutter at the minimum
## logical width while leaving enough room before HelpPanel.
const PANEL_SEMANTIC_TRANSCRIPT_CENTER_OFFSET_X := 36.0
## Public runtime cards occupy the narrow band below the enemy readout. Their
## body may scroll, but their title and action row never leave this fixed frame.
## The 396 px width keeps two logical pixels clear of both floor gutters; the
## 112 px height ends seven pixels above the camera-space reticle marks.
const PANEL_PUBLIC_STATUS_WIDTH := 396.0
const PANEL_PUBLIC_STATUS_HEIGHT := 112.0
const PANEL_PUBLIC_STATUS_TOP := 204.0
const PANEL_PUBLIC_STATUS_CENTER_OFFSET_X := 20.0
## While a public status card is composed, captions move into the fixed band
## immediately above the interaction prompt. The reusable presenter's ordinary
## 272 px reservation remains unchanged whenever no public card is visible.
const PANEL_COMPOSED_CAPTION_BOTTOM_SAFE_LOGICAL := 126.0
const MIN_UI_SCALE := 0.75
const MAX_UI_SCALE := 1.6
const GAMEPAD_CAPTURE_THRESHOLD := 0.75
const MAX_PLANETARY_CRUISE_TOGGLE_SERIAL := 9_007_199_254_740_991
const MAX_ACTIVITY_REWARD_RECEIPTS := 9_007_199_254_740_991
const ACTIVITY_REWARD_SUMMARY_KEYS := [
	"available",
	"total_receipts",
	"last_receipt_id",
	"last_reward_label",
]
const ACTIVITY_REWARD_LABELS := [
	"Race record accepted",
	"Patrol log accepted",
	"Emberline escort credit logged",
	"Fabrication kits returned",
	"Heavy Breach credit logged",
	"Survey data accepted",
	"Derelict material sample recorded",
	"Debris navigation data recorded",
]
const MAX_SESSION_RECOVERY_TOKEN := 9_007_199_254_740_991
const MAX_SESSION_RECOVERY_PHYSICS_SECONDS := 2_592_000.0
const MAX_SESSION_RECOVERY_UNCLEAN_STARTS := 3
const SESSION_RECOVERY_SNAPSHOT_KEYS := [
	"schema_version",
	"state",
	"session_id",
	"startup_generation",
	"unclean_start_count",
	"last_physics_tick",
	"last_elapsed_physics_seconds",
]
const SESSION_RECOVERY_RECOMMENDATION_KEYS := [
	"available",
	"requires_caller_choice",
	"severity",
	"choices",
	"safe_start_patch",
	"applies_settings",
	"persists_settings",
]
const SESSION_RECOVERY_CHOICES := [
	&"normal_start",
	&"safe_graphics_windowed",
	&"discard",
]
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
const PLANETARY_DESTINATION_CATALOG_ID: StringName = &"mudds_planetary_destinations"
const PLANETARY_DESTINATION_SCHEMA_VERSION := 1
const MAX_PLANETARY_DESTINATIONS := 16
const PLANETARY_DESTINATION_STATUS_IDS := PLANETARY_CRUISE_STATUS_IDS

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

## Release exports use this exact filename stamp. The pause footer only claims
## a source revision when the running executable still carries that stamp;
## renamed packages deliberately fall back to an honest unversioned label.
const BUILD_FILENAME_PATTERN := "^MuddsShipyards-([0-9a-fA-F]{7})\\.exe$"

var _root: Control
var _debug_overlay: DebugOverlay
var _minimap: Minimap
var _intro: Control
var _hud: Control
var _hud_panels: Control
var _pause: Control
var _pause_panels: Control
var _pause_main_page: Control
var _build_identity_label: Label
var _build_identity_snapshot: Dictionary = {}
var _activity_selection_page: Control
var _server_browser_page: Control
var _server_browser_title: Label
var _server_browser_detail: Label
var _server_browser_feedback: Label
var _server_browser_focus_target: Control
var _server_browser_address: LineEdit
var _server_browser_port: LineEdit
var _server_browser_player_name: LineEdit
var _server_browser_results_scroll: ScrollContainer
var _server_browser_rows: VBoxContainer
var _server_browser_actions: HBoxContainer
var _server_browser_filter_controls: Dictionary = {}
var _server_browser_filter_summary: Label
var _server_browser_sort_controls: Dictionary = {}
var _server_browser_sort_summary: Label
var _server_browser_accept_results := true
var _activity_selection_buttons: Dictionary = {}
var _patrol_branch_buttons: Dictionary = {}
var _activity_selection_status_label: Label
var _activity_reward_panel: PanelContainer
var _activity_reward_summary_label: Label
var _activity_reward_latest_label: Label
var _activity_reward_summary := {
	"available": false,
	"total_receipts": 0,
	"last_receipt_id": 0,
	"last_reward_label": "",
}
var _activity_selection_kind: StringName = &"timed_race"
var _patrol_branch_id: StringName = &"relay_sweep"
var _activity_selection_locked := false
var _activity_selection_status_reason: StringName = &""
var _nearby_activity_presenter: RefCounted
var _bomber_payload_presenter: RefCounted
var _nearby_activity_page: Control
var _nearby_activity_rows: VBoxContainer
var _nearby_activity_feedback: Label
var _nearby_activity_snapshot: Dictionary = {}
var _last_nearby_convoy_semantic_transition := ""
var _nearby_convoy_semantic_transition_serial := 0
var _planetary_cruise_button: Button
var _planetary_cruise_status_label: Label
var _planetary_cruise_status_id: StringName = &"unavailable"
var _planetary_cruise_status_text := "UNAVAILABLE — SYSTEM OFFLINE"
var _planetary_cruise_toggle_enabled := false
var _planetary_cruise_engagement_requested := false
var _planetary_cruise_toggle_serial := 0
var _planetary_cruise_request_dispatch_active := false
var _planetary_destination_page: Control
var _planetary_destination_rows: VBoxContainer
var _planetary_destination_back_button: Button
var _planetary_destination_buttons: Dictionary = {}
var _planetary_destination_snapshot: Dictionary = {}
var _settings_page: Control
var _settings_scroll: ScrollContainer
var _settings_controls: Dictionary = {}
var _settings_value_labels: Dictionary = {}
const _CONTROLLER_GLYPH_FAMILY_KEY := &"controller_glyph_family"
var _settings_status_label: Label
var _settings_repair_panel: PanelContainer
var _settings_repair_title: Label
var _settings_repair_detail: Label
var _settings_repair_confirm_button: Button
var _settings_repair_report: Dictionary = {}
var _settings_repair_confirmation := ""
var _display_confirmation_panel: PanelContainer
var _display_confirmation_label: Label
var _display_confirmation_summary_label: Label
var _display_confirmation_result_label: Label
var _display_confirmation_keep_button: Button
var _display_confirmation_revert_button: Button
var _display_confirmation_generation := -1
var _settings_dirty := false
var _settings_reset_confirmation: PanelContainer
## The pause overlay survives a whole-Main detach, but Viewport focus does not.
## Retain the exact in-overlay target so controller users return to the same
## reachable control instead of an open page with no GUI focus owner.
var _pause_reentry_focus_target: Control
var _settings_focus_target: Control
var _updating_settings := false
var _input_rebind_service: InputRebindService
var _input_remapping_controller: RuntimeInputRemappingController
var _input_remapping_presenter: RuntimeInputRemappingPresenter
var _runtime_input_rebind_presenter: RefCounted
var _runtime_display_settings_presenter: RefCounted
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
var _engine_component_hud_stage: StringName = &"nominal"
var _engine_throttle_profile: Dictionary = {}
var _hull_bar: ProgressBar
var _damage_status_label: Label
var _hull_frame_profile: Dictionary = {}
var _weapon_component_hud_stage: StringName = &"nominal"
var _weapon_heat_presentation := 0.0
var _weapon_status_presentation: StringName = &"unavailable"
var _last_engine_power_presentation := 1.0
var _last_weapon_power_presentation := 1.0
var _last_targeting_power_presentation := 1.0
var _last_hull_ratio_presentation := 1.0
var _component_status_label: Label
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
var _help_page_label: Label
var _help_previous_button: Button
var _help_next_button: Button
var _help_close_button: Button
var _help_rows: Array = []
var _help_page_index := 0
const HELP_ROWS_PER_PAGE := 5
## Stable row controls reused when mode, device family, or binding text changes.
## Re-entry reapplies an unchanged snapshot, so rebuilding these nodes there
## would violate whole-Main identity even though the displayed copy is the same.
var _help_row_controls: Array[Dictionary] = []
var _reticle: Control
var _reticle_marks: Array[ColorRect] = []
var _reticle_state_label: Label
var _reticle_state: StringName = &"searching"
var _sensor_reticle_profile: Dictionary = {}
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
const CINDER_BOMBER_DISPLAY_NAME := "CINDER LONG-RANGE BOMBER"
const CINDER_BOMBER_ROLE := "LONG-RANGE BOMBER"

var _palette_mode: StringName = PaletteType.MODE_NONE
var _palette: Dictionary = PaletteType.get_palette(PaletteType.MODE_NONE)
## Every element whose colour is a palette role, recorded as it is built so a
## preset change retints the live HUD without rebuilding or reloading it.
var _palette_targets: Array[Dictionary] = []
var _ui_scale := 1.0
var _reduced_motion := false
var _reduced_flash := false
var _payload_visual_intensity := 2
var _bomber_payload_help_snapshot: Dictionary = {}
var _bomber_payload_help_button: Button
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
var _copilot_navigation_presenter := CopilotNavigationSupportPresenterType.new()
var _component_degradation_presenter := ComponentDegradationPresenterType.new()
var _hero_component_hud_binding := HeroComponentHudBindingType.new()
var _loadmaster_telemetry_presenter := LoadmasterTelemetryPresenterType.new()
var _copilot_help_snapshot: Dictionary = {}
var _loadmaster_help_snapshot: Dictionary = {}
var _semantic_audio_cue_presenter := SemanticAudioCuePresenterType.new()
var _heavy_breach_activity_presenter := HeavyBreachActivityPresenterType.new()
var _semantic_transcript_panel: PanelContainer
var _semantic_transcript_body: Label
var _semantic_transcript_heading: Label
var _semantic_transcript_toggle: Button
var _semantic_transcript_scroll := 0
var _semantic_transcript_tick := 0
var _safe_start_recovery_presenter := SafeStartRecoveryPresenterType.new()
## The interrupted-session choice modal and the post-start receipt card can be
## alive at the same time. Their presenter cursors must therefore be separate:
## changing one surface cannot replace the other surface's available actions.
var _safe_start_status_presenter := SafeStartRecoveryPresenterType.new()
var _recovery_prompt_panel: PanelContainer
var _recovery_prompt_title: Label
var _recovery_prompt_detail: Label
var _recovery_prompt_actions: HBoxContainer
var _recovery_prompt_dismiss_button: Button
var _session_recovery_snapshot: Dictionary = {}
var _session_recovery_recommendation: Dictionary = {}
var _session_recovery_support_summary: Dictionary = {}
var _session_recovery_token := 0
var _session_recovery_generation := 0
var _session_recovery_choice_latched := false
var _session_recovery_action_buttons: Dictionary = {}
var _session_recovery_support_export_latched := false
var _first_sortie_tutorial_presenter := FirstSortieTutorialPresenterType.new()
## Caller-owned tutorial progress remains in GameFlow. This is only the latest
## detached source, retained while visible so local glyph presentation can
## refresh after a device/profile/re-entry change without emitting an intent.
var _first_sortie_tutorial_source_snapshot: Dictionary = {}
var _runtime_status_kind: StringName = &""
## Runtime cards are retained by producer instead of sharing one mutable slot.
## The serial selects the most recently updated ordinary card; bomber has an
## explicit foreground band but never destroys the card behind it.
var _runtime_status_cards: Dictionary = {}
var _runtime_status_card_serial := 0
var _server_browser_presenter := ServerBrowserPresenterType.new()
var _runtime_status_panel: PanelContainer
var _runtime_status_title: Label
var _runtime_status_detail: Label
var _runtime_status_rows: VBoxContainer
var _runtime_status_actions: HBoxContainer
var _runtime_status_scroll: ScrollContainer
var _runtime_status_scroll_content: VBoxContainer
var _bomber_status_panel: PanelContainer
var _bomber_status_title: Label
var _bomber_status_detail: Label
var _bomber_status_rows: VBoxContainer
var _bomber_status_actions: HBoxContainer
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
	if (
		not _first_sortie_tutorial_source_snapshot.is_empty()
		and _runtime_input_glyph_presenter != null
	):
		# The retained prompt may have a different preferred device or binding
		# profile after Main was detached. Reuse the ordinary presentation refresh
		# only after the HUD has rejoined the tree; this emits no tutorial intent.
		call_deferred("_refresh_input_prompts_after_reentry")
	if _component_status_label != null:
		call_deferred("_resume_bound_hero_component_report_after_reentry")


func _exit_tree() -> void:
	if is_queued_for_deletion():
		# A queued glyph/profile refresh must not repopulate presentation state
		# while the HUD is being destroyed. Retained subtree exits deliberately
		# keep these records so re-entry can redraw the current tutorial.
		_first_sortie_tutorial_source_snapshot.clear()
		_runtime_status_cards.clear()
		_runtime_status_kind = &""
		_safe_start_status_presenter.detach()
	if _hero_component_hud_binding != null:
		if is_queued_for_deletion():
			_hero_component_hud_binding.detach()
		else:
			_hero_component_hud_binding.suspend_for_tree_exit()
	clear_session_recovery_notice(false)
	clear_nearby_activity_snapshot()
	clear_semantic_caption_transcript()
	clear_runtime_settings_repair_report()
	_apply_hull_frame_stage(&"healthy", 1.0)
	if _pause == null or not _pause.visible:
		return
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	if is_instance_valid(focus_owner) and is_ancestor_of(focus_owner):
		_pause_reentry_focus_target = focus_owner


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_nearby_activity_presenter = NearbySectorActivityPresenterType.new()
	_bomber_payload_presenter = BomberPayloadPresenterType.new()
	_bomber_payload_presenter.attach()
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
	_runtime_display_settings_presenter = RuntimeDisplaySettingsPresenterType.new()
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
		if _settings_page != null and _settings_page.visible and _settings_page.is_ancestor_of(control):
			_settings_focus_target = control
		if _server_browser_page != null and _server_browser_page.visible and _server_browser_page.is_ancestor_of(control):
			_server_browser_focus_target = control


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
			and _nearby_activity_page != null
			and _nearby_activity_page.visible
		):
			_show_activity_selection_page()
		elif (
			_pause.visible
			and _planetary_destination_page != null
			and _planetary_destination_page.visible
		):
			_show_pause_main()
		elif (
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
		if _help_panel.visible:
			_help_page_index = 0
			_refresh_help_page()
			if is_instance_valid(_help_close_button):
				_help_close_button.grab_focus()


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


func get_minimap_objective_marker_legend() -> Array[Dictionary]:
	if not is_instance_valid(_minimap):
		return []
	return _minimap.get_objective_marker_legend()


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
	if _hero_component_hud_binding != null:
		_hero_component_hud_binding.set_presenting(piloting)
	_reticle.visible = piloting
	if not piloting:
		_apply_hull_frame_stage(&"healthy", 1.0)
	if _flight_cue_layer != null:
		_flight_cue_layer.set_piloting(piloting)
	_set_help_text(_help_rows_with_role_context(_state_mode))


## The controls card for one embodiment. Every row here names a binding that is
## live in that state: a hint for a key that does nothing is the same defect as a
## missing one, only harder to notice.
func _help_rows_for_mode(mode: StringName) -> Array:
	match mode:
		MODE_PILOTING:
			var primary_action_label := (
				"RELEASE PAYLOAD" if _has_cinder_bomber_identity() else "FIRE"
			)
			return [
				[_action_prompts([&"move_forward", &"move_back"]), "FORWARD / REVERSE  //  AUTO POWER"],
				[_look_prompt(), "STEER"],
				[_action_prompts([&"pitch_up", &"pitch_down"]), "PITCH"],
				[_action_prompts([&"move_left", &"move_right"]), "YAW"],
				[_action_prompts([&"roll_left", &"roll_right"]), "ROLL"],
				[_action_prompts([&"fire"]), primary_action_label],
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


func _help_rows_with_role_context(mode: StringName) -> Array:
	var rows := _help_rows_for_mode(mode)
	rows.append(["ACTIVITY BOARD", "PAUSE > ACTIVITY BOARD  //  BROWSE PUBLISHED ACTIVITIES"])
	rows.append(["START ACTIVITY", "[ %s ] INTERACT  //  SELECT A BOARD OR START CONTROL" % _action_prompts([&"interact"])])
	rows.append(["READ OBJECTIVE", "CURRENT OBJECTIVE  //  PROGRESS  //  REWARD PENDING"])
	rows.append(["RECOVER", "FAILURE REASON  //  FOLLOW THE PUBLISHED RECOVERY STEP"])
	rows.append(["VOCABULARY", "STATION DEFENSE  //  HEAVY BREACH  //  CINDER CARGO"])
	rows.append(["NETWORK", "HOST OR JOIN  //  WAIT FOR THE PUBLISHED SESSION STATUS"])
	rows.append(["STATUS", "CONNECTING  //  RECONNECTING  //  CONNECTED"])
	rows.append(["RECOVERY", "REJECTED / DISCONNECTED  //  RETRY OR CANCEL"])
	rows.append(["LEAVE", "CONNECTED  //  DISCONNECT  //  FOLLOW THE FOCUSED ACTION"])
	rows.append(["CINDER CARGO HAULER", "BOARD FROM THE STATION  //  WALK THE CABIN  //  CARGO CREW ROLE"])
	rows.append(["LOADMASTER CABIN", "%s  WALK TO THE LOADMASTER SEAT / CONSOLE" % _action_prompts([&"move_forward", &"move_back", &"move_left", &"move_right"])])
	rows.append(["MANIFEST / ROUTE", "%s  REVIEW PUBLISHED READINESS  //  NO INVENTORY AUTHORITY" % _action_prompts([&"interact"])])
	rows.append(["RELEASE / DISEMBARK", "%s  LEAVE THE LOADMASTER SEAT  //  RETURN TO CABIN" % _action_prompts([&"interact"])])
	if not _copilot_help_snapshot.is_empty():
		rows.append(["COPILOT ROLE", "TARGET / ROUTE REVIEW"])
		rows.append(["CLAIM / RELEASE", "REQUEST ONLY  //  NO HELM AUTHORITY"])
		rows.append(["COPILOT READINESS", "%s  //  NO CARGO AUTHORITY" % str(_copilot_help_snapshot.get("request_state", "UNAVAILABLE"))])
	if not _loadmaster_help_snapshot.is_empty():
		rows.append(["LOADMASTER ROLE", "MANIFEST / ROUTE REVIEW"])
		rows.append(["READINESS", str(_loadmaster_help_snapshot.get("readiness_receipt", "NOT PUBLISHED"))])
		rows.append(["TRANSFER / REWARD", "NO INVENTORY TRANSFER  //  NO REWARD AUTHORITY"])
	return rows


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


func _has_cinder_bomber_identity() -> bool:
	return (
		_active_ship_name == CINDER_BOMBER_DISPLAY_NAME
		and _active_ship_role == CINDER_BOMBER_ROLE
	)


func set_objective(text: String, kicker: String = "CURRENT OBJECTIVE") -> void:
	_objective_kicker.text = kicker
	_objective_label.text = text
	_queue_objective_panel_fit()


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
	if activity_id == &"shipyard_heavy_breach":
		var heavy_breach := _heavy_breach_activity_presenter.present(snapshot)
		activity_text = str(heavy_breach.get("text", ""))
		state_id = StringName(heavy_breach.get("state_id", state_id))
		phase_id = StringName(heavy_breach.get("phase_id", phase_id))
		terminal_reason = StringName(heavy_breach.get("outcome", terminal_reason))
	elif activity_kind == &"convoy_escort":
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
	elif activity_id in [&"cargo_transfer", &"cinder_platform_supply_run"] or activity_kind == &"cargo_transfer":
		var transfer_phase := StringName(snapshot.get("phase_id", snapshot.get("phase", &"board")))
		var transfer_progress := maxi(int(snapshot.get("completed_checkpoint_count", snapshot.get("completed_steps", snapshot.get("step_index", 0)))), 0)
		var transfer_total := maxi(int(snapshot.get("checkpoint_count", snapshot.get("total_steps", 4))), 1)
		var transfer_state := state_id if not state_id.is_empty() else &"available"
		var transfer_step := str(snapshot.get("next_step", "")).strip_edges()
		if transfer_step.is_empty():
			transfer_step = {
				&"board": "BOARD JOVIAN",
				&"land": "LAND AT TERMINAL",
				&"disembark": "DISEMBARK",
				&"terminal": "USE CARGO TERMINAL",
				&"return": "RETURN TO BERTH",
			}.get(transfer_phase, "FOLLOW CARGO ROUTE")
		var transfer_prefix := "[ %s ] " % _action_prompts([&"interact"])
		match transfer_state:
			&"active", &"started":
				activity_text = "CARGO  %s%s  %d/%d" % [transfer_prefix, transfer_step.to_upper(), transfer_progress, transfer_total]
			&"completed", &"complete":
				if bool(snapshot.get("reward_retry_available", false)):
					activity_text = "CARGO  COMPLETE  %d/%d  START TO RETRY REWARD" % [transfer_progress, transfer_total]
				elif bool(snapshot.get("reward_pending", snapshot.get("reward_requested", false))):
					activity_text = "CARGO  COMPLETE  %d/%d  REWARD PENDING" % [transfer_progress, transfer_total]
				else:
					activity_text = "CARGO  COMPLETE  %d/%d" % [transfer_progress, transfer_total]
			&"failed", &"aborted", &"expired":
				activity_text = "CARGO  %s — %s  RECOVER: RETURN TO TERMINAL" % [transfer_state.to_upper(), str(snapshot.get("failure_reason", snapshot.get("terminal_reason", "RETRY"))).replace("_", " ").to_upper()]
			_:
				activity_text = "CARGO  %s%s" % [transfer_prefix, transfer_step.to_upper()]
	elif activity_id == &"cinder_platform_mining_run":
		var mining_elapsed := clampf(
			float(snapshot.get("elapsed_seconds", 0.0)), 0.0,
			maxf(float(snapshot.get("extraction_seconds", 0.0)), 0.0),
		)
		var mining_duration := maxf(
			float(snapshot.get("extraction_seconds", 0.0)), 0.0
		)
		var mining_progress := (
			clampf(mining_elapsed / mining_duration, 0.0, 1.0)
			if mining_duration > 0.0 else 0.0
		)
		var mining_percent := clampi(roundi(mining_progress * 100.0), 0, 100)
		var mining_remaining := maxf(mining_duration - mining_elapsed, 0.0)
		match state_id:
			&"active":
				activity_text = "PLATFORM EXTRACTION  %d%%  HOLD %.1fs" % [
					mining_percent, mining_remaining,
				]
			&"complete", &"completed":
				if bool(snapshot.get("capacity_persisted", false)):
					activity_text = "PLATFORM EXTRACTION  COMPLETE — CAPACITY RECORDED"
				elif bool(snapshot.get("persistence_retry_available", false)):
					activity_text = "PLATFORM EXTRACTION  COMPLETE — START TO RETRY SAVE"
				elif bool(snapshot.get("reward_requested", false)):
					activity_text = "PLATFORM EXTRACTION  COMPLETE — RECEIPT PENDING"
				else:
					activity_text = "PLATFORM EXTRACTION  COMPLETE — FILE ORE SAMPLE"
			&"reset":
				activity_text = "PLATFORM EXTRACTION  INTERRUPTED — RETURN TO MARKER"
			_:
				activity_text = ""
	elif activity_id == &"cinder_debris_beacon_traversal":
		var beacon_next := maxi(int(snapshot.get("next_beacon_index", 0)), 0)
		var beacon_count := maxi(int(snapshot.get("beacon_count", 0)), 0)
		var beacon_cleared := mini(beacon_next, beacon_count)
		var beacon_number := mini(beacon_next + 1, beacon_count)
		var beacon_distance := float(snapshot.get("distance_to_next_beacon", -1.0))
		var beacon_distance_text := (
			"  %.0fm" % beacon_distance
			if is_finite(beacon_distance) and beacon_distance >= 0.0 else ""
		)
		match state_id:
			&"active":
				activity_text = "BEACON RUN  %d/%d CLEARED — NEXT %d/%d%s" % [
					beacon_cleared,
					beacon_count,
					beacon_number,
					beacon_count,
					beacon_distance_text,
				]
			&"complete", &"completed":
				if bool(snapshot.get("reward_committed", false)):
					activity_text = "BEACON RUN  COMPLETE — NAV DATA RECORDED"
				elif bool(snapshot.get("reward_pending", false)):
					activity_text = "BEACON RUN  COMPLETE — REWARD PENDING"
				else:
					activity_text = "BEACON RUN  COMPLETE — CLAIM NAV DATA"
			&"reset":
				activity_text = "BEACON RUN  RESET — RETURN TO BEACON 1"
			_:
				activity_text = ""
	elif activity_id == &"cinder_derelict_structure_scan":
		var scan_elapsed := clampf(
			float(snapshot.get("elapsed_seconds", 0.0)), 0.0,
			maxf(float(snapshot.get("scan_seconds", 0.0)), 0.0),
		)
		var scan_duration := maxf(float(snapshot.get("scan_seconds", 0.0)), 0.0)
		var scan_progress := (
			clampf(scan_elapsed / scan_duration, 0.0, 1.0)
			if scan_duration > 0.0 else 0.0
		)
		var scan_percent := clampi(roundi(scan_progress * 100.0), 0, 100)
		var scan_remaining := maxf(scan_duration - scan_elapsed, 0.0)
		var scan_reason := StringName(snapshot.get("presentation_reason", &""))
		match state_id:
			&"active":
				activity_text = (
					"DERELICT SCAN  PAUSED — RETURN TO MARKER"
					if scan_reason == &"outside_scan_approach"
					else "DERELICT SCAN  %d%%  HOLD %.1fs" % [
						scan_percent, scan_remaining,
					]
				)
			&"complete", &"completed":
				if bool(snapshot.get("discovery_persisted", false)):
					activity_text = "DERELICT SCAN  COMPLETE — DISCOVERY RECORDED"
				elif bool(snapshot.get("reward_committed", false)):
					activity_text = "DERELICT SCAN  COMPLETE — SAMPLE RECORDED"
				elif bool(snapshot.get("reward_pending", false)):
					activity_text = "DERELICT SCAN  COMPLETE — REWARD PENDING"
				else:
					activity_text = "DERELICT SCAN  COMPLETE — CLAIM SAMPLE"
			&"reset":
				activity_text = "DERELICT SCAN  RESET — RETURN TO MARKER"
			_:
				activity_text = ""
	elif activity_id == &"station_defense" or activity_kind == &"station_defense":
		var defense_state := state_id if not state_id.is_empty() else &"available"
		var wave := maxi(int(snapshot.get("current_wave_index", snapshot.get("wave_index", 0))), 0)
		var waves := maxi(int(snapshot.get("wave_count", snapshot.get("total_waves", 1))), 1)
		var assets := snapshot.get("protected_assets", []) as Array
		var damaged := maxi(int(snapshot.get("damaged_asset_count", 0)), 0)
		var destroyed := maxi(int(snapshot.get("destroyed_asset_count", 0)), 0)
		for asset_variant in assets:
			if asset_variant is Dictionary:
				damaged += 1 if int((asset_variant as Dictionary).get("damage_event_count", 0)) > 0 else 0
				destroyed += 1 if bool((asset_variant as Dictionary).get("destroyed", false)) else 0
		var defense_step := str(snapshot.get("next_step", "START DEFENSE WAVE")).strip_edges()
		match defense_state:
			&"active", &"started":
				activity_text = "DEFENSE  WAVE %d/%d  %s  ASSETS DAMAGED %d  DESTROYED %d" % [mini(wave + 1, waves), waves, defense_step.to_upper(), damaged, destroyed]
			&"completed", &"complete":
				activity_text = "DEFENSE  COMPLETE  %d/%d  REWARD %s" % [waves, waves, "PENDING" if bool(snapshot.get("reward_pending", snapshot.get("reward_requested", false))) else "READY"]
			&"failed", &"aborted", &"timed_out":
				activity_text = "DEFENSE  %s — %s  RECOVER: REPAIR PROTECTED ASSETS" % [defense_state.to_upper(), str(snapshot.get("failure_reason", snapshot.get("terminal_reason", "RETRY"))).replace("_", " ").to_upper()]
			_:
				activity_text = "[ %s ] DEFENSE  START WAVE" % _action_prompts([&"interact"])
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
	if activity_id == &"shipyard_heavy_breach":
		_activity_objective_report["heavy_breach"] = _heavy_breach_activity_presenter.present(snapshot)
	elif activity_id == &"cinder_platform_mining_run":
		_activity_objective_report["elapsed_seconds"] = float(
			snapshot.get("elapsed_seconds", 0.0)
		)
		_activity_objective_report["extraction_seconds"] = float(
			snapshot.get("extraction_seconds", 0.0)
		)
		_activity_objective_report["progress_unitless"] = float(
			snapshot.get("progress_unitless", 0.0)
		)
		_activity_objective_report["presentation_reason"] = StringName(
			snapshot.get("presentation_reason", &"")
		)
		_activity_objective_report["capacity_persisted"] = bool(
			snapshot.get("capacity_persisted", false)
		)
		_activity_objective_report["persistence_retry_available"] = bool(
			snapshot.get("persistence_retry_available", false)
		)
	elif activity_id == &"cinder_derelict_structure_scan":
		_activity_objective_report["elapsed_seconds"] = float(
			snapshot.get("elapsed_seconds", 0.0)
		)
		_activity_objective_report["scan_seconds"] = float(
			snapshot.get("scan_seconds", 0.0)
		)
		_activity_objective_report["progress_unitless"] = float(
			snapshot.get("progress_unitless", 0.0)
		)
		_activity_objective_report["presentation_reason"] = StringName(
			snapshot.get("presentation_reason", &"")
		)
		_activity_objective_report["reward_pending"] = bool(
			snapshot.get("reward_pending", false)
		)
		_activity_objective_report["reward_committed"] = bool(
			snapshot.get("reward_committed", false)
		)
		_activity_objective_report["discovery_persisted"] = bool(
			snapshot.get("discovery_persisted", false)
		)
	elif activity_id == &"cinder_debris_beacon_traversal":
		_activity_objective_report["next_beacon_index"] = int(
			snapshot.get("next_beacon_index", 0)
		)
		_activity_objective_report["beacon_count"] = int(
			snapshot.get("beacon_count", 0)
		)
		_activity_objective_report["distance_to_next_beacon"] = float(
			snapshot.get("distance_to_next_beacon", -1.0)
		)
		_activity_objective_report["presentation_reason"] = StringName(
			snapshot.get("presentation_reason", &"")
		)
		_activity_objective_report["reward_pending"] = bool(
			snapshot.get("reward_pending", false)
		)
		_activity_objective_report["reward_committed"] = bool(
			snapshot.get("reward_committed", false)
		)
	if is_instance_valid(_activity_objective_label):
		_activity_objective_label.text = activity_text
		_activity_objective_label.visible = visible
		_queue_objective_panel_fit()


func _queue_objective_panel_fit() -> void:
	if is_instance_valid(_objective_panel):
		_objective_panel.call_deferred(&"reset_size")


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
	_apply_hull_frame_stage(
		_hull_frame_stage(damage_status, hull / maximum_hull),
		hull / maximum_hull
	)
	_state_damage = damage_status
	_state_throttle_reverse = throttle < -0.04
	var engine_power := clampf(float(data.get("engine_power", 1.0)), 0.0, 1.0)
	var weapon_power := clampf(float(data.get("weapon_power", 1.0)), 0.0, 1.0)
	var targeting_power := clampf(float(data.get("targeting_power", 1.0)), 0.0, 1.0)
	_last_engine_power_presentation = engine_power
	_last_weapon_power_presentation = weapon_power
	_last_targeting_power_presentation = targeting_power
	_last_hull_ratio_presentation = clampf(hull / maximum_hull, 0.0, 1.0)
	_weapon_heat_presentation = clampf(float(data.get("weapon_heat", 0.0)), 0.0, 1.0)
	_weapon_status_presentation = StringName(data.get("weapon_status", &"unavailable"))
	_speed_label.text = "%03d" % roundi(speed)
	_altitude_label.text = "%04d M" % roundi(altitude)
	_throttle_bar.value = absf(throttle) * 100.0
	_throttle_label.text = "THROTTLE  //  %s" % (
		"REVERSE" if throttle < -0.04 else ("FORWARD" if throttle > 0.04 else "NEUTRAL")
	)
	_throttle_label.modulate = _c(CAUTION) if throttle < -0.04 else _c(MUTED)
	_hull_bar.value = clampf(hull / maximum_hull, 0.0, 1.0) * 100.0
	_render_damage_status_label()
	_damage_status_label.modulate = _damage_status_color(damage_status)
	set_engine_state(str(data.get("engine_state", "OFFLINE")))
	if _flight_cue_layer != null:
		_flight_cue_layer.update_from_telemetry(data)


## Static geometry on the existing hull-telemetry frame. HeroShip remains the
## sole hull authority; this presenter consumes only its detached telemetry and
## never changes panel bounds, content margins, controls, or the damage flash.
func _apply_hull_frame_stage(stage: StringName, health_ratio: float) -> void:
	if not is_instance_valid(_telemetry_panel):
		return
	var frame := _telemetry_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if frame == null:
		return
	var horizontal_width := 1
	var vertical_width := 1
	var corner_radius := 8
	match stage:
		&"damaged":
			horizontal_width = 3
			vertical_width = 3
			corner_radius = 4
		&"critical":
			horizontal_width = 6
			vertical_width = 2
			corner_radius = 0
		&"destroyed":
			horizontal_width = 0
			vertical_width = 0
			corner_radius = 0
		_:
			stage = &"healthy"
	frame.border_width_left = horizontal_width
	frame.border_width_right = horizontal_width
	frame.border_width_top = vertical_width
	frame.border_width_bottom = vertical_width
	# StyleBoxFlat otherwise derives content padding from border thickness. Keep
	# the authored one-pixel inset stable so the heavier rails never shift or
	# crowd the telemetry controls they surround.
	frame.content_margin_left = 1.0
	frame.content_margin_right = 1.0
	frame.content_margin_top = 1.0
	frame.content_margin_bottom = 1.0
	frame.corner_radius_top_left = corner_radius
	frame.corner_radius_top_right = corner_radius
	frame.corner_radius_bottom_left = corner_radius
	frame.corner_radius_bottom_right = corner_radius
	_hull_frame_profile = {
		"stage": stage,
		"health_ratio": clampf(health_ratio, 0.0, 1.0),
		"horizontal_border_width": horizontal_width,
		"vertical_border_width": vertical_width,
		"corner_radius": corner_radius,
		"panel_size": _telemetry_panel.size,
		"panel_offsets": Vector4(
			_telemetry_panel.offset_left,
			_telemetry_panel.offset_top,
			_telemetry_panel.offset_right,
			_telemetry_panel.offset_bottom
		),
		"content_margins": Vector4(
			frame.content_margin_left,
			frame.content_margin_top,
			frame.content_margin_right,
			frame.content_margin_bottom
		),
		"frame_node_count": 1,
		"added_nodes": 0,
		"changes_panel_bounds": false,
		"changes_content_margins": false,
		"geometry_policy": &"static",
		"flashing": false,
		"reduced_flash_safe": true,
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func get_hull_frame_damage_snapshot() -> Dictionary:
	var snapshot := _hull_frame_profile.duplicate(true)
	snapshot["telemetry_panel_instance_id"] = (
		_telemetry_panel.get_instance_id() if is_instance_valid(_telemetry_panel) else 0
	)
	snapshot["damage_flash_instance_id"] = (
		_damage_flash.get_instance_id() if is_instance_valid(_damage_flash) else 0
	)
	snapshot["damage_flash_modulate"] = (
		_damage_flash.modulate if is_instance_valid(_damage_flash) else Color.TRANSPARENT
	)
	snapshot["reticle_snapshot"] = get_sensor_reticle_component_snapshot()
	return snapshot


func _hull_frame_stage(damage_status: String, health_ratio: float) -> StringName:
	if health_ratio <= 0.0 or damage_status == "DESTROYED":
		return &"destroyed"
	if damage_status == "CRITICAL":
		return &"critical"
	if damage_status == "DAMAGED":
		return &"damaged"
	return &"healthy"


## Displays caller-published copilot support only; this HUD never owns helm,
## route, cargo, or berth authority.
func update_copilot_navigation_support(snapshot: Dictionary) -> void:
	_copilot_help_snapshot = snapshot.duplicate(true)
	_render_runtime_status(_copilot_navigation_presenter.present_snapshot(snapshot), &"copilot")
	_refresh_input_prompts()


func clear_copilot_navigation_support() -> void:
	_copilot_help_snapshot = {}
	_copilot_navigation_presenter.detach()
	clear_runtime_status(&"copilot")
	_refresh_input_prompts()


func update_component_degradation(snapshot: Dictionary) -> void:
	_render_runtime_status(_component_degradation_presenter.present_snapshot(snapshot), &"component")


func clear_component_degradation() -> void:
	_component_degradation_presenter.detach()
	clear_runtime_status(&"component")


func bind_hero_component_ship(ship: Node) -> bool:
	if _hero_component_hud_binding == null:
		return false
	var attached := _hero_component_hud_binding.attach(self, ship)
	_hero_component_hud_binding.set_presenting(_state_mode == MODE_PILOTING)
	return attached


func clear_hero_component_ship() -> void:
	if _hero_component_hud_binding != null:
		_hero_component_hud_binding.detach()


func get_hero_component_hud_snapshot() -> Dictionary:
	return _component_degradation_presenter.get_snapshot()


func _present_bound_hero_component_report(report: Dictionary) -> void:
	var presentation := _component_degradation_presenter.present_hero_report(report)
	_present_sensor_reticle_report(report)
	_present_weapon_component_report(report)
	_present_engine_component_report(report)
	if not is_instance_valid(_component_status_label):
		return
	_component_status_label.text = str(presentation.get("text", ""))
	_component_status_label.visible = bool(presentation.get("visible", false)) and _state_mode == MODE_PILOTING
	var wording := StringName(presentation.get("wording", &"nominal"))
	_component_status_label.modulate = _c(DANGER) if wording in [&"critical", &"failed"] else (
		_c(CAUTION) if wording == &"degraded" else _c(MUTED)
	)


func _clear_bound_hero_component_report() -> void:
	_component_degradation_presenter.detach()
	_apply_sensor_reticle_stage(&"nominal", 1.0, &"cleared")
	_weapon_component_hud_stage = &"nominal"
	_apply_engine_throttle_stage(&"nominal", 1.0, &"cleared")
	_render_damage_status_label()
	if is_instance_valid(_component_status_label):
		_component_status_label.text = ""
		_component_status_label.visible = false


func _resume_bound_hero_component_report_after_reentry() -> void:
	if _hero_component_hud_binding != null:
		_hero_component_hud_binding.resume_after_tree_entry()


## Reshapes only the four retained targeting bars. Component authority remains
## in HeroShip and target/lock authority remains with GameFlow; the existing
## state label is deliberately untouched by this presentation.
func _present_sensor_reticle_report(report: Dictionary) -> void:
	var sensor: Dictionary = {}
	for raw_component in report.get("components", []) as Array:
		if raw_component is Dictionary \
				and StringName((raw_component as Dictionary).get("id", &"")) == &"core_systems":
			sensor = raw_component as Dictionary
			break
	if not bool(report.get("configured", false)) or sensor.is_empty():
		_apply_sensor_reticle_stage(&"nominal", 1.0, &"unavailable")
		return
	var integrity := clampf(float(sensor.get("integrity", 0.0)), 0.0, 1.0)
	var authoritative_stage := StringName(sensor.get("state_id", &"failed"))
	var stage: StringName = &"nominal"
	if authoritative_stage == &"failed":
		stage = &"failed"
	elif integrity <= SENSOR_RETICLE_CRITICAL_INTEGRITY:
		stage = &"critical"
	elif authoritative_stage == &"impaired":
		stage = &"degraded"
	_apply_sensor_reticle_stage(stage, integrity, authoritative_stage)


func _apply_sensor_reticle_stage(
		stage: StringName,
		integrity: float,
		authoritative_stage: StringName
	) -> void:
	var visible_count := 4
	var length := 12.0
	match stage:
		&"degraded":
			length = 8.0
		&"critical":
			visible_count = 2
			length = 6.0
		&"failed":
			visible_count = 0
			length = 0.0
		_:
			stage = &"nominal"
	for index in mini(_reticle_marks.size(), SENSOR_RETICLE_MARK_LAYOUT.size()):
		var mark := _reticle_marks[index]
		var layout := SENSOR_RETICLE_MARK_LAYOUT[index] as Array
		var base_position := layout[0] as Vector2
		var base_size := layout[1] as Vector2
		var vertical := base_size.y > base_size.x
		var mark_size := Vector2(base_size.x, length) if vertical else Vector2(length, base_size.y)
		var mark_position := base_position
		if index == 1:
			mark_position.y = 44.0 - length
		elif index == 3:
			mark_position.x = 44.0 - length
		mark.position = mark_position
		mark.size = mark_size
		# Critical retains the top/bottom axis; failed retains no targeting bars.
		mark.visible = index < visible_count
	_sensor_reticle_profile = {
		"stage": stage,
		"integrity": clampf(integrity, 0.0, 1.0),
		"authoritative_stage": authoritative_stage,
		"visible_mark_count": visible_count,
		"mark_length": length,
		"mark_node_count": _reticle_marks.size(),
		"geometry_policy": &"static",
		"flashing": false,
		"reduced_flash_safe": true,
		"changes_lock_state": false,
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func get_sensor_reticle_component_snapshot() -> Dictionary:
	var snapshot := _sensor_reticle_profile.duplicate(true)
	var marks: Array[Dictionary] = []
	for mark in _reticle_marks:
		marks.append({
			"instance_id": mark.get_instance_id(),
			"position": mark.position,
			"size": mark.size,
			"visible": mark.visible,
		})
	snapshot["marks"] = marks
	snapshot["lock_state"] = _reticle_state
	snapshot["lock_text"] = _reticle_state_label.text if is_instance_valid(_reticle_state_label) else ""
	return snapshot


## Inline geometry on the retained telemetry label. The weaker wing determines
## the static pip silhouette; HeroShip remains the only fire and heat authority.
func _present_weapon_component_report(report: Dictionary) -> void:
	var integrity := 1.0
	var authoritative_state: StringName = &"nominal"
	var found := false
	for raw_component in report.get("components", []) as Array:
		if not raw_component is Dictionary:
			continue
		var component := raw_component as Dictionary
		var component_id := StringName(component.get("id", &""))
		if component_id not in [&"port_wing", &"starboard_wing"]:
			continue
		found = true
		var candidate_integrity := clampf(float(component.get("integrity", 0.0)), 0.0, 1.0)
		if candidate_integrity <= integrity:
			integrity = candidate_integrity
			authoritative_state = StringName(component.get("state_id", &"failed"))
	_weapon_component_hud_stage = &"nominal"
	if found and authoritative_state == &"failed":
		_weapon_component_hud_stage = &"failed"
	elif found and integrity <= 0.40:
		_weapon_component_hud_stage = &"critical"
	elif found and authoritative_state == &"impaired":
		_weapon_component_hud_stage = &"degraded"
	_render_damage_status_label()


func _render_damage_status_label() -> void:
	if not is_instance_valid(_damage_status_label):
		return
	_damage_status_label.text = "%s    ENGINE OUTPUT  %03d%%    WEAPONS  %03d%%    TARGETING  %03d%%    HULL INTEGRITY  %03d%%    WEAPON READY / HEAT  //  %s  %s  %03d%%" % [
		_damage_status_accessible_text(_state_damage),
		roundi(_last_engine_power_presentation * 100.0),
		roundi(_last_weapon_power_presentation * 100.0),
		roundi(_last_targeting_power_presentation * 100.0),
		roundi(_last_hull_ratio_presentation * 100.0),
		_weapon_component_heat_pips(_weapon_component_hud_stage, _weapon_heat_presentation),
		_weapon_readiness_text(_weapon_status_presentation),
		roundi(_weapon_heat_presentation * 100.0),
	]


func _weapon_component_heat_pips(stage: StringName, heat: float) -> String:
	var safe_heat := clampf(heat, 0.0, 1.0)
	if stage == &"failed":
		return "[XXXX]"
	var capacity := 2 if stage == &"critical" else 4
	var filled := clampi(roundi(safe_heat * capacity), 0, capacity)
	var pips := ""
	for index in capacity:
		pips += "#" if index < filled else "."
	match stage:
		&"degraded":
			return "[%s %s]" % [pips.left(2), pips.right(2)]
		&"critical":
			return "[%s  %s]" % [pips.left(1), pips.right(1)]
		_:
			return "[%s]" % pips


func _weapon_readiness_text(status: StringName) -> String:
	return str({
		&"ready": "READY",
		&"cooldown": "CYCLING",
		&"overheated": "OVERHEAT",
		&"offline": "SAFE",
	}.get(status, "UNAVAILABLE"))


func get_weapon_heat_component_hud_snapshot() -> Dictionary:
	return {
		"stage": _weapon_component_hud_stage,
		"pips": _weapon_component_heat_pips(
			_weapon_component_hud_stage, _weapon_heat_presentation
		),
		"heat": _weapon_heat_presentation,
		"readiness": _weapon_readiness_text(_weapon_status_presentation),
		"label_text": _damage_status_label.text if is_instance_valid(_damage_status_label) else "",
		"label_instance_id": (
			_damage_status_label.get_instance_id() if is_instance_valid(_damage_status_label) else 0
		),
		"added_nodes": 0,
		"geometry_policy": &"static",
		"flashing": false,
		"reduced_flash_safe": true,
		"changes_reticle": false,
		"changes_hull_frame": false,
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


## Static scaling of the existing throttle bar around its vertical centre.
## Its Control box and value remain unchanged, so HeroShip alone continues to
## own throttle, braking, engine mobility, and failure behavior.
func _present_engine_component_report(report: Dictionary) -> void:
	var engine: Dictionary = {}
	for raw_component in report.get("components", []) as Array:
		if raw_component is Dictionary \
				and StringName((raw_component as Dictionary).get("id", &"")) == &"engine_bay":
			engine = raw_component as Dictionary
			break
	if not bool(report.get("configured", false)) or engine.is_empty():
		_apply_engine_throttle_stage(&"nominal", 1.0, &"unavailable")
		return
	var integrity := clampf(float(engine.get("integrity", 0.0)), 0.0, 1.0)
	var authoritative_stage := StringName(engine.get("state_id", &"failed"))
	var stage: StringName = &"nominal"
	if authoritative_stage == &"failed":
		stage = &"failed"
	elif integrity <= 0.40:
		stage = &"critical"
	elif authoritative_stage == &"impaired":
		stage = &"degraded"
	_apply_engine_throttle_stage(stage, integrity, authoritative_stage)


func _apply_engine_throttle_stage(
		stage: StringName,
		integrity: float,
		authoritative_stage: StringName
	) -> void:
	_engine_component_hud_stage = stage
	if not is_instance_valid(_throttle_bar):
		return
	var geometry_scale := 1.0
	var corner_radius := 3
	match stage:
		&"degraded":
			geometry_scale = 0.75
			corner_radius = 2
		&"critical":
			geometry_scale = 0.45
			corner_radius = 0
		&"failed":
			geometry_scale = 0.12
			corner_radius = 0
		_:
			stage = &"nominal"
			_engine_component_hud_stage = stage
	var authored_height := maxf(_throttle_bar.custom_minimum_size.y, 8.0)
	_throttle_bar.pivot_offset.y = authored_height * 0.5
	_throttle_bar.scale = Vector2(1.0, geometry_scale)
	for style_name in [&"background", &"fill"]:
		var style := _throttle_bar.get_theme_stylebox(style_name) as StyleBoxFlat
		if style == null:
			continue
		style.corner_radius_top_left = corner_radius
		style.corner_radius_top_right = corner_radius
		style.corner_radius_bottom_left = corner_radius
		style.corner_radius_bottom_right = corner_radius
	_engine_throttle_profile = {
		"stage": stage,
		"integrity": clampf(integrity, 0.0, 1.0),
		"authoritative_stage": authoritative_stage,
		"geometry_scale_y": geometry_scale,
		"corner_radius": corner_radius,
		"layout_size": _throttle_bar.size,
		"custom_minimum_size": _throttle_bar.custom_minimum_size,
		"throttle_value": _throttle_bar.value,
		"bar_node_count": 1,
		"added_nodes": 0,
		"changes_layout_box": false,
		"geometry_policy": &"static",
		"flashing": false,
		"reduced_flash_safe": true,
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func get_engine_throttle_component_hud_snapshot() -> Dictionary:
	var snapshot := _engine_throttle_profile.duplicate(true)
	snapshot["bar_instance_id"] = (
		_throttle_bar.get_instance_id() if is_instance_valid(_throttle_bar) else 0
	)
	snapshot["bar_scale"] = _throttle_bar.scale if is_instance_valid(_throttle_bar) else Vector2.ZERO
	snapshot["bar_value"] = _throttle_bar.value if is_instance_valid(_throttle_bar) else 0.0
	snapshot["bar_rect"] = (
		_throttle_bar.get_global_rect() if is_instance_valid(_throttle_bar) else Rect2()
	)
	snapshot["reticle_snapshot"] = get_sensor_reticle_component_snapshot()
	snapshot["weapon_snapshot"] = get_weapon_heat_component_hud_snapshot()
	snapshot["hull_frame_snapshot"] = get_hull_frame_damage_snapshot()
	return snapshot


func update_loadmaster_telemetry(snapshot: Dictionary) -> void:
	_loadmaster_help_snapshot = snapshot.duplicate(true)
	_render_runtime_status(_loadmaster_telemetry_presenter.present_snapshot(snapshot), &"loadmaster")
	_refresh_input_prompts()


## Explicit caller seam for the Cinder Cargo Hauler. The HUD receives detached
## role/status/manifest records; it does not discover the craft or own claims.
func update_cinder_loadmaster_telemetry(
		craft_id: StringName,
		role: StringName,
		status_snapshot: Dictionary,
		manifest_snapshot: Dictionary = {}
) -> void:
	_loadmaster_help_snapshot = status_snapshot.duplicate(true)
	_loadmaster_help_snapshot["craft_id"] = craft_id
	_loadmaster_help_snapshot["role"] = role
	var presentation: Dictionary = _loadmaster_telemetry_presenter.present_cinder_snapshot(
		craft_id, role, status_snapshot, manifest_snapshot
	)
	_render_runtime_status(presentation, &"loadmaster")
	_refresh_input_prompts()


func clear_loadmaster_telemetry() -> void:
	_loadmaster_help_snapshot = {}
	_loadmaster_telemetry_presenter.detach()
	clear_runtime_status(&"loadmaster")
	_refresh_input_prompts()


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
		if _server_browser_page != null and _server_browser_page.visible:
			_render_server_browser(_server_browser_presenter.close_view())
			_server_browser_accept_results = false
			_server_browser_focus_target = _server_browser_page.find_child(
				"ServerBrowserRefreshButton", true, false
			) as Button
			_server_browser_page.visible = false
			_pause_main_page.visible = true
		_binding_capture_action = &""
		_cancel_pending_input_conflict(false)
		_pause_reentry_focus_target = null
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused and _pause_main_page != null:
		var resume := _pause_main_page.find_child("ResumeButton", true, false) as Button
		if resume != null:
			resume.grab_focus()
	elif not paused and _runtime_status_kind == &"tutorial":
		# The modal relinquished focus. Return to the retained tutorial action
		# without rebuilding an otherwise unchanged foreground card.
		if is_instance_valid(_runtime_status_actions) \
				and _runtime_status_actions.get_child_count() > 0:
			var tutorial_action := _runtime_status_actions.get_child(0) as Control
			if tutorial_action.is_inside_tree() and _runtime_status_can_claim_focus():
				tutorial_action.grab_focus()
			else:
				call_deferred(&"_claim_runtime_status_focus", tutorial_action)


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
	if _nearby_activity_page != null and _nearby_activity_page.visible:
		return _first_nearby_activity_focus_target()
	if _settings_page != null and _settings_page.visible:
		if (
			not _binding_capture_action.is_empty()
			and _binding_buttons.has(_binding_capture_action)
		):
			return _binding_buttons[_binding_capture_action] as Control
		return _settings_controls.get(&"ship_mouse_sensitivity") as Control
	if _activity_selection_page != null and _activity_selection_page.visible:
		return _activity_selection_buttons.get(_activity_selection_kind) as Control
	if (
		_planetary_destination_page != null
		and _planetary_destination_page.visible
	):
		return _first_planetary_destination_focus_target()
	if _pause_main_page != null and _pause_main_page.visible:
		return _pause_main_page.find_child("ResumeButton", true, false) as Control
	return null


## Populates every supplied preference without sending change requests back to
## the settings owner. Missing keys retain the values currently shown.
func set_settings_snapshot(snapshot: Dictionary) -> void:
	_updating_settings = true
	if _runtime_display_settings_presenter != null:
		_runtime_display_settings_presenter.attach_snapshot(snapshot)
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
			elif key == &"reduced_flash":
				set_reduced_flash(bool(value))
		elif control is OptionButton:
			var option := control as OptionButton
			option.select(
				_display_option_index(key, value)
				if key in [&"window_mode", &"display_resolution", &"vsync_mode"]
				else clampi(int(value), 0, option.item_count - 1)
			)
		elif control is LineEdit:
			(control as LineEdit).text = str(value)
	_refresh_accessibility_tooltips()
	_updating_settings = false
	# Binding option widgets live outside the generic settings-control map. A
	# retained or recreated HUD therefore needs an explicit refresh after the
	# canonical profile snapshot has replaced its local presenter state.
	_refresh_binding_option_controls()


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


func show_display_settings_confirmation(generation: int, seconds_remaining: float) -> void:
	if _display_confirmation_panel == null:
		return
	var was_visible := _display_confirmation_panel.visible
	_display_confirmation_generation = generation
	_display_confirmation_panel.visible = true
	_display_confirmation_result_label.visible = false
	_display_confirmation_label.visible = true
	var snapshot := (_runtime_display_settings_presenter.get_snapshot() as Dictionary) if _runtime_display_settings_presenter != null else {}
	var resolution := str(snapshot.get("display_resolution", "unknown")).replace("x", " × ")
	var window_mode := str(snapshot.get("window_mode", "unknown")).capitalize()
	_display_confirmation_summary_label.text = "PENDING DISPLAY  //  %s  //  %s" % [resolution, window_mode]
	_display_confirmation_label.text = "KEEP DISPLAY CHANGE  //  REVERT IN: %.0f SECONDS" % maxf(seconds_remaining, 0.0)
	if is_instance_valid(_display_confirmation_keep_button):
		_display_confirmation_keep_button.visible = true
	if is_instance_valid(_display_confirmation_revert_button):
		_display_confirmation_revert_button.visible = true
	if not was_visible and is_instance_valid(_display_confirmation_keep_button):
		_display_confirmation_keep_button.grab_focus()


func present_display_settings_result(message: String) -> void:
	if _display_confirmation_panel == null:
		return
	_display_confirmation_generation = -1
	_display_confirmation_panel.visible = true
	_display_confirmation_label.visible = false
	_display_confirmation_result_label.text = message.strip_edges()
	_display_confirmation_result_label.visible = not _display_confirmation_result_label.text.is_empty()
	if is_instance_valid(_display_confirmation_keep_button):
		_display_confirmation_keep_button.visible = false
	if is_instance_valid(_display_confirmation_revert_button):
		_display_confirmation_revert_button.visible = false


func clear_display_settings_confirmation(result_message: String = "") -> void:
	if _display_confirmation_panel != null:
		if not result_message.strip_edges().is_empty():
			present_display_settings_result(result_message)
		else:
			_display_confirmation_panel.visible = false
	_display_confirmation_generation = -1


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


## Renders only the detached status published by the caller-owned repair
## binding. This surface never inspects a store, prepares a write, or interprets
## a button press as a successful repair.
func present_runtime_settings_repair_report(report: Dictionary) -> bool:
	if not is_instance_valid(_settings_repair_panel):
		return false
	if report.is_empty() or not bool(report.get("attached", false)):
		clear_runtime_settings_repair_report()
		return false
	# Clear the previous actionable state before parsing anything supplied by the
	# caller. A malformed or future report can therefore never inherit an older
	# token or controller path.
	clear_runtime_settings_repair_report()
	_settings_repair_report = report.duplicate(true)
	_settings_repair_panel.visible = true
	if int(report.get("schema_version", -1)) != 1:
		_show_settings_repair_failure(
			"SETTINGS RECOVERY STATUS UNAVAILABLE",
			"Recovery details use an unsupported format. This HUD made no settings changes."
		)
		return false
	var status_variant: Variant = report.get("last_status", report)
	if status_variant is not Dictionary:
		_show_settings_repair_failure(
			"SETTINGS RECOVERY STATUS UNAVAILABLE",
			"Recovery details were incomplete. This HUD made no settings changes."
		)
		return false
	var status := (status_variant as Dictionary).duplicate(true)
	var reason := StringName(status.get("reason", &""))
	if (
		bool(status.get("accepted", false))
		and reason == &"repair_available"
		and status.get("kind", &"") == &"promote_verified_backup"
		and int(status.get("generation", -1)) > 0
		and not str(status.get("confirmation", "")).is_empty()
		and status.get("preserves_unrelated_payload", false) == true
		and status.get("newer_schema", true) == false
	):
		_settings_repair_confirmation = str(status.get("confirmation", ""))
		_settings_repair_title.text = "SETTINGS BACKUP RECOVERY AVAILABLE"
		_settings_repair_title.modulate = _c(CAUTION)
		_settings_repair_detail.text = (
			"A verified backup can replace the unreadable primary settings file. "
			+ "Nothing will be repaired until you confirm and the settings owner completes the request."
		)
		_settings_repair_confirm_button.visible = true
		_settings_repair_confirm_button.disabled = false
		_configure_settings_repair_focus(true)
		return true
	if reason == &"unsupported_newer_schema":
		_show_settings_repair_failure(
			"NEWER SETTINGS DATA PRESERVED",
			"These settings belong to a newer game version. They were not changed or downgraded."
		)
		return true
	if bool(status.get("repair_authority_cleared", false)) or reason in [
		&"authority_changed", &"authority_changed_during_staging",
		&"directory_sync_failed", &"atomic_replace_failed",
		&"published_verification_failed", &"published_directory_sync_failed",
	]:
		_show_settings_repair_failure(
			"SETTINGS REPAIR RESULT AMBIGUOUS",
			"The repair outcome could not be verified. No success is being reported; inspect the current settings authority before trying again."
		)
		return true
	if reason in [
		&"load_not_repairable", &"settings_payload_missing",
		&"stale_load_generation", &"confirmation_mismatch", &"replay_rejected",
	]:
		_show_settings_repair_failure(
			"SETTINGS RECOVERY BLOCKED",
			"The settings data is corrupt, stale, or cannot be verified. It was left unchanged."
		)
		return true
	_show_settings_repair_failure(
		"SETTINGS RECOVERY STATUS UNAVAILABLE",
		"No verified backup repair can be offered. This HUD made no settings changes."
	)
	return false


func _show_settings_repair_failure(title: String, detail: String) -> void:
	_settings_repair_title.text = title
	_settings_repair_title.modulate = _c(DANGER)
	_settings_repair_detail.text = detail
	_settings_repair_confirm_button.visible = false
	_settings_repair_confirm_button.disabled = true


func _request_settings_repair_confirmation() -> void:
	if _settings_repair_confirmation.is_empty():
		return
	settings_repair_confirmation_requested.emit(_settings_repair_confirmation)


## Caller detach and state reset share this clearing seam. The retained report
## and token are deep-detached presentation state and carry no authority.
func clear_runtime_settings_repair_report() -> void:
	_settings_repair_report.clear()
	_settings_repair_confirmation = ""
	if is_instance_valid(_settings_repair_panel):
		_settings_repair_panel.visible = false
	if is_instance_valid(_settings_repair_confirm_button):
		_settings_repair_confirm_button.visible = false
		_settings_repair_confirm_button.disabled = true
	_configure_settings_repair_focus(false)


func _configure_settings_repair_focus(active: bool) -> void:
	if not is_instance_valid(_settings_page):
		return
	var save := _settings_page.find_child("SettingsSaveButton", true, false) as Button
	var back := _settings_page.find_child("SettingsBackButton", true, false) as Button
	if not is_instance_valid(save) or not is_instance_valid(back):
		return
	if active and is_instance_valid(_settings_repair_confirm_button):
		# Keep the conditional row reachable without pointer input. The surrounding
		# page is scrollable, so focus-following remains safe at large UI scale.
		save.focus_neighbor_bottom = save.get_path_to(_settings_repair_confirm_button)
		_settings_repair_confirm_button.focus_neighbor_top = (
			_settings_repair_confirm_button.get_path_to(save)
		)
		_settings_repair_confirm_button.focus_neighbor_bottom = (
			_settings_repair_confirm_button.get_path_to(back)
		)
		back.focus_neighbor_top = back.get_path_to(_settings_repair_confirm_button)
		return
	save.focus_neighbor_bottom = NodePath()
	back.focus_neighbor_top = NodePath()


func get_runtime_settings_repair_presentation() -> Dictionary:
	return {
		"visible": is_instance_valid(_settings_repair_panel) and _settings_repair_panel.visible,
		"confirmation_available": not _settings_repair_confirmation.is_empty(),
		"report": _settings_repair_report.duplicate(true),
		"authority": {"persistence": false, "store": false, "commit": false},
	}.duplicate(true)


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
	if descriptor.has("reduced_flash"):
		set_reduced_flash(bool(descriptor["reduced_flash"]))
	if descriptor.has("payload_visual_intensity"):
		_payload_visual_intensity = clampi(int(descriptor["payload_visual_intensity"]), 0, 2)
		_refresh_bomber_payload_help()
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
	# Runtime cards are overlays, so they are registered only while composed.
	# This keeps the ordinary always-reserved panel contract unchanged while
	# allowing focused layout checks to measure the exact live card rectangle.
	if is_instance_valid(_runtime_status_panel) and _runtime_status_panel.visible:
		var runtime_effective := maxf(_layout_effective_ui_scale, 0.01)
		var runtime_global := _runtime_status_panel.get_global_rect()
		rects["runtime_status"] = Rect2(
			runtime_global.position / runtime_effective,
			runtime_global.size / runtime_effective
		)
	if is_instance_valid(_bomber_status_panel) and _bomber_status_panel.visible:
		var bomber_effective := maxf(_layout_effective_ui_scale, 0.01)
		var bomber_global := _bomber_status_panel.get_global_rect()
		rects["bomber_payload"] = Rect2(
			bomber_global.position / bomber_effective,
			bomber_global.size / bomber_effective
		)
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
		var readable_safe := Rect2(
			contract_safe.position / maxf(effective, 0.01),
			contract_safe.size / maxf(effective, 0.01)
		)
		status_rect = _compose_public_status_below_transcript(status_rect, readable_safe)
		_runtime_status_panel.position = status_rect.position
		_runtime_status_panel.size = status_rect.size
	if is_instance_valid(_bomber_status_panel):
		var bomber_rect := compute_bomber_payload_panel_rect(
			viewport_size, _safe_area_insets, effective
		)
		var bomber_safe := Rect2(
			contract_safe.position / maxf(effective, 0.01),
			contract_safe.size / maxf(effective, 0.01)
		)
		bomber_rect = _compose_public_status_below_transcript(bomber_rect, bomber_safe)
		_bomber_status_panel.position = bomber_rect.position
		_bomber_status_panel.size = bomber_rect.size
	if is_instance_valid(_recovery_prompt_panel):
		var recovery_rect := compute_session_recovery_panel_rect(
			viewport_size, _safe_area_insets, effective
		)
		var recovery_safe := Rect2(
			contract_safe.position / maxf(effective, 0.01),
			contract_safe.size / maxf(effective, 0.01)
		)
		recovery_rect = _clamp_rect_to_safe_area(recovery_rect, recovery_safe)
		_recovery_prompt_panel.position = recovery_rect.position - logical * 0.5
		_recovery_prompt_panel.size = recovery_rect.size
	if is_instance_valid(_reticle):
		# Camera-space targeting remains one-to-one with the viewport. Its textual
		# state changes independently and must not inherit the HUD readability scale.
		_reticle.scale = Vector2.ONE
	if is_instance_valid(_caption_presenter):
		# CaptionPresenter already reserves the contract's base 32 logical px on
		# each side. Add only the extra readable-band inset introduced by an
		# ultrawide viewport or a larger platform safe area, so the caption stays
		# centred between the same left/right gutters as the scaled HUD panels.
		var caption_base_safe := UltrawideSafeAreaContractType.BASE_SAFE_MARGIN_X
		var caption_host_left := (
			CAPTION_HOST_LEFT_LOGICAL + maxf(safe_left - caption_base_safe, 0.0)
		)
		var caption_host_right := (
			CAPTION_HOST_RIGHT_LOGICAL + maxf(safe_right - caption_base_safe, 0.0)
		)
		_caption_presenter.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_caption_presenter.position = Vector2(caption_host_left * effective, 0.0)
		_caption_presenter.size = Vector2(
			maxf(
				1.0,
				viewport_size.x
					- (caption_host_left + caption_host_right) * effective
			),
			viewport_size.y
		)
		_caption_presenter.set_ui_scale(effective)
		_apply_caption_bottom_reservation(effective)
	return effective


static func compute_runtime_status_panel_rect(
	viewport_size: Vector2, safe_insets: Rect2, effective_scale: float
) -> Rect2:
	var scale := maxf(effective_scale, 0.01)
	var logical := viewport_size / scale
	var left := maxf(safe_insets.position.x, 0.0) / scale
	var right := maxf(safe_insets.size.x, 0.0) / scale
	var top := maxf(safe_insets.position.y, 0.0) / scale
	var center_x := (
		left + (logical.x - left - right) * 0.5
		+ PANEL_PUBLIC_STATUS_CENTER_OFFSET_X
	)
	return Rect2(
		Vector2(
			center_x - PANEL_PUBLIC_STATUS_WIDTH * 0.5,
			top + PANEL_PUBLIC_STATUS_TOP
		),
		Vector2(PANEL_PUBLIC_STATUS_WIDTH, PANEL_PUBLIC_STATUS_HEIGHT)
	)


static func compute_bomber_payload_panel_rect(
	viewport_size: Vector2, safe_insets: Rect2, effective_scale: float
) -> Rect2:
	var scale := maxf(effective_scale, 0.01)
	var logical := viewport_size / scale
	var left := maxf(safe_insets.position.x, 0.0) / scale
	var right := maxf(safe_insets.size.x, 0.0) / scale
	var top := maxf(safe_insets.position.y, 0.0) / scale
	var center_x := (
		left + (logical.x - left - right) * 0.5
		+ PANEL_PUBLIC_STATUS_CENTER_OFFSET_X
	)
	return Rect2(
		Vector2(
			center_x - PANEL_PUBLIC_STATUS_WIDTH * 0.5,
			top + PANEL_PUBLIC_STATUS_TOP
		),
		Vector2(PANEL_PUBLIC_STATUS_WIDTH, PANEL_PUBLIC_STATUS_HEIGHT)
	)


## Keeps the recovery decision in the readable centre band on 16:9 through
## 32:9 viewports. Insets are caller-provided display cutouts, never settings.
static func compute_session_recovery_panel_rect(
	viewport_size: Vector2, safe_insets: Rect2, effective_scale: float
) -> Rect2:
	var scale := maxf(effective_scale, 0.01)
	var logical := viewport_size / scale
	var left := maxf(safe_insets.position.x, 0.0) / scale
	var right := maxf(safe_insets.size.x, 0.0) / scale
	var top := maxf(safe_insets.position.y, 0.0) / scale
	var bottom := maxf(safe_insets.size.y, 0.0) / scale
	var available_width := maxf(360.0, logical.x - left - right - PANEL_MARGIN * 2.0)
	var available_height := maxf(220.0, logical.y - top - bottom - PANEL_MARGIN * 2.0)
	var width := minf(680.0, available_width)
	var height := minf(280.0, available_height)
	var center := Vector2(
		left + (logical.x - left - right) * 0.5,
		top + (logical.y - top - bottom) * 0.5
	)
	return Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height))


static func _clamp_rect_to_safe_area(rect: Rect2, safe: Rect2) -> Rect2:
	var width := minf(rect.size.x, safe.size.x)
	var height := minf(rect.size.y, safe.size.y)
	var position := Vector2(
		clampf(rect.position.x, safe.position.x, safe.end.x - width),
		clampf(rect.position.y, safe.position.y, safe.end.y - height)
	)
	return Rect2(position, Vector2(width, height))


func _compose_public_status_below_transcript(rect: Rect2, safe: Rect2) -> Rect2:
	if is_instance_valid(_semantic_transcript_panel) and _semantic_transcript_panel.visible:
		var transcript_height := maxf(
			PANEL_SEMANTIC_TRANSCRIPT_MIN_HEIGHT,
			_semantic_transcript_panel.size.y
		)
		rect.position.y = maxf(
			rect.position.y,
			safe.position.y + transcript_height + 12.0
		)
	return _clamp_rect_to_safe_area(rect, safe)


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
		_objective_panel.position.x = 28.0 + left
		_objective_panel.position.y = 126.0 + top
	if is_instance_valid(_help_panel):
		_help_panel.offset_left = -(PANEL_HELP_WIDTH + PANEL_MARGIN + right)
		_help_panel.offset_right = -PANEL_MARGIN - right
		# The focusable caption-log button owns the first 42 px of this gutter.
		# Keep the controls card immediately below it so both controls remain in
		# the same readable ultrawide band instead of leaving the button stranded
		# against the physical 32:9 edge.
		_help_panel.offset_top = 44.0 + top
		_help_panel.offset_bottom = 358.0 + top
	if is_instance_valid(_semantic_transcript_toggle):
		_semantic_transcript_toggle.offset_left = -250.0 - right
		_semantic_transcript_toggle.offset_right = -20.0 - right
		_semantic_transcript_toggle.offset_top = top
		_semantic_transcript_toggle.offset_bottom = 42.0 + top
	if is_instance_valid(_semantic_transcript_panel):
		# Centre between asymmetric platform insets, then use the measured bias
		# that clears both top gutters at the 1180x690 logical floor. Keeping the
		# expanded card out of the right gutter prevents it from covering the
		# controls card whose full height must remain readable while the log is open.
		var safe_center_offset := (left - right) * 0.5
		_semantic_transcript_panel.offset_left = (
			safe_center_offset + PANEL_SEMANTIC_TRANSCRIPT_CENTER_OFFSET_X
			- PANEL_SEMANTIC_TRANSCRIPT_WIDTH * 0.5
		)
		_semantic_transcript_panel.offset_right = (
			safe_center_offset + PANEL_SEMANTIC_TRANSCRIPT_CENTER_OFFSET_X
			+ PANEL_SEMANTIC_TRANSCRIPT_WIDTH * 0.5
		)
		_semantic_transcript_panel.offset_top = top
		_semantic_transcript_panel.offset_bottom = top + PANEL_SEMANTIC_TRANSCRIPT_MIN_HEIGHT
	if is_instance_valid(_minimap):
		_minimap.offset_left = PANEL_MARGIN + left
		_minimap.offset_right = PANEL_MARGIN + 240.0 + left
		_minimap.offset_top = -270.0 - bottom
		_minimap.offset_bottom = -PANEL_MARGIN - bottom
	if is_instance_valid(_telemetry_panel):
		_telemetry_panel.offset_left = (
			-(PANEL_TELEMETRY_WIDTH + PANEL_MARGIN + right)
			+ PANEL_TELEMETRY_CAPTION_CLEARANCE
		)
		_telemetry_panel.offset_right = (
			-PANEL_MARGIN - right + PANEL_TELEMETRY_CAPTION_CLEARANCE
		)
		_telemetry_panel.offset_top = -PANEL_TELEMETRY_TOP_OFFSET - bottom
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


func set_reduced_flash(enabled: bool) -> void:
	_reduced_flash = enabled
	_refresh_bomber_payload_help()


func is_reduced_motion() -> bool:
	return _reduced_motion


func get_damage_flash_alpha() -> float:
	return REDUCED_DAMAGE_FLASH_ALPHA if _reduced_motion or _reduced_flash else DAMAGE_FLASH_ALPHA


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
	cue_id: StringName, source: StringName, intensity: float, world_position: Vector3,
	metadata: Dictionary = {}
) -> bool:
	if not _captions_enabled:
		return false
	var presentation := _semantic_audio_cue_presenter.present_cue(
		cue_id, source, intensity, world_position, metadata
	)
	if not bool(presentation.get("accepted", false)):
		return false
	_semantic_transcript_tick = int(metadata.get("tick", _semantic_transcript_tick))
	_refresh_semantic_transcript()
	var severity := StringName(presentation.get("severity", &"low"))
	var priority: int = int(presentation.get("priority", {&"low": 45, &"medium": 70, &"high": 90}.get(severity, 45)))
	var text := "%s %s" % [presentation.get("severity_marker", "○"), presentation.caption]
	var direction := str(presentation.get("direction", "")).strip_edges()
	if not direction.is_empty():
		text += " // %s" % direction
	var distance_band := StringName(presentation.get("distance_band", &""))
	if not distance_band.is_empty():
		text += " // %s" % distance_band.to_upper()
	return _submit_caption_request({
		"category_id": &"system",
		"speaker": str(presentation.source),
		"text": text,
		"duration_physics_seconds": CAPTION_DURATION_PHYSICS_SECONDS,
		"priority": priority,
	})


func set_semantic_transcript_tick(tick: int) -> void:
	_semantic_transcript_tick = maxi(tick, 0)
	_refresh_semantic_transcript()


func clear_semantic_caption_transcript() -> void:
	_semantic_audio_cue_presenter.clear_transcript()
	_semantic_transcript_scroll = 0
	_refresh_semantic_transcript()


func toggle_semantic_caption_transcript() -> void:
	if not is_instance_valid(_semantic_transcript_panel):
		return
	_semantic_transcript_panel.visible = not _semantic_transcript_panel.visible
	_semantic_transcript_toggle.text = "CLOSE CAPTION LOG" if _semantic_transcript_panel.visible else "OPEN CAPTION LOG"
	# Opening the log composes the retained tutorial/status card immediately
	# below it. This is presentation-only relayout; it does not alter either
	# card's retained state, action, or focus owner.
	_apply_ui_scale()


func scroll_semantic_caption_transcript(delta: int) -> void:
	_semantic_transcript_scroll = maxi(0, _semantic_transcript_scroll + delta)
	_refresh_semantic_transcript()


func _refresh_semantic_transcript() -> void:
	if not is_instance_valid(_semantic_transcript_body):
		return
	var entries := _semantic_audio_cue_presenter.get_transcript(_semantic_transcript_tick)
	var lines: PackedStringArray = []
	for entry in entries:
		var direction := str(entry.get("direction", "")).strip_edges()
		var suffix := (" // " + direction) if not direction.is_empty() else ""
		lines.append("%s%s  P%d  +%dT" % [str(entry.get("label", "Cue")), suffix, int(entry.get("priority", 0)), int(entry.get("age_ticks", 0))])
	var start := mini(_semantic_transcript_scroll, maxi(0, lines.size() - 8))
	if is_instance_valid(_semantic_transcript_heading):
		var first := 0 if lines.is_empty() else start + 1
		var last := 0 if lines.is_empty() else mini(start + 8, lines.size())
		_semantic_transcript_heading.text = "SEMANTIC CAPTION LOG  //  %d-%d / %d" % [first, last, lines.size()]
	_semantic_transcript_body.text = "\n".join(lines.slice(start, start + 8)) if not lines.is_empty() else "No semantic captions yet."
	if is_instance_valid(_semantic_transcript_panel) and _semantic_transcript_panel.visible:
		# Containers resolve wrapped multi-line minimums on the next layout turn.
		# Recompose the status stack after that measurement so a dense transcript
		# can grow without ever covering the retained tutorial card.
		call_deferred(&"_apply_ui_scale")


func _build_semantic_transcript_panel() -> void:
	_semantic_transcript_toggle = _menu_button("OPEN CAPTION LOG", NOMINAL)
	_semantic_transcript_toggle.name = "SemanticCaptionTranscriptToggle"
	# This supplemental action shares the right HUD gutter with the controls
	# card. A 42 px target keeps both fully readable at the 690 px logical floor
	# while retaining a comfortably focusable target at the supported scale.
	_semantic_transcript_toggle.custom_minimum_size.y = 42.0
	_semantic_transcript_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_semantic_transcript_toggle.position = Vector2(-250.0, 16.0)
	_semantic_transcript_toggle.size = Vector2(230.0, 34.0)
	_semantic_transcript_toggle.focus_mode = Control.FOCUS_ALL
	_semantic_transcript_toggle.pressed.connect(toggle_semantic_caption_transcript)
	_hud_panels.add_child(_semantic_transcript_toggle)
	_semantic_transcript_panel = PanelContainer.new()
	_semantic_transcript_panel.name = "SemanticCaptionTranscriptPanel"
	_semantic_transcript_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_semantic_transcript_panel.position = Vector2(
		-PANEL_SEMANTIC_TRANSCRIPT_WIDTH * 0.5
			+ PANEL_SEMANTIC_TRANSCRIPT_CENTER_OFFSET_X,
		24.0
	)
	_semantic_transcript_panel.size = Vector2(
		PANEL_SEMANTIC_TRANSCRIPT_WIDTH, PANEL_SEMANTIC_TRANSCRIPT_MIN_HEIGHT
	)
	_semantic_transcript_panel.visible = false
	_hud_panels.add_child(_semantic_transcript_panel)
	var margin := _margin(12, 10, 12, 10)
	_semantic_transcript_panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_semantic_transcript_heading = _label("SEMANTIC CAPTION LOG  //  0-0 / 0", 11, PRIMARY)
	stack.add_child(_semantic_transcript_heading)
	_semantic_transcript_body = _label("No semantic captions yet.", 11, NOMINAL_SOFT)
	_semantic_transcript_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_semantic_transcript_body.custom_minimum_size = Vector2(420.0, 120.0)
	stack.add_child(_semantic_transcript_body)
	var controls := HBoxContainer.new()
	stack.add_child(controls)
	var up := _menu_button("NEWER", NOMINAL)
	up.focus_mode = Control.FOCUS_ALL
	up.pressed.connect(func() -> void: scroll_semantic_caption_transcript(-1))
	controls.add_child(up)
	var down := _menu_button("OLDER", NOMINAL)
	down.focus_mode = Control.FOCUS_ALL
	down.pressed.connect(func() -> void: scroll_semantic_caption_transcript(1))
	controls.add_child(down)
	var clear := _menu_button("CLEAR", MUTED)
	clear.focus_mode = Control.FOCUS_ALL
	clear.pressed.connect(clear_semantic_caption_transcript)
	controls.add_child(clear)
	up.focus_next = down.get_path()
	down.focus_previous = up.get_path()
	down.focus_next = clear.get_path()
	clear.focus_previous = down.get_path()
	clear.focus_next = up.get_path()
	up.focus_previous = clear.get_path()


## Presents detached output from SessionDiagnosticLifecycleBridge. The HUD
## neither queries that bridge nor applies a recommendation: it only retains a
## deep copy and emits a fenced request after an explicit player choice.
func present_session_recovery_notice(
	recovery_snapshot: Dictionary,
	recommendation: Dictionary,
	diagnostic_snapshot: Dictionary = {}
) -> Dictionary:
	if not is_inside_tree() or is_queued_for_deletion():
		return {"accepted": false, "reason": &"hud_detached"}
	var validated := _validate_session_recovery_notice(recovery_snapshot, recommendation)
	if not bool(validated.get("accepted", false)):
		return validated.duplicate(true)
	var token := int(recovery_snapshot.get("session_id", 0))
	var generation := int(recovery_snapshot.get("startup_generation", 0))
	if _session_recovery_generation > generation:
		return {"accepted": false, "reason": &"stale_recovery_generation"}
	if (
		_session_recovery_generation == generation
		and _session_recovery_token > 0
	):
		return {
			"accepted": false,
			"reason": (
				&"replayed_recovery_notice"
				if _session_recovery_token == token
				else &"recovery_token_mismatch"
			),
		}
	_session_recovery_snapshot = recovery_snapshot.duplicate(true)
	_session_recovery_recommendation = recommendation.duplicate(true)
	_session_recovery_support_summary = (
		_safe_start_recovery_presenter.present_diagnostic_support_summary(
			diagnostic_snapshot.duplicate(true), token
		)
	)
	_session_recovery_token = token
	_session_recovery_generation = generation
	_session_recovery_choice_latched = false
	_session_recovery_support_export_latched = false
	_render_session_recovery_notice()
	return {
		"accepted": true,
		"reason": &"recovery_notice_presented",
		"recovery_token": token,
		"recovery_generation": generation,
		"automatic_choice": false,
		"presentation_only": true,
	}.duplicate(true)


func _validate_session_recovery_notice(
	recovery_snapshot: Dictionary,
	recommendation: Dictionary
) -> Dictionary:
	if not _has_exact_string_keys(recovery_snapshot, SESSION_RECOVERY_SNAPSHOT_KEYS):
		return {"accepted": false, "reason": &"recovery_snapshot_schema_invalid"}
	var schema: Variant = recovery_snapshot.get("schema_version")
	var state: Variant = recovery_snapshot.get("state")
	var token_value: Variant = recovery_snapshot.get("session_id")
	var generation_value: Variant = recovery_snapshot.get("startup_generation")
	var count_value: Variant = recovery_snapshot.get("unclean_start_count")
	var tick_value: Variant = recovery_snapshot.get("last_physics_tick")
	var elapsed_value: Variant = recovery_snapshot.get("last_elapsed_physics_seconds")
	if (
		schema is not int
		or token_value is not int
		or generation_value is not int
		or count_value is not int
		or tick_value is not int
		or elapsed_value is not float
		or not (state is String or state is StringName)
	):
		return {"accepted": false, "reason": &"recovery_snapshot_types_invalid"}
	var token := token_value as int
	var generation := generation_value as int
	var count := count_value as int
	var physics_tick := tick_value as int
	var elapsed := elapsed_value as float
	if (
		schema != 1
		or StringName(str(state)) != &"running"
		or token <= 0
		or token > MAX_SESSION_RECOVERY_TOKEN
		or generation <= 0
		or generation > MAX_SESSION_RECOVERY_TOKEN
		or count < 0
		or count > MAX_SESSION_RECOVERY_UNCLEAN_STARTS
		or physics_tick < 0
		or physics_tick > MAX_SESSION_RECOVERY_TOKEN
		or is_nan(elapsed)
		or is_inf(elapsed)
		or elapsed < 0.0
		or elapsed > MAX_SESSION_RECOVERY_PHYSICS_SECONDS
	):
		return {"accepted": false, "reason": &"recovery_snapshot_values_invalid"}
	if not _has_exact_string_keys(
		recommendation, SESSION_RECOVERY_RECOMMENDATION_KEYS
	):
		return {"accepted": false, "reason": &"recovery_recommendation_schema_invalid"}
	var available: Variant = recommendation.get("available")
	var caller_choice: Variant = recommendation.get("requires_caller_choice")
	var severity_value: Variant = recommendation.get("severity")
	var choices_value: Variant = recommendation.get("choices")
	var patch_value: Variant = recommendation.get("safe_start_patch")
	var applies: Variant = recommendation.get("applies_settings")
	var persists: Variant = recommendation.get("persists_settings")
	if (
		available is not bool
		or caller_choice is not bool
		or not (severity_value is String or severity_value is StringName)
		or choices_value is not Array
		or patch_value is not Dictionary
		or applies is not bool
		or persists is not bool
	):
		return {"accepted": false, "reason": &"recovery_recommendation_types_invalid"}
	var severity := StringName(str(severity_value))
	if (
		available != true
		or caller_choice != true
		or severity not in [&"review_prior_session", &"safe_graphics_recommended"]
		or (
			severity == &"safe_graphics_recommended"
			and count < MAX_SESSION_RECOVERY_UNCLEAN_STARTS
		)
		or (
			severity == &"review_prior_session"
			and count >= MAX_SESSION_RECOVERY_UNCLEAN_STARTS
		)
		or applies != false
		or persists != false
	):
		return {"accepted": false, "reason": &"recovery_recommendation_values_invalid"}
	var choices := choices_value as Array
	if choices.size() != SESSION_RECOVERY_CHOICES.size():
		return {"accepted": false, "reason": &"recovery_choices_invalid"}
	for index in SESSION_RECOVERY_CHOICES.size():
		var choice: Variant = choices[index]
		if (
			not (choice is String or choice is StringName)
			or StringName(str(choice)) != SESSION_RECOVERY_CHOICES[index]
		):
			return {"accepted": false, "reason": &"recovery_choices_invalid"}
	return {"accepted": true, "reason": &"recovery_notice_valid"}


func _has_exact_string_keys(source: Dictionary, expected: Array) -> bool:
	if source.size() != expected.size():
		return false
	for key: Variant in source.keys():
		if key is not String or key not in expected:
			return false
	return true


func _render_session_recovery_notice() -> void:
	if not is_instance_valid(_recovery_prompt_panel):
		return
	_recovery_prompt_title.text = "INTERRUPTED SESSION"
	var ticks := _session_recovery_snapshot.get("last_physics_tick") as int
	var elapsed := _session_recovery_snapshot.get("last_elapsed_physics_seconds") as float
	var unfinished := _session_recovery_snapshot.get("unclean_start_count") as int
	var advice := StringName(str(_session_recovery_recommendation.get("severity", &"review_prior_session")))
	_recovery_prompt_detail.text = (
		"Session %d did not close cleanly after %d physics ticks (%.2f seconds).\n"
		+ "Unfinished starts: %d  //  Guidance: %s\n"
		+ "Nothing will change until you choose an action."
	) % [
		_session_recovery_token,
		ticks,
		elapsed,
		unfinished,
		str(advice).replace("_", " ").to_upper(),
	]
	if bool(_session_recovery_support_summary.get("available", false)):
		_recovery_prompt_detail.text += (
			"\nSupport summary: session %d  //  retained events: %d  //  last mode: %s"
			% [
				int(_session_recovery_support_summary.get("session_id", 0)),
				int(_session_recovery_support_summary.get("retained_event_count", 0)),
				str(_session_recovery_support_summary.get("last_runtime_mode", &"NOT_RETAINED")),
			]
		)
	_clear_recovery_action_controls()
	for action_data: Dictionary in [
		{"id": &"safe", "label": "Safe Recovery", "role": CAUTION},
		{"id": &"continue", "label": "Continue", "role": NOMINAL},
		{"id": &"discard", "label": "Discard", "role": MUTED},
		{"id": &"support_export", "label": "Save Support Summary", "role": MUTED},
	]:
		var action := StringName(action_data.id)
		var button := _menu_button(str(action_data.label), StringName(action_data.role))
		button.name = "%sSessionRecoveryButton" % str(action).to_pascal_case()
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = "%s interrupted session %d" % [str(action_data.label), _session_recovery_token]
		button.pressed.connect(
			_request_session_recovery_action.bind(
				action, _session_recovery_token, _session_recovery_generation
			)
		)
		_recovery_prompt_actions.add_child(button)
		_session_recovery_action_buttons[action] = button
	var ordered: Array[Button] = [
		_session_recovery_action_buttons[&"safe"] as Button,
		_session_recovery_action_buttons[&"continue"] as Button,
		_session_recovery_action_buttons[&"discard"] as Button,
		_session_recovery_action_buttons[&"support_export"] as Button,
	]
	for index in ordered.size():
		ordered[index].focus_neighbor_left = ordered[index].get_path_to(ordered[maxi(0, index - 1)])
		ordered[index].focus_neighbor_right = ordered[index].get_path_to(ordered[mini(ordered.size() - 1, index + 1)])
	_recovery_prompt_dismiss_button.visible = false
	_recovery_prompt_panel.visible = true
	# The interrupted-session decision is the blocking owner. Keyed cards remain
	# retained behind it, but neither their controls nor bomber's dedicated band
	# may compete with this modal for visibility or focus.
	_refresh_runtime_status_cards()
	ordered[0].grab_focus()


func _request_session_recovery_action(
	action: StringName,
	recovery_token: int,
	recovery_generation: int
) -> bool:
	if (
		not is_inside_tree()
		or is_queued_for_deletion()
		or not is_instance_valid(_recovery_prompt_panel)
		or not _recovery_prompt_panel.visible
		or recovery_token != _session_recovery_token
		or recovery_generation != _session_recovery_generation
		or _session_recovery_choice_latched
	):
		return false
	if action not in [&"safe", &"continue", &"discard", &"support_export"]:
		return false
	if action == &"support_export":
		if _session_recovery_support_export_latched:
			return false
		_session_recovery_support_export_latched = true
		var export_button := _session_recovery_action_buttons.get(&"support_export") as Button
		if is_instance_valid(export_button):
			export_button.disabled = true
		session_recovery_support_export_requested.emit(recovery_token, recovery_generation)
		return true
	_session_recovery_choice_latched = true
	for button_variant: Variant in _session_recovery_action_buttons.values():
		var button := button_variant as Button
		if is_instance_valid(button):
			button.disabled = true
	match action:
		&"safe":
			session_recovery_safe_requested.emit(recovery_token, recovery_generation)
		&"continue":
			session_recovery_continue_requested.emit(recovery_token, recovery_generation)
		&"discard":
			session_recovery_discard_requested.emit(recovery_token, recovery_generation)
	return true


## Bounded presentation-only feedback for the one receipt-fenced local export.
## Paths, snapshots, and sink errors never enter the HUD copy.
func present_session_recovery_support_export_result(
		recovery_token: int,
		recovery_generation: int,
		accepted: bool
		) -> Dictionary:
	if (
		recovery_token != _session_recovery_token
		or recovery_generation != _session_recovery_generation
		or not _session_recovery_support_export_latched
	):
		return {"accepted": false, "reason": &"stale_recovery_fence"}
	if not is_instance_valid(_recovery_prompt_detail):
		return {"accepted": false, "reason": &"recovery_prompt_unavailable"}
	_recovery_prompt_detail.text += (
		"\nSupport summary %s."
		% ("saved locally" if accepted else "could not be saved")
	)
	return {
		"accepted": true,
		"reason": &"support_export_result_presented",
		"export_accepted": accepted,
		"presentation_only": true,
	}.duplicate(true)


func clear_session_recovery_notice(restore_runtime_cards: bool = true) -> void:
	var was_visible := (
		is_instance_valid(_recovery_prompt_panel)
		and _recovery_prompt_panel.visible
	)
	_session_recovery_snapshot.clear()
	_session_recovery_recommendation.clear()
	_session_recovery_support_summary.clear()
	_session_recovery_token = 0
	_session_recovery_generation = 0
	_session_recovery_choice_latched = false
	_session_recovery_support_export_latched = false
	_clear_recovery_action_controls()
	if is_instance_valid(_recovery_prompt_dismiss_button):
		_recovery_prompt_dismiss_button.visible = true
	if is_instance_valid(_recovery_prompt_panel):
		_recovery_prompt_panel.visible = false
	if restore_runtime_cards and was_visible:
		_refresh_runtime_status_cards()


func reset_session_recovery_notice() -> void:
	clear_session_recovery_notice()


func _clear_recovery_action_controls() -> void:
	_session_recovery_action_buttons.clear()
	if not is_instance_valid(_recovery_prompt_actions):
		return
	for child in _recovery_prompt_actions.get_children():
		_recovery_prompt_actions.remove_child(child)
		child.free()


func get_session_recovery_notice_snapshot() -> Dictionary:
	return {
		"active": _session_recovery_token > 0 and _session_recovery_generation > 0,
		"recovery_token": _session_recovery_token,
		"recovery_generation": _session_recovery_generation,
		"choice_latched": _session_recovery_choice_latched,
		"support_export_latched": _session_recovery_support_export_latched,
		"recovery_snapshot": _session_recovery_snapshot.duplicate(true),
		"recommendation": _session_recovery_recommendation.duplicate(true),
		"support_summary": _session_recovery_support_summary.duplicate(true),
		"reduced_motion": _reduced_motion,
		"automatic_choice": false,
		"authority": {
			"filesystem": false,
			"diagnostic_store": false,
			"settings": false,
			"gameplay": false,
		},
	}.duplicate(true)


func apply_recovery_choice_snapshot(snapshot: Dictionary) -> Dictionary:
	clear_session_recovery_notice(false)
	var presentation := _safe_start_recovery_presenter.present_recovery_choice(snapshot)
	if not is_instance_valid(_recovery_prompt_panel):
		return presentation
	_recovery_prompt_panel.visible = presentation.get("status", &"hidden") == &"choice_required"
	if not _recovery_prompt_panel.visible:
		_refresh_runtime_status_cards()
		return presentation
	_recovery_prompt_title.text = "RECOVERY CHOICE REQUIRED"
	_recovery_prompt_detail.text = "%s\n%s" % [presentation.get("message", ""), presentation.get("summary", "")]
	var action_buttons: Array[Button] = []
	for action_variant in presentation.get("actions", []) as Array:
		var action := action_variant as Dictionary
		var button := _menu_button(str(action.get("label", "Choice")), NOMINAL)
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = "Recovery choice: " + str(action.get("label", "Choice"))
		var choice := StringName(action.get("id", &""))
		button.pressed.connect(func() -> void: _request_recovery_choice(choice))
		_recovery_prompt_actions.add_child(button)
		action_buttons.append(button)
	if not action_buttons.is_empty():
		for index in action_buttons.size():
			var button := action_buttons[index]
			button.focus_neighbor_left = button.get_path_to(action_buttons[maxi(0, index - 1)])
			button.focus_neighbor_right = button.get_path_to(action_buttons[mini(action_buttons.size() - 1, index + 1)])
		_refresh_runtime_status_cards()
		action_buttons[0].grab_focus()
	if is_instance_valid(_recovery_prompt_dismiss_button) and not action_buttons.is_empty():
		_recovery_prompt_dismiss_button.visible = true
		_recovery_prompt_dismiss_button.focus_neighbor_left = _recovery_prompt_dismiss_button.get_path_to(action_buttons.back())
		action_buttons.back().focus_neighbor_right = action_buttons.back().get_path_to(_recovery_prompt_dismiss_button)
	return presentation


func _request_recovery_choice(choice: StringName) -> void:
	var intent := _safe_start_recovery_presenter.request_choice(choice)
	if bool(intent.get("accepted", false)):
		presentation_intent_requested.emit(&"recovery", intent)


func dismiss_recovery_prompt() -> void:
	if is_instance_valid(_recovery_prompt_panel) and _recovery_prompt_panel.visible:
		_recovery_prompt_panel.visible = false
		_refresh_runtime_status_cards()


func get_recovery_prompt_snapshot() -> Dictionary:
	return _safe_start_recovery_presenter.get_snapshot()


func _build_recovery_prompt_panel() -> void:
	_recovery_prompt_panel = PanelContainer.new()
	_recovery_prompt_panel.name = "RecoveryChoicePrompt"
	_recovery_prompt_panel.set_anchors_preset(Control.PRESET_CENTER)
	_recovery_prompt_panel.position = Vector2(-300.0, -120.0)
	_recovery_prompt_panel.size = Vector2(600.0, 240.0)
	_recovery_prompt_panel.visible = false
	_hud_panels.add_child(_recovery_prompt_panel)
	var margin := _margin(18, 16, 18, 16)
	_recovery_prompt_panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_recovery_prompt_title = _label("RECOVERY CHOICE REQUIRED", 16, PRIMARY)
	stack.add_child(_recovery_prompt_title)
	_recovery_prompt_detail = _label("", 12, NOMINAL_SOFT)
	_recovery_prompt_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recovery_prompt_detail.custom_minimum_size = Vector2(550.0, 70.0)
	stack.add_child(_recovery_prompt_detail)
	_recovery_prompt_actions = HBoxContainer.new()
	_recovery_prompt_actions.add_theme_constant_override("separation", 8)
	stack.add_child(_recovery_prompt_actions)
	_recovery_prompt_dismiss_button = _menu_button("DISMISS", MUTED)
	_recovery_prompt_dismiss_button.focus_mode = Control.FOCUS_ALL
	_recovery_prompt_dismiss_button.tooltip_text = "Dismiss recovery choices"
	_recovery_prompt_dismiss_button.pressed.connect(dismiss_recovery_prompt)
	stack.add_child(_recovery_prompt_dismiss_button)


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
		"reduced_flash": _reduced_flash,
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
	_objective_panel.position = Vector2(28.0, 126.0)
	_objective_panel.custom_minimum_size = Vector2(PANEL_LEFT_COLUMN_WIDTH, 112.0)
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
	_objective_label.custom_minimum_size.x = PANEL_OBJECTIVE_CONTENT_WIDTH
	objective_stack.add_child(_objective_label)
	_activity_objective_label = _label("", 10, NOMINAL_SOFT)
	_activity_objective_label.name = "ActivityObjectiveLabel"
	_activity_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_activity_objective_label.custom_minimum_size.x = PANEL_OBJECTIVE_CONTENT_WIDTH
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
	# MIN_LOGICAL_WIDTH. 424 still clears the longest authored prompt ("Clear the
	# berth before requesting a return approach", 417 px) on one line, and the
	# label wraps rather than widening the panel if a longer one is ever added.
	_interaction_panel = PanelContainer.new()
	_interaction_panel.name = "InteractionPanel"
	_interaction_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_panel.offset_left = -PANEL_INTERACTION_WIDTH * 0.5
	_interaction_panel.offset_right = PANEL_INTERACTION_WIDTH * 0.5
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
	for rect_data: Array in SENSOR_RETICLE_MARK_LAYOUT:
		var mark := ColorRect.new()
		mark.position = rect_data[0]
		mark.size = rect_data[1]
		_tint_rect(mark, NOMINAL)
		_reticle.add_child(mark)
		_reticle_marks.append(mark)
	_reticle_state_label = _label("[...]  SEARCHING", 10, NOMINAL_SOFT)
	_reticle_state_label.position = Vector2(-46.0, 48.0)
	_reticle_state_label.size = Vector2(136.0, 22.0)
	_reticle_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.add_child(_reticle_state_label)
	_reticle.visible = false
	_apply_sensor_reticle_stage(&"nominal", 1.0, &"nominal")

	_build_telemetry()
	_build_enemy_status()
	_build_toast()
	_build_runtime_status_panel()
	_build_bomber_status_panel()
	_build_semantic_transcript_panel()
	_build_recovery_prompt_panel()
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
	_telemetry_panel.offset_left = (
		-(PANEL_TELEMETRY_WIDTH + PANEL_MARGIN) + PANEL_TELEMETRY_CAPTION_CLEARANCE
	)
	_telemetry_panel.offset_right = -PANEL_MARGIN + PANEL_TELEMETRY_CAPTION_CLEARANCE
	# Component, weapon-heat, and hull lines now coexist in this retained card.
	# The extra height occupies the empty right gutter below HelpPanel and keeps
	# every bar/label in a distinct row without approaching the centre reticle.
	_telemetry_panel.offset_top = -PANEL_TELEMETRY_TOP_OFFSET
	_telemetry_panel.offset_bottom = -PANEL_MARGIN
	_telemetry_panel.add_theme_stylebox_override("panel", _box(PANEL, 8, 1, Color("315367")))
	_hud_panels.add_child(_telemetry_panel)
	_apply_hull_frame_stage(&"healthy", 1.0)
	var margin := _margin(18, 15, 18, 15)
	_telemetry_panel.add_child(margin)
	var stack := VBoxContainer.new()
	# The retained component and weapon rows share this fixed-height panel. Four
	# pixels keeps each authored control on its own row without changing the hull
	# frame bounds or squeezing the bars into adjacent labels.
	stack.add_theme_constant_override("separation", 4)
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
	_throttle_bar.custom_minimum_size.x = PANEL_TELEMETRY_WIDTH - 36.0
	_throttle_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_throttle_bar)
	_apply_engine_throttle_stage(&"nominal", 1.0, &"nominal")
	stack.add_child(_label("HULL INTEGRITY", 9, MUTED))
	_hull_bar = _bar(CAUTION)
	_hull_bar.value = 100.0
	stack.add_child(_hull_bar)
	_damage_status_label = _label("HULL  //  OK    ENGINE OUTPUT  100%", 9, MUTED)
	_damage_status_label.custom_minimum_size.x = PANEL_TELEMETRY_WIDTH - 36.0
	_damage_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_damage_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_damage_status_label)
	_component_status_label = _label("", 9, MUTED)
	_component_status_label.name = "ComponentStatus"
	_component_status_label.visible = false
	stack.add_child(_component_status_label)
	_telemetry_panel.visible = false


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_left = -PANEL_TOAST_WIDTH * 0.5
	_toast_panel.offset_right = PANEL_TOAST_WIDTH * 0.5
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
	_runtime_status_panel.position = Vector2(
		-PANEL_PUBLIC_STATUS_WIDTH * 0.5, -PANEL_PUBLIC_STATUS_HEIGHT * 0.5
	)
	_runtime_status_panel.size = Vector2(
		PANEL_PUBLIC_STATUS_WIDTH, PANEL_PUBLIC_STATUS_HEIGHT
	)
	_runtime_status_panel.add_theme_stylebox_override("panel", _border_box(PANEL_SOLID, 8, NOMINAL))
	_runtime_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_panels.add_child(_runtime_status_panel)
	var margin := _margin(14, 8, 14, 8)
	_runtime_status_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	_runtime_status_title = _label("STATUS", 16, PRIMARY)
	_runtime_status_title.clip_text = true
	_runtime_status_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(_runtime_status_title)
	_runtime_status_scroll = ScrollContainer.new()
	_runtime_status_scroll.name = "RuntimeStatusBodyScroll"
	_runtime_status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_runtime_status_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_runtime_status_scroll.follow_focus = true
	_runtime_status_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runtime_status_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_runtime_status_scroll)
	_runtime_status_scroll_content = VBoxContainer.new()
	_runtime_status_scroll_content.name = "RuntimeStatusScrollableContent"
	_runtime_status_scroll_content.add_theme_constant_override("separation", 4)
	_runtime_status_scroll_content.custom_minimum_size.x = 350.0
	_runtime_status_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runtime_status_scroll.add_child(_runtime_status_scroll_content)
	_runtime_status_detail = _label("", 11, NOMINAL_SOFT)
	_runtime_status_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_runtime_status_detail.custom_minimum_size.x = 350.0
	_runtime_status_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runtime_status_scroll_content.add_child(_runtime_status_detail)
	_runtime_status_rows = VBoxContainer.new()
	_runtime_status_rows.add_theme_constant_override("separation", 4)
	_runtime_status_scroll_content.add_child(_runtime_status_rows)
	_runtime_status_actions = HBoxContainer.new()
	_runtime_status_actions.add_theme_constant_override("separation", 8)
	stack.add_child(_runtime_status_actions)
	_runtime_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runtime_status_panel.visible = false


func _build_bomber_status_panel() -> void:
	_bomber_status_panel = PanelContainer.new()
	_bomber_status_panel.name = "BomberPayloadStatusPanel"
	_bomber_status_panel.set_anchors_preset(Control.PRESET_CENTER)
	_bomber_status_panel.position = Vector2(
		-PANEL_PUBLIC_STATUS_WIDTH * 0.5, -PANEL_PUBLIC_STATUS_HEIGHT * 0.5
	)
	_bomber_status_panel.size = Vector2(
		PANEL_PUBLIC_STATUS_WIDTH, PANEL_PUBLIC_STATUS_HEIGHT
	)
	_bomber_status_panel.add_theme_stylebox_override(
		"panel", _border_box(Color("101c2bf2"), 8, CAUTION)
	)
	_bomber_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_panels.add_child(_bomber_status_panel)
	var margin := _margin(14, 3, 14, 3)
	_bomber_status_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	_bomber_status_title = _label("BOMBER PAYLOAD", 16, PRIMARY)
	_bomber_status_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bomber_status_title.clip_text = true
	_bomber_status_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_bomber_status_title)
	_bomber_status_actions = HBoxContainer.new()
	_bomber_status_actions.add_theme_constant_override("separation", 8)
	header.add_child(_bomber_status_actions)
	_bomber_status_detail = _label("", 9, NOMINAL_SOFT)
	_bomber_status_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bomber_status_detail.custom_minimum_size.x = 350.0
	_bomber_status_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bomber_status_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_bomber_status_detail)
	_bomber_status_rows = VBoxContainer.new()
	_bomber_status_rows.add_theme_constant_override("separation", 4)
	stack.add_child(_bomber_status_rows)
	_bomber_status_panel.visible = false


func update_network_session_status(snapshot: Dictionary) -> void:
	_render_runtime_status(_network_status_presenter.present_snapshot(snapshot), &"network")


func update_crew_role_status(snapshot: Dictionary) -> void:
	var presentation := _crew_role_presenter.present_snapshot(snapshot)
	var gunner := presentation.get("gunner_weapon", {}) as Dictionary
	if not gunner.is_empty():
		var actions := presentation.get("actions", []) as Array
		var fire_action := StringName(gunner.get("fire_action", &"fire"))
		var aim_action := StringName(gunner.get("aim_action", &"aim"))
		var fire: Dictionary = _runtime_input_glyph_presenter.resolve_action(fire_action)
		var aim: Dictionary = _runtime_input_glyph_presenter.resolve_action(aim_action)
		if bool(fire.get("valid", false)):
			actions.append({"id": &"gunner_fire", "label": "[%s] GUNNER FIRE" % str(fire.get("text", "INPUT")), "focusable": true})
		if bool(aim.get("valid", false)):
			actions.append({"id": &"gunner_aim", "label": "[%s] GUNNER AIM" % str(aim.get("text", "INPUT")), "focusable": true})
		presentation["actions"] = actions
	_render_runtime_status(presentation, &"crew")


func update_surface_route_status(snapshot: Dictionary) -> void:
	_render_runtime_status(_surface_route_presenter.present_snapshot(snapshot), &"surface")


## Retires the currently accepted lifecycle cursor and hides its public row.
## Callers cannot use this presentation cleanup to move an actor or advance a
## route; a later attachment must supply a fresh cursor before it can repaint.
func detach_surface_route_status() -> Dictionary:
	var detached := _surface_route_presenter.detach()
	if _runtime_status_kind == &"surface":
		clear_runtime_status()
	return detached


func update_atmospheric_entry_status(snapshot: Dictionary) -> void:
	_render_runtime_status(_entry_guidance_presenter.present_snapshot(snapshot), &"entry")


func apply_bomber_payload_snapshot(snapshot: Dictionary) -> bool:
	if _bomber_payload_presenter == null:
		_bomber_payload_presenter = BomberPayloadPresenterType.new()
		_bomber_payload_presenter.attach()
	elif not bool(_bomber_payload_presenter.get_snapshot().get("attached", false)):
		_bomber_payload_presenter.attach()
	var presentation: Dictionary = _bomber_payload_presenter.present_snapshot(snapshot)
	if not bool(presentation.get("attached", false)):
		return false
	presentation["action_id"] = StringName(str(snapshot.get("action_id", &"fire")))
	_decorate_bomber_payload_action_prompt(presentation)
	presentation["message"] = "%s  %s" % [presentation.get("marker", ""), presentation.get("message", "")]
	_bomber_payload_help_snapshot = presentation.duplicate(true)
	_refresh_bomber_payload_help()
	_render_runtime_status(presentation, &"bomber")
	return true


func request_bomber_payload_release() -> Dictionary:
	if _bomber_payload_presenter == null:
		return {"accepted": false, "reason": &"detached", "presentation_only": true, "input_authority": false}
	var result: Dictionary = _bomber_payload_presenter.request(&"release_payload")
	if bool(result.get("accepted", false)):
		presentation_intent_requested.emit(&"bomber", result)
	return result


func clear_bomber_payload_status() -> void:
	if _bomber_payload_presenter != null:
		_bomber_payload_presenter.detach()
	clear_runtime_status(&"bomber")
	_bomber_payload_help_snapshot = {}
	_refresh_bomber_payload_help()


func apply_first_sortie_tutorial_snapshot(
		snapshot: Dictionary, activate_runtime_card: bool = true
) -> bool:
	# Prompt/glyph redraws may update an existing retained tutorial but cannot
	# recreate one after the complete runtime surface was explicitly cleared.
	if not activate_runtime_card and not _runtime_status_cards.has(&"tutorial"):
		return false
	var caller_snapshot := snapshot.duplicate(true)
	caller_snapshot["input_family"] = _tutorial_input_family()
	caller_snapshot["glyphs"] = _tutorial_glyphs()
	var presentation := _first_sortie_tutorial_presenter.present_snapshot(caller_snapshot)
	if not bool(presentation.get("accepted", false)):
		if StringName(presentation.get("reason", &"")) in [
			&"actor_unavailable", &"session_unavailable", &"tutorials_disabled",
		]:
			clear_first_sortie_tutorial(StringName(presentation.get("reason", &"detached")))
		return false
	_first_sortie_tutorial_source_snapshot = snapshot.duplicate(true)
	var runtime_snapshot := presentation.duplicate(true)
	runtime_snapshot["message"] = presentation.prompt
	runtime_snapshot["detail"] = presentation.prompt
	set_runtime_status_card(&"tutorial", runtime_snapshot, activate_runtime_card)
	return true


func _apply_show_tutorials_setting(enabled: bool) -> void:
	if enabled:
		return
	# RuntimeSettings owns whether tutorials are enabled. The HUD only retires
	# its current presentation so an already-visible prompt cannot outlive the
	# setting or reappear when this retained layer re-enters the tree.
	clear_first_sortie_tutorial(&"tutorials_disabled")


func dismiss_first_sortie_tutorial() -> Dictionary:
	return request_first_sortie_tutorial_action(&"dismiss")


func request_first_sortie_tutorial_action(action: StringName) -> Dictionary:
	var result := _first_sortie_tutorial_presenter.request(action)
	if bool(result.get("accepted", false)):
		presentation_intent_requested.emit(&"tutorial", result)
		if action == &"dismiss":
			clear_first_sortie_tutorial(&"dismissed")
	return result


func clear_first_sortie_tutorial(reason: StringName = &"detached") -> Dictionary:
	var result := _first_sortie_tutorial_presenter.detach(reason)
	_first_sortie_tutorial_source_snapshot.clear()
	if _runtime_status_kind == &"tutorial" and is_instance_valid(_runtime_status_panel):
		var viewport := get_viewport()
		var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
		if is_instance_valid(focus_owner) \
				and _runtime_status_panel.is_ancestor_of(focus_owner):
			focus_owner.release_focus()
	clear_runtime_status(&"tutorial")
	return result


## Presents SafeStartProductionRecovery's detached report as one ordinary keyed
## card. Store-unavailable and malformed-but-cursor-valid reports intentionally
## remain visible; a valid report with no fallback is acknowledged silently.
func apply_safe_start_recovery_report(
		report: Dictionary, activate_runtime_card: bool = true
		) -> Dictionary:
	var presentation := _safe_start_status_presenter.present_receipt(
		report.duplicate(true)
	)
	# Presenter rejections are wrappers around the last accepted snapshot. They
	# must never repaint or clear that snapshot.
	if presentation.has("snapshot"):
		return presentation.duplicate(true)
	var status := StringName(str(presentation.get("status", &"invalid")))
	if status == &"no_fallback_active":
		clear_runtime_status(&"safe_start_recovery")
		return {
			"accepted": true,
			"reason": &"safe_start_recovery_suppressed",
			"visible": false,
			"generation": int(presentation.get("generation", -1)),
			"revision": int(presentation.get("revision", -1)),
			"presentation_only": true,
			"settings_authority": false,
			"filesystem_authority": false,
		}.duplicate(true)
	if not set_runtime_status_card(
		&"safe_start_recovery", presentation, activate_runtime_card
	):
		return {
			"accepted": false,
			"reason": &"safe_start_recovery_card_unavailable",
			"generation": int(presentation.get("generation", -1)),
			"revision": int(presentation.get("revision", -1)),
			"presentation_only": true,
			"settings_authority": false,
			"filesystem_authority": false,
		}.duplicate(true)
	return {
		"accepted": true,
		"reason": &"safe_start_recovery_presented",
		"visible": true,
		"generation": int(presentation.get("generation", -1)),
		"revision": int(presentation.get("revision", -1)),
		"status": status,
		"presentation_only": true,
		"settings_authority": false,
		"filesystem_authority": false,
	}.duplicate(true)


func request_safe_start_recovery_action(
		action: StringName, generation: int, revision: int
		) -> Dictionary:
	var intent: Dictionary
	match action:
		&"restore":
			intent = _safe_start_status_presenter.request_restore(generation, revision)
		&"keep_safe":
			intent = _safe_start_status_presenter.request_keep_safe(generation, revision)
		_:
			return {
				"accepted": false,
				"reason": &"action_unavailable",
				"action": action,
				"generation": generation,
				"revision": revision,
				"presentation_only": true,
				"settings_authority": false,
				"filesystem_authority": false,
			}.duplicate(true)
	if bool(intent.get("accepted", false)):
		presentation_intent_requested.emit(
			&"safe_start_recovery", intent.duplicate(true)
		)
	return intent.duplicate(true)


func clear_safe_start_recovery_status() -> void:
	_safe_start_status_presenter.detach()
	clear_runtime_status(&"safe_start_recovery")


## Clears one producer's retained card. An empty source preserves the legacy
## public signature and explicitly clears the complete runtime-card surface.
func clear_runtime_status(source: StringName = &"") -> void:
	if source.is_empty():
		var previous_foreground := _runtime_status_foreground_kind()
		_runtime_status_cards.clear()
		# This is the only producer-side redraw source kept outside the card map.
		# Retire it with the legacy all-clear so a later device/profile refresh
		# cannot silently resurrect a cleared tutorial.
		_first_sortie_tutorial_source_snapshot.clear()
		if not previous_foreground.is_empty():
			_refresh_runtime_status_cards()
		return
	_clear_runtime_status_card_source(source)


## Source-keyed presentation seam for HUD-only producers. The detached payload
## and stable key are retained independently; no producer can replace another
## producer's backing card merely by drawing.
func set_runtime_status_card(
		source: StringName, snapshot: Dictionary, activate: bool = true
) -> bool:
	if source.is_empty():
		return false
	var previous_foreground := _runtime_status_foreground_kind()
	var content_changed := true
	if _runtime_status_cards.has(source):
		var previous_card := _runtime_status_cards[source] as Dictionary
		content_changed = (
			(previous_card.get("snapshot", {}) as Dictionary) != snapshot
		)
	if not activate:
		if not _runtime_status_cards.has(source):
			return false
		var retained_card := _runtime_status_cards[source] as Dictionary
		retained_card["snapshot"] = snapshot.duplicate(true)
		_runtime_status_cards[source] = retained_card
	else:
		_runtime_status_card_serial += 1
		_runtime_status_cards[source] = {
			"serial": _runtime_status_card_serial,
			"snapshot": snapshot.duplicate(true),
		}
	var next_foreground := _runtime_status_foreground_kind()
	# Rebuild only when publication changed the visible owner or its payload.
	# Bomber priority can keep an activating ordinary update in the background;
	# that retained mutation must not replace the focused bomber action control.
	if (
		next_foreground != previous_foreground
		or (next_foreground == source and content_changed)
	):
		_refresh_runtime_status_cards()
	return true


func clear_runtime_status_card(source: StringName) -> bool:
	if source.is_empty():
		return false
	return _clear_runtime_status_card_source(source)


func _clear_runtime_status_card_source(source: StringName) -> bool:
	if not _runtime_status_cards.has(source):
		return false
	var previous_foreground := _runtime_status_foreground_kind()
	_runtime_status_cards.erase(source)
	if _runtime_status_foreground_kind() != previous_foreground:
		_refresh_runtime_status_cards()
	return true


func _render_runtime_status(snapshot: Dictionary, kind: StringName) -> void:
	set_runtime_status_card(kind, snapshot)


func _refresh_runtime_status_cards() -> void:
	_hide_runtime_status_panel(_runtime_status_panel)
	_hide_runtime_status_panel(_bomber_status_panel)
	_runtime_status_kind = _runtime_status_foreground_kind()
	if is_instance_valid(_recovery_prompt_panel) and _recovery_prompt_panel.visible:
		_apply_caption_bottom_reservation(_layout_effective_ui_scale)
		return
	if _runtime_status_kind == &"bomber":
		var bomber_card := _runtime_status_cards[&"bomber"] as Dictionary
		_render_runtime_status_card(
			bomber_card.get("snapshot", {}) as Dictionary,
			&"bomber",
			_bomber_status_panel,
			_bomber_status_title,
			_bomber_status_detail,
			_bomber_status_rows,
			_bomber_status_actions
		)
		_apply_caption_bottom_reservation(_layout_effective_ui_scale)
		return
	if _runtime_status_kind.is_empty():
		_apply_caption_bottom_reservation(_layout_effective_ui_scale)
		return
	var selected_card := _runtime_status_cards[_runtime_status_kind] as Dictionary
	_render_runtime_status_card(
		selected_card.get("snapshot", {}) as Dictionary,
		_runtime_status_kind,
		_runtime_status_panel,
		_runtime_status_title,
		_runtime_status_detail,
		_runtime_status_rows,
		_runtime_status_actions
	)
	_apply_caption_bottom_reservation(_layout_effective_ui_scale)


func _apply_caption_bottom_reservation(effective_scale: float) -> void:
	if not is_instance_valid(_caption_presenter):
		return
	var logical_margin := CAPTION_BOTTOM_SAFE_LOGICAL
	if (
		(is_instance_valid(_runtime_status_panel) and _runtime_status_panel.visible)
		or (is_instance_valid(_bomber_status_panel) and _bomber_status_panel.visible)
	):
		logical_margin = PANEL_COMPOSED_CAPTION_BOTTOM_SAFE_LOGICAL
	_caption_presenter.set_host_bottom_safe_margin(
		logical_margin * maxf(effective_scale, 0.01)
	)


func _runtime_status_foreground_kind() -> StringName:
	if _runtime_status_cards.has(&"bomber"):
		return &"bomber"
	var selected_kind: StringName = &""
	var selected_serial := -1
	for source_variant: Variant in _runtime_status_cards.keys():
		var source := StringName(str(source_variant))
		if source == &"bomber":
			continue
		var card := _runtime_status_cards[source] as Dictionary
		var serial := int(card.get("serial", -1))
		if serial > selected_serial:
			selected_serial = serial
			selected_kind = source
	return selected_kind


func _hide_runtime_status_panel(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in panel.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false


func _render_runtime_status_card(
		snapshot: Dictionary,
		kind: StringName,
		panel: PanelContainer,
		title_label: Label,
		detail_label: Label,
		rows: VBoxContainer,
		actions: HBoxContainer
		) -> void:
	if not is_instance_valid(panel):
		return
	title_label.text = str(snapshot.get("title", "STATUS"))
	detail_label.text = str(snapshot.get("message", snapshot.get("guidance", "")))
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var detail := detail_label.text
	if snapshot.has("exposure_marker"):
		detail += "\n" + str(snapshot.exposure_marker)
	if snapshot.has("next_landmark"):
		detail += "\nNEXT // %s // %.1f M" % [snapshot.next_landmark, float(snapshot.distance_m)]
	if snapshot.has("state"):
		detail += "\nSTATE // " + str(snapshot.state).to_upper()
	if kind == &"network":
		detail += "\nROLE // %s" % str(snapshot.get("ownership_text", "OBSERVER"))
		var craft_name := str(snapshot.get("controlled_craft", ""))
		if not craft_name.is_empty():
			detail += "\nCRAFT // %s" % craft_name
		if snapshot.has("generation_summary"):
			detail += "\n%s" % str(snapshot.get("generation_summary"))
		for ownership_row in snapshot.get("ownership_rows", []) as Array:
			detail += "\nOWNERSHIP // %s" % str(ownership_row)
		for ownership_notice in snapshot.get("ownership_notices", []) as Array:
			detail += "\n%s" % str(ownership_notice)
		var craft_lifecycle := str(snapshot.get("craft_lifecycle_text", ""))
		if not craft_lifecycle.is_empty():
			detail += "\nCRAFT LIFECYCLE // %s" % craft_lifecycle
		var craft_lifecycle_notice := str(snapshot.get("craft_lifecycle_notice", ""))
		if not craft_lifecycle_notice.is_empty():
			detail += "\n%s" % craft_lifecycle_notice
		for repair_row in snapshot.get("repair_rows", []) as Array:
			detail += "\nREPAIR // %s" % str(repair_row)
		var landing_text := str(snapshot.get("landing_text", ""))
		if not landing_text.is_empty():
			detail += "\nLANDING // %s" % landing_text
		var landing_notice := str(snapshot.get("landing_notice", ""))
		if not landing_notice.is_empty():
			detail += "\n%s" % landing_notice
		for receipt in snapshot.get("history", []) as Array:
			detail += "\nHISTORY // %s" % str(receipt)
	if kind == &"bomber":
		detail += "\nPAYLOADS REMAINING // %d" % maxi(0, int(snapshot.get("ammo", 0)))
		var cooldown := maxf(0.0, float(snapshot.get("cooldown_remaining", 0.0)))
		if cooldown > 0.0:
			detail += "\nCOOLDOWN // %.1f S" % cooldown
		if not bool(snapshot.get("release_allowed", false)):
			detail += "\nUNAVAILABLE // %s" % str(snapshot.get("reason", "unavailable")).to_upper()
	if kind == &"crew" and snapshot.has("gunner_weapon"):
		var gunner := snapshot.get("gunner_weapon", {}) as Dictionary
		detail += "\n%s" % str(gunner.get("status", "GUNNER UNAVAILABLE"))
		detail += "\nSIEGE LANCE CHARGE // %d%%" % roundi(float(gunner.get("charge_progress", 0.0)) * 100.0)
		detail += "\nAMMO // %d" % maxi(0, int(gunner.get("ammunition", 0)))
		var gunner_cooldown := maxf(0.0, float(gunner.get("cooldown_remaining", 0.0)))
		if gunner_cooldown > 0.0:
			detail += "\nCOOLDOWN // %.1f S" % gunner_cooldown
		var gunner_reason := str(gunner.get("unavailable_reason", "")).strip_edges()
		if not gunner_reason.is_empty():
			detail += "\nUNAVAILABLE // %s" % gunner_reason.to_upper()
	detail_label.text = detail
	if kind != &"bomber" and is_instance_valid(_runtime_status_scroll):
		_runtime_status_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		_runtime_status_scroll.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_STOP
	var action_buttons: Array[Button] = []
	for action: Dictionary in snapshot.get("actions", []):
		var button := _menu_button(str(action.get("label", "Action")), NOMINAL)
		button.name = "RuntimeStatus" + String(action.get("id", &"Action")).to_pascal_case() + "Button"
		button.focus_mode = Control.FOCUS_ALL
		var action_id := StringName(str(action.get("id", &"")))
		if kind == &"bomber" and action_id == &"release_payload":
			button.tooltip_text = "Release bomber payload. " + str(snapshot.get("message", "Payload release unavailable."))
		if kind == &"bomber" and action_id == &"release_payload":
			button.pressed.connect(request_bomber_payload_release)
		elif kind == &"tutorial":
			button.pressed.connect(request_first_sortie_tutorial_action.bind(action_id))
		elif kind == &"safe_start_recovery":
			button.tooltip_text = "Settings recovery action. The current settings remain unchanged until GameFlow accepts this fenced request."
			button.pressed.connect(
				request_safe_start_recovery_action.bind(
					action_id,
					int(snapshot.get("generation", -1)),
					int(snapshot.get("revision", -1))
				)
			)
		else:
			button.pressed.connect(func() -> void:
				presentation_intent_requested.emit(kind, {"action": action_id, "snapshot": snapshot.duplicate(true)})
			)
		actions.add_child(button)
		action_buttons.append(button)
	if not action_buttons.is_empty():
		for index in action_buttons.size():
			var button := action_buttons[index]
			button.focus_neighbor_left = button.get_path_to(
				action_buttons[maxi(0, index - 1)]
			)
			button.focus_neighbor_right = button.get_path_to(
				action_buttons[mini(action_buttons.size() - 1, index + 1)]
			)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = true
	if (
		kind == &"tutorial"
		and not action_buttons.is_empty()
		and _runtime_status_can_claim_focus()
	):
		if action_buttons[0].is_inside_tree():
			action_buttons[0].grab_focus()
		else:
			call_deferred(&"_claim_runtime_status_focus", action_buttons[0])


func _runtime_status_can_claim_focus() -> bool:
	return (
		is_inside_tree()
		and not is_queued_for_deletion()
		and (_pause == null or not _pause.visible)
		and (_recovery_prompt_panel == null or not _recovery_prompt_panel.visible)
	)


func _claim_runtime_status_focus(target: Control) -> void:
	if (
		_runtime_status_kind == &"tutorial"
		and is_instance_valid(target)
		and target.is_visible_in_tree()
		and _runtime_status_can_claim_focus()
	):
		target.grab_focus()


func _build_enemy_status() -> void:
	# Narrowed from +/-238. This readout shares its band with the objective card,
	# and at MIN_LOGICAL_WIDTH a 476 px centred panel reached 118 px into it --
	# the measured defect that hid the objective text. There is no vertical slot
	# for it instead: the gap between the objective card and the caption panel is
	# 81 px at MIN_LOGICAL_HEIGHT and this readout is 68 px tall.
	_enemy_panel = PanelContainer.new()
	_enemy_panel.name = "EnemyPanel"
	_enemy_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_enemy_panel.offset_left = -170.0
	_enemy_panel.offset_right = 170.0
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
	_build_planetary_destination_page()
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
	var destinations := _menu_button("DESTINATION BOARD", NOMINAL_SOFT)
	destinations.name = "PlanetaryDestinationOpenButton"
	destinations.tooltip_text = (
		"Browse authored worlds and see which expeditions have a production route."
	)
	destinations.pressed.connect(_show_planetary_destination_page)
	stack.add_child(destinations)
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
	_build_identity_snapshot = resolve_build_identity(
		OS.get_executable_path(),
		str(ProjectSettings.get_setting("application/config/version", "unknown")),
		OS.has_feature("editor"),
	)
	_build_identity_label = _label(
		str(_build_identity_snapshot.get("display_text", "BUILD UNKNOWN")),
		10,
		MUTED,
	)
	_build_identity_label.name = "BuildIdentityLabel"
	_build_identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_identity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_identity_label.focus_mode = Control.FOCUS_NONE
	_build_identity_label.tooltip_text = str(
		_build_identity_snapshot.get("detail_text", "Build identity unavailable.")
	)
	stack.add_child(_build_identity_label)
	# Freeze a controller-only path through the existing pause page. Horizontal
	# movement still crosses the paired Settings/Activity buttons; either route
	# reaches the cruise row on the next down press without pointer input.
	resume.focus_neighbor_bottom = resume.get_path_to(settings)
	settings.focus_neighbor_top = settings.get_path_to(resume)
	settings.focus_neighbor_right = settings.get_path_to(activity_board)
	settings.focus_neighbor_bottom = settings.get_path_to(server_browser)
	activity_board.focus_neighbor_top = activity_board.get_path_to(resume)
	activity_board.focus_neighbor_left = activity_board.get_path_to(settings)
	activity_board.focus_neighbor_bottom = activity_board.get_path_to(server_browser)
	server_browser.focus_neighbor_top = server_browser.get_path_to(settings)
	server_browser.focus_neighbor_bottom = server_browser.get_path_to(destinations)
	destinations.focus_neighbor_top = destinations.get_path_to(server_browser)
	destinations.focus_neighbor_bottom = destinations.get_path_to(
		_planetary_cruise_button
	)
	_planetary_cruise_button.focus_neighbor_top = (
		_planetary_cruise_button.get_path_to(destinations)
	)
	_planetary_cruise_button.focus_neighbor_bottom = (
		_planetary_cruise_button.get_path_to(restart)
	)
	restart.focus_neighbor_top = restart.get_path_to(_planetary_cruise_button)


## Resolves the player-facing build stamp without consulting Git or mutable
## package metadata. The release exporter names each executable from the exact
## clean HEAD revision; preserving that filename is therefore the only case in
## which this presenter claims a revision.
static func resolve_build_identity(
	executable_path: String,
	project_version: String,
	editor_binary: bool,
) -> Dictionary:
	var normalized_path := executable_path.replace("\\", "/")
	var executable_name := normalized_path.get_file().strip_edges()
	var version := project_version.strip_edges()
	if version.is_empty():
		version = "unknown"
	var revision := ""
	var matcher := RegEx.new()
	if matcher.compile(BUILD_FILENAME_PATTERN) == OK:
		var stamped := matcher.search(executable_name)
		if stamped != null:
			revision = stamped.get_string(1).to_lower()
	if not revision.is_empty():
		return {
			"mode": &"stamped_package",
			"revision": revision,
			"exact_revision": true,
			"version": version,
			"executable_name": executable_name,
			"display_text": "BUILD %s  //  v%s" % [revision.to_upper(), version],
			"detail_text": "Stamped package: %s" % executable_name,
			"presentation_only": true,
		}.duplicate(true)
	if editor_binary:
		return {
			"mode": &"source_run",
			"revision": "",
			"exact_revision": false,
			"version": version,
			"executable_name": executable_name,
			"display_text": "SOURCE RUN  //  v%s" % version,
			"detail_text": "Running from the Godot development executable.",
			"presentation_only": true,
		}.duplicate(true)
	return {
		"mode": &"unstamped_package",
		"revision": "",
		"exact_revision": false,
		"version": version,
		"executable_name": executable_name,
		"display_text": "UNSTAMPED BUILD  //  v%s" % version,
		"detail_text": "The executable filename contains no source revision.",
		"presentation_only": true,
	}.duplicate(true)


## Detached support information for screenshots and pause-layout checks.
func get_build_identity_report() -> Dictionary:
	var report := _build_identity_snapshot.duplicate(true)
	report["label_text"] = (
		_build_identity_label.text
		if is_instance_valid(_build_identity_label)
		else ""
	)
	report["label_rect"] = (
		_build_identity_label.get_global_rect()
		if is_instance_valid(_build_identity_label)
		else Rect2()
	)
	report["pause_visible"] = _pause != null and _pause.visible
	report["presentation_only"] = true
	return report


## The smallest reachable selection surface for the four production activities.
## Buttons emit requests only; GameFlow remains the owner of validation, route
## exclusivity, and the post-start selection lock.
func _build_activity_selection_page() -> void:
	_activity_selection_page = PanelContainer.new()
	_activity_selection_page.name = "ActivitySelectionPage"
	_activity_selection_page.set_anchors_preset(Control.PRESET_CENTER)
	_activity_selection_page.position = Vector2(-340.0, -330.0)
	_activity_selection_page.size = Vector2(680.0, 660.0)
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
	_activity_reward_panel = PanelContainer.new()
	_activity_reward_panel.name = "ActivityRewardSummary"
	_activity_reward_panel.add_theme_stylebox_override(
		"panel",
		_border_box(Color("102332"), 5, NOMINAL)
	)
	stack.add_child(_activity_reward_panel)
	var reward_margin := _margin(12, 7, 12, 7)
	_activity_reward_panel.add_child(reward_margin)
	var reward_stack := VBoxContainer.new()
	reward_stack.add_theme_constant_override("separation", 2)
	reward_margin.add_child(reward_stack)
	_activity_reward_summary_label = _label(
		"SHIPYARD RECEIPTS  //  OFFLINE",
		11,
		NOMINAL_SOFT
	)
	_activity_reward_summary_label.name = "ActivityRewardSummaryLabel"
	_activity_reward_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_stack.add_child(_activity_reward_summary_label)
	_activity_reward_latest_label = _label(
		"PERSISTENT RETURN RECORDS ARE UNAVAILABLE",
		10,
		MUTED
	)
	_activity_reward_latest_label.name = "ActivityRewardLatestLabel"
	_activity_reward_latest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activity_reward_latest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_stack.add_child(_activity_reward_latest_label)
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
	_add_patrol_branch_choices(stack)
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
	var nearby := _menu_button("CINDER SECTOR ACTIVITIES", NOMINAL)
	nearby.name = "NearbyActivityOpenButton"
	nearby.tooltip_text = (
		"Open live status and start/reset controls for all eight Cinder activities. "
		+ "Physical activities still enforce their authored approach gates."
	)
	nearby.pressed.connect(show_nearby_activity_page)
	stack.add_child(nearby)
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
	var subtitle := _label(
		"Eight activity records. Start/reset requests still obey ship, route and physical-board gates.",
		11,
		MUTED,
	)
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
	back.pressed.connect(_show_activity_selection_page)
	stack.add_child(back)
	_nearby_activity_page.visible = false


func _build_planetary_destination_page() -> void:
	_planetary_destination_page = PanelContainer.new()
	_planetary_destination_page.name = "PlanetaryDestinationPage"
	_planetary_destination_page.set_anchors_preset(Control.PRESET_CENTER)
	_planetary_destination_page.position = Vector2(-360.0, -290.0)
	_planetary_destination_page.size = Vector2(720.0, 580.0)
	_planetary_destination_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_planetary_destination_page.add_theme_stylebox_override(
		"panel",
		_border_box(PANEL_SOLID, 10, NOMINAL),
	)
	_pause_panels.add_child(_planetary_destination_page)
	var margin := _margin(30, 24, 30, 24)
	_planetary_destination_page.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	var title := _label("DESTINATION BOARD", 26, PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label(
		"Authored nearby worlds. Only commissioned routes can launch an expedition.",
		12,
		MUTED,
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(subtitle)
	_planetary_destination_rows = VBoxContainer.new()
	_planetary_destination_rows.name = "PlanetaryDestinationRows"
	_planetary_destination_rows.add_theme_constant_override("separation", 10)
	_planetary_destination_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_planetary_destination_rows)
	var waiting := _label("NAVIGATION CATALOG OFFLINE", 12, MUTED)
	waiting.name = "PlanetaryDestinationWaitingLabel"
	waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planetary_destination_rows.add_child(waiting)
	_planetary_destination_back_button = _menu_button("BACK", MUTED)
	_planetary_destination_back_button.name = "PlanetaryDestinationBackButton"
	_planetary_destination_back_button.pressed.connect(_show_pause_main)
	stack.add_child(_planetary_destination_back_button)
	_planetary_destination_page.visible = false


## Accepts only the catalog's detached bounded view. A row can request travel,
## but it never supplies the ship, route target, gate result, or journey owner.
func set_planetary_destination_snapshot(snapshot: Dictionary) -> bool:
	if not _valid_planetary_destination_snapshot(snapshot):
		return false
	if snapshot == _planetary_destination_snapshot:
		return true
	var focused_id := &""
	if is_inside_tree() and get_viewport() != null:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if (
			is_instance_valid(focus_owner)
			and _planetary_destination_page != null
			and _planetary_destination_page.is_ancestor_of(focus_owner)
		):
			focused_id = StringName(
				focus_owner.get_meta(&"planetary_destination_id", &"")
			)
	_planetary_destination_snapshot = snapshot.duplicate(true)
	_render_planetary_destination_rows()
	if _planetary_destination_page.visible:
		call_deferred(&"_restore_planetary_destination_focus", focused_id)
	return true


func _render_planetary_destination_rows() -> void:
	if not is_instance_valid(_planetary_destination_rows):
		return
	var retained: Dictionary = {}
	for child in _planetary_destination_rows.get_children():
		var retained_id := StringName(
			child.get_meta(&"planetary_destination_id", &"")
		)
		if not retained_id.is_empty():
			retained[retained_id] = child
	_planetary_destination_buttons.clear()
	var presented_ids: Array[StringName] = []
	var presentation_index := 0
	for row_variant: Variant in _planetary_destination_snapshot.get(
		"destinations", []
	) as Array:
		var row := row_variant as Dictionary
		var destination_id := StringName(row.get("destination_id", &""))
		presented_ids.append(destination_id)
		var card := retained.get(destination_id) as Control
		if is_instance_valid(card):
			_update_planetary_destination_row(card, row)
		else:
			card = _add_planetary_destination_row(row)
		if is_instance_valid(card) and card.get_index() != presentation_index:
			_planetary_destination_rows.move_child(card, presentation_index)
		presentation_index += 1
	for child in _planetary_destination_rows.get_children():
		var retained_id := StringName(
			child.get_meta(&"planetary_destination_id", &"")
		)
		if retained_id.is_empty() or retained_id not in presented_ids:
			child.queue_free()
	_configure_planetary_destination_focus_order()


func _add_planetary_destination_row(row: Dictionary) -> Control:
	var destination_id := StringName(row.get("destination_id", &""))
	var status_id := StringName(row.get("status_id", &"unavailable"))
	var border_role := (
		CAUTION
		if status_id in [&"queued", &"accelerating", &"cruising", &"braking_to_speed", &"braking"]
		else NOMINAL
		if status_id == &"ready"
		else MUTED
	)
	var card := PanelContainer.new()
	card.name = "PlanetaryDestination_%s" % destination_id
	card.set_meta(&"planetary_destination_id", destination_id)
	card.add_theme_stylebox_override(
		"panel",
		_border_box(Color("102332"), 6, border_role),
	)
	_planetary_destination_rows.add_child(card)
	var margin := _margin(16, 12, 16, 12)
	card.add_child(margin)
	var row_layout := HBoxContainer.new()
	row_layout.add_theme_constant_override("separation", 18)
	margin.add_child(row_layout)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 3)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_layout.add_child(copy)
	var heading := _label(
		"%s  //  %s" % [
			str(row.get("display_name", "UNKNOWN DESTINATION")).to_upper(),
			str(row.get("environment_text", "UNKNOWN")),
		],
		15,
		PRIMARY,
	)
	heading.name = "PlanetaryDestinationHeading"
	copy.add_child(heading)
	var distance := _label(str(row.get("distance_text", "ROUTE UNCHARTED")), 11, NOMINAL_SOFT)
	distance.name = "PlanetaryDestinationDistance"
	copy.add_child(distance)
	var summary := _label(str(row.get("travel_summary", "")), 11, MUTED)
	summary.name = "PlanetaryDestinationSummary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(summary)
	var status := _label(
		"STATUS  //  %s" % str(row.get("status_text", "UNAVAILABLE")),
		10,
		border_role,
	)
	status.name = "PlanetaryDestinationStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(status)
	var action := _menu_button(str(row.get("action_text", "ROUTE UNAVAILABLE")), border_role)
	action.name = "PlanetaryDestinationAction_%s" % destination_id
	action.custom_minimum_size = Vector2(190.0, 48.0)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.set_meta(&"planetary_destination_id", destination_id)
	action.disabled = not bool(row.get("action_enabled", false))
	action.focus_mode = Control.FOCUS_NONE if action.disabled else Control.FOCUS_ALL
	action.tooltip_text = (
		"Uses the existing production expedition route."
		if bool(row.get("route_available", false))
		else "This authored world has no commissioned production route yet."
	)
	if bool(row.get("route_available", false)):
		action.pressed.connect(_request_planetary_destination.bind(destination_id))
	row_layout.add_child(action)
	_planetary_destination_buttons[destination_id] = action
	return card


func _update_planetary_destination_row(card: Control, row: Dictionary) -> void:
	var destination_id := StringName(row.get("destination_id", &""))
	var status_id := StringName(row.get("status_id", &"unavailable"))
	var border_role := (
		CAUTION
		if status_id in [&"queued", &"accelerating", &"cruising", &"braking_to_speed", &"braking"]
		else NOMINAL
		if status_id == &"ready"
		else MUTED
	)
	card.add_theme_stylebox_override(
		"panel",
		_border_box(Color("102332"), 6, border_role),
	)
	var heading := card.find_child(
		"PlanetaryDestinationHeading", true, false
	) as Label
	if is_instance_valid(heading):
		heading.text = "%s  //  %s" % [
			str(row.get("display_name", "UNKNOWN DESTINATION")).to_upper(),
			str(row.get("environment_text", "UNKNOWN")),
		]
	var distance := card.find_child(
		"PlanetaryDestinationDistance", true, false
	) as Label
	if is_instance_valid(distance):
		distance.text = str(row.get("distance_text", "ROUTE UNCHARTED"))
	var summary := card.find_child(
		"PlanetaryDestinationSummary", true, false
	) as Label
	if is_instance_valid(summary):
		summary.text = str(row.get("travel_summary", ""))
	var status := card.find_child(
		"PlanetaryDestinationStatus", true, false
	) as Label
	if is_instance_valid(status):
		status.text = "STATUS  //  %s" % str(row.get("status_text", "UNAVAILABLE"))
		status.modulate = _c(border_role)
	var action := card.find_child(
		"PlanetaryDestinationAction_%s" % destination_id, true, false
	) as Button
	if is_instance_valid(action):
		action.text = str(row.get("action_text", "ROUTE UNAVAILABLE"))
		action.disabled = not bool(row.get("action_enabled", false))
		action.focus_mode = Control.FOCUS_NONE if action.disabled else Control.FOCUS_ALL
		_planetary_destination_buttons[destination_id] = action


func _request_planetary_destination(destination_id: StringName) -> void:
	if (
		_planetary_cruise_request_dispatch_active
		or _planetary_cruise_toggle_serial >= MAX_PLANETARY_CRUISE_TOGGLE_SERIAL
	):
		return
	var selected: Dictionary = {}
	for row_variant: Variant in _planetary_destination_snapshot.get(
		"destinations", []
	) as Array:
		var row := row_variant as Dictionary
		if StringName(row.get("destination_id", &"")) == destination_id:
			selected = row
			break
	if selected.is_empty() or not bool(selected.get("action_enabled", false)):
		return
	_planetary_cruise_toggle_serial += 1
	_refresh_planetary_cruise_row()
	_planetary_cruise_request_dispatch_active = true
	planetary_destination_requested.emit(
		destination_id,
		_planetary_cruise_toggle_serial,
	)
	_planetary_cruise_request_dispatch_active = false


func _restore_planetary_destination_focus(preferred_id: StringName = &"") -> void:
	if (
		not is_instance_valid(_planetary_destination_page)
		or not _planetary_destination_page.visible
	):
		return
	var target := _planetary_destination_buttons.get(preferred_id) as Button
	if not is_instance_valid(target) or target.disabled:
		target = _first_planetary_destination_focus_target() as Button
	if is_instance_valid(target):
		target.grab_focus()


func _first_planetary_destination_focus_target() -> Control:
	for destination_id: StringName in _planetary_destination_buttons:
		var button := _planetary_destination_buttons[destination_id] as Button
		if is_instance_valid(button) and not button.disabled:
			return button
	return _planetary_destination_back_button


func _configure_planetary_destination_focus_order() -> void:
	var ordered: Array[Control] = []
	for row_variant: Variant in _planetary_destination_snapshot.get(
		"destinations", []
	) as Array:
		var destination_id := StringName(
			(row_variant as Dictionary).get("destination_id", &"")
		)
		var button := _planetary_destination_buttons.get(destination_id) as Button
		if is_instance_valid(button) and not button.disabled:
			ordered.append(button)
	if is_instance_valid(_planetary_destination_back_button):
		ordered.append(_planetary_destination_back_button)
	for index in ordered.size():
		var control := ordered[index]
		control.focus_neighbor_top = control.get_path_to(
			ordered[maxi(0, index - 1)]
		)
		control.focus_neighbor_bottom = control.get_path_to(
			ordered[mini(ordered.size() - 1, index + 1)]
		)


func _valid_planetary_destination_snapshot(snapshot: Dictionary) -> bool:
	if not _has_exact_string_keys(snapshot, [
		"schema_version",
		"catalog_id",
		"destination_count",
		"available_destination_ids",
		"destinations",
		"authority",
	]):
		return false
	if (
		snapshot.get("schema_version") is not int
		or int(snapshot.get("schema_version", 0))
			!= PLANETARY_DESTINATION_SCHEMA_VERSION
		or snapshot.get("catalog_id") is not StringName
		or snapshot.get("catalog_id") != PLANETARY_DESTINATION_CATALOG_ID
		or snapshot.get("destination_count") is not int
		or snapshot.get("available_destination_ids") is not PackedStringArray
		or snapshot.get("destinations") is not Array
		or snapshot.get("authority") is not Dictionary
	):
		return false
	var rows := snapshot.get("destinations", []) as Array
	if (
		rows.is_empty()
		or rows.size() > MAX_PLANETARY_DESTINATIONS
		or int(snapshot.get("destination_count", 0)) != rows.size()
	):
		return false
	var advertised_available := snapshot.get(
		"available_destination_ids", PackedStringArray()
	) as PackedStringArray
	var actual_available := PackedStringArray()
	var seen: Dictionary = {}
	for row_variant: Variant in rows:
		if row_variant is not Dictionary:
			return false
		var row := row_variant as Dictionary
		if not _valid_planetary_destination_row(row):
			return false
		var destination_id := StringName(row.get("destination_id", &""))
		if seen.has(destination_id):
			return false
		seen[destination_id] = true
		if bool(row.get("route_available", false)):
			actual_available.append(str(destination_id))
	if advertised_available != actual_available:
		return false
	var authority := snapshot.get("authority", {}) as Dictionary
	if authority.is_empty():
		return false
	for value: Variant in authority.values():
		if value is not bool or bool(value):
			return false
	return true


func _valid_planetary_destination_row(row: Dictionary) -> bool:
	if not _has_exact_string_keys(row, [
		"destination_id",
		"display_name",
		"sector_id",
		"environment_id",
		"environment_text",
		"evidence_status",
		"route_id",
		"route_available",
		"orbital_distance_meters",
		"distance_text",
		"travel_summary",
		"status_id",
		"status_text",
		"action_enabled",
		"engagement_requested",
		"action_text",
		"presentation_only",
	]):
		return false
	if (
		row.get("destination_id") is not StringName
		or StringName(row.get("destination_id", &"")).is_empty()
		or row.get("display_name") is not String
		or row.get("sector_id") is not StringName
		or row.get("environment_id") is not StringName
		or row.get("environment_text") is not String
		or row.get("evidence_status") is not StringName
		or row.get("route_id") is not StringName
		or row.get("route_available") is not bool
		or row.get("orbital_distance_meters") is not float
		or row.get("distance_text") is not String
		or row.get("travel_summary") is not String
		or row.get("status_id") is not StringName
		or row.get("status_text") is not String
		or row.get("action_enabled") is not bool
		or row.get("engagement_requested") is not bool
		or row.get("action_text") is not String
		or row.get("presentation_only") is not bool
		or not bool(row.get("presentation_only", false))
	):
		return false
	for copy_key: String in [
		"display_name",
		"environment_text",
		"distance_text",
		"travel_summary",
		"status_text",
		"action_text",
	]:
		var copy := str(row.get(copy_key, ""))
		if (
			copy.is_empty()
			or copy != copy.strip_edges()
			or copy.length() > 128
			or copy.contains("\n")
			or copy.contains("\r")
		):
			return false
	var route_available := bool(row.get("route_available", false))
	if (
		StringName(row.get("status_id", &"")) not in PLANETARY_DESTINATION_STATUS_IDS
		or (not route_available and not StringName(row.get("route_id", &"")).is_empty())
		or (not route_available and bool(row.get("action_enabled", false)))
		or (not route_available and bool(row.get("engagement_requested", false)))
	):
		return false
	return true


func get_planetary_destination_report() -> Dictionary:
	var action_rows: Array[Dictionary] = []
	for row_variant: Variant in _planetary_destination_snapshot.get(
		"destinations", []
	) as Array:
		var row := row_variant as Dictionary
		var destination_id := StringName(row.get("destination_id", &""))
		var button := _planetary_destination_buttons.get(destination_id) as Button
		var card := _planetary_destination_rows.find_child(
			"PlanetaryDestination_%s" % destination_id, true, false
		) as Control
		action_rows.append({
			"destination_id": destination_id,
			"button_text": button.text if is_instance_valid(button) else "",
			"button_disabled": button.disabled if is_instance_valid(button) else true,
			"button_rect": button.get_global_rect() if is_instance_valid(button) else Rect2(),
			"card_rect": card.get_global_rect() if is_instance_valid(card) else Rect2(),
		}.duplicate(true))
	return {
		"snapshot": _planetary_destination_snapshot.duplicate(true),
		"actions": action_rows,
		"page_visible": (
			is_instance_valid(_planetary_destination_page)
			and _planetary_destination_page.visible
		),
		"page_rect": (
			_planetary_destination_page.get_global_rect()
			if is_instance_valid(_planetary_destination_page)
			else Rect2()
		),
		"presentation_only": true,
		"destination_selection_authority": false,
		"movement_authority": false,
	}.duplicate(true)


func set_nearby_activity_snapshot(snapshot: Dictionary) -> Dictionary:
	_nearby_activity_snapshot = snapshot.duplicate(true)
	if _nearby_activity_presenter == null:
		_nearby_activity_presenter = NearbySectorActivityPresenterType.new()
	var view: Dictionary = _nearby_activity_presenter.call("present", _nearby_activity_snapshot)
	_render_nearby_activity_view(view)
	var binding_available := bool(snapshot.get("binding_available", true))
	for button_name in ["NearbyActivitySaveButton", "NearbyActivityLoadButton"]:
		var persistence_button := _nearby_activity_page.find_child(
			button_name, true, false
		) as Button
		if persistence_button != null:
			persistence_button.disabled = not binding_available
	if not binding_available and is_instance_valid(_nearby_activity_feedback):
		_nearby_activity_feedback.text = (
			"CINDER REACH IS OUT OF STREAMING RANGE  //  LAUNCH TOWARD ITS MARKER TO LOAD FIELD ACTIVITIES"
		)
		_nearby_activity_feedback.modulate = _c(CAUTION)
	_present_nearby_convoy_semantic_transition(view)
	return view


## Consumes push-driven convoy presenter transitions. Critical, safe-arrival,
## and terminal-loss responses enter the existing caption seam; activity and
## audio authority remain with their current owners.
func _present_nearby_convoy_semantic_transition(view: Dictionary) -> void:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) != &"cinder_reach_emberline_convoy":
			continue
		var feedback := card.get("convoy_feedback", {}) as Dictionary
		var cue_id := StringName(feedback.get("semantic_cue_id", &""))
		var generation := maxi(int(feedback.get("generation", 0)), 0)
		var transition := "%d|%s" % [generation, cue_id]
		if transition == _last_nearby_convoy_semantic_transition:
			return
		_last_nearby_convoy_semantic_transition = transition
		_nearby_convoy_semantic_transition_serial += 1
		if cue_id not in [
			&"convoy_escort_separation_critical",
			&"convoy_escort_formation_secured",
			&"convoy_escort_lost",
		]:
			return
		present_semantic_audio_cue(
			cue_id,
			&"Cinder convoy",
			1.0,
			Vector3.ZERO,
			{
				"priority": 95,
				"transition_id": "%d:%d:%s" % [
					generation, _nearby_convoy_semantic_transition_serial, cue_id,
				],
			},
		)
		return


func apply_nearby_activity_persistence_result(result: Dictionary) -> Dictionary:
	if _nearby_activity_presenter == null:
		_nearby_activity_presenter = NearbySectorActivityPresenterType.new()
	var view: Dictionary = _nearby_activity_presenter.call("present_persistence_result", result)
	_render_nearby_activity_view(view)
	return view


func _render_nearby_activity_view(view: Dictionary) -> void:
	if _nearby_activity_rows != null:
		var retained_rows: Dictionary = {}
		for child in _nearby_activity_rows.get_children():
			var retained_id := StringName(child.get_meta(&"activity_id", &""))
			if not retained_id.is_empty():
				retained_rows[retained_id] = child
		var presented_ids: Array[StringName] = []
		var presentation_index := 0
		for card in view.get("cards", []) as Array:
			var detached_card := card as Dictionary
			var activity_id := StringName(detached_card.get("activity_id", &""))
			presented_ids.append(activity_id)
			var retained := retained_rows.get(activity_id) as Control
			if retained != null:
				_update_nearby_activity_row(retained, detached_card)
			else:
				_add_nearby_activity_row(detached_card)
				retained = _nearby_activity_rows.get_child(
					_nearby_activity_rows.get_child_count() - 1
				) as Control
			if retained != null and retained.get_index() != presentation_index:
				_nearby_activity_rows.move_child(retained, presentation_index)
			presentation_index += 1
		for retained_id in retained_rows:
			if retained_id not in presented_ids:
				(retained_rows[retained_id] as Control).queue_free()
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
	if _pause_main_page != null:
		_pause_main_page.visible = false
	if _activity_selection_page != null:
		_activity_selection_page.visible = false
	if _settings_page != null:
		_settings_page.visible = false
	if _server_browser_page != null:
		_server_browser_page.visible = false
	if _planetary_destination_page != null:
		_planetary_destination_page.visible = false
	_nearby_activity_page.visible = true
	var first := _first_nearby_activity_focus_target()
	if first != null:
		first.grab_focus()


func _first_nearby_activity_focus_target() -> Control:
	if _nearby_activity_rows != null:
		for row in _nearby_activity_rows.get_children():
			for child in row.get_children():
				if (
					child is BaseButton
					and not (child as BaseButton).disabled
					and (child as Control).focus_mode != Control.FOCUS_NONE
				):
					return child as Control
	return (
		_nearby_activity_page.find_child("NearbyActivityBackButton", true, false)
		as Control
		if _nearby_activity_page != null
		else null
	)


## Renders only the caller-owned activity result. This page never decides
## whether a request was valid; GameFlow and the physical activity adapters do.
func apply_nearby_activity_action_result(
	action: StringName,
	activity_id: StringName,
	result: Dictionary,
	) -> bool:
	if not is_instance_valid(_nearby_activity_feedback):
		return false
	var accepted := bool(result.get("accepted", false))
	var reason := StringName(result.get("reason", &"unavailable"))
	var title := {
		&"cinder_reach_emberline_convoy": "EMBERLINE CONVOY",
		&"cinder_reach_checkpoint_route": "BEACON RACE",
		&"cinder_relay_patrol": "RELAY PATROL",
		&"cinder_platform_mining_run": "PLATFORM EXTRACTION",
		&"cinder_derelict_structure_scan": "DERELICT SCAN",
		&"cinder_debris_beacon_traversal": "DEBRIS BEACON RUN",
		&"cinder_platform_supply_run": "PLATFORM SUPPLY RUN",
		&"station_defense": "STATION DEFENSE",
	}.get(activity_id, "ACTIVITY") as String
	if (
		accepted
		and activity_id in [
			&"cinder_derelict_structure_scan",
			&"cinder_debris_beacon_traversal",
		]
		and reason == &"reward_request_ready"
		and bool((result.get("authority_result", {}) as Dictionary).get(
			"accepted", false
		))
	):
		_nearby_activity_feedback.text = "%s  //  REWARD FILED" % title
		_nearby_activity_feedback.modulate = _c(NOMINAL_SOFT)
	elif accepted:
		_nearby_activity_feedback.text = "%s  //  %s" % [
			title,
			"STARTED" if action == &"start_requested" else "RESET",
		]
		_nearby_activity_feedback.modulate = _c(NOMINAL_SOFT)
	elif activity_id == &"station_defense" and reason in [
		&"out_of_range", &"on_foot_required", &"invalid_actor_or_content",
	]:
		_nearby_activity_feedback.text = (
			"STATION DEFENSE  //  REPORT ON FOOT TO THE MARKED DECK BOARD"
		)
		_nearby_activity_feedback.modulate = _c(CAUTION)
	else:
		_nearby_activity_feedback.text = "%s NOT %s  //  %s" % [
			title,
			"STARTED" if action == &"start_requested" else "RESET",
			str(reason).replace("_", " ").to_upper(),
		]
		_nearby_activity_feedback.modulate = _c(CAUTION)
	return true


func get_nearby_activity_report() -> Dictionary:
	return {"visible": _nearby_activity_page != null and _nearby_activity_page.visible, "snapshot": _nearby_activity_snapshot.duplicate(true), "row_count": _nearby_activity_rows.get_child_count() if _nearby_activity_rows != null else 0}


func _add_nearby_activity_row(card: Dictionary) -> void:
	var row := HBoxContainer.new()
	var activity_id := StringName(card.get("activity_id", &""))
	row.name = "NearbyActivityRow_%s" % str(activity_id)
	row.set_meta(&"activity_id", activity_id)
	row.add_theme_constant_override("separation", 6)
	var label := _label(str(card.get("text", "ACTIVITY — AVAILABLE")), 10, NOMINAL_SOFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	for action in [&"select", &"start", &"reset"]:
		var action_label := str(card.get("reset_label", "RESET")) \
			if action == &"reset" else str(action).to_upper()
		var button := _menu_button(action_label, MUTED)
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not bool(card.get("actions_enabled", true))
		button.pressed.connect(_forward_nearby_activity_intent.bind(action, activity_id))
		row.add_child(button)
	_nearby_activity_rows.add_child(row)


func _update_nearby_activity_row(row: Control, card: Dictionary) -> void:
	if row.get_child_count() == 0 or not row.get_child(0) is Label:
		return
	(row.get_child(0) as Label).text = str(card.get("text", "ACTIVITY — AVAILABLE"))
	for index in range(1, row.get_child_count()):
		if row.get_child(index) is Button:
			(row.get_child(index) as Button).disabled = not bool(
				card.get("actions_enabled", true)
			)
	if row.get_child_count() > 3 and row.get_child(3) is Button:
		(row.get_child(3) as Button).text = str(card.get("reset_label", "RESET"))


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
	if action in [&"select", &"reset"]:
		var view := _nearby_activity_presenter.call(
			"present", _nearby_activity_snapshot
		) as Dictionary
		_render_nearby_activity_view(view)
	if not bool(intent.get("emit_intent", true)):
		return
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
	var filters := HBoxContainer.new()
	filters.name = "ServerBrowserFilters"
	filters.add_theme_constant_override("separation", 5)
	stack.add_child(filters)
	for filter_id: StringName in [&"compatible_only", &"not_full", &"no_password"]:
		var check := CheckButton.new()
		check.name = "ServerBrowserFilter" + String(filter_id).to_pascal_case()
		check.text = {
			&"compatible_only": "COMPATIBLE",
			&"not_full": "NOT FULL",
			&"no_password": "NO PASSWORD",
		}.get(filter_id, String(filter_id))
		check.tooltip_text = "Filter server rows by " + check.text.to_lower()
		check.focus_mode = Control.FOCUS_ALL
		check.toggled.connect(_on_server_browser_filter_changed.bind(filter_id))
		filters.add_child(check)
		_server_browser_filter_controls[filter_id] = check
	var latency := OptionButton.new()
	latency.name = "ServerBrowserFilterLatency"
	latency.add_item("LATENCY: ANY", 0)
	latency.add_item("LATENCY: EXCELLENT", 1)
	latency.add_item("LATENCY: GOOD", 2)
	latency.add_item("LATENCY: POOR", 3)
	latency.add_item("LATENCY: UNKNOWN", 4)
	latency.tooltip_text = "Filter server rows by latency band"
	latency.focus_mode = Control.FOCUS_ALL
	latency.item_selected.connect(_on_server_browser_latency_filter_changed)
	filters.add_child(latency)
	_server_browser_filter_controls[&"latency_band"] = latency
	var clear_filters := _menu_button("CLEAR FILTERS", MUTED)
	clear_filters.name = "ServerBrowserClearFiltersButton"
	clear_filters.focus_mode = Control.FOCUS_ALL
	clear_filters.pressed.connect(_clear_server_browser_filters)
	filters.add_child(clear_filters)
	_server_browser_filter_controls[&"clear_filters"] = clear_filters
	_server_browser_filter_summary = _label("FILTERS: NONE", 10, MUTED)
	_server_browser_filter_summary.name = "ServerBrowserFilterSummary"
	_server_browser_filter_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_server_browser_filter_summary)
	var sort_row := HBoxContainer.new()
	sort_row.name = "ServerBrowserSortControls"
	sort_row.add_theme_constant_override("separation", 5)
	stack.add_child(sort_row)
	var sort_key := OptionButton.new()
	sort_key.name = "ServerBrowserSortKey"
	sort_key.add_item("SORT: NAME", 0)
	sort_key.add_item("SORT: LATENCY", 1)
	sort_key.add_item("SORT: OCCUPANCY", 2)
	sort_key.add_item("SORT: COMPATIBLE FIRST", 3)
	sort_key.tooltip_text = "Choose server row sort order"
	sort_key.focus_mode = Control.FOCUS_ALL
	sort_key.item_selected.connect(_on_server_browser_sort_key_changed)
	sort_row.add_child(sort_key)
	_server_browser_sort_controls[&"sort_key"] = sort_key
	var sort_direction := _menu_button("ASCENDING", MUTED)
	sort_direction.name = "ServerBrowserSortDirection"
	sort_direction.tooltip_text = "Toggle ascending or descending sort"
	sort_direction.focus_mode = Control.FOCUS_ALL
	sort_direction.pressed.connect(_toggle_server_browser_sort_direction)
	sort_row.add_child(sort_direction)
	_server_browser_sort_controls[&"sort_direction"] = sort_direction
	var clear_sort := _menu_button("CLEAR SORT", MUTED)
	clear_sort.name = "ServerBrowserClearSortButton"
	clear_sort.focus_mode = Control.FOCUS_ALL
	clear_sort.pressed.connect(_clear_server_browser_sort)
	sort_row.add_child(clear_sort)
	_server_browser_sort_controls[&"clear_sort"] = clear_sort
	_server_browser_sort_summary = _label("SORT: NAME ↑", 10, MUTED)
	_server_browser_sort_summary.name = "ServerBrowserSortSummary"
	_server_browser_sort_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_server_browser_sort_summary)
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
	_server_browser_results_scroll = ScrollContainer.new()
	_server_browser_results_scroll.name = "ServerBrowserResultsScroll"
	_server_browser_results_scroll.custom_minimum_size.y = 48.0
	_server_browser_results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_server_browser_results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_server_browser_results_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_server_browser_results_scroll.follow_focus = true
	_server_browser_results_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.add_child(_server_browser_results_scroll)
	_server_browser_rows = VBoxContainer.new()
	_server_browser_rows.name = "ServerBrowserRows"
	_server_browser_rows.add_theme_constant_override("separation", 6)
	_server_browser_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_browser_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_server_browser_results_scroll.add_child(_server_browser_rows)
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
	_configure_server_browser_focus_order(refresh, host, manual_join, back)
	_server_browser_page.visible = false


func _configure_server_browser_focus_order(
	refresh: Control, host: Control, manual_join: Control, back: Control
	) -> void:
	var ordered: Array[Control] = [_server_browser_address, _server_browser_port, _server_browser_player_name]
	for filter_id: StringName in [&"compatible_only", &"not_full", &"no_password", &"latency_band", &"clear_filters"]:
		var filter_control := _server_browser_filter_controls.get(filter_id) as Control
		if is_instance_valid(filter_control):
			ordered.append(filter_control)
	for sort_id: StringName in [&"sort_key", &"sort_direction", &"clear_sort"]:
		var sort_control := _server_browser_sort_controls.get(sort_id) as Control
		if is_instance_valid(sort_control):
			ordered.append(sort_control)
	ordered.append_array([refresh, host, manual_join, back])
	for index in ordered.size():
		var control := ordered[index]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_neighbor_top = control.get_path_to(ordered[maxi(0, index - 1)])
		control.focus_neighbor_bottom = control.get_path_to(ordered[mini(ordered.size() - 1, index + 1)])


func _show_server_browser_page() -> void:
	_pause_main_page.visible = false
	_activity_selection_page.visible = false
	if _nearby_activity_page != null:
		_nearby_activity_page.visible = false
	_settings_page.visible = false
	if _planetary_destination_page != null:
		_planetary_destination_page.visible = false
	_server_browser_page.visible = true
	_server_browser_accept_results = true
	var target := _server_browser_focus_target
	if (
		not is_instance_valid(target)
		or not _server_browser_page.is_ancestor_of(target)
		or not target.is_visible_in_tree()
		or target.focus_mode == Control.FOCUS_NONE
	):
		target = _server_browser_page.find_child("ServerBrowserRefreshButton", true, false) as Button
	if target != null:
		target.grab_focus()


## Applies a caller-owned discovery result to the pause browser surface. The
## presenter owns only textual shaping; refresh and join remain external
## intents, so this UI never queries a directory or opens a transport.
func apply_server_browser_result(result: Dictionary) -> bool:
	if not is_instance_valid(_server_browser_page) or not _server_browser_accept_results:
		return false
	var presentation: Dictionary
	var requested_status := StringName(str(result.get("status", &"")))
	if requested_status == &"loading":
		presentation = {
			"status": &"refreshing",
			"rows": [],
			"error_message": "Refreshing server list…",
			"actions": [],
		}
	else:
		presentation = _server_browser_presenter.present_result(result)
		if presentation.get("reason", &"") == &"stale_result_ignored":
			return false
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
	var composed := _server_browser_presenter.configure_manual_connect(
		_server_browser_address.text,
		int(_server_browser_port.text.to_int()),
		_server_browser_player_name.text
	)
	var request := composed.get("intent", {}) as Dictionary
	if not bool(request.get("accepted", false)):
		var focus_target := StringName(composed.get("focus_target", &"manual_address"))
		var target: Control = _server_browser_address
		if focus_target == &"manual_port":
			target = _server_browser_port
		elif focus_target == &"manual_player_name":
			target = _server_browser_player_name
		if is_instance_valid(target):
			target.grab_focus()
		return apply_server_browser_feedback(request)
	var normalized_form := composed.get("form", {}) as Dictionary
	_server_browser_address.text = str(normalized_form.get("address", request.get("address", "")))
	_server_browser_port.text = str(int(normalized_form.get("port", request.get("port", 0))))
	presentation_intent_requested.emit(&"server_browser", request.duplicate(true))
	return request


func request_server_browser_refresh() -> Dictionary:
	var request := _server_browser_presenter.request_retry()
	if not bool(request.get("accepted", false)):
		request = _server_browser_presenter.begin_refresh(&"refresh")
	var presentation := request.get("presentation", {}) as Dictionary
	if not presentation.is_empty():
		_render_server_browser(presentation)
	presentation_intent_requested.emit(&"server_browser", {"action": &"refresh", "request": request})
	return request


func _on_server_browser_filter_changed(_enabled: bool, _filter_id: StringName) -> void:
	_apply_server_browser_filters()


func _on_server_browser_latency_filter_changed(index: int) -> void:
	var bands: Array[StringName] = [&"", &"excellent", &"good", &"poor", &"unknown"]
	var latency := bands[clampi(index, 0, bands.size() - 1)]
	var current := _server_browser_presenter.get_accessibility_filters()
	current["latency_band"] = latency
	var presentation := _server_browser_presenter.set_accessibility_filters(current)
	_render_server_browser(presentation)


func _apply_server_browser_filters() -> void:
	var filters := {
		"compatible_only": bool((_server_browser_filter_controls.get(&"compatible_only") as CheckButton).button_pressed),
		"not_full": bool((_server_browser_filter_controls.get(&"not_full") as CheckButton).button_pressed),
		"no_password": bool((_server_browser_filter_controls.get(&"no_password") as CheckButton).button_pressed),
		"latency_band": _server_browser_presenter.get_accessibility_filters().get("latency_band", &""),
	}
	var presentation := _server_browser_presenter.set_accessibility_filters(filters)
	_render_server_browser(presentation)


func _clear_server_browser_filters() -> void:
	var presentation := _server_browser_presenter.clear_accessibility_filters()
	for filter_id: StringName in [&"compatible_only", &"not_full", &"no_password"]:
		var check := _server_browser_filter_controls.get(filter_id) as CheckButton
		if is_instance_valid(check):
			check.set_pressed_no_signal(false)
	var latency := _server_browser_filter_controls.get(&"latency_band") as OptionButton
	if is_instance_valid(latency):
		latency.select(0)
	_render_server_browser(presentation)


func _on_server_browser_sort_key_changed(index: int) -> void:
	var keys: Array[StringName] = [&"name", &"latency", &"occupancy", &"compatible_first"]
	var direction: bool = bool(_server_browser_presenter.get_sort().get("descending", false))
	var presentation: Dictionary = _server_browser_presenter.set_sort(keys[clampi(index, 0, keys.size() - 1)], direction)
	_render_server_browser(presentation)


func _toggle_server_browser_sort_direction() -> void:
	var current: Dictionary = _server_browser_presenter.get_sort()
	var presentation: Dictionary = _server_browser_presenter.set_sort(StringName(str(current.get("key", &"name"))), not bool(current.get("descending", false)))
	_render_server_browser(presentation)


func _clear_server_browser_sort() -> void:
	var presentation: Dictionary = _server_browser_presenter.clear_sort()
	_render_server_browser(presentation)


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


func _configure_server_browser_result_focus_order(
	result_controls: Array[Control], clear_sort: Control, refresh: Control
	) -> void:
	if not is_instance_valid(clear_sort) or not is_instance_valid(refresh):
		return
	var previous := clear_sort
	for control in result_controls:
		if not is_instance_valid(control) or control.focus_mode == Control.FOCUS_NONE:
			continue
		previous.focus_neighbor_bottom = previous.get_path_to(control)
		control.focus_neighbor_top = control.get_path_to(previous)
		previous = control
	previous.focus_neighbor_bottom = previous.get_path_to(refresh)
	refresh.focus_neighbor_top = refresh.get_path_to(previous)


func _request_server_browser_result_visible(control: Control) -> void:
	_ensure_server_browser_result_visible.call_deferred(control)


func _ensure_server_browser_result_visible(control: Control) -> void:
	if (
		not is_inside_tree()
		or is_queued_for_deletion()
		or not is_instance_valid(_server_browser_results_scroll)
		or _server_browser_results_scroll.is_queued_for_deletion()
		or not _server_browser_results_scroll.is_inside_tree()
		or not is_instance_valid(_server_browser_page)
		or _server_browser_page.is_queued_for_deletion()
		or not _server_browser_page.is_inside_tree()
		or not _server_browser_page.is_visible_in_tree()
		or not is_instance_valid(control)
		or control.is_queued_for_deletion()
		or not control.is_inside_tree()
		or not control.is_visible_in_tree()
		or not _server_browser_results_scroll.is_ancestor_of(control)
		or get_viewport().gui_get_focus_owner() != control
	):
		return
	_server_browser_results_scroll.ensure_control_visible(control)


func _render_server_browser(presentation: Dictionary) -> void:
	var status := StringName(str(presentation.get("status", &"empty")))
	var refresh := (
		_server_browser_page.find_child("ServerBrowserRefreshButton", true, false)
		as Button
	)
	var clear_sort := _server_browser_sort_controls.get(&"clear_sort") as Control
	var focused_session_id: StringName = &""
	var focus_owner := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus_owner) \
			and is_instance_valid(_server_browser_rows) \
			and _server_browser_rows.is_ancestor_of(focus_owner):
		focused_session_id = StringName(focus_owner.get_meta(&"session_id", &""))
	var status_title: String = {
		&"loading": "REFRESHING SERVER LIST",
		&"refreshing": "REFRESHING SERVER LIST",
		&"empty": "NO SESSIONS FOUND",
		&"expired": "SERVER LIST EXPIRED",
		&"error": "SERVER LIST UNAVAILABLE",
		&"full": "ALL SESSIONS FULL",
		&"ready": "AVAILABLE SESSIONS",
	}.get(status, "SERVER BROWSER")
	_server_browser_title.text = status_title
	_server_browser_detail.text = str(presentation.get("error_message", "Select a session to request joining."))
	_server_browser_filter_summary.text = str(presentation.get("active_filter_summary", "FILTERS: NONE"))
	_server_browser_sort_summary.text = str((presentation.get("sort", {}) as Dictionary).get("summary", "SORT: NAME ↑"))
	var sort_state := presentation.get("sort", {}) as Dictionary
	var sort_keys: Array[StringName] = [&"name", &"latency", &"occupancy", &"compatible_first"]
	var sort_key := _server_browser_sort_controls.get(&"sort_key") as OptionButton
	if is_instance_valid(sort_key):
		sort_key.select(sort_keys.find(StringName(str(sort_state.get("key", &"name")))))
	var sort_direction := _server_browser_sort_controls.get(&"sort_direction") as Button
	if is_instance_valid(sort_direction):
		sort_direction.text = "DESCENDING" if bool(sort_state.get("descending", false)) else "ASCENDING"
	var active_filters := presentation.get("accessibility_filters", {}) as Dictionary
	for filter_id: StringName in [&"compatible_only", &"not_full", &"no_password"]:
		var check := _server_browser_filter_controls.get(filter_id) as CheckButton
		if is_instance_valid(check):
			check.set_pressed_no_signal(bool(active_filters.get(filter_id, false)))
	var latency_filter := _server_browser_filter_controls.get(&"latency_band") as OptionButton
	if is_instance_valid(latency_filter):
		var latency_index := [&"", &"excellent", &"good", &"poor", &"unknown"].find(StringName(str(active_filters.get("latency_band", &""))))
		latency_filter.select(maxi(latency_index, 0))
	for child in _server_browser_rows.get_children():
		_server_browser_rows.remove_child(child)
		child.queue_free()
	var retry_focus_target: Button
	var result_focus_controls: Array[Control] = []
	var row_buttons: Dictionary = {}
	var rows: Array = presentation.get("rows", [])
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		var button := _menu_button(
			"%s  //  %s  //  %s  //  %s  //  %s  //  %s  //  %s" % [
				str(row.get("title", "Unnamed session")),
				str(row.get("region_label", "UNKNOWN")),
				str(row.get("latency_band", row.get("ping_label", "Latency Unknown"))),
				str(row.get("occupancy_label", "0/0 players")),
				str(row.get("capacity_label", "AVAILABLE")),
				str(row.get("password_label", "Password Unknown")),
				str(row.get("compatibility_label", "Compatibility Unknown")),
			],
			MUTED if bool(row.get("full", false)) else NOMINAL_SOFT
		)
		var session_id := StringName(str(row.get("session_id", &"")))
		var row_disabled := bool(row.get("full", false))
		button.set_meta(&"session_id", session_id)
		button.disabled = row_disabled
		button.focus_mode = Control.FOCUS_NONE if row_disabled else Control.FOCUS_ALL
		button.tooltip_text = str(row.get("focus_label", "Select server"))
		button.pressed.connect(request_server_browser_join.bind(session_id))
		_server_browser_rows.add_child(button)
		if not session_id.is_empty():
			row_buttons[session_id] = button
		if not row_disabled:
			result_focus_controls.append(button)
	if status in [&"error", &"expired"] and bool(presentation.get("retryable", false)):
		var retry_after_milliseconds := maxi(int(presentation.get("retry_after_milliseconds", 0)), 0)
		var retry_label := "RETRY SERVER LIST"
		if retry_after_milliseconds > 0:
			retry_label += " (%d MS)" % retry_after_milliseconds
		var retry := _menu_button(retry_label, NOMINAL)
		retry.name = "ServerBrowserRetryButton"
		retry.focus_mode = Control.FOCUS_ALL
		retry.tooltip_text = "Retry the server directory request"
		retry.pressed.connect(request_server_browser_refresh)
		_server_browser_rows.add_child(retry)
		retry_focus_target = retry
		result_focus_controls.append(retry)
	_configure_server_browser_result_focus_order(result_focus_controls, clear_sort, refresh)
	if is_instance_valid(retry_focus_target):
		# The presenter's retry focus target is an accessibility instruction. Keep
		# the live retained control as the re-entry target as well as focusing it now.
		_server_browser_focus_target = retry_focus_target
		retry_focus_target.grab_focus()
	elif status == &"refreshing" and is_instance_valid(refresh):
		_server_browser_focus_target = refresh
		refresh.grab_focus()
	elif status == &"full" and is_instance_valid(refresh):
		# Every result row is disabled, so keep controller recovery on the
		# stable refresh action named by the presenter's all-full status.
		_server_browser_focus_target = refresh
		refresh.grab_focus()
	elif not focused_session_id.is_empty():
		var retained_row := row_buttons.get(focused_session_id) as Button
		if is_instance_valid(retained_row) and not retained_row.disabled:
			_server_browser_focus_target = retained_row
			retained_row.grab_focus()
			_request_server_browser_result_visible(retained_row)
		elif is_instance_valid(refresh):
			# A rebuilt directory must not silently move the player to another session.
			# Return to the stable caller-owned action when that identity disappeared.
			_server_browser_focus_target = refresh
			refresh.grab_focus()


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


func _add_patrol_branch_choices(parent: VBoxContainer) -> void:
	var choices := HBoxContainer.new()
	choices.name = "PatrolBranchChoices"
	choices.add_theme_constant_override("separation", 8)
	parent.add_child(choices)
	for branch: Dictionary in [
		{
			"id": &"relay_sweep",
			"text": "RELAY SWEEP",
			"tooltip": "Inspect the relay-side beacon order.",
		},
		{
			"id": &"platform_sweep",
			"text": "PLATFORM SWEEP",
			"tooltip": "Inspect the platform-side beacon order.",
		},
	]:
		var branch_id := StringName(branch.id)
		var button := _menu_button(str(branch.text), MUTED)
		button.name = String(branch_id).to_pascal_case() + "PatrolBranchButton"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = str(branch.tooltip)
		button.pressed.connect(_request_patrol_branch_selection.bind(branch_id))
		choices.add_child(button)
		_patrol_branch_buttons[branch_id] = button


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
	_add_option_setting(display_group, &"display_resolution", "Resolution", ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"], 2)
	_add_option_setting(display_group, &"vsync_mode", "VSync", ["Off", "On", "Adaptive"], 1)

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
		&"reduced_flash",
		"Reduce screen flashes",
		"Suppresses bright damage flashes while retaining text and directional cues.",
		false
	)
	_add_toggle_setting_with_help(
		accessibility_group,
		&"reduced_dynamic_range",
		"Reduced dynamic range",
		"Limits extreme brightness and contrast changes while preserving readable state cues.",
		false
	)
	_add_option_setting(
		accessibility_group,
		&"payload_visual_intensity",
		"Payload visual intensity",
		["Low", "Medium", "High"],
		2
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
	_configure_accessibility_focus_neighbors()
	_refresh_accessibility_tooltips()

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
	_settings_repair_panel = PanelContainer.new()
	_settings_repair_panel.name = "SettingsRepairNotice"
	_settings_repair_panel.visible = false
	_settings_repair_panel.add_theme_stylebox_override(
		"panel", _border_box(Color("241d17"), 6, CAUTION)
	)
	var repair_margin := _margin(14, 10, 14, 10)
	_settings_repair_panel.add_child(repair_margin)
	var repair_stack := VBoxContainer.new()
	repair_stack.add_theme_constant_override("separation", 6)
	repair_margin.add_child(repair_stack)
	_settings_repair_title = _label("SETTINGS RECOVERY", 11, CAUTION)
	_settings_repair_title.name = "SettingsRepairTitle"
	_settings_repair_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	repair_stack.add_child(_settings_repair_title)
	_settings_repair_detail = _label("", 10, NOMINAL_SOFT)
	_settings_repair_detail.name = "SettingsRepairDetail"
	_settings_repair_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_repair_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	repair_stack.add_child(_settings_repair_detail)
	_settings_repair_confirm_button = _menu_button("CONFIRM BACKUP REPAIR", CAUTION)
	_settings_repair_confirm_button.name = "SettingsRepairConfirmButton"
	_settings_repair_confirm_button.focus_mode = Control.FOCUS_ALL
	_settings_repair_confirm_button.tooltip_text = (
		"Send the exact backup-repair confirmation to the settings owner."
	)
	_settings_repair_confirm_button.pressed.connect(_request_settings_repair_confirmation)
	repair_stack.add_child(_settings_repair_confirm_button)
	page_stack.add_child(_settings_repair_panel)
	_display_confirmation_panel = PanelContainer.new()
	_display_confirmation_panel.name = "DisplaySettingsConfirmation"
	_display_confirmation_panel.visible = false
	var display_confirmation_stack := VBoxContainer.new()
	display_confirmation_stack.add_theme_constant_override("separation", 5)
	_display_confirmation_panel.add_child(display_confirmation_stack)
	_display_confirmation_summary_label = _label("PENDING DISPLAY", 11, NOMINAL_SOFT)
	_display_confirmation_summary_label.name = "DisplayConfirmationSummary"
	_display_confirmation_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display_confirmation_stack.add_child(_display_confirmation_summary_label)
	_display_confirmation_label = _label("KEEP DISPLAY CHANGE  //  REVERT IN: 0 SECONDS", 10, NOMINAL_SOFT)
	_display_confirmation_label.name = "DisplayConfirmationCountdown"
	_display_confirmation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display_confirmation_stack.add_child(_display_confirmation_label)
	_display_confirmation_result_label = _label("", 10, NOMINAL_SOFT)
	_display_confirmation_result_label.name = "DisplayConfirmationResult"
	_display_confirmation_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display_confirmation_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_display_confirmation_result_label.visible = false
	display_confirmation_stack.add_child(_display_confirmation_result_label)
	var display_confirmation_actions := HBoxContainer.new()
	display_confirmation_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	display_confirmation_stack.add_child(display_confirmation_actions)
	_display_confirmation_keep_button = _binding_button("KEEP DISPLAY")
	_display_confirmation_keep_button.name = "KeepDisplaySettingsButton"
	_display_confirmation_keep_button.tooltip_text = "Keep the pending resolution and window mode."
	_display_confirmation_keep_button.focus_neighbor_right = NodePath("../RevertDisplaySettingsButton")
	_display_confirmation_keep_button.pressed.connect(func() -> void: display_settings_keep_requested.emit(_display_confirmation_generation))
	display_confirmation_actions.add_child(_display_confirmation_keep_button)
	_display_confirmation_revert_button = _binding_button("REVERT DISPLAY")
	_display_confirmation_revert_button.name = "RevertDisplaySettingsButton"
	_display_confirmation_revert_button.tooltip_text = "Revert the pending resolution and window mode."
	_display_confirmation_revert_button.focus_neighbor_left = NodePath("../KeepDisplaySettingsButton")
	_display_confirmation_revert_button.pressed.connect(func() -> void: display_settings_revert_requested.emit(_display_confirmation_generation))
	display_confirmation_actions.add_child(_display_confirmation_revert_button)
	page_stack.add_child(_display_confirmation_panel)
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
	var deadzone := (controls.deadzone as HSlider).value
	var curve := (
		&"squared" if (controls.curve as OptionButton).selected == 1 else &"linear"
	)
	var hold_mode := (
		&"toggle" if (controls.hold_mode as OptionButton).selected == 1 else &"hold"
	)
	var snapshot := _input_remapping_presenter.commit_options(
		action,
		deadzone,
		curve,
		hold_mode
	)
	if snapshot.status == &"committed":
		_commit_input_remapping_snapshot(
			"INPUT OPTIONS  //  %s  //  %s  //  %s CURVE  //  %d%% DEADZONE"
			% [
				_input_action_label(action).to_upper(),
				String(hold_mode).to_upper(),
				String(curve).to_upper(),
				roundi(deadzone * 100.0),
			]
		)
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
		_set_help_text(_help_rows_with_role_context(_state_mode))
	_refresh_retained_bomber_payload_input_prompts()
	if (
		not is_queued_for_deletion()
		and not _first_sortie_tutorial_source_snapshot.is_empty()
		and _runtime_status_cards.has(&"tutorial")
	):
		apply_first_sortie_tutorial_snapshot(
			_first_sortie_tutorial_source_snapshot, false
		)


func _refresh_input_prompts_after_reentry() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_refresh_input_prompts()


func _tutorial_input_family() -> StringName:
	if _runtime_input_glyph_presenter == null:
		return &"keyboard"
	var family := StringName(str(
		_runtime_input_glyph_presenter.get_snapshot().get("device_family", &"keyboard")
	))
	return &"keyboard" if family in [&"keyboard", &"mouse"] else &"controller"


func _tutorial_glyphs() -> Dictionary:
	var glyphs := {}
	if _runtime_input_glyph_presenter == null:
		return glyphs
	for action: StringName in [
		&"interact", &"move_forward", &"move_left", &"move_right",
		&"pitch_up", &"pitch_down", &"fire", &"landing_assist", &"brake",
	]:
		var resolved: Dictionary = _runtime_input_glyph_presenter.resolve_action(action)
		glyphs[action] = (
			str(resolved.get("text", "INPUT"))
			if bool(resolved.get("valid", false)) else "INPUT"
		)
	return glyphs


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
	selector.focus_mode = Control.FOCUS_ALL
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
	for option: String in ["Automatic", "Generic", "Xbox", "PlayStation", "Nintendo", "Steam Deck"]:
		selector.add_item(option)
	selector.select(0)
	selector.item_selected.connect(_on_controller_glyph_family_selected)
	row.add_child(selector)
	var hint := _label("Presentation only — not saved with gameplay settings.", 10, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hint)
	_settings_controls[_CONTROLLER_GLYPH_FAMILY_KEY] = selector


func _configure_accessibility_focus_neighbors() -> void:
	var ordered_keys: Array[StringName] = [
		&"master_volume", &"ambience_volume", &"music_volume", &"engine_volume",
		&"weapons_volume", &"ui_volume", &"ui_scale", &"colorblind_palette",
		&"reduced_motion", &"reduced_flash", &"reduced_dynamic_range",
		&"payload_visual_intensity", &"captions_enabled", &"show_tutorials",
		_CONTROLLER_GLYPH_FAMILY_KEY,
	]
	var controls: Array[Control] = []
	for key: StringName in ordered_keys:
		var control := _settings_controls.get(key) as Control
		if control != null and control.focus_mode != Control.FOCUS_NONE:
			controls.append(control)
	for index in controls.size():
		var control := controls[index]
		control.focus_neighbor_top = control.get_path_to(controls[maxi(0, index - 1)])
		control.focus_neighbor_bottom = control.get_path_to(controls[mini(controls.size() - 1, index + 1)])


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
		"reduced_flash": _reduced_flash,
		"transition_policy": &"steady_no_flash" if _reduced_flash else &"consumer_standard",
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
		InputGlyphResolverType.FAMILY_GAMEPAD_STEAM,
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
	if not _updating_settings and _runtime_display_settings_presenter != null:
		var display_result := _display_settings_intent(key, value)
		if not display_result.is_empty():
			if not bool(display_result.get("accepted", false)):
				return
			value = (display_result.get("values", {}) as Dictionary).get(String(key), value)
	if value is float:
		_update_setting_value_label(key, float(value))
		if key == &"ui_scale":
			# Apply the preview locally before the settings owner persists it. This
			# keeps an in-progress accessibility adjustment visible even when the
			# HUD is detached or the owner responds on a later frame.
			set_ui_scale(float(value))
	if key == &"show_tutorials":
		_apply_show_tutorials_setting(bool(value))
	if not _updating_settings:
		_settings_dirty = true
		setting_change_requested.emit(key, value)
	if key == &"reduced_flash" or key == &"payload_visual_intensity":
		_refresh_accessibility_tooltips()


func _display_settings_intent(key: StringName, value: Variant) -> Dictionary:
	var generation := int(_runtime_display_settings_presenter.get_snapshot().get("generation", -1))
	if key == &"window_mode":
		return _runtime_display_settings_presenter.select_window_mode(
			[&"windowed", &"borderless", &"fullscreen"][clampi(int(value), 0, 2)], generation
		)
	if key == &"display_resolution":
		return _runtime_display_settings_presenter.select_resolution(
			StringName(str(RuntimeSettingsType.SUPPORTED_DISPLAY_RESOLUTION_IDS[clampi(int(value), 0, 3)])), generation
		)
	if key == &"vsync_mode":
		return _runtime_display_settings_presenter.select_vsync(
			[&"off", &"on", &"adaptive"][clampi(int(value), 0, 2)], generation
		)
	return {}


func _display_option_index(key: StringName, value: Variant) -> int:
	if key == &"window_mode":
		return int(value) if value is int else [&"windowed", &"borderless", &"fullscreen"].find(StringName(str(value)))
	if key == &"display_resolution":
		return RuntimeSettingsType.SUPPORTED_DISPLAY_RESOLUTION_IDS.find(String(value))
	if key == &"vsync_mode":
		return int(value) if value is int else [&"off", &"on", &"adaptive"].find(StringName(str(value)))
	return int(value)


func _refresh_accessibility_tooltips() -> void:
	var reduced_flash := _settings_controls.get(&"reduced_flash") as CheckButton
	if reduced_flash != null:
		reduced_flash.tooltip_text = "Reduce screen flashes: %s. Text and directional cues remain visible." % ("ON" if reduced_flash.button_pressed else "OFF")
	var payload_intensity := _settings_controls.get(&"payload_visual_intensity") as OptionButton
	if payload_intensity != null and payload_intensity.item_count > 0:
		payload_intensity.tooltip_text = "Payload visual intensity: %s. Choose low, medium, or high." % payload_intensity.get_item_text(payload_intensity.selected)


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
	if _nearby_activity_page != null:
		_nearby_activity_page.visible = false
	_server_browser_page.visible = false
	if _planetary_destination_page != null:
		_planetary_destination_page.visible = false
	_settings_page.visible = true
	var target := _settings_focus_target
	if (
		not is_instance_valid(target)
		or not _settings_page.is_ancestor_of(target)
		or not target.is_visible_in_tree()
		or target.focus_mode == Control.FOCUS_NONE
	):
		target = _settings_controls.get(&"ship_mouse_sensitivity") as Control
	if target != null:
		target.grab_focus()


func _show_pause_main() -> void:
	if (
		_pause_main_page == null
		or _activity_selection_page == null
		or _settings_page == null
	):
		return
	var returning_from_activity := (
		_activity_selection_page.visible
		or (_nearby_activity_page != null and _nearby_activity_page.visible)
	)
	var returning_from_browser := _server_browser_page != null and _server_browser_page.visible
	var returning_from_destinations := (
		_planetary_destination_page != null
		and _planetary_destination_page.visible
	)
	if returning_from_browser:
		var browser_focus_was_transient := (
			not is_instance_valid(_server_browser_focus_target)
			or _server_browser_focus_target.name == &"ServerBrowserRetryButton"
			or _server_browser_rows.is_ancestor_of(_server_browser_focus_target)
		)
		_render_server_browser(_server_browser_presenter.close_view())
		_server_browser_accept_results = false
		if browser_focus_was_transient:
			_server_browser_focus_target = _server_browser_page.find_child(
				"ServerBrowserRefreshButton", true, false
			) as Button
	_binding_capture_action = &""
	_cancel_pending_input_conflict(false)
	_pause_main_page.visible = true
	_activity_selection_page.visible = false
	if _nearby_activity_page != null:
		_nearby_activity_page.visible = false
	_server_browser_page.visible = false
	if _planetary_destination_page != null:
		_planetary_destination_page.visible = false
	_settings_page.visible = false
	var focus_button := _pause_main_page.find_child(
		"ActivityBoardButton" if returning_from_activity else (
			"ServerBrowserButton" if returning_from_browser else (
				"PlanetaryDestinationOpenButton"
				if returning_from_destinations
				else "SettingsOpenButton"
			)
		),
		true,
		false
	) as Button
	if _pause.visible and focus_button != null:
		focus_button.grab_focus()


func _show_activity_selection_page() -> void:
	var returning_from_nearby := (
		_nearby_activity_page != null and _nearby_activity_page.visible
	)
	_pause_main_page.visible = false
	_settings_page.visible = false
	_server_browser_page.visible = false
	if _planetary_destination_page != null:
		_planetary_destination_page.visible = false
	if _nearby_activity_page != null:
		_nearby_activity_page.visible = false
	_activity_selection_page.visible = true
	_refresh_activity_selection_page(_activity_selection_status_reason)
	var selected_button := (
		_activity_selection_page.find_child(
			"NearbyActivityOpenButton", true, false
		) as Button
		if returning_from_nearby
		else _activity_selection_buttons.get(_activity_selection_kind) as Button
	)
	if selected_button != null:
		selected_button.grab_focus()


func _show_planetary_destination_page() -> void:
	if not is_instance_valid(_planetary_destination_page):
		return
	_pause_main_page.visible = false
	_activity_selection_page.visible = false
	if _nearby_activity_page != null:
		_nearby_activity_page.visible = false
	_server_browser_page.visible = false
	_settings_page.visible = false
	_planetary_destination_page.visible = true
	_restore_planetary_destination_focus()


## Public embodied entry point for the station's physical navigation console.
## It opens the same retained page as the pause-menu button and adds no route or
## travel authority of its own.
func open_planetary_destination_board() -> bool:
	if (
		is_queued_for_deletion()
		or not is_inside_tree()
		or _pause == null
		or _planetary_destination_page == null
	):
		return false
	set_paused(true)
	_show_planetary_destination_page()
	return _pause.visible and _planetary_destination_page.visible


## Public embodied entry point for the existing Activity Board.  The board is
## still the pause-overlay page: this method only exposes its established
## visibility and focus lifecycle to a physical station console.
func open_activity_board() -> bool:
	if (
		is_queued_for_deletion()
		or not is_inside_tree()
		or _pause == null
		or _activity_selection_page == null
	):
		return false
	set_paused(true)
	_show_activity_selection_page()
	return _pause.visible and _activity_selection_page.visible


## Accepts a detached, bounded receipt summary only. The HUD can display the
## persisted return record, but it cannot inspect the store, grant a reward, or
## infer currency or inventory from the receipt label.
func set_activity_reward_summary(summary: Dictionary) -> bool:
	if not _has_exact_string_keys(summary, ACTIVITY_REWARD_SUMMARY_KEYS):
		return false
	var available_value: Variant = summary.get("available")
	var total_value: Variant = summary.get("total_receipts")
	var receipt_value: Variant = summary.get("last_receipt_id")
	var label_value: Variant = summary.get("last_reward_label")
	if (
		available_value is not bool
		or total_value is not int
		or receipt_value is not int
		or label_value is not String
	):
		return false
	var available := bool(available_value)
	var total_receipts := int(total_value)
	var last_receipt_id := int(receipt_value)
	var last_reward_label := str(label_value)
	if (
		total_receipts < 0
		or total_receipts > MAX_ACTIVITY_REWARD_RECEIPTS
		or last_receipt_id < 0
		or last_receipt_id > MAX_ACTIVITY_REWARD_RECEIPTS
		or (
			not available
			and (
				total_receipts != 0
				or last_receipt_id != 0
				or not last_reward_label.is_empty()
			)
		)
		or (
			available
			and total_receipts == 0
			and (
				last_receipt_id != 0
				or not last_reward_label.is_empty()
			)
		)
		or (
			available
			and total_receipts > 0
			and (
				last_receipt_id != total_receipts
				or last_reward_label not in ACTIVITY_REWARD_LABELS
			)
		)
	):
		return false
	_activity_reward_summary = summary.duplicate(true)
	_refresh_activity_reward_summary()
	return true


func _refresh_activity_reward_summary() -> void:
	if (
		not is_instance_valid(_activity_reward_summary_label)
		or not is_instance_valid(_activity_reward_latest_label)
	):
		return
	if not bool(_activity_reward_summary.get("available", false)):
		_activity_reward_summary_label.text = "SHIPYARD RECEIPTS  //  OFFLINE"
		_activity_reward_latest_label.text = (
			"PERSISTENT RETURN RECORDS ARE UNAVAILABLE"
		)
		return
	var total_receipts := int(_activity_reward_summary.get("total_receipts", 0))
	if total_receipts == 0:
		_activity_reward_summary_label.text = "SHIPYARD RECEIPTS  //  NONE FILED"
		_activity_reward_latest_label.text = (
			"COMPLETE A LISTED SORTIE TO FILE A RETURN RECEIPT"
		)
		return
	_activity_reward_summary_label.text = "SHIPYARD RECEIPTS  //  %d FILED" % total_receipts
	_activity_reward_latest_label.text = "LATEST #%d  //  %s" % [
		int(_activity_reward_summary.get("last_receipt_id", 0)),
		str(_activity_reward_summary.get("last_reward_label", "")).to_upper(),
	]


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
	_activity_selection_status_reason = status_reason
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


func set_patrol_branch_selection_state(
	branch_id: StringName,
	selection_locked: bool,
	status_reason: StringName = &""
	) -> bool:
	if branch_id not in [&"relay_sweep", &"platform_sweep"]:
		return false
	_patrol_branch_id = branch_id
	_activity_selection_locked = selection_locked
	_refresh_patrol_branch_choices()
	if status_reason not in [&"", &"branch_selected", &"already_selected"] \
			and is_instance_valid(_activity_selection_status_label):
		_activity_selection_status_label.text = (
			"ROUTE NOT CHANGED  //  "
			+ str(status_reason).replace("_", " ").to_upper()
		)
		_activity_selection_status_label.modulate = _c(DANGER)
	return true


func _request_activity_selection(activity_kind: StringName) -> void:
	activity_selection_requested.emit(activity_kind)


func _request_patrol_branch_selection(branch_id: StringName) -> void:
	patrol_branch_selection_requested.emit(branch_id)


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
		button.text = (
			"REPEAT  //  "
			if selected and _activity_selection_locked and status_reason == &"repeat_ready"
			else ("SELECTED  //  " if selected else "")
		) + base_text
	_refresh_patrol_branch_choices()
	if _activity_selection_status_label == null:
		return
	var selected_text := {
		&"timed_race": "TIMED CINDER RACE",
		&"patrol": "CINDER PATROL",
		&"cargo_delivery": "JOVIAN KIT DELIVERY",
		&"convoy_escort": "EMBERLINE CONVOY ESCORT",
	}.get(_activity_selection_kind, String(_activity_selection_kind).to_upper()) as String
	if _activity_selection_locked and status_reason == &"repeat_ready":
		_activity_selection_status_label.text = "READY  //  REPEAT " + selected_text
		_activity_selection_status_label.modulate = _c(NOMINAL_SOFT)
	elif _activity_selection_locked:
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


func _refresh_patrol_branch_choices() -> void:
	for raw_branch_id: Variant in _patrol_branch_buttons:
		var branch_id := StringName(raw_branch_id)
		var button := _patrol_branch_buttons[branch_id] as Button
		if not is_instance_valid(button):
			continue
		var selected := branch_id == _patrol_branch_id
		button.disabled = _activity_selection_locked
		var base_text := (
			"PLATFORM SWEEP" if branch_id == &"platform_sweep" else "RELAY SWEEP"
		)
		button.text = ("SELECTED  //  " if selected else "") + base_text


## Detached geometry/state evidence for the production button-route and layout
## regressions. It exposes no callback and cannot mutate selection.
func get_activity_selection_report() -> Dictionary:
	var buttons := {}
	var rows := {}
	var patrol_branches := {}
	for raw_kind: Variant in _activity_selection_buttons:
		var activity_kind := StringName(raw_kind)
		var button := _activity_selection_buttons[activity_kind] as Button
		buttons[activity_kind] = {
			"rect": button.get_global_rect(),
			"text": button.text,
			"disabled": button.disabled,
		}
		rows[activity_kind] = (button.get_parent() as Control).get_global_rect()
	for raw_branch_id: Variant in _patrol_branch_buttons:
		var branch_id := StringName(raw_branch_id)
		var branch_button := _patrol_branch_buttons[branch_id] as Button
		patrol_branches[branch_id] = {
			"rect": branch_button.get_global_rect(),
			"text": branch_button.text,
			"disabled": branch_button.disabled,
		}
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
		"selected_patrol_branch_id": _patrol_branch_id,
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
		"reward_summary": _activity_reward_summary.duplicate(true),
		"reward_summary_text": (
			_activity_reward_summary_label.text
			if is_instance_valid(_activity_reward_summary_label)
			else ""
		),
		"reward_latest_text": (
			_activity_reward_latest_label.text
			if is_instance_valid(_activity_reward_latest_label)
			else ""
		),
		"reward_panel_rect": (
			_activity_reward_panel.get_global_rect()
			if is_instance_valid(_activity_reward_panel)
			else Rect2()
		),
		"reward_summary_rect": (
			_activity_reward_summary_label.get_global_rect()
			if is_instance_valid(_activity_reward_summary_label)
			else Rect2()
		),
		"reward_latest_rect": (
			_activity_reward_latest_label.get_global_rect()
			if is_instance_valid(_activity_reward_latest_label)
			else Rect2()
		),
		"back_rect": back.get_global_rect() if back != null else Rect2(),
		"buttons": buttons,
		"patrol_branch_buttons": patrol_branches,
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
	_help_rows = rows.duplicate(true)
	var page_count := maxi(1, ceili(float(_help_rows.size()) / float(HELP_ROWS_PER_PAGE)))
	_help_page_index = clampi(_help_page_index, 0, page_count - 1)
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
	if _bomber_payload_help_button == null:
		_bomber_payload_help_button = _menu_button("PAYLOAD // WAITING FOR BOMBER", NOMINAL)
		_bomber_payload_help_button.name = "BomberPayloadTutorialButton"
		_bomber_payload_help_button.focus_mode = Control.FOCUS_ALL
		_bomber_payload_help_button.pressed.connect(request_bomber_payload_release)
		_help_stack.add_child(_bomber_payload_help_button)
	if _help_close_button == null:
		var navigation := HBoxContainer.new()
		navigation.name = "HelpNavigation"
		navigation.alignment = BoxContainer.ALIGNMENT_CENTER
		navigation.add_theme_constant_override("separation", 5)
		_help_previous_button = _menu_button("PREVIOUS", MUTED)
		_help_previous_button.name = "HelpPreviousButton"
		_help_previous_button.tooltip_text = "Show the previous controls page"
		_help_previous_button.focus_mode = Control.FOCUS_ALL
		_help_previous_button.pressed.connect(_previous_help_page)
		navigation.add_child(_help_previous_button)
		_help_page_label = _label("PAGE 1 / 1", 10, NOMINAL_SOFT)
		_help_page_label.name = "HelpPageLabel"
		_help_page_label.custom_minimum_size.x = 86.0
		_help_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		navigation.add_child(_help_page_label)
		_help_next_button = _menu_button("NEXT", MUTED)
		_help_next_button.name = "HelpNextButton"
		_help_next_button.tooltip_text = "Show the next controls page"
		_help_next_button.focus_mode = Control.FOCUS_ALL
		_help_next_button.pressed.connect(_next_help_page)
		navigation.add_child(_help_next_button)
		_help_close_button = _menu_button("CLOSE", NOMINAL)
		_help_close_button.name = "HelpCloseButton"
		_help_close_button.tooltip_text = "Close controls help"
		_help_close_button.focus_mode = Control.FOCUS_ALL
		_help_close_button.pressed.connect(_close_help_panel)
		navigation.add_child(_help_close_button)
		_help_previous_button.focus_neighbor_right = _help_previous_button.get_path_to(_help_next_button)
		_help_next_button.focus_neighbor_left = _help_next_button.get_path_to(_help_previous_button)
		_help_next_button.focus_neighbor_right = _help_next_button.get_path_to(_help_close_button)
		_help_close_button.focus_neighbor_left = _help_close_button.get_path_to(_help_next_button)
		_help_stack.add_child(navigation)
	_refresh_help_page()
	_refresh_bomber_payload_help()
	_set_mouse_passthrough(_help_panel)


func _refresh_help_page() -> void:
	if not is_instance_valid(_help_page_label):
		return
	var page_count := maxi(1, ceili(float(_help_rows.size()) / float(HELP_ROWS_PER_PAGE)))
	_help_page_index = clampi(_help_page_index, 0, page_count - 1)
	var first := _help_page_index * HELP_ROWS_PER_PAGE
	for index in _help_row_controls.size():
		var controls := _help_row_controls[index] as Dictionary
		var line := controls.line as Control
		line.visible = index >= first and index < mini(first + HELP_ROWS_PER_PAGE, _help_rows.size())
	_help_page_label.text = "PAGE %d / %d" % [_help_page_index + 1, page_count]
	_help_previous_button.disabled = _help_page_index <= 0
	_help_next_button.disabled = _help_page_index >= page_count - 1


func _previous_help_page() -> void:
	_help_page_index = maxi(_help_page_index - 1, 0)
	_refresh_help_page()
	_help_previous_button.grab_focus()


func _next_help_page() -> void:
	var page_count := maxi(1, ceili(float(_help_rows.size()) / float(HELP_ROWS_PER_PAGE)))
	_help_page_index = mini(_help_page_index + 1, page_count - 1)
	_refresh_help_page()
	_help_next_button.grab_focus()


func _close_help_panel() -> void:
	_help_panel.visible = false
	if is_instance_valid(_help_close_button):
		_help_close_button.release_focus()


func _refresh_bomber_payload_help() -> void:
	if _bomber_payload_help_button == null:
		return
	var snapshot := _bomber_payload_help_snapshot
	var attached := not snapshot.is_empty() and bool(snapshot.get("attached", false))
	_bomber_payload_help_button.visible = attached and bool(snapshot.get("active", true))
	if not attached:
		return
	var state := str(snapshot.get("state", "unavailable")).to_upper()
	var release_action := StringName(str(snapshot.get("action_id", &"fire")))
	var resolved: Dictionary = _runtime_input_glyph_presenter.resolve_action(release_action)
	var glyph := str(resolved.get("text", "INPUT")) if bool(resolved.get("valid", false)) else "INPUT"
	_bomber_payload_help_button.text = "PAYLOAD  // [%s] RELEASE  // %s" % [glyph, state]
	var intensity_names := ["LOW", "MEDIUM", "HIGH"]
	var intensity: String = intensity_names[clampi(_payload_visual_intensity, 0, intensity_names.size() - 1)]
	var detail := "Payload readiness: %s. Remaining: %d." % [state, maxi(0, int(snapshot.get("ammo", 0)))]
	var cooldown := maxf(0.0, float(snapshot.get("cooldown_remaining", 0.0)))
	if cooldown > 0.0:
		detail += " Cooldown: %.1f seconds." % cooldown
	if not bool(snapshot.get("release_allowed", false)):
		detail += " Unavailable: %s." % str(snapshot.get("reason", "unavailable"))
	detail += " Reduced flash: %s. Visual intensity: %s." % ["ON" if _reduced_flash else "OFF", intensity]
	_bomber_payload_help_button.tooltip_text = detail


## Re-resolves only the local presentation label. Payload ordering, admission,
## authority and the presenter's source receipt remain untouched.
func _decorate_bomber_payload_action_prompt(presentation: Dictionary) -> String:
	var release_action := StringName(str(presentation.get("action_id", &"fire")))
	var resolved: Dictionary = _runtime_input_glyph_presenter.resolve_action(release_action)
	var glyph := str(resolved.get("text", "INPUT")) if bool(resolved.get("valid", false)) else "INPUT"
	var label := "[%s] RELEASE PAYLOAD" % glyph
	var action_rows := presentation.get("actions", []) as Array
	for index in action_rows.size():
		var action := action_rows[index] as Dictionary
		if StringName(str(action.get("id", &""))) != &"release_payload":
			continue
		action["label"] = label
		action_rows[index] = action
		presentation["actions"] = action_rows
		return label
	return ""


## Device/profile changes must repaint the retained Cinder prompt without
## re-ingesting a payload receipt or rebuilding the focused keyed-card action.
func _refresh_retained_bomber_payload_input_prompts() -> void:
	if (
		_state_mode != MODE_PILOTING
		or not _has_cinder_bomber_identity()
		or _bomber_payload_help_snapshot.is_empty()
	):
		return
	var help_snapshot := _bomber_payload_help_snapshot.duplicate(true)
	_decorate_bomber_payload_action_prompt(help_snapshot)
	_bomber_payload_help_snapshot = help_snapshot
	_refresh_bomber_payload_help()
	if not _runtime_status_cards.has(&"bomber"):
		return
	var card := (_runtime_status_cards[&"bomber"] as Dictionary).duplicate(true)
	var retained_snapshot := (card.get("snapshot", {}) as Dictionary).duplicate(true)
	var live_label := _decorate_bomber_payload_action_prompt(retained_snapshot)
	card["snapshot"] = retained_snapshot
	_runtime_status_cards[&"bomber"] = card
	if (
		live_label.is_empty()
		or _runtime_status_kind != &"bomber"
		or not is_instance_valid(_bomber_status_actions)
	):
		return
	var live_button := _bomber_status_actions.get_node_or_null(
		^"RuntimeStatusReleasePayloadButton"
	) as Button
	if is_instance_valid(live_button):
		live_button.text = live_label


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
