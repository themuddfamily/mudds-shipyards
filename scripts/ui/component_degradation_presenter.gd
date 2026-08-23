class_name ComponentDegradationPresenter
extends RefCounted

## Read-only, nonvisual component health presentation. Repair authority remains
## with the caller; history is bounded to the published receipt data.

const MAX_HISTORY := 4
const CRITICAL_INTEGRITY_THRESHOLD := 0.40
const COMPONENT_NAMES := {
	&"forward_hull": "FORWARD HULL",
	&"port_wing": "PORT WING",
	&"starboard_wing": "STARBOARD WING",
	&"core_systems": "CORE SYSTEMS",
	&"engine_bay": "ENGINE BAY",
}
var _snapshot: Dictionary = {}


func present_snapshot(snapshot: Dictionary) -> Dictionary:
	_snapshot = snapshot.duplicate(true)
	var engine := _metric(snapshot, "engine_power", "ENGINE")
	var weapon := _metric(snapshot, "weapon_power", "WEAPON")
	var targeting := _metric(snapshot, "targeting_power", "SENSOR TARGETING")
	var affected := str(snapshot.get("affected_component", snapshot.get("component", "NONE"))).strip_edges().to_upper()
	var history: Array = snapshot.get("repair_history", []) as Array
	var receipts: Array[String] = []
	for item in history:
		if receipts.size() >= MAX_HISTORY:
			break
		var text := str(item).strip_edges()
		if not text.is_empty():
			receipts.append(text.to_upper())
	var message := "ENGINE MOBILITY // %s\nWEAPON FIRE // %s\nSENSOR TARGETING // %s\nAFFECTED // %s" % [engine.text, weapon.text, targeting.text, affected]
	if not receipts.is_empty():
		message += "\nREPAIR HISTORY // " + " | ".join(receipts)
	return {
		"schema_version": 1,
		"title": "COMPONENT STATUS",
		"message": message,
		"engine": engine,
		"weapon": weapon,
		"targeting": targeting,
		"affected_component": affected,
		"repair_history": receipts,
		"actions": [{"id": &"component_review", "label": "COMPONENT REVIEW  //  READ ONLY", "focusable": true}],
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func _metric(snapshot: Dictionary, key: StringName, label: String) -> Dictionary:
	var percentage := clampi(roundi(float(snapshot.get(key, 1.0)) * 100.0), 0, 100)
	var state := "NOMINAL" if percentage >= 80 else ("IMPAIRED" if percentage > 0 else "DISABLED")
	return {"label": label, "percentage": percentage, "state": state, "text": "%s %03d%% // %s" % [state, percentage, label]}


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


## Compact retained-flight rendering of the authoritative Hero component report.
## “Critical” is a presentation-only sub-band inside the report's impaired
## integrity range; no stage, health, damage, or repair state is written back.
func present_hero_report(report: Dictionary) -> Dictionary:
	var worst: Dictionary = {}
	for raw_component in report.get("components", []) as Array:
		if not raw_component is Dictionary:
			continue
		var component := raw_component as Dictionary
		var integrity := clampf(float(component.get("integrity", 0.0)), 0.0, 1.0)
		if worst.is_empty() or integrity < float(worst.get("integrity", 2.0)):
			worst = component
	if not bool(report.get("configured", false)) or worst.is_empty():
		_snapshot = {"visible": false, "presentation_only": true, "authority": false}
		return _snapshot.duplicate(true)
	var component_id := StringName(worst.get("id", &"unknown"))
	var integrity := clampf(float(worst.get("integrity", 0.0)), 0.0, 1.0)
	var authoritative_stage := StringName(worst.get("state_id", &"failed"))
	var wording := &"nominal"
	if authoritative_stage == &"failed":
		wording = &"failed"
	elif integrity <= CRITICAL_INTEGRITY_THRESHOLD:
		wording = &"critical"
	elif authoritative_stage == &"impaired":
		wording = &"degraded"
	var component_name := str(COMPONENT_NAMES.get(component_id, String(component_id))).to_upper()
	var percentage := clampi(roundi(integrity * 100.0), 0, 100)
	_snapshot = {
		"visible": true,
		"text": "COMPONENT  //  %s  %03d%%  //  %s" % [
			component_name,
			percentage,
			String(wording).to_upper(),
		],
		"component_id": component_id,
		"component_name": component_name,
		"integrity": integrity,
		"percentage": percentage,
		"authoritative_stage": authoritative_stage,
		"wording": wording,
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_snapshot = {}
	return {"attached": false, "presentation_only": true, "authority": false}
