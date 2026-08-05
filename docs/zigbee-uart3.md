# Zigbee module UART (ttyS3)

The Zigbee gateway module plugs into the 8-pin vertical header (J22) on the
mainboard. Factory U-Boot/kernel sources route it to UART3.

The RM01 kernel DTS (`rk3568-bw-rzw03.dtsi` / ported `rk3568-jl-rm01.dtsi`)
originally did not enable `uart3`, so `/dev/ttyS3` did not exist. The fix:

```dts
&uart3 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&uart3m1_xfer>;
};
```

`uart3m1_xfer` matches the board wiring (UART3 M1). The compiled
`rk3568-jl-rm01.dtb` goes to the HAOS boot partition `dtbs/` and is picked up
by `boot.scr` via `uEnv.txt` (`FDT=dtbs/rk3568-jl-rm01.dtb`).

In Home Assistant select **/dev/ttyS3** for ZHA.

Note: the module was silent on every enabled UART (ttyS0/S4/S7/S9 and ttyS3)
during probing because the 8-pin connector is physically damaged (poor
contact). Verify the connector before assuming a software problem.
