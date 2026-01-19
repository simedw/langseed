defmodule LangseedWeb.LandingLive do
  use LangseedWeb, :live_view

  def mount(_params, _session, socket) do
    # If already logged in, redirect to analyze
    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:ok, push_navigate(socket, to: ~p"/analyze")}
    else
      {:ok, assign(socket, active_example: 0)}
    end
  end

  def handle_event("show_example", %{"index" => index}, socket) do
    {:noreply, assign(socket, active_example: String.to_integer(index))}
  end

  @examples [
    %{
      word: "月",
      pinyin: "yuè",
      definitions: ["🌙 ~三十 天", "一年 有 十二 个 🌙"],
      translation: "moon / month",
      lang: "🇨🇳",
      lang_name: "Chinese"
    },
    %{
      word: "smultronställe",
      pinyin: "/ˈsmʉːl.trɔnˌstɛlːɛ/",
      definitions: ["en plats 🏞️ som är bra, bara du vet 🤫", "din hemliga favorit 📍✨"],
      translation: "a hidden gem / secret favorite place",
      lang: "🇸🇪",
      lang_name: "Swedish"
    },
    %{
      word: "学习",
      pinyin: "xuéxí",
      definitions: ["📚✏️🧠💡", "看 书 📖 + 想 🤔 = 知道 更多"],
      translation: "to study / to learn",
      lang: "🇨🇳",
      lang_name: "Chinese"
    }
  ]

  def render(assigns) do
    assigns = assign(assigns, :examples, @examples)

    ~H"""
    <div class="min-h-screen bg-base-100 overflow-hidden">
      <!-- Decorative background elements -->
      <div class="fixed inset-0 -z-10 overflow-hidden">
        <div class="absolute -top-40 -right-40 w-96 h-96 bg-primary/5 rounded-full blur-3xl"></div>
        <div class="absolute top-1/3 -left-40 w-80 h-80 bg-secondary/5 rounded-full blur-3xl"></div>
        <div class="absolute bottom-20 right-1/4 w-64 h-64 bg-accent/5 rounded-full blur-3xl"></div>
      </div>
      
    <!-- Hero Section -->
      <div class="relative">
        <div class="container mx-auto px-4 pt-12 pb-8 sm:pt-20 sm:pb-16">
          <div class="flex flex-col lg:flex-row items-center gap-12 lg:gap-16">
            <!-- Left side: Text content -->
            <div class="flex-1 text-center lg:text-left max-w-xl">
              <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 text-primary text-sm font-medium mb-6">
                <span class="text-lg">🌱</span>
                <span>Learn words using words you already know</span>
              </div>

              <h1 class="text-4xl sm:text-5xl lg:text-6xl font-bold mb-6 leading-tight">
                <span class="bg-gradient-to-r from-primary via-secondary to-primary bg-clip-text text-transparent bg-[length:200%_auto] animate-[gradient_3s_ease-in-out_infinite]">
                  LangSeed
                </span>
              </h1>

              <p class="text-xl sm:text-2xl text-base-content/80 mb-4 font-light">
                The dictionary that speaks your level
              </p>

              <p class="text-base text-base-content/60 mb-8 leading-relaxed">
                New words are explained using <strong class="text-base-content/80">only vocabulary you already know</strong>,
                with <span class="inline-block">emojis 🎯</span> bridging the gaps.
                Like solving a puzzle; every definition is a clue.
              </p>

              <div class="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
                <a
                  href={~p"/auth/google"}
                  class="group btn btn-primary btn-lg gap-3 shadow-lg shadow-primary/25 hover:shadow-xl hover:shadow-primary/30 transition-all duration-300"
                >
                  <svg class="w-5 h-5" viewBox="0 0 24 24">
                    <path
                      fill="currentColor"
                      d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                    />
                    <path
                      fill="currentColor"
                      d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                    />
                    <path
                      fill="currentColor"
                      d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                    />
                    <path
                      fill="currentColor"
                      d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                    />
                  </svg>
                  <span>Get Started Free</span>
                  <.icon
                    name="hero-arrow-right"
                    class="w-4 h-4 group-hover:translate-x-1 transition-transform"
                  />
                </a>
              </div>

              <p class="text-xs text-base-content/40 mt-4">Free to try · Bring your own API key 🔑</p>
            </div>
            
    <!-- Right side: Interactive example card -->
            <div class="flex-1 w-full max-w-md">
              <div class="relative">
                <!-- Glow effect behind card -->
                <div class="absolute inset-0 bg-gradient-to-r from-primary/20 to-secondary/20 rounded-3xl blur-2xl transform scale-105">
                </div>
                
    <!-- Main card -->
                <div class="relative bg-base-100 rounded-2xl shadow-2xl border border-base-200 overflow-hidden">
                  <!-- Card header -->
                  <div class="px-6 py-4 bg-gradient-to-r from-primary/10 to-secondary/10 border-b border-base-200">
                    <div class="flex items-center justify-between">
                      <span class="text-sm font-medium text-base-content/60">Word Definition</span>
                      <div class="flex items-center gap-1.5">
                        <span class="text-lg">{Enum.at(@examples, @active_example).lang}</span>
                        <span class="text-xs text-base-content/50">
                          {Enum.at(@examples, @active_example).lang_name}
                        </span>
                      </div>
                    </div>
                  </div>
                  
    <!-- Word display -->
                  <div class="px-6 py-8 text-center">
                    <div class="text-6xl font-bold mb-2 text-base-content">
                      {Enum.at(@examples, @active_example).word}
                    </div>
                    <div class="text-lg text-base-content/50 mb-6">
                      {Enum.at(@examples, @active_example).pinyin}
                    </div>
                    
    <!-- Definitions -->
                    <div class="space-y-3">
                      <%= for def <- Enum.at(@examples, @active_example).definitions do %>
                        <div class="bg-base-200/50 rounded-xl px-4 py-3 text-lg">
                          {def}
                        </div>
                      <% end %>
                    </div>
                    
    <!-- Hover to reveal translation -->
                    <div class="mt-6 group cursor-pointer">
                      <div class="text-sm text-base-content/40 group-hover:opacity-0 transition-opacity">
                        Hover to reveal meaning
                      </div>
                      <div class="text-sm text-primary font-medium opacity-0 group-hover:opacity-100 transition-opacity -mt-5">
                        {Enum.at(@examples, @active_example).translation}
                      </div>
                    </div>
                  </div>
                  
    <!-- Example selector -->
                  <div class="px-6 py-4 bg-base-200/30 border-t border-base-200">
                    <div class="flex justify-center gap-2">
                      <%= for {_example, index} <- Enum.with_index(@examples) do %>
                        <button
                          phx-click="show_example"
                          phx-value-index={index}
                          class={[
                            "w-3 h-3 rounded-full transition-all duration-300",
                            if(@active_example == index,
                              do: "bg-primary w-8",
                              else: "bg-base-300 hover:bg-base-content/30"
                            )
                          ]}
                        >
                        </button>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- How It Works Section -->
      <div class="py-20 bg-gradient-to-b from-transparent to-base-200/50">
        <div class="container mx-auto px-4">
          <div class="text-center mb-16">
            <h2 class="text-3xl sm:text-4xl font-bold mb-4">How It Works</h2>
            <p class="text-base-content/60 max-w-2xl mx-auto">
              A vocabulary that grows with you, where every new word builds on what you already know
            </p>
          </div>

          <div class="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto">
            <!-- Step 1 -->
            <div class="group relative">
              <div class="absolute inset-0 bg-gradient-to-br from-primary/10 to-transparent rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-500">
              </div>
              <div class="relative p-8 text-center">
                <div class="w-16 h-16 mx-auto mb-6 bg-primary/10 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                  <span class="text-3xl">📚</span>
                </div>
                <div class="text-sm font-bold text-primary mb-2">STEP 1</div>
                <h3 class="text-xl font-semibold mb-3">Import Real Texts</h3>
                <p class="text-base-content/60 text-sm leading-relaxed">
                  Paste articles, stories, or any text you want to read. We segment it and identify words you don't know yet.
                </p>
              </div>
            </div>
            
    <!-- Step 2 -->
            <div class="group relative">
              <div class="absolute inset-0 bg-gradient-to-br from-secondary/10 to-transparent rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-500">
              </div>
              <div class="relative p-8 text-center">
                <div class="w-16 h-16 mx-auto mb-6 bg-secondary/10 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                  <span class="text-3xl">🧩</span>
                </div>
                <div class="text-sm font-bold text-secondary mb-2">STEP 2</div>
                <h3 class="text-xl font-semibold mb-3">Decode with AI</h3>
                <p class="text-base-content/60 text-sm leading-relaxed">
                  Each word is explained using only your known vocabulary, plus emojis when concepts are hard to express.
                </p>
              </div>
            </div>
            
    <!-- Step 3 -->
            <div class="group relative">
              <div class="absolute inset-0 bg-gradient-to-br from-accent/10 to-transparent rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-500">
              </div>
              <div class="relative p-8 text-center">
                <div class="w-16 h-16 mx-auto mb-6 bg-accent/10 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                  <span class="text-3xl">✨</span>
                </div>
                <div class="text-sm font-bold text-base-content/60 mb-2">STEP 3</div>
                <h3 class="text-xl font-semibold mb-3">Practice & Grow</h3>
                <p class="text-base-content/60 text-sm leading-relaxed">
                  Quiz yourself with fill-in-the-blank and yes/no questions generated just for your vocabulary level.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- The Magic Section -->
      <div class="py-20">
        <div class="container mx-auto px-4">
          <div class="max-w-4xl mx-auto">
            <div class="grid md:grid-cols-2 gap-12 items-center">
              <div>
                <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-warning/10 text-warning text-sm font-medium mb-4">
                  <span>💡</span>
                  <span>The Insight</span>
                </div>
                <h2 class="text-3xl font-bold mb-6">
                  Learning a word feels like solving a puzzle
                </h2>
                <p class="text-base-content/70 mb-4 leading-relaxed">
                  When you see a new word defined with words you already know, your brain works to figure it out.
                  That cognitive effort makes the word stick.
                </p>
                <p class="text-base-content/70 leading-relaxed">
                  And when the AI can't express something with your vocabulary?
                  It uses emojis, the universal language we all understand.
                  <span class="text-2xl ml-1">🎯</span>
                </p>
              </div>

              <div class="bg-base-200/50 rounded-2xl p-6 border border-base-200">
                <div class="text-sm text-base-content/50 mb-4">Example definition for 累 (tired):</div>
                <div class="space-y-2">
                  <div class="bg-base-100 rounded-lg px-4 py-3">
                    做 很 多 事 以后 的 感觉 😴
                  </div>
                  <div class="bg-base-100 rounded-lg px-4 py-3">
                    想 睡觉 💤, 不 想 动 🛋️
                  </div>
                  <div class="bg-base-100 rounded-lg px-4 py-3">
                    工作 很 多 = 很 累 😩
                  </div>
                </div>
                <div class="text-xs text-base-content/40 mt-4 text-right">
                  Using only beginner vocabulary + emojis
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Languages Section -->
      <div class="py-16 bg-base-200/30">
        <div class="container mx-auto px-4">
          <div class="text-center mb-10">
            <h2 class="text-2xl font-bold mb-2">Currently Supporting</h2>
            <p class="text-base-content/50 text-sm">More languages coming soon</p>
          </div>

          <div class="flex flex-wrap justify-center gap-6 max-w-2xl mx-auto">
            <div class="flex items-center gap-3 bg-base-100 px-6 py-4 rounded-xl shadow-sm border border-base-200 hover:border-primary/30 hover:shadow-md transition-all duration-300">
              <span class="text-4xl">🇨🇳</span>
              <div>
                <div class="font-semibold">Chinese</div>
                <div class="text-sm text-base-content/50">中文 · Mandarin</div>
              </div>
            </div>

            <div class="flex items-center gap-3 bg-base-100 px-6 py-4 rounded-xl shadow-sm border border-base-200 hover:border-primary/30 hover:shadow-md transition-all duration-300">
              <span class="text-4xl">🇯🇵</span>
              <div>
                <div class="font-semibold">Japanese</div>
                <div class="text-sm text-base-content/50">日本語</div>
              </div>
            </div>

            <div class="flex items-center gap-3 bg-base-100 px-6 py-4 rounded-xl shadow-sm border border-base-200 hover:border-primary/30 hover:shadow-md transition-all duration-300">
              <span class="text-4xl">🇸🇪</span>
              <div>
                <div class="font-semibold">Swedish</div>
                <div class="text-sm text-base-content/50">Svenska</div>
              </div>
            </div>

            <div class="flex items-center gap-3 bg-base-100 px-6 py-4 rounded-xl shadow-sm border border-base-200 hover:border-primary/30 hover:shadow-md transition-all duration-300">
              <span class="text-4xl">🇬🇧</span>
              <div>
                <div class="font-semibold">English</div>
                <div class="text-sm text-base-content/50">For debugging 😄</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Final CTA -->
      <div class="py-24">
        <div class="container mx-auto px-4">
          <div class="max-w-2xl mx-auto text-center">
            <h2 class="text-3xl sm:text-4xl font-bold mb-6">
              Ready to grow your vocabulary?
            </h2>
            <p class="text-base-content/60 mb-8">
              Start with words you know. Build understanding one definition at a time.
              No flashcards, just genuine comprehension.
            </p>

            <a
              href={~p"/auth/google"}
              class="group btn btn-primary btn-lg gap-3 shadow-lg shadow-primary/25 hover:shadow-xl hover:shadow-primary/30 transition-all duration-300"
            >
              <svg class="w-5 h-5" viewBox="0 0 24 24">
                <path
                  fill="currentColor"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="currentColor"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="currentColor"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                />
                <path
                  fill="currentColor"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                />
              </svg>
              <span>Start Learning Free</span>
              <.icon
                name="hero-arrow-right"
                class="w-4 h-4 group-hover:translate-x-1 transition-transform"
              />
            </a>

            <p class="text-xs text-base-content/40 mt-4">
              Free to try · Bring your own API key
            </p>

            <div class="mt-8 pt-6 border-t border-base-200">
              <a
                href="https://github.com/simedw/langseed"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-2 text-sm text-base-content/50 hover:text-base-content/80 transition-colors"
              >
                <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
                </svg>
                <span>100% Open Source · View on GitHub</span>
                <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
              </a>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Footer -->
      <footer class="border-t border-base-200 py-8">
        <div class="container mx-auto px-4">
          <div class="flex flex-col sm:flex-row justify-between items-center gap-4">
            <div class="flex items-center gap-2 text-base-content/50">
              <span class="text-xl">🌱</span>
              <span class="font-medium">LangSeed</span>
              <span class="text-sm">· Grow your vocabulary, one word at a time</span>
            </div>
            <div class="flex items-center gap-4 text-sm text-base-content/40">
              <a
                href="https://github.com/simedw/langseed"
                target="_blank"
                rel="noopener noreferrer"
                class="flex items-center gap-1.5 hover:text-base-content/70 transition-colors"
              >
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
                </svg>
                <span>GitHub</span>
              </a>
              <span>·</span>
              <a
                href="https://simedw.com/"
                target="_blank"
                rel="noopener noreferrer"
                class="hover:text-base-content/70 transition-colors"
              >
                Blog
              </a>
              <span>·</span>
              <span>Built with 💜 in Phoenix</span>
            </div>
          </div>
        </div>
      </footer>
    </div>
    """
  end
end
