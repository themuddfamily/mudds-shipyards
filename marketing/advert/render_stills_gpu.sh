#!/usr/bin/env bash
# Quick framing stills on the WSL GPU (d3d12 GL, compatibility renderer).
#   ADVERT_ONLY=3,4 render_stills_gpu.sh <out dir>
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; repo="$(cd "$here/../.." && pwd)"
out="${1:-$here/out/stills}"; mkdir -p "$out"
x="$here/out/private-xdg"; mkdir -p "$x"/{data,config,cache,runtime}; chmod 700 "$x"/*
env -u DISPLAY -u WAYLAND_DISPLAY XDG_DATA_HOME="$x/data" XDG_CONFIG_HOME="$x/config" \
  XDG_CACHE_HOME="$x/cache" XDG_RUNTIME_DIR="$x/runtime" GALLIUM_DRIVER=d3d12 \
  MESA_LOADER_DRIVER_OVERRIDE=d3d12 GODOT_SILENCE_ROOT_WARNING=1 ADVERT_MODE=stills \
  ADVERT_STILLS_DIR="$out" timeout --kill-after=10s 1200 xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path "$repo" --audio-driver Dummy --display-driver x11 --rendering-method gl_compatibility \
  --resolution 1920x1080 --script res://marketing/advert/advert_director.gd > "$out/stills.log" 2>&1 || true
grep -E "ADVERT_STILL|SCRIPT ERROR|ERROR:" "$out/stills.log" | head -40
