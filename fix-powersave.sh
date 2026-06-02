#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash fix-powersave.sh"
    exit 1
fi

IFACE=$(ip link | grep -oP 'wlp\S+(?=:)' | head -1)

if [[ -z "$IFACE" ]]; then
    echo "No wireless interface found."
    exit 1
fi

echo "==> Disabling power management on $IFACE..."
iwconfig "$IFACE" power off

echo "==> Writing NetworkManager config..."
tee /etc/NetworkManager/conf.d/wifi-powersave-off.conf > /dev/null <<'CONF'
[connection]
wifi.powersave = 2
CONF

echo "==> Writing udev rule for persistence..."
tee /etc/udev/rules.d/81-wifi-powersave.rules > /dev/null <<EOF
ACTION=="add", SUBSYSTEM=="net", KERNEL=="$IFACE", RUN+="/usr/sbin/iwconfig $IFACE power off"
EOF

echo "==> Reloading udev rules..."
udevadm control --reload-rules

echo ""
echo "Done! Power management disabled on $IFACE. Will persist across reboots."
