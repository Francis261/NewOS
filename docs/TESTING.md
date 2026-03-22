# ISO validation checklist

1. Build `dist/myos-live.iso`:
   - `sudo ./tools/build-iso.sh`
2. Run smoke checks:
   - `./tools/test-iso.sh dist/myos-live.iso`
3. (CI path) Validate direct live-build output too:
   - `sudo lb clean --purge && sudo ./config/auto/config && sudo lb build`
   - `./tools/test-iso.sh live-image-amd64.hybrid.iso`
4. Boot in VM and verify:
   - auto-login to `myos`
   - `systemctl status myos.service` shows active
   - Tauri shell launches from `/opt/myos/bin/myos-shell`
5. If shell is missing, verify fallback xterm message appears with guidance.
6. Verify persistence mode by booting **MyOS Live (Persistence)** and mounting a persistence partition labeled `persistence`.
