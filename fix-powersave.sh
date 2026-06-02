#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash fix-powersave.sh"
    exit 1
fi

echo "==> Checking for wireless-tools..."
if ! command -v iwconfig &>/dev/null; then
    apt-get install -y wireless-tools
fi

IWCONFIG=$(which iwconfig)
IFACE=$(ip link | grep -oP '\bwl\w+' | head -1)

if [[ -z "$IFACE" ]]; then
    echo "No wireless interface found."
    exit 1
fi

echo "==> Disabling power management on $IFACE..."
"$IWCONFIG" "$IFACE" power off

echo "==> Writing NetworkManager config..."
tee /etc/NetworkManager/conf.d/wifi-powersave-off.conf > /dev/null <<'CONF'
[connection]
wifi.powersave = 2
CONF

echo "==> Writing udev rule for persistence..."
tee /etc/udev/rules.d/81-wifi-powersave.rules > /dev/null <<EOF
ACTION=="add", SUBSYSTEM=="net", KERNEL=="$IFACE", RUN+="$IWCONFIG $IFACE power off"
EOF

echo "==> Reloading udev rules..."
udevadm control --reload-rules

echo ""
echo "Done! Power management disabled on $IFACE. Will persist across reboots."
