# Broadcom BCM4331 wl driver for Linux kernel 6.x/7.x

Broadcom's `wl` hybrid wireless driver patched to build on modern Linux kernels, including the Ubuntu 24.04 HWE jump from 6.17 to 7.0.

**Hardware:** MacBook Pro mid-2012, Broadcom BCM4331 802.11a/b/g/n

## Install

```bash
git clone https://github.com/Trentyn/broadcom-wl-linux6.git
cd broadcom-wl-linux6
sudo bash install.sh
```

The script installs all dependencies, builds via DKMS (auto-rebuilds on kernel updates), blacklists conflicting drivers, loads the module, and runs `fix-powersave.sh` to disable WiFi power management (prevents disconnects after long uptime).

The installer is intentionally conservative:

- it only calls `apt-get install` when required build dependencies are actually missing
- it refreshes `/usr/src/broadcom-wl-6.30.223.271` from the checked-out tree before registering DKMS
- it builds/installs the module for every installed kernel that already has headers under `/lib/modules/*/build`

This matters on systems where a broken DKMS tree has already left `dpkg` or a kernel upgrade half-configured: the custom source is synced first, and future DKMS rebuilds use the same source and flags.

To apply the power management fix independently on an already-installed system:

```bash
sudo bash fix-powersave.sh
```

## What was patched for kernel 6.x/7.x

| File | Change |
|---|---|
| `Makefile` | `EXTRA_CFLAGS` → `ccflags-y`, `EXTRA_LDFLAGS` → `ldflags-y`, disable `objtool` invocation for the final linked module via `cmd_objtool=` |
| `dkms.conf` | Pass `cmd_objtool=` into DKMS builds so kernel 7.0+ autoinstall uses the same workaround |
| `src/include/linuxver.h` | Guard removed `net/lib80211.h` include (gone in 6.11+) |
| `src/wl/sys/wl_linux.h` | Replace removed `lib80211`/`ieee80211_tkip` types with `void *` |
| `src/wl/sys/wl_linux.c` | `asm/unaligned.h` → `linux/unaligned.h`, `from_timer` → `container_of`, `del_timer` → `timer_delete`, add `MODULE_DESCRIPTION()` for newer modpost |
| `src/wl/sys/wl_cfg80211_hybrid.c` | Add `radio_idx`/`link_id` params to `set_wiphy_params`, `set_tx_power`, `get_tx_power` (cfg80211 API changes in newer 6.x kernels) |

## Kernel 7.0 note

On kernel `7.0.0-28-generic`, the proprietary Broadcom blob inside `lib/wlc_hybrid.o_shipped` trips `objtool` during final module link with:

```text
wl.o: error: objtool: aes_cbc_encrypt_pad+0x4c: unannotated intra-function call
```

That warning comes from the shipped binary object rather than the open wrapper code. Since the blob cannot be rebuilt, this tree suppresses the `objtool` invocation for the external module link step by passing `cmd_objtool=` through both the local `Makefile` and `dkms.conf`.
