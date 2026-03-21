const dock = document.getElementById('dock');
const workspace = document.getElementById('workspace');
const clock = document.getElementById('clock');
document.getElementById('refreshApps').addEventListener('click', loadApps);

setInterval(() => {
  clock.textContent = new Date().toLocaleString();
}, 1000);

let z = 10;

function makeDraggable(win, handle) {
  let active = false;
  let ox = 0;
  let oy = 0;
  handle.addEventListener('mousedown', (e) => {
    active = true;
    ox = e.clientX - win.offsetLeft;
    oy = e.clientY - win.offsetTop;
    win.style.zIndex = ++z;
  });
  window.addEventListener('mouseup', () => { active = false; });
  window.addEventListener('mousemove', (e) => {
    if (!active) return;
    win.style.left = `${Math.max(0, e.clientX - ox)}px`;
    win.style.top = `${Math.max(42, e.clientY - oy)}px`;
  });
}

function launchApp(app) {
  const win = document.createElement('section');
  win.className = 'window';
  win.style.left = `${100 + Math.random() * 120}px`;
  win.style.top = `${80 + Math.random() * 80}px`;
  win.style.width = app.width || '480px';
  win.style.height = app.height || '360px';
  win.style.zIndex = ++z;

  const header = document.createElement('div');
  header.className = 'win-header';
  header.innerHTML = `<strong>${app.name}</strong>`;
  const close = document.createElement('button');
  close.textContent = '×';
  close.addEventListener('click', () => win.remove());
  header.appendChild(close);
  win.appendChild(header);

  const frame = document.createElement('iframe');
  frame.className = 'win-body';
  frame.sandbox = 'allow-scripts allow-forms';
  frame.src = `/apps/${app.id}/index.html?appId=${encodeURIComponent(app.id)}`;
  win.appendChild(frame);
  makeDraggable(win, header);
  workspace.appendChild(win);
}

async function loadApps() {
  const apps = await WebOS.listApps();
  dock.innerHTML = '';
  for (const app of apps) {
    const btn = document.createElement('button');
    btn.className = 'dock-item';
    btn.textContent = app.name;
    btn.title = app.description || app.name;
    btn.addEventListener('click', () => launchApp(app));
    dock.appendChild(btn);
  }
}

loadApps();
