// Simple OpenAI proxy for MystiQ
// - Exposes POST /generate (JSON) and POST /stream (SSE-like)
// - Reads API key from env: OPENAI_API_KEY
// - Never expose your API key in the mobile app; run this server on your machine

import express from 'express';
import cors from 'cors';
import OpenAI from 'openai';

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Optional: simple bearer token guard (register BEFORE routes)
const APP_TOKEN = process.env.APP_TOKEN || '';
app.use((req, res, next) => {
  if (!APP_TOKEN) return next();
  if (req.path === '/health') return next(); // allow health without auth
  const auth = req.headers['authorization'] || '';
  if (auth === `Bearer ${APP_TOKEN}`) return next();
  return res.status(401).json({ error: 'unauthorized' });
});

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

function buildPrompt({ type, profile, inputs, locale }) {
  const name = profile?.name?.trim() || (locale?.startsWith('tr') ? 'Sevgili ruh' : 'Dear soul');
  const topic = inputs?.topic || 'general';
  const style = inputs?.style || 'practical';
  const cards = Array.isArray(inputs?.cards) ? inputs.cards.join(', ') : '';
  const text = (inputs?.text || '').toString();
  const zodiac = profile?.zodiac || '';
  const dow = new Date().toLocaleDateString(locale || 'tr', { weekday: 'long' });
  const sys = locale?.startsWith('tr')
    ? `Sen MystiQ uygulamasının üretken yazarısın. Kısa, akıcı Türkçe metinler yaz. Kullanıcı adı: ${name}.`
    : `You are the content writer for the MystiQ app. Write concise, natural text. User name: ${name}.`;
  const user = { 'coffee':
    (locale?.startsWith('tr')
      ? `Kahve falı. Gün: ${dow}. Konu: ${topic}. Stil: ${style}.`
      : `Coffee reading. Day: ${dow}. Topic: ${topic}. Style: ${style}.`),
    'tarot':
    (locale?.startsWith('tr')
      ? `Tarot. Kartlar: ${cards}. Konu: ${topic}. Stil: ${style}.`
      : `Tarot. Cards: ${cards}. Topic: ${topic}. Style: ${style}.`),
    'palm':
    (locale?.startsWith('tr') ? `El falı. Gün: ${dow}.` : `Palm reading. Day: ${dow}.`),
    'dream':
    (locale?.startsWith('tr') ? `Rüya: ${text}` : `Dream: ${text}`),
    'astro':
    (locale?.startsWith('tr') ? `Astroloji. Burç: ${zodiac}. Gün: ${dow}.` : `Astrology. Sign: ${zodiac}. Day: ${dow}.`),
  }[type] || (locale?.startsWith('tr') ? 'Genel yorum' : 'Generic reading');
  return { sys, user };
}

app.post('/generate', async (req, res) => {
  try {
    const { type, profile, inputs, locale, model } = req.body || {};
    const { sys, user } = buildPrompt({ type, profile, inputs, locale });
    const r = await client.chat.completions.create({
      model: model || 'gpt-4o-mini',
      temperature: 0.7,
      messages: [
        { role: 'system', content: sys },
        { role: 'user', content: user }
      ],
    });
    const text = r.choices?.[0]?.message?.content?.trim() || '';
    res.json({ text });
  } catch (e) {
    res.status(500).json({ error: e?.message || 'server_error' });
  }
});

app.post('/stream', async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  const send = (data) => res.write(`data: ${data}\n\n`);
  try {
    const { type, profile, inputs, locale, model } = req.body || {};
    const { sys, user } = buildPrompt({ type, profile, inputs, locale });
    const stream = await client.chat.completions.create({
      model: model || 'gpt-4o-mini',
      temperature: 0.7,
      stream: true,
      messages: [
        { role: 'system', content: sys },
        { role: 'user', content: user }
      ],
    });
    for await (const part of stream) {
      const delta = part.choices?.[0]?.delta?.content || '';
      if (delta) send(JSON.stringify({ delta }));
    }
    send('[DONE]');
    res.end();
  } catch (e) {
    send(JSON.stringify({ error: e?.message || 'stream_error' }));
    res.end();
  }
});

const PORT = process.env.PORT || 8787;
app.listen(PORT, () => console.log(`[mystiq-ai] server listening on ${PORT}`));
// (auth middleware is registered above, before routes)

// Simple health check
app.get('/health', (req, res) => {
  res.json({ ok: true, model: (process.env.OPENAI_MODEL || 'gpt-4o-mini') });
});
