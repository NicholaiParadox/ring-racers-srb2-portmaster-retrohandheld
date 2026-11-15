#!/usr/bin/env bash
# Descarga los assets oficiales de Ring Racers 2.4 (~750 MB) y extrae los .pk3
# junto al binario. Ejecutar en el PC o en la consola (requiere ~1.5 GB libres).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URL="https://github.com/KartKrewDev/RingRacers/releases/download/v2.4/Dr.Robotnik.s-Ring-Racers-v2.4-Assets.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Descargando assets de Ring Racers 2.4..."
curl -L --progress-bar -o "$TMP/assets.zip" "$URL"
echo "Extrayendo..."
unzip -o -q "$TMP/assets.zip" -d "$TMP/x"
find "$TMP/x" -name "*.pk3" -exec cp -v {} "$DIR"/ \;
echo "Listo. Los .pk3 estan en: $DIR"
