# Broadcom BCM4331 wl driver for Linux kernel 6.x

Broadcom's `wl` hybrid wireless driver patched to build on Linux kernel 6.x (tested on 6.17).

**Hardware:** MacBook Pro mid-2012, Broadcom BCM4331 802.11a/b/g/n

## Install

```bash
git clone https://github.com/Trentyn/broadcom-wl-linux6.git
cd broadcom-wl-linux6
sudo bash install.sh
```

The script installs all dependencies, builds via DKMS (auto-rebuilds on kernel updates), blacklists conflicting drivers, and loads the module.

## What was patched for kernel 6.x

| File | Change |
|---|---|
| `Makefile` | `EXTRA_CFLAGS` → `ccflags-y`, `EXTRA_LDFLAGS` → `ldflags-y` |
| `src/include/linuxver.h` | Guard removed `net/lib80211.h` include (gone in 6.11+) |
| `src/wl/sys/wl_linux.h` | Replace removed `lib80211`/`ieee80211_tkip` types with `void *` |
| `src/wl/sys/wl_linux.c` | `asm/unaligned.h` → `linux/unaligned.h`, `from_timer` → `container_of`, `del_timer` → `timer_delete` |
| `src/wl/sys/wl_cfg80211_hybrid.c` | Add `radio_idx`/`link_id` params to `set_wiphy_params`, `set_tx_power`, `get_tx_power` (cfg80211 API change in 6.11+) |
