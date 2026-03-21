#!/usr/bin/env node
'use strict';

const express = require('express');
const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

const app = express();
const PORT = process.env.WEBOS_PORT || 8080;
const WEBOS_ROOT = '/opt/webos';
const APPS_ROOT = path.join(WEBOS_ROOT, 'apps');
const DATA_ROOT = path.join(WEBOS_ROOT, 'data');
const FRONTEND_ROOT = path.join(WEBOS_ROOT, 'frontend');

const appPermissions = new Map();

app.use(express.json({ limit: '1mb' }));
app.use('/', express.static(FRONTEND_ROOT, {
  maxAge: '1h',
  etag: true
}));
app.use('/apps', express.static(APPS_ROOT, { maxAge: '1h', etag: true }));

function safeJoin(base, unsafePath) {
  const normalized = path.posix.normalize(`/${unsafePath || ''}`).replace(/^\/+/, '');
  const full = path.resolve(base, normalized);
  if (!full.startsWith(path.resolve(base) + path.sep) && full !== path.resolve(base)) {
    throw new Error('Path escape blocked');
  }
  return full;
}

function ensureApp(appId) {
  if (!/^[a-z0-9-]+$/i.test(appId)) throw new Error('Invalid appId');
  return appId;
}

function getAppRoot(appId) {
  ensureApp(appId);
  return path.join(DATA_ROOT, 'apps', appId);
}

async function ensureDirs() {
  await fs.mkdir(path.join(DATA_ROOT, 'apps'), { recursive: true });
}

function issueToken(appId) {
  const token = crypto.randomBytes(16).toString('hex');
  appPermissions.set(token, { appId, createdAt: Date.now() });
  return token;
}

function authorize(req, res, next) {
  const token = req.headers['x-webos-token'];
  if (!token || !appPermissions.has(token)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  req.appContext = appPermissions.get(token);
  next();
}

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, ts: Date.now() });
});

app.get('/api/apps', async (_req, res) => {
  const entries = await fs.readdir(APPS_ROOT, { withFileTypes: true });
  const apps = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const manifestPath = path.join(APPS_ROOT, entry.name, 'manifest.json');
    try {
      const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'));
      apps.push({ id: entry.name, ...manifest });
    } catch {
      // Skip invalid manifests
    }
  }
  res.json(apps);
});

app.post('/api/session', async (req, res) => {
  try {
    const appId = ensureApp(req.body.appId);
    await fs.access(path.join(APPS_ROOT, appId));
    const token = issueToken(appId);
    return res.json({ token, appId });
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
});

app.get('/api/fs/list', authorize, async (req, res) => {
  try {
    const relative = req.query.path || '';
    const root = getAppRoot(req.appContext.appId);
    await fs.mkdir(root, { recursive: true });
    const dir = safeJoin(root, relative);
    const entries = await fs.readdir(dir, { withFileTypes: true });
    res.json(entries.map((e) => ({
      name: e.name,
      type: e.isDirectory() ? 'dir' : 'file'
    })));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});


app.get('/api/fs/read', authorize, async (req, res) => {
  try {
    const root = getAppRoot(req.appContext.appId);
    const file = safeJoin(root, req.query.path || '');
    const content = await fs.readFile(file, 'utf8');
    res.json({ content });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/fs/write', authorize, async (req, res) => {
  try {
    const root = getAppRoot(req.appContext.appId);
    await fs.mkdir(root, { recursive: true });
    const file = safeJoin(root, req.body.path);
    await fs.mkdir(path.dirname(file), { recursive: true });
    await fs.writeFile(file, String(req.body.content ?? ''), 'utf8');
    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/fs/delete', authorize, async (req, res) => {
  try {
    const root = getAppRoot(req.appContext.appId);
    const target = safeJoin(root, req.body.path);
    await fs.rm(target, { recursive: true, force: true });
    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/fs/mkdir', authorize, async (req, res) => {
  try {
    const root = getAppRoot(req.appContext.appId);
    const target = safeJoin(root, req.body.path);
    await fs.mkdir(target, { recursive: true });
    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.get('/api/public/files', async (_req, res) => {
  const filesPath = path.join(DATA_ROOT, 'shared');
  await fs.mkdir(filesPath, { recursive: true });
  const entries = await fs.readdir(filesPath, { withFileTypes: true });
  res.json(entries.map((e) => ({ name: e.name, type: e.isDirectory() ? 'dir' : 'file' })));
});

app.listen(PORT, async () => {
  await ensureDirs();
  console.log(`WebOS backend running on http://127.0.0.1:${PORT}`);
});
