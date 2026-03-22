# MyOS Debian live-build system

This repository now includes an end-to-end Debian `live-build` configuration under `live-build/config`.

## Folder layout

```
live-build/
  config/
    auto/config
    package-lists/myos.list.chroot
    includes.chroot/
      etc/systemd/system/myos.service
      etc/systemd/system/getty@tty1.service.d/autologin.conf
      opt/myos/start.sh
      opt/myos/launch-ui.sh
      opt/myos/ui/index.html
    hooks/live/
      010-myos-user.hook.chroot
      020-enable-services.hook.chroot
      030-myos-permissions.hook.chroot
    includes.binary/boot/grub/grub.cfg
```

## Build prerequisites

```bash
sudo apt-get update
sudo apt-get install -y live-build debootstrap xorriso squashfs-tools
```

## Build commands

From repo root:

```bash
cd live-build
sudo lb clean --purge
sudo lb config
sudo lb build
```

Or use wrapper:

```bash
./tools/build-live-iso.sh
```

Output ISO:

- `dist/myos-live.iso`

## Runtime behavior

- Boots Debian live system.
- Auto-logins user `myos` on tty1.
- Starts `myos.service` automatically.
- `myos.service` launches X and runs `/opt/myos/start.sh`.
- `/opt/myos/launch-ui.sh` tries, in order:
  1. `/opt/myos/bin/myos-shell` (Tauri binary, kiosk)
  2. `/opt/myos/ui/index.html` via Chromium kiosk
  3. xterm fallback for diagnostics

## Testing the ISO

### QEMU

```bash
qemu-system-x86_64 -m 4096 -smp 2 -enable-kvm -cdrom dist/myos-live.iso
```

### VirtualBox

1. Create a Linux (Debian 64-bit) VM.
2. Attach `dist/myos-live.iso` as optical disk.
3. Enable EFI if needed.
4. Boot and verify auto-login + kiosk UI.

## Persistence

Use the **MyOS Live (Persistence)** boot menu entry and add a persistence partition labeled `persistence`.

## Installer mode (optional)

Set `--debian-installer live` in `config/auto/config` if you want a Debian installer entry.

## Branding

Drop custom splash/background assets under `live-build/config/includes.binary/boot/grub/` and adjust `grub.cfg`.
