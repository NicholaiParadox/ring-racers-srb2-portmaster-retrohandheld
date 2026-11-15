#!/usr/bin/env bash
# =============================================================================
#  Crea un sysroot Debian 13 "Trixie" arm64 en ./sysroot-trixie-arm64
#  (necesario para compilar en cross desde un host x86_64 Debian/Ubuntu)
#  Requiere: apt-get, curl, dpkg-deb (todo estandar en Debian/Ubuntu)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
SYS="$ROOT/sysroot-trixie-arm64"
AR=$(mktemp -d)
trap 'rm -rf "$AR"' EXIT
mkdir -p "$AR"/{etc/apt/sources.list.d,var/lib/apt/lists/partial,var/cache/apt/archives/partial,var/lib/dpkg}
touch "$AR/var/lib/dpkg/status"
echo "deb [arch=arm64 trusted=yes] http://deb.debian.org/debian trixie main" > "$AR/etc/apt/sources.list"

APT=(apt-get -o "Dir=$AR" -o "Dir::State::status=$AR/var/lib/dpkg/status"
     -o APT::Architecture=arm64 -o APT::Architectures=arm64 -o Acquire::Languages=none)

"${APT[@]}" update
PKGS="libc6-dev linux-libc-dev libsdl2-dev libpng-dev zlib1g-dev libcurl4-openssl-dev libopus-dev libegl-dev libgles-dev libdrm-dev libgbm-dev pkg-config"
"${APT[@]}" --no-install-recommends --print-uris -y install $PKGS 2>/dev/null \
	| grep "^'" | sed "s/^'//; s/'[^']*//" > "$AR/urls.txt"

mkdir -p "$AR/debs"
( cd "$AR/debs"
  while read -r u; do
	f=$(basename "${u%%\?*}")
	[ -f "$f" ] || curl -sfL --retry 3 -o "$f" "$u"
  done < "$AR/urls.txt"
  mkdir -p "$SYS"
  for d in *.deb; do dpkg-deb -x "$d" "$SYS"; done
)
ln -sfn usr/lib "$SYS/lib"
echo "==> Sysroot listo en: $SYS"
