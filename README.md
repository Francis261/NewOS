# MyOS live-boot build system (Debian live-build)

This repository is a **live-boot/live-build** project for producing a desktop live ISO that launches a Tauri shell.

## 1) Layout

```text
.
├── .github/workflows/build-live-iso.yml
├── config/
│   ├── auto/config
│   ├── package-lists/myos.list.chroot
│   ├── includes.chroot/
│   │   ├── etc/systemd/system/myos.service
│   │   ├── etc/systemd/system/getty@tty1.service.d/autologin.conf
│   │   └── opt/myos/
│   │       ├── start.sh
│   │       ├── launch-ui.sh
│   │       ├── bin/myos-shell
│   │       └── ui/
│   │           ├── index.html
│   │           ├── styles.css
│   │           └── desktop.js
│   ├── hooks/live/
│   │   ├── 010-users.hook.chroot
│   │   ├── 020-services.hook.chroot
│   │   └── 030-env.hook.chroot
│   └── includes.binary/boot/grub/grub.cfg
├── tools/build-iso.sh
├── tools/test-iso.sh
└── dist/myos-live.iso (generated)
```

## 2) Features

- Debian stable (Bookworm) live ISO.
- Minimal Xorg + Openbox session.
- Auto-login user `myos` on tty1.
- `myos.service` starts X and launches a Tauri shell entrypoint.
- `myos-shell` wrapper resolves packaged app locations (`/opt/myos/tauri/myos-shell`, etc).
- Persistence boot menu entry.
- Optional installer-mode boot menu entry.
- GitHub Actions workflow that builds with wrapper + direct `lb build`, runs smoke tests for both outputs, and uploads artifacts.

## 3) Build prerequisites

```bash
sudo apt-get update
sudo apt-get install -y live-build debootstrap debian-archive-keyring xorriso squashfs-tools
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
- `dist/myos-live-lb.iso` (from direct `lb build` path in CI)

## 5) ISO smoke test

```bash
./tools/test-iso.sh dist/myos-live.iso
```

## 6) QEMU boot test

```bash
qemu-system-x86_64 -m 4096 -smp 2 -enable-kvm -cdrom dist/myos-live.iso
```

## 7) Tauri integration

Put your packaged Tauri shell at one of:

- `/opt/myos/tauri/myos-shell` (preferred)
- `/opt/myos/tauri/MyOS`
- `/usr/local/bin/myos-shell`

The boot path now avoids browser kiosk mode entirely.
