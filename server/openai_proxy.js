// Simple AI proxy for Falla
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
  .map((s) => s.trim())
  .filter(Boolean);

app.use(cors({
  origin: (origin, cb) => {
    if (!origin) return cb(null, true);
    if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) return cb(null, true);
    return cb(new Error('CORS not allowed'), false);
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  maxAge: 600,
}));

app.use(morgan('tiny'));

const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Gemini inline image prompting needs more headroom than the old text-only proxy.
app.use(express.json({ limit: '20mb' }));

// Optional bearer guard
const APP_TOKEN = process.env.APP_TOKEN || '';
app.use((req, res, next) => {
  if (!APP_TOKEN) return next();
  if (req.path === '/health') return next();
  const auth = req.headers.authorization || '';
  if (auth === `Bearer ${APP_TOKEN}`) return next();
  return res.status(401).json({ error: 'unauthorized' });
});

const GEMINI_MODELS = Object.freeze([
  'gemini-2.5-flash',
  'gemini-2.0-flash-001',
  'gemini-1.5-flash',
]);

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

function pickFirstString(...values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return '';
}

function normalizeTopic(topic) {
  const value = (topic || '').toString().trim();
  const normalized = value.toLocaleLowerCase('tr-TR');
  const map = new Map([
    ['general', 'Genel'],
    ['genel', 'Genel'],
    ['love', 'Aşk'],
    ['aşk', 'Aşk'],
    ['ask', 'Aşk'],
    ['work', 'İş'],
    ['iş', 'İş'],
    ['is', 'İş'],
    ['money', 'Para'],
    ['para', 'Para'],
    ['health', 'Sağlık'],
    ['sağlık', 'Sağlık'],
    ['saglik', 'Sağlık'],
  ]);
  return map.get(normalized) || 'Genel';
}

function normalizeCards(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => (item == null ? '' : String(item).trim()))
      .filter(Boolean)
      .slice(0, 3);
  }

  if (typeof value === 'string' && value.trim()) {
    return value
      .replace(/^Tarot cards:\s*/i, '')
      .replace(/^Kartlar:\s*/i, '')
      .split(/[\n,|]+/)
      .map((item) => item.trim())
      .filter(Boolean)
      .slice(0, 3);
  }

  return [];
}

function formatTarotCards(cards) {
  const labels = ['Geçmiş', 'Şimdi', 'Yansıma'];
  if (!cards.length) {
    return [
      '- Geçmiş: Belirtilmedi',
      '- Şimdi: Belirtilmedi',
      '- Yansıma: Belirtilmedi',
      'Kart isimleri paylaşılmadıysa kart adı uydurma; yalnızca pozisyon enerjilerini yorumla.',
    ].join('\n');
  }

  return labels
    .map((label, index) => `- ${label}: ${cards[index] || 'Belirtilmedi'}`)
    .join('\n');
}

function resolveProfile(profile, body) {
  return {
    ...(profile || {}),
    name: pickFirstString(body?.inputs?.userName, body?.userName, body?.name, profile?.name)
    zodiac: pickFirstString(body?.zodiac, body?.sign, profile?.zodiac),
  };
}

function resolveInputs(inputs, body) {
  const inputCards = normalizeCards(inputs?.cards);
  const bodyCards = normalizeCards(body?.cards);
  const inputImages = Array.isArray(inputs?.imageBase64s) ? inputs.imageBase64s : [];
  const bodyImages = Array.isArray(body?.imageBase64s) ? body.imageBase64s : [];

  return {
    ...(inputs || {}),
    topic: pickFirstString(inputs?.topic, body?.topic),
    style: pickFirstString(inputs?.style, body?.style),
    styleHintTr: pickFirstString(inputs?.styleHintTr, body?.styleHintTr),
    text: pickFirstString(inputs?.text, body?.userMessage, body?.text, body?.message),
    cards: inputCards.length ? inputCards : bodyCards,
    imageBase64: pickFirstString(inputs?.imageBase64, body?.imageBase64),
    imageBase64s: [...inputImages, ...bodyImages].filter((item) => typeof item === 'string' && item.trim()),
    prevIntroSig: pickFirstString(inputs?.prevIntroSig, body?.prevIntroSig),
    zodiac: pickFirstString(inputs?.zodiac, body?.zodiac, body?.sign),
  };
}

const READING_RESPONSE_CONFIG = Object.freeze({
  coffee: {
    maxOutputTokens: 800,
    wordLimit: 'Yanıtın 500 ile 550 kelime arasında olsun, ne fazla ne az.',
  },
  tarot: {
    maxOutputTokens: 700,
    wordLimit: 'Yanıtın 450 ile 500 kelime arasında olsun, ne fazla ne az.',
  },
  palm: {
    maxOutputTokens: 750,
    wordLimit: 'Yanıtın 400 ile 450 kelime arasında olsun, ne fazla ne az.',
  },
  astro: {
    maxOutputTokens: 650,
    wordLimit: 'Yanıtın 350 ile 400 kelime arasında olsun, ne fazla ne az.',
  },
  dream: {
    maxOutputTokens: 600,
    wordLimit: 'Yanıtın 300 ile 350 kelime arasında olsun, ne fazla ne az.',
  },
  motivation: {
    maxOutputTokens: 200,
    wordLimit: 'Yanıtın 120 ile 150 kelime arasında olsun, ne fazla ne az.',
  },
});

function normalizeReadingType(type) {
  const normalized = (type || '').toString().trim().toLowerCase();
  if (normalized === 'astrology') return 'astro';
  return normalized;
}

function getReadingResponseConfig(type) {
  return READING_RESPONSE_CONFIG[normalizeReadingType(type)] || null;
}

function getMaxOutputTokens(type) {
  return getReadingResponseConfig(type)?.maxOutputTokens ?? 800;
}

function buildPrompt({ type, profile, inputs, locale }) {
  const normalizedType = normalizeReadingType(type);
  const responseConfig = getReadingResponseConfig(normalizedType);
  const wordLimit = responseConfig?.wordLimit || '';
  const name = pickFirstString(inputs?.userName, profile?.name) || 'danışan';
  const zodiac = pickFirstString(profile?.zodiac, inputs?.zodiac) || 'Belirtilmedi';
  const topic = normalizeTopic(inputs?.topic);
  const text = pickFirstString(inputs?.text);
  const style = pickFirstString(inputs?.style);
  const styleHintTr = pickFirstString(inputs?.styleHintTr);
  const effectiveStyleHint = normalizedType === 'coffee' ? '' : styleHintTr;
  const cards = normalizeCards(inputs?.cards);
  const dow = new Date().toLocaleDateString(locale || 'tr-TR', { weekday: 'long' });

  const extraNotes = [
    style ? `Kullanıcının talep ettiği ton: ${style}` : '',
    effectiveStyleHint ? `Ek stil notu: ${effectiveStyleHint}` : '',
  ]
    .filter(Boolean)
    .join('\n');

  switch (normalizedType) {
    case 'coffee': {
      const sys = `Sen Azra'sın. İstanbul'un tarihi çarşılarında yıllarca kahve yorumu yapmış, sezgileriyle tanınan, derin ve gizemli bir yorumcusun. Söylediklerin bazen şiir gibi akar, bazen susar ve okuyucuyu düşünceyle baş başa bırakırsın.

TEMEL KURAL:
Kullanıcıya yalnızca ilk cümlede bir kez ismiyle hitap et. Sonrasında bir daha isim kullanma.
Konu: ${topic}. Tüm yorum boyunca yalnızca bu konuya odaklan. Konudan sapma.

YORUM YAPISI — bu sırayı koru, başlık yazma, madde yazma:

Önce fincanın genel havasını hisset. Bu fincanı tutan ellerin yorgunluğunu, taşınan yükü sez. Bunu ${topic} ekseninde duygusal ve gizemli bir dille iki ya da üç ağır cümleyle anlat.

Ardından telvelerde gördüğün 2 ila 3 somut şekli tek tek tanımla. Her sembol için önce görsel tarifini yap — rengi, pozisyonu, hareketi — sonra ${topic} konusuyla bağını kur. Şu kalıpları kullan: "Telvelerde ... görünüyor.", "Fincanın sol yanında ... seçiliyor; bu...", "Tabanın ortasında belirginleşen ... şekli...". Sembolleri gerçekmiş gibi somut ve sinematik anlat.

Sonra kullanıcının ${topic} konusunda yakın geçmişte yaşadığı zorlukları, haksızlıkları veya kayıpları sez ve yansıt. Çok bilmiş görünme, hissettir. Şu tür kalıpları kullan: "Uzun zamandır bu yolda seni zorlayan bir yük var...", "Etrafındaki bazı enerjiler seni yoruyor olmalı...", "Beddua mı, nazar mı bilmem ama bazı engeller doğal gelmiyor bu fincanda...".

Ardından ${topic} konusunda önümüzdeki dönemde ne olacağını somut ama mistik bir dille anlat. Mutlaka bir zaman dilimi içer — "önümüzdeki kırk günde", "baharın ikinci ayında", "bu yaz bitmeden" gibi. En az bir somut detay ekle — bir kişi, bir karar, bir fırsat veya para ile ilgili bir gelişme. Olumlu bir dönüm noktasına işaret et.

Son olarak gizemli ve merak uyandırıcı bitir. Kullanıcıyı yarım bir cümleyle ya da sessizlikle bırak. "Buradayız", "Her zaman yanındayım", "Unutma ki..." gibi yapay kapanışlar kesinlikle kullanma.

GENEL YASAKLAR:
Liste yapma, madde yazma, tire veya numara kullanma.
"Mini öneriler", "günün teması", "önerim şu" gibi koçluk dili kullanma.
İsmi birden fazla kez kullanma.
"Her şey çok güzel olacak" tarzı yapay umut pompalama.
İngilizce kelime karıştırma.

UZUNLUK: Yorumun tamamı 550 ile 620 kelime arasında olsun. Ne daha az ne daha fazla.
FORMAT: Sadece akıcı Türkçe paragraflar. Başlık yok, madde yok, emoji yok.`;

      const user = [
        `İsim: ${name}`,
        `Konu: ${topic}`,
        `Gün: ${dow}`,
        `Kullanıcı notu: ${text || 'Belirtilmedi.'}`,
        `Sana ${extraNotes ? extraNotes + ' ' : ''}kahve fincanı ve tabak görselleri gönderildi.`,
        `Görsellere dikkatle bak. Telvelerde oluşan şekilleri, lekeleri, çizgileri ve kümeleri gerçekten gör.`,
        `Her görselde en az bir somut şekil tanımla — hayvan, insan figürü, nesne, yol, dağ, kuş, el, yüz gibi — ve bunu ${topic} konusuyla ilişkilendir.`,
        `Hiçbir görselde net şekil göremesen bile yorumu yap: telvelerin yoğunluğu, akış yönü ve dağılımı da anlam taşır.`,
        `Yorumun tamamı akıcı Türkçe paragraflardan oluşsun. Madde, liste, başlık, tire kullanma.`,
        `Yorum 550 ile 620 kelime arasında olsun. Bu kurala kesinlikle uy.`,
      ].filter(Boolean).join('\n');

      return { sys, user };
    }

    case 'tarot': {
      const sys = `Sen Azra'sın, mistik bir tarot yorumcususun.

KURALLAR:
- Kullanıcıya sadece ilk cümlede bir kez ismiyle hitap et; bir daha tekrar etme.
- Konu: ${topic}. Tüm yorum bu konuya odaklı olsun.
- Seçilen üç kartı Geçmiş, Şimdi ve Yansıma pozisyonlarına göre tek tek yorumla.
- Her kartın ${topic} için ne anlattığını açıkla.
- Kartların birlikte anlattığı hikayeyi ${topic} ekseninde ör.
- Gerçek bir tarot yorumcusu gibi konuş.
- Liste yapma, koçluk dili kullanma.
- Sonu gizemli bitir.

Türkçe yaz. Akıcı paragraflar halinde ilerle.
${wordLimit}`;

      const user = [
        `Tarot bağlamı:`,
        `Açılışta yalnızca bir kez kullanacağın isim: ${name}`,
        `Konu: ${topic}`,
        `Kullanıcının sorusu: ${text || 'Belirtilmedi.'}`,
        `Kartlar:`,
        formatTarotCards(cards),
        extraNotes,
      ].filter(Boolean).join('\n');

      return { sys, user };
    }

    case 'palm': {
      const sys = `Sen Azra'sın, el çizgilerini okuyan deneyimli bir yorumcusun.

KURALLAR:
- Kullanıcıya sadece ilk cümlede bir kez ismiyle hitap et; bir daha tekrar etme.
- Konu: ${topic}. Tüm yorum bu konuya odaklı olsun.
- Kalp çizgisi, kader çizgisi, akıl çizgisi ve yaşam çizgisini ${topic} açısından yorumla.
- Elde gördüğün özel işaretleri belirt.
- Gerçek bir el yorumcusu gibi konuş.
- Liste yapma, koçluk dili kullanma.
- Sonu gizemli bitir.

Türkçe yaz. Akıcı paragraflar halinde ilerle.
${wordLimit}`;

      const user = [
        `El çizgisi yorumu bağlamı:`,
        `Açılışta yalnızca bir kez kullanacağın isim: ${name}`,
        `Konu: ${topic}`,
        `Gün: ${dow}`,
        `Kullanıcının notu: ${text || 'Belirtilmedi.'}`,
        `Gönderilen görsel el fotoğrafıdır. Önce çizgilerin net görünüp görünmediğini kontrol et.`,
        extraNotes,
      ].filter(Boolean).join('\n');

      return { sys, user };
    }

    case 'astro': {
      const sys = `Sen Azra'sın, yıldızları ve gezegenleri okuyan bir astrologsun.

KURALLAR:
- Kullanıcıya sadece ilk cümlede bir kez ismiyle ve burcuyla hitap et; bir daha tekrar etme.
- Konu: ${topic}. Tüm yorum bu konuya odaklı olsun.
- Bu dönemdeki gezegen konumlarının ${topic} üzerindeki etkilerini yorumla.
- Burca özgü güçlü ve hassas dönemleri belirt.
- Gerçek bir astrolog gibi konuş.
- Liste yapma, koçluk dili kullanma.
- Şanslı gün veya enerji dönemi belirt.
- Sonu gizemli bitir.

Türkçe yaz. Akıcı paragraflar halinde ilerle.
${wordLimit}`;

      const user = [
        `Astroloji bağlamı:`,
        `Açılışta yalnızca bir kez kullanacağın isim: ${name}`,
        `Kullanıcı burcu: ${zodiac}`,
        `Konu: ${topic}`,
        `Gün: ${dow}`,
        `Kullanıcının notu: ${text || 'Belirtilmedi.'}`,
        extraNotes,
      ].filter(Boolean).join('\n');

      return { sys, user };
    }

    case 'dream': {
      const sys = `Sen Azra'sın, rüyaları yorumlayan derin bir yorumcusun.

KURALLAR:
- Kullanıcıya sadece ilk cümlede bir kez ismiyle hitap et; bir daha tekrar etme.
- Rüyadaki sembolleri bilinçaltı mesajları olarak yorumla.
- Her sembolün ne anlama geldiğini açıkla.
- Rüyanın genel mesajını ver.
- Gerçek bir rüya yorumcusu gibi konuş.
- Liste yapma, koçluk dili kullanma.
- Sonu umut verici ama gizemli bitir.

Türkçe yaz. Akıcı paragraflar halinde ilerle.
${wordLimit}`;

      const user = [
        `Rüya bağlamı:`,
        `Açılışta yalnızca bir kez kullanacağın isim: ${name}`,
        `Rüya metni:`,
        text || 'Belirtilmedi.',
        extraNotes,
      ].filter(Boolean).join('\n');

      return { sys, user };
    }

    case 'live_chat': {
      const history = Array.isArray(inputs?.history) ? inputs.history : [];
      const transcript = history
        .map((item) => `${item.role === 'assistant' ? 'Asistan' : 'Kullanıcı'}: ${item.text}`)
        .join('\n');
      const user = [
        `Sohbet modu.`,
        `Sadece cevap metnini döndür; başlık, madde listesi veya meta açıklama ekleme.`,
        transcript ? `Geçmiş:\n${transcript}` : '',
        `Son mesaj: ${text || 'Belirtilmedi.'}`,
      ].filter(Boolean).join('\n\n');
      return {
        sys: `Sen Falla asistanısın. Türkçe, kısa ve doğal cevap ver.`,
        user,
      };
    }

    case 'motivation':
      return {
        sys: `Sen Azra'sın, günlük mistik mesajlar ileten bir rehbersin.
- İsim kullanma.
- O günün enerjisine göre ilham verici, mistik ve kısa bir mesaj yaz.
- Gerçek bir rehber gibi konuş.
- Liste yapma.
- Sadece mesaj metnini üret.

Türkçe yaz.
${wordLimit}`,
        user: `Kullanıcı adı: ${name}\nGün: ${dow}\nNot: ${text || 'Belirtilmedi.'}`,
      };

    default:
      return {
        sys: `Sen Falla için Türkçe yorum üreten bir asistansın. Sadece yorum metnini döndür.`,
        user: `Kullanıcı adı: ${name}\nNot: ${text || 'Belirtilmedi.'}`,
      };
  }
}

const PROMPT_LENGTH_SAMPLES = Object.freeze({
  coffee: {
    profile: { name: 'Aylin' },
    inputs: {
      topic: 'general',
      style: 'practical',
      imageBase64s: ['sample-cup', 'sample-saucer'],
    },
  },
  tarot: {
    profile: { name: 'Aylin' },
    inputs: {
      topic: 'general',
      style: 'practical',
      cards: ['Deli', 'Yildiz', 'Asiklar'],
    },
  },
  palm: {
    profile: { name: 'Aylin' },
    inputs: {
      topic: 'general',
      style: 'practical',
      imageBase64: 'sample-palm',
    },
  },
  astro: {
    profile: { name: 'Aylin', zodiac: 'Akrep' },
    inputs: {
      topic: 'general',
      style: 'practical',
      zodiac: 'Akrep',
    },
  },
  dream: {
    profile: { name: 'Aylin' },
    inputs: {
      style: 'practical',
      text: 'Ruyamda deniz kiyisinda yururken parlak bir yildiz gordum ve eski bir kapiyi actim.',
    },
  },
  motivation: {
    profile: { name: 'Aylin' },
    inputs: {
      text: 'Bugun odagimi toplamak ve sakin kalmak istiyorum.',
    },
  },
});

function sampleInputCharCount(profile, inputs) {
  const rawParts = [
    pickFirstString(profile?.name),
    pickFirstString(profile?.zodiac, inputs?.zodiac),
    pickFirstString(inputs?.topic),
    pickFirstString(inputs?.style),
    pickFirstString(inputs?.styleHintTr),
    pickFirstString(inputs?.text),
    ...normalizeCards(inputs?.cards),
  ].filter(Boolean);
  return rawParts.join('\n').length;
}

function sampleImageCount(inputs) {
  const list = Array.isArray(inputs?.imageBase64s) ? inputs.imageBase64s : [];
  const single = typeof inputs?.imageBase64 === 'string' && inputs.imageBase64.trim() ? 1 : 0;
  return list.filter((item) => typeof item === 'string' && item.trim()).length + single;
}

function buildPromptLengthSummary() {
  return Object.fromEntries(
    Object.entries(PROMPT_LENGTH_SAMPLES).map(([type, sample]) => {
      const { sys, user } = buildPrompt({
        type,
        profile: sample.profile,
        inputs: sample.inputs,
        locale: 'tr-TR',
      });

      return [type, {
        systemChars: sys.length,
        userChars: user.length,
        totalChars: sys.length + user.length,
        maxOutputTokens: getMaxOutputTokens(type),
        sampleInputChars: sampleInputCharCount(sample.profile, sample.inputs),
        imageCount: sampleImageCount(sample.inputs),
        acceptsImages: sampleImageCount(sample.inputs) > 0,
      }];
    }),
  );
}

const PROMPT_LENGTH_SUMMARY = Object.freeze(buildPromptLengthSummary());

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

function normalizeImagePart(value) {
  if (typeof value !== 'string' || !value.trim()) return null;
  const trimmed = value.trim();
  const dataUrlMatch = trimmed.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
  if (dataUrlMatch) {
    return {
      mimeType: dataUrlMatch[1],
      data: dataUrlMatch[2],
    };
  }
  return {
    mimeType: guessMimeType(trimmed),
    data: trimmed,
  };
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
  for (const rawImage of rawImages) {
    const imagePart = normalizeImagePart(rawImage);
    if (!imagePart || seen.has(imagePart.data)) continue;
    seen.add(imagePart.data);
    parts.push({
      inlineData: {
        mimeType: imagePart.mimeType,
        data: imagePart.data,
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

function logResponseStats(type, text) {
  const wordCount = text.split(' ').length;
  const charCount = text.length;
  console.log(`[${type}] words:${wordCount} chars:${charCount} tokens:${Math.round(charCount / 4)}`);
}

function shouldRetryGeminiModel(status) {
  return status === 429 || status === 503;
}

async function generateWithGemini({ type, profile, inputs, locale, body }) {
  const apiKey = getGeminiApiKey();
  if (!apiKey) {
    const err = new Error('missing_gemini_api_key');
    err.status = 503;
    throw err;
  }

  const mergedProfile = resolveProfile(profile, body);
  const mergedInputs = resolveInputs(inputs, body);
  const normalizedType = normalizeReadingType(type);
  const { sys, user } = buildPrompt({
    type: normalizedType,
    profile: mergedProfile,
    inputs: mergedInputs,
    locale,
  });

  const temp = (typeof body?.temperature === 'number')
    ? body.temperature
    : ((normalizedType === 'dream') ? 0.3 : 0.85);

  // Gemini expects systemInstruction + contents, not OpenAI-style messages.
  const payload = {
    systemInstruction: {
      parts: [{ text: sys }],
    },
    contents: [
      {
        role: 'user',
        parts: buildGeminiParts({ user, inputs: mergedInputs }),
      },
    ],
    generationConfig: {
      temperature: temp,
      maxOutputTokens: getMaxOutputTokens(normalizedType),
    },
  };
  const payloadSystemText = payload.systemInstruction?.parts?.[0]?.text || '';

  let selectedModel = GEMINI_MODELS[0];
  let text = '';
  let usage = null;
  let data = {};
  let lastError = null;

  for (let index = 0; index < GEMINI_MODELS.length; index += 1) {
    const modelName = GEMINI_MODELS[index];
    selectedModel = modelName;

    try {
      const resp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent`,
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

      text = extractGeminiText(data);
      if (!text) {
        const err = new Error(data?.promptFeedback?.blockReason || 'empty_gemini_response');
        err.status = 502;
        err.response = { data };
        throw err;
      }

      usage = geminiUsageToOpenAI(data?.usageMetadata);
      break;
    } catch (err) {
      lastError = err;
      const status = err?.status || err?.response?.status || 500;
      const canRetry = shouldRetryGeminiModel(status) && index < GEMINI_MODELS.length - 1;
      if (canRetry) {
        console.warn(`[gemini-fallback] model ${modelName} failed with ${status}, trying next`);
        continue;
      }
      throw err;
    }
  }

  if (!text) {
    throw lastError || new Error('gemini_fallback_failed');
  }

  return {
    text,
    usage,
    raw: data,
    debug: {
      modelUsed: selectedModel,
      normalizedType,
      buildPromptCalled: true,
      sys,
      payloadSystemText,
    },
  };
}

app.post('/generate', async (req, res) => {
  console.log('INCOMING_BODY:', JSON.stringify({
    type: req.body?.type,
    topic: req.body?.inputs?.topic,
    styleHintTr: req.body?.inputs?.styleHintTr,
    formatHint: req.body?.inputs?.formatHint,
    userName: req.body?.inputs?.userName,
  }));
  try {
    const { type, profile, inputs, locale } = req.body || {};
    const r = await generateWithGemini({
      type,
      profile,
      inputs,
      locale,
      body: req.body || {},
    });
    if (r.debug?.normalizedType === 'coffee') {
      const sys = r.debug.sys || '';
      console.log('BUILD_PROMPT_CALLED:', r.debug.buildPromptCalled === true);
      console.log('GEMINI_MODEL_USED:', r.debug.modelUsed || '');
      console.log('SYS_PROMPT_FULL:', sys);
      console.log('SYS_PROMPT_FIRST_100:', sys.slice(0, 100));
      console.log('SYS_PROMPT_HAS_TOPIC:', sys.includes('aşk') || sys.includes('topic'));
      console.log('GEMINI_SYSTEM_INSTRUCTION_TEXT:', r.debug.payloadSystemText || '');
    }
    console.log('USAGE:', JSON.stringify(r.usage));
    logResponseStats(type, r.text);

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
    logResponseStats(type, r.text);

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
app.listen(PORT, () => {
  console.log(`[falla-ai] server listening on ${PORT}`);
  console.log('[prompt-lengths]', JSON.stringify(PROMPT_LENGTH_SUMMARY));
});

app.get('/health', (req, res) => {
  const hasKey = Boolean(process.env.GEMINI_API_KEY && process.env.GEMINI_API_KEY.trim());
  res.json({
    ok: true,
    provider: 'gemini',
    model: GEMINI_MODELS[0],
    fallbackModels: GEMINI_MODELS,
    hasApiKey: hasKey,
    promptLengths: PROMPT_LENGTH_SUMMARY,
  });
});

setInterval(() => {
  fetch('https://mystiq-pdxf.onrender.com/health')
    .catch(() => {});
}, 14 * 60 * 1000);
