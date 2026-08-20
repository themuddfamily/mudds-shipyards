extends SceneTree

## Focused contract for accessibility alternatives around authored audio cues.
## This does not exercise the mixer, native output, or a full settings flow.

const Policy := preload("res://scripts/settings/audio_accessibility_policy.gd")
var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var policy = Policy.new()
	_check(policy.get_snapshot().mode == Policy.Mode.OFF, "policy starts disabled")
	_check(policy.configure(Policy.Mode.CAPTIONS).accepted, "caption mode is accepted")
	var caption := policy.resolve_cue(&"combat_alert", &"combat", false)
	_check(bool(caption.accepted), "valid muted combat cue is accepted")
	_check(bool(caption.show_caption) and not bool(caption.show_visual), "caption mode exposes text without forcing a visual flash")
	_check(not bool(caption.audible), "mixer observation is retained without being changed")
	_check(not bool(caption.gameplay_authority), "cue decision cannot grant gameplay authority")
	var generation := int(caption.generation)
	_check(policy.configure(Policy.Mode.CAPTIONS_AND_VISUAL).generation == generation + 1, "configuration advances exactly one generation")
	var visual := policy.resolve_cue(&"combat_alert", &"combat", true)
	_check(bool(visual.show_caption) and bool(visual.show_visual), "combined mode exposes caption and combat visual alternative")
	var ambient := policy.resolve_cue(&"machinery", &"world", true)
	_check(not bool(ambient.show_visual), "world ambience never becomes a flashing combat alternative")
	var off := policy.configure(Policy.Mode.OFF)
	_check(bool(off.accepted) and not bool(policy.resolve_cue(&"ui_confirm", &"ui").show_caption), "off mode disables caption alternatives")
	_check(not policy.configure(-1).accepted and not policy.configure(99).accepted, "unknown modes fail closed without changing policy")
	_check(not bool(policy.resolve_cue(&"Bad ID", &"ui").accepted), "uppercase and spaced cue IDs are rejected")
	_check(not bool(policy.resolve_cue(&"cue", &"unknown").accepted), "unknown cue categories are rejected")
	var snapshot := policy.get_snapshot()
	(snapshot.categories as Array).clear()
	_check(policy.get_snapshot().categories.size() == 5, "snapshots detach category inventory")
	var audit := policy.audit()
	_check(bool(audit.valid) and bool(audit.presentation_only), "audit is deterministic and presentation-only")
	_check(int(audit.cue_id_limits.maximum) == 64 and int(audit.category_count) == 5, "audit freezes bounded cue contract")
	_finish()


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: audio accessibility policy (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)
