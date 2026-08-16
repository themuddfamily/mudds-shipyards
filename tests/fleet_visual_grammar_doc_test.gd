extends SceneTree

## Drift guard for `docs/design/FLEET_VISUAL_GRAMMAR.md`.
##
## The grammar document is the Phase 5 precondition: no new craft may be added
## until the original fleet's shared visual language is written down. A written
## precondition is only worth anything if it stays true, and this repository's
## recurring failure mode is documentation that quietly stops matching the code —
## the same failure that `tests/station_topology_evidence_test.gd` was written to
## remove on the station side.
##
## This suite removes it for the fleet grammar. It parses the three
## marker-delimited tables out of the document and compares every row against the
## thing that actually owns the value:
##
##   * `GRAMMAR-PALETTE` and `GRAMMAR-AUDIT-CONSTANTS` -> the constants and
##     literals inside `tests/fleet_role_differentiation_test.gd` and
##     `tests/fleet_colour_metrics.gd`, which are what the live audit enforces
##     against the production Main scene.
##   * `GRAMMAR-SURFACE` -> the exact material values authored in the ship and
##     station sources, so a change to a hull's `normal_scale` or `clearcoat`
##     cannot leave the document describing the old finish.
##   * `GRAMMAR-EVIDENCE` -> `docs/research/ship_evidence_matrix.json`, so the
##     document can never publish a stronger historical status than the ledger
##     holds.
##
## It also fails if the document uses any of the per-ship `prohibited_wording`
## recorded in the matrix, or an evidence status outside the registered
## vocabulary.
##
## The document is the subject under test, not an oracle: a wrong document turns
## this red exactly as loudly as wrong code does, and the check runs in both
## directions — a documented key with no registry entry fails, and a registry key
## missing from the document fails too, so a claim cannot be silently dropped.
##
## Scope boundary. This suite compares *stated numbers against their sources*. It
## proves nothing about the fleet itself: the colour floors, seating convention,
## boarding walk, envelope gates and lateral-trade-off rule are proved against the
## live production scene by `tests/fleet_role_differentiation_test.gd`, and this
## suite deliberately does not duplicate that work. It reads sources as text
## rather than loading the production scene, so it stays hermetic and fast; what
## it proves is exactly "the document and the code agree", nothing more.
##
## No production value is modified anywhere in this suite.

const DOCUMENT_PATH := "res://docs/design/FLEET_VISUAL_GRAMMAR.md"
const MATRIX_PATH := "res://docs/research/ship_evidence_matrix.json"
const AUDIT_PATH := "res://tests/fleet_role_differentiation_test.gd"
const METRICS_PATH := "res://tests/fleet_colour_metrics.gd"

const HERO_SHIP_PATH := "res://scripts/ships/hero_ship.gd"
const ARROW_PATH := "res://scripts/ships/arrow_recon_ship.gd"
const JOVIAN_PATH := "res://scripts/ships/jovian_light_freighter.gd"
const HALYARD_PATH := "res://scripts/ships/halyard_crew_transport.gd"
const TORRENT_HERO_PRESENTATION_PATH := "res://scenes/ships/presentation/torrent_hero_presentation.gd"
const TORRENT_MACROFORM_PATH := "res://scenes/ships/presentation/torrent_authored_macroform.tscn"
const ZENITH_PRESENTATION_PATH := "res://scenes/ships/presentation/zenith_authored_presentation.gd"
const SHIPYARD_WORLD_PATH := "res://scripts/world/shipyard_world.gd"

## Numeric constants declared in the audit suite. Key in the document -> the
## constant identifier that the live audit asserts with.
const AUDIT_CONSTANT_KEYS := {
	"body_tone_floor": "BODY_TONE_FLOOR",
	"accent_floor": "ACCENT_FLOOR",
	"torrent_accent_floor": "TORRENT_ACCENT_FLOOR",
	"body_tone_minimum_share": "BODY_TONE_MINIMUM_SHARE",
	"pale_body_minimum_lightness": "PALE_BODY_MINIMUM_LIGHTNESS",
	"seat_to_cockpit_camera_rise_m": "SEAT_TO_COCKPIT_CAMERA_RISE",
	"eye_above_head_bone_minimum_m": "EYE_ABOVE_HEAD_BONE_MINIMUM",
	"eye_above_head_bone_maximum_m": "EYE_ABOVE_HEAD_BONE_MAXIMUM",
	"head_hull_clearance_minimum_m": "HEAD_HULL_CLEARANCE_MINIMUM",
	"small_craft_envelope_maximum_m": "SMALL_CRAFT_ENVELOPE_MAXIMUM",
	"interior_minimum_volume_m3": "INTERIOR_MINIMUM_VOLUME",
	"boarding_fallback_reach_m": "BOARDING_FALLBACK_REACH",
	"minimum_staged_distance_m": "MINIMUM_STAGED_DISTANCE",
	"minimum_walk_metres": "MINIMUM_WALK_METRES",
}

## Numbers the audit spells inline inside its assertions rather than as named
## constants. Key in the document -> the pattern that recovers the literal.
## The per-craft interior floors moved into the audit's `INTERIOR_CRAFT` table
## when a second interior-bearing craft joined the fleet, so these patterns are
## anchored on each craft's own role tag rather than on a craft-specific local
## variable name. The values they recover are the same numbers the audit
## enforces; the freighter's are unchanged.
const AUDIT_LITERAL_KEYS := {
	"minimum_differing_handling_axes": "differing >= ([0-9]+)",
	"freighter_envelope_minimum_x_m": "\"light_freighter\",[\\s\\S]*?\"minimum_envelope_x\": ([0-9.]+)",
	"freighter_envelope_minimum_z_m": "\"light_freighter\",[\\s\\S]*?\"minimum_envelope_z\": ([0-9.]+)",
	"freighter_passenger_seat_minimum": "\"light_freighter\",[\\s\\S]*?\"minimum_seats\": ([0-9]+)",
	"crew_transport_envelope_minimum_x_m": "\"crew_transport\",[\\s\\S]*?\"minimum_envelope_x\": ([0-9.]+)",
	"crew_transport_envelope_minimum_z_m": "\"crew_transport\",[\\s\\S]*?\"minimum_envelope_z\": ([0-9.]+)",
	"crew_transport_seat_minimum": "\"crew_transport\",[\\s\\S]*?\"minimum_seats\": ([0-9]+)",
}

## Material values authored per craft. Key -> [source path, capture pattern].
const SURFACE_KEYS := {
	"normal_scale_torrent_procedural": [HERO_SHIP_PATH, "hull_material\\.normal_scale = ([0-9.]+)"],
	"normal_scale_torrent_authored_hero": [TORRENT_HERO_PRESENTATION_PATH, "material\\.normal_scale = ([0-9.]+)"],
	"normal_scale_torrent_macroform_atlas": [TORRENT_MACROFORM_PATH, "normal_scale = ([0-9.]+)"],
	"normal_scale_arrow": [ARROW_PATH, "hull_material\\.normal_scale = ([0-9.]+)"],
	"normal_scale_jovian": [JOVIAN_PATH, "hull_material\\.normal_scale = ([0-9.]+)"],
	"normal_scale_halyard": [HALYARD_PATH, "const HULL_NORMAL_SCALE := ([0-9.]+)"],
	"normal_scale_zenith_hull": [
		ZENITH_PRESENTATION_PATH,
		"PaleCeramicHull\": _hull_material\\(Color\\(\"[0-9a-fA-F]{6}\"\\), [0-9.]+, [0-9.]+, ([0-9.]+)\\)",
	],
	"normal_scale_zenith_secondary": [
		ZENITH_PRESENTATION_PATH,
		"PaleFacetSecondary\": _hull_material\\(Color\\(\"[0-9a-fA-F]{6}\"\\), [0-9.]+, [0-9.]+, ([0-9.]+)\\)",
	],
	"normal_scale_station_panel": [SHIPYARD_WORLD_PATH, "panel_material\\.normal_scale = ([0-9.]+)"],
	"clearcoat_torrent_procedural": [HERO_SHIP_PATH, "hull_material\\.clearcoat = ([0-9.]+)"],
	"clearcoat_torrent_authored_hero": [TORRENT_HERO_PRESENTATION_PATH, "material\\.clearcoat = ([0-9.]+)"],
	"clearcoat_arrow": [ARROW_PATH, "hull_material\\.clearcoat = ([0-9.]+)"],
	"clearcoat_jovian": [JOVIAN_PATH, "hull_material\\.clearcoat = ([0-9.]+)"],
	"clearcoat_halyard": [HALYARD_PATH, "const HULL_CLEARCOAT := ([0-9.]+)"],
	"clearcoat_zenith": [ZENITH_PRESENTATION_PATH, "material\\.clearcoat = ([0-9.]+)"],
}

## Document palette keys -> [audit dictionary name, ship id key inside it].
const PALETTE_KEYS := {
	"body_tone_torrent": ["EXPECTED_BODY_TONE", "torrent_provisional"],
	"body_tone_arrow": ["EXPECTED_BODY_TONE", "arrow_provisional"],
	"body_tone_jovian": ["EXPECTED_BODY_TONE", "jovian_provisional"],
	"body_tone_zenith": ["EXPECTED_BODY_TONE", "zenith_b7_observed"],
	"accent_torrent": ["EXPECTED_ACCENTS", "torrent_provisional"],
	"accent_arrow": ["EXPECTED_ACCENTS", "arrow_provisional"],
	"accent_jovian": ["EXPECTED_ACCENTS", "jovian_provisional"],
	"accent_zenith": ["EXPECTED_ACCENTS", "zenith_b7_observed"],
	"body_tone_halyard": ["EXPECTED_BODY_TONE", "halyard_new_design"],
	"accent_halyard": ["EXPECTED_ACCENTS", "halyard_new_design"],
}

const DOCUMENTED_SHIP_IDS := ["torrent", "zenith", "arrow", "jovian"]
const EMPTY_LIST_MARK := "—"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var document := FileAccess.get_file_as_string(DOCUMENT_PATH)
	_check(not document.is_empty(), "the fleet visual grammar document loads")
	var audit_source := FileAccess.get_file_as_string(AUDIT_PATH)
	_check(not audit_source.is_empty(), "the fleet role differentiation audit source loads")
	var metrics_source := FileAccess.get_file_as_string(METRICS_PATH)
	_check(not metrics_source.is_empty(), "the shared fleet colour metrics source loads")
	if document.is_empty() or audit_source.is_empty() or metrics_source.is_empty():
		_finish()
		return

	var matrix: Dictionary = _load_matrix()
	_check(not matrix.is_empty(), "the ship evidence matrix loads for the documented evidence check")

	_test_audit_constants(document, audit_source, metrics_source)
	_test_palette(document, audit_source)
	_test_surface_values(document)
	_test_evidence_rows(document, matrix)
	_test_prohibited_wording(document, matrix)
	_finish()


# ------------------------------------------------- audit constants ----

func _test_audit_constants(document: String, audit_source: String, metrics_source: String) -> void:
	var expected := {}
	for key: String in AUDIT_CONSTANT_KEYS:
		var identifier: String = AUDIT_CONSTANT_KEYS[key]
		var value := _capture(audit_source, "const %s := ([0-9.]+)" % identifier)
		_check(
			not value.is_empty(),
			"audit constant %s is still declared in %s" % [identifier, AUDIT_PATH]
		)
		expected[key] = value
	for key: String in AUDIT_LITERAL_KEYS:
		var value := _capture(audit_source, str(AUDIT_LITERAL_KEYS[key]))
		_check(
			not value.is_empty(),
			"the audit still spells the %s gate its own assertion enforces" % key
		)
		expected[key] = value

	# Axis counts are read from the arrays the dominance test iterates, so adding
	# or retiring a trade-off axis has to be reflected in the document.
	expected["higher_is_better_axis_count"] = str(
		_quoted_item_count(audit_source, "HIGHER_IS_BETTER := \\[([^\\]]*)\\]")
	)
	expected["lower_is_better_axis_count"] = str(
		_quoted_item_count(audit_source, "LOWER_IS_BETTER := \\[([^\\]]*)\\]")
	)
	expected["vision_model_count"] = str(
		_quoted_item_count(metrics_source, "VISION_MODELS: Array\\[String\\] = \\[([^\\]]*)\\]")
	)
	# The handling vector is whatever ShipDefinition publishes today, read live
	# rather than counted from source text.
	var definition := ShipDefinition.new()
	expected["handling_axis_count"] = str(
		definition.get_flight_profile().size() + definition.get_systems_profile().size()
	)

	_compare_key_table(document, "GRAMMAR-AUDIT-CONSTANTS", expected, true)


# ------------------------------------------------------- palette ----

func _test_palette(document: String, audit_source: String) -> void:
	var expected := {}
	for key: String in PALETTE_KEYS:
		var entry: Array = PALETTE_KEYS[key]
		var block := _capture(audit_source, "%s := \\{([^}]*)\\}" % str(entry[0]))
		_check(
			not block.is_empty(),
			"the audit still declares its %s palette table" % str(entry[0])
		)
		var hex := _capture(block, "&\"%s\": \"([0-9a-fA-F]{6})\"" % str(entry[1]))
		_check(
			not hex.is_empty(),
			"the audit still freezes a %s entry for %s" % [str(entry[0]), str(entry[1])]
		)
		expected[key] = hex
	_compare_key_table(document, "GRAMMAR-PALETTE", expected, false)


# ------------------------------------------------------- surface ----

func _test_surface_values(document: String) -> void:
	var expected := {}
	for key: String in SURFACE_KEYS:
		var entry: Array = SURFACE_KEYS[key]
		var source := FileAccess.get_file_as_string(str(entry[0]))
		_check(not source.is_empty(), "%s loads for the %s surface claim" % [str(entry[0]), key])
		var value := _capture(source, str(entry[1]))
		_check(
			not value.is_empty(),
			"%s still authors the material value the document publishes as %s" % [str(entry[0]), key]
		)
		expected[key] = value
	_compare_key_table(document, "GRAMMAR-SURFACE", expected, true)


# ------------------------------------------------------ evidence ----

func _test_evidence_rows(document: String, matrix: Dictionary) -> void:
	var rows := _table_rows(document, "GRAMMAR-EVIDENCE")
	_check(
		rows.size() == DOCUMENTED_SHIP_IDS.size(),
		"the documented evidence table carries exactly the four implemented craft (%d rows)"
			% rows.size()
	)
	var vocabulary: Array = ((matrix.get("policy", {}) as Dictionary)
		.get("evidence_status_vocabulary", []) as Array)
	_check(not vocabulary.is_empty(), "the matrix publishes its evidence status vocabulary")

	var by_id := {}
	for entry in (matrix.get("ships", []) as Array):
		var ship: Dictionary = entry
		by_id[str(ship.get("ship_id", ""))] = ship

	var seen := PackedStringArray()
	for row in rows:
		var cells: PackedStringArray = row
		if cells.size() < 4:
			_check(false, "every documented evidence row carries four columns")
			continue
		var ship_id := cells[0]
		seen.append(ship_id)
		_check(by_id.has(ship_id), "documented craft '%s' exists in the evidence matrix" % ship_id)
		if not by_id.has(ship_id):
			continue
		var ship: Dictionary = by_id[ship_id]
		var documented_status := cells[1]
		_check(
			vocabulary.has(documented_status),
			"%s uses a registered evidence status ('%s')" % [ship_id, documented_status]
		)
		_check(
			documented_status == str(ship.get("name_to_model_status", "")),
			"%s documents the matrix name_to_model_status (document '%s', matrix '%s')"
				% [ship_id, documented_status, str(ship.get("name_to_model_status", ""))]
		)
		var documented_sources := _split_list(cells[2])
		var matrix_sources := PackedStringArray()
		for source in (ship.get("model_sources", []) as Array):
			matrix_sources.append(str(source))
		_check(
			", ".join(documented_sources) == ", ".join(matrix_sources),
			"%s documents the matrix model_sources (document [%s], matrix [%s])"
				% [ship_id, ", ".join(documented_sources), ", ".join(matrix_sources)]
		)
		_check(
			cells[3] == str(ship.get("implementation_status", "")),
			"%s documents the matrix implementation_status (document '%s', matrix '%s')"
				% [ship_id, cells[3], str(ship.get("implementation_status", ""))]
		)
	for ship_id: String in DOCUMENTED_SHIP_IDS:
		_check(
			seen.has(ship_id),
			"the documented evidence table still covers the implemented craft '%s'" % ship_id
		)


func _test_prohibited_wording(document: String, matrix: Dictionary) -> void:
	var lowered := document.to_lower()
	var checked := 0
	for entry in (matrix.get("ships", []) as Array):
		var ship: Dictionary = entry
		for phrase in (ship.get("prohibited_wording", []) as Array):
			checked += 1
			if lowered.contains(str(phrase).to_lower()):
				_check(
					false,
					"the grammar document avoids the prohibited %s wording '%s'"
						% [str(ship.get("ship_id", "")), str(phrase)]
				)
				return
	_check(
		checked > 0,
		"the matrix supplies prohibited wording for the grammar document to be screened against (%d phrases)"
			% checked
	)
	_check(
		true,
		"the grammar document uses none of the %d prohibited historical-claim phrasings" % checked
	)


# -------------------------------------------------------- helpers ----

## Compares a documented `| key | value | ... |` table against `expected` in both
## directions. `numeric` selects float comparison so `0.10` and `0.1` agree.
func _compare_key_table(
		document: String,
		marker: String,
		expected: Dictionary,
		numeric: bool
	) -> void:
	var rows := _table_rows(document, marker)
	_check(not rows.is_empty(), "the %s table is present and parses" % marker)
	var documented := {}
	for row in rows:
		var cells: PackedStringArray = row
		if cells.size() < 2:
			_check(false, "every %s row carries a key and a value" % marker)
			continue
		_check(
			not documented.has(cells[0]),
			"%s documents '%s' exactly once" % [marker, cells[0]]
		)
		documented[cells[0]] = cells[1]
	for key: String in documented:
		_check(
			expected.has(key),
			"%s key '%s' is backed by a registered source in this suite" % [marker, key]
		)
	for key: String in expected:
		var actual := str(expected[key])
		if not documented.has(key):
			_check(false, "%s still documents '%s' (expected %s)" % [marker, key, actual])
			continue
		var stated := str(documented[key])
		var agrees := stated == actual
		if numeric and not agrees:
			agrees = stated.is_valid_float() and actual.is_valid_float() \
				and is_equal_approx(stated.to_float(), actual.to_float())
		_check(
			agrees,
			"%s '%s' matches its source (document '%s', source '%s')"
				% [marker, key, stated, actual]
		)


func _load_matrix() -> Dictionary:
	var raw := FileAccess.get_file_as_string(MATRIX_PATH)
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


## First capture group of `pattern` in `text`, or "" when it does not match.
func _capture(text: String, pattern: String) -> String:
	var expression := RegEx.new()
	if expression.compile(pattern) != OK:
		return ""
	var found := expression.search(text)
	if found == null:
		return ""
	return found.get_string(1)


## Number of double-quoted entries inside the array literal `pattern` captures.
func _quoted_item_count(text: String, pattern: String) -> int:
	var body := _capture(text, pattern)
	if body.is_empty():
		return -1
	var quotes := 0
	for index in body.length():
		if body.unicode_at(index) == 34:
			quotes += 1
	return quotes / 2


## Data rows of a marker-delimited markdown table, as arrays of unwrapped cells.
## The header row and its separator are dropped and backticks stripped, so the
## document stays readable markdown while the values stay comparable.
func _table_rows(document: String, marker: String) -> Array:
	var begin_token := "<!-- %s:BEGIN -->" % marker
	var end_token := "<!-- %s:END -->" % marker
	var begin := document.find(begin_token)
	var end := document.find(end_token)
	if begin < 0 or end <= begin:
		return []
	var block := document.substr(begin + begin_token.length(), end - begin - begin_token.length())
	var rows: Array = []
	for raw_line in block.split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("|"):
			continue
		var cells := PackedStringArray()
		var is_separator := true
		for raw_cell in line.split("|"):
			var cell := str(raw_cell).strip_edges()
			if cell.is_empty():
				continue
			cells.append(cell.replace("`", ""))
			if cell.replace("-", "").strip_edges() != "":
				is_separator = false
		if cells.is_empty() or is_separator:
			continue
		rows.append(cells)
	if not rows.is_empty():
		rows.remove_at(0)
	return rows


## An em dash marks a deliberately empty list, which must not become a single
## entry named after the dash.
func _split_list(cell: String) -> PackedStringArray:
	var trimmed := cell.strip_edges()
	if trimmed.is_empty() or trimmed == EMPTY_LIST_MARK:
		return PackedStringArray()
	var entries := PackedStringArray()
	for raw in trimmed.split(","):
		var entry := str(raw).strip_edges()
		if not entry.is_empty():
			entries.append(entry)
	return entries


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_VISUAL_GRAMMAR_DOC_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print(
			"FLEET_VISUAL_GRAMMAR_DOC_TEST_FAILED: %d/%d assertions failed: %s"
				% [_failures.size(), _assertions, "; ".join(_failures)]
		)
		quit(1)
