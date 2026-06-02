#!/bin/bash
set -e

DRIVER_NAME=broadcom-wl
DRIVER_VERSION=6.30.223.271
DKMS_SRC=/usr/src/${DRIVER_NAME}-${DRIVER_VERSION}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash install.sh"
    exit 1
fi

echo "==> Installing build dependencies..."
apt-get install -y build-essential linux-headers-$(uname -r) dkms wireless-tools

echo "==> Removing conflicting Broadcom packages..."
apt-get remove -y bcmwl-kernel-source broadcom-sta-dkms 2>/dev/null || true

echo "==> Removing old DKMS entry (if any)..."
dkms remove ${DRIVER_NAME}/${DRIVER_VERSION} --all 2>/dev/null || true

echo "==> Copying source to DKMS tree..."
rm -rf "$DKMS_SRC"
cp -r "$SCRIPT_DIR" "$DKMS_SRC"

echo "==> Building and installing via DKMS..."
dkms add     -m ${DRIVER_NAME} -v ${DRIVER_VERSION}
dkms build   -m ${DRIVER_NAME} -v ${DRIVER_VERSION}
dkms install -m ${DRIVER_NAME} -v ${DRIVER_VERSION}

echo "==> Blacklisting conflicting drivers..."
tee /etc/modprobe.d/broadcom-wl.conf > /dev/null <<'CONF'
blacklist b43
blacklist b43legacy
blacklist brcmsmac
blacklist brcmfmac
blacklist bcma
blacklist ssb
CONF

echo "==> Unloading conflicting modules..."
modprobe -r b43 b43legacy brcmsmac brcmfmac bcma ssb 2>/dev/null || true

echo "==> Loading wl..."
modprobe wl

echo "==> Making wl load on boot..."
grep -q "^wl$" /etc/modules 2>/dev/null || echo 'wl' >> /etc/modules
update-initramfs -u

echo "==> Applying power management fix..."
bash "$SCRIPT_DIR/fix-powersave.sh"

IFACE=$(ip link | grep -oP '\bwl\w+' | head -1)
echo ""
echo "Done! WiFi interface: ${IFACE:-(check: ip link)}"
echo "Connect: nmcli device wifi connect \"SSID\" password \"PASSWORD\""
