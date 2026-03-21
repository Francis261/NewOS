# QEMU Test Instructions

## Boot ISO

```bash
qemu-system-x86_64 \
  -m 2048 \
  -smp 2 \
  -cdrom webos.iso \
  -boot d \
  -enable-kvm \
  -vga virtio
```

## Verify

1. GRUB menu is hidden and boots immediately.
2. Chromium opens full-screen kiosk mode.
3. Desktop shows apps on dock.
4. Notes saves to app-private storage.
5. File Manager creates/deletes files.

## Troubleshooting

- If Chromium does not launch, inspect `/var/log/webos-backend.log`.
- If backend missing dependencies, run `npm ci` under `/opt/webos/backend`.
- If black screen, verify Xorg, GPU options, and Chromium flags.
