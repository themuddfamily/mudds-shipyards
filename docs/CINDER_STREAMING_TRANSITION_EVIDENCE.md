# Cinder streaming transition evidence

`tests/cinder_streaming_transition_render.gd` is the required production-Main
graphical harness for Cinder residency transitions. It does not change the
streaming policy. It drives the real production position-provider seam across
the exact 500 m load and 650 m unload thresholds and uses the one coordinator-
owned `NearbySectorCluster` generation.

The frozen inventory is 24 Forward+ PNGs at 2560×1440: HIGH and LOW quality,
each with normal and reduced motion, crossed with six ordered states:
`pre_load`, `first_committed`, `load_settled`, `pre_unload`,
`first_unloaded`, and `unload_settled`. A single immutable evidence camera is
used throughout. The hidden, frozen production guided ship is only the tracked
position provider, so the 0.2 m threshold movement cannot change camera pixels.

Tracked distances from the Cinder navigation anchor are exactly 500.1 m,
499.9 m, 499.9 m, 649.9 m, 650.1 m, and 650.1 m. The first committed draw must
already have the requested production quality synchronized; the first unloaded
draw must have no cluster attached. Settled frames are separated from their
first transition frame by exactly 60 renderer draws. The manifest records the
coordinator generations, quality and reduced-motion state, environment values,
immutable camera, source hashes, PNG hashes, luminance samples, and transition
pair deltas.

Run the contract without a renderer:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/cinder_streaming_transition_render.gd -- --check-only
```

Generate on-demand evidence with a native display and Forward+ renderer:

```sh
KETH_CINDER_TRANSITION_CAPTURE_DIR=/tmp/cinder-streaming-transition-evidence \
xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . \
  --display-driver x11 --rendering-driver vulkan --audio-driver Dummy \
  --script tests/cinder_streaming_transition_render.gd
```

The registry intentionally leaves source freeze, image inventory, and original-
resolution human review pending. A successful local run and agent inspection
do not satisfy or imply the human-review gate. No subjective pop threshold is
encoded in the harness; acceptance requires inspection of the original PNGs.
