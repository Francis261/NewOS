const desktop = document.getElementById('desktop');
const launcher = document.getElementById('launcher');
const mk = (title, body) => {
  const win = document.createElement('div');
  win.className = 'window';
  win.style.left = `${60 + Math.random() * 240}px`;
  win.style.top = `${40 + Math.random() * 120}px`;
  win.innerHTML = `<header><span>${title}</span><button>✕</button></header>`;
  win.querySelector('button').onclick = () => win.remove();
  const header = win.querySelector('header');
  let dx = 0, dy = 0, drag = false;
  header.onmousedown = e => { drag = true; dx = e.clientX - win.offsetLeft; dy = e.clientY - win.offsetTop; };
  window.onmouseup = () => drag = false;
  window.onmousemove = e => drag && (win.style.left = `${e.clientX-dx}px`, win.style.top = `${e.clientY-dy}px`);
  win.appendChild(body);
  desktop.appendChild(win);
};

function openApp(app) {
  if (app === 'browser') {
    const f = document.createElement('iframe');
    f.src = 'https://example.org';
    mk('Browser (Web app iframe)', f);
  } else if (app === 'files') {
    const p = document.createElement('pre');
    p.textContent = 'File Manager (Tauri API placeholder)\n- /home/myos\n- /opt/myos\nUse Tauri backend commands for real FS operations.';
    mk('Files', p);
  } else if (app === 'terminal') {
    const p = document.createElement('pre');
    p.textContent = 'Terminal (xterm.js placeholder)\nConnect to backend PTY over websocket in production.';
    mk('Terminal', p);
  } else if (app === 'python') {
    const p = document.createElement('pre');
    p.textContent = 'Python runner placeholder\nIntegrate Tauri command to execute controlled scripts.';
    mk('Python', p);
  }
}

document.getElementById('toggle-launcher').onclick = () => launcher.classList.toggle('hidden');
document.querySelectorAll('[data-app]').forEach(btn => btn.onclick = () => openApp(btn.dataset.app));
