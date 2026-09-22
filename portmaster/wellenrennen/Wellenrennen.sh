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

# See Sternenfuchs: get_controls only puts one unrelated GUID into
# SDL_GAMECONTROLLERCONFIG, so use the CFW's complete mapping database.
if [ -f "$controlfolder/${CFW_NAME}/gamecontrollerdb.txt" ]; then
  export SDL_GAMECONTROLLERCONFIG_FILE="$controlfolder/${CFW_NAME}/gamecontrollerdb.txt"
fi

# RT64 renders only through Vulkan. Mali blobs shipped by these CFWs have no
# Vulkan, so Vulkan comes from PortMaster's Mesapack (Lavapipe) and the window
# from Westonpack (Weston + Xwayland, shown through the CFW's own SDL2/GLES).
runtime_mount() {
  local name="$1" dir="$2"
  if [ ! -f "$controlfolder/libs/${name}.squashfs" ]; then
    if [ ! -f "$controlfolder/harbourmaster" ]; then
      pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
      sleep 5
      exit 1
    fi
    $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${name}.squashfs"
  fi
  $ESUDO mkdir -p "$dir"
  if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "$dir" 2>/dev/null
  fi
  $ESUDO mount "$controlfolder/libs/${name}.squashfs" "$dir"
}

weston_dir=/tmp/weston
mesa_dir=/tmp/mesa
runtime_mount weston_pkg_0.2 "$weston_dir"
runtime_mount mesa_pkg_0.1 "$mesa_dir"

$GPTOKEYB "WaveRace64Recomp.${DEVICE_ARCH}" >/dev/null 2>&1 &

pm_platform_helper "$BIN"

# libs.aarch64 holds only what the runtimes lack: the Khronos Vulkan loader,
# the xcb extensions Lavapipe links against, and an X11-capable SDL2.
$ESUDO env \
  VK_ICD_FILENAMES="$mesa_dir/share/vulkan/icd.d/lvp_icd.aarch64.json" \
  WRAPPED_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}" \
  WESTON_KIOSK_NO_RESIZE=1 \
  $weston_dir/westonwrap.sh drm gl kiosk llvmpipe \
  WAYLAND_DISPLAY= SDL_VIDEODRIVER=x11 \
  SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" \
  SDL_GAMECONTROLLERCONFIG_FILE="$SDL_GAMECONTROLLERCONFIG_FILE" \
  "$BIN" "$ROM"

$ESUDO $weston_dir/westonwrap.sh cleanup
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "$weston_dir"
  $ESUDO umount "$mesa_dir"
fi
pm_finish
