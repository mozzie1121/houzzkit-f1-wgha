#!/bin/bash
# Rebuild rk3568-jl-rm01.dtb from the HAOS kernel tree.
# Usage: rebuild-kernel-dtb.sh [kernel-tree]
set -e
K=${1:-/home/mozzie/kernel-6.1-rm01-haos}
cd "$K"

cpp -nostdinc -I arch/arm64/boot/dts -I arch/arm64/boot/dts/include \
    -I scripts/dtc/include-prefixes -I drivers/of/testcase-data \
    -undef -D__DTS__ -x assembler-with-cpp \
    arch/arm64/boot/dts/rockchip/rk3568-jl-rm01.dts -o /tmp/rm01.dts

scripts/dtc/dtc -I dts -O dtb \
    -o arch/arm64/boot/dts/rockchip/rk3568-jl-rm01.dtb \
    -b 0 -i arch/arm64/boot/dts -@ /tmp/rm01.dts

echo "DTB: arch/arm64/boot/dts/rockchip/rk3568-jl-rm01.dtb"
sha256sum arch/arm64/boot/dts/rockchip/rk3568-jl-rm01.dtb
