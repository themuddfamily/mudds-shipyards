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
	# Detached rated definition facts help choose a craft before boarding. They
	# never describe this instance's current velocity, damage or seat authority.
	if state in [&"approach", &"available"]:
		var raw_facts: Variant = snapshot.get("definition_facts", {})
		var facts: Dictionary = raw_facts if raw_facts is Dictionary else {}
		var raw_role: Variant = facts.get("role", "")
		var role := str(raw_role).strip_edges().to_upper() if raw_role is String or raw_role is StringName else ""
		var speed := _positive_number(facts.get("maximum_speed"))
		var hull := _positive_number(facts.get("maximum_hull"))
		if not role.is_empty() and is_finite(speed) and speed > 0.0 \
				and is_finite(hull) and hull > 0.0:
			# The facts line already carries the exact role. Compact repeated class
			# wording while retaining candidate and reconstruction qualifiers.
			var choice_name := craft
			if "-CLASS " in craft:
				choice_name = craft.get_slice("-CLASS ", 0)
				if craft.ends_with(" CANDIDATE"):
					choice_name += " CANDIDATE"
				if " — " in craft:
					choice_name += " // " + craft.get_slice(" — ", 1).replace("-OBSERVED", "")
			reading = _reading_for(state, choice_name, reason)
			var tradeoff := _choice_reading(facts, role, speed, hull)
			var rated_facts := "%s | %.0f M/S BASE | MAX HULL %.0f" % [role, speed, hull]
			if not tradeoff.is_empty():
				# Distribute the complete instruction across the existing heading
				# and body. Only validated Cinder choices use an inline state.
				reading.title = "[>] MOVE TO %s" % choice_name if state == &"approach" else "[+] %s" % choice_name
				var instruction := "LOOK FOR THE BOARDING PROMPT" if state == &"approach" else "PRESS INTERACT TO BOARD"
				reading.message = "%s\n%s\n%s" % [tradeoff, rated_facts, instruction]
				if role == "CARGO HAULER":
					reading.hauler_choice_ship_id = &"cinder_cargo_hauler"
				elif role == "LONG-RANGE BOMBER":
					reading.bomber_choice_ship_id = &"cinder_long_range_bomber"
				else:
					reading.light_choice_ship_id = &"cinder_light_interceptor"
			else:
				reading.message += "\n" + rated_facts
	var view := {
		"accepted": true,
		"state": state,
		"title": reading.title,
		"message": reading.message,
		"shape": reading.shape,
		"generation": int(snapshot.get("generation", 0)),
		"presentation_only": true,
		"reservation_authority": false,
		"transition_authority": false,
	}
	if reading.has("light_choice_ship_id"):
		view.light_choice_ship_id = reading.light_choice_ship_id
	if reading.has("bomber_choice_ship_id"):
		view.bomber_choice_ship_id = reading.bomber_choice_ship_id
	if reading.has("hauler_choice_ship_id"):
		view.hauler_choice_ship_id = reading.hauler_choice_ship_id
	return view.duplicate(true)


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


func _positive_number(value: Variant) -> float:
	if not (value is float or value is int):
		return 0.0
	var number := float(value)
	return number if is_finite(number) and number > 0.0 else 0.0


func _choice_reading(facts: Dictionary, role: String, speed: float, hull: float) -> String:
	var choice: Variant = facts.get("role_choice")
	if choice is Dictionary and role == "CARGO HAULER":
		return _hauler_choice_reading(choice, speed, hull)
	if choice is Dictionary and role == "LONG-RANGE BOMBER":
		return _bomber_choice_reading(choice, speed, hull)
	if not choice is Dictionary or role != "LIGHT INTERCEPTOR":
		return ""
	if choice.get("ship_id") != &"cinder_light_interceptor" \
			or choice.get("role_id") != &"cinder_light_interceptor":
		return ""
	var axes: Variant = choice.get("source_axes")
	if not axes is Dictionary or axes.get("advantage") != &"maximum_speed" \
			or axes.get("weakness") != &"passive_drag":
		return ""
	if not is_equal_approx(_positive_number(choice.get("maximum_speed")), speed) \
			or _positive_number(choice.get("passive_drag")) <= 0.0:
		return ""
	var advantage: Variant = choice.get("advantage")
	var weakness: Variant = choice.get("weakness")
	for text: Variant in [advantage, weakness]:
		if not text is String or text.strip_edges().is_empty() \
				or text.length() > 48 or "\n" in text or "\r" in text:
			return ""
	return "%s // %s" % [advantage, weakness]


func _bomber_choice_reading(choice: Dictionary, speed: float, hull: float) -> String:
	for identity: String in ["ship_id", "role_id"]:
		var value: Variant = choice.get(identity)
		if not (value is String or value is StringName):
			return ""
		if str(value) != "cinder_long_range_bomber":
			return ""
	var axes: Variant = choice.get("source_axes")
	if not axes is Dictionary:
		return ""
	var expected_axes := {"advantage": [&"maximum_hull", &"brake_acceleration"], "weakness": [&"yaw_speed_degrees", &"roll_speed_degrees", &"weapon_cooldown"]}
	if axes.size() != expected_axes.size():
		return ""
	for side: String in expected_axes:
		var values: Variant = axes.get(side)
		if not values is Array:
			return ""
		if values.size() != expected_axes[side].size():
			return ""
		for index in values.size():
			var value: Variant = values[index]
			if not (value is String or value is StringName):
				return ""
			if str(value) != str(expected_axes[side][index]):
				return ""
	var advantage: Variant = choice.get("advantage")
	var weakness: Variant = choice.get("weakness")
	if not advantage is String or not weakness is String:
		return ""
	if advantage != "TOUGH HULL & BRAKES" or weakness != "SLOW TURN / FIRE":
		return ""
	var expected := {"maximum_speed": 72.0, "maximum_hull": 240.0, "brake_acceleration": 28.0, "yaw_speed_degrees": 28.0, "roll_speed_degrees": 34.0, "weapon_cooldown": 0.85}
	for axis: String in expected:
		if not is_equal_approx(_positive_number(choice.get(axis)), expected[axis]):
			return ""
	if not is_equal_approx(speed, _positive_number(choice.get("maximum_speed"))) or not is_equal_approx(hull, _positive_number(choice.get("maximum_hull"))):
		return ""
	return "TOUGH HULL & BRAKES // SLOW TURN / FIRE"


func _hauler_choice_reading(choice: Dictionary, speed: float, hull: float) -> String:
	for identity: String in ["ship_id", "role_id"]:
		var value: Variant = choice.get(identity)
		if not (value is String or value is StringName):
			return ""
		if str(value) != "cinder_cargo_hauler":
			return ""
	var axes: Variant = choice.get("source_axes")
	if not axes is Dictionary:
		return ""
	var expected_axes := {"advantage": [&"maximum_hull", &"passive_drag"], "weakness": [&"maximum_speed", &"thrust_acceleration"]}
	if axes.size() != expected_axes.size():
		return ""
	for side: String in expected_axes:
		var values: Variant = axes.get(side)
		if not values is Array:
			return ""
		if values.size() != expected_axes[side].size():
			return ""
		for index in values.size():
			var value: Variant = values[index]
			if not (value is String or value is StringName):
				return ""
			if str(value) != str(expected_axes[side][index]):
				return ""
	var advantage: Variant = choice.get("advantage")
	var weakness: Variant = choice.get("weakness")
	if not advantage is String or not weakness is String:
		return ""
	if advantage != "HULL & LOW DRAG" or weakness != "SLOW SPEED / THRUST":
		return ""
	var expected := {"maximum_speed": 64.0, "maximum_hull": 220.0, "thrust_acceleration": 14.0, "passive_drag": 1.5}
	for axis: String in expected:
		if not is_equal_approx(_positive_number(choice.get(axis)), expected[axis]):
			return ""
	if not is_equal_approx(speed, _positive_number(choice.get("maximum_speed"))) or not is_equal_approx(hull, _positive_number(choice.get("maximum_hull"))):
		return ""
	return "HULL & LOW DRAG // SLOW SPEED / THRUST"
