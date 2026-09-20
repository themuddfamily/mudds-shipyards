class_name EmberCalderaExpeditionInteractionBinding
extends Area3D

## The offer point for one authored Ember caldera errand, standing at the head
## of that errand's own route. It is the same generation-fenced, physical
## interaction pattern the authored sample rack and survey bunker already use:
## the Area supplies proximity discovery and a readable marker, and the press
## is forwarded verbatim to the caller's errand seam.
##
## It owns no errand, route, progress, reward, save or movement state. Every
## word it shows is derived from a fresh reading of the authoritative errand
## snapshot, and the only thing it can do with a press is ask the caller's sink
## to start or abandon the errand through the existing production seams.

const ExpeditionScript := preload(
	"res://scripts/activities/ember_caldera_expedition_activity.gd"
)

const INTERACTION_LAYER := 1 << 3
const WORLD_ID: StringName = &"ember_moon"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const SHAPE_RADIUS_M := 1.4
const MARKER_OFFSET_M := Vector3(0.0, 1.9, 0.0)
## Ochre matches the authored caldera route strip the trailhead sits on; teal
## matches the authored pad guides. Both readings also differ in wording and in
## bracket shape, so neither depends on colour being perceived.
const AVAILABLE_COLOR := Color(0.94, 0.70, 0.37, 1.0)
const ACTIVE_COLOR := Color(0.44, 0.85, 0.85, 1.0)
const COMPLETE_COLOR := Color(0.32, 0.86, 0.78, 1.0)
const BUSY_COLOR := Color(0.62, 0.62, 0.62, 1.0)

## Only these two readings can be pressed. Anything else keeps the point off
## the interaction layer so it cannot take a press it would have to refuse --
## on Ember the same button is the pilot's way back aboard.
const PRESSABLE_STATES: Array[StringName] = [&"available", &"active"]

var _host: Object
var _region_anchor: Node3D
var _region_anchor_instance_id := 0
var _activity_id: StringName = &""
var _display_name := ""
var _host_generation := -1
var _attachment_generation := -1
var _configured := false
var _attached := false
var _offer_state_source: Callable
var _intent_sink: Callable
var _last_receipt: Dictionary = {}
var _marker: Label3D


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 0
	set_meta("station_interactable", true)
	# GameFlow's Ember reboard gate yields its interaction press only to this
	# existing generic surface-interaction tag.
	set_meta("ember_surface_survey_interaction", true)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "ExpeditionTrailheadShape"
	var shape := SphereShape3D.new()
	shape.radius = SHAPE_RADIUS_M
	shape_node.shape = shape
	add_child(shape_node)
	_marker = Label3D.new()
	_marker.name = "ExpeditionTrailheadMarker"
	_marker.position = MARKER_OFFSET_M
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.font_size = 32
	_marker.outline_size = 8
	_marker.modulate = AVAILABLE_COLOR
	add_child(_marker)
	_apply_presentation()


## `region_anchor` is the live authored landing-region node. The trailhead is
## authored in that region's own frame, so the offer point is anchored to it
## rather than to this owner: a streamed world-origin rebase moves the caldera
## and the point that stands on it by the same translation, and the two can
## never drift apart.
func configure(
		host: Object, activity_id: StringName, region_anchor: Node3D,
		offer_state_source: Callable
	) -> Dictionary:
	if _configured or host == null or not is_instance_valid(host) \
			or not host.has_method(&"get_generation") \
			or not host.has_method(&"get_attachment_generation") \
			or region_anchor == null or not is_instance_valid(region_anchor) \
			or not region_anchor.is_inside_tree() \
			or not ExpeditionScript.is_expedition_activity(activity_id) \
			or not offer_state_source.is_valid():
		return _result(false, &"invalid_expedition_interaction_configuration")
	var trailhead := ExpeditionScript.get_trailhead_region_local(activity_id)
	if not trailhead.is_finite():
		return _result(false, &"invalid_expedition_interaction_configuration")
	_host = host
	_host_generation = int(host.call(&"get_generation"))
	_attachment_generation = int(host.call(&"get_attachment_generation"))
	if not _valid_generation(_host_generation) \
			or not _valid_generation(_attachment_generation):
		return _result(false, &"invalid_expedition_interaction_generation")
	_activity_id = activity_id
	_display_name = ExpeditionScript.get_display_name(activity_id)
	_offer_state_source = offer_state_source
	_region_anchor = region_anchor
	_region_anchor_instance_id = region_anchor.get_instance_id()
	# A rebase owner treats every `top_level` Node3D as one of its translation
	# roots, so standing outside this owner's transform keeps the point in the
	# caldera's frame without taking a transform authority of its own.
	top_level = true
	if not _anchor_to_region():
		return _result(false, &"invalid_expedition_interaction_anchor")
	set_meta("interaction_id", _interaction_id())
	_configured = true
	_attached = true
	_apply_presentation()
	return _result(true, &"expedition_interaction_configured")


## The press sink is installed by the caller that owns the production errand
## seams, after composition. Until it arrives the point reads as available but
## cannot be pressed, so no press is ever silently dropped.
func configure_intent_sink(sink: Callable) -> Dictionary:
	if not _configured or not sink.is_valid():
		return _result(false, &"invalid_expedition_intent_sink")
	_intent_sink = sink
	_apply_presentation()
	return _result(true, &"expedition_intent_sink_configured")


func get_activity_id() -> StringName:
	return _activity_id


func get_interaction_prompt() -> String:
	return _interaction_prompt(_offer_state())


func can_interact(actor: Node = null) -> bool:
	return _pressable(_offer_state()) and _actor_is_current(actor)


func interact(actor: Node = null) -> bool:
	return bool(submit_interaction(actor).get("accepted", false))


## Turns one press into one errand intent for the caller's production seam.
## The binding never decides the outcome: whatever the seam answers is what the
## marker then reads on its next fresh observation.
func submit_interaction(actor: Node = null) -> Dictionary:
	var offer_state := _offer_state()
	if not _current():
		return _result(false, &"expedition_interaction_unavailable")
	if not _pressable(offer_state):
		return _result(false, &"expedition_interaction_not_offered")
	if not _actor_is_current(actor):
		return _result(false, &"expedition_interaction_actor_mismatch")
	var intent := {
		"action": &"abandon" if offer_state == &"active" else &"begin",
		"activity_id": _activity_id,
		"world_id": WORLD_ID,
		"interaction_id": _interaction_id(),
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"activity_authority": false,
		"reward_authority": false,
		"movement_authority": false,
		"save_authority": false,
	}.duplicate(true)
	var answered: Variant = _intent_sink.call(intent.duplicate(true))
	var accepted := answered is Dictionary \
		and bool((answered as Dictionary).get("accepted", false))
	_last_receipt = {
		"intent": intent.duplicate(true),
		"accepted": accepted,
		"reason": (
			(answered as Dictionary).get("reason", &"expedition_intent_rejected")
			if answered is Dictionary else &"expedition_intent_rejected"
		),
	}.duplicate(true)
	_apply_presentation()
	if not accepted:
		return _result(
			false, StringName(_last_receipt.get("reason", &"expedition_intent_rejected"))
		)
	return _result(true, StringName("expedition_%s_submitted" % intent.action))


func detach() -> Dictionary:
	if not _configured or not _attached:
		return _result(false, &"expedition_interaction_not_attached")
	_attached = false
	_apply_presentation()
	return _result(true, &"expedition_interaction_detached")


func reenter(next_attachment_generation: int) -> Dictionary:
	if not _configured or _attached \
			or not _valid_generation(next_attachment_generation) \
			or next_attachment_generation <= _attachment_generation \
			or int(_host.call(&"get_attachment_generation")) != next_attachment_generation:
		return _result(false, &"stale_expedition_interaction_generation")
	_attachment_generation = next_attachment_generation
	_attached = true
	_anchor_to_region()
	_apply_presentation()
	return _result(true, &"expedition_interaction_reentered")


func _is_anchored() -> bool:
	return is_instance_valid(_region_anchor) \
		and _region_anchor.get_instance_id() == _region_anchor_instance_id \
		and _region_anchor.is_inside_tree()


## Re-reads the authored trailhead out of the live region frame. It only ever
## writes this node's own transform, and only from an authored constant.
func _anchor_to_region() -> bool:
	if not _is_anchored() or not is_inside_tree():
		return false
	global_transform = _region_anchor.global_transform * Transform3D(
		Basis.IDENTITY,
		ExpeditionScript.get_trailhead_region_local(_activity_id)
	)
	return true


func get_snapshot() -> Dictionary:
	# One fresh observation drives both the report and the physical marker, so
	# the words on the ground can never disagree with the words in the report.
	var offer_state := _offer_state()
	var active := _current()
	_apply_current_presentation(offer_state, active)
	return {
		"configured": _configured,
		"attached": _attached,
		"active": active,
		"activity_id": _activity_id,
		"interaction_id": _interaction_id(),
		"display_name": _display_name,
		"offer_state": offer_state,
		"pressable": _pressable(offer_state),
		"intent_sink_bound": _intent_sink.is_valid(),
		"position_body_local_m": ExpeditionScript.get_trailhead_body_local(
			_activity_id
		),
		"region_anchor_instance_id": _region_anchor_instance_id,
		"anchored": _is_anchored(),
		"prompt": _interaction_prompt(offer_state),
		"last_receipt": _last_receipt.duplicate(true),
		"physical": {
			"collision_layer": collision_layer,
			"shape": &"sphere",
			"radius_m": SHAPE_RADIUS_M,
			"marker_kind": &"label_3d",
			"marker_visible": _marker.visible if _marker != null else false,
			"marker_text": _marker.text if _marker != null else "",
			"solid_geometry_changed": false,
		},
		"accessibility": {
			# Nothing here moves, pulses or flashes in any setting, so the
			# reduced-motion and reduced-flash contracts are satisfied by
			# construction rather than by reading a setting.
			"animated": false,
			"reduced_motion_safe": true,
			"reduced_flash_safe": true,
			"color_independent": true,
			"text_independent": false,
		},
		"authority": {
			"movement": false, "activity": false, "route": false,
			"reward": false, "save": false, "history": false,
			"hud": false, "solid_geometry": false,
		},
	}.duplicate(true)


func _interaction_id() -> StringName:
	return StringName("%s_trailhead" % _activity_id) if _activity_id != &"" else &""


func _pressable(offer_state: StringName) -> bool:
	return _current() and _intent_sink.is_valid() \
		and offer_state in PRESSABLE_STATES


func _interaction_prompt(offer_state: StringName) -> String:
	if not _current():
		return ""
	var name_text := _display_name.to_upper()
	match offer_state:
		&"available":
			return "[ E ]  BEGIN %s" % name_text if _intent_sink.is_valid() else ""
		&"active":
			return "[ E ]  ABANDON %s" % name_text if _intent_sink.is_valid() else ""
		&"busy":
			# Deliberately short: `GameHUD.set_interaction` renders this in the
			# one shared bottom-centre prompt panel, whose authored width is
			# frozen against the longest prompt in the game.
			return "[ BUSY ]  FINISH THE ERRAND IN HAND FIRST"
		&"completed":
			return "[ COMPLETE ]  %s LOGGED" % name_text
	return ""


func _offer_state() -> StringName:
	if not _offer_state_source.is_valid() or _activity_id == &"":
		return &"unknown"
	return StringName(_offer_state_source.call(_activity_id))


func _current() -> bool:
	if not _configured or not _attached or _host == null \
			or not is_instance_valid(_host) or not _is_anchored():
		return false
	var host_snapshot := _host_snapshot()
	return int(_host.call(&"get_generation")) == _host_generation \
		and int(_host.call(&"get_attachment_generation")) == _attachment_generation \
		and bool(host_snapshot.get("attached", false)) \
		and StringName(host_snapshot.get("phase_id", &"")) == &"on_foot"


## The Host supplies fresh phase/attachment/actor evidence without unrelated
## diagnostics. Existing injected Hosts retain their original full-report seam.
func _host_snapshot() -> Dictionary:
	return _host.call(
		&"get_return_status_snapshot" if _host.has_method(&"get_return_status_snapshot")
		else &"get_snapshot"
	) as Dictionary


func _actor_is_current(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var identities := _host_snapshot().get("identities", {}) as Dictionary
	return actor.get_instance_id() == int(identities.get("player_instance_id", 0))


func _apply_presentation() -> void:
	_apply_current_presentation(_offer_state(), _current())


func _apply_current_presentation(offer_state: StringName, active: bool) -> void:
	collision_layer = INTERACTION_LAYER \
		if active and offer_state in PRESSABLE_STATES else 0
	if _marker == null:
		return
	_marker.visible = active
	var name_text := _display_name.to_upper()
	match offer_state:
		&"active":
			_marker.text = "%s\nERRAND IN HAND" % name_text
			_marker.modulate = ACTIVE_COLOR
		&"completed":
			_marker.text = "%s\nLOGGED" % name_text
			_marker.modulate = COMPLETE_COLOR
		&"busy":
			_marker.text = "%s\nFINISH CURRENT ERRAND" % name_text
			_marker.modulate = BUSY_COLOR
		_:
			_marker.text = "%s\nERRAND AVAILABLE" % name_text
			_marker.modulate = AVAILABLE_COLOR


func _valid_generation(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_GENERATION


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"interaction": get_snapshot(),
	}.duplicate(true)
