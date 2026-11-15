#!/bin/bash
# =============================================================================
#  DR. ROBOTNIK'S RING RACERS - Port para dArkOSRE (R36S / Debian 13 arm64)
#
#  INSTALACION:
#    1) Copia la carpeta del juego a:   /roms/ports/ringracers
#    2) Copia este "RingRacers.sh" a:   /roms/ports/RingRacers.sh
#    3) Los assets (.pk3) van junto al ejecutable (RingRacers o ringracers_r36s)
#    4) En EmulationStation: Ports -> Ring Racers
#
#  SALIR DEL JUEGO: START + SELECT a la vez
#
#  DIAGNOSTICO: cada arranque escribe  <carpeta del juego>/launch.log  con
#  datos de hardware, librerias, almacenamiento, el log del juego y muestras
#  de CPU/temperatura/memoria cada 5 s. Envia ese archivo para depurar.
#  (el anterior se conserva como launch.prev.log)
# =============================================================================
MYDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Registro previo (se escribe aunque el juego no se encuentre) ----------------
PRELOG="$MYDIR/RingRacers-launcher.log"
{
	echo "== $(date) =="
	echo "script: ${BASH_SOURCE[0]}   MYDIR: $MYDIR   usuario: $(id -un)"
} > "$PRELOG" 2>/dev/null

# --- Localiza la carpeta del juego y el ejecutable --------------------------------
GAMEDIR=""
BIN=""
for CAND in \
	"$MYDIR/RingRacers" \
	"$MYDIR/ringracers" \
	"$MYDIR/ringracers-r36s" \
	"$MYDIR" ; do
	[ -d "$CAND" ] || continue
	# Nombres conocidos primero, luego cualquier "ringracers*" (p. ej. ringracers_main_r36s).
	# Solo archivos normales: un directorio llamado RingRacers NO cuenta como ejecutable.
	for F in "$CAND/RingRacers" "$CAND/ringracers_r36s" "$CAND/ringracers_main_r36s" "$CAND/ringracers" "$CAND"/ringracers_* "$CAND"/RingRacers_*; do
		[ -f "$F" ] || continue
		case "$F" in
			*.sh|*.txt|*.log|*.pk3|*.md5cache|*.dat|*.cfg|*.json) continue ;;
		esac
		echo "encontrado: $F (ejecutable: $([ -x "$F" ] && echo si || echo no))" >> "$PRELOG" 2>/dev/null
		# Al copiar desde Windows se puede perder el permiso de ejecucion: lo restauramos.
		[ -x "$F" ] || chmod +x "$F" 2>>"$PRELOG"
		if [ -x "$F" ]; then
			GAMEDIR="$CAND"
			BIN="$F"
			break 2
		fi
	done
done

if [ -z "$BIN" ]; then
	{
		echo "ERROR: no se encontro un ejecutable usable (RingRacers / ringracers_r36s / ringracers_main_r36s)."
		echo "Contenido de $MYDIR:"
		ls -la "$MYDIR" 2>&1 | head -n 40
	} >> "$PRELOG" 2>&1
	echo "ERROR: no se encontro el ejecutable del juego. Revisa $PRELOG"
	sleep 5
	exit 1
fi
echo "usando: $BIN" >> "$PRELOG" 2>/dev/null

cd "$GAMEDIR" || exit 1

# --- Log: rota el anterior y redirige todo --------------------------------------
LOG="$GAMEDIR/launch.log"
[ -f "$LOG" ] && mv -f "$LOG" "$GAMEDIR/launch.prev.log"
exec > "$LOG" 2>&1

section() { echo; echo "===== $* ====="; }
tsmsg()   { echo "[$(date '+%H:%M:%S')] $*"; }

# --- Entorno -----------------------------------------------------------------
# El backend GLES2 nativo (Mali-G31) se elige al COMPILAR (-DSRB2_GLES2=ON).
# NO uses gl4es ni libs de otros ports: limpiamos rutas heredadas.
unset LD_PRELOAD
unset LD_LIBRARY_PATH
if [ -z "${DISPLAY:-}" ] && [ -z "${SDL_VIDEODRIVER:-}" ]; then
	export SDL_VIDEODRIVER=kmsdrm
fi
export SDL_AUDIODRIVER=alsa
# Mensajes de depuracion de SDL (video/render/audio/input) al log:
export SDL_LOGGING="${SDL_LOGGING:-*=info}"
# Mesa (si el sistema usa Panfrost en vez del driver Mali propietario):
export MESA_DEBUG="${MESA_DEBUG:-1}"
export EGL_LOG_LEVEL="${EGL_LOG_LEVEL:-debug}"

# =============================================================================
#  INFORMACION DEL SISTEMA
# =============================================================================
section "FECHA / VERSIONES"
date
echo "script:  $0"
echo "gamedir: $GAMEDIR"
uname -a
[ -f /etc/os-release ] && grep -E '^(PRETTY_NAME|VERSION)=' /etc/os-release
for f in /etc/dArkOS* /etc/darkos* /etc/arkos* /usr/share/dArkOS*; do
	[ -e "$f" ] && { echo "-- $f"; head -n 5 "$f" 2>/dev/null; }
done
echo "usuario: $(id)"
echo "ulimit -n: $(ulimit -n)"

section "CPU"
grep -m1 -E 'Hardware|Model|model name' /proc/cpuinfo
echo "nucleos: $(nproc)"
grep -m1 'CPU part' /proc/cpuinfo
grep -m1 Features /proc/cpuinfo
for c in /sys/devices/system/cpu/cpu[0-9]*; do
	n=$(basename "$c")
	echo "$n: online=$(cat "$c/online" 2>/dev/null || echo 1)" \
	     "gov=$(cat "$c/cpufreq/scaling_governor" 2>/dev/null)" \
	     "cur=$(cat "$c/cpufreq/scaling_cur_freq" 2>/dev/null)" \
	     "min=$(cat "$c/cpufreq/scaling_min_freq" 2>/dev/null)" \
	     "max=$(cat "$c/cpufreq/scaling_max_freq" 2>/dev/null)" \
	     "disp=$(cat "$c/cpufreq/scaling_available_frequencies" 2>/dev/null)"
done

section "MEMORIA"
grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|CmaTotal|CmaFree' /proc/meminfo

section "TEMPERATURAS"
for t in /sys/class/thermal/thermal_zone*; do
	[ -e "$t/temp" ] && echo "$(cat "$t/type" 2>/dev/null): $(cat "$t/temp" 2>/dev/null)"
done

section "GPU / VIDEO"
for d in /sys/class/devfreq/*; do
	[ -e "$d" ] || continue
	echo "devfreq $(basename "$d"): cur=$(cat "$d/cur_freq" 2>/dev/null)" \
	     "gov=$(cat "$d/governor" 2>/dev/null)" \
	     "min=$(cat "$d/min_freq" 2>/dev/null)" \
	     "max=$(cat "$d/max_freq" 2>/dev/null)" \
	     "avail=$(cat "$d/available_frequencies" 2>/dev/null)"
done
for c in /sys/class/drm/card*-*; do
	[ -e "$c/status" ] || continue
	echo "drm $(basename "$c"): $(cat "$c/status" 2>/dev/null) modes: $(tr '\n' ' ' < "$c/modes" 2>/dev/null)"
done
ls -l /dev/dri 2>&1
[ -e /sys/class/graphics/fb0/virtual_size ] && echo "fb0: $(cat /sys/class/graphics/fb0/virtual_size) bpp=$(cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null)"
echo "DISPLAY='${DISPLAY:-}' SDL_VIDEODRIVER='${SDL_VIDEODRIVER:-}' XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR:-}'"
if command -v modetest >/dev/null 2>&1; then modetest -c 2>&1 | head -n 25; fi

section "LIBRERIAS GRAFICAS (sistema)"
ldconfig -p 2>/dev/null | grep -E 'libSDL2|libEGL|libGLES|libGLESv2|libgbm|libdrm|libmali|libGL\.|libGLU|libopus|libpng|libcurl' 
echo "-- ldd del ejecutable:"
ldd "$BIN" 2>&1
echo "-- ejecutable:"
ls -l "$BIN"
file "$BIN" 2>/dev/null

section "ALMACENAMIENTO"
df -h "$GAMEDIR" 2>&1
mount 2>/dev/null | grep -E " $(df --output=target "$GAMEDIR" 2>/dev/null | tail -n1) " 
echo "-- archivos del juego:"
ls -l --block-size=M "$GAMEDIR" 2>&1 | head -n 60
# Prueba de lectura secuencial del pk3 mas grande (64 MB). Sin cache de disco si es root.
BIG="$(ls -S "$GAMEDIR"/*.pk3 2>/dev/null | head -n1)"
if [ -n "$BIG" ]; then
	sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
	echo "-- lectura de $(basename "$BIG") (64 MB):"
	dd if="$BIG" of=/dev/null bs=1M count=64 2>&1 | tail -n1
fi

section "VARIABLES SDL / MESA / EGL"
env | grep -E '^(SDL|MESA|EGL|LIBGL|XDG|RR_|MALI|HOME|PATH|LD_)' | grep -v CONTROLLERCONFIG

section "DMESG (gpu / drm / mali / oom / usb / audio, ultimas lineas)"
dmesg 2>/dev/null | grep -i -E 'mali|gpu|drm|panfrost|oom|killed process|thermal|throttl|undervolt|alsa' | tail -n 25

# --- Mando -------------------------------------------------------------------
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
section "MANDOS (/dev/input)"
for j in /sys/class/input/js*; do
	[ -e "$j/device/name" ] && echo "$(basename "$j"): $(cat "$j/device/name")"
done
echo "gamecontrollerdb: ${SDL_GAMECONTROLLERCONFIG_FILE:-${PM_DB:-ninguno}}"

# =============================================================================
#  EJECUCION
# =============================================================================
# Rendimiento: el juego corre a 35 ticks/s; con "Match refresh rate" el motor
# dibuja ~60 cuadros interpolados, muy caro para el CPU de la R36S (el
# renderer por software va en el CPU, no en la GPU). 35 = lo mas ligero.
# Para cambiarlo: RR_FPSCAP=60 ./RingRacers.sh   (o 0 = igual al refresco)
RR_FPSCAP="${RR_FPSCAP:-35}"

# Muestreo en segundo plano cada 5 s: carga, frecuencias, temperatura, memoria
# y CPU/RSS del proceso del juego.
sampler() {
	local gp="$1"
	local i=0
	while true; do
		sleep 5
		i=$((i + 5))
		echo "[muestra +${i}s] load=$(cut -d' ' -f1-3 /proc/loadavg)" \
		     "cpu0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)" \
		     "temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)" \
		     "memavail_kB=$(awk '/MemAvailable/{print $2}' /proc/meminfo)" \
		     "gpu=$(cat /sys/class/devfreq/*gpu*/cur_freq /sys/class/devfreq/*mali*/cur_freq 2>/dev/null | head -n1)" \
		     "juego(pid cpu% rssKB)=$(ps -o pid=,pcpu=,rss= -p "${gp:-0}" 2>/dev/null | tr -s ' ')"
	done
}

section "ARRANQUE DEL JUEGO"
tsmsg "lanzando: $BIN -fullscreen +fpscap $RR_FPSCAP -logdir $GAMEDIR/logs"
T0=$(date +%s)
"$BIN" -fullscreen +fpscap "$RR_FPSCAP" -logdir "$GAMEDIR/logs" &
GAME_PID=$!
sampler "$GAME_PID" &
SAMPLER_PID=$!
wait "$GAME_PID"
RC=$?

kill "$SAMPLER_PID" 2>/dev/null
T1=$(date +%s)

section "FIN"
tsmsg "codigo de salida: $RC (139 = SIGSEGV, 134 = abort, 137 = matado por OOM/kill)"
echo "duracion de la sesion: $((T1 - T0)) s"
echo "temperatura final: $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"

section "DMESG tras la ejecucion"
dmesg 2>/dev/null | grep -i -E 'mali|gpu|drm|panfrost|oom|killed process|thermal|segfault|ringracers' | tail -n 20

section "LOG DEL MOTOR (ultimas 300 lineas)"
ENGLOG="$(ls -t "$GAMEDIR"/logs/*.txt 2>/dev/null | head -n1)"
if [ -n "$ENGLOG" ]; then
	echo "archivo: $ENGLOG"
	tail -n 300 "$ENGLOG"
else
	echo "(no se encontro log del motor en $GAMEDIR/logs)"
fi

exit $RC
