#!/bin/bash
# =============================================================================
#  DR. ROBOTNIK'S RING RACERS - Port para dArkOSRE (R36S / Debian 13 arm64)
#
#  INSTALACION:
#    1) Copia esta carpeta COMPLETA a:  /roms/ports/ringracers-r36s
#    2) Copia "RingRacers.sh" a:        /roms/ports/RingRacers.sh
#       (tambien vale dejarlo solo dentro de la carpeta; se autodetecta)
#    3) Los assets (.pk3) van junto al binario ringracers_r36s
#    4) En EmulationStation: Ports -> Ring Racers
#
#  SALIR DEL JUEGO: START + SELECT a la vez
# =============================================================================
MYDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Localiza la carpeta del juego -------------------------------------------
# Si este .sh esta en /roms/ports, busca el juego en el subdirectorio tipico;
# si esta dentro de la propia carpeta del juego, usa su ubicacion.
GAMEDIR=""
for CAND in \
	"$MYDIR/ringracers-r36s" \
	"$MYDIR/RingRacers" \
	"$MYDIR" ; do
	if [ -x "$CAND/ringracers_r36s" ]; then
		GAMEDIR="$CAND"
		break
	fi
done

if [ -z "$GAMEDIR" ]; then
	echo "ERROR: no se encontro 'ringracers_r36s' cerca de $MYDIR"
	echo "Coloca este script en /roms/ports o dentro de la carpeta del juego."
	read -rp "Pulsa ENTER para salir..."
	exit 1
fi

cd "$GAMEDIR" || exit 1

# --- Entorno -----------------------------------------------------------------
# El backend GLES2 nativo (Mali-G31) se elige al COMPILAR (-DSRB2_GLES2=ON);
# no hay variable de entorno que lo active. NO uses gl4es ni libs de otros
# ports: limpiamos rutas heredadas para que no se cargue un SDL2/EGL ajeno.
unset LD_PRELOAD
unset LD_LIBRARY_PATH
# Sin X11 (dArkOS normal) SDL2 debe usar KMS/DRM + EGL/GLES2 del sistema.
if [ -z "${DISPLAY:-}" ] && [ -z "${SDL_VIDEODRIVER:-}" ]; then
	export SDL_VIDEODRIVER=kmsdrm
fi
# Audio por ALSA directo (como el resto de ports de la consola):
export SDL_AUDIODRIVER=alsa
# Log para diagnosticar (se sobrescribe en cada arranque):
exec > "$GAMEDIR/launch.log" 2>&1
set -x

# --- Mando -------------------------------------------------------------------
# Prioridad de mapeo:
#   1) gamecontrollerdb.txt junto al binario (incluye el pad "GO-Super
#      Gamepad", identico al Odroid Go Super, y clones play_joystick).
#   2) Lo que exporte el firmware en SDL_GAMECONTROLLERCONFIG.
#   3) Base de datos de PortMaster, si existe.
# Ademas, el motor carga gamecontrollerdb.txt automaticamente desde su
# carpeta de trabajo (srb2path).
DBFILE="$GAMEDIR/gamecontrollerdb.txt"
if [ -f "$DBFILE" ]; then
	export SDL_GAMECONTROLLERCONFIG_FILE="$DBFILE"
fi
if [ -z "${SDL_GAMECONTROLLERCONFIG:-}" ] && [ -z "${SDL_GAMECONTROLLERCONFIG_FILE:-}" ]; then
	PM_DB=""
	for DB in "/opt/portmaster/libs/sdl2/db/controller.darmosre.txt" \
	          "/opt/portmaster/libs/sdl2/db/controller.txt" ; do
		if [ -f "$DB" ]; then
			PM_DB="$DB"
			break
		fi
	done
	if [ -n "$PM_DB" ]; then
		export SDL_GAMECONTROLLERCONFIG="$(grep -h -v '^[[:space:]]*#' "$PM_DB")"
	fi
fi

# D-pad tambien como stick analógico, START = pausa/ESC, START+SELECT = salir.
# Todo esto es codigo del motor; se puede ajustar en la consola del juego:
#   dpadasstick off   startpause off   quitcombo off

# --- Ejecutar -----------------------------------------------------------------
# START+SELECT dentro del juego sale limpiamente en cualquier momento.
#
# NOTA: si en tu variante de firmware la pantalla se queda en negro al abrir
# el port (firmwares que lanzan los juegos dentro de X11), comenta la linea
# "exec_game" de abajo y descomenta el bloque X11:
#
#   # --- lanzar dentro de X11 (solo si hay pantalla negra) ---
#   if [ -z "${DISPLAY:-}" ]; then
#       xinit "$GAMEDIR/ringracers_r36s" -fullscreen -- :0 vt1
#   else
#       "$GAMEDIR/ringracers_r36s" -fullscreen
#   fi
#   exit $?
#
exec_game() {
	"$GAMEDIR/ringracers_r36s" -fullscreen
}

exec_game
exit $?
