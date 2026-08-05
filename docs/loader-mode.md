# Loader mode versus MaskROM

## Current state

The validated PMIC/no-OP-TEE U-Boot includes the RockUSB command and USB gadget
function, but pressing the board Recovery key at power-on does not automatically
enter RockUSB Loader mode. The Rockchip BootROM MaskROM route remains available
by using the board reset/recovery sequence.

## Cause

The original vendor U-Boot enables `CONFIG_ADC_KEY` and its vendor Rockchip
boot path calls `setup_download_mode()`. That code reads the `adc-keys` node,
recognizes the Recovery key as `KEY_VOLUMEUP`, then runs the `download` command
which enters RockUSB when USB VBUS is present.

The U-Boot v2024.10 RM01 configuration used for the validated NPU fix has
`CONFIG_CMD_ROCKUSB=y`, `CONFIG_USB_GADGET_DOWNLOAD=y`, and
`CONFIG_USB_FUNCTION_ROCKUSB=y`, but does not enable the ADC/SARADC path that
the generic `rockchip_dnl_key_pressed()` check needs. Its bootloader DTB also
does not carry the RM01 `adc-keys` description. Consequently the key is never
recognized. Even if only that generic check were enabled, its current action
would reset to BootROM download (MaskROM), not recreate the vendor's RockUSB
Loader branch.

## Safe next implementation

Port the vendor download-key check into the v2024.10 board support, add the
RM01 SARADC/`adc-keys` definition and ADC driver support, and invoke `rockusb`
only after detecting the key and USB VBUS. Test this separately from the
validated NPU boot chain and retain MaskROM as the fallback throughout.

## 2026-08-05 status update

The ADC key path is implemented and verified on hardware (`SARADC0 raw=23`
pressed / `raw=1023` released) and the RM01 hook schedules `rockusb 0 mmc 0`
via the preboot environment. With the original DWC3 stanza the gadget bound
(`Loader descriptor enabled`) and the SoC reset immediately.

Root-cause analysis against the factory firmware shows the DWC3 gadget needs
the full RK3568 quirk set (`dis_enblslpm`, `dis-u2-freeclk-exists`,
`dis_u2_susphy`, `dis-del-phy-power-chg`, `dis-tx-ipgap-linecheck`,
`xhci-trb-ent`) and `dr_mode = "otg"` on the `usb@fcc00000` controller. A
candidate ITB with these settings was built (`loader-mode/`); hardware
validation is pending.

Factory loader-entry sequence (VBUS must be present before U-Boot starts):
USB into OTG port, power on, hold Recovery, tap Reset, release Recovery after
~5 s. A first validation with `dr_mode = "otg"` reached gadget registration
but failed with `g_dnl_register: failed!, error: -110`; a second candidate
with `dr_mode = "peripheral"` (quirks kept) is pending the same test.
