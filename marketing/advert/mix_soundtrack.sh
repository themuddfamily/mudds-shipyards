#!/usr/bin/env bash
# Build the advert soundtrack from the game's own music beds and combat SFX,
# then mux it with the Movie Maker capture into the final MP4.
#   mix_soundtrack.sh <work dir containing raw.avi>
# Cue times follow the shot list in advert_director.gd (63 s total):
#   station 0-25.5 | launch 25.5 | dogfight 31.5-38 (kill at 36.05)
#   surface 38-51  | station/cabin 51-56 | end card 56-63
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
work="${1:-$here/out}"
work="$(cd "$work" && pwd)"
a="$repo/assets/audio"
total=63

# Pulse volley timings for the dogfight.
fire_inputs=()
fire_chain=""
n=0
for t in 31.9 32.15 32.4 32.9 33.15 33.4 34.0 34.25 34.5 34.75 35.3 35.55 35.8; do
  fire_inputs+=(-i "$a/combat/player_pulse_fire_v1.wav")
  ms=$(awk "BEGIN{printf \"%d\", $t*1000}")
  fire_chain+="[$((10 + n)):a]aresample=48000,volume=0.55,adelay=${ms}|${ms}[f$n];"
  n=$((n + 1))
done
fire_mix=""
for ((i = 0; i < n; i++)); do fire_mix+="[f$i]"; done

loop() { echo "aresample=48000,aloop=loop=-1:size=2e9,atrim=0:$1"; }

ffmpeg -y -v error \
  -i "$a/music/station_bed_drone_v1.wav" \
  -i "$a/music/station_bed_harmonics_v1.wav" \
  -i "$a/music/station_bed_motif_v1.wav" \
  -i "$a/music/flight_bed_drift_v1.wav" \
  -i "$a/music/flight_bed_shimmer_v1.wav" \
  -i "$a/music/flight_bed_signal_v1.wav" \
  -i "$a/music/surface_bed_warmth_v1.wav" \
  -i "$a/music/surface_bed_choir_v1.wav" \
  -i "$a/music/surface_bed_pulse_v1.wav" \
  -i "$a/combat/ship_explosion_v1.wav" \
  "${fire_inputs[@]}" \
  -filter_complex "
    [0:a]$(loop $total),volume='if(lt(t,25.5),1,if(lt(t,27),1-(t-25.5)/1.5,if(lt(t,51),0,min(1,(t-51)/1.5))))':eval=frame[sd];
    [1:a]$(loop $total),volume='0.8*if(lt(t,25.5),min(1,t/4),if(lt(t,27),1-(t-25.5)/1.5,if(lt(t,51),0,min(1,(t-51)/1.5))))':eval=frame[sh];
    [2:a]$(loop $total),volume='1.1*if(lt(t,5.5),0,if(lt(t,25.5),min(1,(t-5.5)/1.5),if(lt(t,27),1-(t-25.5)/1.5,if(lt(t,55),0,min(1,(t-55)/1.0)))))':eval=frame[sm];
    [3:a]$(loop $total),volume='if(lt(t,24.5),0,if(lt(t,26),(t-24.5)/1.5,if(lt(t,38),1,if(lt(t,39.5),1-(t-38)/1.5,0))))':eval=frame[fd];
    [4:a]$(loop $total),volume='0.8*if(lt(t,24.5),0,if(lt(t,26),(t-24.5)/1.5,if(lt(t,38),1,if(lt(t,39.5),1-(t-38)/1.5,0))))':eval=frame[fs];
    [5:a]$(loop $total),volume='1.1*if(lt(t,25.5),0,if(lt(t,38),1,if(lt(t,39.5),1-(t-38)/1.5,0)))':eval=frame[fg];
    [6:a]$(loop $total),volume='if(lt(t,37.5),0,if(lt(t,39),(t-37.5)/1.5,if(lt(t,51),1,if(lt(t,52.5),1-(t-51)/1.5,0))))':eval=frame[uw];
    [7:a]$(loop $total),volume='0.9*if(lt(t,44),0,if(lt(t,45.5),(t-44)/1.5,if(lt(t,51),1,if(lt(t,52.5),1-(t-51)/1.5,0))))':eval=frame[uc];
    [8:a]$(loop $total),volume='1.1*if(lt(t,38),0,if(lt(t,51),1,if(lt(t,52.5),1-(t-51)/1.5,0)))':eval=frame[up];
    [9:a]aresample=48000,volume=0.9,adelay=36050|36050[boom];
    ${fire_chain}
    aevalsrc='0.55*sin(2*PI*(38+22*exp(-3*t))*t)*exp(-2.2*t)':s=48000:d=3,adelay=1600|1600[hit1];
    aevalsrc='0.55*sin(2*PI*(38+22*exp(-3*t))*t)*exp(-2.2*t)':s=48000:d=3,adelay=56900|56900[hit2];
    anoisesrc=color=pink:amplitude=0.5:d=4:r=48000,bandpass=f=900:w=1400,volume='2.2*sin(PI*min(t/4,1))^2':eval=frame,adelay=27000|27000[whoosh];
    [sd][sh][sm][fd][fs][fg][uw][uc][up]amix=inputs=9:normalize=0,volume=0.6,highpass=f=30[music];
    ${fire_mix}amix=inputs=${n}:normalize=0[fire];
    [music][fire][boom][hit1][hit2][whoosh]amix=inputs=6:normalize=0,
      afade=t=in:d=1.2,afade=t=out:st=$((total - 3)):d=3,atrim=0:$total,
      alimiter=limit=0.89,aformat=channel_layouts=stereo[out]" \
  -map "[out]" -c:a pcm_s16le "$work/soundtrack.wav"

# Normalise to a streaming-friendly loudness, then mux with the capture.
ffmpeg -y -v error -i "$work/soundtrack.wav" -af loudnorm=I=-16:TP=-1.5:LRA=11 -ar 48000 "$work/soundtrack_norm.wav"
frames="$work/frames"
[[ -d "$frames" ]] || { echo "no captured frames; soundtrack only"; exit 0; }
start=$(grep -oE "ADVERT_START_FRAME [0-9]+" "$work/movie.log" | awk '{print $2}')
[[ "$start" =~ ^[0-9]+$ ]] || { echo "missing or ambiguous advert start frame" >&2; exit 1; }
first=""
shopt -s nullglob
for frame in "$frames"/f????????.png; do
  name="${frame##*/}"
  if [[ "$name" =~ ^f([0-9]{8})\.png$ ]]; then
    first="${BASH_REMATCH[1]}"
    break
  fi
done
[[ -n "$first" ]] || { echo "no captured PNG frames" >&2; exit 1; }
# Skip the load/setup frames Movie Maker recorded before the advert clock ran.
ffmpeg -y -v error -framerate 30 -start_number $((10#$first + start)) -i "$frames/f%08d.png" \
  -i "$work/soundtrack_norm.wav" -map 0:v -map 1:a -frames:v $((total * 30)) \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -movflags +faststart \
  -c:a aac -b:a 192k -shortest "$work/mudds_shipyards_advert.mp4"
echo "ADVERT_MP4 $work/mudds_shipyards_advert.mp4"
