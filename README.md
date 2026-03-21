# NewOS: Bootable Offline Web OS

This repository provides a complete starter implementation for a **bootable Web OS** that launches directly into a local HTML/CSS/JS desktop environment in Chromium kiosk mode.

## 1) Folder structure

```text
.
├── buildroot-overlay/
│   └── etc/
│       ├── init.d/S99webos
│       └── profile.d/webos-env.sh
├── iso/
│   └── boot/grub/
│       ├── grub.cfg
│       └── splash.png
├── rootfs/opt/webos/
│   ├── apps/
│   │   ├── calculator/
│   │   ├── file-manager/
│   │   ├── notes/
│   │   └── settings/
│   ├── assets/splash.png
│   ├── backend/
│   │   ├── package.json
│   │   └── server.js
│   ├── boot/grub.cfg
│   ├── data/
│   ├── frontend/
│   │   ├── desktop.js
│   │   ├── index.html
│   │   ├── styles.css
│   │   └── webos-api.js
│   └── scripts/
│       ├── build-iso.sh
│       └── start-webos.sh
└── docs/qemu.md
```

## 2) Base OS + autostart flow

- Base: Buildroot minimal image (recommended for low RAM footprint).
- Init system launches `/etc/init.d/S99webos`.
- `S99webos` starts Xorg and launches Chromium kiosk mode.
- Chromium opens `http://127.0.0.1:8080/index.html` served by local Node backend.

## 3) GRUB bootloader config

Use `iso/boot/grub/grub.cfg`:

- `timeout=0` for hidden menu.
- auto-load `vmlinuz` and `initrd`.
- optional splash image (`splash.png`).

## 4) Local web desktop

Desktop UI components:

- Dock with dynamic app discovery (`/api/apps`)
- Window manager with draggable app windows
- Sandboxed iframes per app
- Built-in apps: calculator, notes, file manager, settings (+ wasm test)

## 5) Local app system (`/apps`)

Each app folder requires:

- `manifest.json`
- `index.html` (plus optional JS/CSS/WASM assets)

Runtime behavior:

1. Desktop fetches manifests from `/api/apps`.
2. Launch creates a sandboxed iframe: `allow-scripts allow-forms`.
3. App requests a session token via `/api/session`.
4. File APIs require token (`X-WebOS-Token`) and are scoped to `/opt/webos/data/apps/<appId>`.

### Security guarantees

- Path traversal prevention via canonical path validation.
- App IDs must match strict regex.
- No raw filesystem paths exposed to apps.
- App sandboxed from top-level DOM and peer app storage.

## 6) Filesystem model

- Global user data: `/opt/webos/data/shared`
- App private data: `/opt/webos/data/apps/<appId>`
- File manager app uses scoped API for create/list/delete.

## 7) Networking and offline behavior

- Fully local by default (localhost backend + local assets).
- Works without internet after first boot.
- Optional cloud sync toggle in Settings app (stub hook).

## 8) WASM / AI extension support

`WebOS.runWasm(...)` in `frontend/webos-api.js` allows apps to instantiate local WASM binaries.

To add local AI inference:

- ship `*.wasm` model runtime in app folder,
- load with `fetch('/apps/<appId>/model.wasm')`,
- execute in app sandbox.

## 9) Performance profile (2GB RAM target)

Chromium launch optimizations in `start-webos.sh`:

- `--disable-background-networking`
- `--disable-sync`
- reduced disk/media cache sizes
- no first run/UI extras
- per-site process model



## Full Chromium kiosk ISO (production path)

Use this script to produce a **full live ISO** that boots directly into Chromium kiosk and runs the WebOS desktop:

```bash
sudo ./tools/build-full-webos-iso.sh
```

What it does:

1. Creates a Debian live rootfs with `live-boot`, Linux kernel, Xorg, Openbox, Chromium, Node.js.
2. Copies `rootfs/opt/webos` into `/opt/webos` inside the image.
3. Enables `webos-kiosk.service` to run `xinit /opt/webos/scripts/start-webos.sh` on boot.
4. Builds `filesystem.squashfs`, kernel/initrd, and packages everything with GRUB.

Output:

- `dist/newos-full.iso`
- Console output includes ISO byte size and El Torito boot metadata report.

This is the one intended to boot directly into the full WebOS UI.

## Quick immediate ISO (built artifact)

For a fast sanity boot (kernel + GRUB + initramfs shell), run:

```bash
./tools/build-immediate-iso.sh
```

This creates `dist/newos-immediate.iso` immediately. It is bootable and useful for validating ISO/GRUB pipeline quickly.
The script prints ISO byte size and El Torito boot metadata, which helps confirm emulator-visible CD boot records.
For the **full Chromium WebOS desktop boot**, follow the Buildroot flow in section 10.

## 10) Build and package ISO

### A. Build Buildroot image

1. Configure Buildroot with:
   - Linux kernel
   - initramfs / initrd image
   - Xorg + chromium + nodejs + npm + xinit
2. Add this repo's `buildroot-overlay/` as **Root filesystem overlay**.
3. Copy `rootfs/opt/webos` into target rootfs (`/opt/webos`).

### B. Generate boot ISO

On host system with `grub-mkrescue`:

```bash
# from within target runtime or after mounting rootfs layout
/opt/webos/scripts/build-iso.sh /path/to/bzImage /path/to/initrd webos.iso
```

The script places kernel/initrd into an ISO tree and generates `webos.iso`.

## 11) Test in QEMU

See `docs/qemu.md`.
For Android Limbo setup/troubleshooting, see `docs/limbo.md`.

Quick example:

```bash
qemu-system-x86_64 \
  -m 2048 \
  -smp 2 \
  -cdrom webos.iso \
  -boot d \
  -enable-kvm \
  -vga virtio
```

## 11.1) Test in Limbo (Android)

If Limbo shows:

- `Booting from Floppy...`
- `GRUB error: attempt to read or write outside of disk 'fd0'`
- `error: no video mode activated.`

then either:

- the ISO was attached as a **floppy disk** (`fd0`) instead of a **CD-ROM** (`hdc`/`sr0`), or
- GRUB attempted splash/gfx mode that Limbo VGA did not support.

Use these Limbo settings:

- **Load Machine**: New
- **Architecture**: x86_64
- **Machine Type**: pc (i440fx)
- **CPU Model**: qemu64 (or kvm64 if supported)
- **RAM**: 1024 MB minimum (2048 MB recommended for full ISO)
- **CPU Cores**: 2
- **VGA Display**: std
- **CD-ROM / ISO image**: select `newos-full.iso` (or `newos-immediate.iso`)
- **Hard Disk A**: None (optional)
- **Floppy A**: None (**important**)
- **Boot from device**: CD-ROM
- **Network**: User

Tips:

1. Prefer `dist/newos-full.iso` for the full Chromium desktop experience.
2. `dist/newos-immediate.iso` is intentionally small and only boots to an initramfs shell for quick sanity checks.
3. If you changed settings, stop VM fully and cold boot again.
4. If Limbo still boots from floppy, create a new Limbo profile and set CD-ROM first before attaching any other media.

## 12) Add a new app

1. Create `rootfs/opt/webos/apps/my-app/manifest.json`.
2. Add `index.html` (+ optional JS/CSS/WASM).
3. Launch WebOS and click **Refresh Apps**.

Minimal manifest:

```json
{
  "name": "My App",
  "description": "A local app",
  "width": "600px",
  "height": "420px"
}
```
