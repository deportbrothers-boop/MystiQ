MystiQ AI Proxy
================

Small Node proxy to keep your OpenAI API key off-device. Provides:

- POST /generate → returns { text }
- POST /stream → streams SSE lines with { delta }

Run
---

1) Install deps

   npm install

2) Set your key and start

   # Linux/macOS
   OPENAI_API_KEY=sk-... npm start

   # Optional: lock with app token so only your app can call it
   APP_TOKEN=your-public-app-token OPENAI_API_KEY=sk-... npm start

The server listens on port 8787 by default.

App config
----------

In `assets/config/ai.json` set:

{
  "serverUrl": "http://127.0.0.1:8787/generate",
  "streamUrl": "http://127.0.0.1:8787/stream",
  "model": "gpt-4o-mini",
  "appToken": "your-public-app-token"
}

On Android emulator the app automatically rewrites 127.0.0.1 → 10.0.2.2.
