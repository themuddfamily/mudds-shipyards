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

var _presenter := PresenterScript.new() as RefCounted
var _observation_count := 0
var _last_snapshot: Dictionary = {}


func _ready() -> void:
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
	clear(&"detached")


func present_source(source: Dictionary) -> Dictionary:
	var presentation := _presenter.call(&"present_snapshot", source) as Dictionary
	var state := StringName(presentation.get("state", &"support_required"))
	var advisory := StringName(presentation.get(
		"descent_advisory_id", &"safe_descent"
	))
	var reduced_flash := bool(presentation.get("reduced_flash", false))
	var reduced_motion := bool(presentation.get("reduced_motion", false))
	var rendered := _render_tokens(state, advisory, reduced_flash)
	text = str(rendered.text)
	modulate = rendered.color as Color
	visible = true
	_observation_count += 1
	_last_snapshot = {
		"state": state,
		"descent_advisory_id": advisory,
		"text": text,
		"symbol": rendered.symbol,
		"color": modulate,
		"reduced_flash": reduced_flash,
		"reduced_motion": reduced_motion,
		"steady": true,
		"color_independent": true,
	}.duplicate(true)
	return _result(true, &"cockpit_entry_presented")


func clear(reason: StringName = &"cleared") -> Dictionary:
	text = ""
	visible = false
	_last_snapshot = {
		"state": &"cleared",
		"text": "",
		"symbol": &"",
		"steady": true,
		"color_independent": true,
	}.duplicate(true)
	return _result(true, reason)


func get_snapshot() -> Dictionary:
	var snapshot := {
		"component_id": COMPONENT_ID,
		"visible": visible,
		"text": text,
		"observation_count": _observation_count,
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
