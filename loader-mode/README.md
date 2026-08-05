# Recovery-key RockUSB Loader mode (experimental)

Status as of 2026-08-05: Recovery-key ADC detection works; entering RockUSB
used to reset the board immediately. A new candidate aligns the DWC3 gadget
configuration with the factory firmware (`dr_mode = "otg"` plus the RK3568
DWC3 quirk set) and is waiting for hardware validation.

## What works

- `saradc` channel 0 detects the Recovery key: `RM01 recovery: SARADC0 raw=23`
  when pressed, `raw=1023` when released.
- `rockchip_dnl_mode_check()` schedules `rockusb 0 mmc 0` through the preboot
  environment only for the RM01 board.
- MaskROM download keeps working (fallback recovery route).

## What failed before this candidate

With the old DWC3 stanza (`dr_mode = "peripheral"`, only `dis_u2_susphy_quirk`),
the gadget bound (`Loader descriptor enabled`) and the SoC reset immediately,
looping forever while the key was held. The DWC3 on RK3568 requires the full
vendor quirk set; the factory firmware also uses `dr_mode = "otg"`.

## Files

| File | Purpose |
| --- | --- |
| `arch/arm/dts/rk3568-jl-rm01.dts` | Board DTS: ADC key, RK809 LDO7 `vcca_1v8`, OTG DWC3 stanza with quirks |
| `arch/arm/mach-rockchip/boot_mode.c` | RM01 recovery-key hook into `rockchip_dnl_mode_check()` |
| `configs/rk3568-jl-rm01_defconfig` | `CMD_ROCKUSB`, `ADC`/`SARADC_ROCKCHIP`, gadget options |
| `patches/rm01-recovery-rockusb-final.patch` | Boot-mode hook + DTS + defconfig (reference) |
| `patches/rm01-rockusb-loader-identity-location-fix.patch` | bcdUSB 0x0201 in `board.c` |
| `patches/rm01-rockusb-preserve-loader-bcdusb.patch` | Keep bcdUSB 0x0201 in `composite.c` |
| `patches/rm01-rockusb-vendor-bcddevice.patch` | bcdDevice 0x0223 + `f_rockusb` descriptor fix |

The patches apply on top of a clean U-Boot v2024.10 tree in the order listed.

## Build

```sh
scripts/rebuild-uboot-itb.sh
```

## Flash / test

1. Keep the validated idbloader (`idbloader-rm01-pmic-src-no-optee.img`) at
   eMMC LBA `0x40`.
2. Flash `u-boot.itb` at eMMC LBA `0x4000`.
3. Connect a USB data cable to the OTG/download port, hold Recovery and power
   on. RKDevTool should report one LOADER device and the serial console should
   not reset.
