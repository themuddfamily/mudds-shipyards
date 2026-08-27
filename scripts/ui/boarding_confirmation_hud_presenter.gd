class_name BoardingConfirmationHudPresenter
extends RefCounted

## Maps only GameFlow's already-observed boarding transition facts to the
## existing retained status-card vocabulary.  It does not reserve a seat,
## advance a transition, or infer success from an animation.

const STATES := [&"approach", &"available", &"reserved", &"boarding", &"seated", &"disembarking", &"rejected"]


func present(snapshot: Dictionary) -> Dictionary:
	var state := StringName(snapshot.get("state", &""))
	if state not in STATES:
		return {"accepted": false, "reason": &"unknown_boarding_state", "presentation_only": true}
	if state == &"reserved" and not bool(snapshot.get("reservation_retained", false)):
		return {"accepted": false, "reason": &"reservation_not_retained", "presentation_only": true}
	if state == &"boarding" and (
		not bool(snapshot.get("reservation_retained", false))
		or not bool(snapshot.get("transition_busy", false))
	):
		return {"accepted": false, "reason": &"boarding_transition_not_observed", "presentation_only": true}
	if state == &"seated" and not bool(snapshot.get("player_seated", false)):
		return {"accepted": false, "reason": &"seat_not_observed", "presentation_only": true}
	if state == &"disembarking" and (
		not bool(snapshot.get("player_seated", false))
		or not bool(snapshot.get("transition_busy", false))
	):
		return {"accepted": false, "reason": &"disembark_transition_not_observed", "presentation_only": true}
	var craft := str(snapshot.get("craft_name", "CRAFT")).strip_edges().to_upper()
	if craft.is_empty():
		craft = "CRAFT"
	var reason := str(snapshot.get("reason", "")).strip_edges().replace("_", " ").to_upper()
	var reading := _reading_for(state, craft, reason)
	return {
		"accepted": true,
		"state": state,
		"title": reading.title,
		"message": reading.message,
		"shape": reading.shape,
		"generation": int(snapshot.get("generation", 0)),
		"presentation_only": true,
		"reservation_authority": false,
		"transition_authority": false,
	}.duplicate(true)


func _reading_for(state: StringName, craft: String, reason: String) -> Dictionary:
	match state:
		&"approach":
			return {"shape": "[>]", "title": "[>] BOARDING APPROACH", "message": "MOVE TO %s // LOOK FOR THE BOARDING PROMPT" % craft}
		&"available":
			return {"shape": "[+]", "title": "[+] BOARDING AVAILABLE", "message": "%s // PRESS INTERACT TO BOARD" % craft}
		&"reserved":
			return {"shape": "[=]", "title": "[=] BOARDING RESERVED", "message": "%s // ENTRY ROUTE RESERVED FOR YOU" % craft}
		&"boarding":
			return {"shape": "[>>]", "title": "[>>] BOARDING IN PROGRESS", "message": "%s // TRANSFERRING TO PILOT SEAT" % craft}
		&"seated":
			return {"shape": "[#]", "title": "[#] PILOT SEAT SECURED", "message": "%s // FLIGHT CONTROLS AVAILABLE" % craft}
		&"disembarking":
			return {"shape": "[<<]", "title": "[<<] DISEMBARKING", "message": "%s // RETURNING TO THE DECK" % craft}
		&"rejected":
			return {"shape": "[!]", "title": "[!] BOARDING UNAVAILABLE", "message": "%s%s" % [craft, " // " + reason if not reason.is_empty() else " // CHECK SEAT STATUS"]}
	return {"shape": "[?]", "title": "[?] BOARDING STATUS", "message": craft}
