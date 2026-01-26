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
      llm_by_type: Admin.llm_usage_by_type(),
      engagement: Admin.engagement_stats(),
      funnel: Admin.user_funnel()
    }

    # Time series data for charts
    signups_data = Admin.signups_by_day(30)
    practice_data = Admin.practice_by_day(30)
    words_data = Admin.words_by_day(30)
    llm_data = Admin.llm_queries_by_day(30)

    # User list with metrics
    users = Admin.users_with_metrics()

    # Get unique languages for filter dropdown
    languages =
      users
      |> Enum.map(& &1.language)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()

    # Default filters
    filters = %{
      language: "all",
      status: "all",
      search: ""
    }

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       metrics: metrics,
       all_users: users,
       users: users,
       languages: languages,
       filters: filters,
       signups_chart_data: Jason.encode!(signups_data),
       practice_chart_data: Jason.encode!(practice_data),
       words_chart_data: Jason.encode!(words_data),
       llm_chart_data: Jason.encode!(llm_data)
     )}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter_params}, socket) do
    filters = %{
      language: Map.get(filter_params, "language", "all"),
      status: Map.get(filter_params, "status", "all"),
      search: Map.get(filter_params, "search", "")
    }

    filtered_users = filter_users(socket.assigns.all_users, filters)

    {:noreply, assign(socket, filters: filters, users: filtered_users)}
  end

  defp filter_users(users, filters) do
    users
    |> filter_by_language(filters.language)
    |> filter_by_status(filters.status)
    |> filter_by_search(filters.search)
  end

  defp filter_by_language(users, "all"), do: users

  defp filter_by_language(users, language) do
    Enum.filter(users, &(&1.language == language))
  end

  defp filter_by_status(users, "all"), do: users

  defp filter_by_status(users, "active") do
    week_ago = DateTime.utc_now() |> DateTime.add(-7, :day)

    Enum.filter(users, fn user ->
      user.practice_count > 0 && user.last_activity &&
        DateTime.compare(user.last_activity, week_ago) == :gt
    end)
  end

  defp filter_by_status(users, "practiced") do
    Enum.filter(users, &(&1.practice_count > 0))
  end

  defp filter_by_status(users, "never_practiced") do
    Enum.filter(users, &(&1.practice_count == 0))
  end

  defp filter_by_status(users, "added_words") do
    Enum.filter(users, &(&1.word_count > 30))
  end

  defp filter_by_status(users, "starter_only") do
    Enum.filter(users, &(&1.word_count <= 30))
  end

  defp filter_by_search(users, ""), do: users

  defp filter_by_search(users, search) do
    search_lower = String.downcase(search)
    Enum.filter(users, &String.contains?(String.downcase(&1.email || ""), search_lower))
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

        <%!-- Engagement & Retention Section --%>
        <div class="card bg-base-200 shadow mb-8">
          <div class="card-body">
            <h2 class="card-title text-lg">Engagement & Retention</h2>

            <div class="grid md:grid-cols-2 gap-6">
              <%!-- Key Metrics --%>
              <div>
                <h3 class="font-medium mb-3">Activation Metrics</h3>
                <div class="space-y-3">
                  <.engagement_metric
                    label="Practiced at least once"
                    count={@metrics.engagement.practiced_at_least_once}
                    total={@metrics.engagement.total_users}
                    pct={@metrics.engagement.practiced_pct}
                    color="error"
                  />
                  <.engagement_metric
                    label="Added words (beyond starter)"
                    count={@metrics.engagement.added_words}
                    total={@metrics.engagement.total_users}
                    pct={@metrics.engagement.added_words_pct}
                    color="warning"
                  />
                  <.engagement_metric
                    label="Active last 7 days"
                    count={@metrics.engagement.active_7d}
                    total={@metrics.engagement.total_users}
                    pct={@metrics.engagement.active_7d_pct}
                    color="info"
                  />
                  <.engagement_metric
                    label="Active last 30 days"
                    count={@metrics.engagement.active_30d}
                    total={@metrics.engagement.total_users}
                    pct={@metrics.engagement.active_30d_pct}
                    color="success"
                  />
                </div>
              </div>

              <%!-- User Funnel --%>
              <div>
                <h3 class="font-medium mb-3">User Funnel</h3>
                <div class="space-y-2">
                  <.funnel_stage
                    label="Signed up only (30 words, 0 practice)"
                    count={@metrics.funnel.signed_up_only}
                    total={@metrics.engagement.total_users}
                    color="base-300"
                  />
                  <.funnel_stage
                    label="Added words (no practice)"
                    count={@metrics.funnel.added_words}
                    total={@metrics.engagement.total_users}
                    color="warning"
                  />
                  <.funnel_stage
                    label="Tried practice (inactive now)"
                    count={@metrics.funnel.tried_once}
                    total={@metrics.engagement.total_users}
                    color="info"
                  />
                  <.funnel_stage
                    label="Active (practiced in 7 days)"
                    count={@metrics.funnel.active}
                    total={@metrics.engagement.total_users}
                    color="success"
                  />
                </div>
              </div>
            </div>
          </div>
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
            <div class="flex flex-wrap items-center justify-between gap-4 mb-4">
              <h2 class="card-title text-lg">
                Users
                <span class="badge badge-neutral">
                  {length(@users)}
                  <%= if length(@users) != length(@all_users) do %>
                    / {length(@all_users)}
                  <% end %>
                </span>
              </h2>

              <%!-- Filters --%>
              <form phx-change="filter" class="flex flex-wrap items-center gap-2">
                <input
                  type="text"
                  name="filter[search]"
                  value={@filters.search}
                  placeholder="Search email..."
                  class="input input-sm input-bordered w-48"
                  phx-debounce="300"
                />

                <select name="filter[language]" class="select select-sm select-bordered">
                  <option value="all" selected={@filters.language == "all"}>All languages</option>
                  <%= for lang <- @languages do %>
                    <option value={lang} selected={@filters.language == lang}>
                      {language_flag(lang)} {lang}
                    </option>
                  <% end %>
                </select>

                <select name="filter[status]" class="select select-sm select-bordered">
                  <option value="all" selected={@filters.status == "all"}>All users</option>
                  <option value="active" selected={@filters.status == "active"}>
                    Active (7 days)
                  </option>
                  <option value="practiced" selected={@filters.status == "practiced"}>
                    Practiced at least once
                  </option>
                  <option value="never_practiced" selected={@filters.status == "never_practiced"}>
                    Never practiced
                  </option>
                  <option value="added_words" selected={@filters.status == "added_words"}>
                    Added words (>30)
                  </option>
                  <option value="starter_only" selected={@filters.status == "starter_only"}>
                    Starter pack only
                  </option>
                </select>
              </form>
            </div>

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

            <%= if Enum.empty?(@users) do %>
              <div class="text-center py-8 opacity-60">
                No users match the selected filters
              </div>
            <% end %>
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

  # Component for engagement metrics
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :total, :integer, required: true
  attr :pct, :integer, required: true
  attr :color, :string, default: "primary"

  defp engagement_metric(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="flex-1">
        <div class="flex justify-between text-sm mb-1">
          <span>{@label}</span>
          <span class="font-medium">{@count} / {@total} ({@pct}%)</span>
        </div>
        <div class="h-2 bg-base-300 rounded-full overflow-hidden">
          <div class={"h-full bg-#{@color}"} style={"width: #{@pct}%"} />
        </div>
      </div>
    </div>
    """
  end

  # Component for funnel stages
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :total, :integer, required: true
  attr :color, :string, default: "primary"

  defp funnel_stage(assigns) do
    pct = if assigns.total > 0, do: round(assigns.count / assigns.total * 100), else: 0
    assigns = assign(assigns, :pct, pct)

    ~H"""
    <div class="flex items-center gap-2">
      <div class={"w-3 h-3 rounded-full bg-#{@color}"} />
      <span class="flex-1 text-sm">{@label}</span>
      <span class="font-medium text-sm">{@count}</span>
      <span class="text-xs opacity-60">({@pct}%)</span>
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
