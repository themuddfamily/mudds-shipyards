class_name HeavyBreachActivityPresenter
extends RefCounted

## Presentation-only mapping for the detached heavy-breach board snapshot.
## The board/director remain the authorities for admission, combat, objective,
## and reward; this presenter only turns their published receipt into text.

const TERMINAL_OUTCOMES: Array[StringName] = [
	&"cleared", &"escaped", &"withdrawn", &"aborted", &"expired",
]


func present(snapshot: Dictionary) -> Dictionary:
	var director := snapshot.get("director", {}) as Dictionary
	var reward := snapshot.get("reward_handoff", {}) as Dictionary
	var last_reward := reward.get("last_result", {}) as Dictionary
	var state := StringName(director.get("state", &"idle"))
	var scenario := StringName(director.get("scenario", &"heavy_breach"))
	var outcome := StringName(director.get("outcome", &"pending"))
	var generation := int(snapshot.get("generation", director.get("scenario_generation", 0)))
	var objective := str(director.get("protected_anchor", snapshot.get("protected_objective", ""))).strip_edges()
	var picket := str(director.get("breach_picket", "")).strip_edges()
	var launched := bool(director.get("launched", false))
	var elapsed := maxf(float(director.get("elapsed", 0.0)), 0.0)
	var state_text := str(state).replace("_", " ").to_upper()
	var outcome_text := str(outcome).replace("_", " ").to_upper()
	var phase_text := "PHASE %s / %s" % [state_text, str(scenario).replace("_", " ").to_upper()]
	var asset_text := "ASSETS  PROTECTED %s  PICKET %s" % [
		objective if not objective.is_empty() else "UNAVAILABLE",
		picket if not picket.is_empty() else "UNAVAILABLE",
	]
	var reward_text := "REWARD  HANDOFF READY" if bool(reward.get("configured", false)) else "REWARD  UNAVAILABLE"
	if not last_reward.is_empty():
		reward_text = "REWARD  %s%s" % [
		"ACCEPTED" if bool(last_reward.get("accepted", false)) else "NOT ACCEPTED",
		(" — " + str(last_reward.get("reason", &"unknown")).replace("_", " ").to_upper())
			if last_reward.has("reason") else "",
	]
	var failure_text := ""
	if TERMINAL_OUTCOMES.has(outcome):
		failure_text = "RESULT  %s" % outcome_text
	var lines := PackedStringArray([
		"[◆] HEAVY BREACH  %s" % ("LAUNCHED" if launched else "READY"),
		phase_text,
		asset_text,
		"ELAPSED  %.1fs  GENERATION  %d" % [elapsed, generation],
		reward_text,
	])
	if not failure_text.is_empty():
		lines.append(failure_text)
	return {
		"visible": true,
		"text": "\n".join(lines),
		"state_id": state,
		"phase_id": scenario,
		"outcome": outcome,
		"generation": generation,
		"protected_objective": objective,
		"breach_picket": picket,
		"reward": reward_text,
		"failure": failure_text,
		"icon": &"diamond_activity_board",
		"presentation_only": true,
	}.duplicate(true)
