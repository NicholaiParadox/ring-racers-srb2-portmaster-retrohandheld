#!/usr/bin/env bash
# =============================================================================
#  Ring Racers -> dArkOSRE / R36S (RK3326, Debian 13 "Trixie") build script
#
#  Usage:
#    ./build-r36s.sh cross     # cross-compile from an x86_64 Debian host
#    ./build-r36s.sh native    # compile on the R36S itself (slow, needs deps)
#    ./build-r36s.sh package   # assemble a ready-to-copy dArkOSRE folder
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
*)
	echo "Usage: $0 {cross|native|package}"; exit 1
	;;
esac
