# Recovery-key RockUSB Loader mode (experimental)

Status as of 2026-08-05: Recovery-key ADC detection works and the RockUSB
gadget now enumerates on the PC ("Class for rockusb devices"). The missing
piece was `DWC3_GUCTL1_DEV_FORCE_20_CLK_FOR_30_CLK` in `dwc3_core_init()`
(required for USB2-only operation on the RK3568 DWC3); without it the core
stayed halted (`DEVCTLHLT`) and every endpoint command timed out with -110.
PC-side driver installation is still needed to make RKDevTool see the device
as LOADER.

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
vendor quirk set plus `DEV_FORCE_20_CLK_FOR_30_CLK`; the factory firmware also
uses `dr_mode = "otg"`.

## Files

| File | Purpose |
| --- | --- |
| `arch/arm/dts/rk3568-jl-rm01.dts` | Board DTS: ADC key, RK809 LDO7 `vcca_1v8`, OTG DWC3 stanza with quirks |
| `arch/arm/mach-rockchip/boot_mode.c` | RM01 recovery-key hook into `rockchip_dnl_mode_check()` |
| `configs/rk3568-jl-rm01_defconfig` | `CMD_ROCKUSB`, `ADC`/`SARADC_ROCKCHIP`, gadget options |
| `drivers/usb/dwc3/core.c` | `DEV_FORCE_20_CLK_FOR_30_CLK` in `dwc3_core_init()` (key fix) |
| `drivers/usb/dwc3/core.h` | GUCTL1 bit definition |
| `drivers/usb/dwc3/gadget.c` / `dwc3-generic.c` | diagnostics only (can be removed) |
| `drivers/phy/rockchip/phy-rockchip-inno-usb2.c` | clkout experiment (no-op on this board) |
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
3. Use the factory loader-entry sequence (VBUS must be present before U-Boot
   starts):

   ```text
   1. plug USB data cable into the OTG/download port
   2. plug in power
   3. hold Recovery
   4. tap Reset
   5. release Recovery after ~5 s
   ```

   RKDevTool should report one LOADER device and the serial console should not
   reset.
