#!/usr/bin/env bash
# =============================================================================
#  Ring Racers - lanzador para dArkOSRE (R36S / Debian 13 arm64)
#  Coloca este script junto al binario y a los assets del juego.
# =============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# --- GPU: usa el backend GLES2 nativo (Mali-G31) -----------------------------
export SRB2_GLES2=1

# Si tu firmware no asigna un mapeo de mando a SDL2, descomenta y ajusta:
# export SDL_GAMECONTROLLERCONFIG="030000005e0400008e02000010010000,Generic X-Box pad,a:b0,b:b1,x:b2,y:b3,start:b7,back:b6,guide:b8,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftshoulder:b4,rightshoulder:b5,lefttrigger:b6,righttrigger:b7,leftstick:b9,rightstick:b10,"

BIN="$(ls "$DIR"/ringracers* 2>/dev/null | head -n1)"
if [ -z "$BIN" ]; then
	echo "No se encontro el binario ringracers* en $DIR"
	read -p "Pulsa ENTER para salir"
	exit 1
fi

# Nota: la combinacion Start+Select sale del juego en cualquier momento.
exec "$BIN" -fullscreen "$@"
