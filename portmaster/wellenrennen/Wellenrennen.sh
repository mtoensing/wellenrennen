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
> "$GAMEDIR/portmaster.log" && exec > >(tee "$GAMEDIR/portmaster.log") 2>&1

ROM=""
for rom in "$GAMEDIR"/*.z64; do
  if [ -f "$rom" ]; then
    ROM="$rom"
    break
  fi
done

if [ -z "$ROM" ]; then
  echo "Wave Race 64 (USA) (Rev A) .z64 ROM not found in $GAMEDIR"
  pm_finish
  exit 2
fi

if [ ! -f "$BIN" ]; then
  echo "Missing ARM64 binary: $BIN"
  pm_finish
  exit 3
fi

$ESUDO chmod +x "$BIN"

# Keep settings and saves inside the portable PortMaster directory.
touch "$GAMEDIR/portable.txt"

$GPTOKEYB "WaveRace64Recomp.${DEVICE_ARCH}" >/dev/null 2>&1 &

pm_platform_helper "$BIN"
"$BIN" "$ROM"
STATUS=$?

pm_finish
exit $STATUS
