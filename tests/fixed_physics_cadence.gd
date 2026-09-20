extends RefCounted

## Pins the engine to one physics step per rendered frame, for suites whose
## assertions are stated in physics ticks.
##
## The race this exists for: `await physics_frame` followed by
## `await process_frame` advances exactly one physics tick on an idle machine,
## but on a loaded one the engine catches up by running several steps in the
## same rendered frame, so one awaited round can span up to
## `Engine.max_physics_steps_per_frame` ticks. Anything that counts awaited
## rounds as ticks - a per-tick sample series, a cadence, a per-round nudge of a
## flying hull, a send/poll pairing - then silently measures a different window
## than the one it says it measures.
##
## `Engine.max_physics_steps_per_frame = 1` removes the catch-up: every awaited
## round is one tick and one poll, whatever the machine is doing. The
## simulation then falls behind wall-clock under load instead, which is exactly
## the right trade for a suite that counts ticks - the shared bounded waits in
## the soak and cabin harnesses spend a tick budget *and* a wall-clock budget
## before giving up, so a slower-than-real-time simulation cannot time them out.
##
## Usage:
##
##     const Cadence := preload("res://tests/fixed_physics_cadence.gd")
##     var _cadence := Cadence.new()
##     ...
##     _cadence.pin()          # one tick per rendered frame from here
##     ...
##     _cadence.restore()      # back to the project's own setting
##
## `pin()` is re-entrant by depth, so a suite may pin for its whole run and a
## helper inside it may pin around one window without unpinning the caller.


var _depth := 0
var _saved_max_steps := 0
var _saved_ticks_per_second := 0
## Physics frames the engine actually ran while pinned, and awaited rounds the
## caller asked for, so a suite can prove the cadence held rather than assume it.
var _pinned_at_frame := 0


## Pins one physics step per rendered frame. `ticks_per_second` pins the tick
## rate too when it is positive; suites that size a budget from
## `Engine.physics_ticks_per_second` do not need it.
func pin(ticks_per_second: int = 0) -> void:
	_depth += 1
	if _depth > 1:
		return
	_saved_max_steps = Engine.max_physics_steps_per_frame
	_saved_ticks_per_second = Engine.physics_ticks_per_second
	_pinned_at_frame = int(Engine.get_physics_frames())
	Engine.max_physics_steps_per_frame = 1
	if ticks_per_second > 0:
		Engine.physics_ticks_per_second = ticks_per_second


## Restores whatever the project configured. Safe to call when not pinned.
func restore() -> void:
	if _depth <= 0:
		return
	_depth -= 1
	if _depth > 0:
		return
	Engine.max_physics_steps_per_frame = _saved_max_steps
	Engine.physics_ticks_per_second = _saved_ticks_per_second


func is_pinned() -> bool:
	return _depth > 0


## Physics ticks the engine has run since the outermost `pin()`.
func ticks_since_pin() -> int:
	return int(Engine.get_physics_frames()) - _pinned_at_frame


## Seconds of simulated time in `ticks` physics ticks, at the live tick rate.
static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) / maxf(1.0, float(Engine.physics_ticks_per_second))
