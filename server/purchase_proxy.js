// Receipt verification proxy (dev + prod template)
// POST /verify { platform: 'android'|'ios', productId, verificationData }
//   - Android: verificationData.serverVerificationData (purchase token)
//   - iOS: verificationData.serverVerificationData (base64 receipt)
// Env (optional):
//   GOOGLE_SERVICE_ACCOUNT_JSON (inline JSON) or GOOGLE_APPLICATION_CREDENTIALS (path)
//   GOOGLE_PACKAGE_NAME (e.g., app bundle)
//   APPLE_VERIFY_URL (default: https://buy.itunes.apple.com/verifyReceipt or sandbox)
//   APPLE_SHARED_SECRET (App-Specific Shared Secret)

const http = require('http');
let PORT = Number(process.env.PURCHASE_PORT || 8789);

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'POST,OPTIONS,GET',
  });
  res.end(body);
}

async function verifyGooglePurchase(productId, token) {
  // Using googleapis AndroidPublisher Purchases APIs (template)
  try {
    const { google } = require('googleapis');
    let auth;
    if (process.env.GOOGLE_SERVICE_ACCOUNT_JSON) {
      const creds = JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON);
      auth = new google.auth.GoogleAuth({ credentials: creds, scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
    } else {
      auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
    }
    const publisher = google.androidpublisher({ version: 'v3', auth });
    const packageName = process.env.GOOGLE_PACKAGE_NAME;
    if (!packageName) throw new Error('GOOGLE_PACKAGE_NAME missing');
    // Try as product purchase; if it fails and is a sub, you would call purchases.subscriptions API
    const resp = await publisher.purchases.products.get({ packageName, productId, token });
    const ok = resp && resp.data && String(resp.data.purchaseState) === '0';
    return ok;
  } catch (e) {
    console.warn('[GOOGLE VERIFY FALLBACK]', e && e.message ? e.message : e);
    return false; // fallback to dev accept in handler if not configured
  }
}

async function verifyAppleReceipt(receiptB64) {
  try {
    const url = process.env.APPLE_VERIFY_URL || 'https://buy.itunes.apple.com/verifyReceipt';
    const secret = process.env.APPLE_SHARED_SECRET;
    const payload = { 'receipt-data': receiptB64, password: secret, exclude-old-transactions: true };
    const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    if (!res.ok) return false;
    const j = await res.json();
    // status 0 == valid
    return j && j.status === 0;
  } catch (e) {
    console.warn('[APPLE VERIFY FALLBACK]', e && e.message ? e.message : e);
    return false;
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return sendJson(res, 204, {});
  if (req.url === '/health' && req.method === 'GET') return sendJson(res, 200, { ok: true });
  if (req.url !== '/verify' || req.method !== 'POST') return sendJson(res, 404, { error: 'Not found' });

  let raw = '';
  req.on('data', (c) => (raw += c));
  req.on('end', async () => {
    try {
      const j = JSON.parse(raw || '{}');
      const platform = j.platform;
      const productId = j.productId;
      const ver = j.verificationData || {};
      const data = ver.serverVerificationData;
      if (!platform || !productId || !data) return sendJson(res, 400, { ok: false, error: 'invalid payload' });

      let verified = false;
      if (platform === 'android') {
        verified = await verifyGooglePurchase(productId, data);
      } else if (platform === 'ios') {
        verified = await verifyAppleReceipt(data);
      }
      // Development fallback: if not configured, accept but mark mode
      if (!verified && !process.env.GOOGLE_PACKAGE_NAME && !process.env.APPLE_SHARED_SECRET) {
        console.log('[DEV ACCEPT]', platform, productId);
        return sendJson(res, 200, { ok: true, verified: true, mode: 'dev' });
      }
      return sendJson(res, 200, { ok: true, verified, mode: verified ? 'prod' : 'fail' });
    } catch (e) {
      console.error('[VERIFY ERROR]', e && e.message ? e.message : e);
      sendJson(res, 500, { ok: false, error: e && e.message ? e.message : 'verify failed' });
    }
  });
});

function start(port) {
  server.listen(port, () => {
    PORT = port;
    console.log(`Purchase proxy listening on http://127.0.0.1:${PORT}/verify`);
  });
}

server.on('error', (err) => {
  if (err && err.code === 'EADDRINUSE') {
    const next = PORT + 1;
    console.warn(`[PORT BUSY] ${PORT} in use, trying ${next}...`);
    start(next);
  } else {
    console.error('[LISTEN ERROR]', err);
    process.exit(1);
  }
});

start(PORT);
