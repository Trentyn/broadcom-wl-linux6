#!/bin/bash
set -e

DRIVER_NAME=broadcom-wl
DRIVER_VERSION=6.30.223.271
DKMS_SRC=/usr/src/${DRIVER_NAME}-${DRIVER_VERSION}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_PACKAGES=(build-essential dkms wireless-tools)

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash install.sh"
    exit 1
fi

package_installed() {
    dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -q "install ok installed"
}

install_missing_dependencies() {
    local missing=()
    local running_headers="linux-headers-$(uname -r)"
    local pkg

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! package_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [[ -d "/lib/modules/$(uname -r)/build" ]]; then
        :
    elif ! package_installed "$running_headers"; then
        missing+=("$running_headers")
    fi

    if ((${#missing[@]} == 0)); then
        echo "==> Build dependencies already installed."
        return
    fi

    echo "==> Installing missing build dependencies: ${missing[*]}"
    apt-get install -y "${missing[@]}"
}

rebuild_for_installed_kernels() {
    local kver
    local built_any=0

    shopt -s nullglob
    for kdir in /lib/modules/*; do
        kver="${kdir##*/}"

        if [[ ! -d "$kdir/build" ]]; then
            echo "==> Skipping ${kver}: kernel headers are not installed."
            continue
        fi

        echo "==> Building and installing via DKMS for ${kver}..."
        dkms build -m "${DRIVER_NAME}" -v "${DRIVER_VERSION}" -k "${kver}"
        dkms install -m "${DRIVER_NAME}" -v "${DRIVER_VERSION}" -k "${kver}" --force
        built_any=1
    done
    shopt -u nullglob

    if ((built_any == 0)); then
        echo "No installed kernels with headers were found under /lib/modules."
        exit 1
    fi
}

install_missing_dependencies

echo "==> Removing conflicting Broadcom packages..."
apt-get remove -y bcmwl-kernel-source broadcom-sta-dkms 2>/dev/null || true

echo "==> Removing old DKMS entry (if any)..."
dkms remove ${DRIVER_NAME}/${DRIVER_VERSION} --all 2>/dev/null || true

echo "==> Copying source to DKMS tree..."
rm -rf "$DKMS_SRC"
cp -r "$SCRIPT_DIR" "$DKMS_SRC"

echo "==> Registering source with DKMS..."
dkms add -m "${DRIVER_NAME}" -v "${DRIVER_VERSION}"

rebuild_for_installed_kernels

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
bash "$SCRIPT_DIR/fix-powersave.sh" || echo "Warning: power management fix failed, run fix-powersave.sh manually after reboot"

IFACE=$(ip link | grep -oP '\bwl\w+' | head -1)
echo ""
echo "Done! WiFi interface: ${IFACE:-(check: ip link)}"
echo "Connect: nmcli device wifi connect \"SSID\" password \"PASSWORD\""
