const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const host = process.env.MOCK_SUPABASE_HOST || '0.0.0.0';
const port = Number(process.env.MOCK_SUPABASE_PORT || 15421);
const dbPath =
  process.env.MOCK_SUPABASE_DB ||
  path.join(__dirname, '..', 'build', 'mobile_mock_supabase_db.json');

const defaultDb = {
  users: [],
  entries: [],
  entryItems: [],
};

function ensureDbDir() {
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });
}

function loadDb() {
  try {
    return JSON.parse(fs.readFileSync(dbPath, 'utf8'));
  } catch (_) {
    return { ...defaultDb };
  }
}

function saveDb(db) {
  ensureDbDir();
  fs.writeFileSync(dbPath, JSON.stringify(db, null, 2));
}

function send(res, status, value, extraHeaders = {}) {
  const body = value === undefined ? '' : JSON.stringify(value);
  res.writeHead(status, {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PATCH,DELETE,OPTIONS',
    'access-control-allow-headers':
      'authorization, apikey, content-type, x-client-info, x-supabase-api-version, prefer, accept, accept-profile, content-profile, range',
    'access-control-expose-headers': 'content-range',
    'content-type': 'application/json; charset=utf-8',
    ...extraHeaders,
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
    });
    req.on('end', () => {
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (_) {
        resolve({});
      }
    });
  });
}

function base64url(value) {
  return Buffer.from(JSON.stringify(value))
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function accessTokenFor(user) {
  const now = Math.floor(Date.now() / 1000);
  return [
    base64url({ alg: 'none', typ: 'JWT' }),
    base64url({
      aud: 'authenticated',
      exp: now + 60 * 60 * 24 * 7,
      iat: now,
      role: 'authenticated',
      sub: user.id,
      email: user.email,
    }),
    'dev',
  ].join('.');
}

function userJson(user) {
  return {
    id: user.id,
    aud: 'authenticated',
    role: 'authenticated',
    email: user.email,
    phone: '',
    app_metadata: { provider: 'email', providers: ['email'] },
    user_metadata: {
      display_name: user.display_name,
      shop_name: user.shop_name,
    },
    created_at: user.created_at,
    confirmed_at: user.created_at,
    email_confirmed_at: user.created_at,
    updated_at: user.updated_at,
    is_anonymous: false,
  };
}

function sessionJson(user) {
  return {
    access_token: accessTokenFor(user),
    token_type: 'bearer',
    expires_in: 604800,
    refresh_token: `refresh-${user.id}-${Date.now()}`,
    user: userJson(user),
  };
}

function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    display_name: user.display_name || '',
    shop_name: user.shop_name || '',
    phone: user.phone || '',
    member_plan: user.member_plan || 'free',
    member_status: user.member_status || 'active',
    created_at: user.created_at,
    updated_at: user.updated_at,
  };
}

function getBearerUser(req, db) {
  const header = req.headers.authorization || '';
  const token = header.replace(/^Bearer\s+/i, '');
  const payloadPart = token.split('.')[1];
  if (!payloadPart) return null;

  try {
    const normalized = payloadPart.replace(/-/g, '+').replace(/_/g, '/');
    const padded = normalized.padEnd(
      normalized.length + ((4 - (normalized.length % 4)) % 4),
      '=',
    );
    const payload = JSON.parse(Buffer.from(padded, 'base64').toString('utf8'));
    return db.users.find((user) => user.id === payload.sub) || null;
  } catch (_) {
    return null;
  }
}

function objectRequested(req) {
  return String(req.headers.accept || '').includes(
    'application/vnd.pgrst.object+json',
  );
}

function parseEqId(url) {
  const id = url.searchParams.get('id') || '';
  return id.startsWith('eq.') ? id.slice(3) : '';
}

function parseText(rawText) {
  const text = String(rawText || '').trim();
  const items = [];
  const matches = text.matchAll(/([^\s\d]+)\s*(\d+(?:\.\d+)?)/g);
  for (const match of matches) {
    const name = String(match[1] || '').trim();
    const amount = Number(match[2] || 0);
    if (name && Number.isFinite(amount)) {
      items.push({ name, amount, type: 'expense' });
    }
  }
  if (items.length === 0 && text) {
    items.push({ name: text, amount: 0, type: 'expense' });
  }
  return { raw_text: text, items };
}

function createEntry(db, user, rawText, items) {
  const now = new Date().toISOString();
  const entryId = crypto.randomUUID();
  let incomeTotal = 0;
  let expenseTotal = 0;

  for (const item of items) {
    const amount = Number(item.amount || 0);
    if (item.type === 'income') incomeTotal += amount;
    else expenseTotal += amount;
    db.entryItems.push({
      id: crypto.randomUUID(),
      entry_id: entryId,
      user_id: user.id,
      name: String(item.name || 'item'),
      amount,
      type: item.type === 'income' ? 'income' : 'expense',
      created_at: now,
    });
  }

  const type =
    incomeTotal > 0 && expenseTotal > 0
      ? 'mixed'
      : incomeTotal > 0
        ? 'income'
        : 'expense';
  const entry = {
    id: entryId,
    user_id: user.id,
    raw_text: String(rawText || '').trim(),
    type,
    income_total: incomeTotal,
    expense_total: expenseTotal,
    created_at: now,
  };
  db.entries.push(entry);
  return entry;
}

async function handle(req, res) {
  if (req.method === 'OPTIONS') return send(res, 204);

  const db = loadDb();
  const url = new URL(req.url, `http://${req.headers.host}`);

  try {
    if (url.pathname === '/auth/v1/health') {
      return send(res, 200, { name: 'mobile-mock-supabase', healthy: true });
    }

    if (url.pathname === '/auth/v1/signup' && req.method === 'POST') {
      const body = await readBody(req);
      const email = String(body.email || '').trim().toLowerCase();
      const password = String(body.password || '');
      if (!email || !password) {
        return send(res, 400, { msg: 'email and password are required' });
      }

      const now = new Date().toISOString();
      let user = db.users.find((item) => item.email === email);
      if (!user) {
        user = {
          id: crypto.randomUUID(),
          email,
          password,
          display_name: body.data?.display_name || '',
          shop_name: body.data?.shop_name || body.data?.display_name || '',
          phone: body.data?.phone || '',
          member_plan: 'free',
          member_status: 'active',
          created_at: now,
          updated_at: now,
        };
        db.users.push(user);
      } else {
        user.password = password;
        user.display_name = user.display_name || body.data?.display_name || '';
        user.shop_name =
          user.shop_name || body.data?.shop_name || body.data?.display_name || '';
        user.updated_at = now;
      }
      saveDb(db);
      return send(res, 200, sessionJson(user));
    }

    if (url.pathname === '/auth/v1/token' && req.method === 'POST') {
      const body = await readBody(req);
      const email = String(body.email || '').trim().toLowerCase();
      const password = String(body.password || '');
      const user = db.users.find(
        (item) => item.email === email && item.password === password,
      );
      if (!user) return send(res, 400, { msg: 'Invalid login credentials' });
      return send(res, 200, sessionJson(user));
    }

    if (url.pathname === '/auth/v1/user' && req.method === 'GET') {
      const user = getBearerUser(req, db);
      if (!user) return send(res, 401, { msg: 'missing auth user' });
      return send(res, 200, userJson(user));
    }

    if (url.pathname === '/auth/v1/logout') {
      return send(res, 200, {});
    }

    if (url.pathname === '/rest/v1/users') {
      const authUser = getBearerUser(req, db);
      if (!authUser) return send(res, 401, { message: 'missing auth user' });

      if (req.method === 'GET') {
        const id = parseEqId(url);
        const row = publicUser(
          db.users.find((user) => user.id === id) || authUser,
        );
        return send(res, 200, objectRequested(req) ? row : [row]);
      }

      if (req.method === 'PATCH') {
        const body = await readBody(req);
        authUser.display_name = String(body.display_name ?? authUser.display_name);
        authUser.shop_name = String(body.shop_name ?? authUser.shop_name);
        authUser.phone = String(body.phone ?? authUser.phone);
        authUser.member_plan = String(body.member_plan ?? authUser.member_plan);
        authUser.member_status = String(
          body.member_status ?? authUser.member_status,
        );
        authUser.updated_at = new Date().toISOString();
        saveDb(db);
        const row = publicUser(authUser);
        return send(res, 200, objectRequested(req) ? row : [row]);
      }
    }

    if (url.pathname === '/rest/v1/entry_items' && req.method === 'GET') {
      const user = getBearerUser(req, db);
      if (!user) return send(res, 401, { message: 'missing auth user' });

      const rows = db.entryItems
        .filter((item) => item.user_id === user.id)
        .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))
        .slice(0, 100)
        .map((item) => ({
          id: item.id,
          name: item.name,
          amount: item.amount,
          type: item.type,
          created_at: item.created_at,
        }));
      return send(res, 200, rows);
    }

    if (
      url.pathname === '/rest/v1/rpc/create_entry_with_items' &&
      req.method === 'POST'
    ) {
      const user = getBearerUser(req, db);
      if (!user) return send(res, 401, { message: 'missing auth user' });
      const body = await readBody(req);
      const items = Array.isArray(body.p_items) ? body.p_items : [];
      if (!String(body.p_raw_text || '').trim() || items.length === 0) {
        return send(res, 400, { message: 'raw text and items are required' });
      }
      const entry = createEntry(db, user, body.p_raw_text, items);
      saveDb(db);
      return send(res, 200, [entry]);
    }

    if (url.pathname === '/functions/v1/ai-engine' && req.method === 'POST') {
      const user = getBearerUser(req, db);
      if (!user) return send(res, 401, { message: 'missing auth user' });
      const body = await readBody(req);
      const parsed = parseText(body.raw_text);
      if (body.save) {
        createEntry(db, user, parsed.raw_text, parsed.items);
        saveDb(db);
      }
      return send(res, 200, parsed);
    }

    return send(res, 404, { message: `No mock route for ${req.method} ${url.pathname}` });
  } catch (error) {
    return send(res, 500, { message: String(error && error.stack ? error.stack : error) });
  }
}

const server = http.createServer(handle);
server.listen(port, host, () => {
  console.log(`Mobile mock Supabase listening on http://${host}:${port}`);
  console.log(`Data file: ${dbPath}`);
});
