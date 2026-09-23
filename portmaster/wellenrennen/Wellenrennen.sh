#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/wellenrennen"
BIN="$GAMEDIR/WaveRace64Recomp.${DEVICE_ARCH}"

cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

ROM=""
for rom in "$GAMEDIR"/*.z64; do
  if [ -f "$rom" ]; then
    ROM="$rom"
    break
  fi
done

if [ -z "$ROM" ]; then
  pm_message "Copy your Wave Race 64 (USA) (Rev A) .z64 ROM into ports/wellenrennen/"
  sleep 5
  pm_finish
  exit 2
fi

$ESUDO chmod +x "$BIN"

# Keep settings and saves inside the port directory.
touch "$GAMEDIR/portable.txt"

# First run: cheapest settings (original water/textures/music, no MSAA,
# 30 Hz, native resolution, no rumble). Existing player choices are kept.
for f in graphics.json sound.json water.json haptics.json; do
  [ -f "$GAMEDIR/$f" ] || cp "$GAMEDIR/defaults/$f" "$GAMEDIR/$f"
done
mkdir -p "$GAMEDIR/gliden64"

# See Sternenfuchs: get_controls only puts one unrelated GUID into
# SDL_GAMECONTROLLERCONFIG, so use the CFW's complete mapping database.
if [ -f "$controlfolder/${CFW_NAME}/gamecontrollerdb.txt" ]; then
  export SDL_GAMECONTROLLERCONFIG_FILE="$controlfolder/${CFW_NAME}/gamecontrollerdb.txt"
fi

$GPTOKEYB "WaveRace64Recomp.${DEVICE_ARCH}" >/dev/null 2>&1 &
pm_platform_helper "$BIN"

# The upstream renderer (RT64) needs Vulkan, which these Mali GLES drivers do
# not have. Render through the bundled GLideN64 plugin on the CFW's own SDL2 +
# OpenGL ES instead.
$ESUDO env \
  WR64_RENDERER=gliden64 \
  WR64_INPUT_SCRIPT="${WR64_INPUT_SCRIPT:-}" \
  WR64_GLIDEN64_PLUGIN="$GAMEDIR/gliden64/mupen64plus-video-GLideN64.so" \
  WR64_GLIDEN64_CORE="$GAMEDIR/gliden64/libwr64_m64pcore.so" \
  SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" \
  SDL_GAMECONTROLLERCONFIG_FILE="$SDL_GAMECONTROLLERCONFIG_FILE" \
  "$BIN" "$ROM"

pm_finish
