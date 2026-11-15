# =============================================================================
# dArkOSRE / R36S (RK3326, Cortex-A35, Debian 13 "Trixie" arm64) toolchain
#
# Cross-compile from an x86_64 Debian host:
#   sudo apt install crossbuild-essential-arm64 cmake ninja-build pkg-config
#
# You need a Debian 13 arm64 sysroot (default: ../sysroot-trixie-arm64,
# override with -DR36S_SYSROOT=...). build-r36s.sh can create it for you.
# =============================================================================
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(TOOLCHAIN_PREFIX aarch64-linux-gnu)

set(CMAKE_C_COMPILER   ${TOOLCHAIN_PREFIX}-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}-g++)

set(R36S_SYSROOT "${CMAKE_CURRENT_LIST_DIR}/../sysroot-trixie-arm64" CACHE PATH "Debian 13 arm64 sysroot")
set(CMAKE_SYSROOT "${R36S_SYSROOT}")
set(CMAKE_LIBRARY_ARCHITECTURE aarch64-linux-gnu)

set(CMAKE_FIND_ROOT_PATH "${R36S_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# --- dependency hints, all inside the sysroot --------------------------------
set(ZLIB_ROOT "${R36S_SYSROOT}/usr")
set(PNG_ROOT  "${R36S_SYSROOT}/usr")
set(CURL_ROOT "${R36S_SYSROOT}/usr")
set(OPENSSL_ROOT_DIR "${R36S_SYSROOT}/usr")
set(SDL2_DIR  "${R36S_SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}/cmake/SDL2")

set(ENV{PKG_CONFIG_LIBDIR} "${R36S_SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}/pkgconfig:${R36S_SYSROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${R36S_SYSROOT}")

# --- engine tuning for the RK3326 (4x Cortex-A35) ----------------------------
set(R36S_ARCH_FLAGS "-mcpu=cortex-a35+crc" CACHE STRING "R36S CPU flags")
