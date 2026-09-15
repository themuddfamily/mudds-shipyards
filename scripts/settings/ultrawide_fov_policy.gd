class_name UltrawideFovPolicy
extends RefCounted

## The project's ultrawide field-of-view policy, in one side-effect-free place.
##
## WHY THIS EXISTS. Both hero rigs and the on-foot rig are `Camera3D`s on
## [constant Camera3D.KEEP_HEIGHT]: the authored `camera_fov` setting is the
## *vertical* angle and the horizontal angle widens with the display. Since the
## display stretch policy stopped pillarboxing real displays
## (`StartupLoader.stretch_aspect_for_display`), that widening actually reaches
## the player: at the authored 72 degree default the horizontal angle is
## 104.5 degrees at 16:9, 120.1 degrees at 21:9 and 137.7 degrees at 32:9.
## `tools/camera_intrusion_audit.gd` reports near-plane intrusions at 32:9 that
## do not exist at 16:9, because the widened near-plane corners reach into
## cockpit and hull plating that the 16:9 corners clear.
##
## THE POLICY. Hor+ up to 21:9, then a soft cap:
##
##   * at or below [constant REFERENCE_ASPECT] (21:9, the widest panel the
##     roadmap names as "normal") the authored vertical FOV is used *exactly*.
##     16:9 and 21:9 are bit-identical to the uncapped behaviour, so the
##     overwhelming majority of displays see no change at all;
##   * above it, the vertical FOV is reduced just enough that the horizontal
##     angle stays at the ceiling the same authored vertical FOV reaches at
##     21:9 -- 120.1 degrees at the 72 degree default, the "120 degree ceiling".
##
## The ceiling is expressed relative to the authored angle rather than as a flat
## 120 degrees so the "Camera field of view" slider keeps doing something on a
## 32:9 panel. A flat ceiling would collapse every slider position to the same
## vertical angle there and silently disable a shipping setting.
##
## OPT-OUT. The policy is a player setting, `limit_ultrawide_fov`, default ON.
## With it off, [method effective_vertical_fov] is the identity function and the
## rigs behave exactly as they did before this policy existed.
##
## Documented in `docs/ULTRAWIDE_FIELD_OF_VIEW_POLICY.md`.

## Widest aspect that keeps the authored vertical FOV untouched: 3440 x 1440,
## the 21:9 panel `tests/ultrawide_layout_test.gd` measures.
const REFERENCE_ASPECT := 3440.0 / 1440.0

## Aspect used when a viewport cannot be measured (detached rigs, zero-sized
## viewports during a resize). 16:9 never triggers the cap, so an unmeasurable
## viewport can never narrow a player's view.
const FALLBACK_ASPECT := 16.0 / 9.0

## Authored default of the `limit_ultrawide_fov` setting. The policy owns this so
## the rigs and `RuntimeSettings` cannot drift apart on what "unset" means.
const DEFAULT_LIMIT_ULTRAWIDE_FOV := true

## Authored default of the `camera_fov` setting. Only used to report the nominal
## ceiling; the live ceiling always follows the player's own authored angle.
const NOMINAL_VERTICAL_FOV := 72.0


## Horizontal angle a `KEEP_HEIGHT` camera with this vertical angle covers at
## this aspect ratio, in degrees.
static func horizontal_fov_degrees(vertical_fov_degrees: float, aspect: float) -> float:
	return rad_to_deg(
		2.0 * atan(tan(deg_to_rad(vertical_fov_degrees) * 0.5) * aspect)
	)


## Vertical angle a `KEEP_HEIGHT` camera needs at this aspect ratio to cover
## exactly this horizontal angle, in degrees.
static func vertical_fov_degrees(horizontal_fov_degrees_value: float, aspect: float) -> float:
	if aspect <= 0.0 or not is_finite(aspect):
		return horizontal_fov_degrees_value
	return rad_to_deg(
		2.0 * atan(tan(deg_to_rad(horizontal_fov_degrees_value) * 0.5) / aspect)
	)


## The horizontal ceiling this authored vertical angle is held to above 21:9.
## 120.10 degrees at the 72 degree default -- the "120 degree ceiling".
static func horizontal_fov_ceiling_degrees(authored_vertical_fov_degrees: float) -> float:
	return horizontal_fov_degrees(authored_vertical_fov_degrees, REFERENCE_ASPECT)


## Aspect ratio of a live viewport, or [constant FALLBACK_ASPECT] when it cannot
## be measured. The *visible rect* is the authority, not the OS window: the
## content-scale policy is what decides whether a 32:9 window renders a 32:9
## image or a pillarboxed 16:9 one.
static func viewport_aspect(viewport: Viewport) -> float:
	if viewport == null:
		return FALLBACK_ASPECT
	var size := viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return FALLBACK_ASPECT
	var aspect := size.x / size.y
	return aspect if is_finite(aspect) and aspect > 0.0 else FALLBACK_ASPECT


## Whether this aspect ratio is wide enough for the cap to do anything at all.
static func limits_aspect(aspect: float) -> bool:
	return is_finite(aspect) and aspect > REFERENCE_ASPECT


## The vertical FOV a rig should actually run at. Returns `authored` unchanged
## whenever the cap is off or the display is 21:9 or narrower, so equality at
## those aspects is exact rather than approximate.
static func effective_vertical_fov(
		authored_vertical_fov_degrees: float, aspect: float, limit_enabled: bool
	) -> float:
	if not limit_enabled or not limits_aspect(aspect):
		return authored_vertical_fov_degrees
	return rad_to_deg(2.0 * atan(
		tan(deg_to_rad(authored_vertical_fov_degrees) * 0.5)
		* REFERENCE_ASPECT / aspect
	))


## Convenience seam for a rig that already holds a live viewport.
static func effective_vertical_fov_for_viewport(
		authored_vertical_fov_degrees: float, viewport: Viewport, limit_enabled: bool
	) -> float:
	return effective_vertical_fov(
		authored_vertical_fov_degrees, viewport_aspect(viewport), limit_enabled
	)


## Detached descriptor for documentation, tests and audit reports.
static func describe(authored_vertical_fov_degrees: float, aspect: float, limit_enabled: bool) -> Dictionary:
	var effective := effective_vertical_fov(
		authored_vertical_fov_degrees, aspect, limit_enabled
	)
	return {
		"authored_vertical_fov": authored_vertical_fov_degrees,
		"aspect": aspect,
		"limit_enabled": limit_enabled,
		"limited": limit_enabled and limits_aspect(aspect),
		"vertical_fov": effective,
		"horizontal_fov": horizontal_fov_degrees(effective, aspect),
		"horizontal_fov_ceiling": horizontal_fov_ceiling_degrees(
			authored_vertical_fov_degrees
		),
	}
