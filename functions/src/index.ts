import * as functions from 'firebase-functions';
import cors from 'cors';

// Placeholder callable for verifying purchases and granting entitlements/coins.
export const verifyAndGrant = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }
  const { sku } = data ?? {};
  // TODO: Verify with App Store/Google Play and write to Firestore
  return { ok: true, sku };
});

// OpenAI proxy (HTTP) for development use. Set env: OPENAI_API_KEY
const CORS = cors({ origin: true });

export const aiGenerate = functions
  .runWith({ maxInstances: 5, timeoutSeconds: 60 })
  .https.onRequest((req, res) => {
    CORS(req, res, async () => {
      if (req.method === 'OPTIONS') return res.status(204).send('');
      try {
        const apiKey = process.env.OPENAI_API_KEY;
        if (!apiKey) {
          return res
            .status(200)
            .json({ ok: true, source: 'fallback', text: fallbackText(req.body) });
        }
        const body = (req.body || {}) as any;
        const type = body.type || 'coffee';
        const locale = body.locale || 'tr';
        const profile = body.profile || {};
        const inputs = body.inputs || {};

        const messages: any[] = [
          {
            role: 'system',
            content:
              'You are MystiQ, a warm, mystical advisor. Keep tone gentle, inspiring, and safe. 220-340 words (unless specified). Entertainment only; avoid health/financial/legal claims.',
          },
          {
            role: 'user',
            content: `Type: ${type}\nLocale: ${locale}\nProfile: ${JSON.stringify(
              profile,
            )}\nInstruction: Generate a cohesive, symbolic reading with a short title + 3 short paragraphs + a closing affirmation.`,
          },
        ];
        // include images if provided
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
          messages.push({
            role: 'user',
            content:
              'For TAROT: extend slightly (260-380 words). Add card symbolism and a past–present–future thread with practical, kind suggestions.',
          });
        }

        const r = await fetch('https://api.openai.com/v1/chat/completions', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ model: 'gpt-4o-mini', messages, temperature: 0.8 }),
        });
        const json: any = await r.json();
        const text = json.choices?.[0]?.message?.content || '...';
        res.status(200).json({ ok: true, source: 'openai', text });
      } catch (e: any) {
        console.error(e);
        res
          .status(200)
          .json({ ok: true, source: 'error-fallback', text: fallbackText(req.body) });
      }
    });
  });

function fallbackText(body: any = {}) {
  const type = body.type || 'coffee';
  const name = body?.profile?.name || 'Sevgili ruh';
  if (type === 'coffee')
    return `${name}, fincanda beliren kıvrımlar yeni bir döngüyü haber veriyor. İç sesini dinle.`;
  if (type === 'tarot')
    return `${name}, kartların dili sabır ve net niyeti fısıldıyor. Küçük bir adım, büyük bir kapıyı açabilir.`;
  if (type === 'palm')
    return `${name}, çizgilerin kararlı bir yoldan söz ediyor. Emeklerin görünür olacak.`;
  if (type === 'dream')
    return `${name}, rüyanın sembolleri iç denge ve temizlik çağrısı yapıyor.`;
  return `${name}, yıldızların dansı bugün kalbini yumuşakça destekliyor.`;
}

