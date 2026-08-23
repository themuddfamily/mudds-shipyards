class_name ArrowEntryCockpitReadoutPresentation
extends Label3D

## Physical, ship-local warning-strip repeater for the retained entry presenter.
## Text and symbols carry every state; color is redundant and never flashes.

const COMPONENT_ID: StringName = &"arrow-entry-cockpit-readout-presentation"
const PresenterScript := preload(
	"res://scripts/ui/atmospheric_entry_guidance_presenter.gd"
)
const NOMINAL_COLOR := Color("83f4df")
const WATCH_COLOR := Color("ffd36a")
const CRITICAL_COLOR := Color("ff796f")
const REDUCED_CRITICAL_COLOR := Color("f4c879")
const ENVELOPE_SEGMENT_COUNT := 5
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

var _presenter := PresenterScript.new() as RefCounted
var _observation_count := 0
var _last_snapshot: Dictionary = {}
var _generation := 0
var _last_observation_serial := -1
var _previous_envelope_level := 0


func _ready() -> void:
	if _generation == 0:
		_generation = 1
	position = Vector3(0.0, -0.202, 0.151)
	font_size = 32
	pixel_size = 0.00072
	outline_size = 9
	outline_modulate = Color("07111d")
	no_depth_test = true
	text = ""
	visible = false
	set_meta("presentation_only", true)
	set_meta("physical_cockpit_repeater", true)


func _exit_tree() -> void:
	_clear_visuals(&"detached")
	_last_observation_serial = -1
	_previous_envelope_level = 0
	if _generation < MAX_SAFE_GENERATION:
		_generation += 1


func present_source(
		source: Dictionary, observation_serial: int, expected_generation: int
	) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if observation_serial < 1 or observation_serial > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_observation_serial")
	if _last_observation_serial >= 0 \
			and observation_serial != _last_observation_serial + 1:
		return _result(
			false,
			&"observation_serial_replayed" \
				if observation_serial <= _last_observation_serial \
				else &"observation_serial_skipped",
		)
	var presentation := _presenter.call(&"present_snapshot", source) as Dictionary
	var state := StringName(presentation.get("state", &"support_required"))
	var advisory := StringName(presentation.get(
		"descent_advisory_id", &"safe_descent"
	))
	var reduced_flash := bool(presentation.get("reduced_flash", false))
	var reduced_motion := bool(presentation.get("reduced_motion", false))
	var rendered := _render_tokens(state, advisory, reduced_flash)
	var envelope_level := _envelope_level(presentation, state, advisory)
	var recovery := _previous_envelope_level >= 3 and envelope_level < 3
	var gauge := _gauge_text(envelope_level)
	text = "%s | E%s %d/%d%s" % [
		str(rendered.text), gauge, envelope_level, ENVELOPE_SEGMENT_COUNT,
		" RECOVER" if recovery else "",
	]
	modulate = rendered.color as Color
	visible = true
	_observation_count += 1
	_last_observation_serial = observation_serial
	_previous_envelope_level = envelope_level
	_last_snapshot = {
		"state": state,
		"descent_advisory_id": advisory,
		"text": text,
		"symbol": rendered.symbol,
		"envelope_gauge": {
			"segment_count": ENVELOPE_SEGMENT_COUNT,
			"filled_segments": envelope_level,
			"ascii_silhouette": gauge,
			"severity_id": _severity_id(envelope_level),
			"recovery": recovery,
			"bounded": envelope_level >= 0 \
				and envelope_level <= ENVELOPE_SEGMENT_COUNT,
		}.duplicate(true),
		"color": modulate,
		"reduced_flash": reduced_flash,
		"reduced_motion": reduced_motion,
		"steady": true,
		"color_independent": true,
	}.duplicate(true)
	return _result(true, &"cockpit_entry_presented")


func clear(
		reason: StringName, expected_generation: int
	) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	_clear_visuals(reason)
	_last_observation_serial = -1
	_previous_envelope_level = 0
	_generation += 1
	return _result(true, reason)


func _clear_visuals(reason: StringName) -> void:
	text = ""
	visible = false
	_last_snapshot = {
		"state": &"cleared",
		"text": "",
		"symbol": &"",
		"steady": true,
		"color_independent": true,
		"envelope_gauge": {
			"segment_count": ENVELOPE_SEGMENT_COUNT,
			"filled_segments": 0,
			"ascii_silhouette": _gauge_text(0),
			"severity_id": &"clear",
			"recovery": false,
			"bounded": true,
		}.duplicate(true),
		"reason": reason,
	}.duplicate(true)


func get_generation() -> int:
	return _generation


func get_snapshot() -> Dictionary:
	var snapshot := {
		"component_id": COMPONENT_ID,
		"visible": visible,
		"text": text,
		"observation_count": _observation_count,
		"generation": _generation,
		"last_observation_serial": _last_observation_serial,
		"physical_cockpit_repeater": true,
		"presentation_only": true,
		"collision_authority": false,
		"physics_authority": false,
		"movement_authority": false,
		"damage_authority": false,
		"atmosphere_authority": false,
		"landing_authority": false,
	}
	for key: Variant in _last_snapshot:
		snapshot[key] = _last_snapshot[key]
	return snapshot.duplicate(true)


func _envelope_level(
		presentation: Dictionary, state: StringName, advisory: StringName
	) -> int:
	if state == &"airless_descent":
		if advisory == &"high_sink_rate":
			return 4
		if advisory == &"climb_exit":
			return 0
		return 1
	var intensity := clampf(float(presentation.get("entry_intensity", 0.0)), 0.0, 1.0)
	var level := clampi(roundi(intensity * ENVELOPE_SEGMENT_COUNT), 0, ENVELOPE_SEGMENT_COUNT)
	if state == &"critical_entry":
		return ENVELOPE_SEGMENT_COUNT
	if state == &"entry_watch":
		return maxi(3, level)
	return level


func _gauge_text(level: int) -> String:
	var result := "["
	for index in ENVELOPE_SEGMENT_COUNT:
		result += "#" if index < level else "-"
	return result + "]"


func _severity_id(level: int) -> StringName:
	if level >= 5:
		return &"critical"
	if level >= 3:
		return &"warning"
	if level >= 1:
		return &"nominal"
	return &"clear"


func _render_tokens(
		state: StringName, advisory: StringName, reduced_flash: bool
	) -> Dictionary:
	if state == &"airless_descent":
		match advisory:
			&"high_sink_rate":
				return {
					"text": "AIRLESS | [!!] HIGH SINK",
					"symbol": &"[!!]",
					"color": REDUCED_CRITICAL_COLOR \
						if reduced_flash else CRITICAL_COLOR,
				}
			&"climb_exit":
				return {
					"text": "AIRLESS | [^] CLIMB / EXIT",
					"symbol": &"[^]",
					"color": NOMINAL_COLOR,
				}
			_:
				return {
					"text": "AIRLESS | [v] DESCENT SAFE",
					"symbol": &"[v]",
					"color": NOMINAL_COLOR,
				}
	if state == &"critical_entry":
		return {
			"text": "ATM HEAT | [!!] CRITICAL",
			"symbol": &"[!!]",
			"color": REDUCED_CRITICAL_COLOR \
				if reduced_flash else CRITICAL_COLOR,
		}
	if state == &"entry_watch":
		return {
			"text": "ATM HEAT | [!] RISING",
			"symbol": &"[!]",
			"color": WATCH_COLOR,
		}
	return {
		"text": "ATM HEAT | [OK] NOMINAL",
		"symbol": &"[OK]",
		"color": NOMINAL_COLOR,
	}


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"snapshot": get_snapshot(),
		"presentation_only": true,
		"physics_authority": false,
		"movement_authority": false,
		"damage_authority": false,
		"landing_authority": false,
	}.duplicate(true)
