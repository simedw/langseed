# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Langseed.Vocabulary.Concept
alias Langseed.Repo

# Clear existing concepts
Repo.delete_all(Concept)

# Initial vocabulary seed data
# explanation uses ONLY known Chinese words + emojis (no English!)
concepts = [
  # Numbers - foundational
  %{
    word: "一",
    pinyin: "yī",
    meaning: "one",
    part_of_speech: "numeral",
    understanding: 100,
    explanation: "1️⃣"
  },
  %{
    word: "二",
    pinyin: "èr",
    meaning: "two",
    part_of_speech: "numeral",
    understanding: 100,
    explanation: "一 + 一 = 2️⃣"
  },
  %{
    word: "三",
    pinyin: "sān",
    meaning: "three",
    part_of_speech: "numeral",
    understanding: 100,
    explanation: "二 + 一 = 3️⃣"
  },
  %{
    word: "四",
    pinyin: "sì",
    meaning: "four",
    part_of_speech: "numeral",
    understanding: 95,
    explanation: "三 + 一 = 4️⃣"
  },
  %{
    word: "五",
    pinyin: "wǔ",
    meaning: "five",
    part_of_speech: "numeral",
    understanding: 95,
    explanation: "🖐️"
  },
  %{
    word: "六",
    pinyin: "liù",
    meaning: "six",
    part_of_speech: "numeral",
    understanding: 90,
    explanation: "五 + 一"
  },
  %{
    word: "七",
    pinyin: "qī",
    meaning: "seven",
    part_of_speech: "numeral",
    understanding: 90,
    explanation: "六 + 一"
  },
  %{
    word: "八",
    pinyin: "bā",
    meaning: "eight",
    part_of_speech: "numeral",
    understanding: 85,
    explanation: "七 + 一"
  },
  %{
    word: "九",
    pinyin: "jiǔ",
    meaning: "nine",
    part_of_speech: "numeral",
    understanding: 85,
    explanation: "八 + 一"
  },
  %{
    word: "十",
    pinyin: "shí",
    meaning: "ten",
    part_of_speech: "numeral",
    understanding: 95,
    explanation: "🖐️🖐️"
  },
  %{
    word: "百",
    pinyin: "bǎi",
    meaning: "hundred",
    part_of_speech: "numeral",
    understanding: 70,
    explanation: "十 × 十 = 💯"
  },
  %{
    word: "千",
    pinyin: "qiān",
    meaning: "thousand",
    part_of_speech: "numeral",
    understanding: 60,
    explanation: "十 × 百"
  },

  # Pronouns
  %{
    word: "我",
    pinyin: "wǒ",
    meaning: "I, me",
    part_of_speech: "pronoun",
    understanding: 100,
    explanation: "👆🗣️"
  },
  %{
    word: "你",
    pinyin: "nǐ",
    meaning: "you",
    part_of_speech: "pronoun",
    understanding: 100,
    explanation: "👉👂"
  },
  %{
    word: "他",
    pinyin: "tā",
    meaning: "he, him",
    part_of_speech: "pronoun",
    understanding: 95,
    explanation: "👨 不是 我，不是 你"
  },
  %{
    word: "她",
    pinyin: "tā",
    meaning: "she, her",
    part_of_speech: "pronoun",
    understanding: 95,
    explanation: "👩 不是 我，不是 你"
  },
  %{
    word: "我们",
    pinyin: "wǒmen",
    meaning: "we, us",
    part_of_speech: "pronoun",
    understanding: 90,
    explanation: "我 + 他/她 👥"
  },
  %{
    word: "你们",
    pinyin: "nǐmen",
    meaning: "you (plural)",
    part_of_speech: "pronoun",
    understanding: 85,
    explanation: "多 你 👥"
  },
  %{
    word: "他们",
    pinyin: "tāmen",
    meaning: "they, them",
    part_of_speech: "pronoun",
    understanding: 85,
    explanation: "多 他/她 👥"
  },
  %{
    word: "这",
    pinyin: "zhè",
    meaning: "this",
    part_of_speech: "pronoun",
    understanding: 80,
    explanation: "👇 近"
  },
  %{
    word: "那",
    pinyin: "nà",
    meaning: "that",
    part_of_speech: "pronoun",
    understanding: 80,
    explanation: "👉 远"
  },

  # Common Verbs
  %{
    word: "是",
    pinyin: "shì",
    meaning: "to be",
    part_of_speech: "verb",
    understanding: 100,
    explanation: "= ✅"
  },
  %{
    word: "有",
    pinyin: "yǒu",
    meaning: "to have",
    part_of_speech: "verb",
    understanding: 95,
    explanation: "🤲 在 我"
  },
  %{
    word: "做",
    pinyin: "zuò",
    meaning: "to do, to make",
    part_of_speech: "verb",
    understanding: 80,
    explanation: "🛠️ ✋"
  },
  %{
    word: "说",
    pinyin: "shuō",
    meaning: "to say, to speak",
    part_of_speech: "verb",
    understanding: 85,
    explanation: "🗣️ 👄"
  },
  %{
    word: "去",
    pinyin: "qù",
    meaning: "to go",
    part_of_speech: "verb",
    understanding: 90,
    explanation: "🚶➡️ 不在 这"
  },
  %{
    word: "来",
    pinyin: "lái",
    meaning: "to come",
    part_of_speech: "verb",
    understanding: 90,
    explanation: "🚶⬅️ 到 这"
  },
  %{
    word: "想",
    pinyin: "xiǎng",
    meaning: "to think, to want",
    part_of_speech: "verb",
    understanding: 75,
    explanation: "🧠💭"
  },
  %{
    word: "看",
    pinyin: "kàn",
    meaning: "to look, to see",
    part_of_speech: "verb",
    understanding: 85,
    explanation: "👀"
  },
  %{
    word: "吃",
    pinyin: "chī",
    meaning: "to eat",
    part_of_speech: "verb",
    understanding: 95,
    explanation: "🍚➡️👄"
  },
  %{
    word: "喝",
    pinyin: "hē",
    meaning: "to drink",
    part_of_speech: "verb",
    understanding: 90,
    explanation: "💧➡️👄"
  },
  %{
    word: "写",
    pinyin: "xiě",
    meaning: "to write",
    part_of_speech: "verb",
    understanding: 70,
    explanation: "✍️📝"
  },
  %{
    word: "读",
    pinyin: "dú",
    meaning: "to read",
    part_of_speech: "verb",
    understanding: 70,
    explanation: "👀📖"
  },
  %{
    word: "学",
    pinyin: "xué",
    meaning: "to study, to learn",
    part_of_speech: "verb",
    understanding: 80,
    explanation: "📚➡️🧠"
  },
  %{
    word: "知道",
    pinyin: "zhīdào",
    meaning: "to know",
    part_of_speech: "verb",
    understanding: 75,
    explanation: "💡在 🧠"
  },
  %{
    word: "喜欢",
    pinyin: "xǐhuān",
    meaning: "to like",
    part_of_speech: "verb",
    understanding: 85,
    explanation: "❤️😊"
  },

  # Adjectives
  %{
    word: "大",
    pinyin: "dà",
    meaning: "big, large",
    part_of_speech: "adjective",
    understanding: 90,
    explanation: "🐘 不 小"
  },
  %{
    word: "小",
    pinyin: "xiǎo",
    meaning: "small, little",
    part_of_speech: "adjective",
    understanding: 90,
    explanation: "🐜 不 大"
  },
  %{
    word: "好",
    pinyin: "hǎo",
    meaning: "good",
    part_of_speech: "adjective",
    understanding: 100,
    explanation: "👍😊"
  },
  %{
    word: "多",
    pinyin: "duō",
    meaning: "many, much",
    part_of_speech: "adjective",
    understanding: 80,
    explanation: "📦📦📦 不 少"
  },
  %{
    word: "少",
    pinyin: "shǎo",
    meaning: "few, little",
    part_of_speech: "adjective",
    understanding: 75,
    explanation: "📦 不 多"
  },
  %{
    word: "新",
    pinyin: "xīn",
    meaning: "new",
    part_of_speech: "adjective",
    understanding: 70,
    explanation: "✨🆕 不 旧"
  },
  %{
    word: "旧",
    pinyin: "jiù",
    meaning: "old (things)",
    part_of_speech: "adjective",
    understanding: 65,
    explanation: "📦⏰ 不 新"
  },
  %{
    word: "近",
    pinyin: "jìn",
    meaning: "near, close",
    part_of_speech: "adjective",
    understanding: 70,
    explanation: "👇 不 远"
  },
  %{
    word: "远",
    pinyin: "yuǎn",
    meaning: "far",
    part_of_speech: "adjective",
    understanding: 70,
    explanation: "👉🏔️ 不 近"
  },

  # Nouns
  %{
    word: "人",
    pinyin: "rén",
    meaning: "person, people",
    part_of_speech: "noun",
    understanding: 95,
    explanation: "🧑 我，你，他"
  },
  %{
    word: "天",
    pinyin: "tiān",
    meaning: "day, sky",
    part_of_speech: "noun",
    understanding: 85,
    explanation: "☀️ ☁️ ⬆️"
  },
  %{
    word: "年",
    pinyin: "nián",
    meaning: "year",
    part_of_speech: "noun",
    understanding: 80,
    explanation: "📅 十二 月"
  },
  %{
    word: "月",
    pinyin: "yuè",
    meaning: "month, moon",
    part_of_speech: "noun",
    understanding: 80,
    explanation: "🌙 ~三十 天"
  },
  %{
    word: "日",
    pinyin: "rì",
    meaning: "day, sun",
    part_of_speech: "noun",
    understanding: 75,
    explanation: "☀️ 一 天"
  },
  %{
    word: "水",
    pinyin: "shuǐ",
    meaning: "water",
    part_of_speech: "noun",
    understanding: 90,
    explanation: "💧 我们 喝"
  },
  %{
    word: "火",
    pinyin: "huǒ",
    meaning: "fire",
    part_of_speech: "noun",
    understanding: 85,
    explanation: "🔥🥵"
  },
  %{
    word: "山",
    pinyin: "shān",
    meaning: "mountain",
    part_of_speech: "noun",
    understanding: 75,
    explanation: "⛰️🏔️"
  },
  %{
    word: "书",
    pinyin: "shū",
    meaning: "book",
    part_of_speech: "noun",
    understanding: 85,
    explanation: "📕📖 我们 读"
  },
  %{
    word: "中国",
    pinyin: "Zhōngguó",
    meaning: "China",
    part_of_speech: "noun",
    understanding: 90,
    explanation: "🇨🇳"
  },

  # Particles
  %{
    word: "的",
    pinyin: "de",
    meaning: "possessive particle",
    part_of_speech: "particle",
    understanding: 85,
    explanation: "我的 = 🧑👆"
  },
  %{
    word: "了",
    pinyin: "le",
    meaning: "completion particle",
    part_of_speech: "particle",
    understanding: 70,
    explanation: "做 ✅ 完"
  },
  %{
    word: "吗",
    pinyin: "ma",
    meaning: "question particle",
    part_of_speech: "particle",
    understanding: 90,
    explanation: "❓🤔"
  },
  %{
    word: "呢",
    pinyin: "ne",
    meaning: "modal particle",
    part_of_speech: "particle",
    understanding: 60,
    explanation: "你呢？= 你❓"
  },

  # Adverbs
  %{
    word: "不",
    pinyin: "bù",
    meaning: "not, no",
    part_of_speech: "adverb",
    understanding: 100,
    explanation: "🚫❌"
  },
  %{
    word: "很",
    pinyin: "hěn",
    meaning: "very",
    part_of_speech: "adverb",
    understanding: 90,
    explanation: "好 ➡️ 很好 = 好好好"
  },
  %{
    word: "也",
    pinyin: "yě",
    meaning: "also, too",
    part_of_speech: "adverb",
    understanding: 85,
    explanation: "我 喜欢，你 也 喜欢 👥"
  },
  %{
    word: "都",
    pinyin: "dōu",
    meaning: "all, both",
    part_of_speech: "adverb",
    understanding: 75,
    explanation: "我们 都 = 👥✅"
  }
]

# Insert all concepts
for concept_attrs <- concepts do
  %Concept{}
  |> Concept.changeset(concept_attrs)
  |> Repo.insert!()
end

IO.puts("Seeded #{length(concepts)} concepts!")
