defmodule LangseedWeb.AdminDashboardLive do
  use LangseedWeb, :live_view

  alias Langseed.Admin

  @impl true
  def mount(_params, _session, socket) do
    # Load all metrics
    metrics = %{
      total_users: Admin.total_users(),
      total_words: Admin.total_words_learned(),
      total_questions: Admin.total_questions_answered(),
      avg_understanding: Admin.average_understanding(),
      llm_usage: Admin.total_llm_usage(),
      language_distribution: Admin.language_distribution(),
      srs_distribution: Admin.srs_tier_distribution(),
      llm_by_type: Admin.llm_usage_by_type()
    }

    # Time series data for charts
    signups_data = Admin.signups_by_day(30)
    practice_data = Admin.practice_by_day(30)
    words_data = Admin.words_by_day(30)
    llm_data = Admin.llm_queries_by_day(30)

    # User list with metrics
    users = Admin.users_with_metrics()

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       metrics: metrics,
       users: users,
       signups_chart_data: Jason.encode!(signups_data),
       practice_chart_data: Jason.encode!(practice_data),
       words_chart_data: Jason.encode!(words_data),
       llm_chart_data: Jason.encode!(llm_data)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen p-4 md:p-6">
      <div class="max-w-7xl mx-auto">
        <h1 class="text-3xl font-bold mb-6">Admin Dashboard</h1>

        <%!-- Summary Stats Cards --%>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <.stat_card title="Total Users" value={@metrics.total_users} icon="hero-users" />
          <.stat_card title="Words Learned" value={@metrics.total_words} icon="hero-book-open" />
          <.stat_card
            title="Questions Answered"
            value={@metrics.total_questions}
            icon="hero-academic-cap"
          />
          <.stat_card
            title="Avg Understanding"
            value={"#{@metrics.avg_understanding}%"}
            icon="hero-chart-bar"
          />
        </div>

        <%!-- Charts Row --%>
        <div class="grid md:grid-cols-2 gap-6 mb-8">
          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg">User Signups (30 days)</h2>
              <div
                id="signups-chart"
                phx-hook="AdminChart"
                phx-update="ignore"
                data-chart={@signups_chart_data}
                data-label="Signups"
                data-color="#36d399"
                class="h-48"
              />
            </div>
          </div>

          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg">Practice Activity (30 days)</h2>
              <div
                id="practice-chart"
                phx-hook="AdminChart"
                phx-update="ignore"
                data-chart={@practice_chart_data}
                data-label="Questions"
                data-color="#3abff8"
                class="h-48"
              />
            </div>
          </div>
        </div>

        <div class="grid md:grid-cols-2 gap-6 mb-8">
          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg">Words Added (30 days)</h2>
              <div
                id="words-chart"
                phx-hook="AdminChart"
                phx-update="ignore"
                data-chart={@words_chart_data}
                data-label="Words"
                data-color="#f59e0b"
                class="h-48"
              />
            </div>
          </div>

          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg">LLM API Usage (30 days)</h2>
              <div
                id="llm-chart"
                phx-hook="AdminChart"
                phx-update="ignore"
                data-chart={@llm_chart_data}
                data-label="Queries"
                data-color="#a855f7"
                class="h-48"
              />
            </div>
          </div>
        </div>

        <%!-- LLM Usage Stats --%>
        <div class="card bg-base-200 shadow mb-8">
          <div class="card-body">
            <h2 class="card-title text-lg">LLM Token Usage</h2>
            <div class="stats stats-vertical lg:stats-horizontal shadow bg-base-100">
              <div class="stat">
                <div class="stat-title">Total Queries</div>
                <div class="stat-value text-primary">{@metrics.llm_usage.query_count}</div>
              </div>
              <div class="stat">
                <div class="stat-title">Input Tokens</div>
                <div class="stat-value text-secondary">
                  {format_number(@metrics.llm_usage.input_tokens)}
                </div>
              </div>
              <div class="stat">
                <div class="stat-title">Output Tokens</div>
                <div class="stat-value text-accent">
                  {format_number(@metrics.llm_usage.output_tokens)}
                </div>
              </div>
            </div>

            <h3 class="font-medium mt-4 mb-2">By Query Type</h3>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th class="text-right">Count</th>
                    <th class="text-right">Input</th>
                    <th class="text-right">Output</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for stat <- @metrics.llm_by_type do %>
                    <tr>
                      <td>{stat.query_type}</td>
                      <td class="text-right">{stat.count}</td>
                      <td class="text-right">{format_number(stat.input_tokens || 0)}</td>
                      <td class="text-right">{format_number(stat.output_tokens || 0)}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <%!-- Language Distribution --%>
        <div class="grid md:grid-cols-2 gap-6 mb-8">
          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg">Language Distribution</h2>
              <div class="space-y-2">
                <%= for lang <- @metrics.language_distribution do %>
                  <div class="flex items-center gap-2">
                    <span class="w-8">{language_flag(lang.language)}</span>
                    <span class="flex-1">{lang.language}</span>
                    <span class="badge">{lang.count} words</span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg">SRS Tier Distribution</h2>
              <div class="space-y-2">
                <%= for tier <- @metrics.srs_distribution do %>
                  <div class="flex items-center gap-2">
                    <span class="w-16 text-sm">Tier {tier.tier}</span>
                    <div class="flex-1 h-4 bg-base-300 rounded-full overflow-hidden">
                      <div
                        class="h-full bg-primary"
                        style={"width: #{tier_percent(tier.count, @metrics.srs_distribution)}%"}
                      />
                    </div>
                    <span class="w-16 text-right text-sm">{tier.count}</span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <%!-- User Table --%>
        <div class="card bg-base-200 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg">Users</h2>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Email</th>
                    <th>Language</th>
                    <th class="text-right">Words</th>
                    <th class="text-right">Practice</th>
                    <th>Last Activity</th>
                    <th>Signed Up</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for user <- @users do %>
                    <tr>
                      <td class="max-w-[200px] truncate" title={user.email}>{user.email}</td>
                      <td>{language_flag(user.language)} {user.language}</td>
                      <td class="text-right">{user.word_count}</td>
                      <td class="text-right">{user.practice_count}</td>
                      <td>{format_datetime(user.last_activity)}</td>
                      <td>{format_datetime(user.signed_up)}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component for stat cards
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow">
      <div class="card-body p-4">
        <div class="flex items-center gap-2">
          <.icon name={@icon} class="size-5 opacity-60" />
          <span class="text-sm opacity-70">{@title}</span>
        </div>
        <div class="text-2xl font-bold">{@value}</div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_number(nil), do: "0"

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(n), do: format_number(trunc(n))

  defp format_datetime(nil), do: "-"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end

  defp language_flag("zh"), do: "🇨🇳"
  defp language_flag("ja"), do: "🇯🇵"
  defp language_flag("sv"), do: "🇸🇪"
  defp language_flag("en"), do: "🇬🇧"
  defp language_flag("ko"), do: "🇰🇷"
  defp language_flag(_), do: "🌐"

  defp tier_percent(count, distribution) do
    total = Enum.reduce(distribution, 0, fn t, acc -> acc + t.count end)
    if total > 0, do: round(count / total * 100), else: 0
  end
end
