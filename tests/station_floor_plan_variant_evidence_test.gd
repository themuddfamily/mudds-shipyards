extends SceneTree

## Focused gate for ROADMAP Phase 1's floor-plan-variant boundary.
##
## This is an eligibility audit, not a geometry test. A variant may become a
## canonical floor-plan candidate only when source views resolve adjacency,
## scale, and version conflicts together. Current source scopes are recorded
## for future evidence work, but none is allowed to silently become canonical.

const VARIANTS_PATH := "res://docs/research/station_floor_plan_variants.json"
const LEDGER_PATH := "res://docs/research/source_ledger.json"
const TOPOLOGY_PATH := "res://docs/research/STATION_TOPOLOGY.md"
const ROADMAP_PATH := "res://ROADMAP.md"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var variants := _load_json(VARIANTS_PATH)
	var ledger := _load_json(LEDGER_PATH)
	var topology := FileAccess.get_file_as_string(TOPOLOGY_PATH)
	var roadmap := FileAccess.get_file_as_string(ROADMAP_PATH)
	_test_document_identity(variants)
	_test_policy_boundary(variants, topology, roadmap)
	_test_variant_rows(variants, ledger)
	_finish()


func _test_document_identity(document: Dictionary) -> void:
	_check(
		int(document.get("schema_version", 0)) == 1
		and str(document.get("document_id", "")) == "keth_station_floor_plan_variants",
		"floor-plan variant catalog exposes its stable schema identity"
	)
	var variants := document.get("variants", []) as Array
	_check(variants.size() == 3, "catalog records the three currently bounded source scopes")


func _test_policy_boundary(document: Dictionary, topology: String, roadmap: String) -> void:
	var policy := document.get("policy", {}) as Dictionary
	var requirements := policy.get("canonical_variant_requires", []) as Array
	_check(
		_string_set_matches(
			["adjacency_resolved", "scale_resolved", "version_conflicts_resolved"],
			requirements
		),
		"canonical eligibility requires adjacency, scale, and version-conflict resolution"
	)
	_check(
		policy.get("current_canonical_variant", "sentinel") == null
		and str(policy.get("historical_authentication", "")) == "none",
		"catalog keeps the current canonical variant empty and historical authentication absent"
	)
	_check(
		roadmap.contains("Extend the non-metric confidence-graded topology")
		and roadmap.contains("only where new source views resolve adjacency, scale, and version conflicts")
		and topology.contains("Further station expansion still requires new")
		and topology.contains("equally explicit modern/deferred boundaries."),
		"roadmap and topology retain the evidence boundary for future floor-plan variants"
	)


func _test_variant_rows(document: Dictionary, ledger: Dictionary) -> void:
	var source_ids: Array[String] = []
	for source_variant in ledger.get("sources", []) as Array:
		source_ids.append(str((source_variant as Dictionary).get("id", "")))
	var seen_ids: Array[String] = []
	var every_deferred := true
	var every_resolution_typed := true
	for variant_variant in document.get("variants", []) as Array:
		var variant := variant_variant as Dictionary
		var variant_id := str(variant.get("variant_id", ""))
		var refs := variant.get("source_ids", []) as Array
		var claim_ids := variant.get("claim_ids", []) as Array
		var resolved := variant.get("resolved", {}) as Dictionary
		seen_ids.append(variant_id)
		_check(not variant_id.is_empty(), "every floor-plan variant has a stable identifier")
		_check(not refs.is_empty() and not claim_ids.is_empty(), "variant %s has source and claim references" % variant_id)
		for source_ref in refs:
			_check(source_ids.has(str(source_ref)), "variant %s references a registered source" % variant_id)
		every_deferred = every_deferred and str(variant.get("disposition", "")) == "deferred"
		every_resolution_typed = (
			every_resolution_typed
			and resolved.has("adjacency")
			and resolved.has("scale")
			and resolved.has("version_conflicts")
			and not bool(resolved.get("adjacency", true))
			and not bool(resolved.get("scale", true))
		)
		_check(not str(variant.get("reason", "")).is_empty(), "variant %s explains its deferral" % variant_id)
	_check(
		seen_ids.size() == _unique_strings(seen_ids).size(),
		"floor-plan variant identifiers are unique"
	)
	_check(every_deferred, "no current source scope is promoted to an eligible floor-plan variant")
	_check(
		every_resolution_typed,
		"every current variant explicitly records unresolved adjacency and scale"
	)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "JSON resource opens: %s" % path)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary, "JSON resource parses as an object: %s" % path)
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
		print("STATION_FLOOR_PLAN_VARIANT_EVIDENCE_TEST_OK assertions=%d" % _assertions)
	else:
		push_error("STATION_FLOOR_PLAN_VARIANT_EVIDENCE_TEST_FAILED assertions=%d failures=%d" % [_assertions, _failures.size()])
	quit(1 if not _failures.is_empty() else 0)
