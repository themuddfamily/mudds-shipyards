class_name ComponentDegradationPresenter
extends RefCounted

## Read-only, nonvisual component health presentation. Repair authority remains
## with the caller; history is bounded to the published receipt data.

const MAX_HISTORY := 4
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


func detach() -> Dictionary:
	_snapshot = {}
	return {"attached": false, "presentation_only": true, "authority": false}
