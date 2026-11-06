# Development roadmap

**Playable alpha; the full game is unfinished.** Ten of the promised 17 craft
now exist in Main, including Titan's minimum playable pilot loop. This count
is implementation, not full craft qualification. The seven remaining craft have
owner-approved modern design baselines. All 36 original parent outcomes and ten
phase exit gates remain open. There is no evidence-backed completion percentage
or finish date.

**A roadmap heading is not a work assignment.** Select only a bounded child
with a filled [task card](#task-card-required-before-starting). Its result must
be observable, its pass condition fixed before work starts, and its dependencies
actually satisfied. Missing details mean blocked work, not permission to explore
indefinitely. A completed specification does not count as a completed feature.

Latest playable checkpoint: **3bd0c06** — [Windows ZIP](builds/windows/MuddsShipyards-3bd0c06-checkpoint.zip)
([notes](builds/windows/MuddsShipyards-3bd0c06-notes.txt)) and
[Linux archive](builds/linux/MuddsShipyards-3bd0c06-linux-x86_64.tar.gz).
Titan's bay now contains its usable candidate: walk through the physical stern
hatch/ramp to the helm, start, launch, fly, land at its own berth, shut down and
walk out. Both physical passenger chairs support local sit/stand/reseat. Four inert parcels
now load, fly home and return through physical controls with conserved cold custody.
The pilot centre cannon delivers the approved70-damage defensive shot. Localized
component damage now affects flight/fire/aim and clears through landed service.
Destroyed Titan now returns through normal recovery with conserved cargo.
The original nine craft remain available. Paired exports, three strict
startups, the actual packaged-content full pilot loop and all nine package-audit
predicates pass. Native Windows/GPU/device/human and full craft gates remain open.
Vortex standalone hull/pilot content is included, with [preview](builds/windows/MuddsShipyards-0c2f322-vortex-preview.png); it is not registered in Main. Paradox standalone hull/pilot and continuous physical access are included, with [preview](builds/windows/MuddsShipyards-2898b63-paradox-preview.png); it is not registered in Main. Katana standalone hull/pilot content is included, with [preview](builds/windows/MuddsShipyards-b0f97ba-katana-preview.png); it is not registered in Main. Predator standalone hull/pilot, continuous landed physical access and own reachable home berth infrastructure are included, with [preview](builds/windows/MuddsShipyards-3bd0c06-predator-berth-preview.png); it is not registered in Main. Earlier accepted changes remain included in their recorded scopes.

## Current work and next selection

### Selected: Predator ordinary Main pilot loop — build card4

Goal / contract: approved Predator card4 in docs/design/PREDATOR_IMPLEMENTATION_PROPOSAL.md. Add the eleventh usable production craft: actual normal-spawn Main Player walks accepted station/spur/ramp/aisle, claims exact physical helm, starts/launches/flies, receives actual UNARMED feedback, returns to strict own home/OFFLINE, stands inside supported cabin, walks out, reboards and completes second usable sortie/home/exit. Correct active identity and unchanged oldfleet remain. This is first pilot checkpoint, not detention/crew/network/fullcraft or wholeMain-reentry qualification.
Candidate / start: clean1fabe63886a1f9a5650ce911812e6820a9b3cc4e, accepted foundation53201/accessb803/berth3bd. Original selection/mapping starts11:07:00UTC2026-11-06. Same actual MainPlayer normalspawn and actual registered craft; no fixture ship, actor pose/velocity/state writes, direct seatclaims, custom flight command sources, clock/transition overrides or staged outcomes. Only normal Input for positive route; existing production boarding/disembarking animation and collision changes are allowed. Four old parked attempts remain closed; no oldrestart/remote/member is retried.
Owner / files: one high implementer owns scripts/ships/predator_detention_transport.gd, new production scene scenes/ships/predator_detention_transport_pilot.tscn, scenes/main.tscn, narrow hooks in scripts/game/game_flow.gd, scripts/ui/hud.gd (UNARMED readiness only), new tests/game_flow_predator_integration_test.gd/UID; necessary legitimate roster/occupied-state updates in tests/game_flow_titan_integration_test.gd,titan_transport_berth_test.gd,predator_detention_transport_berth_test.gd,game_flow_fleet_expansion_physical_switching_test.gd only. Existing base-scene foundation/access fixtures retain complete original cases and source files unless missing-entry-marker assertion is minimally added. No resource/tuning/hull/access-trajectory/berthgeometry/FleetRoleRegistry-policy/network/role/weapon-resource/Player edits. Independent high reviewer covers shared authority/lifecycle/identity/fire guards and production fitout; root owns release helpers/gates/docs/merge/push/archive/cleanup.
Production composition: reusable accepted standalone base remains unchanged in geometry; a real pilot-fitout PackedScene extends it and is the prefab Main uses, with one actual ShipBoardingArea at the supported helm approach and physical pilot furniture at approved helm, outside clear aisle. This is authored production composition, no testing-mode flag. Main instance unique predator_provisional/homepredator_home_berth at exactroot(39,-.02,-30), one current occupied lease/settings/audio/registration, 11flyables/11physicalberths/9stationmodules/57markers. Existing six FleetRoleRegistry policy contracts stay unchanged; actual flyable registry/console derives Mainships and already supports11rows. Preserve all14 combined definition profiles/16fields/provenance/unarmed baseline; no production weapon source ID, cargo, guard/detainee/cell or movingframe.
Candidate / shared seams: allocate previously missing _boarding_entry_marker exactly(1,1,-5.5), retain anchor(0,1.45,-5.5), eye(0,3.21,-5.75), DockingReceiver(0,2.5,1.5), set supported inside stand/exit(1,1,-5.5). Actual main pilot furniture/collider/visual agree and leave aisle x.2..1.8/y1..3.6 clear; newMainroute uses actualcapsulecentre x1. No through-wall/proximity-fallback boarding: candidate predicate requires real Player inside supported helm approach, open/deployed landed/OFFLINE/apron and fullnormalbody; GameFlow checks it during discovery AND before reserving/boarding. Existing ShipBoardingArea/Player APIs are sole seat transition/reservation. Can mark this physically reached landed approach as interior boarding without MovingInteriorFrame; normal generation fencing and seated checks, coordinator seals hatch, exact real3.8s wake. Do not invent an authority/frame or expose free-standing flight.
Landed exit: Predator-only GameFlow branch requires exact current pilot, supported landed/OFFLINE/noactive landing, current owned strict berth and clear supported inside stand. Normal Player.begin_disembark(actualstand,normalduration,ship), same transitiongeneration/currentPlayer/currentShip checks, normal camera/control/body/audio/HUD release, reservation retire once; failure restores seatedauthority atomically. Keep outer hatch CLOSED until actual on-foot Player walks stern and operates real control. Do not call _leave_seat_into_cabin (requiresframe/grantsmovingoccupancy), do not animate seat→stern or set actor pose. Airborne/OFFLINE and active-engine exit refuse; held/duplicate exit or stale transaction must not duplicate body/claim. Door/engine safety retained. Full walking body restored on completednormaltransition; pending deferred restoration remains part of transition, not skipped walking evidence.
Unarmed/UI: leave Predator absent PLAYER_SOURCE_IDS, still damageable under existing lifecycle owner. Explicit empty weapon profiles/direct GameFlow projectile callback refusal for Predator; no fallback pulse/travelling bolt, damage, projectile, heat or weapon cooldown from FIRE. Existing candidate inert direct/held methods/muzzles absent unchanged. HUD active ship/role/cockpit and readiness show candidate/Detention transport/UNARMED through actual bindings. Add only unarmed→UNARMED readiness mapping; other statuses/ships unchanged. No invulnerability/enemy/physics retuning to pass flight.
Exact positive cases: begin normal shift, unique actualMainPredator with ownoccupiedlease/all old10poses+claims unchanged; same actualPlayer follows full accepted berth ROUTE (spawn→8,11→8,13.5→35,13.5→35,15.5→39,15.5→39,8.5→39,7→39,-17→39,-17.9→42.2,-17.9→42.2,-21.2). Normal process-phase Interact/aim discovers actual reachable stern hatch atlocal(3.2,0,8.8); wait complete opening outside sweep, walk viaapronlocalz13/alignx1 continuously up ramp11→9→7/aisle6→0→-5.5, actual Interact atstand reserves/normalboards realpilot/camera/claim andseals. No direct authority calls replace positive ordinary actions.
Flight/home/reuse TWICE: ordinary move_forward starts inherited3.8s clock, edge count227..229physics ticks fromSTARTING→ONLINE, actual5mdeparture releasesownlease. Same existing Titan physical input controller/limits: up to500ticksdeparture, up to1800ticks tohome-localtarget(0,10,-31.2), finalwithin2m of(0,10,-30), -z>=30,speed<=.5 and wholehull clear; normalpitch/thrust/brake Input only, no pose/velocity/clock override. Actual FIRE gives UNARMED/nooutgoingevent/damage/source/profile; active exit refuses; brake/neutral95ticks reachesairborneOFFLINE, actual Interact refusesairborne exit and retains exact pilot/body/camera/claim. Existing normal flight input restarts3.8 before landing ifrequired; existing capture validates own berth, normal landing_assist Input reachesSHUT_DOWN within600ticks, exact ownroot/basis<=.05/velocity<=.05/currentstrictoccupiedlease/fullclosedhull fit. Normal neutral95ticks reachesOFFLINE. Interact normalstandat(1,1,-5.5), body/claim/audio/camera restored, outerhatchstillclosed; walk realaisle/ramp tosterncontrol, operate realhatch andwalk ontoapron13, seal outside sweep. Physically walkback/reopen/fullaisle/reboard and repeat complete flight/home/OFFLINE/stand/walkout/seal. Finish actualPauseTab/Exit to desktop with normal clean Quit. Old10poses/leases/sourceIDs/control settings remain, actualconsole roster includes11/uniqueidentities; no secondPrefab/duplicatebody/stale helm/hatch states.
Walking/negative proof: independent observer runs afteractualPlayer eachcompleted walkingphysics tick, completed_motion.frame=current and adjacentIDs; support/head/realcapsuleclearance/continuity<.2, originalmask/layer/gravity/capsule unchanged. Queryskinonly .005radius/.01height permitted; normal boarding/seated/disembark temporarycollision changes allowed and observed as transitions, restorebeforewalking. No skippedphysics due slowprocessframes, no actor staging afterspawn. Retain exact berthroutetolerance.035/900ticks/12braking; localaisle endpoints.02 and400tickperleg fromacceptedaccess; process-phaseInput edges. Negative outsidehelm/throughwall, duplicate/foreign/stale reservation using existingAPI only, open/movinglaunch, unsupported/active/airborneexit, fire/directgenericfire refuse atomically without replacing positive gameplay. Camera/seat/fullactualproductionfitoutcapsuleclearance checked.
Existing-test adaptation contract: default standalone foundation/access remain original base scope and no boarding grant; production Main journey is authoritative for actual pilot-fitout prefab. Existing Predatorberth test now uses real registered MainPredator/occupiedlease, removes additional stagedduplicate and keeps full original geometry/sweeps/camera/normalspawnroute/control/return/old10snapshots. Real occupied lease gets idempotency/refusal checks; existing empty-ledgerreserve/occupy/release/reuse cases run against independent same-config ShipBerth fixture (unique testID, cleaned beforewalking), and actual departure/home/reuse is proved twice by newordinary Mainjourney. Never release/reacquire productionlease behind GameFlow. TitanfullMain300/Titanberth240 and physicalswitching300 change only legitimate livecount10→11 andretain all originalcases/routes/limits/inputs (old fixture-specific9counts untouched). No MainRestartShift/re-entry claim; fullcraft/role/recovery/network gates remain later work.
Frozen source commands / scope: serial exactcleancommit/source/cache/head/worktreeguards, each exit0/one marker/raw0. Ninefocusedcases: new tests/game_flow_predator_integration_test.gd600s markerGAME_FLOW_PREDATOR_INTEGRATION_TEST_PASS (ALONE); accepted defaultPredatorfoundation90 markerPREDATOR_DETENTION_TRANSPORT_TEST_OK; accepted accessidentity180 and --transformed180 markerPREDATOR_DETENTION_TRANSPORT_ACCESS_TEST_OK; adaptedfullPredatorberth240 markerPREDATOR_DETENTION_TRANSPORT_BERTH_TEST_PASS; consolidatedship_definition_berth120 markerSHIP_DEFINITION_BERTH_TEST_OK; fullstation_route_registry_integration180 markerSTATION_ROUTE_REGISTRY_INTEGRATION_TEST_OK; fullTitanberth240 markerTITAN_TRANSPORT_BERTH_TEST_PASS; fullgame_flow_fleet_expansion_physical_switching300 marker^PASS game_flow_fleet_expansion_physical_switching_test. CompleteunchangedTitanordinaryMain300ALONE separately (livecount11 only) markerGAME_FLOW_TITAN_INTEGRATION_TEST_PASS, full original cargo/cannon/damage/standing/home/cleanQuit intact.
Package / delivery: same full newMain600ALONE and fullTitan300ALONE againstactualWindowsPCK from blank sourceisolateddirs, exactsamecommittedcases/limits; only same-commit route/oldtransform literals inlined plusrawsourceisolation guards. ActualPCK also repeats foundation90/bothaccess180/fulloccupiedberth240. Three source images production-fitout/berth-ready/cockpit-eye actualproductionprefab, stagedworld/ambient/sun/worldlocal-lightsdisabled as priorcapturedprofile, original180s eachcapturecall/no targetGPU/human/productionlighting qualification. Fresh cleancommit safe pairedexports/startup3 exit0/oneSTARTUP_MENU_READY_OK/raw0, completeWin/Linuxmaps/UIDs andexistingpackageaudit9; eightcheckpointartifacts EXE/ZIP/notes/pilotpreview plusLinuxcompanion inrepobuilds, noDownloads. EveryGodotDummy/headlessorprivateXvfbGLES explicitx11, independentsuite_process abort/reap/inputrelease. Allrequiredownersfinishbeforemerge/push/archive/branch/worktree/scratchcleanup.
Budget / stop: original11:07:00→absolute12:22:00UTC2026-11-06,75minutes ALL-IN (mapping/reading included) forcross-componentpilot/lifecycleandfulltwo-sortieproof. FreezeTWOsubstantiveproductioncorrections; routinecompiler/caller/assertioncorrections retaineveryoriginalcase/threshold/timeouts/deadline. Firstunexpectedfailure retainsoperands/stopsdependents, require demonstratedcause/cumulativecost decisionbeforefix; exhaustion/deadline/contractconflict parksoriginalcard, no renamedretry/subsetpass/silentfieldrevision/automaticparkedreopening. No unrelated shared framework/role/AI work. CloseNOT_RUN: expected11/17Maincraft/11berths, incompletePredatordetention/fullcraft/nativehardware/human/network/recovery/Main-reentry retained.

| Case | Initial state and action | Expected result | Actual result and proof |
| --- | --- | --- | --- |
| Real Main pilot fitout | Normalspawn/registeredunique11thcraft/physicalroute/hatch/helmInteract | Real seat/body/camera/reservation, no throughwall boarding, correctidentity/UNARMED | NOT_RUN |
| Two complete sorties | Normal3.8s start/lift/flight/fire-refusal/strictownhome/OFFLINE/stand/walkout/reboard/repeat | Actuallease release/reacquire, exactdock, supportedinsideexit/bodyrestoration and fullreuse, no actorsnapshotstaging | NOT_RUN |
| Unsafe/authority | Active/airborne/open/moving/foreign/duplicate/stale/fire attempts | Atomicrefusals/currentbody/claim/camera/healthsourcepreserved, no extraauthority | NOT_RUN |
| Fleet/regressions | Complete9focused/Titanordinary andold10snapshots | Alloriginalroutes/limits/sourceguardretained, legitimatecount11, no oldcraftretuning/claimloss | NOT_RUN |
| Current package/closure | ActualPCKnewMain/Titan/berth/foundation/accessI+T, pairedstartup3/maps/audit9/3views/eightartifacts | Exactcases currentcleanC, merged/pushed/verifiedarchive/exactref/worktree/processcleanup before12:22 | NOT_RUN |

### Predator own reachable home berth — build card3 DONE (infrastructure scope)

Source **3bd0c0619**, merged/pushed via **c93cc9e05**, adds the unique compatible
`predator_home_berth`, signed13x26m deck and2.8m supported spur at world
(39,-.02,-30),yaw0. The independent StarboardBerthNode branch changes no
Titan/Paradox connector rails. The same actual normal-spawn Main Player walks the
cabinet-avoiding existing route to the new spur/deck and normal-range fixture hatch,
opens/seals through the existing API, and physically returns. Every completed
movement tick retains support, capsule/head clearance and continuity; no actor staging.
The candidate is initially placed solely as a geometry/control fixture, without
Main registration or production craft claim. Production infrastructure is unoccupied.

Exact shared strict-volume centre(0,2.5,1.5),half(5.5,4,11.5) contains the entire
closed/deployed hull. DefaultZERO preserves every legacy berth; invalid centres
fail closed and transformed point/full-hull containment is covered. Parked root,
assist capture defaults and departure semantics remain unchanged. Complete actual
hull/access shapes, full5m departure/inverse landing sweeps, forward approach lane,
stern headroom and actual chase-camera clearance pass against live Main neighbours.
Wrong-tag/foreign/occupied/duplicate/stale leases refuse atomically; legitimate
reserve/occupy/release/reuse passes. All old10 berth poses and leases are conserved.
Graph now has9 modules/endpoints/slots and57 route markers, new supported edge1.5m.

Seven focused source checks pass: berth240s, unchanged foundation90s, complete
access identity/transformed180s each, definitions120s, registry180s and full
Titan berth240s with legitimate roster changes only. Complete ordinary Titan Main
source and actual Windows PCK loops pass separately ALONE at300s with clean Quit.
Actual Windows PCK repeats exact new berth240s (only same-commit old-transform
constant inlining and isolation guard), unchanged foundation90s and both full
access180s profiles using the same guard-only access adapter. Every case has
exit0/exactlyone marker/raw0 and source/cache/head/worktree guards.
Three private Dummy-audio views berth-approach/berth-closed/berth-open are inspected.
Fresh paired checkpoint **3bd0c06** passes strict startup3, complete equal
Windows/Linux maps and all nine existing package predicates. Eight artifacts include
EXE/ZIP/notes/berth preview and paired Linux executable/archive/export result/notes.

**Main remains10/17 flyable craft; physical berths are now11. Predator is not
registered/selectable in Main.** Card3 own reachable home infrastructure is delivered;
card4 Main integration is pending. Pilot claims, moving cabin, guard/detainee/cell
and detention, damage/service/recovery/save/network and full journeys remain open.
No pilot/role/detention/three-player capacity credit is granted. Native Windows/GPU/
device/audio/readability/human/full-release gates remain NOT_RUN/unqualified.
All earlier parked attempts remain closed with original failures and allowances.
Original10:13:09→11:13:09UTC all-in budget, clean base2320bb7e9 and TWO-production-
repair limit (0 used), source bundle, all7source/4PCK raw
checks and9statuses, views and package records are retained in verified
`/srv/mudds-work/predator-berth-20261106/records.tar.gz`; adjacent closeout records
publication and owned process/ref/worktree cleanup. No next assignment selected.

### Predator continuous stern access — build card2 DONE (standalone landed scope)

Source **b803cd377**, merged/pushed via **d8620b1d7**, adds continuous physical stern
access to accepted foundation53201f8e09dc8b94ce3f22b776c7e30906c57267. The same actual
Player walks apron→reachable physical stern control→real Interact→deployed ramp
and bridge→full starboard aisle→exact helm stand(1,1,-5.5), returns and seals,
twice at identity and elevated35degree yaw. Every completed Player walking/motion
physics tick is observed for support, actual capsule/head clearance and continuity.
Closed crossing and unsupported/moving/active/airborne exterior opening refuse;
open or moving access blocks manual/automatic start and throttle. Original
closed9x16x5m hull/pods/secure-wall/window, floor1, aisle and anchors are retained;
ramp x[-.2,2.2],z7..11,surfacey1→0 stays within deployedz11 through complete motion.
Actual visible/collision geometry agrees without overlapping interiors.

Five focused source checks cover full default Predator foundation, full access
identity and transformed cases, definition/berth and boarding-area. Foundation
retains all16fields/all14profiles/registered6, inherited3.8s startup and UNARMED.
Full ordinary Titan Main source and actual Windows PCK loops pass separately ALONE
with original300s limits and clean Quit. The source-isolated actual Windows PCK
also passes unchanged foundation90s and BOTH full access180s profiles, using one
exact committed external access test plus isolation guard only. Three fixed views
closed-aft, open-stern and cockpit-eye are inspected privately with Dummy audio.
Fresh paired checkpoint **b803cd3** passes strict startup3 and all nine package
predicates with complete matching Win/Linux payload maps. Eight published artifacts
include EXE/ZIP/notes/access preview and paired Linux executable/archive/export
result/notes. VM/Linux-PCK evidence does not qualify native Windows/GPU performance.

**Predator remains standalone, not registered/selectable in Main; Main10/17 and
10physical berths are unchanged.** Continuous landed physical access is delivered.
Card3 own home berth, pilot seat claims, moving cabin, guard/detainee/cell/detention,
production integration, damage/service/recovery/save/network and full journeys
remain open. No seated claim or three-player capacity is established.
Native Windows/GPU/device/audio/readability/human/full-release gates remain open.
Katana access bf5834b22, Paradox berth9d124e5cd, Vortex access1416c9ece and Titan
remote867565997 remain parked/unmerged with their original failures and allowances.
Original09:37:37→10:37:37UTC all-in budget, clean base5684b3ef4, frozen card and
one-production-repair allowance (0 used), source bundle,
raw source/PCK checks/cache guards/views and package records are retained in verified
`/srv/mudds-work/predator-access-20261106/records.tar.gz`; adjacent closeout records
publication and owned process/ref/worktree cleanup. No next assignment is selected.

### Predator standalone hull and pilot — build card1 DONE (foundation scope)

Source **53201f8e0**, merged/pushed via **2140a1a22**, adds the approved original Predator
provisional definition, editable chamfered cabin/twin side pods/port observation
window and separate matched convex collision within the closed9x16x5m envelope.
Cabin floor y1, room/aisle/corridor reservations and pilot anchor(0,1.45,-5.5)
are preserved. All16 approved fields are applied to the actual HeroShip, including
3.8s manual and automatic-demand startup. Actual commands produce flight,
rotation, braking/arrest, neutral OFFLINE/audio retirement and a second usable
start. FIRE/direct-fire paths are unarmed: readable UNARMED, no projectile,
muzzle or charge emitter. This original modern hull is not authenticated history.

Five focused checks cover Predator, unchanged Katana and Paradox foundations,
definition/berth and boarding-area. All14 combined profiles retain14-axis
separation/non-dominance/sibling signatures; registered-six is unchanged.
The full ordinary Titan Main source loop passes serially with clean Quit.
Three fixed source views closed-aft, port-cabin and cockpit-eye were inspected
under isolated display/Dummy audio. Fresh paired checkpoint **53201f8** passes
strict startup3 and all nine package predicates with complete matching payload
maps. Actual Windows PCK under pinned Linux Godot separately passes the exact
committed Predator fixture plus isolation guard and the full ordinary Main loop
from source-isolated directories. Eight published artifacts include the EXE,
Windows ZIP/notes/preview and paired Linux executable/archive/export-result/notes.

**Predator is standalone content and is not registered/selectable in Main.
Main remains10/17 and10 physical berths.** Continuous physical access, own berth,
production integration, guard/detainee roles, consent/cell function, networking,
damage/service/recovery/save and full ordinary craft journeys remain open.
Room geometry and standalone pilot flight do not prove detention or capacity.
Native Windows/GPU/device/audio/readability/human/full-release gates remain open.
All four parked attempts—Katana access bf5834b22, Paradox berth9d124e5cd,
Vortex access1416c9ece and Titan remote867565997—remain archived/unmerged with
original failures and allowances. No retry or next assignment is selected.
Original09:13:23→09:58:23UTC all-in budget, clean base9cba1a85e, frozen card,
source bundle, raw checks/source-cache guards/views and package records are
retained in verified `/srv/mudds-work/predator-foundation-20261106/records.tar.gz`;
adjacent closeout records actual publication and owned process/ref/worktree cleanup.

### Katana physical port access and pilot claim — build card2 PARKED

Goal / contract: approved Katana card2 in docs/design/KATANA_IMPLEMENTATION_PROPOSAL.md. Foundation b0f97baf1 is accepted. Paradox berth, Vortex access and Titan remote remain parked; pending reprioritization is unchanged. This is candidate-only access, not Main integration or a travelling cabin.
Result: the same real Player walks supported apron → port control → ramp/recess → helm approach, claims the single pilot through existing ShipBoardingArea/Player APIs, safely releases to the supported stand pose, walks outside, seals and repeats. Sealed crossing and unsafe launch/access/exit refuse. No jump, through-hull shortcut or free-standing flight/cargo/crew capability.
Candidate / start: clean4936877ea; one initial ship/apron/actualPlayer/command-source placement per process. Identity and elevated35degree-yaw profiles run separately. Initial Player local(-8,0,0), safe control approach(-6.6,0,1.6), return apron(-8,0,0), exact stand/boarding pose(-.9,.6,0). Pilot anchor(0,.55,-1), eye(0,2.31,-1.25) and identity root DockingReceiver unchanged. Complete walk/claim/release/return/seal repeats twice on both profiles.
Owner / files: one high implementer owns only scripts/ships/katana_fighter.gd, scenes/ships/katana_fighter.tscn, existing tests/katana_fighter_journey_test.gd and UID. All16 resource values/provenance/tags fixed. Independent high reviewer covers moving geometry and pilot/exit composition. Root owns docs, gates, release, merge/push/archive/cleanup. No shared HeroShip/GameFlow/Player/registry/world/weapon/cargo/role-framework edits. Existing public APIs suffice; a discovered shared gap stops for concrete scope reconciliation.
Fixed geometry: closed11x12x3.8m, x±5.5,z±6,y0..3.8; deployed x-6..5.5,z±6,y0..5.8. Actual ramp2.2m wide,z±1.1,x-6..-1.5, risingy0..0.6. Opening atx-1.5 at least2x2.3m. Recess x±1.5,z-2..2.5,floor.6, with at least1.2m beside the chair. Retain original tub/blunt nose/aft outriggers. Reachable existing hatch control fits closed bounds and 2.5m reach from safe approach outside the sweep. Visible hull/ramp/canopy/furniture agrees with actual physical shape/poses through inherited motion; all fractions bounded, no hidden unsupported floor/full-room collider/sweep inflation. Measure the whole trajectory and critical fractions before freeze, then observe actual animated poses; fix geometry rather than reach/masks/gravity.
Claim/exit scope: real Player Interact operates discovered/reachable hatch. Only at the physically reached helm approach does a standalone coordinator compose existing ShipBoardingArea.try_reserve(actualPlayer) and Player.begin_boarding(entry,actualAnchor,normalDuration,ship). Existing normal seating animation is allowed; no direct actor pose/velocity/state changes replace it. This fixture composition does not qualify Main. Boarding completion binds the actual command source/piloted state and normal coordinator sealing; only the reserved seated pilot drives. Release requires landed/supported/OFFLINE, normal Input edge and existing Player.begin_disembark(exactStandPose,normalDuration,ship), normal collision/control restoration and reservation retirement. No positive direct door opening replaces on-foot hatch Interact; seated coordinator sealing/release opening are the normal seat handoff. Foreign/duplicate/stale reservations cannot steal. No airborne stand/free cabin. Record actual seated camera/anchor/current claim and every walking tick; legitimate Player-owned boarding/seated/disembark collision changes are allowed, while walking mask/layer/gravity/full capsule restore unchanged. No invented pilot authority owner or test-only success.
Cases: closed real-capsule crossing refusal and return; port Interact open, continuous supported ramp/recess walk to stand pose, real Input pilot claim, sealed2.3s start/neutral OFFLINE, safe normal release, continuous walk out and seal; repeat twice. Every ON_FOOT tick has adjacent completed-Player audit, continuity<.2m, support and actual capsule/head clearance. Query-only contact skin .005radius/.01height is allowed; never change actor shape. Negative foreign/duplicate/stale claim, open/moving start/throttle, unsupported/active opening and airborne exit refuse. After positive cycles, a final real-command airborne/OFFLINE attempt may test no-free-cabin refusal, then cleanup; no pose reset. Same full transformed case. Preserve all16 tuning fields,13 profiles and default foundation behavior.
Proof / commands: /srv/mudds-work/katana-access-20261106/. Extend the SAME journey file: default foundation90s markerKATANA_FIGHTER_JOURNEY_TEST_OK; --access180s markerKATANA_FIGHTER_ACCESS_TEST_OK; --access --transformed180s same access marker. Production preloads only, no excluded-test dependencies. Existing ship_definition_berth120s and ship_boarding_area120s, unchanged complete ordinary Titan Main300s ALONE. Three fixed source views closed/open/actual pilot eye. Actual Windows PCK repeats full foundation and BOTH full access profiles with the same timeouts, plus full ordinary Main300s ALONE, from blank source-isolated directories. Fresh paired safe exports, strictstartup3 each exit0/oneSTARTUP_MENU_READY_OK/raw0, complete Win/Linux maps, existing package audit9 and eight checkpoint artifacts/notes/preview. Every Godot uses Dummy; headless or private Xvfb/GLES explicitx11, independent suite_process abort/reap and released inputs. Clean exact commit/source/cache guards. Native/GPU/device/human/fullcraft/Main/comparative handling/combat/recovery/network stay open.
Budget / stop: original start08:35:14UTC2026-11-06 (mapping/reading included), absolute deadline09:35:14UTC,60minutes ALL-IN including implementation, full source/package checks, fresh build, merge/push/archive and exact-tip branch/worktree/process/scratch cleanup. One substantive production correction. Routine compiler/caller/assertion corrections preserve all original cases/endpoints/thresholds/durations/deadline. First unexpected failure retains operands and stops dependent checks. Exhaustion/deadline/contract conflict parks the original card; no renamed retry, subset acceptance, silent relaxation or automatic parked-work reopening.
Close: PARKED, unmerged source bf5834b2221bfc9f5976b096cf1da3a4075c51ca. The closed retracted ramp intersects the port sill; production repair1/1 was already consumed correcting moving-mesh winding. Source, both raw attempts and exact operands are retained in verified `/srv/mudds-work/katana-access-20261106/records.tar.gz`; adjacent closeout records pushed status, actual elapsed cost and exact-ref/worktree/process cleanup. No runtime merge or new checkpoint. Latest accepted playable remains b0f97ba; Main10/17 and10 physical berths.

First source67dc2d508 failed outward generated normals on PortSill. The sole bf5834 correction reverses only moving-leaf triangle submission; vertices, colliders, motion, timing and acceptance remain unchanged. The full original default foundation rerun then fails actual PortSillCollision/PortRamp0Collision overlap, projected area0.21999645233154m². Sill spans x[-1.6,-1.5], y[.6,1], z[-2,2.5]; closed ramp spans x[-3.75,-1.5], z[-1.1,1.1]. At x=-1.55 its bottom/top are .754222/.793333: point(-1.55,.78,0) lies strictly inside both. Independent review confirms a production defect, not an assertion error. All dependent walking/claim/transformed/Main/render/export/PCK/package checks are NOT_RUN.

Reopening requires explicit owner reprioritization and a newly bounded repair budget, retaining original08:35:14 start/cost, both failures and every original acceptance case. Correct actual closed geometry; do not relax non-overlap or rename/retry automatically. Card2 is unaccepted; dependent Main integration remains gated. Paradox berth, Vortex access and Titan remote remain parked. No next assignment is selected.

| Case | Initial state and action | Expected result | Actual result and proof |
| --- | --- | --- | --- |
| Closed/support/access | Same Player closed refusal/control/Interact/open/continuous ramp+recess walk and return | No closed hull crossing; support and clear actual capsule/head every walking tick, no jump/warp/reach/mask/gravity bypass | NOT_RUN |
| One pilot/reuse | Reached stand pose Interact/exclusive reservation/Player seating, sealed start/idle, safe release, walk out/seal, repeat | Exact anchor/camera/current claim,2.3s clock, pilot-only commands, restored walking body/claim cleanup and second usable claim | NOT_RUN |
| Transformed/unsafe | Same full profile35yaw/elevated; foreign/duplicate/stale, unsupported/active opening, airborne exit | Same ordinary route/claims, atomic refusals, no travelling cabin/extra authority | NOT_RUN |
| Geometry/motion | Actual closed/open/intermediate shape queries, pure trajectory and fixed images | Fixed envelopes/aperture/ramp/recess/aisle, matching bounded motion and clear eye; no hidden floor/full void box | FAIL default foundation: actual closed ramp/sill overlap after sole winding repair. Remaining motion checks NOT_RUN. |
| Regression/package/closure | All named cases/full Main, fresh paired export/actual PCK foundation+both access+Main/startup3/audit9/publish/cleanup | One marker/exit0/raw0/source-cache guards; eight artifacts/notes/preview, merged/pushed/owned cleanup; Main10/17/later cards open | NOT_RUN |


### Katana standalone hull and pilot — build card1 DONE (standalone scope)

Source **b0f97baf1**, merged/pushed via **4b1c19777**, adds the approved original Katana
definition, editable procedural hull/scene and existing HeroShip pilot controller.
Its broad central cockpit pod, blunt squared nose and compact aft outriggers fit
the exact closed11×12×3.8m envelope. Actual convex sections match visible
vertices, face outward, do not overlap and leave the reserved cockpit recess
and eye clear. All16 approved values remain unchanged, including braking64,
landing15 and engine start2.3s. PilotSeatAnchor is exactly(0,.55,-1), cockpit
eye(0,2.31,-1.25), with identity DockingReceiver at the root. Actual command-source
flight completes inherited manual and automatic timed startup, translation,
turning, braking/arrest and normal neutral OFFLINE with engine audio retired,
then a second usable timed start. No runtime pose/velocity/clock override,
access/cargo/specialist/moving-cabin/guest/combat grant or historical-model claim.

Four source checks and unchanged complete ordinary Titan Main pass on the exact
clean commit with source/cache guards and clean Quit. All ten current Main craft
plus accepted standalone Vortex, Paradox and Katana (13 profiles) pass unchanged
14-axis/non-dominance/signature constraints; the registered-six audit is unchanged.
An independently reviewed external adapter asserts exact live Main10, then runs
all original legacy-nine cases/floors/waits unchanged. Vortex, Paradox and Katana
are excluded from Main. This is legacy-nine regression inside ten-craft Main,
not full current-ten/Titan handling qualification. Numeric braking64 establishes
no equal-speed comparative braking/turn/boost/weapon tradeoff qualification;
actual comparative handling remains Katana card6. Three fixed source views were
inspected using private Xvfb/OpenGL ES with Dummy audio.

Fresh paired checkpoint **b0f97ba** passes strict startup3 and all nine existing
package predicates; complete Windows/Linux payload maps match. Actual Windows
packaged content under pinned Linux Godot separately passes the unchanged full
standalone Katana fixture and complete ordinary Titan Main loop from blank
source-isolated directories. Native Windows/GPU/device/audio/human/full-craft
and full-game gates remain open.

**Katana is standalone content, not selectable in Main. Main remains10/17 and
10 physical berths.** The checkpoint includes its runtime scene and companion
preview. Ordinary physical access, berth/Main registration, real emitter damage,
comparative handling, component service, recovery/save and remote pilot journeys
remain later cards. Paradox berth9d124, Vortex access1416 and Titan remote867
remain PARKED/archived/unmerged; their text and exhausted allowances are retained
below. The pending Paradox reprioritization question remains unanswered. No
parked attempt is retried and no next assignment is selected.
Original08:01:12→08:46:12UTC all-in budget, clean based5132eaa1, frozen card,
source bundle, raw checks/source-cache guards/views and package records remain
in verified `/srv/mudds-work/katana-foundation-20261106/records.tar.gz`; adjacent
closeout records actual publication and owned branch/worktree/process cleanup.

### Paradox own reachable home berth — build card3 PARKED

Goal / contract: [approved Paradox card3](docs/design/PARADOX_IMPLEMENTATION_PROPOSAL.md#bounded-implementation-cards--after-owner-approval-only). Foundation/access cards1–2 accepted; Vortex access/Titan remote remain parked. This card adds actual station geometry and docking authority, not Main craft registration.
Result: normal Main Player walks existing station route through Titan connector to a new supported Paradox spur/deck/sign and future stern-control approach; own valid unoccupied paradox_home_berth supports exact modern candidate geometry and compatible conserved lease. Main flyable fleet remains10/17; no candidate spawn/role/combat integration.
Candidate / start: clean c46bac90b. Site source-inspected at root(154,.38,90),yaw−90deg, new floor.38; own local deck x±10,z−18..20 gives20×38m, full ramp tipz18 plus2m apron. New2.8m-wide supported spur at worldx135 fromexistingTitanconnectorz38 toParadoxapronz90; one default-closed Titan connector rail option enabled only inproduction opens its south side atworldx135/z39.52 onto real new support. Preserve all10old berth/craft transforms/leases and existingroutes; no other deck or deferredmarker commandeered.
Owner / files: medium implementer owns new scripts/world/paradox_cruiser_berth.gd, scenes/world/modules/paradox_cruiser_berth.tscn/UID only. Root integrates shared scripts/world/ship_berth.gd, shipyard_world.gd, titan_transport_berth.gd and scenes/world/shipyard_world.tscn; root owns new tests/paradox_cruiser_berth_test.gd, extends existing ship_definition_berth_test.gd, titan_transport_berth_test.gd and station_route_registry_integration_test.gd/UID ifrequired. Independent high reviewer for spatial/layout/shared landing semantics. No Paradox hull/resource/profile/GameFlow/fleet-registry/weapon/role edits.
Dependencies / exact fit: ownShipBerthIDparadox_home_berth, exclusivetagparadox_cruiser, exact parked shiprootmoduleorigin; geometric landing center(0,3,2), halfextents(9,4,17), so permitted volume x±9,y−1..7,z−15..19. Add finite default-zero landing_volume_center to consolidatedShipBerth; only tight containment uses dock*center, while dockplacement/departure/broadassist remainroot-based; defaultzero preserves everyoldberth. Markerat(0,3,2) mustagreeactualAPI. Root authored broadcapturecenter(0,12,−28),half(28,18,42),speed25,tilt65,lift8; broadcapture separatefromtight fit. Preserve Paradox16×28×6stowed/deployedrampz18/all16fields/camera/ordinaryaccess. Unoccupiedownberthisnewworldoutcome; latercard4ownsMaincraftspawn/ordinaryflightlanding.
Cases / proof: /srv/mudds-work/paradox-berth-20261106/, pinnedGodot4.7.1headlessDummy orprivateXvfb/GLES explicitx11, suite_processindependentabort/reap/inputrelease. One full newberthfixture(300s): actualMain normalPlayer noinitialposewrite walks unchangedTitanroute to(135,.38,38) thennewspur(135,.38,50),(135,.38,70),(135,.38,90),apron(139.5,.38,91.9); ordinarylook/move only, everycompletedphysicaltick adjacent/support/capsule/headclear, finalwithin normal2.5reachofactualParadoxcontrol in separate stagedcandidategeometryfixture. Sameactor physically returns tooldconnector. Candidategeometry is installedONCEatownexactdock forfit/collisionqueries, not registeredflyable; distinguishfixturecraft fromproductionfleet. Testwrongtag/occupied/staleleaseatomicrefusal, correctreserve/occupy/release/reuse, root/volume separation/closed+deployed fit/outside-cornerrefusal, livealloldneighbors/chasecamera andcontinuous8mdeparturecasts plusforward/staginglane.
Existing gates: Paradoxfoundation90s, fullaccessidentity180s +transformed180s, extendeddefinition/berth120s, existingTitanberth300s andstationrouteintegration120s (update exact newworldmodule/11berthroster only; oldroute/thresholds/cases preserved), complete unchangedordinaryTitanMain300s ALONE. Threefixedsourceviews newdeck/spur/defaultchase. Freshpairedsafeexports/strictstartup3 each exit0/oneSTARTUP_MENU_READY_OK/raw0; actualWindowsPCK exactnewberthfixture300s +fullordinaryMain300s ALONE, sourceisolatedblankdirs; existingpackageaudit9/completeWinLinuxmaps,8checkpointartifacts/notes/preview. Native/human/fullcraft/release gates stayopen.
Budget / stop: originalstart07:23:29UTC2026-11-06 (mappingincluded); harddeadline08:23:29UTC,60minutesALLIN includingchecks/build/merge/push/archive/exactref/worktree/process/scratchcleanup. One substantiveproductionrepair, routinecompiler/caller/assertionfixesretainalloriginalendpoints/thresholds/durations/deadline. Firstunexpectedfailure retainsoperands/stopsdependentchecks. Exhaustion/deadline/designconflict parksoriginalcard; no renamedretry/subsetacceptance/silentfieldrevision orautomaticparkedworkreopening.
Close: PARKED, unmerged source9d124e5cd; production repair1/1 exhausted. Rawsource/attempts/diagnostics retained in verified `/srv/mudds-work/paradox-berth-20261106/records.tar.gz`; adjacent closeout records originalcost, pushed park status and exactref/worktree/process cleanup. No new checkpoint or runtime merge. Accepted production remains10physical berths/10flyable craft (10/17); latest playable2898b63. Paradox Main card4 is GATED.

Confirmed final failure: the real supported Main Player is at(135.0051,.381211,39.05958), mask7/layer2/gravity_multiplier1, against `/root/Main/ShipyardWorld/TitanTransportBerth/ConnectorSideStarboard`, contact(135.0051,1.62,39.44), normal−Z/depth.000125885; all four forward capsule probes hit the same rail. The productionflag is enabled, but yaw−90 maps local+X toworld+Z: side<0 opens NORTH z36.48, leaving the SOUTH z39.52 rail intact. Its nearface39.44 minus capsule.38 predicts39.06 exactly. This is a production geometry failure, not a missing caller, tolerance or need for a jump.

Earlier1c5baa0's new spur rails crossed the old z38 connector and stoppedx133.0195. The sole63f9 correction shortens both rails toworldz39.6..80 (mesh103), preserving floors/routes/endpoints/masks, and the original crossing then passes. Source9d124 adds only failure operands; productionbytes remain63f9. No further production change is authorized under this exhausted card. Reopen only after explicit owner reprioritization and a newly bounded repair budget, retaining original07:23:29 start/cost/allcases/thresholds/failures, and changing the actual south opening while preserving north safety. Do not rename/retry or start dependent Main integration automatically.

| Case | Initial state and action | Expected result | Actual result and proof |
| --- | --- | --- | --- |
| New own authority/lease | Actual world discovers ownberth, reserve/occupy/release/reuse withcompatiblecandidate; wrongtag/occupied/staletoken | Exactly11physicalberths/10flyablecraft, old10posesunchanged, ownunoccupieduntilfixture; atomicrefusals/no borrowedlease | PARTIAL: own11-candidate-berth/10flyable discovery, old10poses/defaultzero, compatible/wrongtag/occupied/stale/freshlease checks PASS. Final post-return oldlease conservation NOT_RUN because route fails. |
| Root versus volume | Exactdockroot +center(0,3,2),half(9,4,17), closed/openwholecandidatebounds andoutsidecorner | Fullfixedhull/ramp fits tightvolume; outsidecornerrefuses; dock/departure/capture rootunchanged, olddefaultzero contracts pass | PASS in63f9: definition regression plus complete actual closed/deployed fit and outsidecorner refusal; same production in diagnostic9d124. |
| Physical reach/return | ActualnormalMainPlayer spawn→unchangedTitanroute→newspur/deck/controlapproach→oldconnector usingordinarycontrols | Everycompletedtick observed/support/headclear, no warp/jump/reach/mask/gravity bypass; normalreach≥actualdistance; oldroute remainsusable | FAIL: initial1c5baa0 stopsx133.0195 atnewspurrail acrossoldconnector. Sole63f9 repair clearsleg17; leg18 then stopsz39.05958 on actual Titan ConnectorSideStarboard. Fullnewspur/control/return NOT_RUN. |
| Spatial/camera safety | Actualclosed/openconvexshapequeries/casts againstlivedeck/rails/oldships/world,8mlift andforward/staginglane; inspectfixedviews | Onlysupportdeckcontactexcluded, nootherneighborintersection; actualdefaultchasecamera/selfboundaryclear, fullcaptureseparatefromtight | PARTIAL: actualshape8mlift/forward28/vertical4/staging/defaultchase queries PASS; rendered inspection NOT_RUN after route failure. |
| Preserved/package/closure | Literalexistingsuites +fullMain; freshpairedexports/actualPCKnewwholefixture+Main/strictstartup3/audit9 | Allmarkersonce/exit0/raw0/source-cacheguards;8publishedartifacts+notes, merged/pushedandownedcleanup. Main10/17/latercardsopen | Definition suite PASS; fullnewberthfixture FAIL. Subsequentfoundation/accessI/T/Titanberth/route/fullMain/render/export/startups/PCK/audit NOT_RUN. No failed runtime merged or checkpoint published; verified archive and cleanup recorded in closeout. |


### Paradox continuous physical access — build card2 DONE (standalone scope)

Source **2898b63d1**, merged/pushed via **0cf71a5d4**, adds the approved stern hatch,
matched moving ramp, supported vestibule and bounded MovingInteriorFrame.
The same actual Player walks the complete apron→reachable existing hatch
control→ramp→bridge→helm approach→apron route, seals and repeats. Closed
crossing refuses. Every sampled walk retains actual support and capsule/head
clearance with unchanged masks/gravity/reach, and real automatic frame
admission/retirement follows the supported cabin boundary. The complete case
also passes in a separate elevated35degree-yaw fixture. No positive-route
teleport, jump, direct door call, seat warp or controller-state forcing.

Actual intermediate ramp/door mesh and collision transforms stay within the
approved16×28×6m stowed and ramp-only z18 extended bounds. Open/moving access
rejects start/throttle, unsupported/airborne/active opening refuses, and sealed
3.2s timed startup remains usable. All16 numeric definition values/provenance,
12-profile separation/non-dominance/signatures and existing pilot controller
remain unchanged. Shared runtime/Main/role owners are untouched.

Five exact clean-source focused suites and unchanged complete ordinary Titan
Main pass, with clean source/cache guards and normal Quit. Three source views
(closed/open/actual cockpit) were inspected under privateXvfb/GLES/Dummy audio.
Actual WindowsPCK under pinned Linux Godot independently passes the full
foundation and BOTH complete access cases plus full ordinaryMain from blank
source-isolated directories. Paired checkpoint **2898b63**, strictstartup3,
complete matching Win/Linux payload maps and existing package audit9 pass.
EXE/ZIP/notes/preview and companion Linux files are in builds; notes retain
standalone limits and actual validation. Native Windows/GPU/device/human and
fullcraft/release gates remain open/NOT_RUN.

**Paradox remains standalone/unselectable in Main; fleet10/17.** Its own home
berth, Main integration, crew chairs, weapons, service/recovery/save and network
journeys remain later cards. Vortex access and Titan remote remain PARKED and
unmerged; this card does not reopen/reset either. No new task selected here.
Original06:37:57→07:37:57UTC all-in budget and frozen cases/source/raw runs/
review/captures/package records are preserved in verified
`/srv/mudds-work/paradox-access-20261106/records.tar.gz`; adjacent closeout
records actual publication and owned branch/worktree/process/scratch cleanup.

### Paradox standalone hull and pilot — build card1 DONE (standalone scope)

Source **f3c20bf10**, merged/pushed via **624761483**, adds the approved original
Paradox definition, editable procedural scene/hull and existing HeroShip pilot
controller. Its faceted long foredeck, raised aft bridge, twin compact stern
engine blocks and inset stern well fit the exact16×28×6m envelope;21
actual convex sections match visible vertices, face outward, do not overlap
and leave the reserved bridge/cockpit eye clear. All16 approved values remain
unchanged, including landing speed11 and engine start3.2s. The pilot anchor is
exactly(0,1.65,-3.8). Actual command-source flight completes inherited manual
and automatic timed startup, forward translation/turning, braking/arrest and
normal idle OFFLINE with engine audio retired. No runtime pose/velocity/clock
override, cargo/crew/combat grant or historical-model claim.

Four source checks and unchanged complete ordinary Titan Main pass on the exact
clean commit with source/cache guards and clean Quit. All ten current craft
plus accepted standalone Vortex and Paradox (12 profiles) pass unchanged
14-axis/non-dominance/signature constraints. The registered-six audit remains
unchanged. An independently reviewed external adapter asserts exact live Main10
then runs all original legacy-nine cases/floors/waits unchanged; neither Vortex
nor Paradox is in Main. This is legacy-nine regression inside ten-craft Main,
not full current-ten/Titan handling qualification. Three fixed source views
were inspected using private Xvfb/OpenGL ES/Dummy audio.

Fresh paired checkpoint **f3c20bf** passes strict startup3 and all nine existing
package predicates; Windows/Linux payload maps match. Actual Windows packaged
content under pinned Linux Godot separately passes the unchanged standalone
Paradox fixture and full ordinary Titan Main loop from source-isolated blank
directories. Native Windows/GPU/device/human/full-craft gates remain open.

**Paradox is standalone content, not selectable in Main. Main remains10/17.**
The checkpoint includes its runtime scene and a companion preview; continuous
physical access, berth/Main registration, gunner/passenger roles, both weapons,
damage/service/recovery/save and network journeys remain later cards. Vortex
access and Titan remote attempts remain PARKED/archived/unmerged; this delivery
neither retries nor resets either allowance. No new work is selected here.
Original06:13:39→06:58:39UTC all-in budget, clean base53c1ed7f2, frozen card,
source bundle, raw checks/images and package records are retained in verified
`/srv/mudds-work/paradox-foundation-20261106/records.tar.gz`; adjacent closeout
records actual publication and owned branch/worktree/process cleanup.

### Vortex continuous physical access — build card2 PARKED

Goal / contract: [approved Vortex card2](docs/design/VORTEX_IMPLEMENTATION_PROPOSAL.md#bounded-implementation-cards--only-after-approval), supported fixture apron→stern hatch/ramp→aisle→helm approach→same physical return. Accepted card1 source0c2f322e4 is the dependency; Vortex Main/berth/seat/network integration remains separate and Main stays10/17.
Result: the same real Player opens the physical hatch through normal Interact, walks the continuous supported route without jump/teleport/collision bypass, reaches the helm approach, then walks outside and seals/reopens the access. Closed hatch blocks passage. Existing controller cannot launch through open/moving access.
Candidate / start: cleanfbbcb0677; existing Vortex geometry/controller, one staged initial fixture ship/deck/Player pose per independent process. Identity fixture and separately translated/yaw-rotated fixture with ship origin(30,0.38,-20), yaw35degrees; deck/apron composes the same transform. After setup no caller changes actor/ship pose, velocity, gravity, masks, clocks or floor flags. Physical Interact dispatch may be fixture-routed from actual Player.interact_requested to the existing discovered/reachable ShipCabinHatch; no direct positive ship-door call substitutes for the ordinary route.
Owner / files: one high-effort physical/lifecycle implementer owns only `scripts/ships/vortex_troop_transport.gd`, `scenes/ships/vortex_troop_transport.tscn`, Vortex resource evidence-notes wording (all approved numeric fields unchanged), existing `tests/vortex_troop_transport_test.gd`, and new `tests/vortex_troop_transport_access_test.gd`/UID. Independent bounded review for geometry/support/access gates. Root owns release/integration/docs/cleanup. Reuse existing HeroShip/MovingInteriorFrame/ShipCabinHatch/Player owners without editing shared runtime or reopening parked Titan role retirement.
Dependencies / geometry: cabin floor1m; clear x±2.2,z±7.5,ceiling≥3.6; minimum1.4m aisle. Ramp is2.4m wide,4m run atz8..12,y1..0 with supported bridge/no gap; hatch clear opening≥2.0×2.4m. Preserve original10×20×5m stowed envelope; only the deployed ramp extends toz12, no other deployed extension. Actual hull/collision/camera/support must agree; correct candidate geometry rather than enlarging reach or disabling collisions.
Proof: `/srv/mudds-work/vortex-access-20261106/`, actual source and source-isolated Windows-PCK fixtures under pinned Linux Godot; real physics samples and matching visible/collider transforms, private Xvfb/OpenGL ES views and strict package gates. Every Godot call Dummy, rendered display explicitx11; no active desktop/native GPU/human qualification.
Budget: original start05:37:40UTC2026-11-06, absolute deadline06:37:40UTC,60minutes all-in including mapping, implementation, complete source/package checks, checkpoint, merge/push/archive/exact-tip branch/worktree/process cleanup. One substantive production repair; routine compiler/caller/assertion fixes preserve every endpoint and the absolute deadline. Stop at first unexpected failure, retain operands and stop dependent checks; independent supervisor aborts/reaps and releases inputs. No renamed retry/subset pass or silent shape/handling baseline revision.
Cases / commands: focused source existing Vortex controller/geometry(90s), new physical access identity and `--transformed` in separate processes(180s each), existing `ship_definition_berth_test.gd`(120s), existing `moving_interior_frame_test.gd`(120s); complete unchanged ordinary Titan Main(300s, run alone). New access tests preload production resources only. Repeat Vortex foundation plus both full access profiles and complete ordinary Main against actual Windows PCK from blank source-isolated directories, retaining those limits. Existing safe paired exports, strict startup3 and existing nine package predicates remain required.
Close: PARKED, unmerged source1416c9ece. The new ramp toe exceeds the frozen intermediate z≤12.0001 envelope; production repair1/1 is already consumed. Source/raw attempts/diagnostic operands are preserved in verified `/srv/mudds-work/vortex-access-20261106/records.tar.gz`; adjacent closeout records actual push/archive/ref/worktree/process cleanup and elapsed cost. No new access checkpoint is published; accepted standalone build remains0c2f322.

Confirmed final failure: the first actual opening contacts `SternRampToeCollision` at localz12.07887/y.56953 (normal+Z, depth.004470825m), not merely the apron. At the recorded inherited fraction.909 the unchanged authored rigid transforms reconstruct toez12.0788662, exceeding the existing `_geometry_motion` limit12.0001. The centreline caller also stood partly inside the planned sweep; a normal side-control approach could avoid that contact but would still violate the SAME envelope check. No caller change or tolerance waiver can make this card pass. Reopen only after explicit owner reprioritization, a measured trajectory inside the original envelope with a physically clear normal operating approach, and a newly frozen repair budget preserving original cases/thresholds/failures/cost. Card3 is GATED; no automatic successor/retry.

Earlier attempts: e245 could not instantiate because the approach marker was not allocated;8fa adds only its mechanical constructor allocation. Actual new ramp inward normals then failed;7815's sole substantive correction reverses only triangle winding, preserving all vertices/colliders/poses/tests. That source passes the complete foundation geometry/profile/controller check. The access test then fails during first opening;1416 adds failure-only contact operands without changing production/query/assertion/flow, proving the envelope defect. One production repair1/1 remains consumed; original05:37:40→06:37:40UTC window never extended.

| Case | Initial state and action | Expected result | Actual result and proof |
| --- | --- | --- | --- |
| Closed refusal | Fresh supported Player on fixture apron walks toward closed stern and back using ordinary controls | Actual door/collision blocks crossing; same capsule remains supported outside and can walk to hatch control, with unchanged masks/gravity/reach | PARTIAL: same real Player remains supported outside closed assembly and physically returns toward control; no inbound access pass. |
| Physical inbound/return/reuse | Actual Player Interact opens existing hatch, walks apron/ramp/vestibule/aisle to helm approach, walks back outside, seals and repeats opening/return | No jump/teleport/seat warp; every movement sample supported and capsule/head clear. Same Player automatically registers only while inside the actual bounded MovingInteriorFrame and retires on exterior return. Same complete case passes on identity and elevated35degree fixture | FAIL before first complete opening: actual moving ramp contacts capsule; full inbound/return/reuse and transformed case NOT_RUN. |
| Geometry and motion | Query actual open/stowed hull/ramp/aperture and intermediate inherited animation fractions; inspect fixed open/closed/helm-eye views | Approved envelope/opening/ramp/aisle, matching mesh and convex collision through motion, no sealed hull bypass/room blocker, continuous supporting floor, clear camera; no volume/reach inflation | FAIL: actual contactz12.07887 matches reconstructed ramp-toe z12.0788662 at fraction.909, beyond12.0001 limit. Stowed foundation geometry/controller passes7815; full motion cannot qualify. |
| Access/engine safety | Request start/throttle while open and during motion; seal access then use normal3.6s startup and idle shutdown; attempt opening without supporting apron and under actual active/moving flight | Open/moving access retains OFFLINE/no movement; sealed controller clock/flight preserved; unsupported/airborne/active opening refuses with unchanged safe access. Negative API fixtures do not replace ordinary walking proof | NOT_COMPLETE: failing opening observes OFFLINE/no hull movement, but full sealed/start/unsupported/flight negatives gated after failure. |
| Existing source + package | Run all literal focused cases and unchanged full Titan Main; fresh paired exports, actual PCK foundation+identity/transformed access+Main, strict startup3/audit9 | Each invocation exits0/one exact marker/raw diagnostics0 and final clean-source/cache guards. Proper Windows/Linux checkpoint/notes/preview, source merged/pushed, verified archive and owned cleanup; Main remains10/17 | Foundation passes7815; final1416 diagnostic fails identity opening. Transformed/definition/frame/fullMain/newcapture/export/startups/PCK/audit NOT_RUN. Verified source/archive retained before cleanup; no runtime merge. |


### Vortex standalone hull and pilot — build card1 DONE (standalone scope)

Source **0c2f322e4**, merged/pushed via **cde60feb6**, adds the approved original
Vortex definition, editable procedural scene/hull and existing HeroShip pilot
controller. Its broad chamfered pod, two engine housings and recessed stern fit
the exact10×20×5m envelope;15 actual convex sections match visible vertices,
face outward, do not overlap and leave the reserved cabin/cockpit eye clear.
All16 approved fields remain unchanged. Actual command-source flight completes
the3.6s inherited manual and automatic startup, forward translation/turning,
braking/arrest and normal idle OFFLINE with engine audio retired. No runtime
pose/velocity/clock override, cargo/specialist grant or historical-model claim.

Four source checks and unchanged complete ordinary Titan Main pass on the exact
clean commit with source/cache guards and clean Quit. Combined profiles for all
ten current craft plus Vortex pass the unchanged14-axis/non-dominance/signature
constraints. The old fleet audit's obsolete9craft setup was corrected only by
an independently reviewed external adapter: exact live Main10 assertion, then
all original nine cases/floors/waits unchanged. This is **legacy-nine regression
inside ten-craft Main**, not full current-ten/Titan handling qualification. Its
original failure and exact source/adapter hashes remain archived. Three fixed
source views were inspected using private Xvfb/OpenGL ES/Dummy; initial GLX
V-Sync warning captures are retained, final capture exits0 with no diagnostics.

Fresh paired checkpoint **0c2f322** passes strict startup3 and all nine existing
package predicates; Windows/Linux payload maps match. Actual Windows packaged
content under pinned Linux Godot separately passes the unchanged standalone
Vortex fixture and full ordinary Titan Main loop from source-isolated blank
directories. Native Windows/GPU/device/human/full-craft gates remain open.

**Vortex is standalone content, not selectable in Main. Main remains10/17.**
The checkpoint includes its runtime scene and a companion preview; ordinary
access, home berth/Main registration, four chairs, weapon, lifecycle/recovery
and network journeys remain later cards. Vortex card2 continuous
physical fixture access is now PARKED above. Titan's parked remote attempt remains unmerged.
Original05:02:41→05:47:41UTC all-in budget, frozen card, source bundle, raw
checks/images and package records are retained in verified
`/srv/mudds-work/vortex-foundation-20261106/records.tar.gz`; adjacent closeout
records actual publication and owned branch/worktree/process cleanup.

### Titan host and one remote passenger — child 11 PARKED

Goal / contract: [Titan child 11](docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md#bounded-implementation-children), actual playing-host pilot plus one remote passenger. Child10 is accepted in2213baf66; child12 two remote passengers/host loss stays separate.
Result: a joined remote uses either authored Titan passenger chair during host flight, can stand/walk/reseat, and can physically exit after normal home docking. Disconnect retires the old claim; reconnect must earn a fresh claim and cannot acquire the occupied helm.
Candidate / start: clean6f6d179b7; two independent Main/ENet OS processes with separate fresh profiles, ordinary Intro/Begin and station spawn. No actor/ship pose, velocity, clock, hull or seat-state assignment in the ordinary journey.
Owner / files: titan_remote_seam_1106 implements `scripts/game/game_flow.gd`, `scripts/network/network_halyard_passenger_binding.gd`, `scripts/network/network_jovian_engineer_binding.gd`, Titan-local adapters in `scripts/ships/titan_medium_transport.gd`, the exact Titan OFFLINE supported-cabin hatch admission in `scripts/interaction/ship_cabin_hatch.gd`, and `tests/network/titan_network_passenger_route_test.gd` (plus its UID). Independent network/lifecycle reviewer; root owns card, release, integration and cleanup. No shared authority redesign, sibling handling changes, specialist roles or cargo authority expansion.
Dependencies: accepted Titan berth/Main/cabin/chairs/cargo/cannon/component/lifecycle children1–10. Existing production ENet, remote walking-body simulation, boarding/seat authority and moving-interior replication owners are reused. No new external input required.
Proof: `/srv/mudds-work/titan-remote-passenger-20261106/`, silent headless/private Xvfb x11/Dummy peers. Raw OS exit0, explicit terminal success, zero raw diagnostics, actual host and client manifests and process cleanup; source scope and actual source-isolated Windows packaged content under Linux only.
Budget: original start04:23:28UTC2026-11-06, absolute deadline05:23:28UTC,60minutes all-in including mapping, implementation, full affected checks, fresh paired checkpoint, merge/push/archive/ref/worktree cleanup. Existing peer stage waits and300s total/10s abort grace stay unchanged. One substantive production repair after first observed runtime failure; routine compiler/caller/assertion repairs retain this deadline and every affected gate.
Stop: retain first unexpected failure and actual operands, stop dependent checks; no shortened route, pose staging, direct seat claims or simulated peers as ordinary proof. Unresolved production failure after allowance or deadline parks the whole card with original cost. Independent supervisor terminates/reaps owned peers and releases inputs.
Close: PARKED on clean867565997 after actual unsolicited remote chair-claim retirement during departure. The single production repair1/1 was already consumed; no second repair, source merge, checkpoint or successor is authorized by this closure. Source bundle/raw attempts are preserved in verified `/srv/mudds-work/titan-remote-passenger-20261106/records.tar.gz`; adjacent closeout records actual cleanup, remote refs and elapsed cost. Latest accepted playable checkpoint remains2213baf.

First actual attempt9fd45cc4e reached remote station/ramp walking and standing cabin admission, then failed the physical chair claim: shared `NetworkHalyardPassengerBinding.claim` calls absent Titan `get_moving_interior_component()`. Exact host backtrace/guest timeout and source bundle are retained under the task's `attempt-9fd45cc4e`. Sole substantive correction1/1 is db401d32b's Titan-local alias returning its existing `_interior_frame`; no second frame/authority is created. Full ordinary Main and five focused suites passed that earlier source. The sixth existing Jovian regression also exposed a root invocation mistake (its explicit-x11 child had no display); a private Xvfb wrapper fixes only the invocation. Actual processes were reaped before edits. All required source and package cases remain required on the repaired clean commit; original05:23:28UTC deadline and exhausted production correction allowance remain binding.

Confirmed final failure: `host.helm` retains body3787657857150/entity1, passenger claim1 and seated=true; `host.moving` retains that same body/entity but has assignment={} and seat_state=standing, while last_interaction_id remains1. The guest's stand observation occurs later. The host therefore retired the physical passenger claim without a new interaction. The existing passenger-binding `advance()`→`stand_crew_body()`/release path can produce this transition. Strict floor-boundary roundtrip in the physical role contract is a plausible cause, **not proven**: the exact failing contract coordinate was not captured. Full ordinary remote travel is FAIL, reconnect and package gates remain NOT_RUN. Reopen only after explicit owner reprioritization, measured reconciliation of this exact support/role-contract retirement cause and a new bounded repair budget preserving all original endpoints, attempts and cumulative cost. Child12 remains GATED; no automatic retry is scheduled.

Frozen source commands (all through existing `tools/release/suite_process.py`, owned isolated profiles, `godot --headless --audio-driver Dummy --path <clean-worktree> --script res://...`): `tests/titan_medium_transport_test.gd` (100s), `tests/titan_cargo_custody_test.gd` (100s), `tests/network/network_crew_role_authority_test.gd` (60s), `tests/network/game_flow_moving_interior_network_integration_test.gd` (60s), `tests/network/game_flow_halyard_crew_role_bridge_test.gd` (60s), `tests/network/jovian_network_passenger_seat_test.gd` (300s), and `tests/game_flow_titan_integration_test.gd` (300s). New ordinary and `--reconnect` profiles of `tests/network/titan_network_passenger_route_test.gd` each retain300s total plus existing10s owned exit grace. These two profiles and the complete ordinary Titan Main loop are repeated against actual Windows packaged content from a blank directory, with excluded test constants/adapters inlined only as needed and no source runtime fallback. Native Windows is NOT_RUN.

| Case | Initial state and action | Expected result | Actual result and proof |
| --- | --- | --- | --- |
| Ordinary host/remote travel | Two fresh Main processes, host starts session and guest joins using existing production UI/ENet; both Begin and walk station route to Titan; guest walks hatch/ramp to chair and Interacts, host reaches helm and starts normally | Same physical actors; host is sole pilot, one remote owns the selected exact passenger anchor/current claim and supported host body; no pose staging or API seat claim | PARTIAL: actual ordinary station/hatch/ramp, exact remote chair claim and sole host helm reached; complete travel NOT qualified. Raw source-remote host/client logs. |
| Moving stand/walk/reseat | Host physically departs more than existing5m threshold; guest stands, walks more than existing0.6m within moving cabin, approaches and reseats through ordinary controls | Moving authoritative and consumed hull, same guest body/frame, fresh seat claim, no helm/fire authority gained; original8s boundary waits retained | FAIL: same host body loses claim1 during departure before guest stand, interaction cursor unchanged1. Confirmed raw host.helm/host.moving operands; no GO. |
| Dock and physical exit | Normal host neutral/shutdown and own L home landing; guest stands and walks continuous cabin/ramp route outside | Exact own occupied berth; supported unseated remote outside, old chair assignment cleared, no duplicate craft or cargo; normal clean Quit | NOT_RUN: dependent on failed moving-cabin ownership case. |
| Disconnect/reconnect and stale refusal | Separate actual host/remote run, current remote chair claim; guest disconnects through normal session owner, reconnects/joins and physically reboards | Host clears prior seat/body/claim; old generation cannot reclaim or steal helm, rejoined peer earns fresh body/seat authority through physical interaction; host pilot retained | NOT_RUN: dependent on failed ordinary remote journey. |
| Existing behavior | Existing Titan medium/custody suites; existing network crew-role, moving-interior GameFlow integration and physical passenger binding regressions; complete existing ordinary Titan Main test | Each selected suite exits0 with its one success marker/zero diagnostics; original local chairs/cargo/service/cannon/home/Quit behavior retained | PASS final867: six focused suites and unchanged full ordinary Titan Main (serial) exit0/one marker/raw0 with source/cache guards and normal clean Quit. Earlier failures preserved. |
| Fresh package and cleanup | Clean final commit, existing safe paired exports; actual Windows PCK ordinary Titan Main and both new remote profiles; strict startups and existing nine package predicates | EXE/Windows ZIP/notes plus paired Linux files in builds; all scoped checks pass, merge/push verified, accepted branch/worktree/processes removed and failed attempts archived; native/GPU/human/full-craft gates remain open | Package/startups/audit NOT_RUN: unaccepted source. Bundle/archive verified before owned branch/worktree/process cleanup; adjacent closeout records actual outcome. No runtime merge or new build. |


### Titan destruction, regeneration and custody — child 10 DONE in local scope

Source **2213baf66**, merged/pushed via **50f542377**, seals Titan's exact live cargo
manifest through existing authority reassignment and tree detachment. Dead UI
and direct authority requests refuse; ordinary scene reentry cannot unseal it.
The actual normal pending/home regeneration owner restores that same manifest
with fresh handles and unchanged2/2 quantities. No reseed, second spendable pile,
shared cargo framework or new persistence slot. Public early, occupied and stale
reset attempts refuse before gameplay/berth/custody mutation. The sole substantive
correction requires an actual active attempt and elapsed real deadline; existing
Hero pending capability fences synchronous lease reentry.

Three local physical Player fixtures exercise moving pilot/passenger claims,
seat/camera/fire/frame cleanup, supported on-foot recovery and fresh role
rosters. Actual Main separately retains the full original service/cannon/cargo
journey and runs a lifecycle journey: physical load2/2/departure/cannon, real
registered terminal incoming damage, normal supported Player recovery, unchanged
regeneration timer, one nominal220-hull Titan at its exact own occupied berth,
physical return/reboard/start/OFFLINE/exit and actual UI Quit. Old service and
shared-authority handles remain refused; the same manifest and quantities survive.
Custody isolation preserves save bytes; normal death/activity/session writers
remain permitted and are separately recorded in the integrated journey.

Eight final-source invocations pass with guarded source/cache and clean SHA,
including existing destruction/reentry and actual-store fault checks, both full
Main modes and two distinct cold processes. Cold probes consume the actual
post-death committed2/2 envelope: fresh Main and repeated replacement project
exactly four existing parcels to locker4/Titan0, with safe on-foot continuation
and no pilot/seat/camera/in-flight/hull authority resume or duplicate stock.
Fresh paired checkpoint **2213baf** passes three strict startups and all nine
existing package predicates. All1,545 Win/Linux payload entries
match; actual Windows packaged content under pinned Linux Godot independently
passes ordinary/lifecycle Main and two cold processes from source-isolated blank
directories. This proves packaged content under Linux, not native Windows.

Main remains10/17. Next is bounded host/remote passenger composition; complete
role/handling, full craft/world/capacity/final-release and applicable hardware
qualification stay OPEN. Prior Jovian engineer admission failure remains
unchanged/unqualified. Titan remains an approved modern interpretation, not an
authenticated historical reconstruction. Frozen card, source bundle, failure
operands/raw profiles and package records are in verified
`/srv/mudds-work/titan-lifecycle-20261106/records.tar.gz`; adjacent closeout records
actual publication/cleanup and original03:25:54→04:25:54UTC all-in budget.

### Titan component damage and berth service — child 9b DONE

Source **9b5491ef4**, merged/pushed via **babe104ab**, installs Titan's existing shared
localized damage/recovery presentation and a Titan-local adapter over the same
five-component ledger. Anchors now sit on its actual nose, both side engine
boxes, core roof and aft header, retaining inherited radii. Nose performance
caps engine mobility through min(engine,nose) using existing1/.62/0 stages;
side weapon sections and core targeting retain their existing consumers. No
shared/sibling damage or handling tuning changes, new service role or cargo heal.
The single production repair handles measured floor roundoff at local0.799997
against nominal0.8: Titan accepts at most0.0001m below its floor, keeps walls/
ceiling strict and rejects0.001m below. Player containment/reporting reuse only
the live registered exact matching coordinator predicate; bounds/reach/generation
ownership remain unchanged. The failed c032 packaged candidate is retained.

All seven selected existing suites pass with guarded final source/cache. Physical
rays identify all five surfaces, localized feedback tracks actual ledger damage,
and matched real controller/fire/aim inputs prove impairment and recovery.
Ten-craft berth repair/regeneration parity and unchanged shared model/integration
checks pass. In ordinary Main, the complete original cargo/chairs/start/cannon
journey precedes genuine incoming opponent resolver damage. Real automatic
OFFLINE and physical pilot leave/reboard preserve the same Player and damaged
hull/components. Own normal L landing and existing intact landed service restore
nominal components within the unchanged4s window; exact hull damage remains.
Physical cargo return/exit/reboard proves usable helm without seat healing, and
actual UI Quit persists clean recovery/session markers and locker4/Titan0.

Paired checkpoint **9b5491e** passes all three strict startups and all nine
existing package predicates. All1,545 Windows/Linux payload entries
match; only the source-owned Titan/Player runtime changes, with unrelated typed-node
metadata differences separately inspected. The complete Main test passes against
actual packaged Windows content under pinned Linux Godot, blank directory and
source isolation guard. This proves packaged content under Linux. It does not
qualify native Windows/GPU/device/audio/rendered readability/human/full release.
The prior Jovian engineer admission failure remains unchanged and unqualified.

Main remains10/17. Local destruction/regeneration/cold policy is delivered above; remote crew,
complete role/handling and full craft qualification stay OPEN. Titan remains an
approved modern interpretation, not an authenticated historical reconstruction.
Frozen card, raw results/failed attempts and source bundle are in verified
`/srv/mudds-work/titan-service-20261106/records.tar.gz`; adjacent closeout records
actual publication/cleanup and original02:24:30→03:39:30UTC all-in budget.

### Titan pilot cannon — child 9a DONE

Source **bd6938683**, merged/pushed via **f7f629c85**, gives Titan its approved centre
pilot cannon through the existing command, combat and damage owners. The unchanged
Jovian resource supplies650m range,70 damage and0.62s cooldown. Titan owns
source1110; prior1101..1109 identities and weapon resources are retained. The
centre bore at(0,1.1,-8.9) clears a matched skin/collision recess; complete hull
bounds remain12x18x5m. Normal held FIRE drives actual damage and heat/cycling.

All six selected existing suites pass on the final clean source with guarded
source/cache. The complete ordinary Begin/walk/parcel/chair/start/flight journey
adds a staged production opponent at the real pilot reticle: one held-fire shot
emits one70-damage event, subsequent held fire waits38–39 physics ticks and then
misses without target damage. This staged target does not qualify encounter
discovery. Tests retain same Player, healthy220 hull, real3.4s startup, own-home
landing,90 neutral OFFLINE ticks, locker4/Titan0, physical exit and actual UI Quit
with durable clean recovery/session markers. Direct authority cases cover replay,
self/friendly/world blocking, wrong/unregistered/spoofed/inactive/client sources.
Queued real Titan owner refuses source_unavailable and then unregistered_source,
retiring only its registration while protected health/other sources remain intact.

Fresh paired checkpoint **bd69386** passes three strict startup probes and all
nine existing package predicates. All1,545 Windows/Linux payload
entries match. The complete unchanged-input Main test also passes against the
actual Windows package under pinned Linux Godot, blank directory and source
isolation guard. This is packaged-content proof under Linux. Native Windows,
GPU/device/audio/readability/human and full release gates remain open/NOT_RUN.
The prior Jovian engineer admission failure is unchanged and unqualified here.

Child9b component/service is now delivered above. Complete role/handling and
full craft qualification remain OPEN, followed by broader lifecycle and remote crew. Main stays10/17; this is
an approved modern interpretation, not an authenticated historical reconstruction.
Frozen card, raw results, source bundle and failure records are preserved in
`/srv/mudds-work/titan-cannon-20261106/records.tar.gz`; adjacent closeout records
actual publication/cleanup and original01:58:12→03:13:12UTC all-in budget.

### Titan finite parcel transport and cold custody — DONE in parcel scope

Source **2794cfa4c**, merged/pushed via **27f57a620**, delivers four inert sealed repair-kit
parcels, a supported stern supply locker and compact port hold panel. Normal E
loads at supply and returns at hold; both show current stock. Existing cargo
quantity authority owns the pair; no new mission, reward, healing or shared-stock
mutation. Both quantities and safe on-foot recovery commit together before
success. Stale/duplicate/range/actor/seat/lease/quantity/capacity and write failures
refuse without a second spendable pair. Opaque panels/pedestal have solid collision;
status labels clear the surfaces.

Cold restoration returns the four already committed parcels to locker4/Titan0,
using first-use markers and fresh scoped endpoints rather than additive refill.
Corrupt/missing initialized data and unresolved storage recovery fail closed for
cargo/launch. Actual-file refusal/interruption/corruption tests pass. Other ships'
saved recovery contexts remain verbatim in both durable data and live GameFlow;
new actual-store/Main-startup and packaged checks cover that regression.

Safely docked Titan passenger stand now releases cabin/boarding containment into
ordinary supported on-foot movement. Actual full Main input proof loads2/2,
cycles both chairs, returns4/0 after standing, physically exits/reloads2/2/reenters,
then completes healthy flight, own home landing,90 OFFLINE ticks, return4/0,
physical exit and UI Quit. Moving passenger containment remains intact in flight.
Fresh source and packaged retained profiles confirm clean shutdown/recovery.
The packaged route observes 4,493 supported/capsule-clear walking samples.
Two separate packaged cold processes restore the actual physical2/2 commit to4/0,
repeat Main replacement without duplication and reject old scoped requests.

Core immutable checks at037f5bf73 pass; later label/context changes have focused
proof plus final-source full Main and final packaged replay/cold/captures. Legacy
Jovian cargo passes176 checks on the preceding implementation; its mission/authority
code is unchanged and unrelated recovery preservation is separately proved. The
previous Jovian engineer admission failure remains an unqualified gate, not fixed.
Three strict startups and all nine package predicates pass; all1,545 Win/Linux
payload entries match. Three isolated local packaged panel/cabin views inspected;
Main/native GPU/device/audio/human/art and full craft qualification remain open.
No full-project green claim or new craft count: Main remains10/17.

Verified records, failed candidates, source bundles, profiles and captures:
`/srv/mudds-work/titan-parcels-20261106/records.tar.gz`. Adjacent closeout records
actual publication/cleanup and original00:42:59→01:57:59UTC all-in budget. Owned
branch/worktree/process/scratch cleanup is part of closure. Next dependency-ready
construction at that checkpoint was Titan child9a pilot cannon, now delivered
above. Child9b component/service work remains next.

### Titan's two physical passenger chairs — DONE in local scope

Source **c3ba813d7**, merged/pushed via **8bd3e70f3**, adds two visible, collidable
ordinary chairs at the approved distinct port/starboard anchors. Normal E sits;
E stands into the supported aisle. One existing role ledger owns all three
pilot/passenger identities; the narrow optional seal configuration preserves
existing roster defaults. Duplicate, stale, wrong-identity/frame/anchor/generation
claims refuse without mutation. Passengers gain no helm, weapon, repair, cargo
or specialist navigation action.

The actual component fixture seats two Player bodies, then stands, walks and
reseats them while Titan's controller genuinely translates and rotates. The
normal Main loop physically walks from spawn through hatch/ramp, performs
port/starboard/port sit/stand cycles, then retains the complete pilot departure,
flight, own-home landing, 90 neutral OFFLINE ticks, physical exit and UI Quit.
Independent persistent-profile source run passes 3,672 supported/clear walking
samples and clean shutdown/recovery/session-ended markers, with stable full
source/cache hashes. The identical packaged loop passes 3,671 observations,
OS0/one sentinel/zero diagnostics and durable clean markers from a blank source
directory under the pinned Linux engine. This is not native Windows proof.

**12 selected suites pass 957 checks; the full 13-suite selection is not green.**
Jovian's existing engineer ordinary-interaction and dependent hull-loss-admission
test remains FAIL (8 passes, 2 failures). The untouched f200a993f baseline produces
a byte-identical complete raw log, with stable source/cache; no introduced
regression was observed. That failed gate remains OPEN and is recorded in notes.
Existing Halyard and Bulwark crew-owner checks pass. Source review GO is scoped
to the new Titan passenger behavior, not full release qualification.

Fresh paired checkpoint **c3ba813** passes three strict startups and all nine
package-audit predicates. All 1,541 Windows/Linux entries match: four intended
runtime script changes, 68 typed-node-metadata-only scene changes, no added or
removed paths/UID/class mappings. Three packaged local chair/cabin fixture views
inspected on isolated Xvfb/X11/llvmpipe/Dummy (OS0, one environment V-Sync warning).
This does not close Main readability, art, native GPU, device/audio or human gates.
Remote passengers, cargo, combat, lifecycle and full craft qualification remain
OPEN. The fleet count remains 10/17.

Complete frozen card, failed attempts, source bundle, raw results/profiles and
captures are in verified `/srv/mudds-work/titan-passengers-20261106/records.tar.gz`.
Owned branch/worktree/processes/scratch are removed at closure; adjacent
`closeout.json` records actual hashes and publication. Original 00:11:50→01:11:50UTC
2026-11-06 all-in deadline retained and met.

Next dependency-ready construction child: **Titan's four-parcel loading controls
(proposal child 7)**. Freeze the exact existing cargo authority/item/manifests and
physical panel route, conservation/capacity/remote-refusal checks before work.
Cold custody/persistence remains the separate child 8; no whole cargo completion
is inferred from a loading checkpoint.

### Titan minimum Main pilot loop — DONE in pilot scope

Source **af0199339**, merged and pushed via **fe3455ecc**, adds exactly one live
`titan_provisional` at its own berth.
Normal Begin Shift, the 21-leg station walk, physical hatch/ramp/cabin entry,
helm claim, sealed access, timed 3.4s startup, actual flight, own home landing,
90 neutral OFFLINE ticks and physical cabin/ramp exit pass with the same Player.
The final loop records 204 startup physics ticks and 3,369 supported/capsule-clear
walking observations; actual UI Quit exits 0 and persists clean shutdown/recovery.
The final 12-suite regression matrix passes 1,138 checks with stable source/cache.
The original nine craft remain unchanged. Titan has no offensive combat source.
At that checkpoint passengers were not fitted; local chairs are now delivered
above. Cargo, combat, lifecycle/network and full craft qualification remain open.

The station connector producer now separates the coincident navigation markers
by 1.5m, restoring the valid graph/minimap without changing its edge limits or
moving the berth. Earlier berth qualification did not catch that graph defect.

The same full loop passes against actual Windows packaged content under the
pinned Linux engine from an empty source directory: 3,399 supported/clear walking
observations, actual UI Quit, OS0, zero diagnostics and persisted clean markers.
All 1,541 Windows/Linux payload entries match; the existing nine-predicate package
audit passes. Native Windows execution is not established by this Linux probe.

Actual Main software-rendered capture remains **TIMEOUT / unqualified**: private
Xvfb/X11/Dummy/llvmpipe attempts at 120s and 360s produced no image; the second
last reported startup stage was Routing the station. Both owned process groups
were reaped. This is recorded in the build notes; earlier standalone renders
do not establish current Main readability or native GPU performance.

Original readiness 23:17:40 UTC November 5 and hard deadline
00:17:40 UTC November 6 are unchanged. The complete frozen task card, failed
attempts, raw results and verified source bundle are retained in
`/srv/mudds-work/titan-main-20261106/records.tar.gz`. Owned branch/worktree/processes and scratch are removed; the adjacent
`closeout.json` records archive hashes, publication and the retained visual gate.
The original all-in deadline was retained and met.

The subsequent local passenger child3 is delivered above. Cargo and the
remaining full transport/network scope follow through their own bounded cards.

### Titan own reachable berth — DONE in berth scope

Source **6bb77845f**, pushed via **e3d42b6a8**. Own compatible berth/deck at
(154,.38,38), yaw−90°, plus6m supported connector and default-closed/production-open
spur gate. The new eighth module is registered through the normal world hub;
10berths are discovered while old nine craft placements/compatibility and six
feedback placements stay unchanged. Wrong-tag reserve and rogue audit refusal
pass. Actual Main Player traverses all21 frozen route legs from normal spawn,
reaches the normal-range control and opens the staged Titan hatch:2589 source
observations supported/capsule-clear. Complete closed/deployed shape sweeps,
continuous5m lift and actual inherited20m/.55m camera sphere/arm/near boundary pass.

Final committed matrix176checks/OS0/sentinel1each/diagnostics0/guards stable;
spur default/enabled72checks pass. Windows packaged-content replay from a blank
source directory passes25checks and2562 supported/clear observations; excluded
tests and raw runtime.gd are absent. Three strict startup probes and all nine
paired package-audit predicates pass; full1541-entry Win/Linux raw maps match.
Four authored-module render views inspected at production poses on private
llvmpipe/X11/Dummy (OS0, one environment V-Sync warning). Staged hull image is
fit evidence; at that checkpoint the actual production bay remained empty.
Source/artifact review GO.

Seven checkpoint files are published above. Complete records/source/captures are
in verified `/srv/mudds-work/titan-berth-20261105/records.tar.gz`; owned branch,
worktree/processes and scratch removed. Original22:39:21→23:39:21UTC all-in
budget retained and met. At that checkpoint, the bay was empty and count remained
9/17. Main/pilot composition is now delivered above; full craft/native/human gates
remain OPEN. The coincident navigation endpoint defect found subsequently is
corrected in af0199339 above; that was not proved by the earlier berth checks.

### Titan construction — standalone children1 and2 DONE

**Hull/pilot foundation834cc50a3**, pushed via dded94bda: original editable
12×18×5m hull, exact approved definition/pilot/eye, convex shell/engine collision,
clear cabin volume and inherited spool/thrust/braking/neutral shutdown. Focused
suite40checks PASS; all committed hashes match guarded inputs. Source and two
inspected software-rendered views retained in the verified standalone task archive.

**Physical access3b9f5617c**, pushed via4621bf485: real folding stern ramp,
vertically sliding hatch with roof slot, matching moving collision, continuous
floor and existing cabin frame. Actual Player walks apron→helm→apron after
neutral shutdown; all224 inbound and222 outbound frames supported and capsule
clear, endpoints within5cm. Actual unsupported exterior-access opening and
open/moving-access departure refuse. Focused suite63checks/30.109s, OS0,
sentinel1/diagnostics0/source-and-cache-stable; independent review GO. Closed/open
renders inspected on isolated llvmpipe/X11/Dummy (OS0, one environment V-Sync
warning). Complete raw/source/captures preserved in verified
`/srv/mudds-work/titan-access-20261105/records.tar.gz`; owned branch/worktree and
scratch removed. Original22:22:07→23:22:07UTC all-in budget retained and met.

These are standalone children of the [approved Titan proposal](docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md).
At those standalone checkpoints the count remained 9/17. Reachable berth and
minimum Main pilot/physical exit composition are now delivered above. Passenger,
cargo, weapon, lifecycle and full craft qualification remain OPEN; native
Windows/GPU/human gates remain NOT_RUN.

### Hauler ordinary mass-driver hit, miss and home — PARKED, unaccepted

Final retained source **8c56e9d15**. No source from this attempt is merged and
no checkpoint is published. Actual native **c94f4867f** passes ordinary approach,
boarding, neutral90, departure/clearance and a genuine travelling hit: source1109,
correct weapon/sequence/current target, positive-age advancing flight,26damage
and100→74health. The run then stops after80.504s in `miss_aim`: the caller
asserts terminal+42ticks before waiting. Diagnostics0; every input/process cleaned.
The final Python-only wait-gate fix passes317 tests but has no native run.
Distinct lifetime miss, reverse route, strict home, physical exit, normal Quit
and final nine-predicate package audit remain **NOT_RUN**. Full craft and the
ordinary member remain OPEN. Seven source suites, paired exports/three strict
startups pass on c94; those do not close the missing full journey.

Original20:40:26UTC start and22:10:26UTC all-in deadline retained; one substantive
correction used, with routine observer/float/caller repairs recorded separately.
No time reset, smaller endpoint or automatic successor. Unique source, all raw
runs and exact false-miss/fixed-hit Linux packages are preserved in the verified
`/srv/mudds-work/hauler-weapon-20261105/records.tar.gz` with closeout metadata.
The frozen contract below is retained for audit, not an active assignment.
Next construction selection is Titan proposal child1 (standalone authored hull,
definition and pilot fixture), with a new concrete card required before starting.

**CRAFT-ACCEPT-CINDER-HAULER / travelling pilot weapon member**, reusing the
[existing firing-role map](docs/WEAPON_DEFINITION_CONTRACT.md) and accepted
Hauler admission/home99f2717ee. Deliver its missing executable ordinary caller
and terminal observation, not cargo replay or full craft/eleven-binding closure.

- **Candidate/start:** clean e67299a53; fresh normal Boot/private empty profile,
  ordinary E/18 `CinderHaulerSupplyPilot.INITIAL_GOALS`/actual Dock04 boarding
  and90 neutral ticks. No activity arm/load, state/pose/health write or injected
  shot/packet. Ordinary default pilot input only; no parked route retry.
- **Owners/files:** one high-effort implementer owns existing
  `tools/release/run_native_sortie.py`, `tools/release/test_native_sortie.py`,
  `scripts/diagnostics/native_sortie_observer.gd`,
  `scripts/game/startup_loader.gd`, `tests/startup_cli_privacy_test.gd`.
  Root owns card/commands/package/integration/cleanup; one independent high
  reviewer checks terminal attribution, actual input and complete outcomes.
  No gameplay tuning change or missing-original/crew/remote scope.
- **Literal source-owned route binding:** from actual departed Dock04 use its
  accepted live capture→capture+world-UP60m clearance, then station-local
  (0,120,-200)→(0,30,-75), reaching each at≤2m/≤.5m/s. Query actual complete
  current hull/geometry before each leg; fail a blocker, never teleport or
  substitute another goal. Station coordinates follow the live World transform.
  Brake at the firing point; aim from actual muzzle to the current supported
  moving target, using real mouse and measured motion/lead. Missile-style
  camera or actor pose writes are prohibited. Return through (0,120,-200),
  the same live clearance point and original capture/home path.
- **Hit/miss binding:** actual `ExteriorTargetRange/TargetDrone01`, `DRONE-01`,
  base(-13,7,-95), real moving collider radius2.35m, starts100 health. Exactly
  one accepted real FIRE flight must travel then commit26 once (100→74).
  After normal cooldown, ordinary input aims the same muzzle station-UP;
  passively query its actual .45m-radius/180m swept corridor excluding own hull.
  Exactly one second FIRE flight must genuinely miss/expire after the authored
 1.2s/180m, with health74 unchanged. No fabricated target/empty-space receipt.
  Weapon stage45s from settled firing arrival through both terminals; total
  original CAP300/independent360 remains from process launch, never reset.
- **Source facts:** registered source1109/current Hauler, weapon
  cinder_cargo_mass_driver,180m/26/.70s,150m/s/1.2s/.45m; actual3-slot pool.
  Preserve inherited heat/component/ONLINE/cadence gates. Do not use
  get_last_player_shot_result's launch dictionary as a terminal proof. Passive
  pool bolt_launched/resolved/abandoned callbacks and real authoritative
  terminal ShotRequest/adapter hit context must correlate exact flight/source/
  weapon/sequence; slot identity alone does not establish source attribution.
- **Literal executable command:** `python3 -B tools/release/run_native_sortie.py
  ABS_LINUX_ELF --output /srv/mudds-work/hauler-weapon-20261105/ordinary
  --route hauler-weapon`. Add exactly this opt-in selector under existing
  x11/Dummy/private-input admission; preserve all old selectors/order/defaults.
  Existing native private Xvfb/dummy renderer/abort/input release/reaping stays.
  Normal output result must contain success=true and NATIVE_HAULER_WEAPON_OK
  only after every stage/normal OS0. No rendered/GPU/device/human qualification.
- **Complete checks:** existing full Python native suite; seven full headless
  matrix scopes: startup_cli_privacy_test, cinder_cargo_mass_driver_bolt_test,
  cinder_cargo_hauler_test, weapon_definition_test, live_combat_integration_test,
  combat_resolver_test, main_reentry_quality_test. Pinned Godot4.7.1, Dummy,
  jobs1/timeout300, first import always then never, original marker once,
  raw diagnostics0/OS0/stable source+imports. Compile actual observer via
  startup/privacy preload, without calling instance-only methods on its class.
  Clean paired exports/three strict --startup-check probes/full inventory+
  all nine existing package audit predicates remain required before publication.
- **Proof/close:** one exact immutable source/package, actual PID/input/actor/
  muzzle/target/flight/authority/impact/terminal/home/support/stock/reward/claim
  operand records and normal durable clean close. Root retains verified records
  and unique source; merge/push accepted work, seven repository checkpoint files
  with actual scope notes; exact owned worktree/ref/process/scratch cleanup.
  No validators/schema versions/new evidence family, Downloads or hosted CI.
- **Budget/stop:** readiness costs retained from20:40:26UTC2026-11-05;
 90min all-in estimate/absolute22:10:26UTC deadline. Freeze **three corrections
  total** for this cross-component input/flight/terminal capability, each only
  after concrete cause plus cumulative-cost GO. First unexpected failure stops
  dependent work; final failed correction/deadline parks complete delivery.
  Original input/home sublimits remain:15s/walk goal,12s boarding,15s home
  alignment,120s landing,10s exit,90 neutral OFFLINE observations. No cost or
  correction reset, smaller endpoint or automatic successor. Prior parked
  station/Cinder attempts retain their distinct costs and owner gates.

| Frozen case | Actual action | Expected endpoint | Result |
| --- | --- | --- | --- |
| Physical admission/departure | Normal Boot/E/supported18-goal walk/actual E boarding/neutral90/W departure/live clearance and fixed firing route | Same production Dock04 Hauler/Player/source/default controls, ONLINE/home lease released, healthy hull and unchanged cargo/reward/other claims; real full-hull route queries pass | NOT_RUN |
| Genuine travelling hit | Native FIRE once at actual DRONE-01 with real muzzle/motion aim | One correlated current source1109/weapon/sequence/flight; launch health100, positive-age displaced flight observation before actual terminal; supported adapter commits26 once, health74, no duplicate damage | NOT_RUN |
| Genuine miss/retirement | Wait normal .70s gate; physically aim/query station-UP corridor, native FIRE once | Distinct flight, real positive-age travel then lifetime miss; health74 stable, pool/authority active counts0, no abandonment/resurrection/duplicate, authored weapon/heat behavior retained | NOT_RUN |
| Complete home and delivery | Fixed reverse route, original captured L/strict lease,90 neutral OFFLINE, physical E exit/apron walk/normal UI Quit | Exact occupied dock_04_cargo/root error≤.05m/speed≤.05m/s, supported same Player walk≥1m to accepted apron(8.8,4.18,90); actual OS0/both clean markers/diagnostics0; all source/native/package gates pass, pushed source/checkpoint and owned cleanup complete | NOT_RUN |

Hauler correction1/3 authorized21:57UTC: actual travelling impact reached the
moving target, but the authoritative re-query ended at a rounded surface point
roughly1µm outside its collider and returned a miss. Repair only the runtime
terminal-segment handoff in `travelling_bolt_projectile.gd`, extend the existing
oblique target regression in `cinder_cargo_mass_driver_bolt_test.gd`, and retain
the original range/occlusion/source/faction/once-only damage rules. Observer and
Python timing/representation repairs retain real airborne proof and exact26
once-only damage. The original22:10:26UTC all-in deadline is unchanged; failed
native records remain retained. Full hit/miss/home delivery remains unaccepted; the actual hit later passed but the caller stopped before miss/home.

### Station Reduced Flash ordinary package/UI episode — integrated

Source **e3880319c**, pushed in main **a7538b24e**. Actual packaged ordinary
Boot/E, supported spawn, settings OFF→ON→OFF→ON, unchanged actor/resource
identities and gameplay authority, exact presentation caps, explicit Save and
independent durable settings, normal Exit and both clean markers pass in71.645s;
zero diagnostics and all synthetic inputs/processes cleaned up. Six focused
Godot suites pass on unchanged Godot sources;310 Python checks pass. The store
negative-fixture suite deliberately produces four expected warnings; ordinary
package/startup checks produce none. Paired exports, three strict startup probes
and all nine package audit predicates pass. EXE/ZIP/notes and paired Linux
checkpoint are in builds/. This is property/UI qualification, not pixel,
native Windows/GPU or full COMFORT-FLASH acceptance.

Original start20:17:08UTC and21:32:08UTC all-in deadline retained. Runtime,
package audit, integration and push finished before the deadline; archive and
branch housekeeping overran it. Do not count this as an on-budget completed
sprint or reset its cost. Earlier failures remain in the preserved task archive
and [initial failure record](docs/history/ROADMAP_DELIVERIES.md#station-flash-startup-test-compile-stop-20261105).
No more station scope is opened by this result.

### Cinder remote pilot exterior-body handoff — PARKED, unaccepted

The selected ROLE-CINDER-LOADMASTER pilot-body member stopped on its final
allowed correction. Candidates7a356bd18→a98e3b7ac→677c5c4f2→ae24ec526 remain
unmerged. **No gameplay from this attempt is accepted; no checkpoint exported.**

Final actual client/host ENet run exits1 after16 passing assertions: cabin-body
promotion retirement, trusted fresh generation2 handoff, actual host pilot-anchor
birth, early cargo-authorization refusal, real seat-exit completion, restored
collision and on-floor state. Its next required check fails: the actual support
is Hauler `CinderCargoVisual/BoardingRampSupport`, while the frozen assertion
requires support beneath current Cinder access. Actual body position:
(35.21464,-66.98969,-700). This is a measured support-owner mismatch, not proof
of missing floor, a complete physical handoff or an accepted alternative.

Walking/client binding, post-exit cargo eligibility, stale/foreign input,
ordinary A reboard and all four retirement cuts remain **NOT_RUN**. Initial
7a356's complete remote-body suite passes190 assertions/245.002s with stable
source/import guards and zero diagnostics; it does not qualify the corrected
final candidate. Remaining source suites and every package gate are NOT_RUN.

Three corrections are spent: preserve the existing same-A pilot return (review
found an unconditional boarding refusal), repair two multiline fixture lambda
predicates, then explicitly type three WeakRef declarations under warnings as
errors. No failed predicate, original case, threshold or deadline was waived.
The fixed90-minute budget starts19:27:45UTC and ends20:57:45UTC2026-11-05;
actual failure occurs before the deadline. Closure cost and verified retained
source/results are in the [delivery record](docs/history/ROADMAP_DELIVERIES.md#cinder-pilot-exterior-support-owner-stop-20261105).

**Reopening requires explicit user reprioritization**, retaining all prior cost
and exhausted allowance, plus a bounded reconciliation of the actual supported
Hauler-ramp exit with the original live-exit/Cinder support contract. Establish
whether an actual further supported step is required; do not simply loosen the
support-owner assertion. All original walking, eligibility, replay, pilot return,
retirement, regression and checkpoint cases remain required. No retry or next
implementation is selected by this closure. Parked B passenger work is separate.

### Next delivery chain: remote Cinder pilot and terminal

These are separate members of the existing
[ROLE-CINDER-LOADMASTER contract](docs/ROADMAP_BACKLOG.md#cinder-remote-crew-moving-handback),
not new roadmap IDs. Execute in order only after the recorded selection gates
are satisfied. The first member is now PARKED above; the other members remain
GATED. No readiness resurvey or automatic retry is selected.

| Goal | Player-visible result | Fixed proof endpoint | Dependency / selection state |
| --- | --- | --- | --- |
| Host-authoritative pilot exit and walking body | Remote A leaves the Hauler pilot seat at the occupied Cinder berth and walks the same exterior actor on client and host | Host creates exactly one production body at its actual pilot anchor; real seat-exit completes onto support; authenticated input moves that same body≥1m; client/publication generations agree; host Player/camera stays unchanged. Foreign, duplicate and retired-generation input cannot move/recreate it; lease/source loss and disconnect retire it. Stock/payment unchanged. | Existing live Cinder berth/source/attachment and authenticated pilot grant. PARKED/unaccepted at the support-owner predicate above; six-case contract below remains binding. Parked B passenger exit/readmission is not a prerequisite or a retry authorization. |
| Remote terminal interaction and one conserved transfer | A uses normal terminal E after its physical exit and delivers one existing crate | Real host body passes live exit≤2.5m eligibility; current terminal action reaches existing cargo owner; source/hold2→1, destination0→1, exactly one completion/reward. Duplicate/stale/foreign attempts change neither stock nor payment. Existing120s activity limit retained. | GATED on accepted pilot body handoff and the existing load/clear-gate/dock phases. Readiness alone is not cargo authority. |
| Complete Loadmaster moving-crew journey | A pilots while B uses Loadmaster, then both complete the specified home/rejoin/handback route with the conserved delivery | Every original moving/chair/action/home/owner-loss/standing-rejoin/physical-exit/reuse case passes, all three processes exit0, no diagnostics, within original900s internal/960s outer bounds | GATED on both capabilities above, accepted standing readmission, guest ramp/exit and the missing ordinary caller. Two prerequisite attempts remain PARKED; their explicit reopening conditions still apply. |

The first delivery has this finite case membership. This is the acceptance
contract, **not a claim of execution or a completed start card**:

| Case | Setup/action | Expected observation |
| --- | --- | --- |
| 1. Actual pilot exit | Actual Main, authenticated ENet A, exact current Hauler pilot grant and occupied attached Cinder berth; request ordinary confirmed departure | Exactly one host production Player starts at the actual host pilot anchor and follows existing seat-exit motion; collision restored and floor support established at the live exit. No fixture spawn at the exit or actor teleport. |
| 2. Walk and publication | After physical completion, send fresh authenticated walking input | Same body moves≥1m under host simulation; publication advances with matching client/body generation. Host local Player/camera and stock/payment snapshots remain unchanged. |
| 3. Physical eligibility | Try existing cargo actor authorization before and after completion | No authorization before completion; actual completed body qualifies only under the existing live source/lease/attachment and≤2.5m exit rule. This does not perform or prove a transfer. |
| 4. Rejected ownership/replay and preserved pilot return | Submit foreign-peer input, duplicate departure and old body-generation/stream input; then same A walks to the actual supported boarding hatch and requests normal pilot BOARD | No second body, unauthorized movement, authorization, debit or reward. Replacement generation is authority-issued and retires the old input stream. Legitimate same-A/same-craft reboard obtains one current pilot grant and usable helm; old exterior body/publication/client prediction retire once before the ordinary boarding presentation. |
| 5. Retirement | Separately disconnect A, invalidate the berth lease and remove the current source/attachment | Each cut retires its body, movement authority and publication once; later packets cannot resurrect or authorize it. |
| 6. Integration and delivery | Run complete existing Halyard remote-pilot/body regressions and the new Cinder cases, then clean-commit checkpoint export and isolated startup | Original regression cases pass; each required command exits0 with its exact success marker and zero diagnostics. Package startup exits0 with exactly one STARTUP_MENU_READY_OK. Accepted source is merged/pushed; build notes state the scoped result; owned cleanup completes. |

Implementation owners are GameFlow, NetworkRemoteBodySimulation and the ENet
adapter, with the existing remote-pilot test extended. Freeze exact paths,
commands, per-case limits, remaining correction allowance and absolute≤90-minute
all-in deadline on the selected card **before code**. If that cannot fit, stop
selection and split the production capability; do not quietly omit a case.
No full-role, cargo, native-hardware or general exterior-networking completion
is implied by the pilot-body member.

### Closed work and retained exceptions

| Result | Status / retained boundary | Proof |
| --- | --- | --- |
| Checkpoint duplicate cleanup | 298 verified duplicates removed /50.2GB reclaimed; five permission mismatches retained and three Linux candidates NOT_RUN at cutoff. Remaining cleanup PARKED. | [Accounting, archive and restore checks](docs/history/ROADMAP_DELIVERIES.md#checkpoint-duplicate-cleanup-cutoff-20261105) |
| Jovian distant exterior | Scoped runtime/image/package PASS; complete craft and native qualification OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#jovian-whole-lod-delivered-20261105) |
| Hauler distant exterior | Scoped runtime/image/package PASS; complete craft and native qualification OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#hauler-whole-lod-delivered-20261105) |
| Bomber distant exterior | Scoped runtime/image/package PASS; complete craft and native qualification OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#bomber-whole-lod-delivered-20261105) |
| Shared retained-Main all-nine | Source identity/claim/home/repair scope PASS; ordinary journey/restart/networking OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#main-nine-component-claims-home-qualified-20261105) |
| Bulwark editable source | Scoped handoff/reproduction PASS; gameplay/art/LOD OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#bulwark-editable-source-handoff-accepted-20261105) |
| Player-motion retained images | Nine image hashes match; source/run/inspection binding missing. GATED; no unchanged search or recapture selected. | [Exact missing artifacts and search boundary](docs/history/ROADMAP_DELIVERIES.md#player-motion-retained-binding-stop-20261105) |

These are selection constraints, **not a list of tasks running in parallel**:

| Existing goal/member | Current result or blocker | Condition before further work |
| --- | --- | --- |
| [Cinder Light role-choice card](docs/history/ROADMAP_DELIVERIES.md#cinder-light-choice-card-fit-stop-20261105) | PARKED: added line needs73px inside63px body in all six existing fit cases | Explicit reprioritization and bounded text packing that preserves exact trade-off/full instructions/facts/state,normal fonts and original case/tolerance limits;retain cost/exhausted allowance |
| [Bulwark whole-craft LOD runtime](docs/history/ROADMAP_DELIVERIES.md#bulwark-lod-cockpit-clearance-stop-20261105) | PARKED: required capture fails two unchanged cockpit-clearance assertions despite source and dimension passes | Log exact failed operands, reconcile original clearance contract, explicitly reprioritize with prior cost/exhausted allowance; no subset acceptance |
| [Halyard whole-craft LOD runtime](docs/history/ROADMAP_DELIVERIES.md#halyard-lod-capture-viewport-stop-20261105) | PARKED: source passes,but captured strip/panel dimensions crop the staged review layout | Explicitly reprioritize exact harness viewport/content scaling;unchanged image/geometry/camera/package gates and prior cost remain |
| [Rime solo access/outbound caller](docs/history/ROADMAP_DELIVERIES.md#rime-solo-outbound-alignment-stop-20261105) | PARKED: consumed look continues after alignment stage changes; four-tick tolerance fails | Measured input cause/correction and explicit reprioritization; no tuning or tolerance change inferred |
| [Cinder remote terminal handoff](docs/ROADMAP_BACKLOG.md#cinder-remote-crew-moving-handback) | Pilot-body attempt is PARKED at the measured support-owner mismatch; terminal transfer remains GATED | Explicit reprioritization plus exact support-contract reconciliation is required before retry; all six cases and prior cost remain; parked B egress remains separate |
| [Eight missing craft baselines](docs/ROADMAP_BACKLOG.md#owner-design-baselines-20261105) | Owner ADOPTED all eight prepared modern designs2026-11-05; Titan minimum pilot loop now brings Main to10/17 | Select dependency-ready build capabilities; no repeat design approval or false construction credit |
| [Halyard fresh-Main re-entry](docs/history/ROADMAP_DELIVERIES.md#halyard-fresh-main-offtree-stop-20261105) | PARKED: off-tree cabin-transform errors during actual HUD Restart Shift; no complete re-entry pass | Focused repair/retry request unanswered; original12:47:51UTC deadline expired. Requires explicit reprioritization, retaining cost and exhausted allowance |
| [Jovian first kit-delivery caller](docs/history/ROADMAP_DELIVERIES.md#jovian-native-caller-pause-epoch-stop-20261105) | PARKED: observer motion epoch jumps across Resume before walking; no movement defect established | Concrete pause/freshness correction and explicit reprioritization; original limits/cost remain |
| [Guided flight-observation caller](docs/history/ROADMAP_DELIVERIES.md#guided-flight-observation-stimulus-stop-20261105) | PARKED: requested120px input observed as about150px; exact cause unmeasured | Demonstrated input-unit cause and explicit reprioritization; no renamed retry |
| [Cinder Light whole-craft LOD](docs/history/ROADMAP_DELIVERIES.md#cinder-light-whole-lod-render-stop-20261105) | PARKED: capture timed out without an image; declared internal watchdog missing | Retry request unanswered and11:12:11UTC deadline expired; explicit reprioritization required |
| [Arrow whole-craft LOD](docs/history/ROADMAP_DELIVERIES.md#arrow-whole-lod-typed-membership-stop-20261105) | PARKED: typed mesh-array membership fails on Node3D | Type-safe correction and explicit reprioritization retaining exhausted allowance |
| [Zenith whole-craft LOD](docs/history/ROADMAP_DELIVERIES.md#zenith-modern-lod-census-stop-20261105) | PARKED: ArrayMesh-only method called on BoxMesh | Concrete mesh-type correction and explicit reprioritization retaining exhausted allowance |
| [Cinder retained-cabin readmission](docs/history/ROADMAP_DELIVERIES.md#cinder-standing-readmission-initial-chair-stop-20261105) | PARKED: initial Navigator chair Interact fails before rejoin | Diagnose that rejection, preserve landing guard, explicitly reprioritize |
| [Cinder guest egress](docs/history/ROADMAP_DELIVERIES.md#cinder-guest-egress-home-gate-stop-20261105) | PARKED: host home-ramp eligibility fails before guest launch | Satisfy the recorded causal reopening and cumulative-cost conditions |
| [Landed-crew browser entry](docs/history/ROADMAP_DELIVERIES.md#landed-crew-admission-ui-entry-stop-20261105) | PARKED: failed before admission; no joining feature accepted | Satisfy its recorded reopening conditions; no subset pass |

Every parked source/result remains recoverable from its linked delivery record.
Owned branches/worktrees/scratch for the closed attempts are cleaned up. Their
complete routes, failures, original budgets and correction limits stay binding;
a new label or automatic continuation cannot reset them.

Previously accepted [Rime arrival guidance](docs/history/ROADMAP_DELIVERIES.md#rime-arrival-guidance-delivered-20261105),
[retired-world residency](docs/history/ROADMAP_DELIVERIES.md#retired-world-residency-delivered-20261105)
and [Ember passive progress](docs/history/ROADMAP_DELIVERIES.md#ember-passive-progress-delivered-20261105)
remain closed in their recorded scopes. Aurora/Rime settled resume retirement,
Ember Save Progress, Arrow guidance and exported dedicated startup also retain
their accepted scopes. Halyard physical egress and Ember outbound remain parked
at their previously recorded station-spawn and planetary-gravity caller failures.
Do not reselect accepted components or use them to pass an unperformed full journey.

## Read this as a delivery plan

The [canonical backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
retains the original requirements and their detailed acceptance contracts.
Its 337 records include containers, definitions and decisions; **337 is not the
number of coding tasks left**. The [36 original outcomes and ten phase gates](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
remain open. Accepted and failed attempts belong in the
[delivery history](docs/history/ROADMAP_DELIVERIES.md), not in the next-work queue.

Use these three levels:

| Level | What it means | When it closes |
| --- | --- | --- |
| Product outcome | A complete craft, activity, world journey or release requirement | Every named child and its complete integration gate passes |
| Delivery goal | One independently usable game behavior or executable build capability | The fixed player/build action passes, accepted code is merged/pushed, required checkpoint is available and owned cleanup is complete |
| Qualification goal | One named journey, package, hardware or device check | Its original complete cases pass on the declared candidate and environment |

A source map, specification, test fixture or passing component check does not
close a delivery goal for a behavior it has not demonstrated. A completed child
does not close its parent. An unavailable owner decision or device is a named
blocked dependency, not an indefinite coding assignment.

<a id="current-planning-goal-finish-the-executable-breakdown"></a>

## One goal, one result, one stopping point

The existing [337-record backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
retains the requirements and their acceptance contracts. The backlog inventory
and goal classification are closed; do not repeat them. Missing acceptance
fields and owner inputs remain blocked as recorded in their contracts. The
records include completed work, broad containers, implementation, qualification
and owner decisions. They are not 337 unfinished coding tasks. The eight delivery groups below organize that scope;
none is an executable assignment.

Select a bounded child or an explicitly named member of its existing contract.
Give independently deliverable behaviors separate cards. Keep the complete
ordinary journey as a required integration goal; smaller checks never replace
it. No implementation may start from “finish the ship”, “improve multiplayer”
or another broad heading.

## How we will work from this roadmap

### Task card required before starting

Keep the selected card in [Current work](#current-work-and-next-selection),
using the existing goal ID and contract. Fill every field before editing code:

```text
Goal / contract: existing ID and exact member; link to its acceptance contract
Result: one observable player behavior or executable build/release result
Candidate / start: source or package, initial state, location and participants
Owner / files: implementer and exact files; reviewer when needed
Dependencies: prerequisite IDs and accepted results; missing input + owner
Cases: complete finite list, with ordered ordinary actions or literal commands
Expected: observable endpoint/value for EACH case, including preserved behavior
Proof: output location, environment and which scope it can establish
Budget: all-in estimate, absolute start/deadline, original test limits
Stop: correction allowance, independent abort, first-failure endpoint
Close: actual versus expected, status, elapsed cost, merge/push/build/cleanup
```

**A link alone does not fill a field.** Resolve the linked contract to its actual
cases and expected observations on the card. Reuse its values and limits; do not
invent numerical thresholds. A case should read “given this state, perform these
actions, observe this result”. Words such as “polished”, “robust”, “usable” or
“all applicable” need the literal observation that makes them pass or fail.

Use this small table for the cases, then fill the last column at closure:

| Case | Initial state and action | Expected result | Actual result and proof |
| --- | --- | --- | --- |
| Each named case | Exact setup and steps/command | Observable endpoint/value and preserved state | NOT_RUN until performed; then measured result and artifact |

### Missing information has an endpoint

| Situation | Required next action | When that action ends |
| --- | --- | --- |
| Contract field missing | Codex supplies that exact field in its existing contract, using a 15–30 minute bounded definition pass | Finite answer recorded, or exact absent value/artifact, completed search boundary and owner recorded; no rolling research |
| Product choice or external resource missing | State the exact question/artifact and its owner using the [existing input contracts](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources) | Answer/resource recorded; no inferred approval and no blocked implementation |
| Runtime or ordinary caller missing, but behavior defined | Select its bounded implementation with a fixed check | Implemented result passes that check, or failure is parked; a caller/component check alone cannot qualify the ordinary journey |
| Prerequisite unfinished | Name its existing ID and required result | Dependency actually passes before dependent work launches |
| Earlier attempt parked | Retain its failure, source, cumulative cost and causal reopening condition | Reopen only under that condition; exhausted allowance/deadline also requires later explicit user reprioritization |

An undefined goal is **BLOCKED definition**; an unavailable choice/resource is
**BLOCKED input**; an unfinished prerequisite is **GATED**. OPEN and UNSCHEDULED
never mean READY. No missing field authorizes an open-ended assignment.

### Fixed budget and failure boundary

Estimate implementation, checks, required checkpoint, integration and cleanup
**together**, at no more than 90 minutes per implementation assignment. Split
larger production capabilities before starting. Full journeys and soaks retain
their original durations; do not shorten them to fit an implementation card.
Default correction allowance is one; freeze it and the absolute deadline first.

Stop dependent checks at the first unexpected failure and retain its actual
operands/output. Every correction needs a demonstrated cause and cumulative-cost
decision. **Routine compiler errors and incorrect test assertions are normal
implementation repairs inside the unchanged absolute time budget. They do not
require owner permission or consume the substantive-behavior correction limit.**
They still require a clean candidate and rerunning the complete affected gates;
no check, threshold or endpoint may be dropped to obtain a pass.

Frozen correction allowances apply to substantive production/behavior repairs.
Their exhaustion, an unresolved product requirement or the hard deadline parks
the task. New names, branches or smaller subsets never reset cumulative cost or
extend a deadline. Expired or substantively blocked parked attempts retain their
recorded reopening conditions and explicit priority decisions. This is not a
blanket retry of old work. No dependent check starts before its prerequisites
pass; unrelated defects return to their existing owner. Ask the user for real
product/scope/resource decisions, not approval to repair a mistake in a test.

### What counts as finished

A goal is PASS only when **every frozen case passes in the declared scope**,
accepted changes are merged and pushed, any required playable checkpoint is in
`builds/windows/`, and owned branches/worktrees/processes/scratch are cleaned.
Preserve unique rejected source and results before deleting their task refs.
Report retained exceptions. An unfinished task closes as FAIL, BLOCKED or PARKED
with the exact next input/reopening condition; do not quietly move to another
branch. No automatic successor is scheduled by closing a card.

Source tests establish their source scope; staged setup does not establish
ordinary access, and Linux/software rendering does not establish native Windows
or target-GPU performance. Required physical-device and human checks stay open
until performed, subject to the recorded owner exclusions. A completed definition
or child never closes an unperformed gameplay journey or its parent container.

Progress reports use **goal → player/build result → status → proof → blocker →
elapsed cost → next action**. Definitions, validators, test counts and commits
are not a project percentage. Do not invent a finish date from the row count.

## What finishing means

The full original scope is retained. A smaller release would require an explicit
scope decision; this plan does not make one.

| Delivery | Concrete finish line | Canonical goals |
| --- | --- | --- |
| Complete game loop and station | Final-package Guided 3/3, original all-nine/54-waypoint Sandbox/recovery 1/1 and original Settings/re-entry 1/1; all nine named station branches physically usable, required interactions/revisit complete | [Core and station proof](docs/ROADMAP_BACKLOG.md#proof-core) |
| All 17 craft | All twelve originals plus five modern additions exist; each passes its specified boarding, flight, actual functions, damage/recovery, strict home landing/exit/reuse, cross-craft and Main re-entry checks | [Craft proof and missing specifications](docs/ROADMAP_BACKLOG.md#proof-craft) |
| Combat and twelve activities | Real player weapons achieve the named encounter results; every activity completes its actual objective, durable result and usable home return; all twelve required ten-run repeats and Hulk revisit pass | [Combat](docs/ROADMAP_BACKLOG.md#proof-combat), [activity proof](docs/ROADMAP_BACKLOG.md#proof-activity) |
| Three worlds and shared travel | Complete Ember, Aurora and Rime canonical physical round trips, required survey/reward/save/abandonment outcomes and all 21 explicitly named shared-world cases | [World proof](docs/ROADMAP_BACKLOG.md#proof-world) |
| Supported multiplayer | Complete server/two-client baseline and remaining role/helm/actor/browser/reconnect cases; original 30-minute session with required adverse networking; chosen supported capacity qualified | [Multiplayer proof](docs/ROADMAP_BACKLOG.md#proof-network) |
| Durable recovery | Named real-file interruptions restart in the settled supported state, preserve accepted progress/debt, pay once and permit ordinary continuation; migration/corrupt/unsupported data handled correctly | [Recovery proof](docs/ROADMAP_BACKLOG.md#proof-recovery) |
| Presentation and hardware quality | Existing 13 capture sets/143 PNGs reviewed; required UI/device/comfort/audio cases pass; representative actual hardware meets declared performance budgets | [Quality proof](docs/ROADMAP_BACKLOG.md#proof-quality) |
| Ship the exact candidate | Unfiltered local matrix, required ordinary routes, packages/install transactions, rights, trusted signing and authorized downloadable-byte identity pass on one integrated candidate | [Release proof](docs/ROADMAP_BACKLOG.md#proof-release) |

Parents 3/27 share the same 21 world cases; 6/35 share one final matrix; 11/21
share the damage work. Breach/Torpedo combat and activity journeys are reused,
not counted as duplicate deliveries. [All 36 promises and ten gates](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes).

[Final defect reconciliation](docs/ROADMAP_BACKLOG.md#final-candidate-defect-inventory)
now specifies the existing ledger/result inputs, candidate build-note inventory
and exact blocking verdict. Actual candidate review and implementation/qualification
remain open; zero known bugs alone cannot pass unfinished release journeys.

[Torrent remaining damage](docs/ROADMAP_BACKLOG.md#torrent-remaining-contact-repair-contract)
now fixes hit budgets and actual component consumers. It also identifies the
missing legitimate return path after wing/engine failure: the defender phase
blocks landing, so those cases cannot yet be selected for execution.

Existing [docking recovery](docs/ROADMAP_BACKLOG.md#installed-recovery-exact-cuts),
[Halyard engineer](docs/ROADMAP_BACKLOG.md#halyard-engineer-moving-return),
[Zenith contact/repair](docs/ROADMAP_BACKLOG.md#zenith-remaining-contact-repair-contract)
and [caption episode](docs/ROADMAP_BACKLOG.md#caption-ordinary-episode-contract)
contracts already define their acceptance fields. Their remaining work is the
named implementation and qualification, with parked prerequisites preserved;
do not restart those definition surveys from stale status wording.

[Packaged Ember abandonment](docs/ROADMAP_BACKLOG.md#ember-packaged-physical-abandon-contract)
now names the real pause-menu action, incomplete checkpoint/data checks and
physical home/reuse endpoint. Its normal Save integration and complete input
caller remain missing; the parked outbound gate remains a prerequisite.

[Exported dedicated authority](docs/ROADMAP_BACKLOG.md#packaged-dedicated-authority-contract)
now has a concrete Boot/CLI, listening, orderly one-session exit and packaged
two-client acceptance contract. The accepted source harness remains narrower;
normal Boot launch and optional orderly session exit are delivered on24ed6bc86;
packaged gameplay participation and full qualification remain open.

## Selecting work after the breakdown

Select one ready delivery or qualification goal from an existing row; fill its
card before editing or running checks. A broad craft/activity/world container is never one assignment. Follow
literal prerequisite IDs; independent ready capabilities may run in parallel
with disjoint ownership. A parked task needs its recorded causal reopening
condition and cumulative-cost decision before selection; exhausted limits also
require the explicit user reprioritization described above.

Close each assignment before moving on: actual result and proof, merge/push
accepted changes, required playable checkpoint, and owned branch/worktree/process
cleanup. Preserve unique rejected source without merging it. Report retained
exceptions explicitly. A new failure belongs to its existing goal; it does not
automatically enlarge the current task.

## Validation and final release

Automated Godot always uses Dummy audio, headless or private Xvfb with explicit
x11. Audible output requires authorization. GitHub Actions remains disabled.
Native Windows execution and mandatory human review remain owner-excluded;
unperformed facts stay NOT_RUN. Applicable Linux/native GPU/device/audio gates
remain; simulated checks cannot supply physical measurements.

The final exit is one accepted candidate with zeroP0/P1, explicitP2 dispositions,
required complete ordinary journeys and unfiltered local matrix, matching
installable artifacts, settled rights/signatures and authorized downloaded-byte
identity. All [ten phase exits](docs/ROADMAP_BACKLOG.md#original-phase-gates-and-completion)
remain binding. Missing design decisions or hardware access stay named blockers;
they do not become indefinite implementation tasks.
