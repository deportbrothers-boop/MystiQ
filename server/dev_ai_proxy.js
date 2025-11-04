// Minimal local AI proxy for web (CORS-friendly)
// Usage:
//   Windows CMD:  set OPENAI_API_KEY=YOUR_KEY && node server\dev_ai_proxy.js
//   PowerShell:   $env:OPENAI_API_KEY='YOUR_KEY'; node server/dev_ai_proxy.js
//   Then set assets/config/ai.json serverUrl to http://127.0.0.1:8787/ai

/* eslint-disable no-console */
const http = require('http');

const PORT = process.env.PORT || 8787;

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
  });
  res.end(body);
}

function fallbackText(body = {}) {
  const type = body.type || 'coffee';
  const name = body?.profile?.name || 'Sevgili ruh';
  if (type === 'coffee') return `${name}, fincanda beliren kıvrımlar yeni bir döngüyü haber veriyor. İç sesini dinle.`;
  if (type === 'tarot') return `${name}, kartların dili sabır ve net niyeti fısıldıyor. Küçük bir adım, büyük bir kapıyı açabilir.`;
  if (type === 'palm') return `${name}, çizgilerin kararlı bir yoldan söz ediyor. Emeklerin görünür olacak.`;
  if (type === 'dream') return `${name}, rüyanın sembolleri iç denge ve temizlik çağrısı yapıyor.`;
  return `${name}, yıldızların dansı bugün kalbini yumuşatmaya destekliyor.`;
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Methods': 'POST,OPTIONS',
    });
    return res.end();
  }

  if (req.url === '/ai/stream' && req.method === 'POST') {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', async () => {
      try {
        const body = raw ? JSON.parse(raw) : {};
        const text = fallbackText(body);
        // Simple SSE-style streaming of the text in word chunks
        res.writeHead(200, {
          'Content-Type': 'text/event-stream; charset=utf-8',
          'Cache-Control': 'no-cache, no-transform',
          Connection: 'keep-alive',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': '*',
          'Access-Control-Allow-Methods': 'POST,OPTIONS',
          // Ensure proxies do not buffer
          'X-Accel-Buffering': 'no',
        });
        const words = String(text).split(/\s+/);
        for (let i = 0; i < words.length; i++) {
          const piece = words[i] + (i < words.length - 1 ? ' ' : '');
          res.write(`data: ${piece}\n\n`);
          await new Promise((r) => setTimeout(r, 18));
        }
        res.write('data: [DONE]\n\n');
        return res.end();
      } catch (e) {
        console.error(e);
        try {
          res.writeHead(200, {
            'Content-Type': 'text/event-stream; charset=utf-8',
            'Cache-Control': 'no-cache, no-transform',
            Connection: 'keep-alive',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': '*',
            'Access-Control-Allow-Methods': 'POST,OPTIONS',
            'X-Accel-Buffering': 'no',
          });
          res.write('data: Bir akış hatası oluştu.\n\n');
          return res.end();
        } catch (_) {
          return sendJson(res, 200, { ok: true, source: 'error-fallback', text: fallbackText() });
        }
      }
    });
    return;
  }

  if (req.url === '/ai' && req.method === 'POST') {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', async () => {
      try {
        const apiKey = process.env.OPENAI_API_KEY;
        const body = raw ? JSON.parse(raw) : {};
        if (!apiKey) {
          return sendJson(res, 200, { ok: true, source: 'fallback', text: fallbackText(body) });
        }

        const { type = 'coffee', locale = 'tr', profile = {}, inputs = {} } = body;

        const messages = [
          {
            role: 'system',
            content:
              'You are MystiQ, a warm, mystical advisor. Keep tone gentle, inspiring, and safe. 240-380 words (unless specified). Entertainment only; avoid health/financial/legal claims.',
          },
          {
            role: 'user',
            content: `Type: ${type}\nLocale: ${locale}\nProfile: ${JSON.stringify(profile)}\nInstruction: Generate a cohesive, symbolic reading with a short title + 3 short paragraphs + a closing affirmation.`,
          },
        ];

        if (inputs.imageBase64) {
          messages.push({
            role: 'user',
            content: [
              { type: 'text', text: 'Analyze this image in a symbolic, mystical way.' },
              { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${inputs.imageBase64}` } },
            ],
          });
        }
        if (inputs.text) {
          messages.push({ role: 'user', content: `User text: ${inputs.text}` });
        }
        if (type === 'tarot') {
          messages.push({ role: 'user', content: 'For TAROT: extend more (320-500 words). Add card symbolism and a past–present–future thread with practical, kind suggestions; consider multiple selected cards if provided.' });
        }

        // Requires Node 18+ for global fetch
        const r = await fetch('https://api.openai.com/v1/chat/completions', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ model: 'gpt-4o-mini', messages, temperature: 0.8 }),
        });
        const json = await r.json();
        const text = json?.choices?.[0]?.message?.content || fallbackText(body);
        return sendJson(res, 200, { ok: true, source: 'openai', text });
      } catch (e) {
        console.error(e);
        return sendJson(res, 200, { ok: true, source: 'error-fallback', text: fallbackText() });
      }
    });
    return;
  }

  sendJson(res, 404, { error: 'Not found' });
});

server.listen(PORT, () => console.log(`Dev AI proxy listening on http://127.0.0.1:${PORT}/ai`));
