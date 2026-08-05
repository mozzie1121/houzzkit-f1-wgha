# Recovery-key RockUSB Loader mode (experimental)

Status as of 2026-08-05: Recovery-key ADC detection works, the RockUSB gadget
enumerates on the PC ("Class for rockusb devices"), and the missing DWC3 piece
was `DWC3_GUCTL1_DEV_FORCE_20_CLK_FOR_30_CLK` in `dwc3_core_init()` (required
for USB2-only operation on the RK3568 DWC3).

The remaining LOADER-identity work is committed here:

- `g_dnl.c` reports `bcdUSB = 0x0201`. RKDevTool (and rkdeveloptool) classify
  Rockusb devices solely by `bcdUSB & 1`: bit0=0 is MaskROM, bit0=1 is LOADER.
- `composite.c` keeps that odd revision when answering `GET_DESCRIPTOR(DEVICE)`
  (it used to force 0x0200 back), and now answers `GET_DESCRIPTOR(BOS)` at
  HighSpeed too so Windows is happy enumerating a USB 2.1 device.
- `f_rockusb.c` implements `READ_FLASH_INFO` (0x1A) with the same
  `rk_flash_info` layout as the factory loader (block_size=1024, page_size=4,
  flash_size=`blk_desc->lba`, flash_mask=1).

The v2 build makes RKDevTool report LOADER (bcdUSB 0x0201) and pass
GET_CHIP_VER/READ_FLASH_INFO. A v3 build adds the remaining commands the
upgrade flow needs:

- `READ_CAPABILITY` (0xAA): 8-byte capability, DirectLBA + First4M + new
  vendor storage API (matches the factory loader for eMMC).
- `CHANGE_STORAGE` (0x2A): accepts eMMC, replies CSW_GOOD.
- `READ_STORAGE` (0x2B): returns BOOT_TYPE_EMMC.
- Unknown commands now reply with a clean CSW_FAIL instead of emitting a
  `FAILunknown command` string that corrupted the bulk-IN pipe (this was the
  cause of "校验芯片失败" on older RKDevTool versions).
- LBA read path gained chunk-level diagnostics; `usb_ep_dequeue` was dropped
  from `rockusb_tx_write` to silence the DWC3 "request was not queued" spam.

Latest candidate ITB:
`u-boot-rm01-recovery-loader-v3.itb`
(SHA-256 `2bdad7e03d663435b1d3a86cefd382fbbec77cf227a64fcc220cf854d113a43b`).

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
| `drivers/usb/gadget/g_dnl.c` | bcdUSB 0x0201 (LOADER identity) |
| `drivers/usb/gadget/composite.c` | preserve 0x0201 in device descriptor; BOS at HS |
| `drivers/usb/gadget/f_rockusb.c` | READ_FLASH_INFO (0x1A) for RKDevTool |
| `arch/arm/include/asm/arch-rockchip/f_rockusb.h` | 0x2A/0x2B/0xAA command codes |
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
