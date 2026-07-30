# RK3568-JL-RM01 Home Assistant OS port

Reusable bring-up material for running a locally obtained Home Assistant OS image on the SZZN RK3568-JL-RM01 / RZW03 board.

This repository intentionally contains only small, reviewable source files: U-Boot configuration and DTS, a kernel config fragment, plus the HAOS A/B boot script.  It does **not** contain HAOS images, SD-card images, vendor BSP source, RKbin firmware, built binaries, or serial logs.

## Status

The documented configuration has booted HAOS successfully on the target board:

`U-Boot 2024.10 -> boot.scr -> Linux Image + rk3568-jl-rm01.dtb -> EROFS HAOS root -> zram -> Docker/Supervisor`

The NPU is enabled in the known-good configuration.  U-Boot must initialize the RK809 power rails before Linux starts; see [porting notes](docs/porting-notes.md).

## Prerequisites

Use an Ubuntu host or WSL installation with an AArch64 cross compiler and image tools:

```sh
sudo apt update
sudo apt install build-essential gcc-aarch64-linux-gnu device-tree-compiler \\
  u-boot-tools mtools squashfs-tools e2fsprogs
```

Obtain these locally and keep them outside this Git repository:

- U-Boot v2024.10 source and a compatible Rockchip `rkbin` tree.
- The vendor RK3568 Linux 6.1 BSP containing `rk3568-jl-rm01.dtsi` and `jl_v1_linux_defconfig`.
- The HAOS Panther-X2 image used as the source layout.  Observe the upstream license and distribution terms.

## 1. Build U-Boot

Copy the three files below into the matching paths of a clean U-Boot v2024.10 tree, then add `rk3568-jl-rm01.dtb` to its Rockchip DTB make list if that tree does not discover it automatically.  The board DTS and defconfig deliberately enable the Rockchip I2C controller plus RK809 regulator support and reserve a 128 KiB SPL early-malloc/BSS pool for the HAOS GPT; do not omit those options.

```text
u-boot/configs/rk3568-jl-rm01_defconfig
u-boot/arch/arm/dts/rk3568-jl-rm01.dts
u-boot/arch/arm/dts/rk3568-jl-rm01-u-boot.dtsi
```

Build with the BL31 and DDR/TPL blobs from your matching `rkbin` revision:

```sh
export ARCH=arm
export CROSS_COMPILE=aarch64-linux-gnu-
export BL31=/path/to/rkbin/bin/rk35/rk3568_bl31_v1.44.elf
export ROCKCHIP_TPL=/path/to/rkbin/bin/rk35/rk3568_ddr_1560MHz_v1.19.bin
make rk3568-jl-rm01_defconfig
make -j"$(nproc)"
```

Expected outputs are `idbloader.img` and `u-boot.itb`.  The board's known partition layout places them at these **sector (LBA)** offsets:

| File | LBA offset |
| --- | ---: |
| `idbloader.img` | `0x40` |
| `u-boot.itb` | `0x4000` |

Writing bootloader areas can make a board unbootable. Confirm the original `parameter.txt`, retain a known-working bootloader and recovery method, and use the flashing utility appropriate to your board.

## 2. Build the HAOS-capable kernel

From the vendor kernel tree:

```sh
make ARCH=arm64 jl_v1_linux_defconfig
cat /path/to/houzzkit-f1-wgha/kernel/haos.fragment >> .config
make ARCH=arm64 olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KCFLAGS=-Wno-error -j"$(nproc)" Image dtbs
```

The last `KCFLAGS` is for warnings promoted to errors by the available vendor Wi-Fi driver / GCC combination.  Verify the generated DTB is `arch/arm64/boot/dts/rockchip/rk3568-jl-rm01.dtb` and that the final `.config` retains the EROFS, LZ4, nftables, and cgroup options from the fragment.

## 3. Package the HAOS kernel partition

HAOS expects an LZO SquashFS containing a file named `Image`:

```sh
mkdir -p kernel-root
cp arch/arm64/boot/Image kernel-root/Image
mksquashfs kernel-root kernel.squashfs -noappend -comp lzo -b 131072 -all-root
```

For a safe A/B system, put the final `kernel.squashfs` in **both** `hassos-kernel0` and `hassos-kernel1`. Populate `system0` and `system1` with valid matching HAOS EROFS system images as well.

## 4. Update the HAOS boot FAT partition

Place the following files on the HAOS boot partition:

```text
boot.scr                           # generated from haos/boot.cmd.rk3568-jl-rm01
uEnv.txt                           # copied from haos/uEnv.txt
dtbs/rk3568-jl-rm01.dtb            # kernel build output
```

Generate the script after editing it:

```sh
mkimage -A arm -T script -C none -n 'HAOS RK3568-JL-RM01' \\
  -d haos/boot.cmd.rk3568-jl-rm01 boot.scr
```

`boot.cmd` maintains HAOS boot-state variables and chooses slot A or B.  Its `PARTUUID` values are tied to the HAOS image layout used during this port; confirm them with `blkid` / `parted` before adapting the procedure to another base image.

## First-boot verification

At 1,500,000 baud the serial log should reach the HAOS boot-script banner, then systemd and Docker/Supervisor startup.  A successful kernel boot followed by a reboot is often a userspace dependency issue (especially zram or Docker), rather than a new kernel panic.

## Repository layout

```text
u-boot/    U-Boot v2024.10 board configuration and minimal bootloader DTS
kernel/    HAOS kernel configuration fragment
haos/      A/B U-Boot script source and DTB selector
docs/      Compatibility notes and known limitations
```
