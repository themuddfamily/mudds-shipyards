extends SceneTree

## Focused provenance gate for the non-metric floor-plan research manifest.
##
## This is deliberately narrower than a topology or geometry test.  It proves
## that each deferred floor-plan variant points at claims actually registered
## by its cited source, and that the cited source has an observation anchor.
## It never upgrades a variant, derives adjacency, or treats implementation as
## historical evidence.

const VARIANTS_PATH := "res://docs/research/station_floor_plan_variants.json"
const LEDGER_PATH := "res://docs/research/source_ledger.json"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var variants := _load_json(VARIANTS_PATH)
	var ledger := _load_json(LEDGER_PATH)
	_test_identity_and_policy(variants)
	_test_claim_links(variants, ledger)
	_finish()


func _test_identity_and_policy(document: Dictionary) -> void:
	_check(
		int(document.get("schema_version", 0)) == 1
		and str(document.get("document_id", "")) == "keth_station_floor_plan_variants",
		"floor-plan manifest retains its stable schema identity"
	)
	var policy := document.get("policy", {}) as Dictionary
	var requirements := policy.get("canonical_variant_requires", []) as Array
	_check(
		_string_set_matches(
			["adjacency_resolved", "scale_resolved", "version_conflicts_resolved"],
			requirements
		),
		"canonical promotion still requires adjacency, scale, and version resolution"
	)
	_check(
		policy.get("current_canonical_variant", "sentinel") == null
		and str(policy.get("historical_authentication", "")) == "none",
		"manifest has no canonical or historically authenticated floor plan"
	)


func _test_claim_links(document: Dictionary, ledger: Dictionary) -> void:
	var sources := ledger.get("sources", []) as Array
	var source_map := {}
	for source_variant in sources:
		var source := source_variant as Dictionary
		source_map[str(source.get("id", ""))] = source

	var variants := document.get("variants", []) as Array
	_check(not variants.is_empty(), "floor-plan manifest contains bounded source variants")
	var seen_ids: Array[String] = []
	for variant_variant in variants:
		var variant := variant_variant as Dictionary
		var variant_id := str(variant.get("variant_id", ""))
		seen_ids.append(variant_id)
		_check(not variant_id.is_empty(), "every floor-plan variant has a stable ID")
		_check(str(variant.get("disposition", "")) == "deferred", "%s remains deferred" % variant_id)
		var source_ids := variant.get("source_ids", []) as Array
		var claim_ids := variant.get("claim_ids", []) as Array
		_check(not source_ids.is_empty() and not claim_ids.is_empty(), "%s declares sources and claims" % variant_id)
		var all_claims_registered := true
		var all_sources_anchored := true
		for source_id_variant in source_ids:
			var source_id := str(source_id_variant)
			var source: Dictionary = source_map.get(source_id, {})
			_check(not source.is_empty(), "%s cites registered source %s" % [variant_id, source_id])
			all_sources_anchored = all_sources_anchored and not (source.get("anchors", []) as Array).is_empty()
			for claim_id_variant in claim_ids:
				var claim_id := str(claim_id_variant)
				all_claims_registered = all_claims_registered and (source.get("claims_supported", []) as Array).has(claim_id)
		_check(all_sources_anchored, "%s cites source material with at least one registered anchor" % variant_id)
		_check(all_claims_registered, "%s claim IDs resolve in every cited source" % variant_id)
		var resolved := variant.get("resolved", {}) as Dictionary
		_check(
			not bool(resolved.get("adjacency", true))
			and not bool(resolved.get("scale", true)),
			"%s does not claim resolved adjacency or scale" % variant_id
		)
	_check(seen_ids.size() == _unique_strings(seen_ids).size(), "floor-plan variant IDs are unique")


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "JSON resource opens: %s" % path)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary, "JSON resource parses as object: %s" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _string_set_matches(expected: Array, actual: Array) -> bool:
	var left: Array[String] = []
	var right: Array[String] = []
	for value in expected:
		left.append(str(value))
	for value in actual:
		right.append(str(value))
	left.sort()
	right.sort()
	return left == right


func _unique_strings(values: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: " + label)


func _finish() -> void:
	if _failures.is_empty():
		print("RESEARCH_FLOOR_PLAN_LEDGER_LINK_TEST_OK assertions=%d" % _assertions)
	else:
		push_error("RESEARCH_FLOOR_PLAN_LEDGER_LINK_TEST_FAILED assertions=%d failures=%d" % [_assertions, _failures.size()])
	quit(1 if not _failures.is_empty() else 0)
