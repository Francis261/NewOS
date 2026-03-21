# Limbo Emulator (Android) Guide

## Symptom

If you see this in Limbo:

- `Booting from Floppy...`
- `error: attempt to read or write outside of disk 'fd0'`
- `grub rescue>`

the VM is booting from a floppy device (`fd0`) instead of the ISO CD-ROM.

If you see:

- `error: no video mode activated.`

this usually comes from GRUB gfx/splash initialization in limited VGA emulation.
Newer NewOS builds force `terminal_output console` in GRUB to avoid this Limbo failure mode.

## Correct Limbo VM profile

- Architecture: `x86_64`
- Machine Type: `pc` (i440fx)
- CPU Model: `qemu64`
- RAM: `2048 MB` recommended (`1024 MB` minimum)
- Cores: `2`
- CD-ROM: attach `dist/newos-full.iso` (or `dist/newos-immediate.iso`)
- Floppy A: `None`
- Boot Order / Boot from device: `CD-ROM` first
- VGA: `std`

## Which ISO should you use?

- `dist/newos-immediate.iso`: very small by design; verifies GRUB + kernel + initramfs only.
- `dist/newos-full.iso`: much larger; includes Debian live userspace, Chromium, Xorg, Node.js, and the full WebOS desktop.

So a small immediate ISO size is expected and not a corruption signal by itself.

## Validation checks on host

```bash
file dist/newos-immediate.iso
file dist/newos-full.iso
```

Both should report an ISO-9660 CD image.

```bash
xorriso -indev dist/newos-full.iso -report_el_torito plain
```

This should show El Torito boot catalog entries, confirming CD boot metadata is present.

If you build using `tools/build-immediate-iso.sh` or `tools/build-full-webos-iso.sh`, those scripts now print size and El Torito metadata automatically after ISO creation.
