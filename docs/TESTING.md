# ISO validation checklist

1. Boot `dist/myos-live.iso` in VM.
2. Verify automatic login as `myos`.
3. Verify `myos.service` active:
   - `systemctl status myos.service`
4. Verify desktop autostarts and taskbar buttons open windows.
5. Verify Chromium fallback path (if no `/opt/myos/bin/myos-shell`).
6. Verify persistence mode by booting **MyOS Live (Persistence)** and mounting a persistence partition labeled `persistence`.
7. Optional hardening toggle:
   - set `MYOS_KIOSK_LOCKDOWN=0` to reduce kiosk restrictions.
