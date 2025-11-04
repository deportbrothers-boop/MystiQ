// Minimal email proxy for OTP delivery (development)
// Usage (PowerShell):
//   set SMTP_HOST=smtp.example.com
//   set SMTP_PORT=587
//   set SMTP_USER=user@example.com
//   set SMTP_PASS=app_password
//   set FROM_EMAIL=noreply@mystiq.app
//   node server/dev_mail_proxy.js
// Notes:
//   - 587 -> secure:false (STARTTLS), 465 -> secure:true
//   - Android emülatör için uygulama URL'si: http://10.0.2.2:<PORT>/

const http = require('http');
const nodemailer = require('nodemailer');

let PORT = Number(process.env.PORT || 8788);

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT || 587),
  secure: process.env.SMTP_PORT === '465' || process.env.SMTP_SECURE === 'true',
  auth: process.env.SMTP_USER
    ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
    : undefined,
});

// Proactive connection check
transporter.verify((err) => {
  if (err) {
    console.error('[SMTP VERIFY ERROR]', err.message);
  } else {
    console.log('[SMTP VERIFIED] Ready to send');
  }
});

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

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return sendJson(res, 204, {});
  if (req.url === '/health' && req.method === 'GET') return sendJson(res, 200, { ok: true });
  if (req.url !== '/' || req.method !== 'POST') return sendJson(res, 404, { error: 'Not found' });

  let raw = '';
  req.on('data', (c) => (raw += c));
  req.on('end', async () => {
    try {
      const j = JSON.parse(raw || '{}');
      const to = j.email;
      const code = j.code;
      if (!to || !code) return sendJson(res, 400, { ok: false, error: 'email and code required' });
      const from = process.env.FROM_EMAIL || 'noreply@mystiq.app';
      const info = await transporter.sendMail({
        from,
        to,
        subject: 'MystiQ Doğrulama Kodu',
        text: `Giriş doğrulama kodunuz: ${code}\nKod 10 dakika geçerlidir.`,
        html: `<p>Giriş doğrulama kodunuz:</p><h2>${code}</h2><p>Kod 10 dakika geçerlidir.</p>`,
      });
      console.log('[SMTP SENT]', info.messageId);
      sendJson(res, 200, { ok: true, id: info.messageId });
    } catch (e) {
      console.error('[SEND ERROR]', e);
      sendJson(res, 500, { ok: false, error: e && e.message ? e.message : 'send failed' });
    }
  });
});

function start(port) {
  server.listen(port, () => {
    PORT = port;
    console.log(`Dev mail proxy listening on http://127.0.0.1:${PORT}/  (SMTP: ${process.env.SMTP_HOST}:${process.env.SMTP_PORT})`);
  });
}

server.on('error', (err) => {
  if (err && err.code === 'EADDRINUSE') {
    const next = PORT + 1;
    console.warn(`[PORT BUSY] ${PORT} kullanımda, ${next} deneniyor...`);
    start(next);
  } else {
    console.error('[LISTEN ERROR]', err);
    process.exit(1);
  }
});

start(PORT);

