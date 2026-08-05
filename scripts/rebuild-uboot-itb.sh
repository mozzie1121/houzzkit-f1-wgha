#!/bin/bash
# Rebuild the RM01 U-Boot ITB (loader-mode build).
# Usage: rebuild-uboot-itb.sh [src] [out] [rkbin]
set -e
SRC=${1:-/home/mozzie/u-boot-haos-modern-rm01-recovery-loader-src}
OUT=${2:-/home/mozzie/u-boot-haos-modern-build-rm01-recovery-loader}
RK=${3:-/home/mozzie/houzzkit-f1-opensource/houzzkit-f1-bsp-k6199/rkbin}

make -C "$SRC" O="$OUT" ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- \
    BL31="$RK/bin/rk35/rk3568_bl31_v1.44.elf" \
    ROCKCHIP_TPL="$RK/bin/rk35/rk3568_ddr_1560MHz_v1.19.bin" -j"$(nproc)"

echo "ITB:   $OUT/u-boot.itb  -> eMMC LBA 0x4000"
echo "SPL:   $OUT/idbloader.img -> eMMC LBA 0x40"
sha256sum "$OUT/u-boot.itb" "$OUT/idbloader.img"
