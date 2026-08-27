class_name BoardingConfirmationHudComposition
extends RefCounted

## Presentation-only composition for reachable boarding reservation and
## transition snapshots.  GameFlow remains the owner of the snapshots and all
## boarding/seat authority.

const PresenterType := preload("res://scripts/ui/boarding_confirmation_hud_presenter.gd")
const AdapterType := preload("res://scripts/ui/boarding_confirmation_hud_adapter.gd")

var _presenter: RefCounted
var _adapter: RefCounted
var _generation := 0


func attach(hud: Object) -> Dictionary:
	detach()
	_presenter = PresenterType.new()
	_adapter = AdapterType.new()
	var attached: Dictionary = _adapter.attach(hud)
	if not bool(attached.get("accepted", false)):
		_presenter = null
		_adapter = null
		return attached
	_generation += 1
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	if _adapter != null:
		_adapter.detach()
	_presenter = null
	_adapter = null
	return {"accepted": true, "reason": &"detached", "generation": _generation, "presentation_only": true}


func apply_snapshot(snapshot: Dictionary) -> Dictionary:
	if _presenter == null or _adapter == null:
		return {"accepted": false, "reason": &"detached", "presentation_only": true}
	var presented: Dictionary = _presenter.present(snapshot)
	if not bool(presented.get("accepted", false)):
		return presented
	return _adapter.apply_view(presented)


func get_snapshot() -> Dictionary:
	return {"generation": _generation, "adapter": _adapter.get_snapshot() if _adapter != null else {}, "presentation_only": true}.duplicate(true)
