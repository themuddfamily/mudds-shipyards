#!/usr/bin/env bash
# Record the Mudds Shipyards advert with Godot's Movie Maker on an isolated
# Xvfb display, silently (Dummy audio), then mix the soundtrack and encode MP4.
#   marketing/advert/render_advert.sh [work dir]  -> <work>/mudds_shipyards_advert.mp4
# Uses the WSL GPU through Mesa d3d12 (compatibility renderer); llvmpipe Forward+
# works too but takes about a minute per frame.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
work="${1:-$here/out}"
mkdir -p "$work"; touch "$work/.gdignore"  # keep Godot from importing frames
rm -rf "$work/frames"; mkdir -p "$work/frames"
# Movie Maker sizes its output from the project's 1280x720 window override, so
# lift it to 1080p for this run only via a temporary override.cfg.
override="$repo/override.cfg"
[[ -e "$override" ]] && { echo "refusing: $override already exists"; exit 1; }
printf '[display]\n\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > "$override"
trap 'rm -f "$override"' EXIT
x="$work/private-xdg"; mkdir -p "$x"/{data,config,cache,runtime}; chmod 700 "$x"/*
env -u DISPLAY -u WAYLAND_DISPLAY XDG_DATA_HOME="$x/data" XDG_CONFIG_HOME="$x/config" \
  XDG_CACHE_HOME="$x/cache" XDG_RUNTIME_DIR="$x/runtime" GALLIUM_DRIVER=d3d12 \
  MESA_LOADER_DRIVER_OVERRIDE=d3d12 GODOT_SILENCE_ROOT_WARNING=1 \
  timeout --kill-after=10s "${ADVERT_TIMEOUT:-5400}" xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path "$repo" --audio-driver Dummy --display-driver x11 --rendering-method gl_compatibility \
  --resolution 1920x1080 --write-movie "$work/frames/f.png" --fixed-fps 30 \
  --script res://marketing/advert/advert_director.gd > "$work/movie.log" 2>&1 || true
grep -E "ADVERT_START_FRAME|ADVERT_DONE|SCRIPT ERROR" "$work/movie.log" || true
grep -q ADVERT_DONE "$work/movie.log" || { echo "capture did not finish; see $work/movie.log"; exit 1; }
"$here/mix_soundtrack.sh" "$work"
