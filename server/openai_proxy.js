// Simple AI proxy for MystiQ
import 'dotenv/config';
// - Exposes POST /generate (JSON) and POST /stream (SSE-like)
// - Reads Gemini API key from env: GEMINI_API_KEY
// - Never expose your API key in the mobile app; run this server on your machine

import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
// import OpenAI from 'openai';

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
// Gemini inline image prompting needs more headroom than the old text-only proxy.
app.use(express.json({ limit: '20mb' }));

// Optional bearer guard
const APP_TOKEN = process.env.APP_TOKEN || '';
app.use((req, res, next) => {
  if (!APP_TOKEN) return next();
  if (req.path === '/health') return next();
  const auth = req.headers['authorization'] || '';
  if (auth === `Bearer ${APP_TOKEN}`) return next();
  return res.status(401).json({ error: 'unauthorized' });
});

const GEMINI_MODEL = 'gemini-2.5-flash';

/*
// Lazy OpenAI client kept commented for future provider work.
let _client = null;
function getClient() {
  if (_client) return _client;
  const key = process.env.OPENAI_API_KEY || '';
  if (!key) return null;
  _client = new OpenAI({ apiKey: key });
  return _client;
}
*/

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

  const coffeePolicyTr =
    'MYSTIQ – Kahve Yorumu ÇIKTI KURALLARI (GÜNCEL)\n' +
    'ZORUNLU KURALLAR\n' +
    '1) Kullanıcı adı mutlaka geçmeli:\n' +
    '- İlk paragrafta 1 kez: “{userName}, …”\n' +
    '- Metin boyunca toplam 1–2 kez geçsin.\n' +
    '2) Metin uzun olmalı:\n' +
    '- 900–1500 karakter (yaklaşık 140–230 kelime).\n' +
    '- 4–5 kısa paragraf halinde akıcı anlatım.\n' +
    '3) Ton:\n' +
    '- Sıcak, samimi, sezgisel.\n' +
    '- Kesin hüküm yok; “olacak/kesin/garanti/mutlaka” yok.\n' +
    '- Gelecek tahmini / kehanet yok. Yönlendirme ve içgörü dili.\n' +
    '4) İçerik yapısı (bu sırayla):\n' +
    'A) Açılış: isim + fincanın genel havası + gün/ritim\n' +
    'B) Detaylı gözlem: 2–3 iz/şekil + yorum\n' +
    'C) Günün teması\n' +
    'D) Mini öneriler: 2 öneri (1 sosyal, 1 içsel) — 2 satır\n' +
    'E) Kapanış + geri çağırma CTA\n' +
    '5) Kapanış CTA (ZORUNLU): “kahve yorumunun/fincanın sonuna geliyorken” hissi + tekrar çağır.\n' +
    'FORMAT\n' +
    'Başlık: “Kahve Yorumu”\n' +
    'Alt bölüm:\n' +
    '“Bugünün Mini Önerileri:”\n' +
    '- ...\n' +
    '- ...\n' +
    'En alt: “Bu içerik eğlence amaçlıdır; kesinlik içermez.”\n';

  // System prompt: allow heading/sections only for coffee; otherwise keep minimal.
  let sys = (type === 'coffee')
    ? `Sen MystiQ için kahve sembolü yorumlayıcısısın. ${coffeePolicyTr}`
    : `You are MystiQ's ${type || 'reading'} assistant. Produce only the reading text in ${langName}. Do not add headings, disclaimers, or meta comments.`;
  const styleHintTr = (inputs?.styleHintTr || '').toString().trim();
  if (type === 'coffee') {
    sys += ' Gelecek hakkında tahmin yapma. Tarih verme. Kesinlik iddiasında bulunma. “Olacak” yerine “gibi/hissi/çağrıştırıyor” kullan.';
  }
  if (styleHintTr) sys += ` ${styleHintTr}`;

  // Provide raw context by type without stylistic shaping.
  let user;
  switch (type) {
    case 'coffee':
      user = lang.startsWith('tr')
        ? `Kahve yorumu. Gün: ${dow}. ${topic ? `Konu: ${topic}. ` : ''}${style ? `Stil: ${style}. ` : ''}${name ? `Kullanıcı adı: ${name}. ` : ''}${inputs?.prevIntroSig ? `Önceki giriş kalıbı: ${inputs.prevIntroSig}. ` : ''}Kurallara birebir uy.`
        : `Coffee reading. Day: ${dow}. ${topic ? `Topic: ${topic}. ` : ''}${style ? `Style: ${style}. ` : ''}${name ? `User name: ${name}. ` : ''}`;
      break;
    case 'tarot':
      user = lang.startsWith('tr')
        ? `Tarot yorumu. Kartlar: ${cards}. ${topic ? `Konu: ${topic}. ` : ''}${style ? `Stil: ${style}. ` : ''}${name ? `Isim: ${name}.` : ''}`
        : `Tarot reading. Cards: ${cards}. ${topic ? `Topic: ${topic}. ` : ''}${style ? `Style: ${style}. ` : ''}${name ? `Name: ${name}.` : ''}`;
      break;
    case 'palm':
      user = lang.startsWith('tr')
        ? `El cizgisi yorumu. Gun: ${dow}. ${style ? `Stil: ${style}. ` : ''}${name ? `Isim: ${name}.` : ''}`
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

function getGeminiApiKey() {
  return (process.env.GEMINI_API_KEY || '').trim();
}

function guessMimeType(base64) {
  if (typeof base64 !== 'string' || !base64) return 'image/jpeg';
  if (base64.startsWith('/9j/')) return 'image/jpeg';
  if (base64.startsWith('iVBORw0KGgo')) return 'image/png';
  if (base64.startsWith('R0lGOD')) return 'image/gif';
  if (base64.startsWith('UklGR')) return 'image/webp';
  return 'image/jpeg';
}

function buildGeminiParts({ user, inputs }) {
  const parts = [{ text: user }];
  const rawImages = [];
  const imageList = Array.isArray(inputs?.imageBase64s) ? inputs.imageBase64s : [];
  for (const item of imageList) {
    if (typeof item === 'string' && item.trim()) rawImages.push(item.trim());
  }
  if (typeof inputs?.imageBase64 === 'string' && inputs.imageBase64.trim()) {
    rawImages.push(inputs.imageBase64.trim());
  }

  const seen = new Set();
  for (const b64 of rawImages) {
    if (seen.has(b64)) continue;
    seen.add(b64);
    parts.push({
      inlineData: {
        mimeType: guessMimeType(b64),
        data: b64,
      },
    });
  }
  return parts;
}

function geminiUsageToOpenAI(usageMetadata) {
  if (!usageMetadata) return null;
  return {
    prompt_tokens: usageMetadata.promptTokenCount ?? null,
    completion_tokens: usageMetadata.candidatesTokenCount ?? null,
    total_tokens: usageMetadata.totalTokenCount ?? null,
  };
}

function extractGeminiText(data) {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return '';
  return parts
    .map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .join('')
    .trim();
}

async function generateWithGemini({ type, profile, inputs, locale, body }) {
  const apiKey = getGeminiApiKey();
  if (!apiKey) {
    const err = new Error('missing_gemini_api_key');
    err.status = 503;
    throw err;
  }

  const { sys, user } = buildPrompt({ type, profile, inputs, locale });
  const temp = (typeof body?.temperature === 'number')
    ? body.temperature
    : ((type === 'dream') ? 0.3 : 0.85);

  const payload = {
    systemInstruction: {
      parts: [{ text: sys }],
    },
    contents: [
      {
        role: 'user',
        parts: buildGeminiParts({ user, inputs }),
      },
    ],
    generationConfig: {
      temperature: temp,
    },
  };

  const resp = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify(payload),
    },
  );

  const raw = await resp.text();
  let data = {};
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch (_) {
    data = { raw };
  }

  if (!resp.ok) {
    const err = new Error(data?.error?.message || raw || 'gemini_error');
    err.status = resp.status;
    err.response = { data };
    throw err;
  }

  const text = extractGeminiText(data);
  if (!text) {
    const err = new Error(data?.promptFeedback?.blockReason || 'empty_gemini_response');
    err.status = 502;
    err.response = { data };
    throw err;
  }

  const usage = geminiUsageToOpenAI(data?.usageMetadata);
  return { text, usage, raw: data };
}

app.post('/generate', async (req, res) => {
  try {
    const { type, profile, inputs, locale } = req.body || {};
    const r = await generateWithGemini({
      type,
      profile,
      inputs,
      locale,
      body: req.body || {},
    });
    console.log('USAGE:', JSON.stringify(r.usage));

    /*
    // OpenAI request kept commented for future provider work.
    const client = getClient();
    const r = await client.chat.completions.create({
      model: model || 'gpt-4o-mini',
      temperature: temp,
      presence_penalty: presence,
      frequency_penalty: frequency,
      messages: [
        { role: 'system', content: sys },
        { role: 'user', content: user }
      ],
    });
    console.log('USAGE:', JSON.stringify(r.usage));
    */

    res.json({ text: r.text });
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
    const { type, profile, inputs, locale } = req.body || {};
    const r = await generateWithGemini({
      type,
      profile,
      inputs,
      locale,
      body: req.body || {},
    });
    console.log('USAGE:', JSON.stringify(r.usage));

    /*
    // OpenAI streaming kept commented for future provider work.
    const stream = await client.chat.completions.create({
      model: model || 'gpt-4o-mini',
      temperature: temp,
      presence_penalty: presence,
      frequency_penalty: frequency,
      stream: true,
      messages: [
        { role: 'system', content: sys },
        { role: 'user', content: user }
      ],
    });
    */

    const chunks = r.text.match(/\S+\s*/g) || (r.text ? [r.text] : []);
    for (const delta of chunks) {
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
  const hasKey = Boolean(process.env.GEMINI_API_KEY && process.env.GEMINI_API_KEY.trim());
  res.json({ ok: true, provider: 'gemini', model: GEMINI_MODEL, hasApiKey: hasKey });
});
