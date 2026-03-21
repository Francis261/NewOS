import React, { useEffect, useMemo, useRef, useState } from "react";

type AppId = "files" | "browser" | "terminal";

type WindowState = {
  id: string;
  appId: AppId;
  title: string;
  x: number;
  y: number;
  w: number;
  h: number;
  z: number;
  minimized: boolean;
};

type DesktopSettings = {
  wallpaper: string;
  startupApps: AppId[];
  shortcuts: Record<string, string>;
};

const DB_NAME = "webos-desktop-db";
const DB_STORE = "settings";

async function openDb(): Promise<IDBDatabase> {
  return await new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      req.result.createObjectStore(DB_STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function getSettings(): Promise<DesktopSettings | null> {
  const db = await openDb();
  return await new Promise((resolve, reject) => {
    const tx = db.transaction(DB_STORE, "readonly");
    const req = tx.objectStore(DB_STORE).get("desktop");
    req.onsuccess = () => resolve((req.result as DesktopSettings) ?? null);
    req.onerror = () => reject(req.error);
  });
}

async function putSettings(settings: DesktopSettings): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(DB_STORE, "readwrite");
    tx.objectStore(DB_STORE).put(settings, "desktop");
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function warmupWasm() {
  // Placeholder for performance-heavy apps.
  // You can swap this to a real wasm module fetch + instantiate.
  const bytes = new Uint8Array([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00
  ]);
  await WebAssembly.instantiate(bytes);
}

const defaultSettings: DesktopSettings = {
  wallpaper:
    "radial-gradient(circle at 20% 20%, #2b7cff 0%, #192a56 40%, #0b1020 100%)",
  startupApps: ["files", "browser"],
  shortcuts: {
    toggleFullscreen: "F11",
    launcher: "Meta",
    terminal: "Ctrl+Alt+T"
  }
};

const appMeta: Record<AppId, { title: string; icon: string }> = {
  files: { title: "Files", icon: "🗂️" },
  browser: { title: "Browser", icon: "🌐" },
  terminal: { title: "Terminal", icon: "⌨️" }
};

export function Desktop() {
  const [settings, setSettings] = useState<DesktopSettings>(defaultSettings);
  const [windows, setWindows] = useState<WindowState[]>([]);
  const zRef = useRef(10);
  const dragRef = useRef<{ id: string; dx: number; dy: number } | null>(null);

  useEffect(() => {
    (async () => {
      await warmupWasm();
      const saved = await getSettings();
      const loaded = saved ?? defaultSettings;
      setSettings(loaded);
      for (const app of loaded.startupApps) openApp(app);
      if (!saved) await putSettings(loaded);
    })();
  }, []);

  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      if (!dragRef.current) return;
      setWindows((prev) =>
        prev.map((w) =>
          w.id === dragRef.current!.id
            ? {
                ...w,
                x: Math.max(0, e.clientX - dragRef.current!.dx),
                y: Math.max(0, e.clientY - dragRef.current!.dy)
              }
            : w
        )
      );
    };
    const onUp = () => (dragRef.current = null);
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.altKey && e.key.toLowerCase() === "t") {
        openApp("terminal");
      }
      if (e.key === "F11") {
        e.preventDefault();
        document.fullscreenElement
          ? document.exitFullscreen()
          : document.documentElement.requestFullscreen();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const openApp = (appId: AppId) => {
    const id = `${appId}-${Date.now()}-${Math.random()}`;
    const z = ++zRef.current;
    setWindows((prev) => [
      ...prev,
      {
        id,
        appId,
        title: appMeta[appId].title,
        x: 60 + prev.length * 18,
        y: 80 + prev.length * 14,
        w: appId === "browser" ? 920 : 700,
        h: appId === "browser" ? 620 : 460,
        z,
        minimized: false
      }
    ]);
  };

  const focusWindow = (id: string) => {
    const z = ++zRef.current;
    setWindows((prev) => prev.map((w) => (w.id === id ? { ...w, z } : w)));
  };

  const taskbarItems = useMemo(
    () =>
      windows.map((w) => ({
        id: w.id,
        label: `${appMeta[w.appId].icon} ${w.title}`,
        minimized: w.minimized
      })),
    [windows]
  );

  return (
    <div style={{ width: "100vw", height: "100vh", overflow: "hidden", background: settings.wallpaper }}>
      <div style={{ padding: 24, display: "grid", gap: 16, width: 180 }}>
        {(Object.keys(appMeta) as AppId[]).map((app) => (
          <button
            key={app}
            onClick={() => openApp(app)}
            style={{
              border: "1px solid rgba(255,255,255,0.25)",
              background: "rgba(20, 27, 46, 0.6)",
              color: "white",
              borderRadius: 12,
              padding: 10,
              textAlign: "left"
            }}
          >
            {appMeta[app].icon} {appMeta[app].title}
          </button>
        ))}
      </div>

      {windows.map((w) =>
        w.minimized ? null : (
          <section
            key={w.id}
            onMouseDown={() => focusWindow(w.id)}
            style={{
              position: "absolute",
              left: w.x,
              top: w.y,
              width: w.w,
              height: w.h,
              zIndex: w.z,
              background: "#0f172a",
              color: "white",
              border: "1px solid #334155",
              borderRadius: 10,
              boxShadow: "0 12px 32px rgba(0,0,0,0.35)",
              resize: "both",
              overflow: "auto"
            }}
          >
            <header
              onMouseDown={(e) => {
                dragRef.current = { id: w.id, dx: e.clientX - w.x, dy: e.clientY - w.y };
              }}
              style={{ display: "flex", justifyContent: "space-between", padding: "8px 12px", cursor: "move", background: "#1e293b" }}
            >
              <strong>{appMeta[w.appId].icon} {w.title}</strong>
              <span>
                <button onClick={() => setWindows((p) => p.map((x) => (x.id === w.id ? { ...x, minimized: true } : x)))}>_</button>
                <button onClick={() => setWindows((p) => p.filter((x) => x.id !== w.id))}>×</button>
              </span>
            </header>
            <main style={{ padding: 12 }}>
              {w.appId === "files" && <div>File manager (IndexedDB-backed) coming from /apps/files.</div>}
              {w.appId === "browser" && <iframe title="browser" src="https://example.com" style={{ width: "100%", height: w.h - 80, border: 0 }} />}
              {w.appId === "terminal" && <pre>$ webos-shell\n$ wasm ready\n$ indexeddb mounted</pre>}
            </main>
          </section>
        )
      )}

      <footer
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          bottom: 0,
          height: 48,
          background: "rgba(15,23,42,0.92)",
          display: "flex",
          alignItems: "center",
          gap: 8,
          padding: "0 10px"
        }}
      >
        {(Object.keys(appMeta) as AppId[]).map((app) => (
          <button key={app} onClick={() => openApp(app)} style={{ borderRadius: 8 }}>
            {appMeta[app].icon}
          </button>
        ))}
        <div style={{ width: 1, height: 24, background: "#334155" }} />
        {taskbarItems.map((item) => (
          <button
            key={item.id}
            onClick={() =>
              setWindows((prev) =>
                prev.map((w) => (w.id === item.id ? { ...w, minimized: !w.minimized, z: ++zRef.current } : w))
              )
            }
          >
            {item.label}
          </button>
        ))}
      </footer>
    </div>
  );
}
