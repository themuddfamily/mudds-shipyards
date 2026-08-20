extends SceneTree

const Contract := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var contract := Contract.get_contract()
	_check(int(contract.schema_version) == 1, "safe-area contract schema is versioned")
	_check(
		contract.supported_aspect_buckets == [&"16:9", &"16:10", &"21:9", &"32:9"]
		and is_equal_approx(float(contract.readable_aspect), 16.0 / 9.0),
		"contract freezes all supported aspect buckets and readable band"
	)
	var cases := {
		&"16:9": Vector2(1920, 1080),
		&"16:10": Vector2(1920, 1200),
		&"21:9": Vector2(3440, 1440),
		&"32:9": Vector2(5120, 1440),
	}
	for bucket: StringName in cases:
		var viewport: Vector2 = cases[bucket]
		_check(Contract.classify_viewport(viewport) == bucket, "%s aspect bucket is classified" % bucket)
		var safe := Contract.safe_rect(viewport, 1.0)
		_check(safe.position.x >= 32.0 and safe.position.y >= 24.0, "%s keeps top and side margins" % bucket)
		_check(safe.end.x <= viewport.x and safe.end.y <= viewport.y - 42.0, "%s safe rect stays inside viewport" % bucket)
		for anchor: StringName in [&"top_left", &"top_right", &"bottom_left", &"bottom_right", &"bottom_center"]:
			var fitted := Contract.fit_prompt(viewport, Vector2(520, 88), anchor, 1.0)
			var rect: Rect2 = fitted.rect
			_check(bool(fitted.valid) and not bool(fitted.clipped) and safe.encloses(rect), "%s %s prompt remains unclipped" % [bucket, anchor])
	var scaled := Contract.safe_rect(Vector2(5120, 1440), 1.6)
	_check(scaled.position.x >= 51.2 and scaled.position.y >= 38.4, "maximum UI scale expands safe margins")
	_check(Contract.classify_viewport(Vector2(1600, 900)) == &"16:9", "common 16:9 resolution remains accepted")
	_check(Contract.classify_viewport(Vector2(1600, 1000)) == &"16:10", "common 16:10 resolution remains accepted")
	_check(Contract.classify_viewport(Vector2(1000, 700)) == &"unsupported", "ambiguous aspect rejects closed-world classification")
	var oversized := Contract.fit_prompt(Vector2(1920, 1080), Vector2(5000, 88), &"bottom_center", 1.0)
	_check(not bool(oversized.valid) and bool(oversized.clipped), "oversized prompt fails closed instead of claiming safe placement")
	_check(not Contract.fit_prompt(Vector2.ZERO, Vector2(100, 40)).valid, "invalid viewport rejects prompt layout")
	if _failures.is_empty():
		print("ULTRAWIDE_SAFE_AREA_CONTRACT_TEST_PASS: %d assertions" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
