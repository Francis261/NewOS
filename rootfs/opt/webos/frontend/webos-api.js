(function () {
  async function jsonFetch(url, opts = {}) {
    const r = await fetch(url, {
      headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) },
      ...opts
    });
    if (!r.ok) throw new Error(await r.text());
    return r.json();
  }

  const sessions = new Map();

  window.WebOS = {
    async listApps() {
      return jsonFetch('/api/apps');
    },
    async session(appId) {
      if (sessions.has(appId)) return sessions.get(appId);
      const out = await jsonFetch('/api/session', { method: 'POST', body: JSON.stringify({ appId }) });
      sessions.set(appId, out.token);
      return out.token;
    },
    async fsList(appId, dir = '') {
      const token = await this.session(appId);
      return jsonFetch(`/api/fs/list?path=${encodeURIComponent(dir)}`, { headers: { 'X-WebOS-Token': token } });
    },
    async fsWrite(appId, file, content) {
      const token = await this.session(appId);
      return jsonFetch('/api/fs/write', {
        method: 'POST',
        headers: { 'X-WebOS-Token': token },
        body: JSON.stringify({ path: file, content })
      });
    },
    async fsDelete(appId, target) {
      const token = await this.session(appId);
      return jsonFetch('/api/fs/delete', {
        method: 'POST',
        headers: { 'X-WebOS-Token': token },
        body: JSON.stringify({ path: target })
      });
    },
    async runWasm(bytes, imports = {}) {
      const mod = await WebAssembly.instantiate(bytes, imports);
      return mod.instance;
    }
  };
})();
