// Simple OpenAI proxy for MystiQ
import 'dotenv/config';
// - Exposes POST /generate (JSON) and POST /stream (SSE-like)
// - Reads API key from env: OPENAI_API_KEY
// - Never expose your API key in the mobile app; run this server on your machine

import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import OpenAI from 'openai';

const app = express();
// Restrictive CORS: allow configured origins; native apps often have no Origin header
const allowedOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);
app.use(cors({
  origin: (origin, cb) => {
    if (!origin) return cb(null, true);
    if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) return cb(null, true);
    return cb(new Error('CORS not allowed'), false);
  },
  methods: ['GET','POST','OPTIONS'],
  allowedHeaders: ['Content-Type','Authorization'],
  maxAge: 600,
}));
app.use(morgan('tiny'));
const limiter = rateLimit({ windowMs: 60 * 1000, max: 120, standardHeaders: true, legacyHeaders: false });
app.use(limiter);
app.use(express.json({ limit: '1mb' }));

// Optional bearer guard
const APP_TOKEN = process.env.APP_TOKEN || '';
app.use((req, res, next) => {
  if (!APP_TOKEN) return next();
  if (req.path === '/health') return next();
  const auth = req.headers['authorization'] || '';
  if (auth === `Bearer ${APP_TOKEN}`) return next();
  return res.status(401).json({ error: 'unauthorized' });
});

// Lazy OpenAI client
let _client = null;
function getClient() {
  if (_client) return _client;
  const key = process.env.OPENAI_API_KEY || '';
  if (!key) return null;
  _client = new OpenAI({ apiKey: key });
  return _client;
}

function buildPrompt({ type, profile, inputs, locale }) {
  const lang = (locale || 'tr').toLowerCase();
  const langName = lang.startsWith('tr') ? 'Turkish'
    : lang.startsWith('es') ? 'Spanish'
    : lang.startsWith('ar') ? 'Arabic'
    : 'English';

  const name = (profile?.name || '').toString().trim();
  const zodiac = (profile?.zodiac || '').toString().trim();
  const topic = (inputs?.topic || '').toString().trim();
  const style = (inputs?.style || '').toString().trim();
  const text = (inputs?.text || '').toString();
  const cards = Array.isArray(inputs?.cards) ? inputs.cards.join(', ') : '';
  const dow = new Date().toLocaleDateString(locale || 'tr', { weekday: 'long' });

  // Minimal guidance: ask for a pure reading, in the requested language, no extra sections or meta.
  const sys = `You are MystiQ's ${type || 'fortune'} assistant. Produce only the reading text in ${langName}. Do not add headings, disclaimers, or meta comments.`;

  // Provide raw context by type without stylistic shaping.
  let user;
  switch (type) {
    case 'coffee':
      user = lang.startsWith('tr')
        ? `Kahve fali. Gun: ${dow}. ${topic ? `Konu: ${topic}. ` : ''}${style ? `Stil: ${style}. ` : ''}${name ? `Isim: ${name}.` : ''}`
        : `Coffee reading. Day: ${dow}. ${topic ? `Topic: ${topic}. ` : ''}${style ? `Style: ${style}. ` : ''}${name ? `Name: ${name}.` : ''}`;
      break;
    case 'tarot':
      user = lang.startsWith('tr')
        ? `Tarot yorumu. Kartlar: ${cards}. ${topic ? `Konu: ${topic}. ` : ''}${style ? `Stil: ${style}. ` : ''}${name ? `Isim: ${name}.` : ''}`
        : `Tarot reading. Cards: ${cards}. ${topic ? `Topic: ${topic}. ` : ''}${style ? `Style: ${style}. ` : ''}${name ? `Name: ${name}.` : ''}`;
      break;
    case 'palm':
      user = lang.startsWith('tr')
        ? `El fali. Gun: ${dow}. ${style ? `Stil: ${style}. ` : ''}${name ? `Isim: ${name}.` : ''}`
        : `Palm reading. Day: ${dow}. ${style ? `Style: ${style}. ` : ''}${name ? `Name: ${name}.` : ''}`;
      break;
    case 'dream':
      user = lang.startsWith('tr')
        ? `Asagidaki ruya icin yorum yaz. Sadece yorum metnini dondur. Ruya metni:\n${text}`
        : `Write an interpretation for the following dream. Return only the interpretation text. Dream text:\n${text}`;
      break;
    case 'live_chat': {
      const h = Array.isArray(inputs?.history) ? inputs.history : [];
      const turn = (m) => `${m.role === 'assistant' ? (lang.startsWith('tr')? 'Asistan' : 'Assistant') : (lang.startsWith('tr')? 'Kullanici' : 'User')}: ${m.text}`;
      const transcript = h.map(turn).join('\n');
      const q = (inputs?.text || '').toString();
      user = lang.startsWith('tr')
        ? `Sohbet. Sadece cevap metnini dondur; baslik veya aciklama ekleme.\n\nGecmis:\n${transcript}\n\nSoru:\n${q}`
        : `Chat. Return only the reply text; do not add headings or meta.\n\nHistory:\n${transcript}\n\nUser:\n${q}`;
      break;
    }
    case 'astro':
      user = lang.startsWith('tr')
        ? `Gunluk astroloji. Burc: ${zodiac}. Gun: ${dow}.`
        : `Daily astrology. Sign: ${zodiac}. Day: ${dow}.`;
      break;
    case 'motivation':
      user = lang.startsWith('tr')
        ? `Gunluk motivasyon yaz. Gun: ${dow}. Sadece motivasyon metnini dondur.`
        : `Write a daily motivation message. Day: ${dow}. Return only the motivation text.`;
      break;
    default:
      user = lang.startsWith('tr') ? 'Yorum yaz.' : 'Write a reading.';
  }

  return { sys, user };
}

app.post('/generate', async (req, res) => {
  try {
    const client = getClient();
    if (!client) return res.status(503).json({ error: 'missing_api_key' });
    const { type, profile, inputs, locale, model } = req.body || {};
    const { sys, user } = buildPrompt({ type, profile, inputs, locale });
    const temp = (type === 'dream') ? 0.3 : 0.7;
    const r = await client.chat.completions.create({
      model: model || 'gpt-4o-mini',
      temperature: temp,
      messages: [
        { role: 'system', content: sys },
        { role: 'user', content: user }
      ],
    });
    const text = r.choices?.[0]?.message?.content?.trim() || '';
    res.json({ text });
  } catch (e) {
    const status = e?.status || e?.response?.status || 500;
    // Log full error server-side for diagnosis
    try { console.error('[generate]', status, e?.message, e?.response?.data || ''); } catch (_) {}
    res.status(status).json({ error: e?.message || 'server_error', status, details: e?.response?.data });
  }
});

app.post('/stream', async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  const send = (data) => res.write(`data: ${data}\n\n`);
  try {
    const client = getClient();
    if (!client) {
      send(JSON.stringify({ error: 'missing_api_key' }));
      return res.end();
    }
    const { type, profile, inputs, locale, model } = req.body || {};
    const { sys, user } = buildPrompt({ type, profile, inputs, locale });
    const temp = (type === 'dream') ? 0.3 : 0.7;
    const stream = await client.chat.completions.create({
      model: model || 'gpt-4o-mini',
      temperature: temp,
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
    const status = e?.status || e?.response?.status || 500;
    try { console.error('[stream]', status, e?.message, e?.response?.data || ''); } catch (_) {}
    send(JSON.stringify({ error: e?.message || 'stream_error', status, details: e?.response?.data }));
    res.end();
  }
});

const PORT = process.env.PORT || 8787;
app.listen(PORT, () => console.log(`[mystiq-ai] server listening on ${PORT}`));

app.get('/health', (req, res) => {
  const hasKey = Boolean(process.env.OPENAI_API_KEY && process.env.OPENAI_API_KEY.trim());
  res.json({ ok: true, model: (process.env.OPENAI_MODEL || 'gpt-4o-mini'), hasApiKey: hasKey });
});
