#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/mosaic-os/config.json"
JSON_PATH=".screenRecord.savePath"

CUSTOM_PATH=$(jq -r "$JSON_PATH" "$CONFIG_FILE" 2>/dev/null)

RECORDING_DIR=""

if [[ -n "$CUSTOM_PATH" ]]; then
  RECORDING_DIR="$CUSTOM_PATH"
else
  RECORDING_DIR="$HOME/Videos" # Use default path
fi

getdate() {
  date '+%Y-%m-%d_%H.%M.%S'
}
# Mosaic OS: the sound to record (Gravação tab: screenRecord.audio)
# - system: what the default output is playing (its .monitor). The ii listed every
#   monitor source and passed them all as one name, which broke recording with sound.
# - mic: the default input
getaudiooutput() {
  case "$AUDIO_MODE" in
  mic) pactl get-default-source ;;
  *) echo "$(pactl get-default-sink).monitor" ;;
  esac
}
getactivemonitor() {
  hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

# Mosaic OS: resolution and fps from the Gravação tab (config.json, screenRecord)
RES=$(jq -r '.screenRecord.resolution // "native"' "$CONFIG_FILE" 2>/dev/null)
FPS=$(jq -r '.screenRecord.fps // 60' "$CONFIG_FILE" 2>/dev/null)
AUDIO_MODE=$(jq -r '.screenRecord.audio // "system"' "$CONFIG_FILE" 2>/dev/null)
EXTRA=()
[[ "$FPS" =~ ^[0-9]+$ ]] && ((FPS > 0)) && EXTRA+=(-f "$FPS")
[[ "$RES" =~ ^[0-9]+$ ]] && EXTRA+=(-s "$((RES * 16 / 9))x$RES")
mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit

# parse --region <value> without modifying $@ so other flags like --fullscreen still work
ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
FULLSCREEN_FLAG=0
for ((i = 0; i < ${#ARGS[@]}; i++)); do
  if [[ "${ARGS[i]}" == "--region" ]]; then
    if ((i + 1 < ${#ARGS[@]})); then
      MANUAL_REGION="${ARGS[i + 1]}"
    else
      notify-send "Recording cancelled" "No region specified for --region" -a 'Recorder' &
      disown
      exit 1
    fi
  elif [[ "${ARGS[i]}" == "--sound" ]]; then
    [[ "$AUDIO_MODE" != "none" ]] && SOUND_FLAG=1 # "Sem som" in the Gravação tab wins
  elif [[ "${ARGS[i]}" == "--fullscreen" ]]; then
    FULLSCREEN_FLAG=1
  fi
done

if pgrep gpu-screen-recorder >/dev/null; then
  notify-send "Recording Stopped" "Stopped" -a 'Recorder' &
  pkill -INT -f gpu-screen-recorder &
else
  if [[ $FULLSCREEN_FLAG -eq 1 ]]; then
    notify-send "Starting recording" 'recording_'"$(getdate)"'.mp4' -a 'Recorder' &
    disown
    if [[ $SOUND_FLAG -eq 1 ]]; then
      gpu-screen-recorder "${EXTRA[@]}" -w "$(getactivemonitor)" -a default_output -k h264 -q very_high -o './recording_'"$(getdate)"'.mp4'
    else
      gpu-screen-recorder "${EXTRA[@]}" -w "$(getactivemonitor)" -k h264 -q very_high -o './recording_'"$(getdate)"'.mp4'
    fi
  else
    # If a manual region was provided via --region, use it; otherwise run slurp as before.
    if [[ -n "$MANUAL_REGION" ]]; then
      region="$MANUAL_REGION"
    else
      if ! region="$(slurp 2>&1)"; then
        notify-send "Recording cancelled" "Selection was cancelled" -a 'Recorder' &
        disown
        exit 1
      fi
    fi

    notify-send "Starting recording" 'recording_'"$(getdate)"'.mp4' -a 'Recorder' &
    disown
    if [[ $SOUND_FLAG -eq 1 ]]; then
      wf-recorder "${EXTRA[@]}" --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$region" --audio="$(getaudiooutput)"
    else
      wf-recorder "${EXTRA[@]}" --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$region"
    fi
  fi
fi
