# Mudds Shipyards video advert

A 63-second in-engine trailer, captured from the real game with Godot's Movie
Maker and scored with the game's own music beds and combat sounds.

```bash
marketing/advert/render_advert.sh            # -> marketing/advert/out/mudds_shipyards_advert.mp4
ADVERT_ONLY=6,7 marketing/advert/render_stills_gpu.sh /some/dir   # framing stills for shots 6 and 7
```

- `advert_director.gd` holds the shot list (cameras, ship moves, title cards).
  It loads `scenes/main.tscn`, hides the game UI, disables ship logic and poses
  the ships directly, then visits Ember Moon and Aurora.
- `mix_soundtrack.sh` builds the soundtrack from `assets/audio/music` and
  `assets/audio/combat`. Its cue times follow the shot durations in the director.
- Rendering is silent (`--audio-driver Dummy`) on a private Xvfb display. It uses
  the WSL GPU through Mesa d3d12 with the compatibility renderer, so the look is
  the compatibility renderer's rather than Forward+.
- The combat bolts and explosion are advert-only effects, not the game's
  combat presentation.

The runners accept relative or absolute output directories, fail on renderer
errors or timeouts, and require an explicit completion marker. They require
Godot, Xvfb (`xvfb-run`), GNU `timeout`, and FFmpeg; the capture scripts currently
select the WSL Mesa d3d12 driver explicitly. Generated media stays under ignored
`out/` by default. The existing historical render does not qualify current game
content or a new GPU environment.

Run orchestration checks without rendering or audio:

```bash
python3 marketing/advert/test_runners.py
shellcheck marketing/advert/*.sh
```
