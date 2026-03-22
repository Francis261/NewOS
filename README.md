# MyOS live-boot build system (Debian live-build)

This repository is now a clean, **live-boot/live-build** project for producing a lightweight Web OS ISO.

## 1) Layout

```text
.
├── config/
│   ├── auto/config
│   ├── package-lists/myos.list.chroot
│   ├── includes.chroot/
│   │   ├── etc/systemd/system/myos.service
│   │   ├── etc/systemd/system/getty@tty1.service.d/autologin.conf
│   │   └── opt/myos/
│   │       ├── start.sh
│   │       ├── launch-ui.sh
│   │       └── ui/
│   │           ├── index.html
│   │           ├── styles.css
│   │           └── desktop.js
│   ├── hooks/live/
│   │   ├── 010-users.hook.chroot
│   │   ├── 020-services.hook.chroot
│   │   └── 030-env.hook.chroot
│   └── binary/boot/grub/grub.cfg
├── tools/build-iso.sh
└── dist/myos-live.iso (generated)
```

Desktop payload is stored under `/opt/myos/` in the live image.

## 2) Features

- Debian stable (Bookworm) live ISO.
- Minimal Xorg + Openbox desktop session.
- Auto-login user `myos` on tty1.
- `myos.service` starts X and launches kiosk shell.
- Tauri-first boot path (`/opt/myos/bin/myos-shell` if present).
- Chromium kiosk fallback for the included React-style desktop.
- Persistence boot menu entry.
- Optional installer-mode boot menu entry.

## 3) Build prerequisites

```bash
sudo apt-get update
sudo apt-get install -y live-build debootstrap xorriso squashfs-tools
```

## 4) Build commands

### A) Manual

```bash
sudo lb clean --purge
sudo ./config/auto/config
sudo lb build
```

### B) Wrapper (recommended)

```bash
sudo ./tools/build-iso.sh
```

Output:

- `dist/myos-live.iso`

## 5) Boot test

### VirtualBox

1. Create VM: Debian (64-bit), 2+ CPU, 4GB RAM.
2. Attach `dist/myos-live.iso`.
3. Boot and confirm:
   - auto-login to `myos`
   - desktop launches automatically
   - launcher/taskbar/window apps respond

### QEMU

```bash
qemu-system-x86_64 -m 4096 -smp 2 -enable-kvm -cdrom dist/myos-live.iso
```

## 6) Tauri integration

Put your packaged Tauri shell at:

- `/opt/myos/bin/myos-shell`

Then boot will prefer it over Chromium fallback.

## 7) Extra app concepts

The included UI demonstrates:

- Taskbar + launcher
- Virtual windows
- Browser app via iframe
- File-manager placeholder for Tauri backend APIs
- Terminal placeholder for xterm.js bridge
- Python runner placeholder

