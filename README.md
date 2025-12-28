# 🌱 LangSeed

A language learning experiment where new words are defined using only vocabulary you already know, with emojis bridging the gaps.

**Try it:** [langseed.com](https://www.langseed.com) · **Blog post:** [simedw.com](https://simedw.com/2025/12/15/langseed/)

## How it works

1. You have a set of words you've mastered
2. When you encounter a new word, an LLM defines it using only your known vocabulary
3. When concepts are hard to express, it uses emojis as a universal language
4. Practice with fill-in-the-blank and yes/no questions generated at your level

## Supported languages

- 🇨🇳 Chinese (Mandarin)
- 🇸🇪 Swedish
- 🇬🇧 English

## Running locally

```bash
mix setup
iex -S mix phx.server
```

Requires a `.env` file with **required** credentials:

```bash
# Gemini API (required for core functionality)
GOOGLE_AI_API_KEY=...

# Google SSO (required for authentication)
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
```

### Audio/TTS Features

Text-to-speech for Chinese practice uses Gemini TTS with your existing `GOOGLE_AI_API_KEY` - no additional configuration needed!

**Optional: R2 Storage (Recommended for Production)**

```bash
# Cloudflare R2 (for audio caching and de-duplication)
R2_ACCOUNT_ID=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET_NAME=...
```

Without R2, audio is generated on-demand and served as data URLs (works but no caching).
With R2, audio is cached after first generation for instant playback and lower API costs.

## Tech stack

- Elixir / Phoenix LiveView
- PostgreSQL
- Tailwind CSS + daisyUI
- Gemini TTS (uses existing API key)
- Cloudflare R2 (optional, for audio caching)

## License

MIT
