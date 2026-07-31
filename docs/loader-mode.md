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
