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

Requires a `.env` file:

```bash
# Gemini API
GOOGLE_AI_API_KEY=...

# Google SSO
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
```

## Tech stack

- Elixir / Phoenix LiveView
- PostgreSQL
- Tailwind CSS + daisyUI

## License

MIT
