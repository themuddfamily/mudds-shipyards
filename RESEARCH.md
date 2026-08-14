# Keth Shipyards research dossier

Last updated: 2026-08-14

All linked sources were accessed on 2026-08-12 unless noted otherwise. Wayback
dates below identify the capture; a page's own “updated” date can be earlier.

## Purpose and status

This file records what can presently be established about ZolarKeth's original
Roblox experience *Keth Shipyards*. Its purpose is to keep the standalone remake
recognisable while separating observed history from design inference.

The evidence is useful but incomplete. The strongest surviving material proves
the broad station language, the physical walk-to-a-ship loop, a versioned ship
roster, changing controls, arcade combat, and a frame-resolved name-to-model lock
for the **Torrent-class Interceptor shown in B5, footage uploaded in June 2011**.
That upload date does not establish the recording date or live build revision.
The evidence also does **not** yet prove an exact floor plan, dimensions, physics
values, a complete fleet-wide name-to-model mapping, or that the B5-observed
Torrent was unchanged from the 2009 launch build. Those gaps must not be filled
by treating the remake brief,
*Keth Shipyards II*, or a fan recreation as evidence about the original.

### Confidence scale

- **High:** creator-authored or official Roblox record, or an unambiguous event
  visible in contemporary gameplay.
- **Medium:** direct visual observation whose exact build, object name, or context
  is uncertain, or a fact corroborated by more than one non-authoritative source.
- **Low:** later recollection, community recreation, ambiguous video frame, or an
  inference awaiting corroboration.

### Source tiers

- **A — primary:** official Roblox metadata, creator-owned assets, and archived
  creator-written descriptions/comments.
- **B — direct contemporary observation:** player-recorded footage uploaded from
  2010–2012. Strong for what appears on screen; weaker for exact recording date,
  live build provenance, and hidden mechanics.
- **C — later/secondary:** later fixed-build walkthroughs, contemporary-player
  recollections written years later, and preservation/recreation projects.
- **D — design only:** the remake brief and this project's proposals. These are
  requirements or hypotheses, never evidence of the old game.

The machine-readable [source ledger](docs/research/source_ledger.json) mirrors
the A1–A10, B1–B7, and C1–C3 register below with typed date events, exact
observation anchors, inspected-rendition hashes where available, limitations,
and a rights boundary. The repository deliberately excludes third-party source
media; see the [research evidence policy](docs/research/README.md).

## Version boundaries

The name “Keth Shipyards” refers to several related but non-interchangeable
artifacts.

| Label used here | Identity | What may be inferred |
| --- | --- | --- |
| **Original-era Keth Shipyards** | Roblox place `9287346`, created 2009-03-28 by ZolarKeth (`2629700`); archived descriptions and 2010–2012 footage | Primary target for identity, original roster, layout, controls, and play patterns. The experience changed repeatedly even within this era. |
| **Keth Shipyards [Fixed]** | The same place `9287346`, universe `17657420`, repaired and last updated 2017-05-21 | Canonical continuation and valuable preservation reference, but a 2017 visual or control cannot automatically be projected back to 2009. |
| **Keth Shipyards II** | Separate place `18630606`, universe `27644502`, official sequel by ZolarKeth | Context only. Its inventory, economy, allegiance, warp, and `sell/ship` systems are sequel features. |
| **Keth Shipyards: Reboot** | Community recreation, place `340772270`, universe `125891602`, by user `71228031` | Secondary corroboration only. It is not the official/fixed build and may contain reconstruction choices. |

The original and fixed versions share a place ID, but controls, ship counts, and
station content changed over time. Every implementation claim should therefore
carry a date/build qualifier when possible.

## Source register

### Tier A: primary and official

- **A1 — Current official/fixed experience:** [Keth Shipyards [Fixed]](https://www.roblox.com/games/9287346/Keth-Shipyards-Fixed).
  The creator description calls it a deep-space ship construction facility that
  produces and stores small-to-mid-sized vessels and lists the repaired-era
  controls. Creator: ZolarKeth.
- **A2 — Official identity metadata:** [place-to-universe lookup](https://apis.roblox.com/universes/v1/places/9287346/universe)
  and [universe metadata](https://games.roblox.com/v1/games?universeIds=17657420).
  These establish place `9287346`, universe `17657420`, creator `2629700`,
  creation date 2009-03-28, last update 2017-05-21, ten-player server size for
  the fixed listing, and `copyingAllowed: false` in the API response.
- **A3 — 2009-11-12 archived official page:** [Wayback capture](https://web.archive.org/web/20091112091226/http://www.roblox.com/Item.aspx?ID=9287346).
  This is the best creator-authored original-era roster and role description.
  It also records the 2009 controls, chat-based regeneration, cleanup voting,
  and contemporary comments by ZolarKeth and players.
- **A4 — 2010-01-09 archived official page:** [Wayback capture](https://web.archive.org/web/20100109100101/http://www.roblox.com/Item.aspx?ID=9287346).
  The page says the Salyut-class Transport had arrived, gives a total of twelve
  completed ships, and records the `Land`/`Hover` control variant. It also
  exposes the Explorer and Very Important Pilot badge descriptions.
- **A5 — 2010-02-05 capture of the official page updated 2010-01-28:** [Wayback capture](https://web.archive.org/web/20100205194948/http://www.roblox.com/Item.aspx?ID=9287346).
  This names the VIP Zenith-class Interceptor, says piloted vehicles (worded as
  “Planes”) were removed when their pilot died, and repeats the twelve-ship count
  and controls.
- **A6 — 2010-11-30 archived official page:** [Wayback capture](https://web.archive.org/web/20101130043701/http://www.roblox.com/Keth-Shipyards-item?id=9287346).
  This records eleven completed ships and `D` to undock, in addition to start,
  land, hover, fire, and chat regeneration.
- **A7 — 2015-12-08 archived official page:** [Wayback capture](https://web.archive.org/web/20151208133335/http://www.roblox.com/games/9287346/Keth-Shipyards).
  This is evidence for the repaired-era `G` barrel-roll binding, not proof that
  the 2009 release used it.
- **A8 — Official 2017 media:** [media listing](https://games.roblox.com/v2/games/17657420/media),
  [creator-owned image asset `672638117`](https://economy.roblox.com/v2/assets/672638117/details),
  and [current image lookup](https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=17657420&countPerUniverse=10&defaults=true&size=768x432&format=Png&isCircular=false).
  The asset was created by ZolarKeth on 2017-02-27 and is the strongest official
  fixed-build station/fleet overview.
- **A9 — Official VIP shirt:** [asset `18848794` metadata](https://economy.roblox.com/v2/assets/18848794/details)
  and [catalog page](https://www.roblox.com/catalog/18848794/Keth-Shipyards-VIP-Shirt).
  The creator-written 2009 description names a Zenith-class Fighter and documents
  the VIP Room's jetpack and armour, sparkles, Gravity Coil, and Super Jump.
  Its “Fighter” label conflicts with A5's “Interceptor” label.
- **A10 — Official sequel:** [Keth Shipyards II](https://www.roblox.com/games/18630606/Keth-Shipyards-II)
  and [metadata](https://games.roblox.com/v1/games?universeIds=27644502).
  This establishes the separate place/universe and version `0.9.1`; it documents
  `W` to warp, an allegiance GUI, and the `sell/ship` command only for the sequel.
### Tier B: contemporary gameplay footage

Video timestamps are observation anchors, not claims that every visible effect
was intentional. Old Roblox gear, replication, and physics can imitate built-in
weapons or destruction.

- **B1 — [Space Wars In Keth Shipyards](https://www.youtube.com/watch?v=nGvBdddnt38)**,
  uploaded 2010-04-25. Around `0:12`, an angular light-coloured craft appears in
  chase view. Approximately `0:51–2:18` shows close planetary flight, multiple
  craft, combat/explosions, and brick debris. Best original-era combat reference.
- **B2 — [Keth Shipyards Adventure In Roblox](https://www.youtube.com/watch?v=GrnNU2w6FlA)**,
  uploaded 2011-06-09. `0:00–1:20` shows the regeneration/control room;
  approximately `1:56` shows launch, `2:20` exterior chase flight around the
  station, and `5:40` a return to the station. Later sequences show another,
  larger vessel and nearby coloured planets.
- **B3 — [Roblox — Keth Shipyards](https://www.youtube.com/watch?v=7DytRUUhEQI)**,
  uploaded 2012-03-23. The walkthrough repeatedly moves between exterior decks,
  interior controls, regeneration points, ships, and space. In the decoded
  `640x360`, `6 fps` source, the Titan message begins at `05:10.000` (`f1860`)
  and remains with the same long pale craft through `05:13.000` (`f1878`). The
  next frame, `05:13.167` (`f1879`), changes only the message to Torrent; no
  craft changes or appears. The Torrent message persists through `05:17.000`
  (`f1902`) and is absent at `05:17.167` (`f1903`). This corroborates both label
  strings but is negative evidence for identifying the visible craft as Torrent.
  Later messages corroborate Arrow, Altair, and Katana labels.
- **B4 — [Jommy101 Video Keth Shipyards My Favorite Ships](https://www.youtube.com/watch?v=W32fCS_Fif8)**,
  uploaded 2012-05-06. The description repeats the official control set. In the
  inspected `640x360`, `6 fps` rendition, chat contains `Torrent` at
  `04:49.667` (`f1738`) and the exact message “Regenerating Torrent-class
  Interceptor” begins at `04:49.833` (`f1739`). A fixed distant berth remains
  empty through `04:50.167` (`f1741`), then gains a pale craft at `04:50.333`
  (`f1742`) in the same uncut shot. The message lasts through `04:53.000`
  (`f1758`) and is absent at `04:53.167` (`f1759`); Predator follows at
  `04:53.833` (`f1763`). This is a medium-high-confidence name-to-instance link,
  but the craft is only about `61x32` pixels and ladder-obscured, so it supplies
  no reconstruction-grade view. Later messages identify Jovian, Titan, Paradox,
  Katana, and Vortex; earlier footage shows seats, flight, collision, and debris.
- **B5 — [keth shipyard.wmv](https://www.youtube.com/watch?v=gcYx2zm1TfI)**,
  uploaded 2011-06-29 by army22nd. The highest public rendition is `640x480`,
  constant `30 fps`, 2,753 frames. At `00:10.200` (`f306`) the exact message
  “Regenerating Torrent-class Interceptor” appears above a fixed empty berth; the
  berth stays empty through `00:10.700` (`f321`) and the craft materialises at
  `00:10.733` (`f322`) without a cut. The message remains through
  `00:13.833` (`f415`) and is absent at `00:13.867` (`f416`). The avatar
  continuously approaches and enters it around `00:13.000–00:15.500`, occupies
  the visible red seat around
  `00:15.500` (`f465`), and reaches direct chase view by
  `00:16.833–00:17.000` (`f505–f510`). The same piloted craft is visible from
  rear/dorsal (`00:23.000`, `f690`), side/top (`00:29.000`, `f870`), and close
  side/front (`00:41.000`, `f1230`) views. This uncut
  label-to-empty-berth-to-spawn-to-boarding-to-flight chain is the decisive
  high-confidence lock for the B5-observed Torrent model. The June 2011 upload
  date does not verify when it was recorded or which live build revision it
  shows. Do not use views after the unrelated Atlantis regeneration begins
  around `00:46.5`.
- **B6 — [Roblox Space Stunts By Caine2000](https://www.youtube.com/watch?v=duOswIVCYKQ)**,
  uploaded 2011-04-21 by CaineTheAwesomenator. In the highest public `854x480`,
  constant `6 fps` rendition, the Torrent message begins at `05:31.167`
  (`f1987`) and persists through `05:34.500` (`f2007`). A camera turn at
  `05:32.667–05:33.333` (`f1996–f2000`) exposes a partly occluded pale pointed
  craft at the berth before the clip ends at `05:34.667` (`f2008`). This is
  independent medium-high-confidence corroboration of the label/berth and a
  broadly compatible craft family, but not an adequate multi-view lock alone.
- **B7 — [The Flight](https://www.youtube.com/watch?v=J0GVOdxftXI)**,
  uploaded 2012-03-18 by Becker260. The registered public rendition is
  `2,264,402` bytes, `854x480`, constant `11 fps`, and 48 seconds, with SHA-256
  `c716c506d9fd7042ac98720e8815725cf083d24967bc8c9f842cdfa58e8ca144`.
  “Regenerating Zenith-class Interceptor” begins at
  `00:33.455` (`f368`); the berth remains empty through `00:33.818` (`f372`),
  then a pale delta/arrow craft appears at `00:33.909` (`f373`) in the same
  near-static shot. The message lasts through `00:36.818` (`f405`). Continuous
  approach, boarding, and flight identify that craft as Zenith through
  `00:42.455` (`f467`), before a discontinuity at `f468`; `f468+` is excluded
  from the identity chain. This is a strong B7 name-to-model lock in footage
  uploaded in 2012, not proof of a 2012 recording or build. Its wide swept
  delta/arrowhead imagery must not be reassigned to Torrent. The bounded feature
  index and rights-safe reconstruction constraint are frozen in the
  [B7-observed Zenith specification](docs/ZENITH_B7_RECONSTRUCTION_SPEC.md).

### Tier C: later reference and memory

- **C1 — [ZolarKeth's Keth Shipyards](https://www.youtube.com/watch?v=WyFl8VkzsMY)**,
  uploaded 2025-10-01 and described by its uploader as recorded before a Roblox
  access purge. This is a legible later secondary walkthrough: roughly `0:00`
  exterior deck and parked ships, `1:20` habitat entry, `1:50` bunks, `2:00`
  chair-lined corridor, `2:30` consoles, `3:20` red VIP area, and `4:50` exterior
  ship lineup. Its exact recording date, place revision, and fixed-build provenance
  have not been independently established; it is not launch-era evidence.
- **C2 — [CJ_Oyer's 2020 Roblox Developer Forum recollection](https://devforum.roblox.com/t/closed-programmerartist-for-fall-accelerator-program-game/618544)**.
  A contemporary player recalls that Keth Shipyards was highly influential,
  featured fun ships that could be walked around inside, and enabled memorable
  space roleplay. This is strong nostalgia testimony but not geometry evidence.
- **C3 — Community reboot metadata:** [experience page](https://www.roblox.com/games/340772270/Keth-Shipyards-Reboot)
  and [metadata](https://games.roblox.com/v1/games?universeIds=125891602).
  Its author credits ZolarKeth and says they recreated the structure, ships, and
  scripts. The stated private approval is not independently verifiable. This is
  useful when it agrees with A/B sources, but never the sole basis for an
  “original” detail.

## Shipyard structure

### What is established

The current creator description calls the setting a **deep-space construction
facility that produces and stores small-to-mid-sized starships** (A1). The dated
creator pages separately establish original-era fleet rosters and changing ship
counts (A3–A6). Contemporary footage B2–B4 supports parked ships and physical
access; those visual details should not be attributed to the written descriptions
alone. **Confidence: high for the documented facility purpose and dated rosters;
medium-high for the combined physical-play interpretation.**

The observed station language across B2–B4 is:

- a mostly grey, open-to-space modular structure;
- a central spine/lattice with broad walkable decks and narrower projecting arms;
- ships parked physically beside or upon walk-up platforms and approached on foot;
- ladders or short vertical transitions between deck levels;
- boxy enclosed rooms inserted into the otherwise exposed framework;
- a regeneration/control area with labelled controls and coloured push buttons;
- rooms or large-ship spaces with chairs, banks of screens/consoles, and broad
	windows; their exact station function is uncertain;
- blue pads/buttons and a conspicuous red VIP door/area; and
- direct sightlines from station interiors and platforms to ships, planets, and
  ongoing activity in space.

These features recur in contemporary footage. **Confidence: medium to high for
the feature list, low for their exact relative placement.**

A8 shows the fixed station from outside as an asymmetric modular dock lattice:
multiple rectangular grey booms and blocks radiate around a central cluster, with
several parked ships at different orientations. It supports the overall spatial
language, but not an exact 2009 plan. **Confidence: high for the 2017 build,
medium for continuity with the original.**

C1 additionally shows bunks, a long chair-lined corridor, console rooms, and the
VIP area. Its uploader describes it as a later preserved recording, but exact
build provenance has not been independently established. Treat these as later
secondary reference until individually corroborated. **Confidence: medium for
the visible motifs in that recording; low for build provenance and launch-era
applicability.**

### Development-history clue

The 2009-11-12 archived comments in A3 are valuable version evidence. ZolarKeth
asked players about adding a central command section with computers, chairs, a
meeting room, and turret defences. A player independently requested a command
room and bunks. Therefore, those features were planned or requested at that
snapshot rather than safely assumed to have existed from launch. Later footage
contains console/chair/window spaces, but its room purpose, station-versus-ship
context, build date, and relationship to that proposal are not all secure.
**Confidence: high for the archived proposal; medium or lower for attributing
later rooms to a particular command facility or revision.**

In the same comments, ZolarKeth explained that a ship called the Corona had been
removed because it approached one thousand bricks—about one third of the
shipyard's brick count—and acknowledged that easier landing would be difficult
to implement. This is useful evidence of the old scale/performance constraints
and the importance of landing, but it is not enough to reconstruct the Corona.
**Confidence: high for the statement, absent for Corona geometry.**

### Layout facts still missing

No authoritative floor plan, dimensions, coordinate system, complete spawn map,
or orthographic station views have been located. Do not assign numerical scale
from perspective screenshots alone. The tracked
[confidence-graded topology](docs/research/STATION_TOPOLOGY.md) therefore keeps
B2, B3, A8, C1, and the live implementation in separate scopes, labels every
relationship as observed, fixed-era-only, later-source-only, inferred, or
modern, and records no historical coordinates. Roblox avatar height may be used
only as a rough relative scale after correcting for camera field of view.

## Known ship roster

### Best creator-authored original roster: 2009-11-12

A3 says the facility housed ten completed ships and gives useful role text.

| Ship | Creator-authored role/detail | Confidence |
| --- | --- | --- |
| **Jovian-class Light Freighter** | Light freighter | High |
| **Titan-class Medium Transport** | Medium transport | High |
| **Vortex-class Troop Transport** | Troop transport | High |
| **Torrent-class Interceptor** | Interceptor | High |
| **Paradox-class Cruiser** | Cruiser; described as the first warship produced at Keth Shipyards | High |
| **Katana-class Fighter** | Fighter | High |
| **Predator-class Detention Ship** | Specialised in transporting criminals | High |
| **Dynamic-class Gunship** | Small, powerful gunship | High |
| **Utopia-class Dropship** | Able to bring supplies to the front lines during battle | High |
| **Arrow-class Recon Ship** | Reconnaissance ship with two escape pods | High |

### Later additions and count changes

| Ship/change | Evidence | Interpretation |
| --- | --- | --- |
| **Salyut-class Transport** | A4 calls it new and says the station housed twelve completed ships | High-confidence addition by the A4 capture on 2010-01-09; the other ship needed to reach twelve is not enumerated on that page. |
| **Zenith-class Interceptor / Fighter** | A5 calls it the VIP Zenith-class **Interceptor**; A9 calls it the Zenith-class **Fighter**; B7's 2012 runtime message says **Interceptor** and securely links that label to a pale delta/arrow craft | High-confidence ship; strong 2012 name-to-model lock. The creator-written Fighter/Interceptor wording remains a build/date conflict, so preserve both as dated labels. |
| **Altair-class Light Fighter** | On-screen regeneration label in 2012 footage B3 | Medium-high for presence in that 2012 build; no creator-written role or launch-era proof yet. |
| **Eleven completed ships** | A6, 2010-11-30 | The fleet was not a fixed immutable set. One or more ships were removed or rotated; the page does not identify which. |
| **Corona** | ZolarKeth's archived comment in A3 says it was removed for its high brick count | High for prior existence/removal, insufficient evidence to include in the initial remake fleet. |

B3 and B4 collectively corroborate regeneration labels across this roster, but
not every name appears in both recordings. B3 shows Titan, Torrent, Arrow,
Altair, and Katana; B4 shows Torrent, Predator, Jovian, Titan, Paradox, Katana,
and Vortex. B5 and B6 independently show Torrent in footage uploaded in 2011;
their upload dates do not establish recording dates or live build revisions.
These are not complete roster snapshots. A regeneration label alone does not identify whichever ship is
already visible: B3 demonstrates a Titan-to-Torrent label change over the same
unchanged craft. B4 and, decisively, B5 identify the regenerated instance by
holding on an empty berth until a new object appears.

### Minimum evidence required per remake ship

Before calling any model an original-ship remake, record:

1. an authoritative name/build source;
2. at least two views that can be tied to that name, not merely nearby footage;
3. silhouette, relative avatar scale, primary/accent colours, cockpit position,
   engine count/location, access route, seats/interior, and weapon hardpoints;
4. observed role and handling separately from inferred modern role;
5. source timestamps and confidence for every non-obvious choice; and
6. conflicts between builds rather than silently choosing one.

No surviving source currently satisfies all six requirements for every ship.
A3 and B3–B7 clear requirements 1, 2, 5, and 6 for the B5-linked Torrent and
supply most of requirement 3. B5 observes flight but does not isolate or
measure class-specific handling, so requirement 4 remains partial. A5, A9 and
B7 now clear requirements 1, 2, 5, and 6 for the deliberately versioned
**B7-observed Zenith Interceptor** scope and supply a bounded subset of
requirement 3. They do not resolve exact dimensions, access, systems, interior,
materials or class-specific handling, and the A9 Fighter/A5+B7 Interceptor role
conflict remains explicit. Neither craft is therefore a fully specified or
authenticated original-ship reproduction.

## Visual direction of the original/fixed experience

### Supported motifs

Across A8 and B1–B4, the recognisable look is:

- clean, angular, low-part-count spacecraft with broad readable silhouettes;
- light grey/off-white primary hulls over darker grey station structure and
  understructure;
- restrained cyan/blue cockpit glazing or panels, warm yellow/gold nose/window
  accents, and occasional small green/red/blue interaction colours;
- an almost black starfield with dense small stars;
- conspicuously close, simple spherical planets/moons in saturated green,
  pale tan/cream, grey, and orange; and
- exposed decks and large windows that keep ships and the space backdrop visible.

The combination is brighter and more toy-like/readable than a uniformly dark,
grey military setting. Modernisation should preserve the shape hierarchy and
colour blocking even when adding plating, engines, glass, lights, and materials.
**Confidence: medium-high for the broad palette relationship, not exact values.**

Approximate rendered swatches sampled from A8 are included only as blocking
guides, **not canonical material values**:

| Use | Approximate rendered colour |
| --- | --- |
| Space | `#020204` |
| Dark station grey | `#5e5d61` |
| Mid hull grey | `#979698` |
| Bright hull highlight | `#f5f5f6` |
| Warm yellow accent | `#c5b36f` |
| Dark cyan/blue panel | `#2e4c5a` |
| Green-planet midtone | `#5a9b58` |

Lighting, compression, and the thumbnail renderer alter these values. Modern
materials should use them as relative relationships—dark structure, pale ship,
small readable colour—not as exact texture samples.

### Missing visual reference

Still needed are launch-era station wide shots, orthographic or reliably
name-linked views of every ship, cockpit/weapon close-ups, colour references from
more than one renderer, UI/control prompts, spawn locations, landing/docking
sequences, and original audio. Legacy thumbnails referenced by archived HTML do
not appear to have surviving image payloads in the captures examined so far.

## Flight behaviour and controls

### Controls changed by build

| Snapshot | Creator-listed controls | Other creator-listed interaction | Confidence |
| --- | --- | --- | --- |
| 2009-11-12 (A3) | `Y` Start; `X` Stop; `F` Fire; `D` Drop Cargo | Say ship name to regenerate it; `clean`/`cleanup` starts a majority vote | High |
| 2010-01-09 archived page (A4) | `Y` Start; `X` Land; `H` Hover; `F` Fire | Say ship name to regenerate; `clean`/`cleanup` vote | High |
| 2010-01-28 page captured 2010-02-05 (A5) | `Y` Start; `X` Land; `H` Hover; `F` Fire | Say ship name to regenerate; pilot death removes the piloted vehicle (called “Plane” on the page) | High |
| 2010-11-30 (A6) | `Y` Start; `X` Land; `H` Hover; `F` Fire; `D` Undock | Say ship name to regenerate | High |
| repaired/fixed era (A1, A7) | `Y` Start; `X` Stop; `H` Hover; `F` Fire; `G` Barrel Roll | No complete movement map in the current description | High for fixed build only |

This history matters: `X` changed meaning and `D` changed from cargo drop to
undock. A “Classic Controls” preset must select a named snapshot or expose those
conflicts; there is no single timeless classic key map.

### Observed flight character

B1–B4 show immediate third-person/chase flight, close manoeuvring around the
station and large nearby spheres, and ships that can collide and break into loose
parts. Start, land/stop, hover, fire, undock, and later barrel roll support an
arcade vehicle model rather than orbital simulation. Physical cockpits/seats and
station parking connect on-foot and flight play. **Confidence: high for the
overall arcade character, medium for any specific handling claim.**

No reliable measurements exist for acceleration, maximum speed, yaw/pitch/roll
rates, inertia, braking, hover damping, mouse steering, or per-ship differences.
Do not reverse-engineer numerical values from low-frame-rate video without first
calibrating camera motion and scale. The modern remake may tune differentiated
handling, but those values will be new design rather than recovered fact.

## Boarding, player movement, and physical interaction

B2–B4 collectively support the following characteristic physical-play motifs;
the cited footage does **not** establish every step as one uninterrupted run or
prove that every build exposed the same complete sequence. B1 separately
establishes multi-craft fighting, not a continuous boarding-to-combat route:

1. move through or across the station on foot;
2. use a regeneration/control area or approach a physically present ship;
3. climb or step into a physical cockpit/seating area;
4. occupy the pilot position;
5. start and launch/undock;
6. fly in the same surrounding space;
7. collide, explore, or return; and
8. traverse station and ship spaces on foot in separate observed sequences.

The evidence is strongest for small craft with visible seats/cockpits. C2
independently remembers walkable ship interiors and roleplay, and footage shows
seating/control spaces in larger craft, but continuous movement inside a moving
large ship needs stronger timestamped evidence before being called universal.
**Confidence: high for physical boarding; medium for large moving interiors.**

## Combat, damage, and destruction

Supported facts:

- `F` was consistently creator-listed in the fixed description and the dated
  original-era pages that expose a full fire binding (A1, A3–A6).
- The roster explicitly contains fighter, interceptor, cruiser/warship, gunship,
  dropship, detention, transport, freighter, and recon roles (A3–A5).
- B1 shows close-range space fighting involving multiple craft, visible impacts,
  explosions, and brick debris. B3/B4 also show collisions and disassembly.
- A3 documents cleanup voting and A5 documents removal of a piloted vehicle when
  its pilot died. Those mechanics establish replacement/cleanup concerns, but do
  not prove the exact causes or lifecycle of every visible wreck.
- A3 comments show a contemporary tension between players who wanted guns and
  players who wanted uninterrupted roleplay. Combat and social play coexisted.

Unsupported or unresolved facts:

- exact projectile type, colour, speed, damage, cadence, range, convergence, or
  hardpoint placement;
- health, shields, armour, subsystem damage, teams, scoring, or respawn rules;
- whether every observed explosion came from a ship weapon rather than Roblox
  gear, collisions, or general physics; and
- a name-linked combat profile for each ship.

Therefore the vertical slice should reproduce readable, immediate firing and
physical destruction in spirit while labelling its modern weapon/damage values
as new design. It should not claim recovered shield or subsystem mechanics.

## Important nostalgic elements

The following are the best-supported identity anchors, ordered by confidence:

1. **Physical ship access.** Contemporary footage repeatedly links walking,
	ships parked at the facility, cockpits, launch, space flight, and return
	(B2–B4). It does not prove that every build lacked parallel convenience menus.
2. **A shipyard as social playground.** C2 explicitly remembers walkable ships
   and space roleplay; A3's archived comments document a contemporary tension
   between combat requests and uninterrupted roleplay.
3. **Fast experimentation and replacement.** Players regenerated ships by saying
   their names (A3–A6), voted to clean the server (A3/A4), and ships were removed
   when pilots died in one build (A5).
4. **Simple, memorable vehicle commands.** Y/X/H/F/D and later G expose the
   vehicle as a small set of playful verbs rather than a cockpit simulator.
5. **A varied named fleet with functional class names.** Torrent, Titan, Jovian,
   Vortex, Predator, Paradox, Katana, Dynamic, Utopia, Arrow, Salyut, Zenith, and
   later-observed Altair made ship choice understandable and characterful.
6. **Open grey dockwork against colourful space.** Exposed platforms, pale
   angular ships, dense stars, and close green/tan/grey/orange planets are a
   repeated visual signature (A8, B1–B4).
7. **Exploration as a lightweight parallel activity.** A4's Explorer badge says
   players explored planets and frames that achievement as piloting mastery.
8. **Role-specific curiosities.** The VIP room's
   Zenith, jetpack/armour, sparkles, Gravity Coil, and Super Jump (A9), together
   with unusual detention/recon/troop/cargo craft, made the sandbox feel playful.
9. **Roblox-era physical chaos.** Collisions, explosions, and loose bricks are
	directly observed in contemporary footage; landing and cleanup are separately
	creator-documented mechanics. The
	remake should preserve consequence and spectacle while removing destructive
	jitter.

## Vertical-slice ship selection

The [per-ship evidence matrix](docs/research/ship_evidence_matrix.json) applies
one six-gate contract to every currently known name: identity/role, name-tied
multi-view mapping, visual-feature index, observed role/handling, timestamped
confidence, and conflicts/unknowns. It currently records zero authenticated
ship reconstructions, two bounded partial reconstructions (the B5-linked Torrent
and B7-observed Zenith), and two frozen modern candidates (Arrow and Jovian).
The accepted Zenith runtime changes its implementation count, not its evidence
gates or historical confidence. Further original-labelled silhouette work
remains frozen at the recorded gate unless ledger evidence supports it.

The prototype uses the **Torrent-class Interceptor** as its first candidate.

Why it was selected:

- it appears in the creator-authored 2009 roster (A3);
- its exact regeneration label recurs across independent footage uploaded in
  2011 and 2012 (B3–B6); B5 securely ties its label to one spawned, boarded,
  flown model;
  and
- an interceptor suits the required boarding, startup, launch, flight, weapon,
  dogfight, and landing vertical slice without first solving a large interior.

### B5-linked Torrent model lock

B5 overturns the former low-confidence name-to-model hypothesis. In one uncut
sequence, the exact Torrent message precedes materialisation at a fixed empty
berth; the avatar then approaches, physically enters, sits, and flies that same
object through multiple views. The **B5 name-to-model identity gate passes at
high confidence**. B5 was uploaded in June 2011, but its recording date and live
build revision are unverified. This is not proof that the model is unchanged
from 2009, and the **detailed reconstruction gate remains partial**.

Safe visual invariants from B5 are:

- a compact, pale off-white/light-grey, low-part-count angular craft;
- a pointed/faceted nose, raised central spine, blunt boxy aft body, and broad
  swept triangular side planes with stepped/two-tier edges;
- paired circular/cylindrical forms symmetrically mounted beside the aft body;
- tall upright aft rails/fins around the central body; one side appears more
  triangular and the other more vertical in some rear views, but exact symmetry
  and geometry are unresolved;
- a central walk-in single-pilot space, one directly visible red seat, and a
  pale yellow/translucent forward window or panel; and
- avatar-relative compact scale sufficient for the avatar to walk into the
  centre rather than teleport from a distant menu.

Do **not** infer from B5 that the paired circular forms are definitely engines;
that the craft has a cyan canopy, animated hatch, particular weapon hardpoints,
landing gear, blue exhaust, numeric dimensions, symmetric fin geometry, or a
specific material finish; or that observed flight proves class-specific handling.
B7 independently locks a different, wider pale delta/arrowhead craft to Zenith;
do not blend its swept-wing, strake, pod, or cockpit details into Torrent.

### Current B5-linked Torrent reconstruction v1

The current implementation is a bounded **B5-linked Torrent reconstruction v1**,
not an authenticated exact reproduction. Earlier builds used the internal ID
`dated_2011`; current public provenance uses `b5_observed_name_to_model` so the
upload year cannot be mistaken for a verified recording or build date. The B5
name-to-model link is high-confidence, reconstruction status is `partial`, and
continuity with the 2009 model remains `unproved`. The
source-to-art measurements and required evidence boundary are recorded in the
[B5-linked reconstruction specification](docs/TORRENT_2011_RECONSTRUCTION_SPEC.md).

The v1 macroform replaces the former width-dominant smooth arrowhead with a
compact longitudinal faceted wedge: a pointed/chamfered nose, raised central
spine, tall blocky aft body, four stepped side-plane tiers, and two pale upright
rails. An explicitly inferred crossbar preserves the dominant U-like rear read
without being claimed as a separately authenticated B5 part. Its nominal
`L 8.40 m × W 7.20 m × H 4.54 m` envelope is a modern ergonomic normalization
for the remake pilot and existing interaction scale, not a recovered source
measurement. The paired observed aft housings use a nominal `0.80 m` diameter
and `3.35 m` fore-aft length. Their presence and placement are source-supported;
their historical function remains unknown even though the remake places modern
engine internals inside them.

The central physical pilot area retains one directly visible red seat and a
small warm amber/translucent forward panel. The panel's presence and broad colour
are observed, but its historical function as glazing, aperture or another part
is unresolved. Engine internals/exhaust, pressure canopy and hinge, cockpit
controls, weapons, landing gear, docking receiver, RCS, service detail, PBR
finish, handling and damage behaviour are kept in a separate modern-detail
hierarchy or carry equivalent modern/presentation-only metadata. Compact
collision envelopes, boarding/camera/muzzle contracts and damage anchors were
updated to fit the reconstruction without turning those gameplay systems into
historical claims. Arrow and Jovian replace the Torrent visual and collision
hierarchies with their own variant-specific implementations, preventing
Torrent-only reconstruction evidence from leaking into either provisional
candidate.

### B7-observed Zenith reconstruction boundary

Zenith is the second implemented defensible original-labelled ship slice, but
only as the versioned **Zenith-class Interceptor — B7-observed reconstruction**
described in
the [B7 specification](docs/ZENITH_B7_RECONSTRUCTION_SPEC.md). B7 securely ties
the runtime Interceptor label to one pale, very wide swept delta/arrow craft
through an uncut empty-berth, appearance, approach, boarding and flight chain.
The bounded frame index resolves a raised faceted central body/spine, long
strakes, repeated simple subdivisions and at least one function-unknown
cylindrical or pod-like exterior form. It does not supply orthographic views,
absolute scale, exact topology, systems, interior, materials or handling.

The role is deliberately versioned rather than silently canonicalised. A5 and
B7 say **Interceptor**; A9 says **Fighter**. The upload date of 2012-03-18 does
not establish the recording date, game build or model date. The implemented art
slice keeps the pale wide-delta macroform in a removable source core and keeps
pressure glazing, controls, engine internals, weapons, landing gear, docking,
boarding aids, damage hardware, PBR detail and flight balance explicitly modern.
The evidence document and feature index remain the limit: implementation and
capture acceptance make Zenith a bounded partial reconstruction, not an
authenticated historical ship.

## Design invariants derived from evidence

These are the safest Phase 1 constraints for later development:

- The station, parked ships, and surrounding space form one physical world.
- The slice begins on foot and makes a usable parked ship physically reachable;
	this is a remake requirement supported by footage, not proof of every original
	first-login path or the absence of parallel menus.
- A craft has a visible entry/seat, a deliberate start action, a launch or
  undocking moment, immediate arcade flight, a fire action, and a return path.
- The first environment reads as a grey modular shipyard, not a generic planet
  surface, carrier hangar, or menu lobby.
- At least one colourful nearby body and unobstructed space views preserve the
  original spatial composition.
- Controls stay learnable in seconds; simulation depth cannot obscure the core
  verbs.
- Destruction leaves a readable physical aftermath, but modern stability and
  cleanup prevent the old physics from ruining play.
- New detail may enrich the station and ships, but it must not erase their broad,
  clean shapes or the playful contrast of pale craft and colourful space.

## Implementation evidence map — current slice and bounded Phase 3 operational lattice

This map records the evidence boundaries that guided the current blockout and
remain constraints on later revisions; several safe implications are now
implemented. Timestamps refer to the source register above. “Safe implication” is
a remake decision bounded by the evidence, not a claim that the new geometry is
an exact copy.

| Invariant / correction | Source and direct observation | Confidence | Exact safe implementation implication | Explicit unknown |
| --- | --- | --- | --- | --- |
| **The dominant station experience is an exposed dock lattice, not a roofed runway hangar.** | B2 `4:40–5:10` circles a perforated station in open space; `5:25–5:43` shows an avatar on an uncovered deck beside open void and a ladder. B3 `0:04–0:44` and `2:24–2:40` likewise traverse uncovered slabs. A8 independently shows the official 2017 station as exposed booms and blocks. | High that B2/B3 and the fixed build show open station revisions; medium for unchanged 2009 geometry. The footage upload dates do not establish live build dates. | The current blockout replaces the enclosing hangar with an exposed junction, berth arms, launch spine, and compact modules. Preserve direct space/planet sightlines in later refinement. | The exact launch-era enclosure count, pressure-field fiction, and which 2009 revisions used each module are unknown. |
| **Near-black dense stars and conspicuously large simple colour bodies are a recurring space-composition anchor.** | A8 and B1–B4 collectively show dark space, many small stars, and close-looking green, tan/cream, grey, and orange bodies around station and flight views. This broad relationship is better supported than the former teal-nebula/single-ringed-moon composition; no one cited view establishes the live implementation's exact roster. | Medium-high for the broad palette/apparent-scale relationship; low for exact count, placement, radii, materials, or any ring system. | The live world now uses a deterministic dense star shell and four large green/tan/grey/orange presentation-only spheres clustered beyond the launch range. The project-original nebula remains only as a faint cover. Preserve broad colour blocking and direct sightlines; keep every exact value tagged modern composition. | The exact historical body count, orbital relationship, names, surface detail, position from every station revision, scale, shading, atmosphere, and whether any body had rings are unknown. |
| **Solid nodes are separated by long, narrow orthogonal arms and substantial negative space.** | B2 `4:55–5:10` gives the clearest original-era oblique overview: a central crossing/spine links rectangular end volumes through thin beams, with voids at least as visually important as the solids. B3 `6:13–7:10` shows narrow projecting routes at several heights. A8 corroborates the broad-spine/thin-arm hierarchy in the fixed build. | Medium-high for hierarchy; low for measurements. | The current station uses a central junction/spine, narrower arms, broader nodes, and genuine gaps rather than one continuous slab. The bounded Fleet Dock Comb adds one 48 m narrow trunk, three short teeth and three broad empty/deferred slabs without a hidden full-footprint floor. Retain this hierarchy while using modern avatar-clear dimensions and keeping the exact module tagged `modern_interpretation`. | No orthographic view, absolute scale, arm length, deck thickness, exact rung/slab count, berth assignment, or authoritative coordinate map survives. |
| **Enclosed rooms are compact insertions within the open framework.** | In B3 `2:40–3:00`, the avatar moves from an exposed deck through a small blue-operated opening into a grey console room with windows; the surrounding deck remains visible. B2 `7:04–7:22` and B4 `4:20–4:30` show chair/console banks and wide space-facing windows, although the containing station-versus-large-ship context is not always certain. A3 records a command-section proposal in November 2009, but does not prove that any later filmed room implements it. | Medium for original-era spatial relationship; medium that later footage contains comparable room motifs, with function/context unresolved. | The current operations, Habitat, and freight rooms, together with the fixed-rail activity, procedural machinery audio, and outer-face dressing, remain secondary modern insertions attached to the lattice. Keep their roles, routes, layouts, dressing, and audio tagged `modern_interpretation`. | Exact room purposes, station-versus-ship context, build dates, and adjacency are uncertain; no command-room geometry can be projected back to launch day. No cited source authenticates the new operational roles, rails, routes, dressing, or soundscape. |
| **Named regeneration is creator-proven; a physical bank of per-ship regeneration consoles is not.** | A3–A6 explicitly instruct players to say a ship name. In B3 the top message reads “Regenerating Titan-class Medium Transport” at `05:10.000` (`f1860`) and changes to “Regenerating Torrent-class Interceptor” at `05:13.167` (`f1879`) while the same craft remains visible. B4 supplies an uncut Torrent spawn at `04:50.333` (`f1742`), and B5 supplies the decisive continuous spawn/boarding chain. Blue/green pads and consoles appear elsewhere (B2 `0:00–1:00`; B3 `2:40–3:00`), but no cited sequence shows one causing a named regeneration. | High for name/chat regeneration; low for the function of individual coloured controls. | The former console bank is now one explicitly modern registry terminal displaying the classic `SAY SHIP NAME` convention beside a physical berth indicator. Do not present the terminal itself as recovered machinery. | Whether any build also offered a physical regeneration control, and whether the coloured pads are doors, spawn pads, teleports, or controls, remains unproved. |
| **Several ships are parked around separate arms/nodes rather than one hero craft centred on one runway.** | A8 visibly places multiple pale craft at different offsets and orientations around the fixed-build lattice. B2 `4:40–5:10` and B4 `3:43–3:53` show several craft around the station in original-era footage; creator pages A3–A6 describe a facility that stores a fleet of ten to twelve completed ships depending on date. | High for a physically present fleet; medium for exact simultaneous arrangement. | The current sandbox places exactly four flyables—bounded partial Torrent and Zenith reconstructions plus provisional Arrow and Jovian candidates—at distinct physical berths. Torrent and Zenith have version-bounded name-to-model locks; none of the current berth transforms is authenticated. | Which class belongs at which historical berth, how many ships were simultaneously spawned, and exact parking transforms are unknown. |
| **A visible historical docking/berth-state display is not established.** | The registered sources support physically present ships, name-based regeneration, embodied boarding, and return/landing motifs, but no cited sequence resolves a three-state lease display, its wording, colour language, geometry, animation, or control relationship. Coloured pads and controls elsewhere have unresolved functions and cannot be reassigned to docking feedback. | Absent for the implemented display; unknown for whether some original build had comparable feedback. | The exact four production berths may expose presentation-only modern lease feedback derived from their existing authority: cyan `BERTH OPEN` for released, amber `APPROACH VECTOR` for reserved-only approach, and green `BERTH SECURED` for occupied. Keep it collision-, audio-, navigation-, and authority-free and tagged `modern_interpretation`. | Any original docking aid, state model, label, colour, animation, dimensions, placement, material, light, sound, or relationship to landing authority remains unresolved. |
| **The observed spawn/return anchor is on or immediately beside an exposed main deck with a short ladder transition.** | B3 begins with an avatar materialising in a protective bubble on the uncovered deck at `0:04–0:10`; after a death, `1:03–1:10` returns to the same deck. A ladder is directly ahead, and the red VIP entrance and branching arms remain in sight (`0:20–0:52`). C1 `0:00–0:24` shows a visually similar later relationship, but its exact build is unverified. | Medium-high for the observed 2012 return point; medium for the recurring later motif; unresolved for first-join spawn. | The current slice begins at an exposed junction facing a short stair and visible craft. Treat that placement as a source-bounded remake decision, not a recovered first-login coordinate. | First-login and death respawn may differ; C1's build, exact orientation, VIP adjacency in earlier builds, menu availability, and the route to each ship are unknown. |
| **Torrent boarding reaches a visible physical pilot position; the exact hatch/canopy mechanism is unresolved.** | B5 continuously links the named spawn at `00:10.733` to an on-foot approach around `00:13`, entry into the central pilot space around `00:14.5–00:15.5`, a visible red occupied seat at `00:15.500`, and chase view by `00:16.833–00:17.000`. Compression/clipping prevents a defensible animated-door or canopy claim. B2 and B4 independently support embodied access for other craft. | High for Torrent physical entry and one visible pilot seat in the B5-observed model; low for exact entry side, hatch/canopy mechanics, or controls. | Preserve a physically reachable central single-pilot position and same-world boarding. Keep the current side steps, hinged canopy, detailed controls, camera transition, and exit path modular and labelled as modern design. | Exact entry side, door/canopy existence and motion, instrument layout, restraints, egress, and whether the yellow/translucent panel is glazing remain unresolved. |
| **The B5 Torrent name-to-model identity is locked; bounded reconstruction v1 is source-aligned but partial.** | A3 is creator-authored name/role evidence. In B5 the exact label begins at `00:10.200` (`f306`), the berth remains empty through `f321`, the craft appears at `00:10.733` (`f322`), and continuous boarding/flight supplies named rear/dorsal (`00:23`, `f690`), side/top (`00:29`, `f870`), and close side/front (`00:41`, `f1230`) views. B6 independently corroborates a compatible pale pointed craft at a Torrent-labelled berth. B3 is a warning against label overlap; B4 supplies a separate tiny spawn link. B7 positively identifies a different wide delta/arrow craft as Zenith. | High for the B5 name-to-model identity and broad silhouette; medium for fine geometry/colour; low for recording/build provenance, 2009 equivalence, and unobserved systems. | Reconstruction v1 implements the compact faceted wedge, pointed nose, raised spine/blocky aft, four stepped side-plane tiers, paired round housings and dominant upright rails. Its crossbar is an explicitly inferred reconstruction used to preserve the U-like rear read, not a separately authenticated B5 part. The central red seat and restrained amber forward panel remain visible. Its metre envelope is a modern ergonomic normalization; the panel and housing functions remain unknown. Engine internals, canopy, controls, weapons, gear, RCS/service/docking hardware, materials, handling and damage behaviour remain separated/tagged modern design. Arrow and Jovian use isolated visual/collision implementations; do not import B7's Zenith-locked delta details or Torrent evidence into either candidate. | Exact source dimensions/proportions/topology, function of the circular housings and forward panel, hardpoints/weapons, landing gear, exhaust, hatch animation, materials, symmetric fin geometry, handling, recording/build provenance, and continuity with the 2009 model remain unresolved. |
| **The B7 Zenith name-to-model identity is locked for a deliberately versioned scope; the bounded partial reconstruction is implemented.** | A5 calls Zenith an Interceptor, A9 calls it a Fighter, and the conflict remains dated rather than resolved. In B7 the Interceptor label begins at `00:33.455` (`f368`), the berth remains empty through `f372`, and a pale wide-delta craft appears without a cut at `00:33.909` (`f373`). Continuous approach, boarding and flight retain that identity through `00:42.455` (`f467`); `f468+` follows a discontinuity and is excluded. | High for the B7 name-to-model identity and physical boarding/flight chain; medium-high for the width-dominant pale macroform; medium for centre/spine, strake and step features; low for fine geometry; absent for recording/build provenance and class-specific handling. | Keep the versioned label `Zenith-class Interceptor — B7-observed reconstruction`. The removable source core implements the pale full-delta/arrow planform, raised faceted centre/spine, long strakes, repeated stepped subdivisions and cautiously indexed pod-like forms. Pod-like forms remain function-unknown. Exact dimensions, cockpit/access construction, engines, weapons, gear, materials, handling and Fleet Dock berth placement are modern or unresolved. Tests and captures accept this bounded implementation but do not authenticate it. | Whether A5/A9/B7 concern the same model/build, Fighter versus Interceptor outside the B7 scope, exact proportions/topology/scale, pod count/function, interior, access mechanism, engines, weapons, materials, handling, recording date, live build revision and 2009 continuity remain unresolved. |
| **“Jovian-class Light Freighter” is proven; the current freighter, interior, and berth are not.** | A3 is creator-authored name/role evidence. B4 `4:50–5:20` independently repeats the Jovian regeneration label, but the sequence does not securely tie a visible model to that name. No registered source establishes a Jovian silhouette, interior, ramp, handling, weapons, or berth. | High for the name and light-freighter role; absent for an authenticated name-to-model, interior, or berth mapping. | Keep the implemented Jovian explicitly provisional. Treat its silhouette, dimensions, colours, cargo/passenger/cockpit route, ramp, capacity, engines, weapons, materials, handling, mechanics, and port freight berth as modern design that can be replaced without revising the historical claim. | Name-linked multi-view geometry, scale, colours, access, interior plan, crew/cargo capacity, propulsion, weapons, handling, and historical berth placement are unresolved. |

### Current implementation status and next evidence work (2026-08-14)

The exposed station prototype and settled Phase 3 operational-lattice slice are
implemented as a **modern, source-bounded prototype**, not a recovered floor
plan, historical operations simulation, or audio reconstruction:

The B7-observed Zenith evidence boundary remains frozen as a non-media written
specification, and the accepted project-original implementation now adds a
fourth runtime craft and world-owned berth. It deliberately versions the
Interceptor/Fighter conflict and remains a bounded partial reconstruction, not
an authenticated ship.

1. The old enclosing runway blockout has been replaced by an exposed central
   junction, orthogonal berth arms, narrow aft/launch spines, and genuine voids.
2. The speculative per-ship console bank was replaced by one explicitly modern
   registry terminal. Its labels preserve creator-documented names and the
   `SAY SHIP NAME` convention without claiming that the terminal itself existed.
3. Exactly four physical flyables now occupy separate registered berths. The
   Torrent uses the bounded B5-linked reconstruction v1 described above: its
   high-confidence identity lock is distinct from its partial reconstruction
   status and unproved 2009 continuity. Its compact faceted macroform, four
   stepped side-plane tiers, upright rail hierarchy, red seat and amber
   unknown-function panel are source-directed; the joining crossbar is an
   explicitly inferred reconstruction. Its approximately
   `8.4 m × 7.2 m × 4.54 m` envelope is a modern normalization. The paired
   `0.80 m`-diameter, `3.35 m`-long housings preserve an observed form while
   keeping their historical function unknown. Modern engine internals, exhaust,
   canopy, controls, weapons, landing gear, RCS/service/docking hardware,
   materials, handling and damage behaviour remain separated or tagged as
   modern interpretations. Collision envelopes and damage anchors were revised
   for the compact form while retaining the gameplay contracts.
   The Zenith uses a separately versioned B7-observed partial reconstruction:
   47,274 close and 5,412 far presentation triangles batch to 22 meshes/surfaces,
   while 24 mixed runtime shapes independently own collision authority. Its
   removable source core preserves the wide pale delta/arrow, raised centre,
   long strakes, stepped subdivisions and cautiously indexed pod-like forms;
   their function remains unknown. Its cockpit/access, engines, weapons, gear,
   materials, handling and Fleet Dock placement remain modern. Focused physical
   lifecycle validation passed all 49 assertions twice, but that is gameplay
   integration evidence rather than historical authentication.
4. The distinct **provisional Arrow-class Recon Ship candidate** and larger
   **provisional Jovian-class Light Freighter candidate** retain their own visual
   and collision hierarchies rather than inheriting Torrent reconstruction claims.
   Creator evidence supports the Arrow name, reconnaissance role, and exactly two
   escape pods (A3), and supports only the Jovian name and light-freighter role
   (A3; independently repeated as a regeneration label in B4). Neither candidate's
   current shape is authenticated or securely name-linked to adequate historical
   views.
5. Every current Jovian silhouette, dimension, colour, cargo and passenger
   interior, ramp, cockpit/access route, capacity, engine, weapon, material,
   handling value, mechanic, and berth detail is an explicitly modern provisional
   interpretation. The integrated port freight branch leads to a separate berth,
   loading apron, and service room; its ramp, cargo bay, passenger cabin, and
   cockpit form one attached collision-backed ship-local hierarchy rather than a
   detached interior or separate teleported level. Automated locomotion proves
   ramp-to-cargo-to-passenger traversal, while cockpit boarding is separately
   tested through the exterior pilot hatch; a continuous ramp-to-cockpit walk has
   not yet been demonstrated.
6. All four flyables have visible cockpits, seats, physical access, seated
   pilots, and same-world exits. B5 shows that its linked Torrent model had a
   physical central entry and one visible red pilot seat, but it does not prove
   the current canopy, steps, controls, camera, exit, or transition design. No
   cited sequence proves those model-specific implementations for Arrow or Jovian.
   B7 directly supports an approach/boarding/flight chain for Zenith, but not the
   current canopy, entry side, access construction or single-seat layout.
   The Torrent's compact translucent forward panel, anti-glare instrument hood
   and side consoles, restrained live readouts, practical light, and sampled
   `10 m` pilot-eye sight corridor are likewise modern presentation choices, not
   newly recovered historical cockpit evidence.
7. A first Aft Junction Stack adds a short physical stair, two elevations, an
   enterable operations pod with a cyan door, and a red locked/deferred VIP
   landmark. These express the bounded spatial motifs in the table above; the
   module name, dimensions, plan, furniture, door mechanics, and adjacency are
   explicitly modern interpretation. A separate visible bridge continues from
   its upper circulation into the Fleet Dock Comb: one narrow starboard trunk,
   three short teeth, three broad separated slabs, real voids and one short
   ramp. B2 supports that repeated macro rhythm, not the exact implementation.
   Dock 01 records a modern external Zenith assignment aligned to a world-owned
   berth; Docks 02/03 remain empty and deferred. The comb's markers themselves
   add no berth, lease, regeneration, interaction, audio or gameplay authority.
8. A Habitat Spine is integrated through the starboard lattice with an operated
   door, corridor, six bunk alcoves, an eight-chair observation/common room,
   glazing, consoles, service detail, and a sealed deferred branch. C1 motivates
   the habitat/bunk/chair motifs only as later secondary material: its exact build
   provenance is unverified, while the module name, placement, dimensions, room
   functions, layout, furniture, connector, and mechanics are a fixed-era-inspired
   modern interpretation rather than recovered geometry.
9. The settled bounded operational lattice integrates exactly four fixed-rail,
   presentation-only activity roles: `Full` at Central
   (`CentralTowServiceActivity`), `Gantry` at Freight
   (`FreightApproachGantry`, corrected to freight-module-local `z = 0.9`),
   `Service Arm` at Aft (`AftOperationsActivity`), and `Drone Patrol` at Habitat
   (`HabitatServicePatrol`). Each placement has a fixed transform and seed, finite
   render and service envelopes, and no collision nodes. Absolute seek and
   30/60/120 Hz subdivision produce the same motion, while pause, disable,
   re-enable, detach/re-entry, and teardown have explicit deterministic audits.
   These are fixed presentation rails, not a navigation graph, docking authority,
   or autonomous-logistics system; the patrol drones are not autonomous agents.
   No source authenticates these roles, routes, motions, dimensions, or placements.
10. Exactly four finite-range positional 3D procedural machinery beds are
    integrated: `central-berth-utilities` (`26 m` maximum / `4 m` reference
    distance), `aft-operations-service-wall` (`24 m` / `3.5 m`),
    `habitat-environmental-main` (`22 m` / `3 m`), and
    `freight-control-machinery` (`28 m` / `4 m`). Each project-original emitter
    deterministically synthesizes a loop plus servo and latch cues as bounded
    16 kHz mono voices. Aft, Habitat, and Freight station doors invoke the servo
    while moving and the latch when motion completes. The emitters and hooks are
    `modern_interpretation`; no surviving source authenticates the original
    shipyard's machinery ambience, door sounds, acoustic ranges, or placement.
11. Exactly four collision-free planar outer-face dressings are integrated:
    `CentralBerthOuterFascia` (standard, `20 m`),
    `AftOperationsOuterFascia` (light, `6 m`),
    `HabitatOuterServiceDressing` (standard, `12 m`), and
    `FreightRackServiceDressing` (light, `20 m`). They stay on the outward side of
    their attachment surfaces, neither widen walkable decks nor fill station
    voids, and expose prebuilt deterministic Low / Medium / High counts of
    16 / 33 / 41 visible primitives per instance without runtime reconstruction.
    Their structure, detail, material, light, dimensions, and placement are
    `modern_interpretation`. Component counts and budgets are not measured
    representative-Windows performance evidence.
12. The live flight path samples validated `ShipCommand` snapshots from a
    swappable command source. Its current modern control contract adds explicit
    keyboard pitch/roll, a partial two-stick gamepad layout with `0.18` deadzones,
    a bounded lossless-across-ticks mouse-motion backlog, a capped chase-boom
    attitude lag, and a separate active-camera flight-path cue showing actual
    velocity alongside the fixed nose/weapon reticle. Those input, camera, HUD and
    cockpit contracts are remake design and usability work, not recovered original
    flight physics or control evidence. Both sides of live hitscan combat use one
    registered-source `CombatResolver` with stable identities, factions, weapon
    profiles, replay sequencing, source exclusion, occlusion, and lifecycle
    proxies. Ship-local thrust presentation consumes the same sampled command's
    boost flag together with the resulting actual throttle, rather than separately
    polling local input. These are new remake architecture and testable future
    authority seams, not evidence about the original implementation and not proof
    of multiplayer or network play.
13. A reusable `MovingInteriorFrame` now applies a live ship's translation and
    rotation to registered occupants, aligns floor classification, exposes
    ship-local gravity, and imparts relative plus frame velocity once on exit. The
    production `PlayerController` consumes that gravity and resolves movement in
    the live deck-tangent plane. This is local-authority remake infrastructure with
    one player avatar, not evidence about the original and not implemented
    multiplayer or multi-crew gameplay.
14. Simultaneous modern mouse yaw/pitch now uses one local rotation-vector step
    while the input adapter retains bounded pixel backlog across ticks. This
    removes a remake-only 30/60/120 Hz diagonal-sampling artifact; it is a control
    comfort correction, not evidence about original handling.
15. Guided Torrent completion now remains separate from combat victory. Defender
    destruction grants only a pending return authorization; the same craft must
    obtain an opaque ship-bound physical berth lease, pass schema-v2 full-hull and
    exact-dock acceptance, convert that reservation to occupancy, shut down, and
    finish a generation-guarded physical disembark before the guide commits once.
    Landing or shutdown alone remains incomplete, while abort, destruction, reuse,
    and duplicate lifecycle signals release or invalidate stale authority and leave
    a coherent retry. These completion, lease, landing, and transition rules are
    modern remake design; the sources do not establish their exact historical
    state machine, dimensions, tolerances, latch rules, feedback, or timing.
16. Exactly four direct-child `ShipBerthFeedback` components render the real
    production berth leases as `BERTH OPEN`, `APPROACH VECTOR`, and `BERTH
    SECURED`. They have deterministic manual clocks and instance-local materials,
    but no collision, physics queries, lights, audio, particles, timers,
    navigation, or docking authority. Their roster, geometry, labels, colours,
    animation, dimensions, materials, and placements are explicit
    `modern_interpretation`; no cited source authenticates an original docking
    display. The now-superseded v0.10 harness passed nine HUD-free 2560x1440
    views across the three states and then-current three berths; that remains
    historical presentation evidence, not validation of the four-berth source or
    a historical docking-display claim. The current runner declares twelve views
    across all four berths; a source-current four-berth rerun remains pending.
17. Each production craft owns one definition-selected finite-range positional 3D
    `ShipAudioRig`: Torrent and Zenith `standard_fighter`, Arrow
    `efficient_twin_recon`, and Jovian `heavy_quad_freighter`. Four craft therefore
    share three modern profiles. Each synthesizes four loop layers and eight cues
    into a fixed six-voice/two-transient hierarchy, releases PCM/playback handles
    on detach, and regenerates deterministically on re-entry. One global
    `PulseWeaponPresentation` renders accepted resolved shots through a fixed
    preallocated six-slot oldest-recycle pool with three modern styles and no
    collision, damage, query, firing, or audio authority. Every profile, waveform,
    range, level, cue mapping, pulse shape, palette, timing, impact, and pooling
    choice is project-original `modern_interpretation`, not recovered audio or an
    authenticated historical weapon effect. Automated audio checks prove
    synthesis, routing, engine queue state, allocation, and lifecycle—not audible
    output on real hardware. The pulse pool and combat authority are local
    presentation/resolution infrastructure, not networked projectiles.
18. Whole-`Main` detach/re-entry preserves gameplay state and node identity without
    replaying startup, disconnects and restores live combat registrations exactly
    once, clears transient pulse visuals, releases and rebuilds procedural audio
    resources, and preserves resolver sequence history so a captured request
    cannot apply damage again. Process-owned regeneration deadlines never mutate a
    detached tree; an occupied home berth schedules a bounded retry, and the same
    craft instance regenerates only after acquiring its occupied lease. This is
    whole-tree local lifecycle/replay/regeneration hardening, not multiplayer,
    network persistence, or evidence about the original implementation.
19. The earlier settled tree passed all 37 then-current `tests/*_test.gd` headless
    suites with 2,571 recorded `PASS` results. The prior pre-operational-lattice
    matrix then passed all 40 suites with 2,819 recorded `PASS` assertions, 40
    suite sentinels, and zero failures, errors, warnings, leaks, or timeouts after
    adding focused control-mapping, flight-path-cue, and combined flight-quality
    closure audits. Its 202-file scoped manifest remained unchanged during that
    historical run at SHA-256
    `a03f98deaf2e2a9b74e9a6c35a141ad504f71c850fdc8742ed0127eb1e4f1b5d`.
    The now-superseded v0.9 operational-lattice checkpoint then passed all 44
    then-current suites with 3,392 exact `PASS:` assertions and 44 suite sentinels;
    its scoped 221-file manifest was byte-identical before and after at SHA-256
    `66d33185ee8d922af931d90330296518e16fbdc58eeb24c08c6e6c7133161273`.

    The now-superseded v0.10 inventory contained exactly 54 `tests/*_test.gd` headless
    suites. Under Godot 4.7.1, the editor/import gate exited `0`; all 54 of 54
    suites exited `0` with 4,075 anchored `PASS:` assertions and 54 exact terminal
    sentinels. The raw matrix contained zero failures, errors, warnings, timeouts,
    or genuine RID/ObjectDB/resource-leak/orphan diagnostics. Its scoped manifest
    contains 252 files: 2 root configuration files, 76 scripts, 21 scenes, 120 test
    files, and 33 assets. That manifest was byte-identical before and after at
    SHA-256
    `204f6d482370684c823e84ecef66a44540d37f84f583915802df56533cf5197c`.

    That historical v0.10 automated integration exercised Arrow- and
    Jovian-first free-sortie boundaries, the protected guided range, then-current three-craft
    berth/damage/recovery lifecycle, station/Habitat/freight traversal,
    moving-interior behaviour, transition-destruction recovery, and the 27
    distinct 1280x720 states declared by the main rendered-evidence runner. A
    separate capture-only harness validates 12 distinct HUD-free 2560x1440
    Torrent hero-cell views, extending the original nine with
    cockpit power-off, online, and critical states. Six additional HUD-free
    2560x1440 operational-lattice views cover the exposed overview, Central, Aft,
    Habitat, Freight, and launch flypast. Nine more HUD-free 2560x1440 Forward+
    berth-feedback views cover released, approach, and occupied at the Central,
    Arrow, and Jovian berths. That historical automated evidence total is 54
    frames (`27 + 12 + 6 + 9`). All four harnesses exit `0` with exact sentinels;
    all 54 declared PNGs have the correct type and dimensions and unique full-file
    SHA-256 hashes. The closest pair in every harness passes its threshold: main
    mean difference/changed fraction `0.02177`/`0.081`, hero
    `0.05385`/`0.242`, station `0.05045`/`0.300`, and berth
    `0.00085`/`0.0039`. Representative original-resolution inspection of flight,
    dogfight, touchdown, disembark, Central approach/occupied, and Jovian
    approach/occupied found no blank, corrupt, or clipped blocker; landing text is
    legible and occupied mint cues visibly differ. The Jovian cue is subtler and
    partly obscured by the large freighter but remains visible and nonblocking.

    The critical 255-file capture scope (`project.godot`, `export_presets.cfg`,
    `default_bus_layout.tres`, `scripts/`, `scenes/`, `tests/`, `assets/`, and
    `tools/`) remains byte-identical before and after at SHA-256
    `7b00e37f8af4c857665bf12f840717cd0d8ebe1a4d56b3e5932085901839e11d`.
    Logs contain no `ERROR`, `SCRIPT ERROR`, or `FATAL` diagnostics,
    harness-failure lines, or failed sentinels. Each Linux llvmpipe X11 process
    emits only the generic root startup warning and the known seven retained
    Texture RID warning after its successful sentinel. These staged frames and
    representative screenshot review document integration but do not prove
    historical accuracy, final human visual sign-off, native-GPU or native-Windows
    behaviour, representative performance, an uninterrupted human playthrough,
    or audio audibility; broader human review remains pending.

    The definitive Godot 4.7.1 v0.12 matrix recorded an editor/import exit of `0`
    in 2,844 ms and exactly 75 of 75 suite exits of `0`, with 6,969 anchored
    `PASS:` assertions and exactly 75 terminal sentinels (73 `OK` plus two
    `PASS`). Logs contained zero timeout, failure, error, fatal, RID, ObjectDB,
    resource, or orphan diagnostics; the only warnings were 76 generic root-
    startup warnings. Its 452-file source scope remained byte-identical before
    and after at SHA-256
    `2115dddd6c11fa751c804b1e3140e0b2cf1b476b478675fe17ed2f7383e68792`.
    Results-table, exact-sentinel-validation, and ordered process-hash-aggregate
    SHA-256 values are respectively
    `521d9bfd278ddec4ba0623f070b08487d962e7748d9eeafce09134f9125fe349`,
    `c243dfea866cb07a01343ad0300db10f9a72a12948b5a7c9a1d6e76c45ac1e05`,
    and `f0338503e70ca534a666b04c2ee41e4cb22d180f45fa7818ce110a6cbd493b10`.
    The prior 72-suite, 6,673-assertion matrix remains a byte-pinned historical
    checkpoint rather than the v0.12 result.

    The final Zenith-specific X11 Forward+ capture passed all seven declared
    2560x1440 frames with distinct bounded semantic states; original-resolution
    review found no blocker. Evidence-manifest SHA-256 is
    `6e6d66b3d6a7a1254da6da8ce1259b5c593f7820312c74ed199c4712a529c89a`,
    286-file frozen-source aggregate SHA-256 is
    `68d23207b9841463c61273b8c3de610a25519e82dc56f46eeddfb7befdef77c4`,
    and raw-log SHA-256 is
    `6da081c58304bb152d7553669395fd481fd64862276a944fd17be6cedd117704`.
    Its only post-sentinel diagnostic was the known seven-Texture-RID capture
    warning. These staged captures and bounded review validate presentation
    integration, not historical fidelity or authentication, complete-project
    craftsmanship sign-off, native-Windows behaviour, or an uninterrupted sortie.
20. The now-superseded v0.10 Windows export completed with exit `0`.
    `builds/windows/KethShipyardsReforged.exe` is 137,356,496 bytes, was modified
    `2026-08-13 08:25:39.484373665 +0100`, and has SHA-256
    `fe41f1b52e43c6e11b3fd3782088a66efb851b6e70ca0ea49a99f8c5126d6147`.
    It is a PE32+ AMD64 Windows GUI executable with 12 sections, embedded
    file/product version `0.10.0.0`, product name `Keth Shipyards: Reforged`, and
    file description `Early standalone Keth Shipyards fan prototype`. Its PE
    Security Directory offset and size are both zero, so it contains no embedded
    Authenticode certificate; external catalog signing was not assessed.

    Its embedded Godot 4.7.1 format-4 PCK contains exactly 161 unique entries;
    the sorted-entry manifest has SHA-256
    `765f5d31b73e45e119d45fc62e67dc71684b1931758b6fbeaa1ec753bec4091a`.
    The exact 12 additions over v0.9 are compiled-script/remap pairs and compiled-
    scene/remap entries for `ShipAudioRig`, `PulseWeaponPresentation`, and
    `ShipBerthFeedback`. All three scripts and all three scenes load from the
    mounted pack. It contains zero test, artifact, or tool paths and zero raw
    `.gd`, `.tscn`, or `.tres` files. An isolated Linux Godot 4.7.1 headless Dummy-
    audio main-pack smoke ran 300 frames in 3.258 seconds and exited `0`, with zero
    error, warning, leak, or orphan markers. The 133-file release scope remained
    byte-identical before and after at SHA-256
    `1db8afc2e44d809c5df2802885e292e9181d3df96e598e7f63bc2c8f12166b87`.
    This verified that historical package and Linux embedded-pack startup, not native-Windows
    behaviour, representative performance, audible output, historical
    authenticity, or an uninterrupted human playthrough. Native-Windows
    validation and a no-shortcut human playtest.

    The later v0.11 `MuddsShipyards.exe` package is also historical source
    evidence now: it predates the accepted fourth craft and must not be treated as
    v0.12 evidence. The source-current v0.12 Windows x86-64 artifact at
    `builds/windows/MuddsShipyards.exe` is 153,657,032 bytes, was modified
    `2026-08-14 07:42:29.806068718 +0100`, and has SHA-256
    `014b6e443822cf263d8811af946bda43f29bf10f8986b0dabb6a6d804282b669`.
    It is a 12-section PE32+ x86-64 Windows GUI executable with product name
    `Mudds Shipyards`, file description `Modern standalone Keth Shipyards fan
    remake prototype`, and file/product version `0.12.0.0`. Its zero-offset/zero-
    size Security Directory records no embedded Authenticode certificate;
    signing remains pending. It embeds a 44,428,988-byte format-4 Godot 4.7.1 PCK
    at offset 109,228,032 with flags `2`, and has no external PCK. Isolated
    candidate and promoted-artifact Linux headless Dummy-audio smokes each ran 300
    frames in about 3.72 seconds, exited `0`, and emitted no diagnostics. These
    checks prove bounded package structure and Linux startup, not native-Windows
    behaviour, representative performance, audibility, signing, release
    permission, historical authenticity, or uninterrupted human play; each of
    those applicable release checks remains pending.

The next evidence work is to triangulate a confidence-graded relative station
map, resolve the remaining Torrent reconstruction details, establish B5's
recording/build provenance and test continuity with 2009, deepen Zenith beyond
the bounded B7 macroform with higher-resolution name-tied views, prove or reject
the Arrow and Jovian name-to-model hypotheses, and repeat name-linked visual
indexing before treating any additional historical name as an authenticated
model. Further implementation revisions must keep those unknowns visible in
data and UI.

These changes are geometry and interaction priorities, not permission to copy
source assets. No source model, place file, script, texture, or audio is needed
or authorised by this evidence map.

## Unresolved research backlog

Priority order:

1. **Torrent reconstruction completion:** B5 now locks its observed
   name-to-model identity, while recording/build provenance remains unverified.
   Seek less-compressed front/side/top/rear and cockpit
   views that resolve exact proportions, fins, access mechanics, dimensions,
   circular-housing function, engines/exhaust, hardpoints/firing, landing gear,
   materials, handling, and whether the 2009 model was the same revision.
2. **Station map:** triangulate B2–B7 and C1 into a labelled relative floor plan;
   mark every segment as original-era observed, fixed-era only, or inferred.
3. **Fleet visual index:** repeat the name-to-model process for all creator-listed
   ships, particularly Paradox, Jovian, Titan, Vortex, Katana, Predator, Dynamic,
   Utopia, Arrow, and Salyut. For Zenith, seek higher-resolution uninterrupted
   views that extend the bounded B7 feature sheet without promoting the upload
   date to a recording/build date or silently resolving Fighter/Interceptor.
4. **Spawn and interaction locations:** document player spawn, each regeneration
   control, VIP access, cockpit/seat route, launch direction, landing pads, and
   cleanup behaviour.
5. **Flight measurement:** find uninterrupted clips with known craft and stable
   landmarks; estimate only relative acceleration, turn response, braking,
   hover, and roll after scale/camera calibration.
6. **Combat attribution:** distinguish built-in guns from carried Roblox gear;
   locate clear firing, impact, destruction, and respawn sequences.
7. **Colours and audio:** acquire less-compressed original-era frames and clean
   recordings of ambience, startup, thrust, weapons, collision, and explosions.
8. **Developer testimony:** seek public statements from ZolarKeth about layout,
   ship inspirations, intended roles, controls, and which fixed-build changes
   preserve the original versus repair it.
9. **Archival media:** search for surviving legacy thumbnails, screenshots,
   models legitimately released by their author, and the old forum guide linked
   from Keth Shipyards II.
10. **Contemporary discussion:** preserve relevant comments with capture date and
    author, but separate requests (“add shields”) from existing features.

## Rights, attribution, and licensing caution

This research establishes historical identity, **not permission to copy or ship
the underlying intellectual property**.

- Public Roblox pages, archived pages, YouTube videos, and a playable/fixed
  experience do not grant a licence to reuse names, exact ship/station designs,
  models, scripts, textures, audio, logos, or screenshots in a standalone game.
- Official metadata identifies ZolarKeth as creator and reports the experience as
  copy-locked/`copyingAllowed: false`. Do not extract or redistribute an RBXL,
  meshes, scripts, textures, or sounds from the Roblox experience.
- The community reboot's claim that its author received private approval is not
  public, transferable permission for this project. It must not be treated as a
  licence or chain of title.
- Roblox marks and platform assets have their own rights and must not be bundled
  into the standalone title merely because they appear in reference footage.
- YouTube uploads and archived screenshots remain owned by their respective
  creators/rightsholders. Use citations and limited internal study references;
  obtain permission before redistributing source media.
- Build all production art, code, audio, writing, UI, and branding independently.
  Maintain provenance for every asset and avoid copying source geometry more
  literally than the project's rights position permits.
- Before public release or commercial use, contact the relevant rightsholder(s)
  for written permission and obtain qualified legal review of the title, ship
  names, look and feel, branding, and marketing claims.

This is a project-risk warning, not legal advice. Until permission is documented,
“faithful remake” should describe the research goal, not imply endorsement,
ownership, or authorisation by ZolarKeth or Roblox.

## Research hygiene for future edits

When adding a fact, include the source ID/link, build/date, exact timestamp or
archived page section, direct observation versus inference, confidence, and any
conflict. Never silently turn a modern proposal into a historical fact. Preserve
source URLs and archive URLs, and record an access date if a source is volatile.

The completion test for Phase 1 is not “a `RESEARCH.md` exists.” It is that every
claimed invariant used by the vertical slice can be traced to adequate evidence,
and every unresolved choice is visibly labelled as inference or new design.
