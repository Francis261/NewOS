# Tauri-based WebOS (Bootable Linux)

This repository now includes a Tauri shell scaffold under:

```text
rootfs/opt/webos/
├── backend/                  # local API service
├── config/startup.json       # shortcuts/fullscreen/startup apps
├── scripts/start-webos.sh    # starts backend, then Tauri shell
└── tauri/
    ├── Cargo.toml
    ├── build.rs
    ├── src/main.rs
    ├── tauri.conf.json
    └── frontend/
        ├── package.json
        ├── tsconfig.json
        ├── vite.config.ts
        ├── index.html
        └── src/
            ├── main.tsx
            └── Desktop.tsx
```

## Features in provided React desktop component

- Desktop background + launcher icons
- Taskbar with app launcher and live window buttons
- Draggable/resizable windows
- Multi-app windows (`files`, `browser`, `terminal`)
- IndexedDB persistence for desktop settings
- WASM initialization hook (`warmupWasm`) for heavy workloads
- Keyboard shortcuts (`Ctrl+Alt+T`, `F11`)

## Build Tauri shell

```bash
cd rootfs/opt/webos/tauri/frontend
npm install
npm run build

cd ..
cargo tauri build
```

Output binary should be:

- `target/release/webos-shell`

Install into image rootfs:

```bash
install -Dm755 target/release/webos-shell /opt/webos/tauri/target/release/webos-shell
```

## Minimal Linux boot flow

1. Boot kernel + initrd via GRUB.
2. systemd starts kiosk service (`xinit /opt/webos/scripts/start-webos.sh`).
3. `start-webos.sh` starts backend then launches Tauri shell fullscreen.

## Recommended runtime packages (Debian/Ubuntu)

- `xserver-xorg`
- `xinit`
- `openbox` (optional lightweight WM)
- `libwebkit2gtk-4.1-0` (or distro-equivalent WebKitGTK runtime for Tauri)
- `libgtk-3-0`
- `libayatana-appindicator3-1` (if tray usage needed)

## Memory optimization guidance (50–150MB target)

- Build release binaries with LTO in Rust (`profile.release.lto = true`).
- Disable heavy background services in Linux image.
- Keep React desktop code-split and lazy-load apps.
- Use WASM for CPU-heavy tools (preview/render/compute).
- Use IndexedDB for local persistence instead of large in-memory stores.
