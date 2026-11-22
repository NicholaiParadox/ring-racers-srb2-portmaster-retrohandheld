#!/usr/bin/env bash
# =============================================================================
#  Ring Racers -> dArkOSRE / R36S (RK3326, Debian 13 "Trixie") build script
#
#  Usage:
#    ./build-r36s.sh cross     # cross-compile from an x86_64 Debian host
#    ./build-r36s.sh native    # compile on the R36S itself (slow, needs deps)
#    ./build-r36s.sh package   # assemble a ready-to-copy dArkOSRE folder
#    ./build-r36s.sh bullseye  # Debian 11 / Ubuntu 20.04 (glibc 2.31) build for PortMaster (see
#                              # .github/workflows/build-bullseye.yml): checks portability + bundles libs
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

BUILD_DIR=build-r36s
ARCH_FLAGS="-mcpu=cortex-a35+crc -fomit-frame-pointer -fno-math-errno"
# Keep float math conservative enough for netgame demos, but tune hard for A35:
PERF_FLAGS="-O3 -funroll-loops -ffp-contract=fast"

COMMON_CMAKE_ARGS=(
	-DCMAKE_BUILD_TYPE=Release
	-DSRB2_GLES2=ON                          # native OpenGL ES 2.0 for Mali-G31
	-DSRB2_CONFIG_HWRENDER=OFF               # legacy desktop-GL renderer cannot work on GLES-only Mali
	-DSRB2_CONFIG_ENABLE_WEBM_MOVIES=OFF     # saves RAM/CPU, not needed on handheld
	-DSRB2_CONFIG_ENABLE_DISCORDRPC=OFF      # no Discord on the R36S
	-DSRB2_CONFIG_STATIC_STDLIB=OFF
	-DSRB2_SDL2_EXE_SUFFIX=r36s
	-DUSE_CCACHE=OFF
	-DCMAKE_C_FLAGS="${ARCH_FLAGS} ${PERF_FLAGS}"
	-DCMAKE_CXX_FLAGS="${ARCH_FLAGS} ${PERF_FLAGS}"
)

do_configure() {
	echo "==> Configuring Ring Racers for R36S..."
	cmake -B "$BUILD_DIR" "${COMMON_CMAKE_ARGS[@]}" "$@"
}

case "${1:-cross}" in
cross)
	command -v aarch64-linux-gnu-gcc >/dev/null || {
		echo "ERROR: install 'crossbuild-essential-arm64' first (see cmake/r36s-aarch64.toolchain.cmake)"; exit 1; }
	do_configure -DCMAKE_TOOLCHAIN_FILE=cmake/r36s-aarch64.toolchain.cmake
	cmake --build "$BUILD_DIR" -j"$(nproc)"
	echo "==> Binary: $BUILD_DIR/bin/"
	;;
native)
	do_configure
	cmake --build "$BUILD_DIR" -j"$(nproc)"
	echo "==> Binary: $BUILD_DIR/bin/"
	;;
bullseye)
	# Build meant to run on any PortMaster firmware with glibc >= 2.31 (run it inside a Debian 11
	# bullseye / Ubuntu 20.04 environment, NOT on trixie/noble: the glibc you build on is the minimum).
	# Only SDL2/EGL/GLES come from the firmware; libpng/libopus are bundled in libs.aarch64/.
	extra=()
	[ -n "${RR_PREFIX_PATH:-}" ] && extra+=("-DCMAKE_PREFIX_PATH=${RR_PREFIX_PATH}")
	do_configure "${extra[@]}"
	cmake --build "$BUILD_DIR" -j"$(nproc)"
	./build-r36s.sh check-portable
	./build-r36s.sh bundle-libs
	;;
check-portable)
	BIN="$(ls "$BUILD_DIR"/bin/ringracers* 2>/dev/null | head -n1 || true)"
	[ -n "$BIN" ] || { echo "ERROR: no binary found in $BUILD_DIR/bin"; exit 1; }
	MAX_GLIBC="${RR_MAX_GLIBC:-2.31}"
	MAX_GLIBCXX="${RR_MAX_GLIBCXX:-3.4.28}"
	# "$1" is greater than "$2" in version order
	ver_gt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ]; }
	echo "==> $BIN"
	echo "==> Needed libraries:"; readelf -d "$BIN" | awk '/NEEDED/{gsub(/[\[\]]/,"",$5); print "     " $5}'
	fail=0
	for v in $(objdump -T "$BIN" | grep -o 'GLIBC_[0-9][0-9.]*' | sed 's/GLIBC_//' | sort -Vu || true); do
		if ver_gt "$v" "$MAX_GLIBC"; then
			echo "  FAIL: needs GLIBC_$v (maximum allowed: $MAX_GLIBC). Symbols:"
			objdump -T "$BIN" | grep "GLIBC_$v" | awk '{print "     " $NF}' | head -n 5
			fail=1
		fi
	done
	for v in $(objdump -T "$BIN" | grep -o 'GLIBCXX_[0-9][0-9.]*' | sed 's/GLIBCXX_//' | sort -Vu || true); do
		if ver_gt "$v" "$MAX_GLIBCXX"; then
			echo "  FAIL: needs GLIBCXX_$v (maximum allowed: $MAX_GLIBCXX)"; fail=1
		fi
	done
	# Libraries that are allowed to come from the firmware / glibc; anything else must be bundled.
	for n in $(readelf -d "$BIN" | awk '/NEEDED/{gsub(/[\[\]]/,"",$5); print $5}'); do
		case "$n" in
			libSDL2-2.0.so.0|libpng16.so.16|libopus.so.0|libz.so.1|libm.so.6|libc.so.6|libpthread.so.0|libdl.so.2|librt.so.1|libstdc++.so.6|libgcc_s.so.1|ld-linux-aarch64.so.1) ;;
			*) echo "  WARNING: unexpected dependency $n (is it on every firmware?)" ;;
		esac
	done
	if [ "$fail" = 0 ]; then echo "==> OK: binary needs at most glibc $MAX_GLIBC / GLIBCXX $MAX_GLIBCXX"; else exit 1; fi
	;;
bundle-libs)
	BIN="$(ls "$BUILD_DIR"/bin/ringracers* 2>/dev/null | head -n1 || true)"
	[ -n "$BIN" ] || { echo "ERROR: no binary found in $BUILD_DIR/bin"; exit 1; }
	rm -rf "$BUILD_DIR/libs.aarch64" && mkdir -p "$BUILD_DIR/libs.aarch64"
	# ldd lines look like:  libpng16.so.16 => /lib/aarch64-linux-gnu/libpng16.so.16 (0x...)
	for pat in 'libpng16\.so' 'libopus\.so'; do
		line="$(ldd "$BIN" | awk -v p="^${pat}" '$1 ~ p && $3 ~ /^\// {print $1 " " $3; exit}' || true)"
		if [ -n "$line" ]; then
			name="${line%% *}"; path="${line##* }"
			cp -L "$path" "$BUILD_DIR/libs.aarch64/$name"
			echo "==> bundled $name (from $path)"
		else
			echo "WARNING: $pat not found among the binary's dependencies"
		fi
	done
	ls -la "$BUILD_DIR/libs.aarch64"
	# Make the executable look for the bundled libs next to itself, even if the launcher does not set
	# LD_LIBRARY_PATH (RUNPATH is searched before the system library directories).
	if command -v patchelf >/dev/null 2>&1; then
		patchelf --set-rpath '$ORIGIN/libs.aarch64' "$BIN"
		echo "==> RPATH: $(patchelf --print-rpath "$BIN")"
	else
		echo "WARNING: patchelf not found; the launcher must set LD_LIBRARY_PATH=<port>/libs.aarch64"
	fi
	;;
package)
	./build-r36s.sh package-only
	;;
package-only)
	OUT=dist/ringracers-r36s
	rm -rf "$OUT" && mkdir -p "$OUT"
	cp "$BUILD_DIR"/bin/ringracers* "$OUT"/
	cp packaging/r36s/run-r36s.sh "$OUT"/start-ringracers.sh
	chmod +x "$OUT"/start-ringracers.sh
	cp packaging/r36s/README-R36S.txt "$OUT"/LEEME.txt
	tar -czf dist/ringracers-r36s.tar.gz -C dist ringracers-r36s
	echo "==> Package: dist/ringracers-r36s.tar.gz"
	;;
portmaster)
	# PortMaster layout: RingRacers.sh + ringracers/ (+ port.json) -> dist/RingRacers.zip
	OUT=dist/portmaster
	rm -rf "$OUT" && mkdir -p "$OUT/ringracers"
	cp "$BUILD_DIR"/bin/ringracers* "$OUT/ringracers/"
	chmod +x "$OUT"/ringracers/ringracers*
	cp packaging/r36s/RingRacers.sh "$OUT/RingRacers.sh"
	cp packaging/r36s/gamecontrollerdb.txt packaging/r36s/fetch-assets.sh "$OUT/ringracers/"
	cp packaging/r36s/README-R36S.txt "$OUT/ringracers/README.txt"
	cp packaging/portmaster/port.json "$OUT/ringracers/port.json"
	cp packaging/portmaster/gameinfo.xml "$OUT/ringracers/gameinfo.xml"
	if [ -d "$BUILD_DIR/libs.aarch64" ]; then cp -r "$BUILD_DIR/libs.aarch64" "$OUT/ringracers/"; fi
	chmod +x "$OUT/RingRacers.sh" "$OUT/ringracers/fetch-assets.sh"
	(cd "$OUT" && zip -qr ../RingRacers.zip RingRacers.sh ringracers)
	echo "==> PortMaster package: dist/RingRacers.zip"
	;;
*)
	echo "Usage: $0 {cross|native|bullseye|check-portable|bundle-libs|package|portmaster}"; exit 1
	;;
esac
