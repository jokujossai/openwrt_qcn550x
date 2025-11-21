# OpenWrt image for Asus RT-AC59U

## Overview

This repository adds a build profile for Asus RT-AC59U with QCN5502 patches.
Device configuration and patches from [looi:qcn550x](https://github.com/looi/openwrt/tree/qcn550x)

## Supported Devices

| rt-ac59u | rt-ac59u-v2 |
| --- | --- |
| ASUS RT-AC59U V1 | ASUS RT-AC59U V2 |
| ASUS RT-AC1200GE | ASUS RT-AC1300G PLUS V3 |
| ASUS RT-AC1500G PLUS | ASUS RT-AC57U V3 |
| ASUS RT-AC57U V2 | ASUS RT-AC58U V3 |
| ASUS RT-AC58U V2 |
| ASUS RT-ARCH12 |
| ASUS RT-AC1300G Plus V2 |

## Building

Clone repository and run `make`

## Installation methods

### TFTP

Router has recovery mode that allows uploading factory firmware with tftp

1. Connect router's LAN port to your computer
2. Set static IP of computer to 192.168.1.10/24 (`ip addr add 192.168.1.10/24 dev eth0`)
3. Power down the device
4. Hold the reset button
5. Turn on the router and keep holding the button a few seconds until you see the power LED blinking slowly
6. Use a tftp client to send the image file to IP 192.168.1.1 at port 69

  a. `aftp --put -l /path/to/image 192.168.1.1 69`
  b. `tftp 192.168.1.1 69` with commands `mode binary` and `put /path/to/image`

7. If there are no errors from tftp client, bootloader is installing OpenWrt; wait 2-3 minutes
8. Remove static IP from your computer's network interface, switch back to DHCP

## License

Copyright (C) 2025 Daniel Linjama

This project is licensed under the GNU General Public License v2.0. See the [LICENSE](LICENSE) file for details.

This licensing is consistent with OpenWrt and the Linux kernel.
