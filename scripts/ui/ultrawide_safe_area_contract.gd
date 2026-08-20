class_name UltrawideSafeAreaContract
extends RefCounted

## Renderer-independent layout contract for settings and interaction prompts.
##
## The production HUD may choose its own controls, but any edge-anchored prompt
## can use this contract to keep text in the same readable band on 16:9, 16:10,
## 21:9 and 32:9 displays.  It owns no Control nodes or settings state.

const CONTRACT_SCHEMA_VERSION := 1
const MIN_UI_SCALE := 0.75
const MAX_UI_SCALE := 1.6
const BASE_SAFE_MARGIN_X := 32.0
const BASE_SAFE_MARGIN_TOP := 24.0
const BASE_SAFE_MARGIN_BOTTOM := 42.0
const READABLE_ASPECT := 16.0 / 9.0
const SUPPORTED_BUCKETS: Array[StringName] = [&"16:9", &"16:10", &"21:9", &"32:9"]
# Common 21:9 panels are marketed as 21:9 but ship at 2560x1080 or
# 3440x1440 (43:18), so the closed-world bucket allows that small production
# variance while still rejecting ordinary tablet/portrait ratios.
const ASPECT_TOLERANCE := 0.06


static func classify_viewport(viewport_size: Vector2) -> StringName:
	if not _valid_viewport(viewport_size):
		return &"unsupported"
	var ratio := viewport_size.x / viewport_size.y
	var candidates := {
		&"16:9": 16.0 / 9.0,
		&"16:10": 16.0 / 10.0,
		&"21:9": 21.0 / 9.0,
		&"32:9": 32.0 / 9.0,
	}
	var closest: StringName = &"unsupported"
	var distance := INF
	for bucket: StringName in SUPPORTED_BUCKETS:
		var candidate_distance := absf(ratio - float(candidates[bucket]))
		if candidate_distance < distance:
			distance = candidate_distance
			closest = bucket
	return closest if distance <= ASPECT_TOLERANCE else &"unsupported"


static func get_contract() -> Dictionary:
	return {
		"schema_version": CONTRACT_SCHEMA_VERSION,
		"supported_aspect_buckets": SUPPORTED_BUCKETS.duplicate(),
		"aspect_tolerance": ASPECT_TOLERANCE,
		"readable_aspect": READABLE_ASPECT,
		"base_safe_margin_x": BASE_SAFE_MARGIN_X,
		"base_safe_margin_top": BASE_SAFE_MARGIN_TOP,
		"base_safe_margin_bottom": BASE_SAFE_MARGIN_BOTTOM,
		"ui_scale_range": Vector2(MIN_UI_SCALE, MAX_UI_SCALE),
		"policy": &"centered_16_9_readable_band_with_scaled_edge_margins",
		"prompt_clipping_policy": &"fit_inside_safe_rect",
	}.duplicate(true)


static func safe_rect(viewport_size: Vector2, ui_scale := 1.0) -> Rect2:
	if not _valid_viewport(viewport_size) or not is_finite(ui_scale):
		return Rect2()
	var scale := clampf(ui_scale, MIN_UI_SCALE, MAX_UI_SCALE)
	var target_band_width := viewport_size.y * READABLE_ASPECT
	var horizontal_margin := maxf(
		BASE_SAFE_MARGIN_X * scale,
		(viewport_size.x - target_band_width) * 0.5 + BASE_SAFE_MARGIN_X * scale
	)
	var top := BASE_SAFE_MARGIN_TOP * scale
	var bottom := BASE_SAFE_MARGIN_BOTTOM * scale
	return Rect2(
		horizontal_margin,
		top,
		maxf(1.0, viewport_size.x - horizontal_margin * 2.0),
		maxf(1.0, viewport_size.y - top - bottom)
	)


## Fits a desired prompt rectangle into the safe rect. The returned dictionary
## is detached and explicitly reports clipping so callers cannot silently place
## an oversized prompt at an ultrawide edge.
static func fit_prompt(viewport_size: Vector2, desired_size: Vector2, anchor := &"bottom_center", ui_scale := 1.0) -> Dictionary:
	var safe := safe_rect(viewport_size, ui_scale)
	var valid := _valid_viewport(viewport_size) and desired_size.x > 0.0 and desired_size.y > 0.0
	if not valid or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return {"valid": false, "clipped": true, "rect": Rect2(), "safe_rect": safe, "aspect_bucket": classify_viewport(viewport_size)}
	var clipped := desired_size.x > safe.size.x or desired_size.y > safe.size.y
	var size := Vector2(minf(desired_size.x, safe.size.x), minf(desired_size.y, safe.size.y))
	var position := _anchored_position(safe, size, anchor)
	var rect := Rect2(position, size)
	return {
		"valid": not clipped,
		"clipped": clipped,
		"rect": rect,
		"safe_rect": safe,
		"aspect_bucket": classify_viewport(viewport_size),
		"anchor": anchor,
	}


static func _anchored_position(safe: Rect2, size: Vector2, anchor: StringName) -> Vector2:
	match anchor:
		&"top_left":
			return safe.position
		&"top_right":
			return Vector2(safe.end.x - size.x, safe.position.y)
		&"bottom_left":
			return Vector2(safe.position.x, safe.end.y - size.y)
		&"bottom_right":
			return safe.end - size
		&"center":
			return safe.position + (safe.size - size) * 0.5
		_: # bottom-center is the default prompt placement.
			return Vector2(safe.position.x + (safe.size.x - size.x) * 0.5, safe.end.y - size.y)


static func _valid_viewport(size: Vector2) -> bool:
	return is_finite(size.x) and is_finite(size.y) and size.x > 1.0 and size.y > 1.0
