# Validated NPU boot baseline — 2026-07-31

This is the source-only record for the hardware validation of the
RK3568-JL-RM01 HAOS port. The binary image and full UART log are intentionally
kept in the local backup, not in Git.

## Result

The following boot chain reached the Home Assistant serial login prompt on the
physical RM01 board:

```text
RK809 PMIC / no-OP-TEE U-Boot
  -> HAOS SD image with rknpu enabled
  -> rknpu 0.9.8 initialized
  -> HAOS Docker and Supervisor started
```

The relevant log markers were:

```text
PMIC: RK809 (on=0x40, off=0x00)
Initialized rknpu 0.9.8 ...
Started rk35xx npu boot config service.
Started HAOS supervisor.
homeassistant login:
```

The historical `failed to get ack on domain 'npu'` panic is therefore resolved.

## Reproducibility constraints

- U-Boot must include the RK809 I2C PMIC and regulator drivers.
- The RM01 U-Boot DTB must define `DCDC_REG4` as `vdd_npu`.
- Build the FIT without a `tee-*` image. The working board showed asynchronous
  SError failures when using the earlier OP-TEE-containing experiment.
- Flash `idbloader.img` at eMMC LBA `0x40` and `u-boot.itb` at `0x4000` as a
  pair.

The local validation backup records exact artifact hashes and is the authority
for binary recovery.
