# Porting notes

## Tested combination

| Component | Tested choice |
| --- | --- |
| Board | SZZN RK3568-JL-RM01 (Linux compatible: `rockchip,rk3568-rzw03`) |
| Boot loader | U-Boot v2024.10, configured by this repository |
| Kernel source | Vendor RK3568 Linux 6.1 BSP, `jl_v1_linux_defconfig` base |
| HAOS userspace | Panther-X2 HAOS 18 image as a local input |
| Root filesystem | EROFS with LZ4 compression |

## Bring-up fixes that matter

1. The HAOS `system0` / `system1` root partitions are EROFS; ext4 or SquashFS alone is insufficient.  `CONFIG_EROFS_FS=y` must be built into the kernel.
2. HAOS creates LZ4 zram devices during boot.  Enable both `CONFIG_LZ4_COMPRESS=y` and `CONFIG_CRYPTO_LZ4=y`.
3. Supervisor / Docker needs the nftables and block-cgroup options in `kernel/haos.fragment`.  If Docker fails, HAOS may request an orderly reboot even after the kernel has booted.
4. The RM01 BSP NPU path requires RK809 rails to be initialized before Linux begins.  The U-Boot DTS defines `vdd_logic` (DCDC_REG1), `vdd_gpu` (DCDC_REG2), and `vdd_npu` (DCDC_REG4), each enabled at 900 mV.  The U-Boot defconfig must enable `CONFIG_SYS_I2C_ROCKCHIP`, `CONFIG_PMIC_RK8XX`, and `CONFIG_REGULATOR_RK8XX`.  With these in place the kernel initializes `rknpu` without the former PMU ACK panic.
5. HAOS has a larger GPT than the vendor eMMC layout.  Set both `CONFIG_SPL_SYS_MALLOC_F_LEN` and `CONFIG_SPL_BSS_MAX_SIZE` to `0x20000`; the vendor-sized 32 KiB SPL heap exhausts while parsing the HAOS GPT and then fails while loading the U-Boot FIT.

## A/B warning

The first successful SD test booted slot A (`kernel0` + `system0`).  Always populate and validate both kernel slots and both HAOS system slots before using this as a production or OTA-capable image.  The files in this repository do not replace HAOS's normal RAUC update workflow.
