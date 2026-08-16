extends SceneTree

## Live import/material audit for the station-only symmetry-safe PBR tile and
## the CentralBerth authored UV0 correction. Ship-specific material identities
## remain deliberately outside the station material family.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ALBEDO_PATH := "res://assets/materials/procedural-panel-triplanar-albedo-v2.png"
const NORMAL_PATH := "res://assets/materials/procedural-panel-triplanar-normal-v2.png"
const ROUGHNESS_PATH := "res://assets/materials/procedural-panel-triplanar-roughness-v2.png"
const TORRENT_HULL_PATH := "res://assets/materials/torrent-hull-albedo-v1.png"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_imported_normal_direction()
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main scene instantiates for live texture audit")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	_check(world != null, "production ShipyardWorld is present")
	if world != null:
		_test_live_station_coverage(world)
		_test_live_central_deck_uv0(world)
	_test_four_ship_material_identity(game)
	game.queue_free()
	await process_frame
	_finish()


func _test_imported_normal_direction() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(NORMAL_PATH))
	var imported_texture := load(NORMAL_PATH) as Texture2D
	var imported := imported_texture.get_image() if imported_texture != null else null
	_check(
		source != null and not source.is_empty()
		and imported != null and not imported.is_empty()
		and source.get_size() == Vector2i(512, 512)
		and imported.get_size() == source.get_size(),
		"normal source and live imported texture are pixel-registered at 512 square"
	)
	if source == null or imported == null or source.is_empty() or imported.is_empty():
		return
	var directional_samples := 0
	var maximum_red_blue_error := 0.0
	var maximum_inverted_green_error := 0.0
	for y in range(0, source.get_height(), 3):
		for x in range(0, source.get_width(), 3):
			var encoded := source.get_pixel(x, y)
			if absf(encoded.g - 0.5) < 0.02:
				continue
			var live := imported.get_pixel(x, y)
			directional_samples += 1
			maximum_red_blue_error = maxf(
				maximum_red_blue_error,
				maxf(absf(live.r - encoded.r), absf(live.b - encoded.b))
			)
			maximum_inverted_green_error = maxf(
				maximum_inverted_green_error,
				absf(live.g - (1.0 - encoded.g))
			)
	_check(
		directional_samples >= 1000
		and maximum_red_blue_error <= 1.1 / 255.0
		and maximum_inverted_green_error <= 2.1 / 255.0,
		"live imported normal preserves X/Z and performs the exact effective tangent-Y inversion"
	)


func _test_live_station_coverage(world: ShipyardWorld) -> void:
	var mapped_surface_count := 0
	var scale_022_count := 0
	var scale_028_count := 0
	var scale_030_count := 0
	var exact_recipe := true
	var forbidden_ship_atlas_count := 0
	# The nearby sector cluster is inside the world but is not station stock, and
	# its plate size is not the station's. `uv1_scale` is a physical scale under
	# world triplanar — 0.22 lays a plate every 4.5 m, which is right for a 2 m
	# door frame and reads as woven gingham on Cinder Reach's 34 m gantry beams,
	# where a rendered frame settled it. So the cluster keeps the same registered
	# maps and the same `normal_scale`, at its own coarser scales, and this
	# station-family census stops at the station envelope. `_test_cluster_family`
	# below holds the excluded subtree to the recipe so nothing hides in the gap.
	# Same reasoning for the VIP reception suite, and it is the whole point of that
	# room: it is deliberately NOT station stock. Its registered table runs 0.12
	# pearl through 0.40 bronze — roughly metre-wide plate on the shell where the
	# working modules put one every half metre — and both directions of that were
	# rendered before the values were frozen (0.22 everywhere photographed as a
	# riveted tile grid, 1.05 as bathroom mosaic). Folding those scales into the
	# station family would either fail this census or force the room back onto the
	# working grain and undo the only thing that separates it. It keeps the same
	# registered maps and normal_scale; `_test_vip_suite_family` holds it to the
	# recipe so nothing hides in the gap.
	var vip_root := world.get_node_or_null(^"VipReceptionSuite")
	var cluster_root := world.get_node_or_null(^"NearbySectorCluster")
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		if vip_root != null and vip_root.is_ancestor_of(mesh_instance):
			continue
		if cluster_root != null and cluster_root.is_ancestor_of(mesh_instance):
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			var albedo_path := _texture_path(material.albedo_texture)
			if "arrow-hull-" in albedo_path or "jovian-hull-" in albedo_path:
				forbidden_ship_atlas_count += 1
			if albedo_path != ALBEDO_PATH:
				continue
			mapped_surface_count += 1
			exact_recipe = (
				exact_recipe
				and material.normal_enabled
				and _texture_path(material.normal_texture) == NORMAL_PATH
				# Re-frozen from 0.48 by a rendered sweep at 0.48 / 1.0 / 1.4 / 1.9.
				# 0.48 left plated walls nearly featureless at eye height; 1.9 domed
				# the plate faces into embossed plastic on bright surfaces. 1.0 is the
				# highest sampled value with no doming in any frame. This stays an
				# exact equality on purpose: the whole point is that every module
				# shares one relief depth.
				and is_equal_approx(material.normal_scale, 1.0)
				and _texture_path(material.roughness_texture) == ROUGHNESS_PATH
				and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
				and material.uv1_triplanar
				and material.uv1_world_triplanar
				and material.texture_repeat
			)
			if material.uv1_scale.is_equal_approx(Vector3.ONE * 0.22):
				scale_022_count += 1
			elif material.uv1_scale.is_equal_approx(Vector3.ONE * 0.28):
				scale_028_count += 1
			elif material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30):
				scale_030_count += 1
			else:
				exact_recipe = false
	print(
		"LIVE_STATION_TRIPLANAR_COVERAGE: mapped=", mapped_surface_count,
		" scale_0.22=", scale_022_count,
		" scale_0.28=", scale_028_count,
		" scale_0.30=", scale_030_count
	)
	# Re-frozen from 507/11/262/234 when the walked-on overlays joined the family:
	# the Aft continuous stair ramp plus nine operations pressure plates (+10 at
	# 0.30) and the three Habitat connector/corridor/common floor insets (+3 at
	# 0.28). No previously mapped surface was removed and no scale changed.
	#
	# Re-frozen again from 520/11/265/244 by the MAP-001 stair-gate fix: the
	# stair-base landing gained a south and a west guard rail (+4 `warm_grey`
	# posts) and the eastern stair rail line no longer starts on the landing
	# (-1 post), a net +3 at the Aft module's 0.30 scale. The two new pod
	# threshold aprons use `deck_light`, which is not in this family, so they do
	# not appear here. No previously mapped surface was removed and no scale
	# changed.
	#
	# Re-frozen again from 523/11/265/247 when the last three unmapped station
	# populations joined the family, all at the Aft module's existing 0.30 scale
	# and all with the recipe copied verbatim:
	#
	#   `StationOperationsActivity` bound its four structural greys (`frame`,
	#   `frame_edge`, `graphite`, `ceramic`), adding 106 surfaces across the four
	#   production placements (FULL, GANTRY, SERVICE_ARM, DRONE_PATROL).
	#   `FleetDockComb` bound `deck`, `deck_light`, `frame`, `underframe` and
	#   `grip`, adding 33.
	#   `ShipyardWorld` bound `deck`, `deck_light`, `navy`, `blue`, `steel_blue`,
	#   `ivory` and `black`, adding 247. This was by far the largest gap: the hub
	#   owns roughly 6.6 thousand square metres of walkable deck plus keels,
	#   braces and pods, and `_material()` had produced pure scalar colour with no
	#   albedo, normal, roughness or triplanar at all.
	#
	#   `AftJunctionStack` additionally bound `mid_grey` and `hull_dark`, adding
	#   121. Those are the same two colours as its already-mapped `mid_grey_floor`
	#   and `hull_dark_floor`, so a wall was reading as plastic while the plated
	#   floor met it at the skirting.
	#
	# Net +368 mapped surfaces, 662 -> 1030. The 0.28 bucket returns to 265 because
	# the Fleet Dock comb moved from 0.28 to 0.30 to match the hub it bolts onto,
	# so no plate size changes across the connector seam; that is a move between
	# frozen buckets, not a new scale. 0.30 goes 353 -> 633. 0.22 is untouched.
	# Painted hazard bands, tyre rubber, transparent glass and every emissive
	# legend, route cue and beacon lens deliberately stay outside the family in
	# every module, so signage and lit cues keep their flat readable identity. No
	# previously mapped surface was removed and no new scale was introduced.
	#
	# Re-frozen again from 1154/115/285/754 by the structural-and-painted closing
	# pass, measured per key against the live scene:
	#
	#   `HabitatSpine.structural` +233 at 0.28. The module's primary structural
	#   grey: pressure ribs, service rails, bunk plinths, window mullions, chair
	#   pedestals. At eye height in a bunk bay it read as wet black plastic beside
	#   a plated wall, and it is by far the largest single population here.
	#   `AftJunctionStack.brass` +51 at 0.30 and `HabitatSpine.brass` +14 at 0.28.
	#   New non-emissive structural twins of the `gold` / `amber` cue colours. The
	#   cue colours keep every route arc tile, control lamp, cabinet status and
	#   sign; the twins take only the physical brass furniture — handrails,
	#   collars, column feet, fasteners — which were flat yellow sticks bolted to
	#   plated posts at arm's reach.
	#   `JovianFreightBerth.orange` +43 at 0.30. Painted handling steel: crane
	#   rails and feet, rack beams, apron and lattice diagonals, rail posts. It was
	#   the loudest untextured population left in the station.
	#
	# Net +341, 1154 -> 1495. 0.22 is untouched at 115; 0.28 goes 285 -> 532 and
	# 0.30 goes 754 -> 848. No previously mapped surface was removed and no new
	# scale was introduced. Deliberately still outside the family everywhere:
	# every emissive cue (`cyan`, `red`, `teal`, `amber`, `gold`, `*_glow`,
	# `worklight`), the `orange_glow` hazard and lane striping, transparent
	# `glass`, `rubber`, seating fabric, screens, the dark `graphite` seam and
	# reveal trim whose whole job is to read as a clean unbroken line, and the
	# `copper` pipe runs, which are drawn tube stock rather than panel.
	#
	# Re-frozen again from 1495/115/532/848 by the station-life pass, which added
	# four new `StationOperationsActivity` placements to the production lattice.
	# Measured per placement against the live scene, all at the component's own
	# 0.30 physical scale:
	#
	#   `CentralCargoTransferLine` (cargo_line) +30 of its 47 meshes.
	#   `FreightApproachSignage` (signage_pylon) +19 of 33.
	#   `HabitatSkywatchPost` (observatory) +26 of 33.
	#   `AftCrewWorkPost` (crew_workpost) +37 of 48.
	#
	# The two new painted-container colours `crate` and `crate_alt` joined the
	# family, because a shipping container is plate stock like everything else the
	# component bolts to a deck. The other three new materials did not: `green_dim`
	# / `green_lit` are a status cue and `sign_lit` is a lit sign face, and every
	# module already keeps its cues flat and readable.
	#
	# Net +112, 1495 -> 1607. 0.22 is untouched at 115 and 0.28 is untouched at
	# 532; 0.30 goes 848 -> 960. No previously mapped surface was removed and no
	# new scale was introduced.
	#
	# Re-frozen once more, 1607 -> 1627, by the station-navigation slice. Its four
	# `StationServiceAgent` couriers were the last visible station bodies still
	# built from raw `BoxMesh` with flat scalar colour; a rendered review at player
	# eye height showed them reading as untextured primitives beside the plated
	# deck they fly over, so their `hull`, `hull_edge` and `graphite` greys joined
	# the family at 0.30. Five of each courier's seven meshes are structural
	# (`Hull`, `ForwardCowl`, `PortPod`, `StarboardPod`, `TailFin`), so 4 x 5 = +20
	# at 0.30, 960 -> 980. The painted `orange` cargo pod and the cyan status lens
	# stay outside the family like every other module's painted and lit cues.
	# Re-frozen again by the global art-direction pass: `ShipyardWorld.orange`
	# joins the family, +68 at 0.30, 1495 -> 1563 and 848 -> 916. This is the same
	# move the Jovian berth's `orange` made in the previous pass and for the same
	# reason. The hub's hazard-paint role is not signage: it covers every branch
	# cross brace, every rail post on the branch arms, the aft spine and the aft
	# connector, the dock mast collars, the signal mast collars, the junction
	# stair rail, the safety pylons and the tow tractor. Left unmapped those were
	# the largest remaining fields of flat untextured colour anywhere in a deck
	# frame, and with the palette pass desaturating them to ochre they still read
	# as moulded plastic sticks next to plated steel until they took the plate.
	# 0.22 and 0.28 are untouched. Everything listed above as deliberately outside
	# the family stays outside it: the hub's own emissives, `orange_glow` lane
	# striping, `red` alert paint and the transparent `glass` are unchanged.
	#
	# Re-frozen once more, 1627 -> 1703, when the global look pass merged with the
	# station-life and nearby-sector work. Measured on the merged tree rather than
	# predicted: neither branch's arithmetic gives this number on its own. The look
	# pass's `HAZARD_AMBER` split the hazard surface off the warning lamp and joined
	# the plate family, which lands at BOTH mapped scales, not just 0.30 --
	# 0.22 goes 115 -> 129 (+14) and 0.30 goes 980 -> 1042 (+62). 0.28 is untouched
	# at 532. No previously mapped surface was removed and no new scale introduced.
	#
	# Re-frozen once more, 1703 -> 1764, by the interior-relationship pass, which
	# dressed the comb's three dock arms, the regeneration/registry pod and the
	# central observation platform. Every piece it added was built on an already
	# registered structural role, so no role joined or left the family, no new
	# scale was introduced, and 0.22 and 0.28 are untouched at 129 and 532: the
	# whole delta is +61 at 0.30, 1042 -> 1103. It is arithmetic rather than a
	# measurement, and it reconciles exactly:
	#
	#   Fleet Dock Comb, +39. Per arm, ten mapped parts — bracket and toe kerb
	#   (`frame`), service pod, umbilical head and two cleat bollards
	#   (`underframe`), mast and cap (`deck_light`), two cleat pads (`grip`) —
	#   plus one boom (`underframe`) each, so 33; then the assigned arm's dropped
	#   umbilical hose, the two trunk conduits and the three rung branch conduits,
	#   all `underframe`, +6. The three mast status lenses stay outside the family
	#   with every other cue, exactly as the slab stripes and corner beacons do.
	#   Registry pod, +16: four roof columns, two terminal risers, the task-lamp
	#   housing and the parts tray (`steel_blue`), the roof fascia, dispatch board,
	#   tool rack and observation console (`navy`), the crew bench (`deck_light`),
	#   the stowed manifest (`ivory`), and three floor marks (`orange`). The four
	#   berth tiles are `cyan_glow` and stay out.
	#   Dock Operations pod, +1: its matching roof fascia (`steel_blue`). The
	#   glazing went four panes to three and every pane is transparent `glass`,
	#   which was never in the family, so that repair moves this count by nothing.
	#   Observation landing, +5: deck inset (`deck`), console and viewer head
	#   (`navy`), viewer post (`steel_blue`), equipment locker (`deck_light`). Its
	#   lit readout and legend stay out with the other emissives.
	# Re-frozen once more, 1703 -> 1706, by the interior legibility pass. The
	# operations room's single centreline row of three ceiling luminaires became
	# two rows of three, so three more `CeilingLuminaireBody` boxes exist and they
	# are `hull_dark`, which is in the plate family. That is the entire delta:
	# 0.30 goes 1042 -> 1045 (+3), 0.22 and 0.28 are untouched at 129 and 532. The
	# same pass added three more luminaire bodies in the habitat common room and a
	# sill cove lens, none of which appear here, because the habitat's `graphite`
	# and every lens material (`worklight`, `warm_light`, `teal_dim`) are lit or
	# painted cues and stay outside the family exactly as they did before.
	# Re-frozen once more, 1767 -> 1863, by the central-berth finishing pass, which
	# furnished the hero berth's empty port flank with ground support equipment and
	# put foot hardware under the four dock masts. Like the interior-relationship
	# pass above, every piece is built on an already registered hub role, so no
	# role joined or left the family, no new physical scale was introduced, and
	# 0.22 and 0.28 are untouched at 129 and 532. The whole delta is +96 at 0.30,
	# 1106 -> 1202, and it reconciles piece by piece:
	#
	#   Berth readiness board, +14: foot, three pin sockets, the two dark bay
	#   tiles, the withdrawn-pin clip and the lamp hood (`black`); the board mast
	#   (`steel_blue`); the panel and the seated retaining pin (`ivory`); the board
	#   face (`navy`); the two withdrawn pins (`orange`). The lit bay tile is
	#   `berth_cyan_glow` and the hood lens is `white_glow`, so both stay outside
	#   the family with every other cue and lens.
	#   Cable drum stand, +14: plinth, three stowed coils and three lead segments
	#   (`black`); two cheeks and the deck coupling (`steel_blue`); the barrel
	#   (`orange`); crank hub, crank arm and crank grip (`ivory`).
	#   Parts bin rack, +18: foot and strip housing (`black`); two uprights
	#   (`steel_blue`); two shelves and two of the six stock blocks (`ivory`, with
	#   the other four `black`); six bins (`orange`/`blue`). Its strip lens is
	#   `white_glow` and stays out.
	#   Chock locker, +8: body (`deck_light`); lid (`black`); door (`navy`);
	#   handle (`ivory`); two chock bodies and two chock ramps (`orange`).
	#   Access work stand, +14: four legs and the lamp arm (`steel_blue`);
	#   platform and two steps (`deck_light`); three rail posts, the rail and the
	#   stowed hard hat (`orange`); the lamp hood (`black`). The toolbox is `red`
	#   alert paint, which has never been in the family, and the lamp lens is
	#   `white_glow`, so neither appears here.
	#   Dock mast feet, +28: seven mapped parts each at four masts — base flange
	#   and lamp hood (`black`), two cleat stems and two cleat horns (`ivory`),
	#   junction box (`steel_blue`). Each foot's state tile and lens are
	#   `berth_cyan_glow` and stay out, exactly as the comb's mast status lenses do.
	#
	# The assertion text is corrected to the frozen number at the same time; it had
	# been left reading 1764 through the two re-freezes above.
	#
	# Re-frozen 1863 -> 1876 on merge, measured on the merged tree rather than
	# predicted. The central-berth service line was authored against a base that
	# did not yet carry the Halyard's widened Dock 02 apron; both passes add
	# plated structure at 0.30, so neither branch's total is right on its own and
	# they do not simply sum from either side. 0.22 stays 129 and 0.28 stays 532 -
	# every added surface is plate stock at 0.30, which goes 1202 -> 1215.
	# Re-frozen once more, 1767 -> 1890, by the Jovian freight-handling pass, which
	# furnished the freight berth's apron. No structural role joined or left the
	# family and no new scale was introduced: the freight module's registered plate
	# roles are unchanged at `ceramic`, `ceramic_warm`, `ceramic_floor`,
	# `steel_blue`, `deck` and `orange`, so the whole delta is +1 at 0.22 (129 ->
	# 130) and +122 at 0.30 (1106 -> 1228), with 0.28 untouched at 532. It is
	# arithmetic rather than a measurement, and it reconciles exactly:
	#
	#   0.22, +1: the boarding platform deck, the pass's one walked-on `deck`
	#   surface. Its seven stair blocks and the gantry catwalk are `deck_grip`,
	#   which has never been in the family.
	#   Approach portal, +6: two masts and two mast feet, the header beam and the
	#   freight-control door header. The sign board and its fascia are `deep_blue`,
	#   the chevrons and mast bands `orange_glow`, the board edges `cyan` — all cues
	#   and all outside the family, exactly as the module's other lane striping is.
	#   Handling zones, +18: ten envelope bollards and eight lashing rings. The
	#   bollard collars, both painted staging bays and every hatch strip are
	#   `orange_glow`; the lashing plates are `graphite`; the chocks are `rubber`.
	#   Freight stores, +42: six rack decks, six stored crates, six stored drums,
	#   five lockers with five doors and five handles, the locker canopy, two
	#   gas-bottle uprights and their rail, four pallet drums and the skip body. The
	#   bottles themselves are `cyan_dim`/`red` alert paint, the bases and rims
	#   `graphite`, the skip band `orange_glow`.
	#   Loading apparatus, +19: four platform legs, four rail posts and three rails,
	#   the toe board, two hose reel drums, the pallet truck body, and the two
	#   staged stacks' lower and upper crates. Pallets, stands and the truck handle
	#   are `graphite`; the straps are `deep_blue`.
	#   Gantry access, +35: ten catwalk rail posts, two top rails, two toe boards,
	#   twelve ladder rungs, two ladder stringers, four cage hoops, the crane cab,
	#   its leg bracket and its floor plate. The catwalk deck and landing are
	#   `deck_grip`, the cab glazing is transparent `glass`, the cable tray
	#   `graphite`.
	#   Dispatch annex, +2: the manifest kiosk and the load-check readout post. Its
	#   screens are `screen`, its plate `deck_grip` and its corner marks
	#   `orange_glow`.
	#   The eighteen new dock-guide lens housings are `graphite` and add nothing
	#   here, which is the point of them: they are the missing fitting under an
	#   existing lens, not a new painted surface.
	#
	# Re-frozen 1876 -> 1999 on merge, measured on the merged tree. The freight
	# berth pass adds 105 handling fixtures across 36 classes and 100 drawn
	# meshes; 0.22 gains one surface (130) and 0.30 gains 122 (1337), with 0.28
	# untouched at 532. Measured rather than summed: this branch was authored
	# before the Halyard apron and the central berth service line landed, and
	# neither branch's total is correct on its own.
	# Re-frozen once more, 1767 -> 1940, by the aft operations content pass. Every
	# piece it added sits on a structural role this module had already bound, so no
	# role joined or left the family and no scale was introduced: 0.22 and 0.28 are
	# untouched at 129 and 532, and the whole delta is +173 at the Aft module's own
	# 0.30, 1106 -> 1279. Measured against the live scene and reconciled per
	# assembly, which is the check that the number is the content and not a drift:
	#
	#   Watch rack bank, 67. Three `mid_grey` rack frames and three `hull_dark`
	#   caps; two fascias plus the removed third; ten plug-in modules with two
	#   `brass` knobs each; fourteen `panel_light` cards in the two opened cages;
	#   three breaker bodies and three levers; the tray, its riser and four clamps;
	#   the lockout hasp and chain.
	#   Module status board, 27. Body, four frame members, five schematic links, six
	#   nodes, six annunciator bodies and the five raised flags.
	#   Traffic plot table, 23. Two pedestals, top, apron, chart cradle, disc rim,
	#   hub, five tokens, four rim posts, two rim rails, the sweep beam and head,
	#   the mug and its handle, and the dividers.
	#   Coordinator desk, 11. Body, top, two drawer fronts, two pulls, lamp stalk
	#   and head, the pen, the handset cradle and the headset hook.
	#   Chart press, 13. Body, top, five drawer fronts, five pulls, clipboard hook.
	#   Refreshment stand, 16. Counter, top, two doors, two pulls, urn, collar, lid,
	#   tap and handle, four mugs, and the waste bin.
	#   Stair-head muster locker, 16. Both carcass halves, the bay side and top, the
	#   cap, both doors, the latch and open-door pull, the hose hub, three kit
	#   cases, two headboard posts and the route board.
	#
	# Deliberately still outside the family, exactly as everywhere else: the two new
	# `fabric` and `paper` roles (a coverall, chart rolls, notice sheets, a duty
	# log), `graphite` seam and chart-field trim, `rubber` kicks, `copper` cable
	# looms and the hose reel, and every lit cue — `cyan`, `gold`, `red`,
	# `screen_dark`, `worklight`, `amber_light`, `cyan_dim` — including the plot
	# graticule, the annunciator lenses and both legends.
	#
	# Re-frozen 1999 -> 2172 on merge, measured on the merged tree. The aft
	# operations content pass adds +173 at the aft module's existing 0.30 scale
	# (1337 -> 1510); 0.22 stays 130 and 0.28 stays 532. Measured rather than
	# summed: that pass was authored before the Halyard apron, the central berth
	# service line and the freight berth pass landed.
	# Re-frozen once more, 1764 -> 1813, by the long-cargo pass. 0.22 and 0.28 are
	# untouched at 129 and 532; the whole delta is +49 at 0.30, 1103 -> 1152. It is
	# arithmetic and it reconciles exactly:
	#
	#   `CentralCargoTransferLine` (cargo_line) 30 -> 23, a loss of 7. Its five
	#   rail ties (`graphite`) and two container ribs (`crate_alt`) became
	#   instanced copies and so are no longer individual surfaces this walk sees.
	#   Nothing was unmapped: the batches bind the same materials, and
	#   `_test_instanced_station_family()` below holds them to the same recipe.
	#   Its four sled wheels (`rubber`) and two hoist post bands (`orange`) were
	#   never in the family and so move nothing.
	#   `PortBranchCargoLine` and `StarboardBranchCargoLine` (cargo_line_long)
	#   +28 each of their 39 meshes: two rail beams, four hoist posts and two
	#   hoist rails (`frame` / `frame_edge`), two pallet decks (`graphite`), six
	#   crates (`crate` / `crate_alt`), the control pedestal and housing, three of
	#   the sled's five parts, three of the hoist's four, and four beacon bases.
	#   The rail stops, the hook, the lit manifests, the readout and the beacon
	#   lenses stay outside the family with every other painted and lit cue.
	#
	# No previously mapped surface was unmapped and no new scale was introduced.
	#
	# Re-frozen 2172 -> 2221 on merge, measured on the merged tree. The cargo line
	# expansion adds +49, all at 0.30 (1510 -> 1559); 0.22 stays 130 and 0.28 stays
	# 532. Measured rather than summed: that pass was authored before the aft
	# operations content landed.
	#
	# NOT re-frozen when the VIP reception suite landed, and that is the result
	# rather than an oversight: its 63 mapped surfaces leave this census entirely,
	# because that room is deliberately not station stock and carries its own
	# registered scale table (0.12 pearl through 0.40 bronze). It keeps the same
	# maps and the same normal_scale and is held to the recipe by its own family
	# test, exactly as the Cinder Reach cluster already was. The station family is
	# unchanged at 2221 / 130 / 532 / 1559.
	#
	# Re-frozen 2221 -> 2436 on rebase, measured on the merged tree. The habitat
	# rooms pass adds +215 at the habitat module's existing 0.28 scale (532 -> 747);
	# 0.22 stays 130 and 0.30 stays 1559. No non-habitat role or scale changed.
	#
	# What the +215 is. The habitat's living quarters were furnished: six bunk
	# mouths given jambs, heads and head lips, and the berths behind them given
	# shelves, brackets, stowage nets, locker shutters and shelves; a galley run
	# with a carcass, worktop, splashback, doors, rail posts and a bin; a mess
	# table with trestles, top and two benches; a berth roster board; and a
	# vestibule notice wall with its shelf and brackets. Every one of those is
	# structure or fitted joinery, so every one of them is in the plate family at
	# this module's frozen 0.28 m physical scale.
	#
	# What is deliberately *not* in it, and this is the larger half of the pass by
	# object count: the blankets, folded linen, curtains, coveralls, boots, kit
	# bags, mugs, trays, ration cartons, name cards, notice cards, the floor mat
	# and the planting. Those are `linen`, `blanket`, `coverall`, `leather`,
	# `plastic_pale`, `paper`, `rug`, `netting` and `greenery` — a soft-goods
	# palette created for this pass and deliberately left unmapped, because a
	# plate-and-rivet normal map at 0.28 m per repeat would print rivets across a
	# 0.3 m mug. Same split the operations module makes between its six structural
	# keys and its painted accents. The one new mapped material is `steel_bright`,
	# the galley worktop, which is a 4.3 m plate at waist height under a task light
	# and is exactly the case a flat scalar surface fails.
	# Re-frozen 2436 -> 2551 on rebase, measured on the merged tree. The side
	# branch garden bay moves only 0.28, 747 -> 862 (+115); 0.22 remains 130 and
	# 0.30 remains 1559. The delta is the bay's shell and its
	# fitted joinery — link floor, ceiling, sills, headers, mullions; the garden's
	# four wall runs, its ceiling ring and the cupola curb; the grow racks'
	# uprights, crowns and 18 steel trays; the planting kerbs; the benches; the
	# potting bench carcass, worktop and splashback; and the nutrient tanks. The
	# greenery, the grow-light strips, the plastic trays and the soil beds are not
	# in it, for the same reason the living quarters' soft goods are not.
	#
	# The cupola's eight mullions and eight cap segments are not in it either, and
	# that is worth recording because it would otherwise look like a gap: they are
	# `structural` and `shell_light`, both mapped, but they are drawn through
	# `MultiMeshInstance3D` rather than as individual `MeshInstance3D` nodes, and
	# this census walks `MeshInstance3D`. The batching was done under whole-scene
	# instance-budget pressure and it moves 16 mapped surfaces out of this count
	# without changing a pixel.
	_check(
		mapped_surface_count == 2551
		and scale_022_count == 130
		and scale_028_count == 862
		and scale_030_count == 1559,
		"live station binds exactly 2551 surfaces at the frozen 0.22/0.28/0.30 physical scales"
	)
	_check(exact_recipe, "every mapped station surface uses the matched world-triplanar albedo/normal/roughness recipe")
	_check(forbidden_ship_atlas_count == 0, "no live station surface reuses the Arrow or Jovian directional ship atlases")
	_test_instanced_station_family(world, cluster_root)
	_test_cluster_family(cluster_root)


## Instanced station structure, which the surface walk above cannot see.
##
## The coverage count walks `MeshInstance3D`, so a `MultiMeshInstance3D` batch
## contributes nothing to it however many copies it draws. Without this check,
## moving a population into a batch would look like the surfaces had left the
## family rather than like they had been instanced — which is exactly what the
## long-cargo pass did to the short cargo line's rail ties and container ribs.
##
## Batches are held to the same recipe and the same frozen physical scales as
## drawn surfaces. They are not added to the frozen count, because a batch is one
## bound material rather than N surfaces and mixing the two would make that count
## mean two different things.
func _test_instanced_station_family(world: Node3D, cluster_root: Node3D) -> void:
	var batches := 0
	var mapped := 0
	var exact := true
	for candidate in world.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := candidate as MultiMeshInstance3D
		if not batch.is_visible_in_tree() or batch.multimesh == null:
			continue
		if cluster_root != null and cluster_root.is_ancestor_of(batch):
			continue
		batches += 1
		var material := batch.material_override as StandardMaterial3D
		if material == null or _texture_path(material.albedo_texture) != ALBEDO_PATH:
			continue
		mapped += 1
		exact = (
			exact
			and material.normal_enabled
			and _texture_path(material.normal_texture) == NORMAL_PATH
			and is_equal_approx(material.normal_scale, 1.0)
			and _texture_path(material.roughness_texture) == ROUGHNESS_PATH
			and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
			and material.uv1_triplanar
			and material.uv1_world_triplanar
			and material.texture_repeat
			and (
				material.uv1_scale.is_equal_approx(Vector3.ONE * 0.22)
				or material.uv1_scale.is_equal_approx(Vector3.ONE * 0.28)
				or material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
			)
		)
	print("LIVE_STATION_INSTANCED_FAMILY: batches=", batches, " mapped=", mapped)
	# Thirteen: twelve across the three cargo lines plus the backdrop's
	# `ParallaxStars`, which is unlit sky and correctly outside the plate family.
	# Of the cargo batches the structural halves — rail ties and container ribs —
	# bind the family; sled wheels are `rubber` and hoist post bands are painted
	# `orange`, and both stay outside it exactly as their drawn equivalents in
	# every other module do.
	# Re-frozen 13 -> 23 total and 6 -> 9 mapped: the Habitat adds ten visual-only
	# stock batches, of which the cupola posts/caps and spare trays use the family.
	_check(batches == 23 and mapped == 9, "instanced station structure is exactly twenty-three batches, nine of them mapped")
	_check(exact, "every mapped instanced batch uses the same recipe and frozen scale as drawn surfaces")


## The other side of the exclusion above. Cinder Reach's manufactured surfaces
## are outside the station's frozen plate sizes on purpose, but they are not
## outside the recipe: same three registered maps, same red-channel roughness,
## same world triplanar, same `normal_scale`. Only the physical scale differs,
## and it is required to be coarser than the station's largest plate rather than
## merely different, so "not 0.22" cannot quietly become "anything".
func _test_cluster_family(cluster_root: Node) -> void:
	_check(cluster_root != null, "the nearby sector cluster is present in the live world")
	if cluster_root == null:
		return
	var mapped := 0
	var exact := true
	var coarser_than_station := true
	for candidate in cluster_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material == null or _texture_path(material.albedo_texture) != ALBEDO_PATH:
				continue
			mapped += 1
			exact = (
				exact
				and material.normal_enabled
				and _texture_path(material.normal_texture) == NORMAL_PATH
				and is_equal_approx(material.normal_scale, 1.0)
				and _texture_path(material.roughness_texture) == ROUGHNESS_PATH
				and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
				and material.uv1_triplanar
				and material.uv1_world_triplanar
				and material.texture_repeat
			)
			if material.uv1_scale.x >= 0.22:
				coarser_than_station = false
	_check(mapped >= 40, "the cluster's manufactured surfaces bind the registered panel maps (%d)" % mapped)
	_check(exact, "every mapped cluster surface uses the same recipe and the same 1.0 relief depth")
	_check(
		coarser_than_station,
		"every cluster plate is physically larger than the station's largest, as its structures are"
	)


func _test_four_ship_material_identity(game: GameFlow) -> void:
	var ship_specs := {
		"ArrowReconShip": "res://assets/materials/arrow-hull-albedo-v1.png",
		"JovianLightFreighter": "res://assets/materials/jovian-hull-albedo-v1.png",
		"TorrentInterceptor": TORRENT_HULL_PATH,
		"ZenithInterceptor": TORRENT_HULL_PATH,
	}
	for ship_name: String in ship_specs:
		var ship := game.get_node_or_null(NodePath(ship_name)) as Node3D
		var expected_path := str(ship_specs[ship_name])
		var expected_surface_count := 0
		var station_surface_count := 0
		if ship != null:
			for candidate in ship.find_children("*", "MeshInstance3D", true, false):
				var mesh_instance := candidate as MeshInstance3D
				if mesh_instance.mesh == null:
					continue
				for surface_index in mesh_instance.mesh.get_surface_count():
					var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
					if material == null:
						continue
					var albedo_path := _texture_path(material.albedo_texture)
					expected_surface_count += 1 if albedo_path == expected_path else 0
					station_surface_count += 1 if albedo_path == ALBEDO_PATH else 0
		_check(
			ship != null and expected_surface_count > 0 and station_surface_count == 0,
			"%s retains its registered ship material identity and never binds the station tile" % ship_name
		)
	_test_torrent_zenith_uv0_tangent_handedness(game)


func _test_torrent_zenith_uv0_tangent_handedness(game: GameFlow) -> void:
	var mapped_surface_count := 0
	var positive_tangent_vertices := 0
	var negative_tangent_vertices := 0
	var complete_arrays := true
	for ship_name in ["TorrentInterceptor", "ZenithInterceptor"]:
		var ship := game.get_node_or_null(NodePath(ship_name)) as Node3D
		if ship == null:
			complete_arrays = false
			continue
		for candidate in ship.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface_index in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
				if material == null or _texture_path(material.albedo_texture) != TORRENT_HULL_PATH:
					continue
				mapped_surface_count += 1
				complete_arrays = complete_arrays and not material.uv1_triplanar
				var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
				var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
				var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
				complete_arrays = (
					complete_arrays
					and not vertices.is_empty()
					and uvs.size() == vertices.size()
					and tangents.size() == vertices.size() * 4
				)
				for vertex_index in vertices.size():
					var tangent_w := tangents[vertex_index * 4 + 3]
					complete_arrays = complete_arrays and is_equal_approx(absf(tangent_w), 1.0)
					positive_tangent_vertices += 1 if tangent_w > 0.0 else 0
					negative_tangent_vertices += 1 if tangent_w < 0.0 else 0
	_check(
		mapped_surface_count == 9
		and complete_arrays
		and positive_tangent_vertices > 8000
		and negative_tangent_vertices > 29000,
		"Torrent/Zenith keep explicit UV0 and valid ±1 tangent handedness across mirrored authored islands"
	)


func _test_live_central_deck_uv0(world: ShipyardWorld) -> void:
	var presentation := world.get_central_berth_hero_presentation()
	var deck_root := presentation.get_semantic_root(&"deck_panels") if presentation != null else null
	var mesh_instance: MeshInstance3D
	if deck_root != null:
		for candidate in deck_root.find_children("*", "MeshInstance3D", true, false):
			if StringName(candidate.get_meta("central_berth_material_role", &"")) == &"DeckComposite":
				mesh_instance = candidate as MeshInstance3D
				break
	_check(mesh_instance != null, "live imported CentralBerth DeckComposite mesh is present")
	if mesh_instance == null:
		return
	var anisotropy_values: Array[float] = []
	var density_values: Array[float] = []
	var degenerate_count := 0
	var canonical_axis_count := 0
	for surface_index in mesh_instance.mesh.get_surface_count():
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		for triangle_index in indices.size() / 3:
			var i0 := indices[triangle_index * 3]
			var i1 := indices[triangle_index * 3 + 1]
			var i2 := indices[triangle_index * 3 + 2]
			var normal := (normals[i0] + normals[i1] + normals[i2]).normalized()
			if normal.y < 0.9:
				continue
			var duv1 := uvs[i1] - uvs[i0]
			var duv2 := uvs[i2] - uvs[i0]
			var uv_determinant := duv1.cross(duv2)
			if absf(uv_determinant) <= 0.000001:
				degenerate_count += 1
				continue
			var p1 := Vector2(vertices[i1].x - vertices[i0].x, vertices[i1].z - vertices[i0].z)
			var p2 := Vector2(vertices[i2].x - vertices[i0].x, vertices[i2].z - vertices[i0].z)
			var dp_du := (p1 * duv2.y - p2 * duv1.y) / uv_determinant
			var dp_dv := (-p1 * duv2.x + p2 * duv1.x) / uv_determinant
			var gram_a := dp_du.dot(dp_du)
			var gram_b := dp_du.dot(dp_dv)
			var gram_c := dp_dv.dot(dp_dv)
			var discriminant := sqrt(maxf((gram_a - gram_c) * (gram_a - gram_c) + 4.0 * gram_b * gram_b, 0.0))
			var lambda_max := maxf((gram_a + gram_c + discriminant) * 0.5, 0.0)
			var lambda_min := maxf((gram_a + gram_c - discriminant) * 0.5, 0.0)
			if lambda_min <= 0.000001:
				degenerate_count += 1
				continue
			anisotropy_values.append(sqrt(lambda_max / lambda_min))
			var jacobian_determinant := dp_du.cross(dp_dv)
			density_values.append(sqrt(absf(jacobian_determinant)))
			if (
				jacobian_determinant < 0.0
				and dp_du.normalized().dot(Vector2.RIGHT) >= 0.99
				and dp_dv.normalized().dot(Vector2(0.0, -1.0)) >= 0.99
			):
				canonical_axis_count += 1
	anisotropy_values.sort()
	density_values.sort()
	var sample_count := anisotropy_values.size()
	var median_density := density_values[sample_count / 2] if sample_count > 0 else 0.0
	var maximum_density_deviation := 99.0
	if sample_count > 0 and median_density > 0.0:
		maximum_density_deviation = 0.0
		for density in density_values:
			maximum_density_deviation = maxf(maximum_density_deviation, absf(density - median_density) / median_density)
	var p95_anisotropy := anisotropy_values[mini(int(sample_count * 0.95), sample_count - 1)] if sample_count > 0 else 99.0
	var maximum_anisotropy := anisotropy_values[-1] if sample_count > 0 else 99.0
	_check(
		sample_count == 190
		and degenerate_count == 0
		and maximum_anisotropy <= 2.0
		and p95_anisotropy <= 1.25
		and maximum_density_deviation <= 0.25,
		"live imported CentralBerth top UV0 has uniform singular-value density with no degenerates"
	)
	_check(
		canonical_axis_count == sample_count,
		"all live CentralBerth top triangles use canonical non-mirrored +U→+X, +V→−Z axes"
	)


func _texture_path(texture: Texture2D) -> String:
	return texture.resource_path if texture != null else ""


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_TRIPLANAR_MATERIAL_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("STATION_TRIPLANAR_MATERIAL_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
